namespace ExploreMy.Api.Domain.Entities;

public class CommunityMember
{
    public int CommunityMemberId { get; set; }
    public int CommunityId { get; set; }
    public int UserId { get; set; }
    public string Role { get; set; } = "Member"; // "Member" | "Moderator"
    public bool IsActive { get; set; } = true;
    public DateTime JoinedAt { get; set; }
    public DateTime? LeftAt { get; set; }
}
