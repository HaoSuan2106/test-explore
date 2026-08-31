using ExploreMy.Api.DTOs.PostReview;

namespace ExploreMy.Api.Application.PostReview.Facade;

/// <summary>
/// Facade that coordinates the two PostReview feature services
/// (ManagePost, SocialEngagement).
/// </summary>
public interface IPostReviewService
{
    // ---- Posts ----
    Task<List<PostSummaryDto>> GetFeedAsync(int currentUserId, string? category, string? type, string? sort, int? minEngagement, int? maxEngagement, int page, int pageSize);
    Task<List<PostSummaryDto>> SearchPostsAsync(int currentUserId, string query, int page, int pageSize);
    Task<PostDetailsDto> GetPostDetailsAsync(int currentUserId, string postId);
    Task<List<PostSummaryDto>> GetMyPostsAsync(int currentUserId);
    Task<CreatePostResponseDto> CreatePostAsync(int currentUserId, CreatePostRequestDto request);
    Task<UpdatePostResponseDto> UpdatePostAsync(int currentUserId, string postId, UpdatePostRequestDto request);
    Task<DeletePostResponseDto> DeletePostAsync(int currentUserId, string postId);

    // ---- Saved posts ----
    Task<SavePostResponseDto> SavePostAsync(int currentUserId, string postId);
    Task<SavePostResponseDto> UnsavePostAsync(int currentUserId, string postId);

    Task<List<VisitedAttractionDto>> GetVisitedAttractionsAsync(int currentUserId);
    Task<bool> HasVisitedAttractionsAsync(int currentUserId);
    Task<string> UploadPostImageAsync(int currentUserId, Stream fileStream, string fileName, string contentType);

    // ---- Comments ----
    Task<List<PostCommentDto>> GetCommentsAsync(string postId);
    Task<List<PostCommentDto>> GetMyCommentsAsync(int currentUserId);
    Task<CreateCommentResponseDto> CreateCommentAsync(int currentUserId, string postId, CreateCommentRequestDto request);
    Task<UpdateCommentResponseDto> UpdateCommentAsync(int currentUserId, string commentId, UpdateCommentRequestDto request);
    Task<DeleteCommentResponseDto> DeleteCommentAsync(int currentUserId, string commentId);

    // ---- Reactions ----
    Task<ToggleReactionResponseDto> ToggleReactionAsync(int currentUserId, string postId, ToggleReactionRequestDto request);

    // ---- Reports ----
    Task<CreateReportResponseDto> CreateReportAsync(int currentUserId, string postId, CreateReportRequestDto request);
    Task<PostReportDto> WithdrawReportAsync(int currentUserId, string postId, string reportId);
    Task<List<PostReportDto>> GetMyReportsAsync(int currentUserId);
    IReadOnlyList<string> GetReportReasons();
}
