using System.Text.Json;
using ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;
using ExploreMy.Api.Configuration;
using ExploreMy.Api.DataAccess.ExternalClients.GooglePlaces;
using ExploreMy.Api.DataAccess.ExternalClients.SupabaseStorage;
using ExploreMy.Api.DataAccess.Repositories.PlacePhotos;
using ExploreMy.Api.Domain.Entities;
using Microsoft.Extensions.Options;

namespace ExploreMy.Api.Application.HiddenPlace.PlacePhotos;

/// <summary>
/// Copies place photos out of Google and into our own Supabase bucket, once per place, and hands
/// back the URLs the app should load.
///
/// The flow for a place we have never seen before is three hops:
///
///   1) Google's searchNearby already gave us a photo RESOURCE NAME in photos_json. That is only a
///      handle - it is not an image and not a URL.
///   2) Ask Google's Place Photos endpoint to turn that handle into a real image URI. This is the
///      billed step ($7/1,000 images, 1,000 free a month) and the reason everything here is built
///      around never doing it twice for the same place.
///   3) Download those bytes and re-upload them to Supabase, then remember our own URL forever.
///
/// Google's image URI is short-lived, so step 3 is not an optimisation - without it the app would
/// have to redo step 2 on every single render, and the bill would scale with screen refreshes
/// rather than with how many places exist.
/// </summary>
public class PlacePhotoService : IPlacePhotoService
{
    /// <summary>
    /// Requested width in pixels. Price does not depend on size - only Supabase storage and the
    /// app's load time do. 800px covers both uses: the 150dp-wide card in the list and a full-width
    /// image on a details screen, at roughly 80-150KB each.
    /// </summary>
    private const int MaxWidthPx = 800;

    /// <summary>
    /// How many photos are copied at once for a single search. Each one is a Google round-trip plus
    /// a Supabase upload, so this is the difference between a first search of a new area taking a
    /// couple of seconds and taking twenty. Kept below the search fan-out (HiddenPlaceService's
    /// MaxConcurrentFetches) because these are much heavier calls - whole images, not JSON.
    /// </summary>
    private const int MaxConcurrentCopies = 6;

    /// <summary>
    /// Ceiling on how many places one search will resolve a photo for. A first search of a dense city
    /// can surface a hundred-plus unseen places, and handling all of them would put a multi-second
    /// stall in front of the user and, in the worst case, spend a tenth of the monthly free tier in
    /// one tap. Places over the limit are skipped this time and picked up by the next search that
    /// includes them, so coverage fills in over a few uses instead of all at once.
    ///
    /// A slot is not necessarily a purchase: one spent on a photo already sitting in the shared
    /// bucket costs nothing but a HEAD request. This is a latency budget first and a money budget
    /// second - see the counts logged after the copy loop for what was actually bought.
    /// </summary>
    private const int MaxNewPhotosPerSearch = 25;

    private readonly IPlacePhotoRepository _repository;
    private readonly IPlacesApiClient _placesApiClient;
    private readonly IStorageClient _storage;
    private readonly HttpClient _httpClient;
    private readonly SupabaseSettings _supabase;
    private readonly ILogger<PlacePhotoService> _logger;

    public PlacePhotoService(
        IPlacePhotoRepository repository,
        IPlacesApiClient placesApiClient,
        IStorageClient storage,
        HttpClient httpClient,
        IOptions<SupabaseSettings> supabase,
        ILogger<PlacePhotoService> logger)
    {
        _repository = repository;
        _placesApiClient = placesApiClient;
        _storage = storage;
        _httpClient = httpClient;
        _supabase = supabase.Value;
        _logger = logger;
    }

