using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.DataAccess.Repositories.AuthProfile;
using ExploreMy.Api.DataAccess.Repositories.Community;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.Community;
using CommunityEntity = ExploreMy.Api.Domain.Entities.Community;

namespace ExploreMy.Api.Application.Community.ExploreCommunity;

/// <summary>
/// "Community Chat" screen: the Explore (joined) / Browse (discoverable) tabs,
/// and joining/leaving a community group.
/// </summary>
public class ExploreCommunityService : IExploreCommunityService
{
    private readonly ICommunityRepository _communityRepository;
    private readonly IAuthProfileRepository _authProfileRepository;
    private readonly ILogger<ExploreCommunityService> _logger;

    public ExploreCommunityService(
        ICommunityRepository communityRepository,
        IAuthProfileRepository authProfileRepository,
        ILogger<ExploreCommunityService> logger)
    {
        _communityRepository = communityRepository;
        _authProfileRepository = authProfileRepository;
        _logger = logger;
    }

    public async Task<List<CommunitySummaryDto>> GetJoinedCommunitiesAsync(int userId)
    {
        var communities = await _communityRepository.GetJoinedCommunitiesAsync(userId);
        var dtos = new List<CommunitySummaryDto>(communities.Count);
        foreach (var community in communities)
        {
            dtos.Add(await ToSummaryDtoAsync(community, userId));
        }
        return dtos;
    }

    public async Task<List<CommunitySummaryDto>> BrowseCommunitiesAsync(BrowseCommunitiesRequestDto request, int userId)
    {
        var communities = await _communityRepository.SearchCommunitiesAsync(request.Keyword, request.State);
        var dtos = new List<CommunitySummaryDto>(communities.Count);
        foreach (var community in communities)
        {
            dtos.Add(await ToSummaryDtoAsync(community, userId));
        }
        return dtos;
    }

    public async Task<CommunityDetailDto> GetCommunityDetailAsync(int communityId, int userId)
    {
        var community = await _communityRepository.GetCommunityByIdAsync(communityId)
            ?? throw new NotFoundException("Community not found.");

        var summary = await ToSummaryDtoAsync(community, userId);
        var recentMessages = await _communityRepository.GetRecentMessagesAsync(communityId, take: 10, beforeMessageId: null);
        var messageDtos = await MapMessagesAsync(recentMessages);

        return new CommunityDetailDto
        {
            CommunityId = summary.CommunityId,
            Name = summary.Name,
            Description = summary.Description,
            Area = summary.Area,
            State = summary.State,
            ImageUrl = summary.ImageUrl,
            MemberCount = summary.MemberCount,
            IsJoined = summary.IsJoined,
            LastMessagePreview = summary.LastMessagePreview,
            LastMessageAt = summary.LastMessageAt,
            LatestMessages = messageDtos,
        };
    }

    public async Task<JoinCommunityResponseDto> JoinCommunityAsync(int communityId, int userId)
    {
        var community = await _communityRepository.GetCommunityByIdAsync(communityId)
            ?? throw new NotFoundException("Community not found.");

        var existing = await _communityRepository.GetMembershipAsync(communityId, userId);
        if (existing is { IsActive: true })
        {
            return new JoinCommunityResponseDto { CommunityId = communityId, Success = true, Message = "Already joined." };
        }

        if (existing != null)
        {
            // Rejoining after a previous leave — reactivate the existing row (it already
            // has a real primary key) rather than routing it through AddMemberAsync, which
            // would try to INSERT it again and collide on that key.
            await _communityRepository.ReactivateMemberAsync(existing);
        }
        else
        {
            await _communityRepository.AddMemberAsync(new CommunityMember
            {
                CommunityId = communityId,
                UserId = userId,
                Role = "Member",
                IsActive = true,
                JoinedAt = DateTime.UtcNow,
            });
        }

        _logger.LogInformation("User {UserId} joined community {CommunityId}.", userId, communityId);
        return new JoinCommunityResponseDto { CommunityId = communityId, Success = true, Message = "Community Joined Successfully" };
    }

    public async Task<LeaveCommunityResponseDto> LeaveCommunityAsync(int communityId, int userId)
    {
        var membership = await _communityRepository.GetMembershipAsync(communityId, userId)
            ?? throw new NotFoundException("You are not a member of this community.");

        await _communityRepository.RemoveMemberAsync(membership);
        _logger.LogInformation("User {UserId} left community {CommunityId}.", userId, communityId);
        return new LeaveCommunityResponseDto { CommunityId = communityId, Success = true, Message = "Left the community." };
    }

    private async Task<CommunitySummaryDto> ToSummaryDtoAsync(CommunityEntity community, int userId)
    {
        var memberCount = await _communityRepository.GetMemberCountAsync(community.CommunityId);
        var membership = await _communityRepository.GetMembershipAsync(community.CommunityId, userId);
        var lastMessage = await _communityRepository.GetLastMessageAsync(community.CommunityId);

        return new CommunitySummaryDto
        {
            CommunityId = community.CommunityId,
            Name = community.Name,
            Description = community.Description,
            Area = community.Area,
            State = community.State,
            ImageUrl = community.ImageUrl,
            MemberCount = memberCount,
            IsJoined = membership is { IsActive: true },
            LastMessagePreview = lastMessage?.Content,
            LastMessageAt = lastMessage?.SentAt,
        };
    }

    private async Task<List<MessageDto>> MapMessagesAsync(List<Message> messages)
    {
        if (messages.Count == 0) return new List<MessageDto>();

        var attachments = await _communityRepository.GetAttachmentsForMessagesAsync(messages.Select(m => m.MessageId));
        var attachmentsByMessage = attachments.GroupBy(a => a.MessageId).ToDictionary(g => g.Key, g => g.ToList());

        var dtos = new List<MessageDto>(messages.Count);
        foreach (var message in messages)
        {
            var sender = await _authProfileRepository.GetByIdAsync(message.SenderUserId);
            dtos.Add(new MessageDto
            {
                MessageId = message.MessageId,
                CommunityId = message.CommunityId,
                SenderUserId = message.SenderUserId,
                SenderUsername = sender?.Username ?? "Unknown User",
                SenderProfilePictureUrl = sender?.ProfilePictureUrl,
                Content = message.Content,
                SentAt = message.SentAt,
                ReplyToMessageId = message.ReplyToMessageId,
                Attachments = attachmentsByMessage.TryGetValue(message.MessageId, out var list)
                    ? list.Select(a => new MessageAttachmentDto
                    {
                        AttachmentId = a.AttachmentId,
                        Type = a.Type,
                        MediaUrl = a.MediaUrl,
                        PlaceId = a.PlaceId,
                        PlaceName = a.PlaceName,
                        PlaceAddress = a.PlaceAddress,
                        PlaceImageUrl = a.PlaceImageUrl,
                        PlaceStatus = a.PlaceStatus,
                        PlaceLatitude = a.PlaceLatitude,
                        PlaceLongitude = a.PlaceLongitude,
                        PlacePrimaryType = a.PlacePrimaryType,
                        IsCommunityPlace = a.IsCommunityPlace,
                    }).ToList()
                    : new List<MessageAttachmentDto>(),
            });
        }
        return dtos;
    }
}
