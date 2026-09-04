using System.Linq.Expressions;

namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// Single source of truth for "what counts as engagement" on a community post (V-08).
///
/// D2: popularity = number of ACTIVE likes + number of ACTIVE comments.
///
/// The formula lives here (a domain concept) so a change to the engagement definition
/// is one edit in the domain, not a hunt through the repository. The repository applies
/// <see cref="Popularity"/> mechanically via <see cref="OrderByPopularityInRange"/>, which
/// stays EF-translatable so pagination still happens in SQL.
/// </summary>
public static class PostEngagement
{
    /// <summary>
    /// The popularity metric: count of ACTIVE reactions (likes) plus count of ACTIVE
    /// comments. Reused for both the min/max engagement range filter and the descending
    /// popularity ordering.
    /// </summary>
    public static Expression<Func<Post, int>> Popularity { get; } =
        p => p.Reactions.Count(r => r.Status == PostReactionStatus.Active)
           + p.Comments.Count(c => c.Status == PostCommentStatus.Active);

    /// <summary>
    /// Orders <paramref name="source"/> by <see cref="Popularity"/> descending (ties by
    /// CreatedAt descending) and, when a min/max engagement range is given, keeps only
    /// posts whose engagement falls inside that range. Built as an EF-translatable
    /// expression composition from the canonical formula.
    /// </summary>
    public static IQueryable<Post> OrderByPopularityInRange(
        IQueryable<Post> source, int? minEngagement, int? maxEngagement)
    {
        var param = Expression.Parameter(typeof(Post), "p");
        var popularityBody = new ReplaceParameterVisitor(Popularity.Parameters[0], param)
            .Visit(Popularity.Body);

        Expression? rangeFilter = null;
        if (minEngagement is not null)
        {
            rangeFilter = Expression.GreaterThanOrEqual(
                popularityBody, Expression.Constant(minEngagement.Value));
        }

        if (maxEngagement is not null)
        {
            var upper = Expression.LessThanOrEqual(
                popularityBody, Expression.Constant(maxEngagement.Value));
            rangeFilter = rangeFilter is null ? upper : Expression.AndAlso(rangeFilter, upper);
        }

        var ordered = source.OrderByDescending(Popularity).ThenByDescending(p => p.CreatedAt);
        return rangeFilter is null
            ? ordered
            : ordered.Where(Expression.Lambda<Func<Post, bool>>(rangeFilter, param));
    }

    /// <summary>Rewrites the body of the canonical formula to reference a fresh parameter.</summary>
    private sealed class ReplaceParameterVisitor(ParameterExpression from, Expression to) : ExpressionVisitor
    {
        protected override Expression VisitParameter(ParameterExpression node)
            => node == from ? to : base.VisitParameter(node);
    }
}
