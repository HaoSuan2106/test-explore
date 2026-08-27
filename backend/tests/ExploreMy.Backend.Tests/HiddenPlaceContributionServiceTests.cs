using ExploreMy.Api.Application.HiddenPlace.HiddenPlaceContribution;
using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.DataAccess.Repositories.HiddenPlace;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.HiddenPlace;
using Microsoft.Extensions.Logging;
using Moq;

namespace ExploreMy.Backend.Tests;

public class HiddenPlaceContributionServiceTests
{
    private readonly Mock<IHiddenPlaceRepository> _repository = new();
    private readonly Mock<ILogger<HiddenPlaceContributionService>> _logger = new();

    private HiddenPlaceContributionService CreateService() => new(_repository.Object, _logger.Object);

    private static RecommendedPlace CreatePlace(
        string submissionId = "sub-1",
        int submitterId = 1,
        string status = RecommendedPlaceStatus.UnderVoting,
        string category = RecommendedPlaceCategories.Cafe) => new()
    {
        SubmissionId = submissionId,
        SubmitterId = submitterId,
        Name = "Secret Café",
        LocationAddress = "12 Hidden Lane",
        Latitude = 10.5m,
        Longitude = 106.7m,
        Category = category,
        Description = "A lovely hidden café.",
        Status = status,
    };

    private static SubmitRecommendedPlaceRequestDto ValidSubmitRequest() => new()
    {
        Name = "Secret Café",
        LocationAddress = "12 Hidden Lane",
        Latitude = 10.5m,
        Longitude = 106.7m,
        Category = RecommendedPlaceCategories.Cafe,
        Description = "A lovely hidden café.",
    };

    // ============================================================
    // SubmitPlace
    // ============================================================

    [Fact]
    public async Task SubmitPlace_ValidRequest_CreatesUnderVoting()
    {
        var service = CreateService();
        _repository.Setup(r => r.ExistsByNameAndAddressAsync("Secret Café", "12 Hidden Lane")).ReturnsAsync(false);
        _repository.Setup(r => r.ExistsNearbyAsync(10.5m, 106.7m, RecommendedPlaceThresholds.ProximityRadiusMeters)).ReturnsAsync(false);

        var result = await service.SubmitPlaceAsync(1, ValidSubmitRequest());

        Assert.False(string.IsNullOrEmpty(result.SubmissionId));
        Assert.Equal("Your recommendation is now under community voting.", result.Message);
        _repository.Verify(r => r.CreatePlaceAsync(It.Is<RecommendedPlace>(p =>
            p.SubmitterId == 1
            && p.Name == "Secret Café"
            && p.LocationAddress == "12 Hidden Lane"
            && p.Category == RecommendedPlaceCategories.Cafe
            && p.Description == "A lovely hidden café."
            && p.Status == RecommendedPlaceStatus.UnderVoting)), Times.Once);
    }

    [Theory]
    [InlineData("Name", "")]
    [InlineData("Name", "   ")]
    [InlineData("Category", "")]
    [InlineData("Description", "")]
    [InlineData("Description", "   ")]
    [InlineData("LocationAddress", "")]
    public async Task SubmitPlace_MissingRequiredField_ThrowsValidationException(string field, string value)
    {
        var service = CreateService();
        var request = ValidSubmitRequest();
        switch (field)
        {
            case "Name":
                request.Name = value;
                break;
            case "Category":
                request.Category = value;
                break;
            case "Description":
                request.Description = value;
                break;
            case "LocationAddress":
                request.LocationAddress = value;
                break;
        }

        await Assert.ThrowsAsync<ValidationException>(() => service.SubmitPlaceAsync(1, request));
        _repository.Verify(r => r.CreatePlaceAsync(It.IsAny<RecommendedPlace>()), Times.Never);
    }

    public static IEnumerable<object?[]> MissingCoordinateCases()
    {
        yield return new object?[] { (decimal?)null, 106.7m }; // missing latitude
        yield return new object?[] { 10.5m, (decimal?)null };  // missing longitude
    }

