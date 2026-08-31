using ExploreMy.Api.Application.PostReview.ManagePost;
using ExploreMy.Api.Application.PostReview.SocialEngagement;
using ExploreMy.Api.DTOs.PostReview;

namespace ExploreMy.Api.Application.PostReview.Facade;

/// <summary>
/// Facade that coordinates the two PostReview feature services
/// (ManagePost, SocialEngagement).
/// </summary>
public class PostReviewService : IPostReviewService
{
    private readonly IManagePostService _managePost;
    private readonly ISocialEngagementService _socialEngagement;

    public PostReviewService(
        IManagePostService managePost,
        ISocialEngagementService socialEngagement)
    {
        _managePost = managePost;
        _socialEngagement = socialEngagement;
    }

    public Task<List<PostSummaryDto>> GetFeedAsync(int currentUserId, string? category, string? type, string? sort, int? minEngagement, int? maxEngagement, int page, int pageSize)
        => _managePost.GetFeedAsync(currentUserId, category, type, sort, minEngagement, maxEngagement, page, pageSize);

    public Task<List<PostSummaryDto>> SearchPostsAsync(int currentUserId, string query, int page, int pageSize)
        => _managePost.SearchPostsAsync(currentUserId, query, page, pageSize);

    public Task<PostDetailsDto> GetPostDetailsAsync(int currentUserId, string postId)
        => _managePost.GetPostDetailsAsync(currentUserId, postId);

    public Task<List<PostSummaryDto>> GetMyPostsAsync(int currentUserId)
        => _managePost.GetMyPostsAsync(currentUserId);

    public Task<CreatePostResponseDto> CreatePostAsync(int currentUserId, CreatePostRequestDto request)
        => _managePost.CreatePostAsync(currentUserId, request);

    public Task<UpdatePostResponseDto> UpdatePostAsync(int currentUserId, string postId, UpdatePostRequestDto request)
        => _managePost.UpdatePostAsync(currentUserId, postId, request);

    public Task<DeletePostResponseDto> DeletePostAsync(int currentUserId, string postId)
        => _managePost.DeletePostAsync(currentUserId, postId);

    public Task<SavePostResponseDto> SavePostAsync(int currentUserId, string postId)
        => _managePost.SavePostAsync(currentUserId, postId);

    public Task<SavePostResponseDto> UnsavePostAsync(int currentUserId, string postId)
        => _managePost.UnsavePostAsync(currentUserId, postId);

    public Task<List<VisitedAttractionDto>> GetVisitedAttractionsAsync(int currentUserId)
        => _managePost.GetVisitedAttractionsAsync(currentUserId);

    public Task<bool> HasVisitedAttractionsAsync(int currentUserId)
        => _managePost.HasVisitedAttractionsAsync(currentUserId);

    public Task<string> UploadPostImageAsync(int currentUserId, Stream fileStream, string fileName, string contentType)
        => _managePost.UploadPostImageAsync(currentUserId, fileStream, fileName, contentType);

    public Task<List<PostCommentDto>> GetCommentsAsync(string postId)
        => _socialEngagement.GetCommentsAsync(postId);

    public Task<List<PostCommentDto>> GetMyCommentsAsync(int currentUserId)
        => _socialEngagement.GetMyCommentsAsync(currentUserId);

    public Task<CreateCommentResponseDto> CreateCommentAsync(int currentUserId, string postId, CreateCommentRequestDto request)
        => _socialEngagement.CreateCommentAsync(currentUserId, postId, request);

    public Task<UpdateCommentResponseDto> UpdateCommentAsync(int currentUserId, string commentId, UpdateCommentRequestDto request)
        => _socialEngagement.UpdateCommentAsync(currentUserId, commentId, request);

    public Task<DeleteCommentResponseDto> DeleteCommentAsync(int currentUserId, string commentId)
        => _socialEngagement.DeleteCommentAsync(currentUserId, commentId);

    public Task<ToggleReactionResponseDto> ToggleReactionAsync(int currentUserId, string postId, ToggleReactionRequestDto request)
        => _socialEngagement.ToggleReactionAsync(currentUserId, postId, request);

    public Task<CreateReportResponseDto> CreateReportAsync(int currentUserId, string postId, CreateReportRequestDto request)
        => _socialEngagement.CreateReportAsync(currentUserId, postId, request);

    public Task<PostReportDto> WithdrawReportAsync(int currentUserId, string postId, string reportId)
        => _socialEngagement.WithdrawReportAsync(currentUserId, postId, reportId);

    public Task<List<PostReportDto>> GetMyReportsAsync(int currentUserId)
        => _socialEngagement.GetMyReportsAsync(currentUserId);

    public IReadOnlyList<string> GetReportReasons()
        => _socialEngagement.GetReportReasons();

}
