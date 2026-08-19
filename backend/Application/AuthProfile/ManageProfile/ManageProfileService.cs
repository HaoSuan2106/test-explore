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
        user.City = request.City;
        user.Age = request.Age;
        user.Gender = request.Gender;
        user.UpdatedAt = DateTime.UtcNow;
        await _repository.UpdateUserAsync(user);

        return MapToDto(user);
    }

    public async Task RequestEmailChangeAsync(int userId, RequestEmailChangeRequestDto request)
    {
        var user = await _repository.GetByIdAsync(userId)
            ?? throw new NotFoundException("User not found.");

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
