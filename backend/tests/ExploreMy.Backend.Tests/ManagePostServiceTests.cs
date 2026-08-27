using ExploreMy.Api.Application.PostReview.ManagePost;
using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.DataAccess.ExternalClients.SupabaseStorage;
using ExploreMy.Api.DataAccess.Repositories.PostReview;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.PostReview;
using Microsoft.Extensions.Logging;
using Moq;

namespace ExploreMy.Backend.Tests;

public class ManagePostServiceTests
{
    private readonly Mock<IPostReviewRepository> _repository = new();
    private readonly Mock<IStorageClient> _storageClient = new();
    private readonly Mock<ILogger<ManagePostService>> _logger = new();

    private ManagePostService CreateService() => new(_repository.Object, _storageClient.Object, _logger.Object);

    private static Post CreatePost(
        string postId = "post-1",
        int authorId = 1,
        string taggedPlaceId = "place-1",
        string status = PostStatus.Active) => new()
    {
        PostId = postId,
        AuthorId = authorId,
        TaggedPlaceId = taggedPlaceId,
        Title = "A great spot",
        Description = "Beautiful place to visit.",
        Status = status,
    };

    private static CreatePostRequestDto ValidCreateRequest(string taggedPlaceId = "place-1") => new()
    {
        TaggedPlaceId = taggedPlaceId,
        Title = "A great spot",
        Description = "Beautiful place to visit.",
    };

    private static Place EligiblePlace(string placeId = "place-1") => new()
    {
        PlaceId = placeId,
        Name = "Beach",
        Address = "1 Sea Road",
        Category = "Nature & Parks",
    };

    // ============================================================
    // CreatePost
    // ============================================================

