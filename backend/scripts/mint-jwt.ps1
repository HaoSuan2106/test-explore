param(
    [int]$UserId = 1,
    [string]$Email = "alice@example.com",
    [string]$Username = "alice"
)
$key = "VzmsrIpoj8JcE4fvuQUBB0RzNNwONq0uBwZnq5hIHkv5YbkFY0400M0PoArgyWM0"
function B64Url([byte[]]$bytes) {
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('/','_').Replace('+','-')
}
$now = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
$header = B64Url ([Text.Encoding]::UTF8.GetBytes('{"alg":"HS256","typ":"JWT"}'))
$payloadJson = "{`"iss`":`"ExploreMyAPI`",`"aud`":`"ExploreMyClient`",`"sub`":`"$UserId`",`"email`":`"$Email`",`"username`":`"$Username`",`"jti`":`"test-$now-$(Get-Random)`",`"exp`":2147483647,`"iat`":$now}"
$payload = B64Url ([Text.Encoding]::UTF8.GetBytes($payloadJson))
$hmac = [Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($key))
$sig = B64Url ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes("$header.$payload")))
Write-Output "$header.$payload.$sig"
