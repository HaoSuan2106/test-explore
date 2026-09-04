using ExploreMy.Api.DTOs.AuthProfile;

namespace ExploreMy.Api.Application.AuthProfile.Facade;

/// <summary>
/// Facade that coordinates the two AuthProfile feature services
/// (Authentication, ManageProfile).
/// </summary>
public interface IAuthProfileService
{
    // Authentication
    Task<RegisterResponseDto> RegisterAsync(RegisterRequestDto request);
    Task<LoginResponseDto> VerifyEmailAsync(VerifyEmailRequestDto request);
    Task ResendVerificationAsync(ResendVerificationRequestDto request);
    Task<LoginResponseDto> LoginAsync(LoginRequestDto request);
    Task<LoginResponseDto> RefreshTokenAsync(RefreshTokenRequestDto request);
    Task LogoutAsync(LogoutRequestDto request);
    Task RequestPasswordResetAsync(ForgotPasswordRequestDto request);
    Task VerifyPasswordResetCodeAsync(VerifyForgotPasswordCodeRequestDto request);
    Task ResetPasswordAsync(ResetPasswordRequestDto request);

    // ManageProfile
    Task<UserProfileDto> GetProfileAsync(int userId);
    Task<UserProfileDto> UpdateProfilePictureAsync(int userId, Stream fileStream, string fileName, string contentType);
    Task<UserProfileDto> RemoveProfilePictureAsync(int userId);
    Task<UserProfileDto> UpdateProfileAsync(int userId, UpdateProfileRequestDto request);
    Task RequestCurrentEmailVerificationAsync(int userId);
    Task VerifyCurrentEmailVerificationAsync(int userId, VerifyCurrentEmailRequestDto request);
    Task RequestEmailChangeAsync(int userId, RequestEmailChangeRequestDto request);
    Task<UserProfileDto> VerifyEmailChangeAsync(int userId, VerifyEmailChangeRequestDto request);
    Task CancelEmailChangeAsync(int userId);
    Task RequestPasswordResetCodeAsync(int userId);
    Task VerifyPasswordResetCodeAsync(int userId, VerifyPasswordResetCodeRequestDto request);
    Task VerifyCurrentPasswordAsync(int userId, CheckPasswordRequestDto request);
    Task UpdatePasswordAsync(int userId, UpdatePasswordRequestDto request);
}
