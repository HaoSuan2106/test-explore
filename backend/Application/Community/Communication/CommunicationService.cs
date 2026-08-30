using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.Configuration;
using ExploreMy.Api.DataAccess.ExternalClients.SupabaseStorage;
using ExploreMy.Api.DataAccess.Repositories.AuthProfile;
using ExploreMy.Api.DataAccess.Repositories.Community;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.Community;
using ExploreMy.Api.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Options;

namespace ExploreMy.Api.Application.Community.Communication;

public class CommunicationService : ICommunicationService
{
    private readonly ICommunityRepository _communityRepository;
    private readonly IAuthProfileRepository _authProfileRepository;
    private readonly IStorageClient _storageClient;
    private readonly SupabaseSettings _supabase;
    private readonly IHubContext<CommunityChatHub> _chatHub;
    private readonly ILogger<CommunicationService> _logger;

    public CommunicationService(
        ICommunityRepository communityRepository,
        IAuthProfileRepository authProfileRepository,
        IStorageClient storageClient,
        IOptions<SupabaseSettings> supabase,
        IHubContext<CommunityChatHub> chatHub,
        ILogger<CommunicationService> logger)
    {
        _communityRepository = communityRepository;
        _authProfileRepository = authProfileRepository;
        _storageClient = storageClient;
        _supabase = supabase.Value;
        _chatHub = chatHub;
        _logger = logger;
    }

    private static string GroupName(int communityId) => $"community-{communityId}";

    public async Task<List<MessageDto>> GetMessagesAsync(int communityId, int userId, int take, int? beforeMessageId)
    {
        await EnsureMemberAsync(communityId, userId);
        var messages = await _communityRepository.GetRecentMessagesAsync(communityId, take, beforeMessageId);
        return await MapMessagesAsync(messages);
    }

    public async Task<MessageDto> SendMessageAsync(SendMessageRequestDto request, int userId)
    {
        await EnsureMemberAsync(request.CommunityId, userId);

        var hasContent = !string.IsNullOrWhiteSpace(request.Content);
        var hasImages = request.ImageUrls is { Count: > 0 };
        var hasPlaces = request.SharedPlaces is { Count: > 0 };
        var hasPosts = request.SharedPosts is { Count: > 0 };
        if (!hasContent && !hasImages && !hasPlaces && !hasPosts)
        {
            throw new ArgumentException("A message needs text, an image, a shared place, or a shared post.");
        }

        if (request.ReplyToMessageId.HasValue)
        {
            var replyTarget = await _communityRepository.GetMessageByIdAsync(request.ReplyToMessageId.Value);
            if (replyTarget == null || replyTarget.CommunityId != request.CommunityId)
            {
                throw new ArgumentException("The message being replied to could not be found in this community.");
            }
        }

        var message = new Message
        {
            CommunityId = request.CommunityId,
            SenderUserId = userId,
            Content = hasContent ? request.Content!.Trim() : null,
            ReplyToMessageId = request.ReplyToMessageId,
            IsDeleted = false,
            SentAt = DateTime.UtcNow,
        };
        await _communityRepository.AddMessageAsync(message);

        var attachments = new List<MessageAttachment>();
        if (hasImages)
        {
            attachments.AddRange(request.ImageUrls!.Select(url => new MessageAttachment
            {
                MessageId = message.MessageId,
                Type = "Image",
                MediaUrl = url,
            }));
        }
        if (hasPlaces)
        {
            attachments.AddRange(request.SharedPlaces!.Select(p => new MessageAttachment
            {
                MessageId = message.MessageId,
                Type = "PlaceShare",
                PlaceId = p.PlaceId,
                PlaceSource = p.PlaceSource,
                ShareDataJson = p.ShareDataJson,
                PlaceName = p.PlaceName,
                PlaceAddress = p.PlaceAddress,
                PlaceImageUrl = p.PlaceImageUrl,
                PlaceStatus = p.PlaceStatus,
            }));
        }
        if (hasPosts)
        {
            attachments.AddRange(request.SharedPosts!.Select(p => new MessageAttachment
            {
                MessageId = message.MessageId,
                Type = "PostShare",
                PostId = p.PostId,
                PlaceName = p.PostTitle,
                PlaceAddress = p.PostLocation,
                PlaceImageUrl = p.PostImageUrl,
            }));
        }
        if (attachments.Count > 0)
        {
            // Assigns each attachment's real AttachmentId (auto-increment PK)
            // onto these same in-memory instances.
            await _communityRepository.AddAttachmentsAsync(attachments);

            // Now that the ids are known, move any uploaded images out of the
            // "pending" holding area (see UploadMessageImageAsync) into their
            // permanent, id-named path: community/{communityId}/{attachmentId}.
            // This organizes the Supabase bucket by group chat, then by
            // attachment id, instead of a flat folder of random filenames.
            foreach (var attachment in attachments.Where(a => a.Type == "Image" && a.MediaUrl != null))
            {
                var oldPath = _storageClient.GetPathFromPublicUrl(attachment.MediaUrl!, _supabase.CommunityMediaBucket);
                if (oldPath == null) continue;

                var extension = Path.GetExtension(oldPath);
                var newPath = $"community/{request.CommunityId}/{attachment.AttachmentId}{extension}";
                try
                {
                    attachment.MediaUrl = await _storageClient.MoveAsync(oldPath, newPath, _supabase.CommunityMediaBucket);
                    await _communityRepository.UpdateAttachmentAsync(attachment);
                }
                catch (Exception ex)
                {
                    // Not fatal to the message: the image still works from its
                    // pending URL if the move fails. Just log and move on.
                    _logger.LogWarning(ex, "Failed to move attachment {AttachmentId} to its permanent path.", attachment.AttachmentId);
                }
            }
        }

        var dto = (await MapMessagesAsync(new List<Message> { message })).Single();

        await _chatHub.Clients.Group(GroupName(request.CommunityId)).SendAsync("ReceiveMessage", dto);
        return dto;
    }

