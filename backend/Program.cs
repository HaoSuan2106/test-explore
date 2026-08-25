using ExploreMy.Api.Application.AuthProfile.Authentication;
using ExploreMy.Api.Application.AuthProfile.Facade;
using ExploreMy.Api.Application.AuthProfile.ManageProfile;
using ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;
using ExploreMy.Api.Application.HiddenPlace.Facade;
using ExploreMy.Api.Common.Helpers;
using ExploreMy.Api.Configuration;
using ExploreMy.Api.DataAccess.ExternalClients.GooglePlaces;
using ExploreMy.Api.DataAccess.ExternalClients.SupabaseStorage;
using ExploreMy.Api.DataAccess.Repositories.AuthProfile;
using ExploreMy.Api.DataAccess.Repositories.HiddenPlace;
using ExploreMy.Api.Middleware;
using ExploreMy.Api.Persistence.DbContext;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.Net.Http.Headers;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Config binding
builder.Services.Configure<JwtSettings>(builder.Configuration.GetSection("Jwt"));
builder.Services.Configure<SmtpSettings>(builder.Configuration.GetSection("Smtp"));
builder.Services.Configure<SupabaseSettings>(builder.Configuration.GetSection("Supabase"));
builder.Services.Configure<GoogleApiSettings>(builder.Configuration.GetSection("GoogleApi"));
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
        .UseSnakeCaseNamingConvention()
        .EnableSensitiveDataLogging();
});

// App services
builder.Services.AddScoped<IAuthProfileRepository, AuthProfileMySqlRepository>();
builder.Services.AddSingleton<IEmailSender, EmailSender>();
builder.Services.AddScoped<IAuthenticationService, AuthenticationService>();
builder.Services.AddScoped<IAuthProfileService, AuthProfileService>();
builder.Services.AddSingleton<IJwtTokenGenerator, JwtTokenGenerator>();
builder.Services.AddScoped<IManageProfileService, ManageProfileService>();
builder.Services.AddScoped<IDiscoverHiddenPlaceService, DiscoverHiddenPlaceService>();
builder.Services.AddScoped<IHiddenPlaceRepository, HiddenPlaceMySqlRepository>();
builder.Services.AddScoped<IHiddenPlaceService, HiddenPlaceService>();

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
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseMiddleware<ExceptionHandlingMiddleware>();

app.UseHttpsRedirection();

app.UseAuthorization();

app.UseAuthorization();

app.MapControllers();

app.Run();