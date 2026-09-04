using ExploreMy.Api.Application.HiddenPlace.HiddenPlaceContribution;
using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.DataAccess.ExternalClients.SupabaseStorage;
using ExploreMy.Api.DataAccess.Repositories.HiddenPlace;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.HiddenPlace;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;

namespace ExploreMy.Api.Tests;

/// <summary>
/// UNIT tests for HiddenPlaceContributionService business rules (submit, update, withdraw,
/// toggle-verification, report). Tests the guard logic — repository calls are mocked.
/// </summary>
public class HiddenPlaceContributionServiceTests
{
    // --- Helpers ---

    private static Mock<IHiddenPlaceRepository> MockRepo()
    {
        var repo = new Mock<IHiddenPlaceRepository>();
        // Default: any submission fetched by id returns a valid submission owned by userId=1.
        repo.Setup(r => r.GetByIdAsync(It.IsAny<string>()))
            .ReturnsAsync(new PlaceSubmission
            {
                SubmissionId = "sub-1",
                Status = RecommendedPlaceStatus.UnderVoting,
                SubmitterId = 1,
                RecommendPlaceId = "rec-1",
                Place = new RecommendPlace
                {
                    Name = "Test Place",
                    PrimaryType = "Cafe",
                    Latitude = 3.14,
                    Longitude = 101.69,
                },
            });
        // Primary Types must contain the types the form accepts, or the validation
        // guard ("Primary Type 'Cafe' is not supported") rejects valid submissions.
        repo.Setup(r => r.GetDistinctPrimaryTypesAsync()).ReturnsAsync(new List<string> { "Cafe", "Restaurant" });
        return repo;
    }

    private static Mock<IHiddenPlaceSuppressionRepository> MockSuppression()
    {
        var supp = new Mock<IHiddenPlaceSuppressionRepository>();
        // Default: no duplicate report exists, no report count
        supp.Setup(s => s.ExistsAsync(It.IsAny<int>(), It.IsAny<string>())).ReturnsAsync(false);
        supp.Setup(s => s.GetReportCountByPlaceIdAsync(It.IsAny<string>())).ReturnsAsync(0);
        return supp;
    }

    private static HiddenPlaceContributionService CreateService(
        IHiddenPlaceRepository? repo = null,
        IHiddenPlaceSuppressionRepository? suppression = null,
        IStorageClient? storage = null)
    {
        return new HiddenPlaceContributionService(
            repo ?? MockRepo().Object,
            suppression ?? MockSuppression().Object,
            storage ?? Mock.Of<IStorageClient>(),
            NullLogger<HiddenPlaceContributionService>.Instance);
    }

    private static SubmitRecommendedPlaceRequestDto SubmitDto(string name = "New Place")
        => new() { Name = name, PrimaryType = "Cafe", Latitude = 3.14m, Longitude = 101.69m };

    // ============================================================
    // SECURITY GUARDS
    // ============================================================

    [Fact]
    public async Task ToggleVerification_Self_Throws_Forbidden()
    {
        // Submitter (userId=1) tries to verify their own submission.
        var svc = CreateService();
        await Assert.ThrowsAsync<ForbiddenException>(() =>
            svc.ToggleVerificationAsync(1, "sub-1", verify: true));
    }

    [Fact]
    public async Task ToggleVerification_Withdraw_Without_Existing_Throws_Validation()
    {
        // Non-submitter (userId=2) tries to withdraw a verification they never cast.
        // There is no active verification row, so the service rejects with Validation.
        var svc = CreateService();
        await Assert.ThrowsAsync<ValidationException>(() =>
            svc.ToggleVerificationAsync(2, "sub-1", verify: false));
    }

    // ============================================================
    // REPORT GUARDS
    // ============================================================

    [Fact]
    public async Task ReportPlace_Duplicate_Throws_Conflict()
    {
        var supp = MockSuppression();
        supp.Setup(s => s.ExistsAsync(It.IsAny<int>(), It.IsAny<string>())).ReturnsAsync(true);
        var svc = CreateService(suppression: supp.Object);
        await Assert.ThrowsAsync<ConflictException>(() =>
            svc.ReportPlaceAsync(2, "sub-1", "Incorrect location"));
    }

