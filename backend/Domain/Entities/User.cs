namespace ExploreMy.Api.Domain.Entities;

public class User
{
    public int UserId { get; set; }
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    public string? ProfilePictureUrl { get; set; }
    public string? City { get; set; }
    public int? Age { get; set; }
    public string? Gender { get; set; }
    public string AccountStatus { get; set; } = "pending_verification";
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

}
