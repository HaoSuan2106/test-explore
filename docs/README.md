# ExploreMy Email

Email: exploremy888@gmail.com

Password: exploreMy123

wcpa bzus zyri rmsn



Organization: ExploreMy

Supabase password : exploreMy123@123





dotnet run --project .\\explore\_my\_backend.csproj --urls "http://0.0.0.0:5226"





# **Configure User Secrets**

Open a terminal in the folder containing explore\_my\_backend.csproj, then run:



dotnet user-secrets set "Supabase:ServiceRoleKey" 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx2cWZ2b2Fib3Zzd2p4empqYndhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njg2NDg3NiwiZXhwIjoyMTAyNDQwODc2fQ.IwlHrJWC4sc6qlZEVBqzXLR\_QKhu\_LcET2lxmblrYxA' --project ".\\explore\_my\_backend.csproj"

dotnet user-secrets set "Smtp:Password" 'wcpa bzus zyri rmsn' --project ".\\explore\_my\_backend.csproj"

dotnet user-secrets set "Jwt:Key" 'VzmsrIpoj8JcE4fvuQUBB0RzNNwONq0uBwZnq5hIHkv5YbkFY0400M0PoArgyWM0' --project ".\\explore\_my\_backend.csproj"

dotnet user-secrets set "ConnectionStrings:MySqlConnection" 'server=localhost;port=3306;database=exploremy\_dev;user=exploremy\_app;password=exploreMy123;' --project ".\\explore\_my\_backend.csproj"
dotnet user-secrets set "GoogleApi:ApiKey" "AIzaSyBDmaSFhdyQChdfMpRFkGo1aBTeDShjW58" --project ".\\explore\_my\_backend.csproj"

//qizhan
//删除hidden_place_cache的data记录，在mysql写
USE exploremy_dev;
TRUNCATE TABLE hidden_place_cache;
//更新mysql的table，在backend terminal写
dotnet ef database update
