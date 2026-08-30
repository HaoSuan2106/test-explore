using Microsoft.Extensions.Options;
using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.Common.Helpers;
using ExploreMy.Api.Configuration;
using ExploreMy.Api.DataAccess.Repositories.AuthProfile;
using ExploreMy.Api.DTOs.AuthProfile;
using ExploreMy.Api.Domain.Entities;

namespace ExploreMy.Api.Application.AuthProfile.Authentication;

public class AuthenticationService : IAuthenticationService
{
    private readonly IAuthProfileRepository _repository;
    private readonly IJwtTokenGenerator _tokenGenerator;
    private readonly IEmailSender _emailSender;
    private readonly JwtSettings _jwtSettings;
    private readonly SmtpSettings _smtpSettings;
    private readonly ILogger<AuthenticationService> _logger;

    public AuthenticationService(
        IAuthProfileRepository repository,
        IJwtTokenGenerator tokenGenerator,
        IEmailSender emailSender,
        IOptions<JwtSettings> jwtSettings,
        IOptions<SmtpSettings> smtpSettings,
        ILogger<AuthenticationService> logger)
    {
        _repository = repository;
        _tokenGenerator = tokenGenerator;
        _emailSender = emailSender;
        _jwtSettings = jwtSettings.Value;
        _smtpSettings = smtpSettings.Value;
        _logger = logger;
    }

