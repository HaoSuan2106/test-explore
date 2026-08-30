using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.DataAccess.ExternalClients.SupabaseStorage;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.HiddenPlace;
using Microsoft.AspNetCore.Http;
using ReviewEntity = ExploreMy.Api.Domain.Entities.Review;

namespace ExploreMy.Api.Application.HiddenPlace.Review;

public class ReviewService : IReviewService
{
    private readonly IReviewRepository _repository;
    private readonly IReviewPhotoRepository _reviewPhotoRepository;
    private readonly IStorageClient _storageClient;

    private readonly IReviewReportRepository _reviewReportRepository;

    public ReviewService(
    IReviewRepository repository,
    IReviewPhotoRepository reviewPhotoRepository,
    IStorageClient storageClient,
    IReviewReportRepository reviewReportRepository)
    {
        _repository = repository;
        _reviewPhotoRepository = reviewPhotoRepository;
        _storageClient = storageClient;
        _reviewReportRepository = reviewReportRepository;
    }

    public async Task<HiddenPlaceReviewDto?> GetByIdAsync(long reviewId)
    {
        var review = await _repository.GetByIdAsync(reviewId);

        if (review is null)
            return null;

        var dto = MapToDto(review);

        await AttachPhotosAsync(dto);

        return dto;
    }

    public async Task<List<HiddenPlaceReviewDto>> GetByGooglePlaceIdAsync(
    string googlePlaceId)
    {
        var reviews = await _repository.GetByGooglePlaceIdAsync(
            googlePlaceId);

        foreach (var review in reviews)
        {
            await AttachPhotosAsync(review);
        }

        return reviews;
    }

    public async Task<List<HiddenPlaceReviewDto>> GetByRecommendPlaceIdAsync(
    string recommendPlaceId)
    {
        var reviews = await _repository.GetByRecommendPlaceIdAsync(
            recommendPlaceId);

        foreach (var review in reviews)
        {
            await AttachPhotosAsync(review);
        }

        return reviews;
    }

    public async Task<HiddenPlaceReviewDto?> GetUserReviewForGooglePlaceAsync(
    int userId,
    string googlePlaceId)
    {
        var review = await _repository.GetUserReviewForGooglePlaceAsync(
            userId,
            googlePlaceId);

        if (review is null)
            return null;

        await AttachPhotosAsync(review);

        return review;
    }

    public async Task<HiddenPlaceReviewDto?> GetUserReviewForRecommendPlaceAsync(
    int userId,
    string recommendPlaceId)
    {
        var review = await _repository.GetUserReviewForRecommendPlaceAsync(
            userId,
            recommendPlaceId);

        if (review is null)
            return null;

        await AttachPhotosAsync(review);

        return review;
    }
    public async Task<HiddenPlaceReviewDto> CreateAsync(
        int userId,
        CreateHiddenPlaceReviewRequestDto request)
    {
        ValidateTarget(request.GooglePlaceId, request.RecommendPlaceId);

        ValidateRating(request.Rating);

        if (string.IsNullOrWhiteSpace(request.Comment))
        {
            throw new ArgumentException("Review comment cannot be empty.");
        }

        // Prevent one user from reviewing the same place twice.
        HiddenPlaceReviewDto? existingReview;

        if (!string.IsNullOrWhiteSpace(request.GooglePlaceId))
        {
            existingReview =
                await _repository.GetUserReviewForGooglePlaceAsync(
                    userId,
                    request.GooglePlaceId);
        }
        else
        {
            existingReview =
                await _repository.GetUserReviewForRecommendPlaceAsync(
                    userId,
                    request.RecommendPlaceId!);
        }

        if (existingReview is not null)
        {
            throw new ConflictException(
                "You have already reviewed this place.");
        }

        var review = new ReviewEntity
        {
            GooglePlaceId = request.GooglePlaceId,
            RecommendPlaceId = request.RecommendPlaceId,
            UserId = userId,
            Rating = request.Rating,
            Comment = request.Comment.Trim(),
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = null,
            Status = "ACTIVE"
        };

        await _repository.AddAsync(review);

        return MapToDto(review);
    }

