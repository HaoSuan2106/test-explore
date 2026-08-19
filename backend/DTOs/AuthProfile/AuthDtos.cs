using System.ComponentModel.DataAnnotations;

namespace ExploreMy.Api.DTOs.AuthProfile;

public class LoginRequestDto
{
    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    public string Password { get; set; } = string.Empty;
}

public class LoginResponseDto
{
    public int UserId { get; set; }
    public string Username { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Token { get; set; } = string.Empty;
    public DateTime ExpiresAtUtc { get; set; }
    public string RefreshToken { get; set; } = string.Empty;
}

public class RefreshTokenRequestDto
{
    [Required]
    public string RefreshToken { get; set; } = string.Empty;
}

public class LogoutRequestDto
{
    [Required]
    public string RefreshToken { get; set; } = string.Empty;
}

public class RegisterRequestDto
{
    [Required, MinLength(3), MaxLength(30)]
    public string Username { get; set; } = string.Empty;

    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(8)]
    public string Password { get; set; } = string.Empty;
}

public class RegisterResponseDto
{
    public int UserId { get; set; }
    public string Username { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string AccountStatus { get; set; } = string.Empty;
}

public class AuthDtos
{
}

public class VerifyEmailRequestDto
{
    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(4), MaxLength(8)]
    public string Code { get; set; } = string.Empty;
}

public class ResendVerificationRequestDto
{
    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;
}
