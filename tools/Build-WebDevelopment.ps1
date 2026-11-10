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
$package = Join-Path $OutputDirectory 'package'
$appVersion = (Get-Content -LiteralPath (Join-Path $repoRoot 'src/web/app.json') -Raw -Encoding UTF8 | ConvertFrom-Json).version
$archive = Join-Path $OutputDirectory "PsyReaSFX_WebView_${appVersion}_ReaWebAPI_${tag}_dev_win_x64.zip"
& (Join-Path $PSScriptRoot 'Build-WebRelease.ps1') -DependencyLockPath $candidate -OutputPath $package -ArchivePath $archive
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'SHA256SUMS.txt'), "$hash  $([IO.Path]::GetFileName($archive))`n", (New-Object Text.UTF8Encoding($false)))
Write-Host "Development build uses the latest published upstream runtime, mirrored by Psysia: $tag."
Write-Host "Package: $archive"
Write-Host 'Native REAPER acceptance remains pending; the active release lock is unchanged.'