    [Theory]
    [MemberData(nameof(MissingCoordinateCases))]
    public async Task SubmitPlace_MissingCoordinates_ThrowsValidationException(decimal? latitude, decimal? longitude)
    {
        var service = CreateService();
        var request = ValidSubmitRequest();
        request.Latitude = latitude;
        request.Longitude = longitude;

        await Assert.ThrowsAsync<ValidationException>(() => service.SubmitPlaceAsync(1, request));
        _repository.Verify(r => r.CreatePlaceAsync(It.IsAny<RecommendedPlace>()), Times.Never);
    }

    [Theory]
    [InlineData("Not a real category")]
    [InlineData("")]
    public async Task SubmitPlace_UnsupportedCategory_ThrowsValidationException(string category)
    {
        var service = CreateService();
        var request = ValidSubmitRequest();
        request.Category = category;

        await Assert.ThrowsAsync<ValidationException>(() => service.SubmitPlaceAsync(1, request));
        _repository.Verify(r => r.CreatePlaceAsync(It.IsAny<RecommendedPlace>()), Times.Never);
    }

    // ============================================================
    // ViewPlace
    // ============================================================

    [Fact]
    public async Task ViewPlace_GetPlaceDetailsAsync_ReturnsDetails()
    {
        var service = CreateService();
        var place = CreatePlace(submitterId: 2);
        place.Verifications.Add(new RecommendedPlaceVerification
        {
            SubmissionId = "sub-1",
            UserId = 3,
            Status = RecommendedPlaceVerificationStatus.Active,
        });
        place.Reports.Add(new RecommendedPlaceReport
        {
            SubmissionId = "sub-1",
            ReporterId = 4,
            Reason = RecommendedPlaceReportReasons.OtherViolation,
            Status = RecommendedPlaceReportStatus.Active,
        });
        _repository.Setup(r => r.GetByIdAsync("sub-1")).ReturnsAsync(place);

        var result = await service.GetPlaceDetailsAsync(1, "sub-1");

        Assert.Equal("sub-1", result.SubmissionId);
        Assert.Equal("Secret Café", result.Name);
        Assert.Equal(RecommendedPlaceCategories.Cafe, result.Category);
        Assert.Equal(RecommendedPlaceStatus.UnderVoting, result.Status);
        Assert.Equal(1, result.VerificationCount);
        Assert.Equal(1, result.ReportCount);
        Assert.Equal(RecommendedPlaceThresholds.RequiredVerifications, result.RequiredVerifications);
        Assert.False(result.IsCurrentUserSubmitter);
        Assert.False(result.IsVerifiedByCurrentUser);
        Assert.False(result.IsReportedByCurrentUser);
    }

    // ============================================================
    // WithdrawPlace
    // ============================================================

    [Fact]
    public async Task WithdrawPlace_OwnPlace_Withdraws()
    {
        var service = CreateService();
        var place = CreatePlace(submitterId: 1);
        _repository.Setup(r => r.GetByIdAsync("sub-1")).ReturnsAsync(place);

        var result = await service.WithdrawPlaceAsync(1, "sub-1");

        Assert.Equal(RecommendedPlaceStatus.Withdrawn, result.Status);
        Assert.Equal(RecommendedPlaceStatus.Withdrawn, place.Status);
        _repository.Verify(r => r.UpdatePlaceAsync(place), Times.Once);
    }

