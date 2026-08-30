using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.Common.Helpers;
using ExploreMy.Api.Configuration;
using ExploreMy.Api.DataAccess.ExternalClients.SupabaseStorage;
using ExploreMy.Api.DataAccess.Repositories.AuthProfile;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.AuthProfile;
using Microsoft.Extensions.Options;

namespace ExploreMy.Api.Application.AuthProfile.ManageProfile;

public class ManageProfileService : IManageProfileService
{
    private readonly IAuthProfileRepository _repository;
    private readonly IStorageClient _storageClient;
    private readonly IEmailSender _emailSender;
    private readonly SmtpSettings _smtpSettings;
    private readonly ILogger<ManageProfileService> _logger;

    public ManageProfileService(
        IAuthProfileRepository repository,
        IStorageClient storageClient,
        IEmailSender emailSender,
        IOptions<SmtpSettings> smtpSettings,
        ILogger<ManageProfileService> logger)
    {
        _repository = repository;
        _storageClient = storageClient;
        _emailSender = emailSender;
        _smtpSettings = smtpSettings.Value;
        _logger = logger;
    }

    public async Task<UserProfileDto> GetProfileAsync(int userId)
    {
        var user = await _repository.GetByIdAsync(userId)
            ?? throw new NotFoundException("User not found.");

        return MapToDto(user);
    }

    public async Task<UserProfileDto> UpdateProfilePictureAsync(int userId, Stream fileStream, string fileName, string contentType)
    {
        var user = await _repository.GetByIdAsync(userId)
            ?? throw new NotFoundException("User not found.");

        var previousUrl = user.ProfilePictureUrl;

        var extension = Path.GetExtension(fileName);
        var path = $"{userId}/{Guid.NewGuid()}{extension}";
        user.ProfilePictureUrl = await _storageClient.UploadAsync(path, fileStream, contentType);
        user.UpdatedAt = DateTime.UtcNow;
        await _repository.UpdateUserAsync(user);

        if (!string.IsNullOrEmpty(previousUrl))
        {
            await DeleteStoredPictureAsync(previousUrl);
        }

        return MapToDto(user);
    }

    public async Task<UserProfileDto> RemoveProfilePictureAsync(int userId)
    {
        var user = await _repository.GetByIdAsync(userId)
            ?? throw new NotFoundException("User not found.");

        if (!string.IsNullOrEmpty(user.ProfilePictureUrl))
        {
            var previousUrl = user.ProfilePictureUrl;
            user.ProfilePictureUrl = null;
            user.UpdatedAt = DateTime.UtcNow;
            await _repository.UpdateUserAsync(user);

            await DeleteStoredPictureAsync(previousUrl);
        }

        return MapToDto(user);
    }

    private static bool Blank(string? value) => string.IsNullOrWhiteSpace(value);

    public async Task<UserProfileDto> UpdateProfileAsync(int userId, UpdateProfileRequestDto request)
    {
        var user = await _repository.GetByIdAsync(userId)
            ?? throw new NotFoundException("User not found.");

        var username = request.Username.Trim();
        if (!string.Equals(username, user.Username, StringComparison.Ordinal))
        {
            var existing = await _repository.GetByUsernameAsync(username);
            if (existing is not null && existing.UserId != userId)
            {
                throw new ConflictException("Username is already in use.");
            }
        }

        user.Username = username;
        // Optional fields: a blank one is stored as NULL rather than "", so
        // "not set" has a single representation everywhere it is read back.
        user.City = Blank(request.City) ? null : request.City!.Trim();
        user.Age = request.Age;
        user.Gender = Blank(request.Gender) ? null : request.Gender;
        user.UpdatedAt = DateTime.UtcNow;
        await _repository.UpdateUserAsync(user);

        return MapToDto(user);
    }

    public async Task RequestCurrentEmailVerificationAsync(int userId)
    {
        var user = await _repository.GetByIdAsync(userId)
            ?? throw new NotFoundException("User not found.");

        await _repository.InvalidateActiveTokensAsync(userId);

        var code = VerificationCodeHelper.Generate();
        var token = new EmailVerificationToken
        {
            UserId = userId,
            Token = RefreshTokenHelper.Hash(code),
            PendingEmail = null,
            ExpiresAt = DateTime.UtcNow.AddMinutes(_smtpSettings.VerificationCodeExpiryMinutes),
            IsUsed = false,
            CreatedAt = DateTime.UtcNow
        };
        await _repository.CreateEmailVerificationTokenAsync(token);

        var subject = "Confirm it's you before changing your ExploreMy email";
        var body = $"<p>Your ExploreMy verification code is:</p><h2>{code}</h2>" +
                   $"<p>This code expires in {_smtpSettings.VerificationCodeExpiryMinutes} minutes.</p>";

        // Fire-and-forget: the code is already persisted, so don't make the
        // caller wait on the SMTP round trip. Failures are logged, not
        // surfaced — "Resend" is the recovery path.
        _ = Task.Run(async () =>
        {
            try
            {
                await _emailSender.SendAsync(user.Email, subject, body);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Could not send current-email verification code to {Email}.", user.Email);
            }
        });
    }