    [Fact]
    public async Task CreatePost_ValidPost_CreatesSuccessfully()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetEligibleAttractionsAsync(1)).ReturnsAsync(new List<Place> { EligiblePlace() });

        var result = await service.CreatePostAsync(1, ValidCreateRequest());

        Assert.False(string.IsNullOrEmpty(result.PostId));
        Assert.Equal("Post created successfully.", result.Message);
        _repository.Verify(r => r.CreatePostAsync(It.Is<Post>(p =>
            p.AuthorId == 1
            && p.TaggedPlaceId == "place-1"
            && p.Title == "A great spot"
            && p.Description == "Beautiful place to visit."
            && p.Status == PostStatus.Active)), Times.Once);
    }

    [Fact]
    public async Task CreatePost_WithoutEligibleAttraction_ThrowsValidationException()
    {
        var service = CreateService();
        // The user has only explored "other-place", not the tagged "place-1".
        _repository.Setup(r => r.GetEligibleAttractionsAsync(1)).ReturnsAsync(new List<Place> { EligiblePlace("other-place") });

        await Assert.ThrowsAsync<ValidationException>(() => service.CreatePostAsync(1, ValidCreateRequest("place-1")));
        _repository.Verify(r => r.CreatePostAsync(It.IsAny<Post>()), Times.Never);
    }

    [Theory]
    [InlineData("", "A valid description.")]   // blank title
    [InlineData("   ", "A valid description.")] // whitespace title
    [InlineData("A valid title", "")]          // blank description
    [InlineData("A valid title", "   ")]       // whitespace description
    public async Task CreatePost_BlankTitleOrDescription_ThrowsValidationException(string title, string description)
    {
        var service = CreateService();
        _repository.Setup(r => r.GetEligibleAttractionsAsync(1)).ReturnsAsync(new List<Place> { EligiblePlace() });
        var request = ValidCreateRequest();
        request.Title = title;
        request.Description = description;

        await Assert.ThrowsAsync<ValidationException>(() => service.CreatePostAsync(1, request));
        _repository.Verify(r => r.CreatePostAsync(It.IsAny<Post>()), Times.Never);
    }

    // ============================================================
    // UpdatePost
    // ============================================================

    [Fact]
    public async Task UpdatePost_OwnPost_UpdatesSuccessfully()
    {
        var service = CreateService();
        var post = CreatePost();
        _repository.Setup(r => r.GetByIdAsync("post-1", 1)).ReturnsAsync(post);

        var result = await service.UpdatePostAsync(1, "post-1", new UpdatePostRequestDto
        {
            Title = "Updated title",
            Description = "Updated description.",
        });

        Assert.Equal("Post updated successfully.", result.Message);
        Assert.Equal("Updated title", post.Title);
        Assert.Equal("Updated description.", post.Description);
        _repository.Verify(r => r.UpdatePostAsync(post), Times.Once);
    }

    [Fact]
    public async Task UpdatePost_AnotherUsersPost_ThrowsForbiddenException()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetByIdAsync("post-1", 1)).ReturnsAsync(CreatePost(authorId: 2));

        await Assert.ThrowsAsync<ForbiddenException>(() => service.UpdatePostAsync(1, "post-1", new UpdatePostRequestDto
        {
            Title = "Updated title",
            Description = "Updated description.",
        }));
        _repository.Verify(r => r.UpdatePostAsync(It.IsAny<Post>()), Times.Never);
    }

    // ============================================================
    // DeletePost
    // ============================================================

    [Fact]
    public async Task DeletePost_OwnPost_DeletesSuccessfully()
    {
        var service = CreateService();
        var post = CreatePost();
        _repository.Setup(r => r.GetByIdAsync("post-1", 1)).ReturnsAsync(post);

        var result = await service.DeletePostAsync(1, "post-1");

        Assert.Equal("post-1", result.PostId);
        Assert.Equal(PostStatus.Deleted, post.Status);
        _repository.Verify(r => r.UpdatePostAsync(post), Times.Once);
    }

    [Fact]
    public async Task DeletePost_AnotherUsersPost_ThrowsForbiddenException()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetByIdAsync("post-1", 1)).ReturnsAsync(CreatePost(authorId: 2));

        await Assert.ThrowsAsync<ForbiddenException>(() => service.DeletePostAsync(1, "post-1"));
        _repository.Verify(r => r.UpdatePostAsync(It.IsAny<Post>()), Times.Never);
    }

    // ============================================================
    // SavePost
    // ============================================================

    [Fact]
    public async Task SavePost_ValidSave_CreatesSaveRecord()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetPostForSaveValidationAsync("post-1")).ReturnsAsync(CreatePost(authorId: 2));
        _repository.Setup(r => r.HasActiveReportAsync("post-1", 1)).ReturnsAsync(false);
        _repository.Setup(r => r.IsPostSavedAsync("post-1", 1)).ReturnsAsync(false);

        var result = await service.SavePostAsync(1, "post-1");

        Assert.True(result.IsSaved);
        Assert.Equal("Post saved successfully.", result.Message);
        _repository.Verify(r => r.CreateSavedPostAsync(It.Is<UserSavedPost>(s =>
            s.PostId == "post-1" && s.UserId == 1)), Times.Once);
    }

    [Fact]
    public async Task SavePost_OwnPost_ThrowsForbiddenException()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetPostForSaveValidationAsync("post-1")).ReturnsAsync(CreatePost(authorId: 1));

        await Assert.ThrowsAsync<ForbiddenException>(() => service.SavePostAsync(1, "post-1"));
        _repository.Verify(r => r.CreateSavedPostAsync(It.IsAny<UserSavedPost>()), Times.Never);
    }

    [Fact]
    public async Task SavePost_ReportedPost_ThrowsForbiddenException()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetPostForSaveValidationAsync("post-1")).ReturnsAsync(CreatePost(authorId: 2));
        _repository.Setup(r => r.HasActiveReportAsync("post-1", 1)).ReturnsAsync(true);

        await Assert.ThrowsAsync<ForbiddenException>(() => service.SavePostAsync(1, "post-1"));
        _repository.Verify(r => r.CreateSavedPostAsync(It.IsAny<UserSavedPost>()), Times.Never);
    }

    [Fact]
    public async Task SavePost_DuplicateSave_IsIdempotent()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetPostForSaveValidationAsync("post-1")).ReturnsAsync(CreatePost(authorId: 2));
        _repository.Setup(r => r.HasActiveReportAsync("post-1", 1)).ReturnsAsync(false);
        _repository.Setup(r => r.IsPostSavedAsync("post-1", 1)).ReturnsAsync(true);

        var result = await service.SavePostAsync(1, "post-1");

        Assert.True(result.IsSaved);
        Assert.Equal("Post already saved.", result.Message);
        // No duplicate row is written — a no-op, not an error.
        _repository.Verify(r => r.CreateSavedPostAsync(It.IsAny<UserSavedPost>()), Times.Never);
    }

    // ============================================================
    // UnsavePost
    // ============================================================

    [Fact]
    public async Task UnsavePost_ValidUnsave_RemovesRecord()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetPostForSaveValidationAsync("post-1")).ReturnsAsync(CreatePost(authorId: 2));
        _repository.Setup(r => r.IsPostSavedAsync("post-1", 1)).ReturnsAsync(true);

        var result = await service.UnsavePostAsync(1, "post-1");

        Assert.False(result.IsSaved);
        Assert.Equal("Post unsaved successfully.", result.Message);
        _repository.Verify(r => r.DeleteSavedPostAsync("post-1", 1), Times.Once);
    }

    [Fact]
    public async Task UnsavePost_AlreadyUnsaved_IsIdempotent()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetPostForSaveValidationAsync("post-1")).ReturnsAsync(CreatePost(authorId: 2));
        _repository.Setup(r => r.IsPostSavedAsync("post-1", 1)).ReturnsAsync(false);

        var result = await service.UnsavePostAsync(1, "post-1");

        Assert.False(result.IsSaved);
        Assert.Equal("Post was not saved.", result.Message);
        _repository.Verify(r => r.DeleteSavedPostAsync(It.IsAny<string>(), It.IsAny<int>()), Times.Never);
    }

    // ============================================================
    // GetFeedAsync — My Activity routing
    // ============================================================

    [Fact]
    public async Task GetFeed_MyActivityPosted_CallsGetByAuthorAsync()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetByAuthorAsync(1)).ReturnsAsync(new List<Post> { CreatePost(authorId: 1) });
        _repository.Setup(r => r.GetSavedPostIdsAsync(1)).ReturnsAsync(new HashSet<string>());

        var result = await service.GetFeedAsync(1, "myActivity", "posted", null, null, null, 1, 10);

        Assert.Single(result);
        _repository.Verify(r => r.GetByAuthorAsync(1), Times.Once);
        _repository.Verify(r => r.GetPostsCommentedByAsync(It.IsAny<int>(), It.IsAny<int>(), It.IsAny<int>()), Times.Never);
        _repository.Verify(r => r.GetPostsReportedByAsync(It.IsAny<int>(), It.IsAny<int>(), It.IsAny<int>()), Times.Never);
        _repository.Verify(r => r.GetFeedAsync(It.IsAny<int>(), It.IsAny<PostFeedSort>(), It.IsAny<int?>(), It.IsAny<int?>(), It.IsAny<int>(), It.IsAny<int>()), Times.Never);
    }

    [Fact]
    public async Task GetFeed_MyActivityCommented_CallsGetPostsCommentedByAsync()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetPostsCommentedByAsync(1, 1, 10)).ReturnsAsync(new List<Post> { CreatePost(authorId: 2) });
        _repository.Setup(r => r.GetSavedPostIdsAsync(1)).ReturnsAsync(new HashSet<string>());

        var result = await service.GetFeedAsync(1, "myActivity", "commented", null, null, null, 1, 10);

        Assert.Single(result);
        _repository.Verify(r => r.GetPostsCommentedByAsync(1, 1, 10), Times.Once);
        _repository.Verify(r => r.GetByAuthorAsync(It.IsAny<int>()), Times.Never);
        _repository.Verify(r => r.GetPostsReportedByAsync(It.IsAny<int>(), It.IsAny<int>(), It.IsAny<int>()), Times.Never);
    }

    [Fact]
    public async Task GetFeed_MyActivityReported_CallsGetPostsReportedByAsync()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetPostsReportedByAsync(1, 1, 10)).ReturnsAsync(new List<Post> { CreatePost(authorId: 2) });
        _repository.Setup(r => r.GetSavedPostIdsAsync(1)).ReturnsAsync(new HashSet<string>());

        var result = await service.GetFeedAsync(1, "myActivity", "reported", null, null, null, 1, 10);

        Assert.Single(result);
        _repository.Verify(r => r.GetPostsReportedByAsync(1, 1, 10), Times.Once);
        _repository.Verify(r => r.GetByAuthorAsync(It.IsAny<int>()), Times.Never);
        _repository.Verify(r => r.GetPostsCommentedByAsync(It.IsAny<int>(), It.IsAny<int>(), It.IsAny<int>()), Times.Never);
    }

    // ============================================================
    // GetFeedAsync — Discover sort routing
    // ============================================================

    [Fact]
    public async Task GetFeed_DiscoverPopularity_CallsRepoWithPopularitySort()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetFeedAsync(1, PostFeedSort.Popularity, null, null, 1, 10))
            .ReturnsAsync(new List<Post> { CreatePost() });

        var result = await service.GetFeedAsync(1, "discover", null, "popularity", null, null, 1, 10);

        Assert.Single(result);
        _repository.Verify(r => r.GetFeedAsync(1, PostFeedSort.Popularity, null, null, 1, 10), Times.Once);
    }

    [Fact]
    public async Task GetFeed_DiscoverNewest_CallsRepoWithNewestSort()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetFeedAsync(1, PostFeedSort.Newest, null, null, 1, 10))
            .ReturnsAsync(new List<Post> { CreatePost() });

        var result = await service.GetFeedAsync(1, "discover", null, "newest", null, null, 1, 10);

        Assert.Single(result);
        _repository.Verify(r => r.GetFeedAsync(1, PostFeedSort.Newest, null, null, 1, 10), Times.Once);
    }

    [Fact]
    public async Task GetFeed_DiscoverSaved_CallsRepoWithSavedSort()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetFeedAsync(1, PostFeedSort.Saved, null, null, 1, 10))
            .ReturnsAsync(new List<Post> { CreatePost() });

        var result = await service.GetFeedAsync(1, "discover", null, "saved", null, null, 1, 10);

        Assert.Single(result);
        _repository.Verify(r => r.GetFeedAsync(1, PostFeedSort.Saved, null, null, 1, 10), Times.Once);
    }

    [Fact]
    public async Task GetFeed_MinMaxEngagement_PassedThroughToRepository()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetFeedAsync(1, PostFeedSort.Popularity, 10, 50, 1, 10))
            .ReturnsAsync(new List<Post> { CreatePost() });

        var result = await service.GetFeedAsync(1, "discover", null, "popularity", 10, 50, 1, 10);

        Assert.Single(result);
        _repository.Verify(r => r.GetFeedAsync(1, PostFeedSort.Popularity, 10, 50, 1, 10), Times.Once);
    }

    // ============================================================
    // Eligible attractions
    // ============================================================

    [Fact]
    public async Task GetEligibleAttractions_ReturnsMappedPlaces()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetEligibleAttractionsAsync(1)).ReturnsAsync(new List<Place> { EligiblePlace() });

        var result = await service.GetEligibleAttractionsAsync(1);

        var attraction = Assert.Single(result);
        Assert.Equal("place-1", attraction.PlaceId);
        Assert.Equal("Beach", attraction.Name);
        Assert.Equal("1 Sea Road", attraction.Address);
        Assert.Equal("Nature & Parks", attraction.Category);
    }

    [Fact]
    public async Task HasEligibleAttractions_WithPlaces_ReturnsTrue()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetEligibleAttractionsAsync(1)).ReturnsAsync(new List<Place> { EligiblePlace() });

        Assert.True(await service.HasEligibleAttractionsAsync(1));
    }

    [Fact]
    public async Task HasEligibleAttractions_WithoutPlaces_ReturnsFalse()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetEligibleAttractionsAsync(1)).ReturnsAsync(new List<Place>());

        Assert.False(await service.HasEligibleAttractionsAsync(1));
    }
}
