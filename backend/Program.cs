using ExploreMy.Api.Application.AuthProfile.Authentication;
using ExploreMy.Api.Application.AuthProfile.Facade;
using ExploreMy.Api.Application.AuthProfile.ManageProfile;
using ExploreMy.Api.Application.FootTracker.ExplorationHistory;
using ExploreMy.Api.Application.FootTracker.Facade;
using ExploreMy.Api.Application.FootTracker.FavouritePlace;
using ExploreMy.Api.Application.FootTracker.Navigation;
using ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;
using ExploreMy.Api.Application.HiddenPlace.Facade;
using ExploreMy.Api.Application.HiddenPlace.HiddenPlaceContribution;
using ExploreMy.Api.Application.HiddenPlace.PlacePhotos;
using ExploreMy.Api.Application.HiddenPlace.Review;
using ExploreMy.Api.Application.PostReview.Facade;
using ExploreMy.Api.Application.PostReview.ManagePost;
using ExploreMy.Api.Application.PostReview.SocialEngagement;
using ExploreMy.Api.Common.Helpers;
using ExploreMy.Api.Configuration;
using ExploreMy.Api.DataAccess.ExternalClients.GooglePlaces;
using ExploreMy.Api.DataAccess.ExternalClients.OpenRouteService;
using ExploreMy.Api.DataAccess.ExternalClients.SupabaseStorage;
using ExploreMy.Api.DataAccess.Repositories.AuthProfile;
using ExploreMy.Api.DataAccess.Repositories.FootTracker;
using ExploreMy.Api.DataAccess.Repositories.HiddenPlace;
using ExploreMy.Api.DataAccess.Repositories.PlacePhotos;
using ExploreMy.Api.DataAccess.Repositories.PostReview;
using ExploreMy.Api.Infrastructure.Repositories.HiddenPlace.Review;
using ExploreMy.Api.Middleware;
using ExploreMy.Api.Persistence.DbContext;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.Net.Http.Headers;
using System.Text;

Console.WriteLine(
    PasswordHasher.HashPassword("exploreMy123")
);
var builder = WebApplication.CreateBuilder(args);

// Config binding
builder.Services.Configure<JwtSettings>(builder.Configuration.GetSection("Jwt"));
builder.Services.Configure<SmtpSettings>(builder.Configuration.GetSection("Smtp"));
builder.Services.Configure<SupabaseSettings>(builder.Configuration.GetSection("Supabase"));
builder.Services.Configure<GoogleApiSettings>(builder.Configuration.GetSection("GoogleApi"));
builder.Services.AddSingleton<IDistrictLookupService, DistrictLookupService>();
var jwtSettings = builder.Configuration.GetSection("Jwt").Get<JwtSettings>()!;
var supabaseSettings = builder.Configuration.GetSection("Supabase").Get<SupabaseSettings>()!;

// Read the connection string from User Secrets/appsettings.json
var connectionString = builder.Configuration
    .GetConnectionString("MySqlConnection")
    ?? throw new InvalidOperationException(
        "Connection string 'MySqlConnection' was not found.");

// Register MySQL DbContext
builder.Services.AddDbContext<MySqlDbContext>(options =>
{
    options
        .UseMySQL(connectionString)
        .UseSnakeCaseNamingConvention();

    // L-17: sensitive data (query parameter values) must never be logged
    // outside development environments.
    if (builder.Environment.IsDevelopment())
    {
        options.EnableSensitiveDataLogging();
    }
});

// App services
builder.Services.AddScoped<IAuthProfileRepository, AuthProfileMySqlRepository>();
builder.Services.AddSingleton<IEmailSender, EmailSender>();
builder.Services.AddScoped<IAuthenticationService, AuthenticationService>();
builder.Services.AddScoped<IAuthProfileService, AuthProfileService>();
builder.Services.AddSingleton<IJwtTokenGenerator, JwtTokenGenerator>();
builder.Services.AddScoped<IManageProfileService, ManageProfileService>();
// PostReview (Post module) services
builder.Services.AddScoped<IPostReviewRepository, PostReviewMySqlRepository>();
builder.Services.AddScoped<IManagePostService, ManagePostService>();
builder.Services.AddScoped<ISocialEngagementService, SocialEngagementService>();
builder.Services.AddScoped<IPostReviewService, PostReviewService>();

// HiddenPlace (My Recommended Places module) services
builder.Services.AddScoped<IHiddenPlaceRepository, HiddenPlaceMySqlRepository>();
builder.Services.AddScoped<IHiddenPlaceContributionService, HiddenPlaceContributionService>();
builder.Services.AddScoped<IDiscoverHiddenPlaceService, DiscoverHiddenPlaceService>();
builder.Services.AddScoped<IHiddenPlaceService, HiddenPlaceService>();
builder.Services.AddScoped<IPlacePhotoRepository, PlacePhotoMySqlRepository>();
builder.Services.AddScoped<IHiddenPlaceSuppressionRepository, HiddenPlaceSuppressionMySqlRepository>();
builder.Services.AddScoped<
    IReviewRepository,
    ReviewMySqlRepository>();

builder.Services.AddScoped<
    IReviewPhotoRepository,
    ReviewPhotoMySqlRepository>();

builder.Services.AddScoped<
    IReviewReportRepository,
    ReviewReportMySqlRepository>();

builder.Services.AddScoped<IReviewService, ReviewService>();

// FootTracker modules services
builder.Services.AddScoped<IFootTrackerRepository, FootTrackerMySqlRepository>();
builder.Services.AddScoped<IFavouritePlaceService, FavouritePlaceService>();
builder.Services.AddScoped<IFootTrackerService, FootTrackerService>();
builder.Services.Configure<OpenRouteServiceSettings>(builder.Configuration.GetSection("OpenRouteService"));
builder.Services.AddScoped<IExplorationHistoryService, ExplorationHistoryService>();

