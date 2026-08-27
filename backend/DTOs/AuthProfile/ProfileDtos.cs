using System.ComponentModel.DataAnnotations;

namespace ExploreMy.Api.DTOs.AuthProfile;

public class UserProfileDto
{
    public int UserId { get; init; }
    public string Username { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public string? City { get; init; }
    public int? Age { get; init; }
    public string? Gender { get; init; }
    public string? ProfilePictureUrl { get; init; }
}

public class UserProfileSummaryDto
{
    public int UserId { get; init; }
    public string Username { get; init; } = string.Empty;
    public string? City { get; init; }
    public string? ProfilePictureUrl { get; init; }
}

public class UpdateProfileRequestDto
{
    [Required, MinLength(3), MaxLength(30)]
    public string Username { get; init; } = string.Empty;

    [MaxLength(100)]
    public string? City { get; init; }

    [Range(1, 120)]
    public int? Age { get; init; }

    [MaxLength(30)]
    public string? Gender { get; init; }
}

public class RequestEmailChangeRequestDto
{
    [Required, EmailAddress]
    public string NewEmail { get; init; } = string.Empty;
}

public class VerifyEmailChangeRequestDto
{
    [Required, EmailAddress]
    public string NewEmail { get; init; } = string.Empty;

    [Required, MinLength(4), MaxLength(8)]
    public string Code { get; init; } = string.Empty;
}

public class VerifyCurrentEmailRequestDto
{
    [Required, MinLength(4), MaxLength(8)]
    public string Code { get; init; } = string.Empty;
}

public class VerifyPasswordResetCodeRequestDto
{
    [Required, MinLength(4), MaxLength(8)]
    public string Code { get; init; } = string.Empty;
}

public class CheckPasswordRequestDto
{
    [Required]
    public string CurrentPassword { get; init; } = string.Empty;
}

public class UpdatePasswordRequestDto
{
    public string? CurrentPassword { get; init; }

    public string? ResetCode { get; init; }

    [Required, MinLength(8)]
    [RegularExpression(
        @"^(?=.*\d)(?=.*[^A-Za-z0-9\s]).{8,}$",
        ErrorMessage = "Password must be at least 8 characters and include a number and a symbol.")]
    public string NewPassword { get; init; } = string.Empty;
}

public class ProfileDtos
{
}