    [Fact]
    public async Task ReportPlace_Owner_Cannot_Report_Own_Throws_Forbidden()
    {
        // Submitter/OWNER (userId=1) tries to report their own recommendation.
        // Owner restriction (R9): owners manage their own recommendation via
        // Withdraw Recommendation — never via Place Report.
        var svc = CreateService();
        await Assert.ThrowsAsync<ForbiddenException>(() =>
            svc.ReportPlaceAsync(1, "sub-1", "Incorrect location"));
    }

    [Fact]
    public async Task ReportPlace_Withdrawn_Throws_Validation()
    {
        var repo = MockRepo();
        repo.Setup(r => r.GetByIdAsync("sub-1"))
            .ReturnsAsync(new PlaceSubmission
            {
                SubmissionId = "sub-1",
                Status = RecommendedPlaceStatus.Withdrawn,
                SubmitterId = 1,
                RecommendPlaceId = "rec-1",
            });
        var svc = CreateService(repo: repo.Object);
        await Assert.ThrowsAsync<ValidationException>(() =>
            svc.ReportPlaceAsync(2, "sub-1", "Incorrect location"));
    }

    [Fact]
    public async Task ReportPlace_Empty_Reason_Throws_Validation()
    {
        var svc = CreateService();
        await Assert.ThrowsAsync<ValidationException>(() =>
            svc.ReportPlaceAsync(2, "sub-1", ""));
    }

