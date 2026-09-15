[CmdletBinding()]
param(
    [string]$ReaperResourcePath = "",
    [switch]$RemoveCache
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ReaperResourcePath)) {
    if ([string]::IsNullOrWhiteSpace($env:APPDATA)) {
        throw "REAPER resource path was not supplied and APPDATA is unavailable."
    }
    $ReaperResourcePath = Join-Path $env:APPDATA "REAPER"
}

$resourcePath = [IO.Path]::GetFullPath($ReaperResourcePath)
$targetPath = [IO.Path]::GetFullPath((Join-Path $resourcePath "Scripts/PsyReaSFX/neural_similarity"))
$expectedSuffix = [IO.Path]::Combine("Scripts", "PsyReaSFX", "neural_similarity")
if (-not $targetPath.EndsWith($expectedSuffix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove an unexpected directory: $targetPath"
}
if (-not (Test-Path -LiteralPath $targetPath -PathType Container)) {
    Write-Host "PsyReaSFX Neural Similarity is not installed at $targetPath"
    exit 0
}

if ($RemoveCache) {
    Remove-Item -LiteralPath $targetPath -Recurse -Force
    Write-Host "Removed the neural component and its rebuildable embedding/index cache."
    exit 0
}

$managedPaths = @(
    (Join-Path $targetPath "PsyReaSFX.NeuralSidecar.exe"),
    (Join-Path $targetPath "models/mn04_as_scene_320_v1"),
    (Join-Path $targetPath "capabilities-v1.json")
)
foreach ($path in $managedPaths) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}

Write-Host "Removed the neural executable and model."
Write-Host "The rebuildable embedding/index cache remains at: $targetPath"
Write-Host "Run again with -RemoveCache to remove that cache too."
