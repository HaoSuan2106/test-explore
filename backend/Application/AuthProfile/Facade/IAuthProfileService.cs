using ExploreMy.Api.DTOs.AuthProfile;

namespace ExploreMy.Api.Application.AuthProfile.Facade;

public interface IAuthProfileService
{
    Task<RegisterResponseDto> RegisterAsync(RegisterRequestDto request);
    Task<LoginResponseDto> VerifyEmailAsync(VerifyEmailRequestDto request);
    Task ResendVerificationAsync(ResendVerificationRequestDto request);
    Task<LoginResponseDto> LoginAsync(LoginRequestDto request);
    Task<LoginResponseDto> RefreshTokenAsync(RefreshTokenRequestDto request);
    Task LogoutAsync(LogoutRequestDto request);
}
