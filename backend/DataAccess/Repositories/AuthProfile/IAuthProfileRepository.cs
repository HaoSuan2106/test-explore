using ExploreMy.Api.Domain.Entities;

namespace ExploreMy.Api.DataAccess.Repositories.AuthProfile;

public interface IAuthProfileRepository
{
    Task<User?> GetByEmailAsync(string email);
    Task<User?> GetByUsernameAsync(string username);
    Task<User?> GetByIdAsync(int userId);
    Task CreateUserAsync(User user);
    Task UpdateUserAsync(User user);
    Task CreateSessionAsync(UserSession session);
    Task<UserSession?> GetActiveSessionByTokenHashAsync(string tokenHash);
    Task RevokeSessionAsync(UserSession session);
    Task CreateEmailVerificationTokenAsync(EmailVerificationToken token);
    Task<EmailVerificationToken?> GetLatestActiveTokenByUserIdAsync(int userId);
    Task InvalidateActiveTokensAsync(int userId);
    Task MarkTokenUsedAsync(EmailVerificationToken token);
}
