using System.Net.Http.Headers;
using ExploreMy.Api.Configuration;
using Microsoft.Extensions.Options;

namespace ExploreMy.Api.DataAccess.ExternalClients.SupabaseStorage;

public class SupabaseStorageClient : IStorageClient
{
    private readonly HttpClient _httpClient;
    private readonly SupabaseSettings _settings;
    private readonly ILogger<SupabaseStorageClient> _logger;

    public SupabaseStorageClient(HttpClient httpClient, IOptions<SupabaseSettings> settings, ILogger<SupabaseStorageClient> logger)
    {
        _httpClient = httpClient;
        _settings = settings.Value;
        _logger = logger;
    }

    public async Task<string> UploadAsync(string path, Stream content, string contentType)
    {
        using var fileContent = new StreamContent(content);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue(contentType);

        var requestUri = $"/storage/v1/object/{_settings.Bucket}/{path}";
        using var response = await _httpClient.PostAsync(requestUri, fileContent);

        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync();
            _logger.LogError("Supabase upload to {Path} failed with {StatusCode}: {Body}", path, response.StatusCode, body);
            throw new InvalidOperationException("Failed to upload file to storage.");
        }

        return $"{_settings.Url}/storage/v1/object/public/{_settings.Bucket}/{path}";
    }

    public async Task DeleteAsync(string path)
    {
        var requestUri = $"/storage/v1/object/{_settings.Bucket}/{path}";
        using var response = await _httpClient.DeleteAsync(requestUri);

        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync();
            _logger.LogWarning("Supabase delete of {Path} failed with {StatusCode}: {Body}", path, response.StatusCode, body);
        }
    }

    public string? GetPathFromPublicUrl(string publicUrl)
    {
        var marker = $"/storage/v1/object/public/{_settings.Bucket}/";
        var index = publicUrl.IndexOf(marker, StringComparison.Ordinal);
        return index < 0 ? null : publicUrl[(index + marker.Length)..];
    }
}
