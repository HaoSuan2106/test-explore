namespace ExploreMy.Api.Configuration;

/// <summary>Bound from the "GoogleApi" section of appsettings.json / user secrets.</summary>
public class GoogleApiSettings
{
    /// <summary>API key with the Places API (New) enabled in Google Cloud Console. Keep this out of source control.</summary>
    public string ApiKey { get; set; } = string.Empty;
}
