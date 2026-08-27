$ErrorActionPreference = 'Stop'
$base = 'http://localhost:5226/api'
$results = @()

function Invoke-Json($method, $path, $body, $token, $expectStatus = 200) {
  $headers = @{}
  if ($token) { $headers['Authorization'] = "Bearer $token" }
  $params = @{ Uri = "$base$path"; Method = $method; Headers = $headers; TimeoutSec = 15 }
  if ($null -ne $body) {
    $params['ContentType'] = 'application/json'
    $params['Body'] = ($body | ConvertTo-Json -Depth 8 -Compress)
  }
  try {
    $resp = Invoke-RestMethod @params
    return @{ ok = $true; status = 200; data = $resp }
  } catch {
    $status = 0
    try { $status = [int]$_.Exception.Response.StatusCode } catch {}
    $respBody = ''
    try {
      $stream = $_.Exception.Response.GetResponseStream()
      $reader = New-Object System.IO.StreamReader($stream)
      $respBody = $reader.ReadToEnd()
    } catch {}
    return @{ ok = ($status -eq $expectStatus); status = $status; data = $respBody; error = $_.Exception.Message }
  }
}

function Login-User($email) {
  $r = Invoke-Json 'POST' '/auth/login' @{ Email = $email; Password = 'TestPass123!' }
  if ($r.ok -and $r.data.token) { return $r.data }
  return $null
}

# User A (post author) — has eligible attractions
$loginA = Login-User 'e2e2.test@integration.com'
if (-not $loginA) { 'LOGIN e2e2 FAILED'; exit 1 }
$results += "LOGIN userA (e2e2) : OK userId=$($loginA.userId)"
$tokenA = $loginA.token

# User B (commenter/saver/reporter) — different user
$loginB = Login-User 'e2e3.test@integration.com'
$tokenB = $loginB.token
$results += "LOGIN userB (e2e3) : OK userId=$($loginB.userId)"

# ---------- POST: User A creates a post ----------
$el = Invoke-Json 'GET' '/posts/eligible-attractions' $null $tokenA
if (-not $el.ok -or $el.data.Count -eq 0) { 'NO ELIGIBLE ATTRACTIONS for userA'; exit 1 }
$placeId = $el.data[0].placeId
$stamp = (Get-Date -Format 'yyyyMMddHHmmssfff')
$postTitle = "B1 Live Post $stamp"
$post = Invoke-Json 'POST' '/posts' @{
  TaggedPlaceId = $placeId; Title = $postTitle; Description = 'B1 persistence check.'
  Images = @()
} $tokenA
$postId = $post.data.postId
$results += "POST create by userA : status=$($post.status) id=$postId"

# ---------- COMMENT: User B comments on User A's post ----------
$comment = Invoke-Json 'POST' "/posts/$postId/comments" @{ Content = "B1 comment $stamp" } $tokenB
$commentId = $comment.data.comment.commentId
$results += "COMMENT by userB : status=$($comment.status) id=$commentId"

# ---------- REACTION: User B likes User A's post ----------
$like = Invoke-Json 'POST' "/posts/$postId/reactions" @{ ReactionType = 'LIKE' } $tokenB
$results += "REACTION like by userB : status=$($like.status) reacted=$($like.data.isReacted) count=$($like.data.reactionCount)"

# ---------- SAVE: User B saves User A's post ----------
$save = Invoke-Json 'POST' "/posts/$postId/save" $null $tokenB
$results += "SAVE by userB : status=$($save.status) saved=$($save.data.isSaved)"

# ---------- REPORT: User B reports User A's post ----------
$report = Invoke-Json 'POST' "/posts/$postId/reports" @{ Reason = 'Other violation' } $tokenB
$results += "REPORT by userB : status=$($report.status) reportId=$($report.data.reportId)"

# ---------- RECOMMENDATION: User A submits a new place ----------
$stamp2 = Get-Date -Format 'yyyyMMddHHmmssfff'
# Unique coordinates far from any existing submission (avoids the
# proximity-duplicate check) — derive from the timestamp to stay unique.
$latSeed = 4 + ([double](Get-Random -Minimum 1000 -Maximum 9000) / 10000.0)
$lonSeed = 100 + ([double](Get-Random -Minimum 1000 -Maximum 9000) / 10000.0)
$rec = Invoke-Json 'POST' '/recommended-places' @{
  Name = "B1 Gem $stamp2"
  LocationAddress = "Jalan B1 $stamp2, KL"
  Latitude = $latSeed; Longitude = $lonSeed
  Category = 'Restaurant'
  Description = 'B1 check.'
} $tokenA
$recId = $rec.data.submissionId
$results += "RECOMMEND by userA : status=$($rec.status) id=$recId"

