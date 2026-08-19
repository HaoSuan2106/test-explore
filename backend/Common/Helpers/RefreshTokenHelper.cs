using System.Security.Cryptography;
using System.Text;

namespace ExploreMy.Api.Common.Helpers;

public static class RefreshTokenHelper
{
    public static string Generate()
    {
        var bytes = new byte[64];
        RandomNumberGenerator.Fill(bytes);
        return Convert.ToBase64String(bytes);
    }

    public static string Hash(string refreshToken)
    {
        var hashBytes = SHA256.HashData(Encoding.UTF8.GetBytes(refreshToken));
        return Convert.ToHexString(hashBytes);
    }
}
