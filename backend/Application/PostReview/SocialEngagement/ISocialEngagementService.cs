using ExploreMy.Api.DTOs.PostReview;

namespace ExploreMy.Api.Application.PostReview.SocialEngagement;

public interface ISocialEngagementService
{
    Task<List<PostCommentDto>> GetCommentsAsync(string postId);
    Task<List<PostCommentDto>> GetMyCommentsAsync(int currentUserId);
    Task<CreateCommentResponseDto> CreateCommentAsync(int currentUserId, string postId, CreateCommentRequestDto request);
    Task<UpdateCommentResponseDto> UpdateCommentAsync(int currentUserId, string commentId, UpdateCommentRequestDto request);
    Task<DeleteCommentResponseDto> DeleteCommentAsync(int currentUserId, string commentId);

    Task<ToggleReactionResponseDto> ToggleReactionAsync(int currentUserId, string postId, ToggleReactionRequestDto request);

    Task<CreateReportResponseDto> CreateReportAsync(int currentUserId, string postId, CreateReportRequestDto request);
    Task<List<PostReportDto>> GetMyReportsAsync(int currentUserId);
    IReadOnlyList<string> GetReportReasons();
}