    public async Task<HiddenPlaceReviewDto> UpdateAsync(
        int userId,
        long reviewId,
        UpdateHiddenPlaceReviewRequestDto request)
    {
        ValidateRating(request.Rating);

        if (string.IsNullOrWhiteSpace(request.Comment))
        {
            throw new ArgumentException("Review comment cannot be empty.");
        }

        var review = await _repository.GetByIdAsync(reviewId);

        if (review is null || review.Status != "ACTIVE")
        {
            throw new NotFoundException("Review not found.");
        }

        // Only the owner of the review can update it.
        if (review.UserId != userId)
        {
            throw new ForbiddenException(
                "You are not allowed to update this review.");
        }

        review.Rating = request.Rating;
        review.Comment = request.Comment.Trim();
        review.UpdatedAt = DateTime.UtcNow;

        await _repository.UpdateAsync(review);

        return MapToDto(review);
    }

    public async Task DeleteAsync(
    int userId,
    long reviewId)
    {
        var review = await _repository.GetByIdAsync(reviewId);

        if (review is null || review.Status != "ACTIVE")
        {
            throw new NotFoundException("Review not found.");
        }

        // Only the owner can delete their review.
        if (review.UserId != userId)
        {
            throw new ForbiddenException(
                "You are not allowed to delete this review.");
        }

        // Get all photos belonging to this review.
        var photos = await _reviewPhotoRepository
            .GetByReviewIdAsync(reviewId);

        // Delete the actual files from Supabase Storage.
        foreach (var photo in photos)
        {
            var storagePath =
                _storageClient.GetPathFromPublicUrl(photo.PhotoUrl);

            if (!string.IsNullOrWhiteSpace(storagePath))
            {
                await _storageClient.DeleteAsync(storagePath);
            }
        }

        // Delete all photo records from the database.
        await _reviewPhotoRepository.DeleteByReviewIdAsync(reviewId);

        // Soft delete the review.
        review.Status = "DELETED";
        review.UpdatedAt = DateTime.UtcNow;

        await _repository.UpdateAsync(review);
    }

    private static void ValidateTarget(
        string? googlePlaceId,
        string? recommendPlaceId)
    {
        var hasGooglePlace =
            !string.IsNullOrWhiteSpace(googlePlaceId);

        var hasRecommendPlace =
            !string.IsNullOrWhiteSpace(recommendPlaceId);

        // A review must belong to exactly one type of place.
        if (hasGooglePlace == hasRecommendPlace)
        {
            throw new ArgumentException(
                "A review must have either GooglePlaceId or RecommendPlaceId, but not both.");
        }
    }

    private static void ValidateRating(decimal rating)
    {
        if (rating < 1 || rating > 5)
        {
            throw new ArgumentException(
                "Rating must be between 1 and 5.");
        }
    }

    private static HiddenPlaceReviewDto MapToDto(
        ReviewEntity review)
    {
        return new HiddenPlaceReviewDto
        {
            ReviewId = review.ReviewId,
            GooglePlaceId = review.GooglePlaceId,
            RecommendPlaceId = review.RecommendPlaceId,
            UserId = review.UserId,
            Rating = review.Rating,
            Comment = review.Comment,
            CreatedAt = review.CreatedAt,
            UpdatedAt = review.UpdatedAt,
            Status = review.Status
        };
    }

    public async Task<List<HiddenPlaceReviewPhotoDto>> UploadPhotosAsync(
    int userId,
    long reviewId,
    List<IFormFile> files)
    {
        var review = await _repository.GetByIdAsync(reviewId);

        if (review is null || review.Status != "ACTIVE")
        {
            throw new NotFoundException("Review not found.");
        }

        // Only the owner of the review can upload photos.
        if (review.UserId != userId)
        {
            throw new ForbiddenException(
                "You are not allowed to upload photos to this review.");
        }

        if (files == null || files.Count == 0)
        {
            throw new ArgumentException("No photos were uploaded.");
        }

        var existingPhotos = await _reviewPhotoRepository
            .GetByReviewIdAsync(reviewId);

        if (existingPhotos.Count + files.Count > 5)
        {
            throw new ArgumentException(
                "A review can have a maximum of 5 photos.");
        }

        var allowedContentTypes = new HashSet<string>(
            StringComparer.OrdinalIgnoreCase)
    {
        "image/jpeg",
        "image/png",
        "image/webp"
    };

        const long maxFileSize = 5 * 1024 * 1024;

        var photos = new List<ReviewPhoto>();

        for (var i = 0; i < files.Count; i++)
        {
            var file = files[i];

            if (file == null || file.Length == 0)
            {
                throw new ArgumentException("One of the uploaded files is empty.");
            }

            if (file.Length > maxFileSize)
            {
                throw new ArgumentException(
                    "Each photo must not exceed 5MB.");
            }

            if (!allowedContentTypes.Contains(file.ContentType))
            {
                throw new ArgumentException(
                    "Unsupported photo type. Allowed: jpeg, png, webp.");
            }

            var extension = file.ContentType switch
            {
                "image/jpeg" => ".jpg",
                "image/png" => ".png",
                "image/webp" => ".webp",
                _ => ""
            };

            var fileName = $"{Guid.NewGuid():N}{extension}";

            var storagePath =
                $"reviews/{reviewId}/{fileName}";

            await using var stream = file.OpenReadStream();

            var photoUrl = await _storageClient.UploadAsync(
                storagePath,
                stream,
                file.ContentType);

            photos.Add(new ReviewPhoto
            {
                ReviewId = reviewId,
                PhotoUrl = photoUrl,
                DisplayOrder = existingPhotos.Count + i + 1,
                CreatedAt = DateTime.UtcNow
            });
        }

        await _reviewPhotoRepository.AddRangeAsync(photos);

        return photos.Select(photo => new HiddenPlaceReviewPhotoDto
        {
            ReviewPhotoId = photo.ReviewPhotoId,
            ReviewId = photo.ReviewId,
            PhotoUrl = photo.PhotoUrl,
            DisplayOrder = photo.DisplayOrder,
            CreatedAt = photo.CreatedAt
        }).ToList();
    }