    [Fact]
    public async Task WithdrawPlace_AnotherUsersPlace_ThrowsForbiddenException()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetByIdAsync("sub-1")).ReturnsAsync(CreatePlace(submitterId: 2));

        await Assert.ThrowsAsync<ForbiddenException>(() => service.WithdrawPlaceAsync(1, "sub-1"));
        _repository.Verify(r => r.UpdatePlaceAsync(It.IsAny<RecommendedPlace>()), Times.Never);
    }

    [Fact]
    public async Task WithdrawPlace_VerifiedPlace_ThrowsValidationException()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetByIdAsync("sub-1")).ReturnsAsync(CreatePlace(submitterId: 1, status: RecommendedPlaceStatus.Verified));

        await Assert.ThrowsAsync<ValidationException>(() => service.WithdrawPlaceAsync(1, "sub-1"));
        _repository.Verify(r => r.UpdatePlaceAsync(It.IsAny<RecommendedPlace>()), Times.Never);
    }

    // ============================================================
    // ToggleVerification — verify
    // ============================================================

    [Fact]
    public async Task VerifyPlace_Verify_AddsVote()
    {
        var service = CreateService();
        var place = CreatePlace(submitterId: 2);
        _repository.Setup(r => r.GetByIdAsync("sub-1")).ReturnsAsync(place);
        _repository.Setup(r => r.GetActiveVerificationAsync("sub-1", 1)).ReturnsAsync((RecommendedPlaceVerification?)null);
        _repository.Setup(r => r.GetAnyVerificationAsync("sub-1", 1)).ReturnsAsync((RecommendedPlaceVerification?)null);
        _repository.Setup(r => r.GetActiveVerificationCountAsync("sub-1")).ReturnsAsync(1);

        var result = await service.ToggleVerificationAsync(1, "sub-1", verify: true);

        Assert.True(result.IsVerified);
        Assert.Equal(1, result.VerificationCount);
        Assert.Equal(RecommendedPlaceStatus.UnderVoting, result.PlaceStatus);
        _repository.Verify(r => r.CreateVerificationAsync(It.Is<RecommendedPlaceVerification>(v =>
            v.SubmissionId == "sub-1"
            && v.UserId == 1
            && v.Status == RecommendedPlaceVerificationStatus.Active)), Times.Once);
        _repository.Verify(r => r.UpdatePlaceAsync(It.IsAny<RecommendedPlace>()), Times.Never);
    }

    [Fact]
    public async Task VerifyPlace_OwnPlace_ThrowsForbiddenException()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetByIdAsync("sub-1")).ReturnsAsync(CreatePlace(submitterId: 1));

        await Assert.ThrowsAsync<ForbiddenException>(() => service.ToggleVerificationAsync(1, "sub-1", verify: true));
        _repository.Verify(r => r.CreateVerificationAsync(It.IsAny<RecommendedPlaceVerification>()), Times.Never);
    }

    [Fact]
    public async Task VerifyPlace_VerifyTwice_ThrowsValidationException()
    {
        // The current implementation rejects a second verify while an active
        // verification already exists (no toggle-to-withdraw on verify).
        var service = CreateService();
        var place = CreatePlace(submitterId: 2);
        _repository.Setup(r => r.GetByIdAsync("sub-1")).ReturnsAsync(place);
        _repository.Setup(r => r.GetActiveVerificationAsync("sub-1", 1)).ReturnsAsync(new RecommendedPlaceVerification
        {
            SubmissionId = "sub-1",
            UserId = 1,
            Status = RecommendedPlaceVerificationStatus.Active,
        });

        await Assert.ThrowsAsync<ValidationException>(() => service.ToggleVerificationAsync(1, "sub-1", verify: true));
        _repository.Verify(r => r.CreateVerificationAsync(It.IsAny<RecommendedPlaceVerification>()), Times.Never);
    }

    // ============================================================
    // ToggleVerification — withdraw
    // ============================================================

    [Fact]
    public async Task WithdrawVerification_OwnVerification_Withdraws()
    {
        var service = CreateService();
        var place = CreatePlace(submitterId: 2);
        var verification = new RecommendedPlaceVerification
        {
            SubmissionId = "sub-1",
            UserId = 1,
            Status = RecommendedPlaceVerificationStatus.Active,
        };
        _repository.Setup(r => r.GetByIdAsync("sub-1")).ReturnsAsync(place);
        _repository.Setup(r => r.GetActiveVerificationAsync("sub-1", 1)).ReturnsAsync(verification);
        _repository.Setup(r => r.GetActiveVerificationCountAsync("sub-1")).ReturnsAsync(0);

        var result = await service.ToggleVerificationAsync(1, "sub-1", verify: false);

        Assert.False(result.IsVerified);
        Assert.Equal(0, result.VerificationCount);
        Assert.Equal(RecommendedPlaceVerificationStatus.Withdrawn, verification.Status);
        _repository.Verify(r => r.UpdateVerificationAsync(verification), Times.Once);
    }

    [Fact]
    public async Task WithdrawVerification_SomeoneElsesVerification_ThrowsValidationException()
    {
        // A user can only withdraw their OWN verification. Here the active
        // verification belongs to another user (user 3); the current user (1)
        // has no active verification, so the withdraw is rejected.
        var service = CreateService();
        var place = CreatePlace(submitterId: 2);
        _repository.Setup(r => r.GetByIdAsync("sub-1")).ReturnsAsync(place);
        _repository.Setup(r => r.GetActiveVerificationAsync("sub-1", 1)).ReturnsAsync((RecommendedPlaceVerification?)null);

        await Assert.ThrowsAsync<ValidationException>(() => service.ToggleVerificationAsync(1, "sub-1", verify: false));
        _repository.Verify(r => r.UpdateVerificationAsync(It.IsAny<RecommendedPlaceVerification>()), Times.Never);
    }

    // ============================================================
    // Verification threshold / state transitions
    // ============================================================

    [Fact]
    public async Task Threshold_FiveVotes_TransitionsToVerified()
    {
        var service = CreateService();
        var place = CreatePlace(submitterId: 2);
        _repository.Setup(r => r.GetByIdAsync("sub-1")).ReturnsAsync(place);
        _repository.Setup(r => r.GetActiveVerificationAsync("sub-1", 1)).ReturnsAsync((RecommendedPlaceVerification?)null);
        _repository.Setup(r => r.GetAnyVerificationAsync("sub-1", 1)).ReturnsAsync((RecommendedPlaceVerification?)null);
        _repository.Setup(r => r.GetActiveVerificationCountAsync("sub-1")).ReturnsAsync(RecommendedPlaceThresholds.RequiredVerifications);

        var result = await service.ToggleVerificationAsync(1, "sub-1", verify: true);

        Assert.Equal(RecommendedPlaceStatus.Verified, result.PlaceStatus);
        Assert.Equal(RecommendedPlaceStatus.Verified, place.Status);
        _repository.Verify(r => r.UpdatePlaceAsync(place), Times.Once);
    }

    [Fact]
    public async Task StateTransition_VerifyKeepsUnderVoting_FifthVoteVerifies()
    {
        var service = CreateService();
        var place = CreatePlace(submitterId: 2);
        _repository.Setup(r => r.GetByIdAsync("sub-1")).ReturnsAsync(place);
        _repository.Setup(r => r.GetActiveVerificationAsync("sub-1", 1)).ReturnsAsync((RecommendedPlaceVerification?)null);
        _repository.Setup(r => r.GetAnyVerificationAsync("sub-1", 1)).ReturnsAsync((RecommendedPlaceVerification?)null);
        _repository.SetupSequence(r => r.GetActiveVerificationCountAsync("sub-1"))
            .ReturnsAsync(1)
            .ReturnsAsync(2)
            .ReturnsAsync(3)
            .ReturnsAsync(4)
            .ReturnsAsync(RecommendedPlaceThresholds.RequiredVerifications);

        // Votes 1..4 keep the place UNDER_VOTING.
        for (var i = 0; i < 4; i++)
        {
            var intermediate = await service.ToggleVerificationAsync(1, "sub-1", verify: true);
            Assert.Equal(RecommendedPlaceStatus.UnderVoting, intermediate.PlaceStatus);
            Assert.Equal(RecommendedPlaceStatus.UnderVoting, place.Status);
        }

        // The 5th vote transitions the place to VERIFIED.
        var fifth = await service.ToggleVerificationAsync(1, "sub-1", verify: true);
        Assert.Equal(RecommendedPlaceStatus.Verified, fifth.PlaceStatus);
        Assert.Equal(RecommendedPlaceStatus.Verified, place.Status);
        _repository.Verify(r => r.CreateVerificationAsync(It.IsAny<RecommendedPlaceVerification>()), Times.Exactly(5));
        _repository.Verify(r => r.UpdatePlaceAsync(place), Times.Once);
    }

    // ============================================================
    // ReportPlace
    // ============================================================

    [Fact]
    public async Task ReportPlace_ValidReport_CreatesRecord()
    {
        var service = CreateService();
        var place = CreatePlace(submitterId: 2);
        _repository.Setup(r => r.GetByIdAsync("sub-1")).ReturnsAsync(place);
        _repository.Setup(r => r.GetActiveReportAsync("sub-1", 1)).ReturnsAsync((RecommendedPlaceReport?)null);
        _repository.Setup(r => r.GetActiveReportCountAsync("sub-1")).ReturnsAsync(1);

        var result = await service.ReportPlaceAsync(1, "sub-1", RecommendedPlaceReportReasons.OtherViolation);

        Assert.False(string.IsNullOrEmpty(result.ReportId));
        Assert.Equal(1, result.ReportCount);
        Assert.Equal(RecommendedPlaceStatus.UnderVoting, result.PlaceStatus);
        _repository.Verify(r => r.CreateReportAsync(It.Is<RecommendedPlaceReport>(rep =>
            rep.SubmissionId == "sub-1"
            && rep.ReporterId == 1
            && rep.Reason == RecommendedPlaceReportReasons.OtherViolation
            && rep.Status == RecommendedPlaceReportStatus.Active)), Times.Once);
        _repository.Verify(r => r.UpdatePlaceAsync(It.IsAny<RecommendedPlace>()), Times.Never);
    }

    [Fact]
    public async Task ReportPlace_InvalidReason_ThrowsValidationException()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetByIdAsync("sub-1")).ReturnsAsync(CreatePlace(submitterId: 2));

        await Assert.ThrowsAsync<ValidationException>(() => service.ReportPlaceAsync(1, "sub-1", "Not a real reason"));
        _repository.Verify(r => r.CreateReportAsync(It.IsAny<RecommendedPlaceReport>()), Times.Never);
    }

    [Fact]
    public async Task ReportPlace_OwnPlace_ThrowsForbiddenException()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetByIdAsync("sub-1")).ReturnsAsync(CreatePlace(submitterId: 1));

        await Assert.ThrowsAsync<ForbiddenException>(() => service.ReportPlaceAsync(1, "sub-1", RecommendedPlaceReportReasons.OtherViolation));
        _repository.Verify(r => r.CreateReportAsync(It.IsAny<RecommendedPlaceReport>()), Times.Never);
    }

    [Fact]
    public async Task ReportPlace_DuplicateActiveReport_ThrowsValidationException()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetByIdAsync("sub-1")).ReturnsAsync(CreatePlace(submitterId: 2));
        _repository.Setup(r => r.GetActiveReportAsync("sub-1", 1)).ReturnsAsync(new RecommendedPlaceReport
        {
            SubmissionId = "sub-1",
            ReporterId = 1,
            Reason = RecommendedPlaceReportReasons.OtherViolation,
            Status = RecommendedPlaceReportStatus.Active,
        });

        await Assert.ThrowsAsync<ValidationException>(() => service.ReportPlaceAsync(1, "sub-1", RecommendedPlaceReportReasons.OtherViolation));
        _repository.Verify(r => r.CreateReportAsync(It.IsAny<RecommendedPlaceReport>()), Times.Never);
    }

    [Fact]
    public async Task ReportPlace_ThresholdReached_TransitionsToReportedClosed()
    {
        var service = CreateService();
        var place = CreatePlace(submitterId: 2);
        _repository.Setup(r => r.GetByIdAsync("sub-1")).ReturnsAsync(place);
        _repository.Setup(r => r.GetActiveReportAsync("sub-1", 1)).ReturnsAsync((RecommendedPlaceReport?)null);
        _repository.Setup(r => r.GetActiveReportCountAsync("sub-1")).ReturnsAsync(RecommendedPlaceThresholds.HideThreshold);

        var result = await service.ReportPlaceAsync(1, "sub-1", RecommendedPlaceReportReasons.OtherViolation);

        Assert.Equal(RecommendedPlaceStatus.ReportedClosed, result.PlaceStatus);
        Assert.Equal(RecommendedPlaceStatus.ReportedClosed, place.Status);
        _repository.Verify(r => r.UpdatePlaceAsync(place), Times.Once);
    }

    // ============================================================
    // GetMyPlaces
    // ============================================================

    [Fact]
    public async Task GetMyPlaces_ReturnsSubmitterPlaces()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetBySubmitterAsync(1)).ReturnsAsync(new List<RecommendedPlace>
        {
            CreatePlace(submissionId: "sub-old", submitterId: 1),
            CreatePlace(submissionId: "sub-new", submitterId: 1),
        });

        var result = await service.GetMyPlacesAsync(1);

        Assert.Equal(2, result.Count);
        Assert.Contains(result, p => p.SubmissionId == "sub-old");
        Assert.Contains(result, p => p.SubmissionId == "sub-new");
        _repository.Verify(r => r.GetBySubmitterAsync(1), Times.Once);
    }
}