    public async Task VerifyCurrentEmailVerificationAsync(int userId, VerifyCurrentEmailRequestDto request)
    {
        var token = await _repository.GetLatestActiveTokenByUserIdAsync(userId);
        if (token is null
            || token.PendingEmail is not null
            || RefreshTokenHelper.Hash(request.Code) != token.Token)
        {
            throw new AuthenticationException("Invalid or expired verification code.");
        }

        await _repository.MarkTokenUsedAsync(token);
    }

    public async Task RequestEmailChangeAsync(int userId, RequestEmailChangeRequestDto request)
    {
        var user = await _repository.GetByIdAsync(userId)
            ?? throw new NotFoundException("User not found.");

        var verifiedCurrentEmail = await _repository.GetLatestVerifiedCurrentEmailTokenAsync(userId);
        if (verifiedCurrentEmail is null)
        {
            throw new AuthenticationException("Please verify your current email before changing it.");
        }

        var newEmail = request.NewEmail.Trim();
        if (string.Equals(newEmail, user.Email, StringComparison.OrdinalIgnoreCase))
        {
            throw new ConflictException("This is already your current email address.");
        }

        var existing = await _repository.GetByEmailAsync(newEmail);
        if (existing is not null && existing.UserId != userId)
        {
            throw new ConflictException("Email is already in use.");
        }

        await _repository.InvalidateActiveTokensAsync(userId);

        var code = VerificationCodeHelper.Generate();
        var token = new EmailVerificationToken
        {
            UserId = userId,
            Token = RefreshTokenHelper.Hash(code),
            PendingEmail = newEmail,
            ExpiresAt = DateTime.UtcNow.AddMinutes(_smtpSettings.VerificationCodeExpiryMinutes),
            IsUsed = false,
            CreatedAt = DateTime.UtcNow
        };
        await _repository.CreateEmailVerificationTokenAsync(token);

        var subject = "Confirm your new ExploreMy email address";
        var body = $"<p>Your ExploreMy email change verification code is:</p><h2>{code}</h2>" +
                   $"<p>This code expires in {_smtpSettings.VerificationCodeExpiryMinutes} minutes.</p>";

        // Fire-and-forget: the code is already persisted, so don't make the
        // caller wait on the SMTP round trip. Failures are logged, not
        // surfaced — "Resend" is the recovery path.
        _ = Task.Run(async () =>
        {
            try
            {
                await _emailSender.SendAsync(newEmail, subject, body);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Could not send email-change verification code to {Email}.", newEmail);
            }
        });
    }

    public async Task<UserProfileDto> VerifyEmailChangeAsync(int userId, VerifyEmailChangeRequestDto request)
    {
        var user = await _repository.GetByIdAsync(userId)
            ?? throw new NotFoundException("User not found.");

        var newEmail = request.NewEmail.Trim();
        var token = await _repository.GetLatestActiveTokenByUserIdAsync(userId);
        if (token is null
            || token.PendingEmail is null
            || !string.Equals(token.PendingEmail, newEmail, StringComparison.OrdinalIgnoreCase)
            || RefreshTokenHelper.Hash(request.Code) != token.Token)
        {
            throw new AuthenticationException("Invalid or expired verification code.");
        }

        var existing = await _repository.GetByEmailAsync(newEmail);
        if (existing is not null && existing.UserId != userId)
        {
            throw new ConflictException("Email is already in use.");
        }

        await _repository.MarkTokenUsedAsync(token);

        user.Email = newEmail;
        user.UpdatedAt = DateTime.UtcNow;
        await _repository.UpdateUserAsync(user);

        return MapToDto(user);
    }

    /// UC103 A3-4 step 3 — abandoning the email change invalidates any code
    /// that was issued for it, so a stale code can never be replayed later.
    public async Task CancelEmailChangeAsync(int userId)
    {
        await _repository.InvalidateActiveTokensAsync(userId);
    }

