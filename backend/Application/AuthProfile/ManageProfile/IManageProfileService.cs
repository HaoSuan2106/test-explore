using ExploreMy.Api.DTOs.AuthProfile;

namespace ExploreMy.Api.Application.AuthProfile.ManageProfile;

public interface IManageProfileService
{
    Task<UserProfileDto> GetProfileAsync(int userId);
    Task<UserProfileDto> UpdateProfilePictureAsync(int userId, Stream fileStream, string fileName, string contentType);
    Task<UserProfileDto> RemoveProfilePictureAsync(int userId);
    Task<UserProfileDto> UpdateProfileAsync(int userId, UpdateProfileRequestDto request);
    Task RequestEmailChangeAsync(int userId, RequestEmailChangeRequestDto request);
    Task<UserProfileDto> VerifyEmailChangeAsync(int userId, VerifyEmailChangeRequestDto request);
    Task RequestPasswordResetCodeAsync(int userId);
    Task VerifyPasswordResetCodeAsync(int userId, VerifyPasswordResetCodeRequestDto request);
}