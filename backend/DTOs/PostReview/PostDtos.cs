using System.ComponentModel.DataAnnotations;

namespace ExploreMy.Api.DTOs.PostReview;

// ============================================================
// Community Post — request DTOs
// ============================================================

public class CreatePostRequestDto
{
    [Required]
    public string TaggedPlaceId { get; set; } = string.Empty;

    [Required, MaxLength(100)]
    public string Title { get; set; } = string.Empty;

    [Required, MaxLength(2000)]
    public string Description { get; set; } = string.Empty;

    [MaxLength(5)]
    public List<PostImageRequestDto> Images { get; set; } = new();
}

public class UpdatePostRequestDto
{
    [Required, MaxLength(100)]
    public string Title { get; set; } = string.Empty;

    [Required, MaxLength(2000)]
    public string Description { get; set; } = string.Empty;

    [MaxLength(5)]
    public List<PostImageRequestDto> Images { get; set; } = new();
}

/// <summary>Either an existing image URL (kept) or a newly uploaded image id.</summary>
public class PostImageRequestDto
{
    [Required]
    public string ImageUrl { get; set; } = string.Empty;

    [Range(1, 5)]
    public short DisplayOrder { get; set; } = 1;
}

// ============================================================
// Community Post — response DTOs
// ============================================================

public class PostSummaryDto
{
    public string PostId { get; init; } = string.Empty;
    public string AuthorId { get; init; } = string.Empty;
    public string AuthorName { get; init; } = string.Empty;
    public string? AuthorAvatarUrl { get; init; }
    public string TaggedPlaceId { get; init; } = string.Empty;
    public string TaggedPlaceName { get; init; } = string.Empty;
    public string TaggedPlaceAddress { get; init; } = string.Empty;
    public string? Title { get; init; }
    public string Description { get; init; } = string.Empty;
    public List<string> ImageUrls { get; init; } = new();
    public int ReactionCount { get; init; }
    public int CommentCount { get; init; }
    public int ReportCount { get; init; }
    public bool IsReactedByCurrentUser { get; init; }
    public bool IsReportedByCurrentUser { get; init; }
    public bool IsSavedByCurrentUser { get; init; }
    public int ViewsCount { get; init; }
    public string Status { get; init; } = string.Empty;
    public DateTime CreatedAt { get; init; }
    public DateTime UpdatedAt { get; init; }
}

public class PostDetailsDto : PostSummaryDto
{
    public List<PostCommentDto> Comments { get; init; } = new();
    public List<PostReportDto> Reports { get; init; } = new();
}

public class PostCommentDto
{
    public string CommentId { get; init; } = string.Empty;
    public string PostId { get; init; } = string.Empty;
    public string PostTitle { get; init; } = string.Empty;
    public string AuthorId { get; init; } = string.Empty;
    public string AuthorName { get; init; } = string.Empty;
    public string? AuthorAvatarUrl { get; init; }
    public string Content { get; init; } = string.Empty;
    public int LikesCount { get; init; }
    public DateTime CreatedAt { get; init; }
    public DateTime UpdatedAt { get; init; }
}

public class PostReportDto
{
    public string ReportId { get; init; } = string.Empty;
    public string PostId { get; init; } = string.Empty;
    public string ReporterId { get; init; } = string.Empty;
    public string Reason { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty;
    public DateTime CreatedAt { get; init; }
    public DateTime? WithdrawnAt { get; init; }
    // Reported-post preview fields (populated from the report's Post navigation)
    public string PostTitle { get; init; } = string.Empty;
    public string PostedBy { get; init; } = string.Empty;
    public string TaggedPlaceName { get; init; } = string.Empty;
    public string PostDescription { get; init; } = string.Empty;
    public string PostImageUrl { get; init; } = string.Empty;
    public int ReactionCount { get; init; }
    public int CommentCount { get; init; }
}

public class CreatePostResponseDto
{
    public string PostId { get; init; } = string.Empty;
    public string Message { get; init; } = string.Empty;
}

public class UpdatePostResponseDto
{
    public PostSummaryDto Post { get; init; } = null!;
    public string Message { get; init; } = string.Empty;
}

public class DeletePostResponseDto
{
    public string PostId { get; init; } = string.Empty;
    public string Message { get; init; } = string.Empty;
}

// ============================================================
// Saved posts — request / response
// ============================================================

public class SavePostResponseDto
{
    public string PostId { get; init; } = string.Empty;
    public bool IsSaved { get; init; }
    public string Message { get; init; } = string.Empty;
}

// ============================================================
// Comments — request / response
// ============================================================

public class CreateCommentRequestDto
{
    [Required, MaxLength(100)]
    public string Content { get; set; } = string.Empty;
}

public class UpdateCommentRequestDto
{
    [Required, MaxLength(100)]
    public string Content { get; set; } = string.Empty;
}

public class CreateCommentResponseDto
{
    public PostCommentDto Comment { get; init; } = null!;
    public string Message { get; init; } = string.Empty;
}

public class UpdateCommentResponseDto
{
    public PostCommentDto Comment { get; init; } = null!;
    public string Message { get; init; } = string.Empty;
}

public class DeleteCommentResponseDto
{
    public string CommentId { get; init; } = string.Empty;
    public string Message { get; init; } = string.Empty;
}

// ============================================================
// Reactions — request / response
// ============================================================

public class ToggleReactionRequestDto
{
    /// <summary>Reaction type; currently only "LIKE" (Love) is supported.</summary>
    [Required]
    public string ReactionType { get; set; } = "LIKE";
}

public class ToggleReactionResponseDto
{
    public string PostId { get; init; } = string.Empty;
    public string ReactionType { get; init; } = string.Empty;
    public bool IsReacted { get; init; }
    public int ReactionCount { get; init; }
}

// ============================================================
// Reports — request / response
// ============================================================

public class CreateReportRequestDto
{
    [Required, MaxLength(100)]
    public string Reason { get; set; } = string.Empty;
}

public class CreateReportResponseDto
{
    public string ReportId { get; init; } = string.Empty;
    public string PostId { get; init; } = string.Empty;
    public int ReportCount { get; init; }
    public string Message { get; init; } = string.Empty;
}

// ============================================================
// Visited attractions (derived from the user's real FootTracker
// visits via IFootTrackerService.GetVisitsAsync → List<VisitLogDto>).
// The JSON shape is unchanged from the previous eligible-attractions
// contract so the Post module API remains stable.
// ============================================================

public class VisitedAttractionDto
{
    public string PlaceId { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string Address { get; init; } = string.Empty;
    public string Category { get; init; } = string.Empty;
    public string? Description { get; init; }
}