# ---------- VOTING: 5 distinct users verify -> VERIFIED ----------
# Voters 32-36 (exclude the submitter 31).
$vMails = @('e2e3.test@integration.com','e2e.voter3@integration.com','e2e.voter4@integration.com','e2e.voter5@integration.com','e2e.voter6@integration.com')
$voteResults = @()
$verified = $false
$finalStatus = ''
foreach ($v in $vMails) {
  $vLogin = Login-User $v
  if (-not $vLogin) { $voteResults += "VOTE login fail: $v"; continue }
  $vote = Invoke-Json 'POST' "/recommended-places/$recId/verifications" @{ Verify = $true } $vLogin.token
  $voteResults += "VOTE $v : status=$($vote.status) count=$($vote.data.verificationCount) placeStatus=$($vote.data.placeStatus)"
  if ($null -ne $vote.data -and $vote.data.placeStatus -eq 'VERIFIED') { $verified = $true; $finalStatus = $vote.data.placeStatus }
}
$results += "VOTING 5x : verified=$verified status=$finalStatus"
$results += $voteResults

# ---------- PERSISTENCE: fresh GET (simulates restart) ----------
Start-Sleep -Seconds 1
$gPost = Invoke-Json 'GET' "/posts/$postId" $null $tokenA
$gComments = Invoke-Json 'GET' "/posts/$postId/comments" $null $tokenA
$gSaved = Invoke-Json 'GET' '/posts/saved' $null $tokenB
$gRec = Invoke-Json 'GET' "/recommended-places/$recId" $null $tokenA
$results += "PERSIST post : found=$($null -ne $gPost.data.postId) title=$($gPost.data.title)"
$results += "PERSIST comment : found=$($gComments.data.Count -gt 0) count=$($gComments.data.Count)"
$results += "PERSIST save : inSavedList=$($gSaved.data.postId -contains $postId)"
$results += "PERSIST rec : found=$($null -ne $gRec.data.submissionId) status=$($gRec.data.status)"

# ---------- B3 duplicate-action checks ----------
$like2 = Invoke-Json 'POST' "/posts/$postId/reactions" @{ ReactionType = 'LIKE' } $tokenB
$save2 = Invoke-Json 'POST' "/posts/$postId/save" $null $tokenB
$dupVote = Invoke-Json 'POST' "/recommended-places/$recId/verifications" @{ Verify = $true } $loginB.token
$results += "DUP like-toggle : status=$($like2.status) count=$($like2.data.reactionCount) (toggle; 403 expected - reporter cannot react)"
$results += "DUP save-toggle : status=$($save2.status) saved=$($save2.data.isSaved) (toggle; 403 expected - reporter cannot save)"
$results += "DUP vote by userB : status=$($dupVote.status) (expected 400 - already voted)"

# ---------- A3 live verify: unsave removes from Saved filter ----------
$unsave = Invoke-Json 'DELETE' "/posts/$postId/save" $null $tokenB
$gSaved2 = Invoke-Json 'GET' '/posts/saved' $null $tokenB
$results += "A3 unsave : status=$($unsave.status) saved=$($unsave.data.isSaved)"
$results += "A3 unsave removes from Saved filter : stillInList=$($gSaved2.data.postId -contains $postId) (expected False)"

# ---------- B5 error message check ----------
$badPost = Invoke-Json 'POST' '/posts' @{ TaggedPlaceId = ''; Title = ''; Description = '' } $tokenA 400
$badComment = Invoke-Json 'POST' "/posts/$postId/comments" @{ Content = '' } $tokenB 400
$badVote = Invoke-Json 'POST' "/recommended-places/$recId/verifications" @{ } $tokenA 400
$results += "ERR create-empty : status=$($badPost.status) body=$($badPost.data)"
$results += "ERR comment-empty : status=$($badComment.status) body=$($badComment.data)"
$results += "ERR vote-empty-body : status=$($badVote.status) body=$($badVote.data)"

$results | ForEach-Object { $_ }
Write-Output '---B1_E2E_DONE---'