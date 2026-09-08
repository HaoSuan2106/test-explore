# ExploreMy

A travel discovery app for finding hidden places, tracking your exploration footprint, sharing
reviews, and chatting with local communities.

- **Backend** — ASP.NET Core (.NET 10) REST API + SignalR, MySQL via EF Core
- **Frontend** — Flutter (Dart), targeting Android / iOS / Web / Desktop
- **Storage** — Supabase Storage for images
- **External APIs** — Google Places, OpenRouteService

---

## Table of contents

- [Prerequisites](#prerequisites)
- [Repository layout](#repository-layout)
- [First-time setup](#first-time-setup)
- [Running the backend (HTTP)](#running-the-backend-http)
- [Running the backend (HTTPS)](#running-the-backend-https)
- [Running the Flutter app](#running-the-flutter-app)
- [Common database tasks](#common-database-tasks)
- [Tests](#tests)
- [Troubleshooting](#troubleshooting)
- [Security notes](#security-notes)

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| .NET SDK | 10.0 | `dotnet --version` |
| MySQL Server | 8.x | Local instance on port `3306` |
| Flutter SDK | stable | `flutter doctor` |
| EF Core tools | 10.x | `dotnet tool install --global dotnet-ef` |

---

## Repository layout

```
ExploreMy/
├── backend/                  ASP.NET Core Web API (.NET 10)
│   ├── Application/          Business logic, one folder per module
│   │   ├── AuthProfile/      Auth, registration, profile management
│   │   ├── Community/        Communities + real-time chat
│   │   ├── FootTracker/      Visits, favourites, routing, exploration map
│   │   ├── HiddenPlace/      Discovery, contributions, reviews, photos
│   │   └── PostReview/       Posts, comments, reactions, reports
│   ├── Controllers/          HTTP endpoints
│   ├── DataAccess/           Repositories + external API clients
│   ├── Hubs/                 SignalR hubs (community chat)
│   ├── Migrations/           EF Core migrations
│   ├── Properties/           launchSettings.json (http / https profiles)
│   └── tests/                xUnit test project
├── frontend/                 Flutter application
│   └── lib/
│       ├── api_communication/  Dio HTTP client, SignalR client, secure storage
│       ├── models/             Data models per module
│       ├── providers/          State management
│       └── screens/            UI
├── database/
│   ├── schema/               Table creation SQL
│   ├── scripts/              Utility SQL
│   └── seed_data/            Sample data inserts
└── scripts/                  PowerShell helper scripts
```

---

## First-time setup

### 1. Create the MySQL database and user

```sql
CREATE DATABASE exploremy_dev;
CREATE USER 'exploremy_app'@'localhost' IDENTIFIED BY '<your-mysql-password>';
GRANT ALL PRIVILEGES ON exploremy_dev.* TO 'exploremy_app'@'localhost';
FLUSH PRIVILEGES;
```

### 2. Configure User Secrets

Secrets are **never** stored in `appsettings.json` — they live in .NET User Secrets, outside the
repository (`%APPDATA%\Microsoft\UserSecrets\` on Windows). The project's `UserSecretsId` is already
set in `explore_my_backend.csproj`.

Open a terminal **in the folder containing `explore_my_backend.csproj`** (`backend/`), then run:

```bash
dotnet user-secrets set "ConnectionStrings:MySqlConnection" 'server=localhost;port=3306;database=exploremy_dev;user=exploremy_app;password=<your-mysql-password>;' --project ".\explore_my_backend.csproj"
```

```bash
dotnet user-secrets set "Supabase:ServiceRoleKey" '<your-supabase-service-role-key>' --project ".\explore_my_backend.csproj"
```

```bash
dotnet user-secrets set "Smtp:Password" '<your-gmail-app-password>' --project ".\explore_my_backend.csproj"
```

```bash
dotnet user-secrets set "Jwt:Key" '<your-jwt-signing-key-min-32-chars>' --project ".\explore_my_backend.csproj"
```

```bash
dotnet user-secrets set "GoogleApi:ApiKey" '<your-google-places-api-key>' --project ".\explore_my_backend.csproj"
```

```bash
dotnet user-secrets set "OpenRouteService:ApiKey" '<your-openrouteservice-api-key>' --project ".\explore_my_backend.csproj"
```

> **Team members:** the actual values for this project are kept out of git. Ask the project owner,
> or see `backend/SECRETS.local.md` if you have it — that file is gitignored and must never be committed.

Verify what's stored:

```bash
dotnet user-secrets list --project ".\explore_my_backend.csproj"
```

### 3. Apply database migrations

From the `backend/` folder:

```bash
dotnet ef database update
```

### 4. (Optional) Seed sample data

Run the SQL files in `database/seed_data/` against `exploremy_dev` in MySQL Workbench or the CLI.

---

## Running the backend (HTTP)

This is the default development mode. From the `backend/` folder:

```bash
dotnet run --project .\explore_my_backend.csproj --urls "http://0.0.0.0:5226"
```

Binding to `0.0.0.0` (rather than `localhost`) makes the API reachable from the Android emulator and
from physical devices on the same Wi-Fi network.

| Endpoint | URL |
|---|---|
| API base | `http://localhost:5226` |
| Swagger UI | `http://localhost:5226/swagger` |
| SignalR hub | `http://localhost:5226/hubs/community-chat` |

Equivalent using the launch profile:

```bash
dotnet run --project .\explore_my_backend.csproj --launch-profile http
```

---

## Running the backend (HTTPS)

The `https` launch profile already exists in `backend/Properties/launchSettings.json` and binds
**both** `https://localhost:7011` and `http://0.0.0.0:5226`.

### 1. Trust the ASP.NET Core development certificate (one time per machine)

```bash
dotnet dev-certs https --trust
```

Windows shows a certificate-install prompt — accept it. This is what stops the browser from warning
about an untrusted certificate on `localhost`.

Check it worked:

```bash
dotnet dev-certs https --check --trust
```

### 2. Run with the `https` profile

```bash
dotnet run --project .\explore_my_backend.csproj --launch-profile https
```

In Visual Studio, change the dropdown next to the ▶ Run button from `http` to `https`.

| Endpoint | URL |
|---|---|
| API base | `https://localhost:7011` |
| Swagger UI | `https://localhost:7011/swagger` |
| SignalR hub | `wss://localhost:7011/hubs/community-chat` |

### 3. Point the Flutter app at the HTTPS URL

No code change needed — the base URL is compile-time overridable:

```bash
flutter run --dart-define=API_BASE_URL=https://localhost:7011
```

The SignalR client derives its hub URL from the same value, so it upgrades to `wss://` automatically.

### Things to be aware of

- **CORS needs no change.** The `FlutterWebDev` policy in `Program.cs` matches origins by *host*
  only, so `https://localhost` is already allowed.
- **`https://localhost:7011` is loopback-only.** The Android emulator (`10.0.2.2`) and physical
  phones cannot reach it. To expose HTTPS on the network, change the profile's `applicationUrl` to
  `https://0.0.0.0:7011`.
- **The dev certificate is only trusted on your host machine.** An Android emulator or physical
  device has its own certificate store and will reject it with
  `HandshakeException: CERTIFICATE_VERIFY_FAILED`. Testing HTTPS from a device requires exporting the
  certificate and installing it on the device — plain HTTP over the LAN is the simpler dev path.
- **`UseHttpsRedirection()` is intentionally not enabled.** See the comment in `Program.cs`. Because
  the `https` profile binds both ports, turning redirection on would break any client still calling
  port `5226` over HTTP.

---

## Running the Flutter app

From the `frontend/` folder:

```bash
flutter pub get
```

```bash
flutter run
```

### Setting the backend URL

The default is `http://10.0.2.2:5226` — the alias the **Android emulator** maps to your host
machine's localhost. Override it without editing any file:

| Scenario | Command |
|---|---|
| Android emulator (default) | `flutter run` |
| Physical phone on same Wi-Fi | `flutter run --dart-define=API_BASE_URL=http://<your-lan-ip>:5226` |
| Flutter Web / Windows desktop | `flutter run --dart-define=API_BASE_URL=http://localhost:5226` |
| Backend over HTTPS (host only) | `flutter run --dart-define=API_BASE_URL=https://localhost:7011` |

Find your LAN IP on Windows with `ipconfig` (look for the Wi-Fi adapter's IPv4 address). For a
physical device the backend must listen on `0.0.0.0`, both devices must share a network, and Windows
Firewall must allow inbound traffic on port `5226`.

---

## Common database tasks

Apply pending migrations — run from the `backend/` folder:

```bash
dotnet ef database update
```

Create a new migration after changing an entity:

```bash
dotnet ef migrations add <MigrationName>
```

Clear the cached Google Places results (run in MySQL):

```sql
USE exploremy_dev;
TRUNCATE TABLE hidden_place_cache;
```

Re-seed the cache afterwards with `database/seed_data/SeedHiddenPlaceCache.sql` if needed.

---

## Tests

From the `backend/` folder:

```bash
dotnet test .\tests\ExploreMy.Api.Tests.csproj
```

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Connection string 'MySqlConnection' was not found` | User Secrets not set — re-run step 2 from the correct folder. |
| `Failed to determine the https port for redirect` | Expected on the `http` profile; harmless. |
| `CERTIFICATE_VERIFY_FAILED` from Flutter | The device doesn't trust the dev certificate. Use HTTP for device testing. |
| Emulator can't reach the API | Use `10.0.2.2`, not `localhost`, and make sure the backend binds `0.0.0.0`. |
| Physical phone can't reach the API | Wrong IP, different Wi-Fi network, or Windows Firewall blocking port `5226`. |
| CORS error in Flutter Web | Add your host to the `FlutterWebDev` policy in `Program.cs`. |
| Timestamps off by hours | All writes use `DateTime.UtcNow`; `UtcDateTimeConverter` normalises them on the way out. |

---

## Security notes

- **Never commit secrets.** API keys, passwords, and connection strings belong in User Secrets
  (development) or environment variables / a secrets manager (production) — never in
  `appsettings.json`, this README, or any tracked file.
- The **Supabase service-role key** bypasses row-level security and grants full database access.
  Treat it like a root password; it must never reach the Flutter client.
- The **JWT signing key** must be at least 32 characters and unique per environment. Anyone holding
  it can forge a valid token for any user.
- If a secret is ever committed or shared in plain text, **rotate it** — removing it from a later
  commit does not remove it from git history.
