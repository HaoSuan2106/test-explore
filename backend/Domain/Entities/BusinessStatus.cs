namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// The closed set of business statuses shared by every layer that reasons about them:
/// the contribution-service whitelist, the EF default value, the discovery quality-gate
/// options, and the entity defaults. A new status (e.g. PERMANENTLY_CLOSED) is added in
/// exactly one place.
/// </summary>
public static class BusinessStatus
{
    public const string Operational = "OPERATIONAL";
    public const string ClosedTemporarily = "CLOSED_TEMPORARILY";

    /// <summary>
    /// Statuses accepted when submitting/updating a recommended place.
    /// </summary>
    public static readonly IReadOnlyList<string> Allowed =
    [
        Operational,
        ClosedTemporarily,
    ];

    public static bool IsAllowed(string? status)
        => Allowed.Contains(status ?? string.Empty, StringComparer.OrdinalIgnoreCase);
}
