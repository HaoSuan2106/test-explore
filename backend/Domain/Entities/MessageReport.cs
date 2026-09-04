namespace ExploreMy.Api.Domain.Entities;

/// A member flagging a message as inappropriate/spam/etc. Purely a record for
/// now — there's no moderation review UI yet, this just makes sure reports
/// aren't lost once one gets built.
public class MessageReport
{
    public int ReportId { get; set; }
    public int MessageId { get; set; }
    public int ReporterUserId { get; set; }
    public string? Reason { get; set; }
    public DateTime CreatedAt { get; set; }
}