    public async Task<RegisterResponseDto> RegisterAsync(RegisterRequestDto request)
    {
        var email = request.Email.Trim();
        var username = request.Username.Trim();

        var existingByEmail = await _repository.GetByEmailAsync(email);
        if (existingByEmail is not null)
        {
            if (existingByEmail.AccountStatus != "pending_verification")
            {
                _logger.LogWarning("Registration attempt failed for {Email}: email already in use.", email);
                throw new ConflictException("Email is already in use.");
            }

            // Account exists but was never verified — resume registration by
            // reissuing a code instead of blocking a legitimate retry. The
            // username may have been changed on the retry, so it still has to
            // be free (unless this same row already owns it).
            var usernameOwner = await _repository.GetByUsernameAsync(username);
            if (usernameOwner is not null && usernameOwner.UserId != existingByEmail.UserId)
            {
                _logger.LogWarning("Registration attempt failed for {Username}: username already in use.", username);
                throw new ConflictException("Username is already in use.");
            }

            return await ResumeRegistrationAsync(existingByEmail, username, email, request.Password);
        }

        var existingByUsername = await _repository.GetByUsernameAsync(username);
        if (existingByUsername is not null)
        {
            if (existingByUsername.AccountStatus != "pending_verification")
            {
                _logger.LogWarning("Registration attempt failed for {Username}: username already in use.", username);
                throw new ConflictException("Username is already in use.");
            }

            // Same unverified sign-up being retried with a corrected email. The
            // address is known to be unclaimed (checked above), so move the
            // pending row onto it rather than dead-ending the user on a
            // username they believe is theirs.
            return await ResumeRegistrationAsync(existingByUsername, username, email, request.Password);
        }

        var user = new User
        {
            Username = username,
            Email = email,
            PasswordHash = PasswordHasher.HashPassword(request.Password),
            AccountStatus = "pending_verification",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        try
        {
            await _repository.CreateUserAsync(user);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Registration failed for {Email}: could not create user.", email);
            throw;
        }

        await IssueVerificationCodeAsync(user);

        return new RegisterResponseDto
        {
            UserId = user.UserId,
            Username = user.Username,
            Email = user.Email,
            AccountStatus = user.AccountStatus
        };
    }

    /// Re-runs an unverified sign-up on the existing row: the details the user
    /// just typed win (nothing was ever confirmed on the old ones), and a fresh
    /// code goes out so the caller lands on the verification step.
    private async Task<RegisterResponseDto> ResumeRegistrationAsync(
        User user, string username, string email, string password)
    {
        user.Username = username;
        user.Email = email;
        user.PasswordHash = PasswordHasher.HashPassword(password);
        user.UpdatedAt = DateTime.UtcNow;
        await _repository.UpdateUserAsync(user);

        await IssueVerificationCodeAsync(user);

        _logger.LogInformation(
            "Resumed pending registration for {Email} (user {UserId}).", email, user.UserId);

        return new RegisterResponseDto
        {
            UserId = user.UserId,
            Username = user.Username,
            Email = user.Email,
            AccountStatus = user.AccountStatus
        };
    }

    public async Task<LoginResponseDto> VerifyEmailAsync(VerifyEmailRequestDto request)
    {
        var user = await _repository.GetByEmailAsync(request.Email);
        if (user is null)
        {
            _logger.LogWarning("Verification attempt failed: no account for {Email}.", request.Email);
            throw new AuthenticationException("Invalid email or verification code.");
        }

        if (user.AccountStatus == "active")
        {
            throw new ConflictException("This account is already verified.");
        }

        var token = await _repository.GetLatestActiveTokenByUserIdAsync(user.UserId);
        if (token is null || RefreshTokenHelper.Hash(request.Code) != token.Token)
        {
            _logger.LogWarning("Verification attempt failed for {Email}: invalid or expired code.", request.Email);
            throw new AuthenticationException("Invalid email or verification code.");
        }

        await _repository.MarkTokenUsedAsync(token);

        user.AccountStatus = "active";
        user.UpdatedAt = DateTime.UtcNow;
        await _repository.UpdateUserAsync(user);

        return await IssueTokensAsync(user);
    }

    public async Task ResendVerificationAsync(ResendVerificationRequestDto request)
    {
        var user = await _repository.GetByEmailAsync(request.Email);
        if (user is null)
        {
            throw new NotFoundException("No account found with this email.");
        }

        if (user.AccountStatus == "active")
        {
            throw new ConflictException("This account is already verified.");
        }

        await IssueVerificationCodeAsync(user);
    }

    private async Task IssueVerificationCodeAsync(User user)
    {
        await _repository.InvalidateActiveTokensAsync(user.UserId);

        var code = VerificationCodeHelper.Generate();
        var token = new EmailVerificationToken
        {
            UserId = user.UserId,
            Token = RefreshTokenHelper.Hash(code),
            ExpiresAt = DateTime.UtcNow.AddMinutes(_smtpSettings.VerificationCodeExpiryMinutes),
            IsUsed = false,
            CreatedAt = DateTime.UtcNow
        };
        await _repository.CreateEmailVerificationTokenAsync(token);

        var subject = "Verify your ExploreMy account";
        var body = $"<p>Your ExploreMy verification code is:</p><h2>{code}</h2>" +
                   $"<p>This code expires in {_smtpSettings.VerificationCodeExpiryMinutes} minutes.</p>";

        // Fire-and-forget: the code is already persisted, so don't make the
        // caller wait on the SMTP round trip (often the slowest step by far).
        // Failures are logged, not surfaced — "Resend" is the recovery path.
        _ = Task.Run(async () =>
        {
            try
            {
                await _emailSender.SendAsync(user.Email, subject, body);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Could not send verification email to {Email}.", user.Email);
            }
        });
    }

    public async Task<LoginResponseDto> LoginAsync(LoginRequestDto request)
    {
        User? user;
        try
        {
            user = await _repository.GetByEmailAsync(request.Email);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Login failed for {Email}: could not reach the repository.", request.Email);
            throw;
        }

        if (user is null || !PasswordHasher.VerifyPassword(request.Password, user.PasswordHash))
        {
            _logger.LogWarning("Login attempt failed for {Email}: invalid credentials.", request.Email);
            throw new AuthenticationException("Invalid email or password.");
        }

        if (user.AccountStatus == "suspended")
        {
            _logger.LogWarning("Login attempt blocked for {Email}: account suspended.", request.Email);
            throw new ForbiddenException("This account has been suspended.");
        }

        try
        {
            return await IssueTokensAsync(user);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Login failed for {Email}: token generation or session creation error.", request.Email);
            throw;
        }
    }

    public async Task<LoginResponseDto> RefreshTokenAsync(RefreshTokenRequestDto request)
    {
        var tokenHash = RefreshTokenHelper.Hash(request.RefreshToken);

        UserSession? session;
        try
        {
            session = await _repository.GetActiveSessionByTokenHashAsync(tokenHash);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Refresh failed: could not reach the repository.");
            throw;
        }

        if (session is null || session.ExpiresAt <= DateTime.UtcNow)
        {
            _logger.LogWarning("Refresh attempt rejected: invalid or expired refresh token.");
            throw new AuthenticationException("Invalid or expired refresh token.");
        }

        User? user;
        try
        {
            user = await _repository.GetByIdAsync(session.UserId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Refresh failed for user {UserId}: could not reach the repository.", session.UserId);
            throw;
        }

        if (user is null || user.AccountStatus == "suspended")
        {
            _logger.LogWarning("Refresh attempt rejected for user {UserId}: account missing or suspended.", session.UserId);
            throw new ForbiddenException("This account is no longer able to sign in.");
        }

        try
        {
            await _repository.RevokeSessionAsync(session);
            return await IssueTokensAsync(user);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Refresh failed for user {UserId}: token generation or session creation error.", user.UserId);
            throw;
        }
    }

    public async Task LogoutAsync(LogoutRequestDto request)
    {
        var tokenHash = RefreshTokenHelper.Hash(request.RefreshToken);

        // Idempotent: if the session is already gone or expired, logging out
        // still succeeds — the end state (no active session) is what matters.
        var session = await _repository.GetActiveSessionByTokenHashAsync(tokenHash);
        if (session is not null)
        {
            await _repository.RevokeSessionAsync(session);
        }
    }

    /// UC102 FR102-13/FR102-14 — the signed-out "Forgot password?" entry point.
    ///
    /// Always completes successfully: replying differently for a known and an
    /// unknown address would turn this endpoint into an account-enumeration
    /// oracle. A suspended account is likewise treated as "nothing to send"
    /// (FR102-05).
    public async Task RequestPasswordResetAsync(ForgotPasswordRequestDto request)
    {
        var user = await _repository.GetByEmailAsync(request.Email.Trim());
        if (user is null || user.AccountStatus == "suspended" || user.AccountStatus == "pending_verification")
        {
            _logger.LogInformation(
                "Password reset requested for {Email}: no eligible account, nothing sent.", request.Email);
            return;
        }

        await IssuePasswordResetCodeAsync(user);
    }

    public async Task VerifyPasswordResetCodeAsync(VerifyForgotPasswordCodeRequestDto request)
    {
        var user = await ResolveResettableUserAsync(request.Email);
        var token = await _repository.GetLatestActivePasswordResetTokenByUserIdAsync(user.UserId);

        // FR102-17 / FR102-16: only the latest unused, unexpired code counts.
        if (token is null || RefreshTokenHelper.Hash(request.Code) != token.Token)
        {
            throw new AuthenticationException("Invalid or expired verification code.");
        }
    }

    /// FR102-20/FR102-21 — the code is re-validated here and only marked used
    /// once the new password has actually been stored.
    public async Task ResetPasswordAsync(ResetPasswordRequestDto request)
    {
        var user = await ResolveResettableUserAsync(request.Email);

        var token = await _repository.GetLatestActivePasswordResetTokenByUserIdAsync(user.UserId);
        if (token is null || RefreshTokenHelper.Hash(request.Code) != token.Token)
        {
            throw new AuthenticationException("Invalid or expired verification code.");
        }

        if (PasswordHasher.VerifyPassword(request.NewPassword, user.PasswordHash))
        {
            throw new ValidationException("New password must be different from the current password.");
        }

        user.PasswordHash = PasswordHasher.HashPassword(request.NewPassword);
        user.UpdatedAt = DateTime.UtcNow;
        await _repository.UpdateUserAsync(user);

        await _repository.MarkPasswordResetTokenUsedAsync(token);
        await _repository.InvalidateActivePasswordResetTokensAsync(user.UserId);
    }

    private async Task<User> ResolveResettableUserAsync(string email)
    {
        var user = await _repository.GetByEmailAsync(email.Trim());
        if (user is null)
        {
            // Same message as a wrong code, so this cannot be used to probe
            // which addresses have accounts.
            throw new AuthenticationException("Invalid or expired verification code.");
        }

        if (user.AccountStatus == "suspended")
        {
            throw new ForbiddenException("This account has been suspended.");
        }

        return user;
    }

    private async Task IssuePasswordResetCodeAsync(User user)
    {
        // FR102-15: issuing a new code invalidates any earlier unused one.
        await _repository.InvalidateActivePasswordResetTokensAsync(user.UserId);

        var code = VerificationCodeHelper.Generate();
        var token = new PasswordResetToken
        {
            UserId = user.UserId,
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

    private async Task<LoginResponseDto> IssueTokensAsync(User user)
    {
        var (accessToken, accessTokenExpiresAtUtc) = _tokenGenerator.GenerateToken(user);
        var refreshToken = RefreshTokenHelper.Generate();
        var refreshTokenExpiresAtUtc = DateTime.UtcNow.AddDays(_jwtSettings.RefreshTokenExpiryDays);

        var session = new UserSession
        {
            UserId = user.UserId,
            SessionToken = RefreshTokenHelper.Hash(refreshToken),
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = refreshTokenExpiresAtUtc,
            IsActive = true
        };

        await _repository.CreateSessionAsync(session);

        return new LoginResponseDto
        {
            UserId = user.UserId,
            Username = user.Username,
            Email = user.Email,
            Token = accessToken,
            ExpiresAtUtc = accessTokenExpiresAtUtc,
            RefreshToken = refreshToken
        };
    }

}
