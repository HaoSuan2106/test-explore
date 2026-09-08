using System;

namespace ExploreMy.Api.Common.Helpers;

/// <summary>
/// Explicit Malaysia (Asia/Kuala_Lumpur, UTC+08:00) time helper.
///
/// Storage contract (app-wide, D-06): every DB write uses <c>DateTime.UtcNow</c> and
/// DATETIME(6) columns hold UTC wall-clock. This helper is therefore the API
/// PRESENTATION converter: <see cref="FromUtc"/> turns a stored UTC instant into
/// Malaysia wall-clock for MalaysiaLocalDateTimeConverter, which emits the explicit
/// "+08:00" offset. (It previously produced the DB write value for
/// place_submissions; that contract was unified to UTC — see the audit report
/// validation_evidence/DATETIME_TIMEZONE_AUDIT_IMPLEMENTATION.md.)
///
/// No hard-coded +8 arithmetic anywhere: the offset always comes from the
/// resolved <see cref="TimeZoneInfo"/> for the zone.
/// </summary>
public static class MalaysiaTime
{
    private static readonly TimeZoneInfo ZoneValue = ResolveZone();

    /// <summary>The resolved Asia/Kuala_Lumpur timezone (Windows: "Singapore Standard Time").</summary>
    public static TimeZoneInfo Zone => ZoneValue;

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
