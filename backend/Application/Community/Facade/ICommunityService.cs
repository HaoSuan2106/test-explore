using ExploreMy.Api.DTOs.Community;

namespace ExploreMy.Api.Application.Community.Facade;

/// <summary>
/// Single entry point the controller talks to for the whole Communication
/// module — delegates to IExploreCommunityService (list/browse/join/leave)
/// and ICommunicationService (messages/participants/media) underneath.
/// </summary>
public interface ICommunityService
{
    Task<List<CommunitySummaryDto>> GetJoinedCommunitiesAsync(int userId);
    Task<List<CommunitySummaryDto>> BrowseCommunitiesAsync(BrowseCommunitiesRequestDto request, int userId);
    Task<CommunityDetailDto> GetCommunityDetailAsync(int communityId, int userId);
    Task<JoinCommunityResponseDto> JoinCommunityAsync(int communityId, int userId);
    Task<LeaveCommunityResponseDto> LeaveCommunityAsync(int communityId, int userId);

    Task<List<MessageDto>> GetMessagesAsync(int communityId, int userId, int take, int? beforeMessageId);
    Task<MessageDto> SendMessageAsync(SendMessageRequestDto request, int userId);
    Task<bool> DeleteMessageAsync(int messageId, int userId);
    Task<List<MessageDto>> SearchMessagesAsync(SearchMessagesRequestDto request, int userId);
    Task<List<ParticipantDto>> GetParticipantsAsync(int communityId, int userId);
    Task<string> UploadMessageImageAsync(int communityId, int userId, Stream fileStream, string fileName, string contentType);
    Task ReportMessageAsync(int messageId, int userId, string? reason);
}
