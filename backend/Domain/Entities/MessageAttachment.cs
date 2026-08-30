namespace ExploreMy.Api.Domain.Entities;

public class MessageAttachment
{
    public int AttachmentId { get; set; }
    public int MessageId { get; set; }
    public string Type { get; set; } = string.Empty; // "Image" | "PlaceShare" | "PostShare"

    // "Image" attachments
    public string? MediaUrl { get; set; }

    // "PlaceShare" attachments (Hidden Place Discovery). PlaceId is a Google
    // place_id or a community submissionId (string either way); PlaceSource
    // ("GOOGLE" | "COMMUNITY") says which, so a tap knows how to reopen it.
    // ShareDataJson is only set for a GOOGLE place: a snapshot of the
    // PlaceData taken at share time, since Google-sourced places have no
    // "fetch by id" route to reopen live the way a COMMUNITY place does.
    public string? PlaceId { get; set; }
    public string? PlaceSource { get; set; }
    public string? ShareDataJson { get; set; }
    public string? PlaceName { get; set; }
    public string? PlaceAddress { get; set; }
    public string? PlaceImageUrl { get; set; }
    public string? PlaceStatus { get; set; }

    // "PostShare" attachments (Post Feed). Reopens live via Post Review's own
    // /post/details/:id route, so no snapshot is needed here.
    public string? PostId { get; set; }
}
