using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace ExploreMy.Api.Hubs;

/// <summary>
/// Real-time transport for Send/Receive Messages. REST endpoints on
/// CommunityController do the actual persistence and broadcast through this
/// hub's group (`community-{id}`) via IHubContext — clients only use this hub
/// directly to join/leave the group and to relay typing indicators.
/// </summary>
[Authorize]
public class CommunityChatHub : Hub
{
    private int CurrentUserId => int.Parse(Context.User!.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private static string GroupName(int communityId) => $"community-{communityId}";

    public async Task JoinCommunityGroup(int communityId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, GroupName(communityId));
        await Clients.OthersInGroup(GroupName(communityId))
            .SendAsync("ParticipantOnlineStatusChanged", communityId, CurrentUserId, true);
    }

    public async Task LeaveCommunityGroup(int communityId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, GroupName(communityId));
        await Clients.OthersInGroup(GroupName(communityId))
            .SendAsync("ParticipantOnlineStatusChanged", communityId, CurrentUserId, false);
    }

    public async Task NotifyTyping(int communityId, bool isTyping)
    {
        await Clients.OthersInGroup(GroupName(communityId)).SendAsync("TypingChanged", communityId, CurrentUserId, isTyping);
    }
}
