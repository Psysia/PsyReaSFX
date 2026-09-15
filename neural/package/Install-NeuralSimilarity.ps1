[CmdletBinding()]
param(
    [string]$ReaperResourcePath = ""
)

$ErrorActionPreference = "Stop"

function Resolve-ReaperResourcePath {
    param([string]$RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        return [IO.Path]::GetFullPath($RequestedPath)
    }
    if ([string]::IsNullOrWhiteSpace($env:APPDATA)) {
        throw "REAPER resource path was not supplied and APPDATA is unavailable."
    }
    return [IO.Path]::GetFullPath((Join-Path $env:APPDATA "REAPER"))
}

$resourcePath = Resolve-ReaperResourcePath $ReaperResourcePath
if (-not (Test-Path -LiteralPath $resourcePath -PathType Container)) {
    throw "REAPER resource directory was not found: $resourcePath"
}

$payloadPath = Join-Path $PSScriptRoot "payload"
$sidecarSource = Join-Path $payloadPath "PsyReaSFX.NeuralSidecar.exe"
$modelSource = Join-Path $payloadPath "models/mn04_as_scene_320_v1"
if (-not (Test-Path -LiteralPath $sidecarSource -PathType Leaf)) {
    throw "The neural sidecar payload is incomplete."
}
if (-not (Test-Path -LiteralPath (Join-Path $modelSource "manifest-v1.json") -PathType Leaf)) {
    throw "The neural model payload is incomplete."
}

$dataPath = Join-Path $resourcePath "Scripts/PsyReaSFX"
$targetPath = Join-Path $dataPath "neural_similarity"
$targetModelPath = Join-Path $targetPath "models/mn04_as_scene_320_v1"
$stagingPath = Join-Path $dataPath (".neural_similarity.install." + [guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Path $stagingPath -Force | Out-Null
try {
    Copy-Item -LiteralPath $sidecarSource -Destination $stagingPath
    New-Item -ItemType Directory -Path (Join-Path $stagingPath "models") -Force | Out-Null
    Copy-Item -LiteralPath $modelSource -Destination (Join-Path $stagingPath "models") -Recurse

    $stagedSidecar = Join-Path $stagingPath "PsyReaSFX.NeuralSidecar.exe"
    $stagedModel = Join-Path $stagingPath "models/mn04_as_scene_320_v1"
    & $stagedSidecar self-test $stagedModel | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Neural component self-test failed with exit code $LASTEXITCODE."
    }

    New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $targetModelPath) -Force | Out-Null
    Copy-Item -LiteralPath $stagedSidecar -Destination (Join-Path $targetPath "PsyReaSFX.NeuralSidecar.exe") -Force
    Copy-Item -LiteralPath $stagedModel -Destination (Split-Path -Parent $targetModelPath) -Recurse -Force
}
finally {
    if (Test-Path -LiteralPath $stagingPath) {
        Remove-Item -LiteralPath $stagingPath -Recurse -Force
    }
}

Write-Host "PsyReaSFX Neural Similarity installed successfully."
Write-Host "Target: $targetPath"
Write-Host "Restart PsyReaSFX in REAPER to enable the optional neural path."
