namespace ExploreMy.Api.Domain.Entities;

public class Message
{
    public int MessageId { get; set; }
    public int CommunityId { get; set; }
    public int SenderUserId { get; set; }
    public string? Content { get; set; }
    public int? ReplyToMessageId { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime SentAt { get; set; }
}
