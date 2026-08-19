namespace ExploreMy.Api.Domain.Entities;

public class EmailVerificationToken
{
    public int TokenId { get; set; }
    public int UserId { get; set; }
    public string Token { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public bool IsUsed { get; set; }
    public DateTime CreatedAt { get; set; }

    /// <summary>
    /// The new email address awaiting confirmation, for email-change tokens.
    /// Null for registration verification tokens.
    /// </summary>
    public string? PendingEmail { get; set; }
}