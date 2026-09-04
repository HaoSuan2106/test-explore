// The "Community" alias below avoids a compiler error (CS0118): this file's own
// namespace ends in "...Repositories.Community", so an unqualified reference to
// the `Community` entity type resolves to this namespace segment instead of the
// entity, unless we alias it explicitly.
using CommunityEntity = ExploreMy.Api.Domain.Entities.Community;
using ExploreMy.Api.Domain.Entities;

namespace ExploreMy.Api.DataAccess.Repositories.Community;

public interface ICommunityRepository
{
    Task<List<CommunityEntity>> SearchCommunitiesAsync(string? keyword, string? state = null);
    Task<List<CommunityEntity>> GetJoinedCommunitiesAsync(int userId);
    Task<CommunityEntity?> GetCommunityByIdAsync(int communityId);
    Task<int> GetMemberCountAsync(int communityId);
    Task<CommunityMember?> GetMembershipAsync(int communityId, int userId);
    Task AddMemberAsync(CommunityMember member);
    Task ReactivateMemberAsync(CommunityMember member);
    Task RemoveMemberAsync(CommunityMember member);
    Task<List<CommunityMember>> GetActiveMembersAsync(int communityId);

    Task AddMessageAsync(Message message);
    Task<Message?> GetMessageByIdAsync(int messageId);
    Task<Message?> GetLastMessageAsync(int communityId);
    Task<List<Message>> GetRecentMessagesAsync(int communityId, int take, int? beforeMessageId);
    Task<List<Message>> SearchMessagesAsync(int communityId, string keyword);
    Task SoftDeleteMessageAsync(Message message);

    Task AddAttachmentsAsync(IEnumerable<MessageAttachment> attachments);
    Task<List<MessageAttachment>> GetAttachmentsForMessagesAsync(IEnumerable<int> messageIds);
    Task UpdateAttachmentAsync(MessageAttachment attachment);

    Task<bool> HasReportedAsync(int messageId, int reporterUserId);
    Task AddMessageReportAsync(MessageReport report);
}
