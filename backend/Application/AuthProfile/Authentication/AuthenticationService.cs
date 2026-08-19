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
        var existingUser = await _repository.GetByEmailAsync(request.Email);
        if (existingUser is not null)
        {
            if (existingUser.AccountStatus != "pending_verification")
            {
                _logger.LogWarning("Registration attempt failed for {Email}: email already in use.", request.Email);
                throw new ConflictException("Email is already in use.");
            }

            // Account exists but was never verified — resume registration by
            // reissuing a code instead of blocking a legitimate retry.
            await IssueVerificationCodeAsync(existingUser);

            return new RegisterResponseDto
            {
                UserId = existingUser.UserId,
                Username = existingUser.Username,
                Email = existingUser.Email,
                AccountStatus = existingUser.AccountStatus
            };
        }

        if (await _repository.GetByUsernameAsync(request.Username) is not null)
        {
            _logger.LogWarning("Registration attempt failed for {Username}: username already in use.", request.Username);
            throw new ConflictException("Username is already in use.");
        }

        var user = new User
        {
            Username = request.Username,
            Email = request.Email,
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
            _logger.LogError(ex, "Registration failed for {Email}: could not create user.", request.Email);
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
