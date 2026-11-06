<#
.SYNOPSIS
    KubeCon AKS capture-the-flag lab - open the event leaderboard to attendees: publish its submit URL to the secret
    gist behind the event's registration link, https://aka.ms/aksctfsecrets.

.DESCRIPTION
    Attendees join the leaderboard from the lab instructions (Get started, Task 6): the lab repository's
    scoring/join-leaderboard.ps1 (or .sh) reads the submit URL from the registration link, which points at one file
    in a secret GitHub gist. So a new token needs no change to the lab profile, its life cycle actions, or the lab
    instructions: this script writes the file with the submit URL that leaderboard/setup wrote
    (.lab/leaderboard/submit-url.txt), and then checks that the link serves it.

    The first run creates the secret gist, and prints the address to point the link at, once. Later runs update the
    same gist, which .lab/leaderboard/gist.env records. -Close publishes "no leaderboard is open"; leaderboard/cleanup
    does that too.

    Needs the GitHub CLI, signed in with the gist scope (gh auth login). Anyone with the link can read the token, as
    anyone on a lab VM can: see leaderboard/README.md, Security.

.EXAMPLE
    ./leaderboard/publish.ps1                     # after ./leaderboard/setup.ps1
.EXAMPLE
    ./leaderboard/publish.ps1 -Close              # no new joins
