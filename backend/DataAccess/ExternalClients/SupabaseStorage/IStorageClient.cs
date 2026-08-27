namespace ExploreMy.Api.DataAccess.ExternalClients.SupabaseStorage;

public interface IStorageClient
{
    /// <summary>
    /// Uploads content to storage and returns its public URL.
    /// </summary>
    /// <param name="bucket">Bucket to write to. Null uses the configured default (profile pictures).</param>
    /// <param name="upsert">
    /// Allow overwriting an object that already exists at <paramref name="path"/>. Off by default:
    /// user uploads get a fresh path every time, so a collision there means something is wrong and
    /// should fail loudly rather than quietly destroy someone else's file. Callers that address
    /// objects by a stable key - place photos are named after the place id - need it on.
    /// </param>
    Task<string> UploadAsync(
        string path,
        Stream content,
        string contentType,
        string? bucket = null,
        bool upsert = false);

    /// <summary>
    /// Whether an object already exists at <paramref name="path"/>.
    ///
    /// Exists so a caller can treat the bucket itself as the record of what has already been
    /// fetched, instead of its own database. Place photos need that: every developer runs a separate
    /// local MySQL but the whole team shares one Supabase project, so a photo someone already paid
    /// Google for is sitting in the bucket even though this machine's tables have never heard of it.
    /// Only meaningful for paths built from a stable key - a randomly-named object can never be
    /// found this way.
    /// </summary>
    Task<bool> ExistsAsync(string path, string? bucket = null);

    /// <summary>
    /// The public URL an object at <paramref name="path"/> has (or would have), without any network
    /// call. Lets callers name an object they did not upload themselves, and keeps the URL format in
    /// one place rather than string-built at each call site.
    /// </summary>
    string GetPublicUrl(string path, string? bucket = null);

    Task DeleteAsync(string path);

    /// Extracts the storage object path from a public URL previously returned by UploadAsync, or null if the URL isn't from this bucket.
    string? GetPathFromPublicUrl(string publicUrl);
}
