param(
    [Parameter(Mandatory = $true)][string]$ArchivePath,
    [string]$ReferenceLuaPath = "PsyReaSFX_v0_7_23_Stable.lua"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Get-BytesHash([byte[]]$bytes) {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hasher.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant() }
    finally { $hasher.Dispose() }
}
function Read-EntryBytes($entry) {
    $stream = $entry.Open()
    $buffer = [IO.MemoryStream]::new()
    try { $stream.CopyTo($buffer); return ,$buffer.ToArray() }
    finally { $stream.Dispose(); $buffer.Dispose() }
}
$reference = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $ReferenceLuaPath)).Replace("`r`n", "`n").Replace("`r", "`n")
$fingerprint = [regex]::Match($reference, 'source_sha256 = "([a-f0-9]{64})"').Groups[1].Value
$normalized = $reference.Replace('source_sha256 = "' + $fingerprint + '"', 'source_sha256 = "development"')
if ($fingerprint.Length -ne 64 -or (Get-BytesHash ([Text.Encoding]::UTF8.GetBytes($normalized))) -cne $fingerprint) {
    throw "Reference Lua source fingerprint is missing or invalid."
}
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ArchivePath))
try {
    $entries = @($zip.Entries | Where-Object { $_.FullName.EndsWith('/RELEASE-PROVENANCE.json') })
    if ($entries.Count -ne 1) { throw "Expected one provenance manifest." }
    $entry = $entries[0]
    $manifest = [Text.Encoding]::UTF8.GetString((Read-EntryBytes $entry)) | ConvertFrom-Json
    if ($manifest.schema -cne 'PsyReaSFX-Release-Provenance-v1' -or
        $manifest.project -cne 'Psysia/PsyReaSFX' -or $manifest.source_sha256 -cne $fingerprint) {
        throw "Archive provenance does not match reference source."
    }
    $version = [regex]::Match($reference, '(?m)^-- @version\s+(\S+)').Groups[1].Value
    if ($manifest.release_id -cne "PsyReaSFX/$version" -or
        $manifest.official_release -cne "https://github.com/Psysia/PsyReaSFX/releases/tag/v$version") {
        throw "Archive release identity mismatch."
    }
    $prefix = $entry.FullName.Substring(0, $entry.FullName.Length - 'RELEASE-PROVENANCE.json'.Length)
    $payloads = @($manifest.payload_sha256.PSObject.Properties)
    if ($payloads.Count -lt 2) { throw "Incomplete payload fingerprints." }
    foreach ($payload in $payloads) {
        if ($payload.Name.Contains('..') -or $payload.Name.StartsWith('/')) { throw "Unsafe payload path." }
        $payloadEntry = $zip.GetEntry($prefix + $payload.Name)
        if ($null -eq $payloadEntry -or (Get-BytesHash (Read-EntryBytes $payloadEntry)) -cne $payload.Value) {
            throw "Payload checksum mismatch: $($payload.Name)"
        }
        if ($payload.Name.EndsWith('.lua')) {
            $lua = [Text.Encoding]::UTF8.GetString((Read-EntryBytes $payloadEntry)).Replace("`r`n", "`n").Replace("`r", "`n")
            if ($lua -cne $reference) { throw "Packaged Lua differs from reference." }
        }
    }
    Write-Host "Release provenance verified against reference: $($manifest.release_id), $($payloads.Count) payloads."
} finally { $zip.Dispose() }
