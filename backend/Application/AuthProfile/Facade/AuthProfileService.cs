using ExploreMy.Api.Application.AuthProfile.Authentication;
using ExploreMy.Api.Application.AuthProfile.ManageProfile;
using ExploreMy.Api.DTOs.AuthProfile;

namespace ExploreMy.Api.Application.AuthProfile.Facade;

/// <summary>
/// Facade that coordinates the two AuthProfile feature services
/// (Authentication, ManageProfile).
/// </summary>
public class AuthProfileService : IAuthProfileService
{
    private readonly IAuthenticationService _authenticationService;
    private readonly IManageProfileService _manageProfileService;

    public AuthProfileService(
        IAuthenticationService authenticationService,
        IManageProfileService manageProfileService)
    {
        _authenticationService = authenticationService;
        _manageProfileService = manageProfileService;
    }

    public Task<LoginResponseDto> LoginAsync(LoginRequestDto request)
    {
        return _authenticationService.LoginAsync(request);
    }

    public Task<LoginResponseDto> VerifyEmailAsync(VerifyEmailRequestDto request)
    {
        return _authenticationService.VerifyEmailAsync(request);
    }

    public Task ResendVerificationAsync(ResendVerificationRequestDto request)
    {
        return _authenticationService.ResendVerificationAsync(request);
    }

    public Task<LoginResponseDto> RefreshTokenAsync(RefreshTokenRequestDto request)
    {
        return _authenticationService.RefreshTokenAsync(request);
    }

    public Task LogoutAsync(LogoutRequestDto request)
    {
        return _authenticationService.LogoutAsync(request);
    }

    public Task<RegisterResponseDto> RegisterAsync(RegisterRequestDto request)
    {
        return _authenticationService.RegisterAsync(request);
    }

    public Task RequestPasswordResetAsync(ForgotPasswordRequestDto request)
    {
        return _authenticationService.RequestPasswordResetAsync(request);
    }

    public Task VerifyPasswordResetCodeAsync(VerifyForgotPasswordCodeRequestDto request)
    {
        return _authenticationService.VerifyPasswordResetCodeAsync(request);
    }

    public Task ResetPasswordAsync(ResetPasswordRequestDto request)
    {
        return _authenticationService.ResetPasswordAsync(request);
    }

    public Task<UserProfileDto> GetProfileAsync(int userId)
    {
        return _manageProfileService.GetProfileAsync(userId);
    }

    public Task<UserProfileDto> UpdateProfilePictureAsync(int userId, Stream fileStream, string fileName, string contentType)
    {
        return _manageProfileService.UpdateProfilePictureAsync(userId, fileStream, fileName, contentType);
    }

    public Task<UserProfileDto> RemoveProfilePictureAsync(int userId)
    {
        return _manageProfileService.RemoveProfilePictureAsync(userId);
    }

    public Task<UserProfileDto> UpdateProfileAsync(int userId, UpdateProfileRequestDto request)
    {
        return _manageProfileService.UpdateProfileAsync(userId, request);
    }

    public Task RequestCurrentEmailVerificationAsync(int userId)
    {
        return _manageProfileService.RequestCurrentEmailVerificationAsync(userId);
    }

    public Task VerifyCurrentEmailVerificationAsync(int userId, VerifyCurrentEmailRequestDto request)
    {
        return _manageProfileService.VerifyCurrentEmailVerificationAsync(userId, request);
    }

    public Task RequestEmailChangeAsync(int userId, RequestEmailChangeRequestDto request)
    {
        return _manageProfileService.RequestEmailChangeAsync(userId, request);
    }

    public Task<UserProfileDto> VerifyEmailChangeAsync(int userId, VerifyEmailChangeRequestDto request)
    {
        return _manageProfileService.VerifyEmailChangeAsync(userId, request);
    }

    public Task CancelEmailChangeAsync(int userId)
    {
        return _manageProfileService.CancelEmailChangeAsync(userId);
    }

    public Task RequestPasswordResetCodeAsync(int userId)
    {
        return _manageProfileService.RequestPasswordResetCodeAsync(userId);
    }

    public Task VerifyPasswordResetCodeAsync(int userId, VerifyPasswordResetCodeRequestDto request)
    {
        return _manageProfileService.VerifyPasswordResetCodeAsync(userId, request);
    }

    public Task VerifyCurrentPasswordAsync(int userId, CheckPasswordRequestDto request)
    {
        return _manageProfileService.VerifyCurrentPasswordAsync(userId, request);
    }

    public Task UpdatePasswordAsync(int userId, UpdatePasswordRequestDto request)
    {
        return _manageProfileService.UpdatePasswordAsync(userId, request);
    }
}