    [Fact]
    public async Task ReportPlace_Threshold_Promotes_To_ReportedClosed()
    {
        var repo = MockRepo();
        var supp = MockSuppression();
        supp.Setup(s => s.ExistsAsync(It.IsAny<int>(), It.IsAny<string>())).ReturnsAsync(false);
        // Set report count above the hide threshold
        supp.Setup(s => s.GetReportCountByPlaceIdAsync(It.IsAny<string>())).ReturnsAsync(
            RecommendedPlaceThresholds.HideThreshold + 1);
        supp.Setup(s => s.RecordReportAsync(It.IsAny<int>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync(new HiddenPlaceSuppression { PlaceId = "rec-1" });

        var svc = CreateService(repo: repo.Object, suppression: supp.Object);
        var result = await svc.ReportPlaceAsync(2, "sub-1", "Incorrect location");

        Assert.NotNull(result);
        Assert.Equal("sub-1", result.SubmissionId);
        // The submission status should have been updated to REPORTED_CLOSED
        repo.Verify(r => r.UpdateSubmissionAsync(It.Is<PlaceSubmission>(s => s.Status == RecommendedPlaceStatus.ReportedClosed)));
        Assert.Equal(RecommendedPlaceStatus.ReportedClosed, result.PlaceStatus);
    }

    // ============================================================
    // SUBMIT & UPDATE
    // ============================================================

    [Fact]
    public async Task SubmitPlace_Requires_NonEmpty_Name()
    {
        var svc = CreateService();
        await Assert.ThrowsAsync<ValidationException>(() => svc.SubmitPlaceAsync(1, SubmitDto(name: "")));
    }

    [Fact]
    public async Task SubmitPlace_Requires_NonEmpty_PrimaryType()
    {
        var svc = CreateService();
        await Assert.ThrowsAsync<ValidationException>(() => svc.SubmitPlaceAsync(1,
            new SubmitRecommendedPlaceRequestDto { Name = "Valid", PrimaryType = "" }));
    }

    [Fact]
    public async Task SubmitPlace_Requires_Supported_PrimaryType()
    {
        // "NonsenseType" is not in the mocked GetDistinctPrimaryTypesAsync result.
        var svc = CreateService();
        await Assert.ThrowsAsync<ValidationException>(() => svc.SubmitPlaceAsync(1,
            new SubmitRecommendedPlaceRequestDto { Name = "Valid", PrimaryType = "NonsenseType" }));
    }

    [Fact]
    public async Task UpdateRecommendation_NonOwner_Throws_Forbidden()
    {
        var svc = CreateService();
        await Assert.ThrowsAsync<ForbiddenException>(() =>
            svc.UpdateRecommendationAsync(2, "sub-1", SubmitDto()));
    }

    [Fact]
    public async Task UpdateRecommendation_Owner_Succeeds()
    {
        var repo = MockRepo();
        repo.Setup(r => r.GetByIdAsync("sub-1"))
            .ReturnsAsync(new PlaceSubmission
            {
                SubmissionId = "sub-1",
                Status = RecommendedPlaceStatus.UnderVoting,
                SubmitterId = 1,
                RecommendPlaceId = "rec-1",
                Place = new RecommendPlace { Name = "Old", PrimaryType = "Cafe", Latitude = 3.14, Longitude = 101.69 },
            });
        var svc = CreateService(repo: repo.Object);
        var result = await svc.UpdateRecommendationAsync(1, "sub-1", SubmitDto(name: "Updated"));
        Assert.NotNull(result);
        Assert.Equal("sub-1", result.SubmissionId);
        // Repository receives the edited canonical place + the submission (2 args).
        repo.Verify(r => r.UpdateRecommendationAsync(It.IsAny<RecommendPlace>(), It.IsAny<PlaceSubmission>()));
    }

    // ============================================================
    // WITHDRAWAL GUARDS (OWNER ONLY)
    // ============================================================

    [Fact]
    public async Task WithdrawRecommendation_Owner_Succeeds()
    {
        // OWNER (userId=1) withdraws their own recommendation.
        var repo = MockRepo();
        var svc = CreateService(repo: repo.Object);
        var result = await svc.WithdrawRecommendationAsync(1, "sub-1");

        Assert.NotNull(result);
        Assert.Equal("sub-1", result.SubmissionId);
        // Repository must have updated the submission to WITHDRAWN.
        repo.Verify(r => r.UpdateSubmissionAsync(It.Is<PlaceSubmission>(s =>
            s.Status == RecommendedPlaceStatus.Withdrawn)));
    }

    [Fact]
    public async Task WithdrawRecommendation_NonOwner_Throws_Forbidden()
    {
        // Non-owner (userId=2) tries to withdraw another user's recommendation.
        var svc = CreateService();
        await Assert.ThrowsAsync<ForbiddenException>(() =>
            svc.WithdrawRecommendationAsync(2, "sub-1"));
    }

    [Fact]
    public async Task WithdrawRecommendation_AlreadyWithdrawn_Throws_Validation()
    {
        // Owner tries to withdraw a recommendation that is already WITHDRAWN.
        var repo = MockRepo();
        repo.Setup(r => r.GetByIdAsync("sub-1"))
            .ReturnsAsync(new PlaceSubmission
            {
                SubmissionId = "sub-1",
                Status = RecommendedPlaceStatus.Withdrawn,
                SubmitterId = 1,
                RecommendPlaceId = "rec-1",
            });
        var svc = CreateService(repo: repo.Object);
        await Assert.ThrowsAsync<ValidationException>(() =>
            svc.WithdrawRecommendationAsync(1, "sub-1"));
    }

    [Fact]
    public async Task WithdrawRecommendation_ReportedClosed_Throws_Validation()
    {
        // Owner tries to withdraw a recommendation that was REPORTED_CLOSED.
        var repo = MockRepo();
        repo.Setup(r => r.GetByIdAsync("sub-1"))
            .ReturnsAsync(new PlaceSubmission
            {
                SubmissionId = "sub-1",
                Status = RecommendedPlaceStatus.ReportedClosed,
                SubmitterId = 1,
                RecommendPlaceId = "rec-1",
            });
        var svc = CreateService(repo: repo.Object);
        await Assert.ThrowsAsync<ValidationException>(() =>
            svc.WithdrawRecommendationAsync(1, "sub-1"));
    }
}