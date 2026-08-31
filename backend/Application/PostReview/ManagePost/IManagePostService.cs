using ExploreMy.Api.DTOs.PostReview;

namespace ExploreMy.Api.Application.PostReview.ManagePost;

public interface IManagePostService
{
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
}
