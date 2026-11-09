[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^v\d+(\.\d+){2,3}$')][string]$Tag,
    [string]$OutputPath = ''
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$version = $Tag.Substring(1)
if (-not $OutputPath) { $OutputPath = Join-Path $repoRoot "dist/reawebapi-candidates/$version.lock.json" }
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$active = [IO.Path]::GetFullPath((Join-Path $repoRoot 'dependencies/reawebapi/windows-x64.lock.json'))
if ($OutputPath -ieq $active -or (Test-Path -LiteralPath $OutputPath)) { throw 'Candidate output must be a new file, separate from the active dependency lock.' }
$headers = @{ 'User-Agent' = 'PsyReaSFX-dependency-candidate'; Accept = 'application/vnd.github+json' }
if ($env:GH_TOKEN) { $headers.Authorization = "Bearer $env:GH_TOKEN" }
elseif ($env:GITHUB_TOKEN) { $headers.Authorization = "Bearer $env:GITHUB_TOKEN" }
$api = 'https://api.github.com/repos/zaibuyidao/ReaWebAPI'
try {
    $release = Invoke-RestMethod -Uri "$api/releases/tags/$Tag" -Headers $headers
    $commit = (Invoke-RestMethod -Uri "$api/commits/$Tag" -Headers $headers).sha
}
catch { throw 'GitHub release metadata is unavailable or rate-limited. Retry later or use an existing GH_TOKEN/GITHUB_TOKEN environment credential. The active lock has not changed.' }
if ($commit -notmatch '^[a-f0-9]{40}$') { throw 'Could not resolve the release to a full commit.' }
$name = "ReaWebAPI-windows-x64-$Tag.zip"
$asset = @($release.assets | Where-Object { $_.name -ceq $name })
if ($asset.Count -ne 1 -or $asset[0].digest -notmatch '^sha256:[a-f0-9]{64}$') { throw 'Release is missing its Windows x64 asset or GitHub SHA-256 digest.' }
$work = Join-Path $env:TEMP "PsyReaSFX-runtime-candidate-$([guid]::NewGuid().ToString('N'))"
[IO.Directory]::CreateDirectory($work) | Out-Null
$archive = Join-Path $work $name
Invoke-WebRequest -Uri $asset[0].browser_download_url -OutFile $archive -UseBasicParsing
$archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($archiveHash -cne $asset[0].digest.Substring(7)) { throw 'GitHub release digest mismatch.' }
$sourceName = 'ReaWebAPI-source.zip'
$sourceUrl = "https://codeload.github.com/zaibuyidao/ReaWebAPI/zip/$commit"
$sourcePath = Join-Path $work $sourceName
Invoke-WebRequest -Uri $sourceUrl -OutFile $sourcePath -UseBasicParsing
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    $entry = $zip.GetEntry('UserPlugins/reaper_reawebapi-x64.dll')
    if (-not $entry) { throw 'Release layout changed. Review the upstream package before proceeding.' }
    $binary = Join-Path $work 'reaper_reawebapi-x64.dll'
    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $binary)
}
finally { $zip.Dispose() }
$lock = Get-Content -LiteralPath $active -Raw -Encoding UTF8 | ConvertFrom-Json
$lock.version = $version
$lock.commit = $commit
$lock.archive.url = $asset[0].browser_download_url
$lock.archive.file = $name
$lock.archive.sha256 = $archiveHash
$lock.binary.sha256 = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant()
$lock.source.url = $sourceUrl
$lock.source.file = $sourceName
$lock.source.sha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
$lock.runtime_policy.baseline_versions = @($version)
$lock.runtime_policy.validation_status = 'native_acceptance_pending'
[IO.Directory]::CreateDirectory((Split-Path -Parent $OutputPath)) | Out-Null
$candidate = Join-Path $work 'candidate.lock.json'
[IO.File]::WriteAllText($candidate, ($lock | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
& (Join-Path $PSScriptRoot 'Get-ReaWebAPIRuntime.ps1') -LockPath $candidate -CachePath $work -Destination (Join-Path $work 'verified')
[IO.File]::Move($candidate, $OutputPath)
Write-Host "Candidate prepared at $OutputPath. Active dependency lock is unchanged."
Write-Host 'Build using -DependencyLockPath, run regressions, and complete native REAPER acceptance before promoting this candidate.'