    private async Task AttachPhotosAsync(HiddenPlaceReviewDto review)
    {
        var photos = await _reviewPhotoRepository
            .GetByReviewIdAsync(review.ReviewId);

        review.Photos = photos
            .Select(photo => new HiddenPlaceReviewPhotoDto
            {
                ReviewPhotoId = photo.ReviewPhotoId,
                ReviewId = photo.ReviewId,
                PhotoUrl = photo.PhotoUrl,
                DisplayOrder = photo.DisplayOrder,
                CreatedAt = photo.CreatedAt
            })
            .OrderBy(photo => photo.DisplayOrder)
            .ToList();
    }

    public async Task DeletePhotoAsync(
    int userId,
    long reviewId,
    long reviewPhotoId)
    {
        var review = await _repository.GetByIdAsync(reviewId);

        if (review is null || review.Status != "ACTIVE")
        {
            throw new NotFoundException("Review not found.");
        }

        // Only the owner of the review can delete its photos.
        if (review.UserId != userId)
        {
            throw new ForbiddenException(
                "You are not allowed to delete photos from this review.");
        }

        var photos = await _reviewPhotoRepository
            .GetByReviewIdAsync(reviewId);

        var photo = photos.FirstOrDefault(
            p => p.ReviewPhotoId == reviewPhotoId);

        if (photo is null)
        {
            throw new NotFoundException("Review photo not found.");
        }

        // Delete the file from Supabase Storage.
        var storagePath =
            _storageClient.GetPathFromPublicUrl(photo.PhotoUrl);

        if (!string.IsNullOrWhiteSpace(storagePath))
        {
            await _storageClient.DeleteAsync(storagePath);
        }

        // Delete the database record.
        await _reviewPhotoRepository.DeleteAsync(photo);
    }

    public async Task ReportAsync(
    int userId,
    long reviewId,
    string reason)
    {
        const int reportThreshold = 1;

        var review = await _repository.GetByIdAsync(reviewId);

        if (review is null || review.Status != "ACTIVE")
        {
            throw new NotFoundException("Review not found.");
        }

        if (string.IsNullOrWhiteSpace(reason))
        {
            throw new ArgumentException(
                "Report reason is required.");
        }

        var allowedReasons = new HashSet<string>(
            StringComparer.OrdinalIgnoreCase)
            {
                "Off topic",
                "Spam",
                "Conflict of interest",
                "Profanity",
                "Harmful",
                "Not helpful"
            };

        if (!allowedReasons.Contains(reason.Trim()))
        {
            throw new ArgumentException(
                "Invalid report reason.");
        }

        var alreadyReported =
            await _reviewReportRepository.ExistsAsync(
                reviewId,
                userId);

        if (alreadyReported)
        {
            throw new ConflictException(
                "You have already reported this review.");
        }

        var report = new ReviewReport
        {
            ReviewId = reviewId,
            UserId = userId,
            Reason = reason.Trim(),
            CreatedAt = DateTime.UtcNow
        };

        await _reviewReportRepository.AddAsync(report);

        var reportCount =
            await _reviewReportRepository.CountByReviewIdAsync(
                reviewId);

        if (reportCount >= reportThreshold)
        {
            review.Status = "REMOVED";
            review.UpdatedAt = DateTime.UtcNow;

            await _repository.UpdateAsync(review);
        }
    }
}