    public async Task<IReadOnlyDictionary<string, PlacePhotoInfo>> EnsurePhotosAsync(
        IReadOnlyCollection<PlaceCandidate> places,
        CancellationToken cancellationToken = default)
    {
        var known = new Dictionary<string, PlacePhotoInfo>();
        if (places.Count == 0)
        {
            return known;
        }

        try
        {
            var stored = await _repository.GetByPlaceIdsAsync(
                places.Select(p => p.PlaceId).Distinct().ToList());

            foreach (var (placeId, row) in stored)
            {
                known[placeId] = new PlacePhotoInfo(row.PhotoUrl, row.Attribution);
            }

            // Only places we have never copied AND that Google actually offered a photo for. Plenty of
            // obscure places - exactly the kind this app is looking for - have no photo at all, and
            // asking Google for one anyway would be a paid call that can only fail.
            var toCopy = places
                .Where(p => !known.ContainsKey(p.PlaceId))
                .DistinctBy(p => p.PlaceId)
                .Select(p => (Place: p, Reference: FirstPhotoReference(p.PhotosJson)))
                .Where(x => x.Reference is not null)
                .Take(MaxNewPhotosPerSearch)
                .ToList();

            if (toCopy.Count == 0)
            {
                return known;
            }

            // Counted rather than inferred, because the two outcomes cost very different things and
            // only one of them shows up on a Google bill.
            var boughtFromGoogle = 0;

            using var throttle = new SemaphoreSlim(MaxConcurrentCopies);

            // Downloads and uploads run concurrently; the DbContext is deliberately untouched in here.
            // EF Core's DbContext is not thread-safe, so every database call in this method happens
            // before this block (the read above) or after it (the write below), never inside it.
            var copied = await Task.WhenAll(toCopy.Select(async item =>
            {
                await throttle.WaitAsync(cancellationToken);
                try
                {
                    return await CopyOneAsync(
                        item.Place,
                        item.Reference!,
                        () => Interlocked.Increment(ref boughtFromGoogle),
                        cancellationToken);
                }
                finally
                {
                    throttle.Release();
                }
            }));

            var newRows = copied.Where(row => row is not null).Select(row => row!).ToList();

            _logger.LogInformation(
                "Resolved {Resolved}/{Attempted} place photo(s): {Bought} bought from Google, "
                + "{Reused} already in the shared bucket.",
                newRows.Count, toCopy.Count, boughtFromGoogle, newRows.Count - boughtFromGoogle);

            if (newRows.Count > 0)
            {
                await _repository.AddRangeAsync(newRows);
                foreach (var row in newRows)
                {
                    known[row.PlaceId] = new PlacePhotoInfo(row.PhotoUrl, row.Attribution);
                }
            }
        }
        catch (Exception ex)
        {
            // Whatever went wrong, the search itself succeeded and the user should still get their
            // places - just without pictures this time. See IPlacePhotoService for why this never
            // rethrows.
            _logger.LogError(ex, "Place photo lookup failed; returning results without photos.");
        }

        return known;
    }

