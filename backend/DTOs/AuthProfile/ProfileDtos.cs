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
    [RegularExpression(@"^[a-zA-Z0-9_ ]+$",
        ErrorMessage = "Username may only contain letters, numbers, spaces and underscores.")]
    public string Username { get; init; } = string.Empty;

    // City, Age and Gender are optional: the profile can be saved with any of
    // them left blank, and clearing one is how the user removes it. The rules
    // below only constrain a value that was actually supplied — null skips
    // every validation attribute except [Required], which is why none is used.
    [MaxLength(100)]
    public string? City { get; init; }

    [Range(13, 120, ErrorMessage = "Age must be between 13 and 120.")]
    public int? Age { get; init; }

    [MaxLength(30)]
    [RegularExpression("^(Male|Female|Prefer not to say)$",
        ErrorMessage = "Gender must be one of the available options.")]
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

    [Required, RegularExpression(VerificationCodeRules.Pattern,
        ErrorMessage = VerificationCodeRules.ErrorMessage)]
    public string Code { get; init; } = string.Empty;
}

public class VerifyCurrentEmailRequestDto
{
    [Required, RegularExpression(VerificationCodeRules.Pattern,
        ErrorMessage = VerificationCodeRules.ErrorMessage)]
    public string Code { get; init; } = string.Empty;
}

public class VerifyPasswordResetCodeRequestDto
{
    [Required, RegularExpression(VerificationCodeRules.Pattern,
        ErrorMessage = VerificationCodeRules.ErrorMessage)]
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
    [RegularExpression(PasswordPolicy.Pattern, ErrorMessage = PasswordPolicy.ErrorMessage)]
    public string NewPassword { get; init; } = string.Empty;
}

public class ProfileDtos
{
}
