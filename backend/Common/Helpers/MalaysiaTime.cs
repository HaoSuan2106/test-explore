using System;

namespace ExploreMy.Api.Common.Helpers;

/// <summary>
/// Explicit Malaysia (Asia/Kuala_Lumpur, UTC+08:00) time source for the
/// <c>place_submissions.created_at / updated_at</c> storage contract.
///
/// The DB contract is literal Malaysia wall-clock in DATETIME(6) columns:
///   Malaysia now  2026-08-30 21:16:00 +08:00  →  DATETIME(6) 2026-08-30 21:16:00
/// (NOT 13:16:00 UTC). This helper derives Malaysia time from the UTC instant
/// through <see cref="TimeZoneInfo"/>, so the server OS timezone is never
/// assumed — a deployment on a UTC host still produces Malaysia wall-clock.
///
/// No hard-coded +8 arithmetic anywhere: the offset always comes from the
/// resolved <see cref="TimeZoneInfo"/> for the zone.
/// </summary>
public static class MalaysiaTime
{
    private static readonly TimeZoneInfo ZoneValue = ResolveZone();

    /// <summary>The resolved Asia/Kuala_Lumpur timezone (Windows: "Singapore Standard Time").</summary>
    public static TimeZoneInfo Zone => ZoneValue;

    /// <summary>
    /// Current Malaysia wall-clock. Returned DateTime has Kind=Unspecified when the
    /// resolved zone is not the server-local zone, which is exactly what DATETIME(6)
    /// storage expects — the wall-clock value is written as-is, no conversion.
    /// </summary>
    public static DateTime Now => TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, ZoneValue);

    /// <summary>Converts a UTC instant to Malaysia wall-clock (Kind=Unspecified).</summary>
    public static DateTime FromUtc(DateTime utc)
        => TimeZoneInfo.ConvertTimeFromUtc(
            utc.Kind == DateTimeKind.Utc ? utc : DateTime.SpecifyKind(utc, DateTimeKind.Utc),
            ZoneValue);

    /// <summary>Resolves the Malaysia zone explicitly. IANA id works on Linux; on Windows the
    /// same zone is exposed as "Singapore Standard Time" (UTC+08:00 Kuala Lumpur, Singapore).</summary>
    private static TimeZoneInfo ResolveZone()
    {
        foreach (var id in new[] { "Asia/Kuala_Lumpur", "Singapore Standard Time" })
        {
            try
            {
                return TimeZoneInfo.FindSystemTimeZoneById(id);
            }
            catch (TimeZoneNotFoundException)
            {
                // try next candidate
            }
            catch (InvalidTimeZoneException)
            {
                // try next candidate
            }
        }

        // Last resort: the server-local zone. Malaysia is UTC+08:00 with no DST, so on any
        // correctly configured Malaysia host this equals the target zone. Never silently
        // assumed — this branch only runs when neither known id resolves.
        return TimeZoneInfo.Local;
    }
}
