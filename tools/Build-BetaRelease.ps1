param(
    [string]$Version = "0.9.0-beta7.4",
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot "dist"
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if ($Version -notmatch '^\d+\.\d+\.\d+-beta\d+(?:\.\d+)?$') {
    throw "Invalid beta version: $Version"
}

$displayVersion = $Version -replace '-beta', ' Beta '
$fileVersion = $Version.Replace('.', '_').Replace('-', '_')
$luaPackageName = "PsyReaSFX_v$fileVersion"
$neuralPackageName = "PsyReaSFX_Neural_Similarity_v${fileVersion}_win_x64"
$sidecarAssetName = "PsyReaSFX.NeuralSidecar_v${fileVersion}_win_x64.exe"
$workRoot = Join-Path ([IO.Path]::GetTempPath()) ("PsyReaSFX-release-" + [guid]::NewGuid().ToString("N"))
$luaRoot = Join-Path $workRoot $luaPackageName
$neuralRoot = Join-Path $workRoot $neuralPackageName

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $luaRoot -Force | Out-Null
New-Item -ItemType Directory -Path $neuralRoot -Force | Out-Null

try {
    & (Join-Path $PSScriptRoot "Build-LuaRelease.ps1") `
        -Version $Version `
        -OutputPath (Join-Path $luaRoot "$luaPackageName.lua")

    foreach ($file in @("LICENSE", "README.md", "README_zh-CN.md")) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $file) -Destination $luaRoot
    }
    foreach ($directory in @("assets/brand", "assets/fonts", "assets/screenshots", "assets/ucs")) {
        $destination = Join-Path $luaRoot $directory
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repoRoot $directory) -Destination $destination -Recurse
    }
    $docsDestination = Join-Path $luaRoot "docs"
    New-Item -ItemType Directory -Path $docsDestination -Force | Out-Null
    foreach ($document in @(
        "CHANGELOG_en-US.md",
        "CHANGELOG_zh-CN.md",
        "AI_SEMANTIC_SEARCH_ARCHITECTURE_0_9_zh-CN.md",
        "HARDENING_TECHNICAL_ARCHIVE_0_8_BETA4_zh-CN.md",
        "NEURAL_SIMILARITY_ARCHITECTURE_0_9_zh-CN.md",
        "ROADMAP_0_9_TO_1_0_zh-CN.md",
        "SIMILARITY_ARCHITECTURE_0_9_zh-CN.md",
        "SPECTRAL_ANALYSIS_ARCHITECTURE_0_9_zh-CN.md",
        "UCS_CLASSIFICATION_ARCHITECTURE_0_9_zh-CN.md",
        "USER_GUIDE_en-US.md",
        "USER_GUIDE_zh-CN.md"
    )) {
        Copy-Item -LiteralPath (Join-Path $repoRoot "docs/$document") -Destination $docsDestination
    }

    $publishDirectory = Join-Path $workRoot "sidecar-publish"
    dotnet publish (Join-Path $repoRoot "neural/PsyReaSFX.NeuralSidecar/PsyReaSFX.NeuralSidecar.csproj") `
        -c Release -r win-x64 --self-contained true `
        -p:PublishSingleFile=true `
        -p:IncludeNativeLibrariesForSelfExtract=true `
        -p:EnableCompressionInSingleFile=true `
        -o $publishDirectory
    if ($LASTEXITCODE -ne 0) { throw "Neural sidecar publish failed: $LASTEXITCODE" }

    foreach ($file in @(
        "Install-NeuralSimilarity.cmd",
        "Install-NeuralSimilarity.ps1",
        "Uninstall-NeuralSimilarity.cmd",
        "Uninstall-NeuralSimilarity.ps1",
        "LICENSE-NAudio.txt",
        "README.md",
        "README_zh-CN.md"
    )) {
        Copy-Item -LiteralPath (Join-Path $repoRoot "neural/package/$file") -Destination $neuralRoot
    }
    Copy-Item -LiteralPath (Join-Path $repoRoot "LICENSE") -Destination (Join-Path $neuralRoot "LICENSE-PsyReaSFX.txt")
    $payloadDirectory = Join-Path $neuralRoot "payload"
    New-Item -ItemType Directory -Path (Join-Path $payloadDirectory "models") -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $publishDirectory "PsyReaSFX.NeuralSidecar.exe") -Destination $payloadDirectory
    $sidecarAsset = Join-Path $OutputDirectory $sidecarAssetName
    Copy-Item -LiteralPath (Join-Path $publishDirectory "PsyReaSFX.NeuralSidecar.exe") -Destination $sidecarAsset -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot "assets/neural/mn04_as_scene_320_v1") `
        -Destination (Join-Path $payloadDirectory "models") -Recurse

    $nugetRoot = if (-not [string]::IsNullOrWhiteSpace($env:NUGET_PACKAGES)) {
        $env:NUGET_PACKAGES
    } else {
        Join-Path $env:USERPROFILE ".nuget/packages"
    }
    $onnxPackage = Join-Path $nugetRoot "microsoft.ml.onnxruntime/1.30.0"
    Copy-Item -LiteralPath (Join-Path $onnxPackage "LICENSE") -Destination (Join-Path $neuralRoot "LICENSE-ONNXRuntime.txt")
    Copy-Item -LiteralPath (Join-Path $onnxPackage "ThirdPartyNotices.txt") -Destination (Join-Path $neuralRoot "ThirdPartyNotices-ONNXRuntime.txt")

    & (Join-Path $payloadDirectory "PsyReaSFX.NeuralSidecar.exe") self-test `
        (Join-Path $payloadDirectory "models/mn04_as_scene_320_v1") | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Packaged neural sidecar self-test failed: $LASTEXITCODE" }

    $luaZip = Join-Path $OutputDirectory "$luaPackageName.zip"
    $neuralZip = Join-Path $OutputDirectory "$neuralPackageName.zip"
    foreach ($archive in @($luaZip, $neuralZip)) {
        if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
    }
    Compress-Archive -LiteralPath $luaRoot -DestinationPath $luaZip -CompressionLevel Optimal
    Compress-Archive -LiteralPath $neuralRoot -DestinationPath $neuralZip -CompressionLevel Optimal

    $checksumPath = Join-Path $OutputDirectory "SHA256SUMS-$Version.txt"
    $checksumLines = foreach ($archive in @($luaZip, $neuralZip, $sidecarAsset)) {
        $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $([IO.Path]::GetFileName($archive))"
    }
    [IO.File]::WriteAllLines($checksumPath, $checksumLines, [Text.UTF8Encoding]::new($false))

    Write-Host "Built $displayVersion release assets:"
    Get-Item -LiteralPath $luaZip, $neuralZip, $sidecarAsset, $checksumPath | Select-Object Name, Length
}
finally {
    if (Test-Path -LiteralPath $workRoot) {
        for ($attempt = 1; $attempt -le 8; $attempt++) {
            try {
                Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction Stop
                break
            }
            catch {
                if ($attempt -eq 8) { throw }
                Start-Sleep -Milliseconds 250
            }
        }
    }
}
