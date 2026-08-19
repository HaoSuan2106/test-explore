using BCrypt.Net;

namespace ExploreMy.Api.Common.Helpers;

public static class PasswordHasher
{
    public static string HashPassword(string plainTextPassword)
    {
        return BCrypt.Net.BCrypt.HashPassword(plainTextPassword);
    }

    public static bool VerifyPassword(string plainTextPassword, string passwordHash)
    {
        return BCrypt.Net.BCrypt.Verify(plainTextPassword, passwordHash);
    }
}