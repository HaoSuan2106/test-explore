using ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;
using ExploreMy.Api.Application.HiddenPlace.PlacePhotos;
using ExploreMy.Api.DataAccess.ExternalClients.GooglePlaces;
using ExploreMy.Api.DataAccess.Repositories.HiddenPlace;
using ExploreMy.Api.Domain.Entities;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;

namespace ExploreMy.Api.Tests;

/// <summary>
/// UNIT tests for the hidden-gem discovery algorithm (the pure-computation core of
/// DiscoverHiddenPlaceService.Discover / PassesQualityGate). No database or network involved.
/// </summary>
public class DiscoverHiddenPlaceServiceTests
{
    private static DiscoverHiddenPlaceService CreateService()
    {
        // The algorithm methods under test (Discover / PassesQualityGate) do not use the injected
        // collaborators; mocks stand in purely so the service can be constructed.
        return new DiscoverHiddenPlaceService(
            Mock.Of<IHiddenPlaceRepository>(),
            NullLogger<DiscoverHiddenPlaceService>.Instance);
    }

    private static PlaceCandidate Place(
        string id, string name, string primaryType = "restaurant",
        double? rating = 4.5, int ratingCount = 100,
        string businessStatus = "OPERATIONAL")
        => new()
        {
            PlaceId = id,
            Name = name,
            PrimaryType = primaryType,
            Latitude = 3.14,
            Longitude = 101.69,
            Rating = rating,
            UserRatingCount = ratingCount,
            BusinessStatus = businessStatus,
        };

    [Fact]
    public void Discover_Empty_Input_Returns_Empty()
    {
        var svc = CreateService();
        var result = svc.Discover([]);
        Assert.Empty(result);
    }

    [Fact]
    public void Discover_Drops_Closed_Places()
    {
        var svc = CreateService();
        var candidates = new[]
        {
            Place("p1", "Open Cafe", businessStatus: "OPERATIONAL"),
            Place("p2", "Closed Shop", businessStatus: "CLOSED_PERMANENTLY"),
        };
        var result = svc.Discover(candidates);
        Assert.Single(result);
        Assert.Equal("p1", result[0].Place.PlaceId);
    }

    [Fact]
    public void Discover_Drops_Below_Min_Rating()
    {
        var svc = CreateService();
        var candidates = new[]
        {
            Place("p1", "Good Place", rating: 4.9, ratingCount: 50),
            Place("p2", "Poor Place", rating: 2.5, ratingCount: 80),
        };
        var result = svc.Discover(candidates);
        Assert.Single(result);
        Assert.Equal("p1", result[0].Place.PlaceId);
    }

    [Fact]
    public void Discover_Drops_Chain_Brands()
    {
        var svc = CreateService();
        var candidates = new[]
        {
            Place("p1", "Starbucks Reserve", rating: 4.7, ratingCount: 30),
            Place("p2", "Local Kopitiam", rating: 4.7, ratingCount: 30),
        };
        var result = svc.Discover(candidates);
        Assert.Single(result);
        Assert.Equal("p2", result[0].Place.PlaceId);
    }

    [Fact]
    public void Discover_Enforces_Max_User_Rating_Count_Ceiling()
    {
        var svc = CreateService();
        var options = new DiscoverHiddenPlaceOptions
        {
            MaxUserRatingCount = 100,
            MaxUserRatingPercentile = 1.0, // percentile ceiling off
        };
        var candidates = new[]
        {
            Place("p1", "Famous Place", rating: 4.8, ratingCount: 5000),
            Place("p2", "Obscure Place", rating: 4.5, ratingCount: 40),
        };
        var result = svc.Discover(candidates, options);
        Assert.Single(result);
        Assert.Equal("p2", result[0].Place.PlaceId);
    }

    [Fact]
    public void Discover_Ranks_More_Obscure_Higher()
    {
        var svc = CreateService();
        var options = new DiscoverHiddenPlaceOptions
        {
            MaxUserRatingCount = 10_000,
            MaxUserRatingPercentile = 1.0,
        };
        var candidates = new[]
        {
            Place("famous", "Well Known", rating: 4.9, ratingCount: 9000),
            Place("obscure", "Hidden Gem", rating: 4.6, ratingCount: 25),
        };
        var result = svc.Discover(candidates, options);
        Assert.Equal(2, result.Count);
        // The obscure place (fewer reviews) should outrank the famous one.
        Assert.Equal("obscure", result[0].Place.PlaceId);
        Assert.True(result[0].HiddenScore > result[1].HiddenScore);
    }

    [Fact]
    public void Discover_All_Scores_Within_Zero_One()
    {
        var svc = CreateService();
        var candidates = Enumerable.Range(1, 20)
            .Select(i => Place($"p{i}", $"Place {i}", rating: 3.8 + (i % 12) * 0.1, ratingCount: i * 7))
            .ToList();
        var result = svc.Discover(candidates);
        Assert.NotEmpty(result);
        foreach (var r in result)
        {
            Assert.InRange(r.HiddenScore, 0.0, 1.0);
            Assert.InRange(r.PopularityNorm, 0.0, 1.0);
            Assert.InRange(r.RatingNorm, 0.0, 1.0);
        }
    }

    [Fact]
    public void Discover_Result_Is_Sorted_By_Score_Descending()
    {
        var svc = CreateService();
        var candidates = Enumerable.Range(1, 15)
            .Select(i => Place($"p{i}", $"Place {i}", rating: 4.0 + (i % 8) * 0.1, ratingCount: i * 10))
            .ToList();
        var result = svc.Discover(candidates);
        for (var i = 1; i < result.Count; i++)
        {
            Assert.True(result[i - 1].HiddenScore >= result[i].HiddenScore,
                $"Result {i - 1} ({result[i - 1].HiddenScore}) must be >= result {i} ({result[i].HiddenScore}).");
        }
    }

    [Fact]
    public void PassesQualityGate_Rejects_Closed_And_Unrated()
    {
        var svc = CreateService();
        Assert.False(svc.PassesQualityGate(Place("c1", "Closed", businessStatus: "CLOSED_TEMPORARILY")));
        Assert.False(svc.PassesQualityGate(Place("c2", "No Rating", rating: null, ratingCount: 0)));
        Assert.True(svc.PassesQualityGate(Place("c3", "Normal Place", rating: 4.3, ratingCount: 25)));
    }

    [Fact]
    public void PassesQualityGate_Rejects_Chain_Keyword()
    {
        var svc = CreateService();
        Assert.False(svc.PassesQualityGate(Place("c1", "Old Town White Coffee", rating: 4.4, ratingCount: 100)));
    }
}