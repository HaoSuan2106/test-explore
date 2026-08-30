using ExploreMy.Api.DTOs.Community;

namespace ExploreMy.Api.Application.Community.ExploreCommunity;

/// <summary>Covers: View Community List, Join Community Group.</summary>
public interface IExploreCommunityService
{
    Task<List<CommunitySummaryDto>> GetJoinedCommunitiesAsync(int userId);

    Task<List<CommunitySummaryDto>> BrowseCommunitiesAsync(BrowseCommunitiesRequestDto request, int userId);

    Task<CommunityDetailDto> GetCommunityDetailAsync(int communityId, int userId);

    Task<JoinCommunityResponseDto> JoinCommunityAsync(int communityId, int userId);

    Task<LeaveCommunityResponseDto> LeaveCommunityAsync(int communityId, int userId);
}
