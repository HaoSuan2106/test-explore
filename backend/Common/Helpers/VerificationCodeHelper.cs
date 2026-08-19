using System.Security.Cryptography;

namespace ExploreMy.Api.Common.Helpers;

public static class VerificationCodeHelper
{
    public static string Generate()
    {
        return RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
    }
}