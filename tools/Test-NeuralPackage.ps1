param(
    [Parameter(Mandatory = $true)]
    [string]$ArchivePath,
    [string]$FixtureDirectory = ""
)

$ErrorActionPreference = "Stop"
$archive = (Resolve-Path -LiteralPath $ArchivePath).Path
if ([string]::IsNullOrWhiteSpace($FixtureDirectory)) {
    $FixtureDirectory = Join-Path ([IO.Path]::GetTempPath()) ("PsyReaSFX-neural-package-" + [guid]::NewGuid().ToString("N"))
}
$fixture = [IO.Path]::GetFullPath($FixtureDirectory)
$extract = Join-Path $fixture "extract"
$resource = Join-Path $fixture "reaper-resource"
New-Item -ItemType Directory -Path $extract, $resource -Force | Out-Null

Expand-Archive -LiteralPath $archive -DestinationPath $extract
$package = Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1
if ($null -eq $package) { throw "Package root was not found." }
$installer = Join-Path $package.FullName "Install-NeuralSimilarity.ps1"
$uninstaller = Join-Path $package.FullName "Uninstall-NeuralSimilarity.ps1"

& $installer -ReaperResourcePath $resource
$target = Join-Path $resource "Scripts/PsyReaSFX/neural_similarity"
$sidecar = Join-Path $target "PsyReaSFX.NeuralSidecar.exe"
$model = Join-Path $target "models/mn04_as_scene_320_v1"
if (-not (Test-Path -LiteralPath $sidecar -PathType Leaf)) { throw "Installed sidecar is missing." }
if (-not (Test-Path -LiteralPath (Join-Path $model "manifest-v1.json") -PathType Leaf)) { throw "Installed model is missing." }
& $sidecar capabilities $model | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Installed sidecar capability test failed: $LASTEXITCODE" }

$cache = Join-Path $target "embeddings-mn04_as_scene_320_v1-v2.bin"
[IO.File]::WriteAllText($cache, "package-test-cache")
& $uninstaller -ReaperResourcePath $resource
if (Test-Path -LiteralPath $sidecar) { throw "Uninstaller did not remove the sidecar." }
if (-not (Test-Path -LiteralPath $cache -PathType Leaf)) { throw "Default uninstall did not preserve the cache." }

& $uninstaller -ReaperResourcePath $resource -RemoveCache
if (Test-Path -LiteralPath $target) { throw "Full uninstall did not remove the neural directory." }

Write-Host "Neural package install/uninstall smoke test passed."
