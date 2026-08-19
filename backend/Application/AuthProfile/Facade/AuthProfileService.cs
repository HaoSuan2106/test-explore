using ExploreMy.Api.Application.AuthProfile.Authentication;
using ExploreMy.Api.DTOs.AuthProfile;

namespace ExploreMy.Api.Application.AuthProfile.Facade;

public class AuthProfileService : IAuthProfileService
{
    private readonly IAuthenticationService _authenticationService;

    public AuthProfileService(IAuthenticationService authenticationService)
    {
        _authenticationService = authenticationService;
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
}
