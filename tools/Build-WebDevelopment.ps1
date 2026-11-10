[CmdletBinding()]
param(
    [string]$OutputDirectory = '',
    [switch]$ReadOnlySync,
    [ValidateRange(0, 1800)][int]$SyncWaitSeconds = 600
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) {
    $name = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6)
    $OutputDirectory = Join-Path $repoRoot "dist/webview-development/$name"
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Choose a new development output directory.' }
$tag = & (Join-Path $PSScriptRoot 'Sync-ReaWebAPIFork.ps1') -ReadOnly:$ReadOnlySync -WaitSeconds $SyncWaitSeconds
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$candidate = Join-Path $OutputDirectory 'runtime.lock.json'
& (Join-Path $PSScriptRoot 'New-ReaWebAPICandidate.ps1') -Tag $tag -OutputPath $candidate
$selected = Get-Content -LiteralPath $candidate -Raw | ConvertFrom-Json
$source = Join-Path $env:LOCALAPPDATA "PsyReaSFX/build-cache/reawebapi/$($selected.version)/$($selected.source.file)"
$report = Join-Path $OutputDirectory 'upstream-dock-compatibility.json'
python (Join-Path $PSScriptRoot 'reawebapi-fork/check_dock_compatibility.py') $source --report $report
if ($LASTEXITCODE -ne 0) { throw 'Candidate compatibility checker failed.' }
$compatibility = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
if (-not $compatibility.compatible) {
    # Keep checking/mirroring the newest upstream every run, but never package
    # a known regression just because its release number is newer.
    Copy-Item -LiteralPath $candidate -Destination (Join-Path $OutputDirectory 'upstream-candidate.lock.json')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'dependencies/reawebapi/windows-x64.lock.json') -Destination $candidate -Force
    $selected = Get-Content -LiteralPath $candidate -Raw | ConvertFrom-Json
    Write-Warning "Upstream $tag Docker check $($compatibility.status): $($compatibility.detail). Building pinned compatibility runtime $($selected.version)."
}
$package = Join-Path $OutputDirectory 'package'
$appVersion = (Get-Content -LiteralPath (Join-Path $repoRoot 'src/web/app.json') -Raw -Encoding UTF8 | ConvertFrom-Json).version
$archive = Join-Path $OutputDirectory "PsyReaSFX_WebView_${appVersion}_ReaWebAPI_v$($selected.version)_dev_win_x64.zip"
& (Join-Path $PSScriptRoot 'Build-WebRelease.ps1') -DependencyLockPath $candidate -OutputPath $package -ArchivePath $archive
if ($env:CI -or $compatibility.status -ne 'unverified') {
    $selectedReport = Join-Path $OutputDirectory 'selected-dock-compatibility.json'
    python (Join-Path $PSScriptRoot 'reawebapi-fork/check_dock_compatibility.py') (Join-Path $package "sources/$($selected.source.file)") --report $selectedReport
    if ($LASTEXITCODE -ne 0 -or -not (Get-Content $selectedReport -Raw | ConvertFrom-Json).compatible) {
        throw 'Selected runtime failed the native Docker regression. Do not publish this development artifact.'
    }
}
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'SHA256SUMS.txt'), "$hash  $([IO.Path]::GetFileName($archive))`n", (New-Object Text.UTF8Encoding($false)))
Write-Host "Checked upstream $tag; development package uses ReaWebAPI $($selected.version). Docker regression: $($compatibility.status)."
Write-Host "Package: $archive"
Write-Host 'Native REAPER acceptance remains pending; the active release lock is unchanged.'