    public async Task<bool> DeleteMessageAsync(int messageId, int userId)
    {
        var message = await _communityRepository.GetMessageByIdAsync(messageId);
        if (message == null || message.IsDeleted)
        {
            return false;
        }

        if (message.SenderUserId != userId)
        {
            throw new ForbiddenException("You can only delete your own messages.");
        }

        await _communityRepository.SoftDeleteMessageAsync(message);
        await _chatHub.Clients.Group(GroupName(message.CommunityId)).SendAsync("MessageDeleted", message.CommunityId, message.MessageId);
        return true;
    }

    public async Task<List<MessageDto>> SearchMessagesAsync(SearchMessagesRequestDto request, int userId)
    {
        await EnsureMemberAsync(request.CommunityId, userId);
        var messages = await _communityRepository.SearchMessagesAsync(request.CommunityId, request.Keyword.Trim());
        return await MapMessagesAsync(messages);
    }

    public async Task<List<ParticipantDto>> GetParticipantsAsync(int communityId, int userId)
    {
        await EnsureMemberAsync(communityId, userId);

        var members = await _communityRepository.GetActiveMembersAsync(communityId);
        var dtos = new List<ParticipantDto>(members.Count);
        foreach (var member in members)
        {
            var user = await _authProfileRepository.GetByIdAsync(member.UserId);
            dtos.Add(new ParticipantDto
            {
                UserId = member.UserId,
                Username = user?.Username ?? "Unknown User",
                ProfilePictureUrl = user?.ProfilePictureUrl,
                Role = member.Role,
                JoinedAt = member.JoinedAt,
            });
        }
        return dtos;
    }

    public async Task<string> UploadMessageImageAsync(int communityId, int userId, Stream fileStream, string fileName, string contentType)
    {
        await EnsureMemberAsync(communityId, userId);

        // The image is uploaded here — before the message (and its
        // MessageAttachment row) exists — so there's no attachment id yet to
        // name the file after. It lands in a "pending" holding area under
        // this community first; once SendMessageAsync creates the real
        // MessageAttachment row and its AttachmentId is known, the file is
        // moved to its permanent community/{communityId}/{attachmentId}
        // path (see the move step at the end of SendMessageAsync).
        var extension = Path.GetExtension(fileName);
        var path = $"community/{communityId}/pending/{Guid.NewGuid()}{extension}";
        return await _storageClient.UploadAsync(path, fileStream, contentType, bucket: _supabase.CommunityMediaBucket);
    }

