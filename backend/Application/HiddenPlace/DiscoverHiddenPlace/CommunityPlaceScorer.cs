using ExploreMy.Api.Domain.Entities;

namespace ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;

/// <summary>Tunables for <see cref="CommunityPlaceScorer"/>. Mirrors DiscoverHiddenPlaceOptions in spirit.</summary>
public class CommunityPlaceScoringOptions
{
    /// <summary>
    /// Weight of the obscurity term, which is a CONSTANT 1 for every community place - see
    /// CommunityPlaceScorer.Score. It therefore does not rank anything; it sets the floor these
    /// places start from, and the remaining weights decide the order among them.
    /// </summary>
    public double ObscurityWeight { get; init; } = 0.5;

    /// <summary>Weight of what our reviewers think of the place.</summary>
    public double QualityWeight { get; init; } = 0.3;

    /// <summary>Weight of how many people have verified the recommendation is real.</summary>
    public double VerificationWeight { get; init; } = 0.2;

    /// <summary>
    /// Same rating floor the Google algorithm uses (DiscoverHiddenPlaceOptions.MinRating), so the two
    /// quality terms mean the same thing on the same 0-1 scale. Not a filter here: a community place
    /// rated below it scores badly rather than disappearing, because a recommendation people
    /// disliked is still a real place someone stood at.
    /// </summary>
    public double MinRating { get; init; } = 3.8;

    /// <summary>
    /// How many reviews it takes before a rating is taken at close to face value. With a handful of
    /// reviewers, one 5.0 is an opinion, not a measurement - so the score is pulled toward
    /// <see cref="NeutralQuality"/> in proportion to how thin the evidence is (a standard shrinkage
    /// estimate). At 3: one review carries 1/4 of its face value, three carry half, twenty carry 87%.
    ///
    /// This is what stops a just-submitted place with a single 5-star review from topping the list -
    /// the failure mode MinUserRatingCount's doc comment describes on the Google side.
    /// </summary>
    public int ConfidenceReviews { get; init; } = 3;

    /// <summary>
    /// The quality score for a place with no evidence either way. 0.5 rather than 0: an unreviewed
    /// recommendation is unknown, not bad, and scoring it as bad would bury every new submission
    /// under older ones purely for being new.
    /// </summary>
    public double NeutralQuality { get; init; } = 0.5;
}

/// <summary>
/// One place's community score, in the same 0-1 shape HiddenPlaceResult uses so the DTO can carry
/// either without the client needing to tell them apart.
/// </summary>
public sealed record CommunityPlaceScore(
    double HiddenScore,
    double ObscurityScore,
    double QualityScore,
    double VerificationScore);

/// <summary>
/// Scoring for community (user-recommended) places - the counterpart to DiscoverHiddenPlaceService,
/// which cannot be reused here because every input it needs is missing.
///
/// A community place has no Google rating, no Google review count, and no position in the local
/// review-count distribution the hidden-gem score is measured against. Feeding it zeros would not
/// score it badly, it would score it meaninglessly: NormalizeReviewCount(0) says "nobody knows this
/// place", which is exactly the same thing it says about a place Google has simply never heard of.
///
/// So the question is answered from what a community place actually has:
///
///   obscurity    - a constant 1. Not an estimate: a place that had to be typed in by hand is one
///                  Google's index does not carry as a findable result, which is the strongest form
///                  of "hidden" this app deals in. Every community place shares it, so it lifts them
///                  as a group and never orders them.
///   quality      - what our own reviewers rated it, shrunk toward neutral while the sample is thin
///                  (see ConfidenceReviews). With no reviews at all it falls back to the
///                  verification score: five strangers agreeing the place is real is the only
///                  evidence available, so it is what stands in.
///   verification - how far through verification it is, capped at the threshold. This is the term
///                  that separates "five people checked this" from "one person's word".
///
/// The result is comparable in scale to a Google HiddenScore but is NOT the same measurement, which
/// is why HiddenPlaceService still appends community places after the ranked Google list instead of
/// interleaving them. This orders them within their own section.
/// </summary>
public static class CommunityPlaceScorer
{
    public static CommunityPlaceScore Score(
        int verificationCount,
        int reviewCount,
        double? averageRating,
        CommunityPlaceScoringOptions? options = null)
    {
        options ??= new CommunityPlaceScoringOptions();

        const double obscurity = 1.0;

        var verification = Math.Clamp(
            (double)verificationCount / RecommendedPlaceThresholds.RequiredVerifications, 0, 1);

        var quality = QualityScore(reviewCount, averageRating, verification, options);

        var hidden =
            (options.ObscurityWeight * obscurity) +
            (options.QualityWeight * quality) +
            (options.VerificationWeight * verification);

        return new CommunityPlaceScore(
            Math.Clamp(hidden, 0, 1),
            obscurity,
            quality,
            verification);
    }

    private static double QualityScore(
        int reviewCount, double? averageRating, double verification, CommunityPlaceScoringOptions options)
    {
        if (reviewCount <= 0 || averageRating is null)
        {
            // Nothing to read a rating from, so verification stands in - but CAPPED AT NEUTRAL, and
            // the cap is the whole point of the rule.
            //
            // Verification answers "is this place real", not "is this place good". Letting it score
            // above neutral would mean a fully-verified place nobody has reviewed beats a
            // fully-verified place people came back and rated 4.5 - the score would be rewarding the
            // absence of evidence. Below neutral it still separates "five people checked this" from
            // "one person's word", which is the ordering that was actually missing.
            return Math.Min(verification, options.NeutralQuality);
        }

        const double maxRating = 5.0;
        var ratingNorm = maxRating <= options.MinRating
            ? 1
            : Math.Clamp((averageRating.Value - options.MinRating) / (maxRating - options.MinRating), 0, 1);

        // Shrinkage: pull the rating toward neutral by however thin the sample is. See ConfidenceReviews.
        var confidence = (double)reviewCount / (reviewCount + Math.Max(1, options.ConfidenceReviews));

        return Math.Clamp(
            options.NeutralQuality + ((ratingNorm - options.NeutralQuality) * confidence), 0, 1);
    }
}