    public async Task RequestPasswordResetCodeAsync(int userId)
    {
        var user = await _repository.GetByIdAsync(userId)
            ?? throw new NotFoundException("User not found.");

        await _repository.InvalidateActivePasswordResetTokensAsync(userId);

        var code = VerificationCodeHelper.Generate();
        var token = new PasswordResetToken
        {
            UserId = userId,
            Token = RefreshTokenHelper.Hash(code),
            ExpiresAt = DateTime.UtcNow.AddMinutes(_smtpSettings.VerificationCodeExpiryMinutes),
            IsUsed = false,
            CreatedAt = DateTime.UtcNow
        };
        await _repository.CreatePasswordResetTokenAsync(token);

        var subject = "Your ExploreMy password reset code";
        var body = $"<p>Your ExploreMy password reset code is:</p><h2>{code}</h2>" +
                   $"<p>This code expires in {_smtpSettings.VerificationCodeExpiryMinutes} minutes. " +
                   "If you didn't request this, you can safely ignore this email.</p>";

        // Fire-and-forget: the code is already persisted, so don't make the
        // caller wait on the SMTP round trip. Failures are logged, not
        // surfaced — "Resend" is the recovery path.
        _ = Task.Run(async () =>
        {
            try
            {
                await _emailSender.SendAsync(user.Email, subject, body);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Could not send password reset code to {Email}.", user.Email);
            }
        });
    }

    public async Task VerifyPasswordResetCodeAsync(int userId, VerifyPasswordResetCodeRequestDto request)
    {
        var token = await _repository.GetLatestActivePasswordResetTokenByUserIdAsync(userId);
        if (token is null || RefreshTokenHelper.Hash(request.Code) != token.Token)
        {
            throw new AuthenticationException("Invalid or expired verification code.");
        }
    }

    public async Task VerifyCurrentPasswordAsync(int userId, CheckPasswordRequestDto request)
    {
        var user = await _repository.GetByIdAsync(userId)
            ?? throw new NotFoundException("User not found.");

        if (!PasswordHasher.VerifyPassword(request.CurrentPassword, user.PasswordHash))
        {
            throw new AuthenticationException("Current password is incorrect.");
        }
    }

    public async Task UpdatePasswordAsync(int userId, UpdatePasswordRequestDto request)
    {
        var user = await _repository.GetByIdAsync(userId)
            ?? throw new NotFoundException("User not found.");

        PasswordResetToken? resetToken = null;
        if (!string.IsNullOrWhiteSpace(request.CurrentPassword))
        {
            if (!PasswordHasher.VerifyPassword(request.CurrentPassword, user.PasswordHash))
            {
                throw new AuthenticationException("Current password is incorrect.");
            }
        }
        else if (!string.IsNullOrWhiteSpace(request.ResetCode))
        {
            resetToken = await _repository.GetLatestActivePasswordResetTokenByUserIdAsync(userId);
            if (resetToken is null || RefreshTokenHelper.Hash(request.ResetCode) != resetToken.Token)
            {
                throw new AuthenticationException("Invalid or expired verification code.");
            }
        }
        else
        {
            throw new AuthenticationException(
                "Confirm your current password or verify a reset code before updating your password.");
        }

        if (PasswordHasher.VerifyPassword(request.NewPassword, user.PasswordHash))
        {
            throw new ValidationException("New password must be different from the current password.");
        }

        user.PasswordHash = PasswordHasher.HashPassword(request.NewPassword);
        user.UpdatedAt = DateTime.UtcNow;
        await _repository.UpdateUserAsync(user);

        if (resetToken is not null)
        {
            await _repository.MarkPasswordResetTokenUsedAsync(resetToken);
        }
        await _repository.InvalidateActivePasswordResetTokensAsync(userId);
    }

    private async Task DeleteStoredPictureAsync(string publicUrl)
    {
        var path = _storageClient.GetPathFromPublicUrl(publicUrl);
        if (path == null)
        {
            return;
        }

        try
        {
            await _storageClient.DeleteAsync(path);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to delete previous profile picture at {Path}.", path);
        }
    }

    private static UserProfileDto MapToDto(User user) => new()
    {
        UserId = user.UserId,
        Username = user.Username,
        Email = user.Email,
        City = user.City,
        Age = user.Age,
        Gender = user.Gender,
        ProfilePictureUrl = user.ProfilePictureUrl,
    };
}