    public async Task ReportMessageAsync(int messageId, int userId, string? reason)
    {
        var message = await _communityRepository.GetMessageByIdAsync(messageId)
            ?? throw new NotFoundException("Message not found.");

        await EnsureMemberAsync(message.CommunityId, userId);

        var alreadyReported = await _communityRepository.HasReportedAsync(messageId, userId);
        if (alreadyReported)
        {
            // Not an error — the user's intent ("flag this") is already satisfied.
            return;
        }

        await _communityRepository.AddMessageReportAsync(new MessageReport
        {
            MessageId = messageId,
            ReporterUserId = userId,
            Reason = reason,
            CreatedAt = DateTime.UtcNow,
        });

        _logger.LogInformation("User {UserId} reported message {MessageId}.", userId, messageId);
    }

    private async Task EnsureMemberAsync(int communityId, int userId)
    {
        var membership = await _communityRepository.GetMembershipAsync(communityId, userId);
        if (membership is not { IsActive: true })
        {
            throw new ForbiddenException("Join this community to take part in its chat.");
        }
    }

    private async Task<List<MessageDto>> MapMessagesAsync(List<Message> messages)
    {
        if (messages.Count == 0) return new List<MessageDto>();

        var attachments = await _communityRepository.GetAttachmentsForMessagesAsync(messages.Select(m => m.MessageId));
        var attachmentsByMessage = attachments.GroupBy(a => a.MessageId).ToDictionary(g => g.Key, g => g.ToList());

        // Reply previews only need one level deep, so fetch each distinct target once.
        var replyIds = messages.Where(m => m.ReplyToMessageId.HasValue).Select(m => m.ReplyToMessageId!.Value).Distinct().ToList();
        var replyTargets = new Dictionary<int, Message>();
        foreach (var id in replyIds)
        {
            var target = await _communityRepository.GetMessageByIdAsync(id);
            if (target != null) replyTargets[id] = target;
        }

        var dtos = new List<MessageDto>(messages.Count);
        foreach (var message in messages)
        {
            var sender = await _authProfileRepository.GetByIdAsync(message.SenderUserId);

            MessageDto? replyPreview = null;
            if (message.ReplyToMessageId.HasValue && replyTargets.TryGetValue(message.ReplyToMessageId.Value, out var target))
            {
                var replySender = await _authProfileRepository.GetByIdAsync(target.SenderUserId);
                replyPreview = new MessageDto
                {
                    MessageId = target.MessageId,
                    CommunityId = target.CommunityId,
                    SenderUserId = target.SenderUserId,
                    SenderUsername = replySender?.Username ?? "Unknown User",
                    SenderProfilePictureUrl = replySender?.ProfilePictureUrl,
                    Content = target.Content,
                    SentAt = target.SentAt,
                };
            }

            dtos.Add(new MessageDto
            {
                MessageId = message.MessageId,
                CommunityId = message.CommunityId,
                SenderUserId = message.SenderUserId,
                SenderUsername = sender?.Username ?? "Unknown User",
                SenderProfilePictureUrl = sender?.ProfilePictureUrl,
                Content = message.Content,
                SentAt = message.SentAt,
                ReplyToMessageId = message.ReplyToMessageId,
                ReplyToPreview = replyPreview,
                Attachments = attachmentsByMessage.TryGetValue(message.MessageId, out var list)
                    ? list.Select(a => new MessageAttachmentDto
                    {
                        AttachmentId = a.AttachmentId,
                        Type = a.Type,
                        MediaUrl = a.MediaUrl,
                        PlaceId = a.PlaceId,
                        PlaceSource = a.PlaceSource,
                        ShareDataJson = a.ShareDataJson,
                        PlaceName = a.PlaceName,
                        PlaceAddress = a.PlaceAddress,
                        PlaceImageUrl = a.PlaceImageUrl,
                        PlaceStatus = a.PlaceStatus,
                        PostId = a.PostId,
                    }).ToList()
                    : new List<MessageAttachmentDto>(),
            });
        }
        return dtos;
    }
}
