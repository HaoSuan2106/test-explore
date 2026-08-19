using ExploreMy.Api.DTOs.AuthProfile;

namespace ExploreMy.Api.Application.AuthProfile.Authentication;

public interface IAuthenticationService
{
    Task<RegisterResponseDto> RegisterAsync(RegisterRequestDto request);
    Task<LoginResponseDto> VerifyEmailAsync(VerifyEmailRequestDto request);
    Task ResendVerificationAsync(ResendVerificationRequestDto request);
    Task<LoginResponseDto> LoginAsync(LoginRequestDto request);
    Task<LoginResponseDto> RefreshTokenAsync(RefreshTokenRequestDto request);
    Task LogoutAsync(LogoutRequestDto request);
}