#>
#Requires -Version 7.4
[CmdletBinding()]
param(
    # The gist's ID or address. Default: the one in .lab/leaderboard/gist.env, else a new secret gist.
    [string]$Gist,
    # The registration link that the attendees' join script reads.
    [ValidatePattern('^https://')][string]$Link = 'https://aka.ms/aksctfsecrets',
    # Publish "no leaderboard is open" instead of the submit URL.
    [switch]$Close,
    # How long to wait for the link to serve the new file: GitHub takes a few seconds to serve a new version. 0 doesn't
    # check the link.
    [ValidateRange(0, 30)][int]$WaitMinutes = 3
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$outDir = Join-Path $repoRoot '.lab/leaderboard'
$gistEnv = Join-Path $outDir 'gist.env'
$fileName = 'kubecon-ctf-leaderboard.env'
$submitPattern = '^https://[a-z0-9]{3,24}\.blob\.core\.windows\.net/[a-z0-9-]{3,63}\?\S*sig='

function Write-Step([string]$Message) { Write-Host ''; Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Info([string]$Message) { Write-Host "    $Message" }
function Write-Ok([string]$Message) { Write-Host '    ' -NoNewline; Write-Host 'OK' -ForegroundColor Green -NoNewline; Write-Host "  $Message" }
function Get-EnvValue([string]$Path, [string]$Key) {
    if (Test-Path -LiteralPath $Path) {
        foreach ($line in Get-Content -LiteralPath $Path) { if ($line -match "^$Key=(.*)$") { return $Matches[1].Trim() } }
    }
    return ''
}
# gh ...; the request body, which can hold the token, goes through a temporary file, never the command line.
function Invoke-Gh([string[]]$Arguments, [string]$Body) {
    $err = New-TemporaryFile
    $in = $null
    try {
        if ($Body) {
            $in = New-TemporaryFile
            [IO.File]::WriteAllText($in.FullName, $Body, [Text.UTF8Encoding]::new($false))
            $Arguments += @('--input', $in.FullName)
        }
        $out = & gh @Arguments 2>$err.FullName
        if ($LASTEXITCODE -ne 0) { throw "gh $($Arguments[0..2] -join ' ') failed: $(((Get-Content -Raw $err.FullName) -replace '\s+', ' ').Trim())" }
        return ($out | Out-String).Trim()
    }
    finally {
        Remove-Item $err.FullName -ErrorAction SilentlyContinue
        if ($in) { Remove-Item $in.FullName -ErrorAction SilentlyContinue }
    }
}
# What the registration link serves: the submit URL in its file ('' when closed), or why it has none.
function Read-Link([string]$Uri) {
    try {
        $r = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 20 -SkipHttpErrorCheck
        $final = [string]$r.BaseResponse.RequestMessage.RequestUri
        $text = if ($r.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }
        if ($text -notmatch '(?m)^CTF_LEADERBOARD_URL=' -and $final -match '^https://gist\.github\.com/[^/?#]+/[0-9a-fA-F]+/?$') {
            $r = Invoke-WebRequest -Uri ($final.TrimEnd('/') + '/raw') -UseBasicParsing -TimeoutSec 20 -SkipHttpErrorCheck
            $final = [string]$r.BaseResponse.RequestMessage.RequestUri
            $text = if ($r.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }
        }
        # As the join script does: a unique query string reads the newest version, which GitHub doesn't cache.
        if ($final -match '^https://gist\.githubusercontent\.com/[^?#]+$') {
            $r = Invoke-WebRequest -Uri "${final}?nocache=$([guid]::NewGuid().ToString('N'))" -UseBasicParsing -TimeoutSec 20 -SkipHttpErrorCheck
            $text = if ($r.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }
        }
    }
    catch { return [pscustomobject]@{ State = 'error'; Value = ''; Detail = $_.Exception.Message } }
    if ($text -match '(?m)^CTF_LEADERBOARD_URL=(.*)$') { return [pscustomobject]@{ State = 'file'; Value = $Matches[1].Trim(); Detail = $final } }
    if ($final -match '^https://www\.bing\.com/.*[?&]shorturl=') { return [pscustomobject]@{ State = 'missing'; Value = ''; Detail = $final } }
    return [pscustomobject]@{ State = 'other'; Value = ''; Detail = "HTTP $([int]$r.StatusCode) from $final" }
}

Write-Step 'Checking prerequisites'
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'The GitHub CLI (gh) is required: https://cli.github.com' }
$login = Invoke-Gh @('api', 'user', '--jq', '.login')
Write-Info "GitHub account $login"
$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
$header = '# Read by scoring/join-leaderboard.ps1 and .sh in https://github.com/bbenz/kubecon26-pre-day-lab: never run.'
if ($Close) {
    $url = ''
    $lines = @($header, "# No KubeCon CTF leaderboard is open. Published by leaderboard/publish, $now UTC.")
    Write-Info 'Publishing: no leaderboard is open'
}
else {
    $saved = Join-Path $outDir 'submit-url.txt'
    if (-not (Test-Path -LiteralPath $saved)) { throw "Run ./leaderboard/setup.ps1 first: it writes $saved." }
    $url = (Get-Content -Raw -LiteralPath $saved).Trim()
    if ($url -notmatch $submitPattern) { throw "$saved doesn't have a submit URL: run ./leaderboard/setup.ps1 again." }
    if ($url -notmatch '[?&]sp=c(&|$)') { throw 'The token must only add results (sp=c): run ./leaderboard/setup.ps1 again.' }
    $expires = Get-EnvValue (Join-Path $outDir 'settings.env') 'LB_TOKEN_EXPIRES'
    $expiresAt = [DateTimeOffset]::MinValue
    if ($expires -and [DateTimeOffset]::TryParse($expires, [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$expiresAt) -and $expiresAt -le [DateTimeOffset]::UtcNow) {
        throw "The token expired at $expires UTC: run ./leaderboard/setup.ps1 to issue a new one."
    }
    $lines = @($header,
        "# KubeCon CTF leaderboard: a token that can add results, not read them. Expires $expires UTC.",
        "# Published by leaderboard/publish, $now UTC.")
    Write-Info "Publishing the submit URL from $saved (token expires $expires UTC)"
}
$content = (($lines + "CTF_LEADERBOARD_URL=$url") -join "`n") + "`n"

Write-Step 'Secret gist'
$gistId = ''
if ($Gist) {
    if ($Gist -notmatch '([0-9a-fA-F]{20,})/?$') { throw "-Gist must be a gist's ID or address: $Gist" }
    $gistId = $Matches[1]
}
else { $gistId = Get-EnvValue $gistEnv 'LB_GIST_ID' }
$files = @{ $fileName = @{ content = $content } }
if ($gistId) {
    try { $info = Invoke-Gh @('api', "gists/$gistId", '--jq', '[(.public | tostring), .owner.login, .html_url] | @tsv') }
    catch { throw "Can't read gist $gistId with GitHub account ${login}: $($_.Exception.Message) To start over with a new gist, delete $gistEnv, and point the registration link at the new one." }
    $public, $owner, $page = $info -split "`t"
    if ($public -ne 'false') { throw "Gist $gistId is public. Use a secret gist: leave out -Gist (and delete $gistEnv, if it names this gist), and run this again to create one." }
    Invoke-Gh @('api', '-X', 'PATCH', "gists/$gistId", '--jq', '.id') (@{ files = $files } | ConvertTo-Json -Depth 5) | Out-Null
    Write-Ok "updated $page"
}
else {
    $body = @{ description = 'KubeCon CTF leaderboard registration (see leaderboard/README.md)'; public = $false; files = $files } | ConvertTo-Json -Depth 5
    $gistId, $owner, $page = (Invoke-Gh @('api', '-X', 'POST', 'gists', '--jq', '[.id, .owner.login, .html_url] | @tsv') $body) -split "`t"
    Write-Ok "created a secret gist: $page"
}
# The file's address without a revision, so it always serves the latest version.
$raw = "https://gist.githubusercontent.com/$owner/$gistId/raw/$fileName"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$record = @(
    '# Written by leaderboard/publish - the secret gist behind the registration link (no token here)'
    "LB_GIST_ID=$gistId", "LB_GIST_OWNER=$owner", "LB_GIST_RAW_URL=$raw", "LB_REGISTRATION_LINK=$Link"
)
[IO.File]::WriteAllText($gistEnv, ($record -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
Write-Info "File: $raw"

if ($WaitMinutes -eq 0) { Write-Info "Didn't check $Link (-WaitMinutes 0)."; return }
Write-Step "Registration link $Link"
$deadline = (Get-Date).AddMinutes($WaitMinutes)
$waited = $false
while ($true) {
    $served = Read-Link $Link
    if ($served.State -eq 'file' -and $served.Value -eq $url) { break }
    if ($served.State -eq 'missing') {
        Write-Warning "$Link isn't set up yet. In the aka.ms portal, point it at $raw (once), and then run this script again to check it."
        exit 1
    }
    if ($served.State -eq 'other') {
        Write-Warning "$Link doesn't serve the gist's file ($($served.Detail)). Point it at $raw, and then run this script again to check it."
        exit 1
    }
    if ((Get-Date) -gt $deadline) {
        $what = if ($served.State -eq 'error') { "can't be read: $($served.Detail)" } else { 'still serves an earlier version' }
        Write-Warning "$Link $what after $WaitMinutes minutes. Check that it points at $raw, and run this script again."
        exit 1
    }
    if (-not $waited) { Write-Info 'Waiting for the link to serve the new version ...'; $waited = $true }
    Start-Sleep -Seconds 10
}
if ($Close) { Write-Ok 'serves "no leaderboard is open": attendees who join now are told so' }
else { Write-Ok 'serves the new submit URL: attendees can join (lab instructions, Get started, Task 6)' }
