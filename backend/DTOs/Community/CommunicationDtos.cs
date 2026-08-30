using System.ComponentModel.DataAnnotations;

namespace ExploreMy.Api.DTOs.Community;

public class CommunitySummaryDto
{
    public int CommunityId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Area { get; set; }
    public string? State { get; set; }
    public string? ImageUrl { get; set; }
    public int MemberCount { get; set; }
    public bool IsJoined { get; set; }
    public string? LastMessagePreview { get; set; }
    public DateTime? LastMessageAt { get; set; }
}

public class CommunityDetailDto : CommunitySummaryDto
{
    public List<MessageDto> LatestMessages { get; set; } = new();
}

public class BrowseCommunitiesRequestDto
{
    public string? Keyword { get; set; }
    /// Optional exact-match filter on Community.State (e.g. "Selangor"). Null/empty means all states.
    public string? State { get; set; }
}

public class JoinCommunityRequestDto
{
    [Required]
    public int CommunityId { get; set; }
}

public class JoinCommunityResponseDto
{
    public int CommunityId { get; set; }
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
}

public class LeaveCommunityResponseDto
{
    public int CommunityId { get; set; }
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
}

public class ParticipantDto
{
    public int UserId { get; set; }
    public string Username { get; set; } = string.Empty;
    public string? ProfilePictureUrl { get; set; }
    public string Role { get; set; } = "Member";
    public DateTime JoinedAt { get; set; }
}

public class MessageAttachmentDto
{
    public int AttachmentId { get; set; }
    public string Type { get; set; } = string.Empty; // "Image" | "PlaceShare" | "PostShare"
    public string? MediaUrl { get; set; }
    public string? PlaceId { get; set; }
    public string? PlaceSource { get; set; } // "GOOGLE" | "COMMUNITY"
    public string? ShareDataJson { get; set; }
    public string? PlaceName { get; set; }
    public string? PlaceAddress { get; set; }
    public string? PlaceImageUrl { get; set; }
    public string? PlaceStatus { get; set; }
    public string? PostId { get; set; }
}

public class MessageDto
{
    public int MessageId { get; set; }
    public int CommunityId { get; set; }
    public int SenderUserId { get; set; }
    public string SenderUsername { get; set; } = string.Empty;
    public string? SenderProfilePictureUrl { get; set; }
    public string? Content { get; set; }
    public DateTime SentAt { get; set; }
    public int? ReplyToMessageId { get; set; }
    public MessageDto? ReplyToPreview { get; set; }
    public List<MessageAttachmentDto> Attachments { get; set; } = new();
}

public class SharedPlaceDto
{
    [Required]
    public string PlaceId { get; set; } = string.Empty;
    /// "GOOGLE" | "COMMUNITY" — which detail screen a tap on this message should reopen.
    [Required]
    public string PlaceSource { get; set; } = string.Empty;
    /// Snapshot of the place (PlaceData, JSON-encoded) taken at share time. Required when
    /// PlaceSource is "GOOGLE" (no live "fetch by id" route exists for Google-sourced places);
    /// left null for "COMMUNITY", which reopens live instead.
    public string? ShareDataJson { get; set; }
    public string PlaceName { get; set; } = string.Empty;
    public string? PlaceAddress { get; set; }
    public string? PlaceImageUrl { get; set; }
    public string? PlaceStatus { get; set; }
}

public class SharedPostDto
{
    [Required]
    public string PostId { get; set; } = string.Empty;
    public string PostTitle { get; set; } = string.Empty;
    public string? PostImageUrl { get; set; }
    public string? PostLocation { get; set; }
}

public class SendMessageRequestDto
{
    [Required]
    public int CommunityId { get; set; }

    [MaxLength(2000)]
    public string? Content { get; set; }

    public int? ReplyToMessageId { get; set; }

    /// Image URLs already uploaded via POST /api/community/{id}/media.
    public List<string>? ImageUrls { get; set; }

    public List<SharedPlaceDto>? SharedPlaces { get; set; }

    /// Posts shared into the chat via Post Feed/Post Details' "Share to Chat" action.
    public List<SharedPostDto>? SharedPosts { get; set; }
}

public class SearchMessagesRequestDto
{
    [Required]
    public int CommunityId { get; set; }

    [Required]
    public string Keyword { get; set; } = string.Empty;
}

public class ReportMessageRequestDto
{
    [MaxLength(500)]
    public string? Reason { get; set; }
}
