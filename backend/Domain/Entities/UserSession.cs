namespace ExploreMy.Api.Domain.Entities;

public class UserSession
{
    public int SessionId { get; set; }
    public int UserId { get; set; }
    public string SessionToken { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
    public bool IsActive { get; set; }
}
