using ExploreMy.Api.DTOs.Community;

namespace ExploreMy.Api.Application.Community.Communication;

/// <summary>
/// Covers: Send/Receive Messages, Reply Messages, Search Messages,
/// View Participant List, Share Media.
/// </summary>
public interface ICommunicationService
{
    Task<List<MessageDto>> GetMessagesAsync(int communityId, int userId, int take, int? beforeMessageId);

    Task<MessageDto> SendMessageAsync(SendMessageRequestDto request, int userId);

    Task<bool> DeleteMessageAsync(int messageId, int userId);

    Task<List<MessageDto>> SearchMessagesAsync(SearchMessagesRequestDto request, int userId);

    Task<List<ParticipantDto>> GetParticipantsAsync(int communityId, int userId);

    Task<string> UploadMessageImageAsync(int communityId, int userId, Stream fileStream, string fileName, string contentType);

    Task ReportMessageAsync(int messageId, int userId, string? reason);
}
