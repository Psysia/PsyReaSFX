[CmdletBinding()]
param(
    [string]$LockPath = (Join-Path $PSScriptRoot '../dependencies/reawebapi/windows-x64.lock.json'),
    [Parameter(Mandatory = $true)][string]$Destination,
    [string]$CachePath = ''
)
$ErrorActionPreference = 'Stop'
$lock = Get-Content -LiteralPath $LockPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($lock.schema -cne 'PsyReaSFX-Dependency-Lock-v1' -or $lock.platform -cne 'windows-x64') {
    throw 'Unsupported ReaWebAPI dependency lock.'
}
if ($lock.version -notmatch '^\d+(\.\d+){2,3}$' -or $lock.binary.file -cne 'reaper_reawebapi-x64.dll') {
    throw 'Invalid runtime version or binary name.'
}
if (-not $CachePath) { $CachePath = Join-Path $env:LOCALAPPDATA "PsyReaSFX/build-cache/reawebapi/$($lock.version)" }
$CachePath = [IO.Path]::GetFullPath($CachePath)
$Destination = [IO.Path]::GetFullPath($Destination)
[IO.Directory]::CreateDirectory($CachePath) | Out-Null

function Get-LockedDownload($Spec) {
    if ($Spec.sha256 -notmatch '^[a-f0-9]{64}$' -or $Spec.file -ne [IO.Path]::GetFileName($Spec.file)) {
        throw 'Invalid locked asset name or checksum.'
    }
    $uri = [Uri]$Spec.url
    if ($uri.Scheme -cne 'https' -or $uri.Host -notin @('github.com', 'codeload.github.com')) {
        throw 'Dependency downloads must use the official HTTPS repository.'
    }
    $path = Join-Path $CachePath $Spec.file
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $Spec.sha256) { return $path }
        throw "Cached dependency checksum mismatch. Remove or replace this cache file: $path"
    }
    $temporary = "$path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        Invoke-WebRequest -Uri $Spec.url -OutFile $temporary -UseBasicParsing
        if ((Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant() -cne $Spec.sha256) {
            throw "Downloaded dependency checksum mismatch: $($Spec.file)"
        }
        Move-Item -LiteralPath $temporary -Destination $path
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
    return $path
}

$runtimeArchive = Get-LockedDownload $lock.archive
$sourceArchive = Get-LockedDownload $lock.source
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($runtimeArchive)
try {
    $binaryDirectory = Join-Path $Destination 'runtime/reawebapi'
    $licenseDirectory = Join-Path $Destination 'licenses/reawebapi'
    $sourceDirectory = Join-Path $Destination 'sources'
    foreach ($directory in @($binaryDirectory, $licenseDirectory, $sourceDirectory)) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
    }
    $entry = $zip.GetEntry($lock.binary.entry)
    if (-not $entry) { throw 'The locked runtime archive is missing its native extension.' }
    $binary = Join-Path $binaryDirectory $lock.binary.file
    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $binary, $true)
    if ((Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant() -cne $lock.binary.sha256) {
        throw 'The native extension differs from the dependency lock.'
    }
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -notmatch '^ReaWebAPI/(COPYING(?:\.LESSER)?|LICENSE\.md|THIRD_PARTY\.md|licenses/[^/]+)$') { continue }
        $relative = $entry.FullName.Substring('ReaWebAPI/'.Length)
        $target = [IO.Path]::GetFullPath((Join-Path $licenseDirectory $relative))
        if (-not $target.StartsWith($licenseDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid license path.' }
        [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
    }
    foreach ($required in @('COPYING', 'COPYING.LESSER', 'LICENSE.md', 'THIRD_PARTY.md')) {
        if (-not (Test-Path -LiteralPath (Join-Path $licenseDirectory $required))) { throw "Missing license material: $required" }
    }
    Copy-Item -LiteralPath $sourceArchive -Destination (Join-Path $sourceDirectory $lock.source.file) -Force
    Copy-Item -LiteralPath $LockPath -Destination (Join-Path $Destination 'runtime-lock.json') -Force
}
finally { $zip.Dispose() }
Write-Host "Bundled ReaWebAPI $($lock.version), SHA-256 verified, with licenses and matching source archive."
