[CmdletBinding()]
param(
    [ValidatePattern('^(latest|v\d+(\.\d+){2,3})$')][string]$Tag = 'latest',
    [string]$OutputPath = '',
    [string]$CachePath = ''
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$repository = 'Psysia/ReaWebAPI'
$active = [IO.Path]::GetFullPath((Join-Path $repoRoot 'dependencies/reawebapi/windows-x64.lock.json'))
if ($OutputPath) {
    $OutputPath = [IO.Path]::GetFullPath($OutputPath)
    if ($OutputPath -ieq $active -or (Test-Path -LiteralPath $OutputPath)) { throw 'Candidate output must be a new file, separate from the active dependency lock.' }
}
$headers = @{ 'User-Agent' = 'PsyReaSFX-dependency-candidate'; Accept = 'application/vnd.github+json' }
if ($env:GH_TOKEN) { $headers.Authorization = "Bearer $env:GH_TOKEN" }
elseif ($env:GITHUB_TOKEN) { $headers.Authorization = "Bearer $env:GITHUB_TOKEN" }
$api = "https://api.github.com/repos/$repository"
$releasePath = if ($Tag -ceq 'latest') { 'latest' } else { "tags/$Tag" }
$release = Invoke-RestMethod -Uri "$api/releases/$releasePath" -Headers $headers
if ($release.draft -or $release.tag_name -notmatch '^v\d+(\.\d+){2,3}$' -or ($Tag -cne 'latest' -and $release.tag_name -cne $Tag)) { throw 'Unexpected mirror release tag or publication state.' }
$Tag = $release.tag_name
$version = $Tag.Substring(1)
$commit = (Invoke-RestMethod -Uri "$api/commits/$Tag" -Headers $headers).sha
if ($commit -notmatch '^[a-f0-9]{40}$') { throw 'Could not resolve the mirror release to a full commit.' }
if (-not $OutputPath) { $OutputPath = Join-Path $repoRoot "dist/reawebapi-candidates/$version.lock.json" }
if (Test-Path -LiteralPath $OutputPath) { throw 'Candidate output must be a new file.' }
if (-not $CachePath) { $CachePath = Join-Path $env:LOCALAPPDATA "PsyReaSFX/build-cache/reawebapi/$version" }
[IO.Directory]::CreateDirectory($CachePath) | Out-Null
$work = Join-Path $env:TEMP "PsyReaSFX-runtime-candidate-$([guid]::NewGuid().ToString('N'))"
[IO.Directory]::CreateDirectory($work) | Out-Null

function Get-MirrorAsset([string]$Name) {
    $foundAssets = @($release.assets | Where-Object { $_.name -ceq $Name })
    if ($foundAssets.Count -ne 1 -or $foundAssets[0].digest -notmatch '^sha256:[a-f0-9]{64}$') { throw "Missing mirror asset or digest: $Name" }
    if ($foundAssets[0].browser_download_url -cne "https://github.com/$repository/releases/download/$Tag/$Name") { throw "Unexpected mirror download URL: $Name" }
    return $foundAssets[0]
}
function Save-VerifiedAsset($Asset, [string]$Folder) {
    $path = Join-Path $Folder $Asset.name
    if (-not (Test-Path -LiteralPath $path)) {
        $temporary = "$path.$([guid]::NewGuid().ToString('N')).tmp"
        try {
            Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $temporary -UseBasicParsing
            if ((Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant() -cne $Asset.digest.Substring(7)) { throw 'GitHub release digest mismatch.' }
            Move-Item -LiteralPath $temporary -Destination $path
        }
        finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
    }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $Asset.digest.Substring(7)) { throw "Cached mirror digest mismatch: $path" }
    return $path
}
$bundleAsset = Get-MirrorAsset "ReaWebAPI-windows-x64-$Tag.zip"
$sourceAsset = Get-MirrorAsset 'ReaWebAPI-source.zip'
$dllAsset = Get-MirrorAsset 'reaper_reawebapi-x64.dll'
$manifestPath = Save-VerifiedAsset (Get-MirrorAsset 'mirror-manifest.json') $work
$mirror = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($mirror.schema -cne 'PsyReaSFX-ReaWebAPI-Mirror-v1' -or $mirror.repository -cne $repository -or
    $mirror.upstream -cne 'zaibuyidao/ReaWebAPI' -or $mirror.modified -cne $false -or $mirror.tag -cne $Tag -or $mirror.commit -cne $commit) { throw 'Mirror provenance does not match the release.' }
foreach ($asset in @($bundleAsset, $sourceAsset, $dllAsset)) {
    if ($mirror.files.($asset.name) -cne $asset.digest.Substring(7)) { throw "Mirror manifest digest mismatch: $($asset.name)" }
}
$lock = Get-Content -LiteralPath $active -Raw -Encoding UTF8 | ConvertFrom-Json
$policy = $lock.runtime_policy
if ($mirror.contracts.protocol -ne $policy.protocol -or $mirror.contracts.runtime -notin $policy.runtime_contracts -or
    $mirror.contracts.web -notin $policy.web_contracts -or $mirror.contracts.max_message_bytes -lt $policy.minimum_message_bytes) {
    throw 'Upstream runtime contracts are incompatible with this app. Update the adapter and tests before adopting this release.'
}
$null = Save-VerifiedAsset $bundleAsset $CachePath
$sourcePath = Save-VerifiedAsset $sourceAsset $CachePath
Add-Type -AssemblyName System.IO.Compression.FileSystem
$sourceZip = [IO.Compression.ZipFile]::OpenRead($sourcePath)
try {
    if (-not $sourceZip.GetEntry("ReaWebAPI-$commit/src/core/core.cpp")) { throw 'Source archive does not match the release commit.' }
}
finally { $sourceZip.Dispose() }
$lock.version = $version
$lock.repository = "https://github.com/$repository"
$lock.commit = $commit
$lock.archive.url = $bundleAsset.browser_download_url
$lock.archive.file = $bundleAsset.name
$lock.archive.sha256 = $bundleAsset.digest.Substring(7)
$lock.binary.sha256 = $dllAsset.digest.Substring(7)
$lock.source.url = $sourceAsset.browser_download_url
$lock.source.file = $sourceAsset.name
$lock.source.sha256 = $sourceAsset.digest.Substring(7)
$lock.runtime_policy.baseline_versions = @($version)
$lock.runtime_policy.validation_status = 'native_acceptance_pending'
$candidate = Join-Path $work 'candidate.lock.json'
[IO.File]::WriteAllText($candidate, ($lock | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
& (Join-Path $PSScriptRoot 'Get-ReaWebAPIRuntime.ps1') -LockPath $candidate -CachePath $CachePath -Destination (Join-Path $work 'verified')
[IO.Directory]::CreateDirectory((Split-Path -Parent $OutputPath)) | Out-Null
[IO.File]::Move($candidate, $OutputPath)
Write-Host "Candidate prepared at $OutputPath from $repository $Tag. Active dependency lock is unchanged."
