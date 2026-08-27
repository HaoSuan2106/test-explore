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

    public async Task<string> UploadAsync(
        string path,
        Stream content,
        string contentType,
        string? bucket = null,
        bool upsert = false)
    {
        var targetBucket = string.IsNullOrWhiteSpace(bucket) ? _settings.Bucket : bucket;

        using var fileContent = new StreamContent(content);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue(contentType);

        var requestUri = $"/storage/v1/object/{targetBucket}/{path}";
        using var request = new HttpRequestMessage(HttpMethod.Post, requestUri) { Content = fileContent };

        // Supabase rejects a POST to a path that already holds an object unless this header says
        // otherwise. Sent only when the caller asked for it - see IStorageClient.UploadAsync.
        if (upsert)
        {
            request.Headers.Add("x-upsert", "true");
        }

        using var response = await _httpClient.SendAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync();
            _logger.LogError("Supabase upload to {Path} failed with {StatusCode}: {Body}", path, response.StatusCode, body);
            throw new InvalidOperationException("Failed to upload file to storage.");
        }

        return GetPublicUrl(path, targetBucket);
    }

    public async Task<bool> ExistsAsync(string path, string? bucket = null)
    {
        var targetBucket = string.IsNullOrWhiteSpace(bucket) ? _settings.Bucket : bucket;

        // HEAD on the public route: headers only, no body, and no charge. The public route rather
        // than the authenticated one because a miss there is a plain 404, whereas the authenticated
        // one can also answer 400/403 for reasons that have nothing to do with the object existing.
        using var request = new HttpRequestMessage(
            HttpMethod.Head, $"/storage/v1/object/public/{targetBucket}/{path}");

        try
        {
            using var response = await _httpClient.SendAsync(request);
            return response.IsSuccessStatusCode;
        }
        catch (HttpRequestException ex)
        {
            // Answer "no" on a network failure rather than throwing. This check is an optimisation -
            // the caller has a slower path that still works - so a Supabase blip should cost a
            // redundant fetch, not the whole request.
            _logger.LogWarning(ex, "Could not check whether {Path} exists in storage; assuming it does not.", path);
            return false;
        }
    }

    public string GetPublicUrl(string path, string? bucket = null)
    {
        var targetBucket = string.IsNullOrWhiteSpace(bucket) ? _settings.Bucket : bucket;
        return $"{_settings.Url}/storage/v1/object/public/{targetBucket}/{path}";
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
