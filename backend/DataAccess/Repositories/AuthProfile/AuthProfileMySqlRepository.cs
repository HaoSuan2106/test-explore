using Microsoft.EntityFrameworkCore;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.Persistence.DbContext;

namespace ExploreMy.Api.DataAccess.Repositories.AuthProfile;

public class AuthProfileMySqlRepository : IAuthProfileRepository
{
    private readonly MySqlDbContext _context;
    private readonly ILogger<AuthProfileMySqlRepository> _logger;

    public AuthProfileMySqlRepository(MySqlDbContext context, ILogger<AuthProfileMySqlRepository> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<User?> GetByEmailAsync(string email)
    {
        try
        {
            return await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while looking up user by email {Email}.", email);
            throw;
        }
    }

    public async Task<User?> GetByIdAsync(int userId)
    {
        try
        {
            return await _context.Users.FirstOrDefaultAsync(u => u.UserId == userId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while looking up user by id {UserId}.", userId);
            throw;
        }
    }

    public async Task CreateSessionAsync(UserSession session)
    {
        try
        {
            _context.UserSessions.Add(session);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while creating session for user {UserId}.", session.UserId);
            throw;
        }
    }

    public async Task<UserSession?> GetActiveSessionByTokenHashAsync(string tokenHash)
    {
        try
        {
            return await _context.UserSessions
                .FirstOrDefaultAsync(s => s.SessionToken == tokenHash && s.IsActive);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while looking up session by token hash.");
            throw;
        }
    }

    public async Task RevokeSessionAsync(UserSession session)
    {
        try
        {
            session.IsActive = false;
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while revoking session {SessionId}.", session.SessionId);
            throw;
        }
    }

    public async Task<User?> GetByUsernameAsync(string username)
    {
        try
        {
            return await _context.Users.FirstOrDefaultAsync(u => u.Username == username);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while looking up user by username {Username}.", username);
            throw;
        }
    }

    public async Task CreateUserAsync(User user)
    {
        try
        {
            _context.Users.Add(user);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while creating user {Email}.", user.Email);
            throw;
        }
    }

    public async Task UpdateUserAsync(User user)
    {
        try
        {
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while updating user {UserId}.", user.UserId);
            throw;
        }
    }

    public async Task CreateEmailVerificationTokenAsync(EmailVerificationToken token)
    {
        try
        {
            _context.EmailVerificationTokens.Add(token);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while creating verification token for user {UserId}.", token.UserId);
            throw;
        }
    }

    public async Task<EmailVerificationToken?> GetLatestActiveTokenByUserIdAsync(int userId)
    {
        try
        {
            return await _context.EmailVerificationTokens
                .Where(t => t.UserId == userId && !t.IsUsed && t.ExpiresAt > DateTime.UtcNow)
                .OrderByDescending(t => t.CreatedAt)
                .FirstOrDefaultAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while looking up verification token for user {UserId}.", userId);
            throw;
        }
    }

    public async Task<EmailVerificationToken?> GetLatestVerifiedCurrentEmailTokenAsync(int userId)
    {
        try
        {
            return await _context.EmailVerificationTokens
                .Where(t => t.UserId == userId && t.PendingEmail == null && t.IsUsed && t.ExpiresAt > DateTime.UtcNow)
                .OrderByDescending(t => t.CreatedAt)
                .FirstOrDefaultAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while looking up current-email verification for user {UserId}.", userId);
            throw;
        }
    }

    public async Task InvalidateActiveTokensAsync(int userId)
    {
        try
        {
            var activeTokens = await _context.EmailVerificationTokens
                .Where(t => t.UserId == userId && !t.IsUsed)
                .ToListAsync();

            foreach (var token in activeTokens)
            {
                token.IsUsed = true;
            }

            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while invalidating verification tokens for user {UserId}.", userId);
            throw;
        }
    }

    public async Task MarkTokenUsedAsync(EmailVerificationToken token)
    {
        try
        {
            token.IsUsed = true;
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while marking verification token {TokenId} used.", token.TokenId);
            throw;
        }
    }

    public async Task CreatePasswordResetTokenAsync(PasswordResetToken token)
    {
        try
        {
            _context.PasswordResetTokens.Add(token);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while creating password reset token for user {UserId}.", token.UserId);
            throw;
        }
    }

    public async Task<PasswordResetToken?> GetLatestActivePasswordResetTokenByUserIdAsync(int userId)
    {
        try
        {
            return await _context.PasswordResetTokens
                .Where(t => t.UserId == userId && !t.IsUsed && t.ExpiresAt > DateTime.UtcNow)
                .OrderByDescending(t => t.CreatedAt)
                .FirstOrDefaultAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while looking up password reset token for user {UserId}.", userId);
            throw;
        }
    }

    public async Task InvalidateActivePasswordResetTokensAsync(int userId)
    {
        try
        {
            var activeTokens = await _context.PasswordResetTokens
                .Where(t => t.UserId == userId && !t.IsUsed)
                .ToListAsync();

            foreach (var token in activeTokens)
            {
                token.IsUsed = true;
            }

            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while invalidating password reset tokens for user {UserId}.", userId);
            throw;
        }
    }

    public async Task MarkPasswordResetTokenUsedAsync(PasswordResetToken token)
    {
        try
        {
            token.IsUsed = true;
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while marking password reset token {TokenId} used.", token.TokenId);
            throw;
        }
    }

}