    /// <summary>
    /// Google -> our bucket, for a single place. Returns null (already logged) on any failure, so one
    /// bad image cannot take the other 24 down with it.
    /// </summary>
    private async Task<PlacePhoto?> CopyOneAsync(
        PlaceCandidate place,
        string photoReference,
        Action onBoughtFromGoogle,
        CancellationToken cancellationToken)
    {
        // Always .jpg, whatever Google actually sends. The real media type is still recorded on the
        // object at upload, and that is what browsers and Flutter read - the extension is decoration.
        // What it buys is a path that can be COMPUTED from a place id alone, which is what makes the
        // existence check below a single request instead of one guess per possible extension.
        var objectPath = $"places/{place.PlaceId}.jpg";

        try
        {
            // Ask the bucket before paying Google. This machine's place_photo table being empty does
            // not mean nobody has bought this photo - every developer has their own local MySQL, but
            // the team shares one Supabase project, so a teammate's earlier run may already have put
            // the image there. Without this, each person re-buys the same photos out of the same
            // monthly free allowance.
            if (await _storage.ExistsAsync(objectPath, _supabase.PlacePhotoBucket))
            {
                return BuildRow(
                    place,
                    photoReference,
                    _storage.GetPublicUrl(objectPath, _supabase.PlacePhotoBucket));
            }

            var photoUri = await _placesApiClient.GetPhotoUriAsync(
                photoReference, MaxWidthPx, cancellationToken);

            if (photoUri is null)
            {
                return null;
            }

            using var response = await _httpClient.GetAsync(photoUri, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning(
                    "Downloading the photo for {PlaceId} failed with {StatusCode}.",
                    place.PlaceId, response.StatusCode);
                return null;
            }

            // Recorded on the object so Supabase serves the right Content-Type back, even though the
            // path always ends in .jpg - see objectPath above.
            var contentType = response.Content.Headers.ContentType?.MediaType ?? "image/jpeg";

            await using var bytes = await response.Content.ReadAsStreamAsync(cancellationToken);

            // upsert because two searches can lose the existence check above to each other and both
            // arrive here; a plain upload of an existing path is rejected, and failing the second one
            // would waste a photo that has already been paid for.
            var url = await _storage.UploadAsync(
                objectPath,
                bytes,
                contentType,
                bucket: _supabase.PlacePhotoBucket,
                upsert: true);

            // Only here - past the bucket check, past the download - has anything actually been billed.
            onBoughtFromGoogle();

            return BuildRow(place, photoReference, url);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not copy the photo for {PlaceId}.", place.PlaceId);
            return null;
        }
    }

    /// <summary>
    /// The row to remember, whether the image was just bought or was already sitting in the bucket.
    ///
    /// Attribution comes from this machine's own cached photos_json rather than from storage - the
    /// bucket holds bytes, not credits - so it is available on both paths.
    /// </summary>
    private PlacePhoto BuildRow(PlaceCandidate place, string photoReference, string url) => new()
    {
        PlaceId = place.PlaceId,
        PhotoUrl = url,
        PhotoReference = photoReference,
        Attribution = FirstAttribution(place.PhotosJson),
        CreatedAt = DateTime.UtcNow
    };

    /// <summary>
    /// Pulls the first entry's resource name out of the raw `photos` array Google returned, or null
    /// if there isn't one.
    ///
    /// The JSON is stored verbatim rather than modelled in C#, so it is read defensively here: it is
    /// whatever Google sent at the time the row was cached, which may be up to a month old and may
    /// predate a schema change on their side. A parse failure means no picture, never an exception.
    /// </summary>
    private string? FirstPhotoReference(string? photosJson) =>
        ReadFirstPhoto(photosJson, photo =>
            photo.TryGetProperty("name", out var name) && name.ValueKind == JsonValueKind.String
                ? name.GetString()
                : null);

    /// <summary>The photographer credit on the first photo - see PlacePhoto.Attribution for why it matters.</summary>
    private string? FirstAttribution(string? photosJson) =>
        ReadFirstPhoto(photosJson, photo =>
        {
            if (!photo.TryGetProperty("authorAttributions", out var authors)
                || authors.ValueKind != JsonValueKind.Array
                || authors.GetArrayLength() == 0)
            {
                return null;
            }

            return authors[0].TryGetProperty("displayName", out var displayName)
                   && displayName.ValueKind == JsonValueKind.String
                ? displayName.GetString()
                : null;
        });

    private string? ReadFirstPhoto(string? photosJson, Func<JsonElement, string?> select)
    {
        if (string.IsNullOrWhiteSpace(photosJson))
        {
            return null;
        }

        try
        {
            using var document = JsonDocument.Parse(photosJson);
            var root = document.RootElement;

            if (root.ValueKind != JsonValueKind.Array || root.GetArrayLength() == 0)
            {
                return null;
            }

            return select(root[0]);
        }
        catch (JsonException ex)
        {
            _logger.LogWarning(ex, "Could not read the cached photos JSON; treating the place as having no photo.");
            return null;
        }
    }
}
