using Microsoft.EntityFrameworkCore;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.Persistence.DbContext;
using CommunityEntity = ExploreMy.Api.Domain.Entities.Community;

namespace ExploreMy.Api.DataAccess.Repositories.Community;

public class CommunityMySqlRepository : ICommunityRepository
{
    private readonly MySqlDbContext _context;
    private readonly ILogger<CommunityMySqlRepository> _logger;

    public CommunityMySqlRepository(MySqlDbContext context, ILogger<CommunityMySqlRepository> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<List<CommunityEntity>> SearchCommunitiesAsync(string? keyword, string? state = null)
    {
        try
        {
            var query = _context.Communities.AsQueryable();
            if (!string.IsNullOrWhiteSpace(keyword))
            {
                var trimmed = keyword.Trim();
                query = query.Where(c => c.Name.Contains(trimmed) || (c.Area != null && c.Area.Contains(trimmed)));
            }
            if (!string.IsNullOrWhiteSpace(state))
            {
                var trimmedState = state.Trim();
                query = query.Where(c => c.State != null && c.State == trimmedState);
            }
            return await query.OrderBy(c => c.Name).ToListAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error searching communities with keyword '{Keyword}' and state '{State}'.", keyword, state);
            throw;
        }
    }

    public async Task<List<CommunityEntity>> GetJoinedCommunitiesAsync(int userId)
    {
        try
        {
            var communityIds = await _context.CommunityMembers
                .Where(m => m.UserId == userId && m.IsActive)
                .Select(m => m.CommunityId)
                .ToListAsync();

            return await _context.Communities
                .Where(c => communityIds.Contains(c.CommunityId))
                .ToListAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error fetching joined communities for user {UserId}.", userId);
            throw;
        }
    }

    public async Task<CommunityEntity?> GetCommunityByIdAsync(int communityId)
    {
        try
        {
            return await _context.Communities.FirstOrDefaultAsync(c => c.CommunityId == communityId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error fetching community {CommunityId}.", communityId);
            throw;
        }
    }

    public async Task<int> GetMemberCountAsync(int communityId)
    {
        try
        {
            return await _context.CommunityMembers.CountAsync(m => m.CommunityId == communityId && m.IsActive);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error counting members of community {CommunityId}.", communityId);
            throw;
        }
    }

    public async Task<CommunityMember?> GetMembershipAsync(int communityId, int userId)
    {
        try
        {
            return await _context.CommunityMembers
                .FirstOrDefaultAsync(m => m.CommunityId == communityId && m.UserId == userId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error fetching membership for community {CommunityId}, user {UserId}.", communityId, userId);
            throw;
        }
    }

    public async Task AddMemberAsync(CommunityMember member)
    {
        try
        {
            _context.CommunityMembers.Add(member);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error adding member for community {CommunityId}, user {UserId}.", member.CommunityId, member.UserId);
            throw;
        }
    }

    public async Task ReactivateMemberAsync(CommunityMember member)
    {
        try
        {
            // NOTE: no _context.CommunityMembers.Add(member) here on purpose — `member`
            // was loaded from the database (by GetMembershipAsync) and is already tracked
            // with its real primary key. Calling Add() on it would flip its EF state to
            // Added and produce an INSERT with that existing id, colliding on the primary
            // key (this was the "Duplicate entry for key community_member.PRIMARY" bug).
            // Just mutating the tracked entity and calling SaveChangesAsync is enough for
            // EF to generate the correct UPDATE.
            member.IsActive = true;
            member.LeftAt = null;
            member.JoinedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error reactivating member for community {CommunityId}, user {UserId}.", member.CommunityId, member.UserId);
            throw;
        }
    }

    public async Task RemoveMemberAsync(CommunityMember member)
    {
        try
        {
            member.IsActive = false;
            member.LeftAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error removing member for community {CommunityId}, user {UserId}.", member.CommunityId, member.UserId);
            throw;
        }
    }

    public async Task<List<CommunityMember>> GetActiveMembersAsync(int communityId)
    {
        try
        {
            return await _context.CommunityMembers
                .Where(m => m.CommunityId == communityId && m.IsActive)
                .ToListAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error fetching active members of community {CommunityId}.", communityId);
            throw;
        }
    }

    public async Task AddMessageAsync(Message message)
    {
        try
        {
            _context.Messages.Add(message);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error adding message to community {CommunityId}.", message.CommunityId);
            throw;
        }
    }

    public async Task<Message?> GetMessageByIdAsync(int messageId)
    {
        try
        {
            return await _context.Messages.FirstOrDefaultAsync(m => m.MessageId == messageId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error fetching message {MessageId}.", messageId);
            throw;
        }
    }

    public async Task<Message?> GetLastMessageAsync(int communityId)
    {
        try
        {
            return await _context.Messages
                .Where(m => m.CommunityId == communityId && !m.IsDeleted)
                .OrderByDescending(m => m.SentAt)
                .FirstOrDefaultAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error fetching the last message of community {CommunityId}.", communityId);
            throw;
        }
    }

    public async Task<List<Message>> GetRecentMessagesAsync(int communityId, int take, int? beforeMessageId)
    {
        try
        {
            var query = _context.Messages.Where(m => m.CommunityId == communityId && !m.IsDeleted);

            if (beforeMessageId.HasValue)
            {
                query = query.Where(m => m.MessageId < beforeMessageId.Value);
            }

            var messages = await query
                .OrderByDescending(m => m.SentAt)
                .Take(take)
                .ToListAsync();

            messages.Reverse(); // oldest-first for display
            return messages;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error fetching recent messages for community {CommunityId}.", communityId);
            throw;
        }
    }

    public async Task<List<Message>> SearchMessagesAsync(int communityId, string keyword)
    {
        try
        {
            return await _context.Messages
                .Where(m => m.CommunityId == communityId && !m.IsDeleted && m.Content != null && m.Content.Contains(keyword))
                .OrderByDescending(m => m.SentAt)
                .ToListAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error searching messages in community {CommunityId}.", communityId);
            throw;
        }
    }

    public async Task SoftDeleteMessageAsync(Message message)
    {
        try
        {
            message.IsDeleted = true;
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error deleting message {MessageId}.", message.MessageId);
            throw;
        }
    }

    public async Task AddAttachmentsAsync(IEnumerable<MessageAttachment> attachments)
    {
        try
        {
            _context.MessageAttachments.AddRange(attachments);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error adding message attachments.");
            throw;
        }
    }

    public async Task UpdateAttachmentAsync(MessageAttachment attachment)
    {
        try
        {
            // The instance passed in is the same one AddAttachmentsAsync just
            // inserted within this request's DbContext, so it's already
            // tracked — the caller only mutated MediaUrl, and SaveChangesAsync
            // is enough to persist that (no .Update()/.Add() needed, same
            // reasoning as ReactivateMemberAsync above).
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error updating attachment {AttachmentId}.", attachment.AttachmentId);
            throw;
        }
    }

    public async Task<List<MessageAttachment>> GetAttachmentsForMessagesAsync(IEnumerable<int> messageIds)
    {
        try
        {
            var ids = messageIds.ToList();
            if (ids.Count == 0) return new List<MessageAttachment>();

            return await _context.MessageAttachments
                .Where(a => ids.Contains(a.MessageId))
                .ToListAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error fetching attachments for messages.");
            throw;
        }
    }

    public async Task<bool> HasReportedAsync(int messageId, int reporterUserId)
    {
        try
        {
            return await _context.MessageReports
                .AnyAsync(r => r.MessageId == messageId && r.ReporterUserId == reporterUserId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error checking existing report for message {MessageId}.", messageId);
            throw;
        }
    }

    public async Task AddMessageReportAsync(MessageReport report)
    {
        try
        {
            _context.MessageReports.Add(report);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error adding a report for message {MessageId}.", report.MessageId);
            throw;
        }
    }
}
