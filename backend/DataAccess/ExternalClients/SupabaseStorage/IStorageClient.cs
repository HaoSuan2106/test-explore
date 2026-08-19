namespace ExploreMy.Api.DataAccess.ExternalClients.SupabaseStorage;

public interface IStorageClient
{
    /// Uploads content to storage and returns its public URL.
    Task<string> UploadAsync(string path, Stream content, string contentType);

    Task DeleteAsync(string path);

    /// Extracts the storage object path from a public URL previously returned by UploadAsync, or null if the URL isn't from this bucket.
    string? GetPathFromPublicUrl(string publicUrl);
}
