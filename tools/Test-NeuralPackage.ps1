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
$manifestPath = Join-Path $package.FullName 'package-manifest.json'
if (Test-Path -LiteralPath $manifestPath) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.schema -cne 'PsyReaSFX-Neural-Package-v1' -or @($manifest.files).Count -lt 10) { throw 'Invalid neural package manifest.' }
    $targets = @{}
    foreach ($entry in $manifest.files) {
        $relative = [string]$entry.path
        if ([IO.Path]::IsPathRooted($relative) -or $relative.Contains(':') -or $relative -match '(^|[\\/])\.\.([\\/]|$)' -or
            $targets.ContainsKey($relative)) { throw 'Unsafe or duplicate neural manifest path.' }
        $targets[$relative] = $true
        $file = Join-Path $package.FullName $relative
        if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or
            (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -cne $entry.sha256) {
            throw "Neural payload hash mismatch: $relative"
        }
    }
}
$installer = Join-Path $package.FullName "Install-NeuralSimilarity.ps1"
$uninstaller = Join-Path $package.FullName "Uninstall-NeuralSimilarity.ps1"

& $installer -ReaperResourcePath $resource
$target = Join-Path $resource "Scripts/PsyReaSFX/neural_similarity"
$sidecar = Join-Path $target "PsyReaSFX.NeuralSidecar.exe"
$model = Join-Path $target "models/mn04_as_scene_320_v1"
if (-not (Test-Path -LiteralPath $sidecar -PathType Leaf)) { throw "Installed sidecar is missing." }
if (-not (Test-Path -LiteralPath (Join-Path $model "manifest-v1.json") -PathType Leaf)) { throw "Installed model is missing." }
$capabilities = (& $sidecar capabilities $model | Out-String) | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "Installed sidecar capability test failed: $LASTEXITCODE" }
if ((Test-Path -LiteralPath $manifestPath) -and $capabilities.sidecarVersion -cne $manifest.sidecarVersion) {
    throw 'Installed neural executable version differs from the package manifest.'
}

$cache = Join-Path $target "embeddings-mn04_as_scene_320_v1-v2.bin"
[IO.File]::WriteAllText($cache, "package-test-cache")
& $uninstaller -ReaperResourcePath $resource
if (Test-Path -LiteralPath $sidecar) { throw "Uninstaller did not remove the sidecar." }
if (-not (Test-Path -LiteralPath $cache -PathType Leaf)) { throw "Default uninstall did not preserve the cache." }

& $uninstaller -ReaperResourcePath $resource -RemoveCache
if (Test-Path -LiteralPath $target) { throw "Full uninstall did not remove the neural directory." }

Write-Host "Neural package install/uninstall smoke test passed."
