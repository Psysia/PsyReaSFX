[CmdletBinding()]
param(
    [switch]$ReadOnly,
    [ValidateRange(0, 1800)][int]$WaitSeconds = 600
)
$ErrorActionPreference = 'Stop'
$headers = @{ 'User-Agent' = 'PsyReaSFX-runtime-sync'; Accept = 'application/vnd.github+json' }
if ($env:GH_TOKEN) { $headers.Authorization = "Bearer $env:GH_TOKEN" }
elseif ($env:GITHUB_TOKEN) { $headers.Authorization = "Bearer $env:GITHUB_TOKEN" }
function Get-Metadata([string]$Path, [switch]$Optional) {
    try { return Invoke-RestMethod -Uri "https://api.github.com/repos/$Path" -Headers $headers }
    catch {
        if ($Optional -and $_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) { return $null }
        throw
    }
}
$upstream = Get-Metadata 'zaibuyidao/ReaWebAPI/releases/latest'
$tag = [string]$upstream.tag_name
if ($tag -notmatch '^v\d+(\.\d+){2,3}$' -or $upstream.draft) { throw 'Unexpected upstream release.' }
$commit = (Get-Metadata "zaibuyidao/ReaWebAPI/commits/$tag").sha
$sourceHead = (Get-Metadata 'zaibuyidao/ReaWebAPI/commits/main').sha
if ($commit -notmatch '^[a-f0-9]{40}$' -or $sourceHead -notmatch '^[a-f0-9]{40}$') { throw 'Invalid upstream source commit.' }
function Test-MirrorReady {
    $mirror = Get-Metadata "Psysia/ReaWebAPI/releases/tags/$tag" -Optional
    if (-not $mirror -or $mirror.draft) { return $false }
    foreach ($name in @("ReaWebAPI-windows-x64-$tag.zip", 'reaper_reawebapi-x64.dll')) {
        $original = @($upstream.assets | Where-Object name -CEQ $name)
        $copied = @($mirror.assets | Where-Object name -CEQ $name)
        if ($original.Count -ne 1 -or $original[0].digest -notmatch '^sha256:[a-f0-9]{64}$') { throw "Upstream asset is not ready: $name" }
        if ($copied.Count -ne 1 -or $copied[0].digest -cne $original[0].digest) { throw "Published fork asset differs from upstream: $name" }
    }
    foreach ($name in @('ReaWebAPI-source.zip', 'mirror-manifest.json')) {
        if (@($mirror.assets | Where-Object name -CEQ $name).Count -ne 1) { throw "Published mirror is incomplete: $name" }
    }
    if ((Get-Metadata "Psysia/ReaWebAPI/commits/$tag").sha -cne $commit) { throw 'Fork tag does not match upstream.' }
    $forkHead = (Get-Metadata 'Psysia/ReaWebAPI/commits/main').sha
    if ($forkHead -ceq $sourceHead) { return $true }
    # The author can publish another source commit while the sync job is queued.
    return $forkHead -ceq (Get-Metadata 'zaibuyidao/ReaWebAPI/commits/main').sha
}
if (Test-MirrorReady) {
    Write-Host "Fork is current: $tag ($commit)."
    return $tag
}
if (-not $ReadOnly) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'Install GitHub CLI and run gh auth login to request immediate fork synchronization.' }
    $dispatch = & gh workflow run sync-upstream.yml --repo Psysia/ReaWebAPI --ref psyreasfx -f "tag=$tag"
    if ($LASTEXITCODE -ne 0) { throw 'Could not dispatch the fork sync workflow. Check gh auth status.' }
    Write-Host "Requested fork sync for $tag. $dispatch"
}
else { Write-Host "Waiting for the fork scheduled sync of $tag (read-only CI credential)." }
$deadline = [DateTime]::UtcNow.AddSeconds($WaitSeconds)
while ([DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Seconds ([Math]::Min(15, [Math]::Max(1, [int]($deadline - [DateTime]::UtcNow).TotalSeconds)))
    if (Test-MirrorReady) { Write-Host "Fork synchronized: $tag ($commit)."; return $tag }
}
throw "Fork sync has not completed. Inspect https://github.com/Psysia/ReaWebAPI/actions/workflows/sync-upstream.yml and retry. No older runtime was substituted for $tag."
