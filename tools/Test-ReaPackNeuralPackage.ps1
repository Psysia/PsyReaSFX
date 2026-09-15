param(
    [string]$IndexPath = "index.xml",
    [string]$Version = "0.9.0-beta6.1",
    [Parameter(Mandatory = $true)]
    [string]$SidecarPath,
    [string]$FixtureDirectory = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$index = [IO.Path]::GetFullPath((Join-Path (Get-Location) $IndexPath))
$sidecar = (Resolve-Path -LiteralPath $SidecarPath).Path
if ([string]::IsNullOrWhiteSpace($FixtureDirectory)) {
    $FixtureDirectory = Join-Path ([IO.Path]::GetTempPath()) ("PsyReaSFX-reapack-neural-" + [guid]::NewGuid().ToString("N"))
}
$fixture = [IO.Path]::GetFullPath($FixtureDirectory)
$dataRoot = Join-Path $fixture "Data"

[xml]$document = [IO.File]::ReadAllText($index)
$package = @($document.index.category.reapack) | Where-Object {
    $_.name -eq "PsyReaSFX Neural Similarity"
}
if ($package.Count -ne 1) { throw "Expected one PsyReaSFX Neural Similarity package." }
if ($package.type -ne "data") { throw "Neural ReaPack package must use type=data." }
$release = @($package.version) | Where-Object { $_.name -eq $Version }
if ($release.Count -ne 1) { throw "Expected one neural ReaPack version $Version." }
$sources = @($release.source)
if ($sources.Count -lt 10) { throw "Neural ReaPack package is incomplete." }

$targets = @{}

function Resolve-SourceFile([string]$url) {
    if ($url -match '/releases/download/[^/]+/PsyReaSFX\.NeuralSidecar_.*_win_x64\.exe$') {
        return $sidecar
    }
    if ($url -match '/PsyReaSFX/[^/]+/(.+)$') {
        return Join-Path $repoRoot ($Matches[1] -replace '/', [IO.Path]::DirectorySeparatorChar)
    }
    if ($url -eq 'https://raw.githubusercontent.com/microsoft/onnxruntime/v1.30.0/LICENSE') {
        $download = Join-Path $fixture "source-onnxruntime-license.txt"
        Invoke-WebRequest -UseBasicParsing $url -OutFile $download
        return $download
    }
    if ($url -eq 'https://raw.githubusercontent.com/microsoft/onnxruntime/v1.30.0/ThirdPartyNotices.txt') {
        $download = Join-Path $fixture "source-onnxruntime-notices.txt"
        Invoke-WebRequest -UseBasicParsing $url -OutFile $download
        return $download
    }
    throw "Unsupported ReaPack source URL: $url"
}

try {
    New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null
    foreach ($source in $sources) {
        $target = [string]$source.file
        $url = ([string]$source.InnerText).Trim()
        $hash = [string]$source.hash
        if ([string]$source.platform -ne "win64") { throw "Source is not restricted to win64: $target" }
        if (-not $target.StartsWith("PsyReaSFX/neural_similarity/")) { throw "Unsafe data target: $target" }
        if ($target.Contains("..") -or $targets.ContainsKey($target)) { throw "Duplicate or unsafe data target: $target" }
        if ($hash -notmatch '^1220[0-9a-f]{64}$') { throw "Invalid ReaPack SHA-256 multihash: $target" }
        $targets[$target] = $true

        $local = Resolve-SourceFile $url
        if (-not (Test-Path -LiteralPath $local -PathType Leaf)) { throw "Missing local source for $target`: $local" }
        $actual = "1220" + (Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -cne $hash) { throw "Hash mismatch for $target`: expected $hash, got $actual" }

        $destination = Join-Path $dataRoot ($target -replace '/', [IO.Path]::DirectorySeparatorChar)
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $local -Destination $destination
    }

    $installedRoot = Join-Path $dataRoot "PsyReaSFX/neural_similarity"
    $installedSidecar = Join-Path $installedRoot "PsyReaSFX.NeuralSidecar.exe"
    $installedModel = Join-Path $installedRoot "models/mn04_as_scene_320_v1"
    & $installedSidecar capabilities $installedModel | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "ReaPack-layout sidecar capability test failed: $LASTEXITCODE" }
    Write-Host "ReaPack neural data package validation passed: $($sources.Count) files."
}
finally {
    if (Test-Path -LiteralPath $fixture) {
        Remove-Item -LiteralPath $fixture -Recurse -Force
    }
}
