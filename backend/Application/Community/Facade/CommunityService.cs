using ExploreMy.Api.Application.Community.Communication;
using ExploreMy.Api.Application.Community.ExploreCommunity;
using ExploreMy.Api.DTOs.Community;

namespace ExploreMy.Api.Application.Community.Facade;

public class CommunityService : ICommunityService
{
    private readonly IExploreCommunityService _exploreCommunityService;
    private readonly ICommunicationService _communicationService;

    public CommunityService(IExploreCommunityService exploreCommunityService, ICommunicationService communicationService)
    {
        _exploreCommunityService = exploreCommunityService;
        _communicationService = communicationService;
    }

    public Task<List<CommunitySummaryDto>> GetJoinedCommunitiesAsync(int userId) =>
        _exploreCommunityService.GetJoinedCommunitiesAsync(userId);

    public Task<List<CommunitySummaryDto>> BrowseCommunitiesAsync(BrowseCommunitiesRequestDto request, int userId) =>
        _exploreCommunityService.BrowseCommunitiesAsync(request, userId);

    public Task<CommunityDetailDto> GetCommunityDetailAsync(int communityId, int userId) =>
        _exploreCommunityService.GetCommunityDetailAsync(communityId, userId);

    public Task<JoinCommunityResponseDto> JoinCommunityAsync(int communityId, int userId) =>
        _exploreCommunityService.JoinCommunityAsync(communityId, userId);

    public Task<LeaveCommunityResponseDto> LeaveCommunityAsync(int communityId, int userId) =>
        _exploreCommunityService.LeaveCommunityAsync(communityId, userId);

    public Task<List<MessageDto>> GetMessagesAsync(int communityId, int userId, int take, int? beforeMessageId) =>
        _communicationService.GetMessagesAsync(communityId, userId, take, beforeMessageId);

    public Task<MessageDto> SendMessageAsync(SendMessageRequestDto request, int userId) =>
        _communicationService.SendMessageAsync(request, userId);

    public Task<bool> DeleteMessageAsync(int messageId, int userId) =>
        _communicationService.DeleteMessageAsync(messageId, userId);

    public Task<List<MessageDto>> SearchMessagesAsync(SearchMessagesRequestDto request, int userId) =>
        _communicationService.SearchMessagesAsync(request, userId);

    public Task<List<ParticipantDto>> GetParticipantsAsync(int communityId, int userId) =>
        _communicationService.GetParticipantsAsync(communityId, userId);

    public Task<string> UploadMessageImageAsync(int communityId, int userId, Stream fileStream, string fileName, string contentType) =>
        _communicationService.UploadMessageImageAsync(communityId, userId, fileStream, fileName, contentType);

    public Task ReportMessageAsync(int messageId, int userId, string? reason) =>
        _communicationService.ReportMessageAsync(messageId, userId, reason);
}