builder.Services.AddHttpClient<IStorageClient, SupabaseStorageClient>(client =>
{
    client.BaseAddress = new Uri(supabaseSettings.Url);
    client.DefaultRequestHeaders.Add("apikey", supabaseSettings.ServiceRoleKey);
    client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", supabaseSettings.ServiceRoleKey);
});

builder.Services.AddHttpClient<IPlacesApiClient, GooglePlacesApiClient>(client =>
{
    client.BaseAddress = new Uri("https://places.googleapis.com");
});
builder.Services.AddSingleton<IDistrictLookupService, DistrictLookupService>();

// Its HttpClient is deliberately bare: no BaseAddress, no API key, no auth header. It only ever
// downloads image bytes from whatever CDN URI Google hands back, and those URIs are already signed.
// Giving this client credentials would mean shipping them to a third-party host on every photo.
builder.Services.AddHttpClient<IPlacePhotoService, PlacePhotoService>();

builder.Services.AddHttpClient<IRoutingApiClient, OpenRouteServiceApiClient>(client =>
{
    client.BaseAddress = new Uri("https://api.openrouteservice.org");
});
builder.Services.AddScoped<INavigationService, NavigationService>();

// JWT auth (validates tokens on future protected endpoints)
builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtSettings.Issuer,
            ValidAudience = jwtSettings.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSettings.Key))
        };
    });

// Add other services
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        // D-06 (post timestamp fix): this MySQL instance stores the wall-clock
        // values it is given (no session-timezone conversion), and every app
        // write uses DateTime.UtcNow, so the database holds UTC wall-clock
        // values. MySql.Data returns those TIMESTAMP values as Kind=Local,
        // so System.Text.Json serialized them with a +08:00 offset - e.g. a
        // post created at 03:08Z was emitted as "03:08+08:00" (8 hours
        // behind) and the Flutter feed showed "8 hours ago" for a brand-new
        // post. Relabelling Local-kind values as Utc makes every app-written
        // timestamp serialize as its true instant ("...Z").
        options.JsonSerializerOptions.Converters.Add(new UtcDateTimeConverter());
    });
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "Enter your JWT token."
    });

    options.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// CORS for Flutter Web development (must precede UseAuthentication/UseAuthorization/endpoints).
// Restricted development origins only; credentials allowed only for those origins.
// NOTE: Do NOT use AllowAnyOrigin() together with AllowCredentials().
// Flutter Web dev server binds a dynamic localhost port, so origins are matched by host
// (loopback + the development LAN host) instead of a fixed port list.
builder.Services.AddCors(options =>
{
    options.AddPolicy("FlutterWebDev", policy =>
    {
        policy
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials()
            .SetIsOriginAllowed(origin =>
            {
                if (Uri.TryCreate(origin, UriKind.Absolute, out var uri))
                {
                    return uri.Host == "localhost"
                        || uri.Host == "127.0.0.1"
                        || uri.Host == "10.210.56.218"
                        || uri.Host == "10.255.28.218";
                }
                return false;
            });
    });
});

var app = builder.Build();

// Configure HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseMiddleware<ExceptionHandlingMiddleware>();

// NOTE: no UseHttpsRedirection() here. This backend is HTTP-only (the Flutter
// Web client calls http://<host>:5226 directly; no HTTPS endpoint or TLS
// termination is configured). With no HTTPS port available the redirect
// middleware only emits a "Failed to determine the https port for redirect"
// warning on every startup and redirects nothing.

app.UseCors("FlutterWebDev");

app.UseAuthentication();

app.UseAuthorization();

app.MapControllers();

app.Run();

/// <summary>
/// D-06: serializes <see cref="DateTime"/> values as their true UTC instant.
/// The app's storage contract is "every app write uses DateTime.UtcNow, so the
/// database holds UTC wall-clock values" — but the MySQL driver reads those
/// back with different Kind markers depending on column type:
///   - TIMESTAMP columns come back as Kind=Local (raw UTC wall-clock value);
///   - DATETIME(6) columns come back as Kind=Unspecified (raw UTC wall-clock).
/// Both must be relabelled to Kind=Utc so the emitted JSON carries the "Z"
/// suffix. Only the Kind is relabelled — the clock value is never shifted —
/// so no +8h hard-coding is involved, and the Flutter client can then convert
/// the instant to the device's local time for display.
/// </summary>
internal sealed class UtcDateTimeConverter : System.Text.Json.Serialization.JsonConverter<System.DateTime>
{
    public override System.DateTime Read(
        ref System.Text.Json.Utf8JsonReader reader,
        Type typeToConvert,
        System.Text.Json.JsonSerializerOptions options)
        => reader.GetDateTime();

    public override void Write(
        System.Text.Json.Utf8JsonWriter writer,
        System.DateTime value,
        System.Text.Json.JsonSerializerOptions options)
    {
        if (value.Kind == DateTimeKind.Local || value.Kind == DateTimeKind.Unspecified)
        {
            // Relabel the UTC wall-clock value as Utc so the emitted string
            // carries the "Z" suffix (the correct instant). DATETIME(6) reads
            // arrive as Unspecified and were previously emitted with no suffix,
            // which made the Flutter client treat the UTC clock as local time.
            value = DateTime.SpecifyKind(value, DateTimeKind.Utc);
        }

        writer.WriteStringValue(
            value.ToString("yyyy-MM-ddTHH:mm:ss.FFFFFFFK", System.Globalization.CultureInfo.InvariantCulture));
    }
}