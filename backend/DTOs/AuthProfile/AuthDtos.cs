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
    [RegularExpression(
        PasswordPolicy.Pattern,
        ErrorMessage = PasswordPolicy.ErrorMessage)]
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

    [Required, RegularExpression(VerificationCodeRules.Pattern,
        ErrorMessage = VerificationCodeRules.ErrorMessage)]
    public string Code { get; set; } = string.Empty;
}

public class ResendVerificationRequestDto
{
    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;
}

/// The password policy (UC101 C1): at least 8 characters, with an uppercase
/// letter, a lowercase letter, a number and a special character. Shared by
/// every DTO that accepts a password so the rule cannot drift between the
/// registration, password-change and password-reset endpoints.
public static class PasswordPolicy
{
    public const string Pattern =
        @"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9\s]).{8,}$";

    public const string ErrorMessage =
        "Password must be at least 8 characters and include an uppercase letter, " +
        "a lowercase letter, a number and a symbol.";
}

/// Email/password verification codes are six digits (FR101-10, FR102-14).
public static class VerificationCodeRules
{
    public const string Pattern = @"^\d{6}$";

    public const string ErrorMessage = "The verification code must be 6 digits.";
}

public class ForgotPasswordRequestDto
{
    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;
}

public class VerifyForgotPasswordCodeRequestDto
{
    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required, RegularExpression(VerificationCodeRules.Pattern,
        ErrorMessage = VerificationCodeRules.ErrorMessage)]
    public string Code { get; set; } = string.Empty;
}

public class ResetPasswordRequestDto
{
    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required, RegularExpression(VerificationCodeRules.Pattern,
        ErrorMessage = VerificationCodeRules.ErrorMessage)]
    public string Code { get; set; } = string.Empty;

    [Required, MinLength(8)]
    [RegularExpression(PasswordPolicy.Pattern, ErrorMessage = PasswordPolicy.ErrorMessage)]
    public string NewPassword { get; set; } = string.Empty;
}
