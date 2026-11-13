[CmdletBinding()]
param([string]$OutputDirectory = '')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$metadataPath = Join-Path $repoRoot 'neural/package/package.json'
$metadata = Get-Content -LiteralPath $metadataPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($metadata.version -notmatch '^\d+\.\d+\.\d+(?:-beta\d+(?:\.\d+)?)?$' -or
    $metadata.releaseTag -notmatch '^v\d+\.\d+\.\d+(?:-beta\d+(?:\.\d+)?)?$') {
    throw 'Invalid neural package version or release tag.'
}
[xml]$project = Get-Content -LiteralPath (Join-Path $repoRoot 'neural/PsyReaSFX.NeuralSidecar/PsyReaSFX.NeuralSidecar.csproj') -Raw
$program = Get-Content -LiteralPath (Join-Path $repoRoot 'neural/PsyReaSFX.NeuralSidecar/Program.cs') -Raw
if ($project.Project.PropertyGroup.Version -cne $metadata.sidecarVersion -or
    $program -notmatch ('SidecarVersion = "' + [regex]::Escape($metadata.sidecarVersion) + '"')) {
    throw 'Neural package, assembly and protocol versions must agree.'
}
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repoRoot 'dist/neural-current' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$fileVersion = $metadata.version.Replace('.', '_').Replace('-', '_')
$packageName = "PsyReaSFX_Neural_Similarity_v${fileVersion}_win_x64"
$archive = Join-Path $OutputDirectory "$packageName.zip"
$sidecarAsset = Join-Path $OutputDirectory "PsyReaSFX.NeuralSidecar_v${fileVersion}_win_x64.exe"
if ((Test-Path -LiteralPath $archive) -or (Test-Path -LiteralPath $sidecarAsset)) {
    throw 'Choose fresh neural package outputs; published payloads are never overwritten.'
}
$workRoot = Join-Path ([IO.Path]::GetTempPath()) ('PsyReaSFX-neural-build-' + [guid]::NewGuid().ToString('N'))
$packageRoot = Join-Path $workRoot $packageName
$publishRoot = Join-Path $workRoot 'publish'
[IO.Directory]::CreateDirectory($packageRoot) | Out-Null
try {
    dotnet publish (Join-Path $repoRoot 'neural/PsyReaSFX.NeuralSidecar/PsyReaSFX.NeuralSidecar.csproj') `
        -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true `
        -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -o $publishRoot
    if ($LASTEXITCODE -ne 0) { throw "Neural package publish failed: $LASTEXITCODE" }
    foreach ($file in @('Install-NeuralSimilarity.cmd', 'Install-NeuralSimilarity.ps1',
        'Uninstall-NeuralSimilarity.cmd', 'Uninstall-NeuralSimilarity.ps1',
        'LICENSE-NAudio.txt', 'README.md', 'README_zh-CN.md', 'package.json')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot "neural/package/$file") -Destination $packageRoot
    }
    Copy-Item -LiteralPath (Join-Path $repoRoot 'LICENSE') -Destination (Join-Path $packageRoot 'LICENSE-PsyReaSFX.txt')
    $nugetRoot = if ($env:NUGET_PACKAGES) { $env:NUGET_PACKAGES } else { Join-Path $env:USERPROFILE '.nuget/packages' }
    Copy-Item -LiteralPath (Join-Path $nugetRoot 'microsoft.ml.onnxruntime/1.30.0/LICENSE') -Destination (Join-Path $packageRoot 'LICENSE-ONNXRuntime.txt')
    Copy-Item -LiteralPath (Join-Path $nugetRoot 'microsoft.ml.onnxruntime/1.30.0/ThirdPartyNotices.txt') -Destination (Join-Path $packageRoot 'ThirdPartyNotices-ONNXRuntime.txt')
    $payload = Join-Path $packageRoot 'payload'
    [IO.Directory]::CreateDirectory((Join-Path $payload 'models')) | Out-Null
    $sidecar = Join-Path $payload 'PsyReaSFX.NeuralSidecar.exe'
    Copy-Item -LiteralPath (Join-Path $publishRoot 'PsyReaSFX.NeuralSidecar.exe') -Destination $sidecar
    Copy-Item -LiteralPath (Join-Path $repoRoot 'assets/neural/mn04_as_scene_320_v1') -Destination (Join-Path $payload 'models') -Recurse
    & $sidecar self-test (Join-Path $payload 'models/mn04_as_scene_320_v1') | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Packaged neural model regression failed: $LASTEXITCODE" }
    $capabilities = (& $sidecar capabilities (Join-Path $payload 'models/mn04_as_scene_320_v1') | Out-String) | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $capabilities.sidecarVersion -cne $metadata.sidecarVersion) {
        throw 'The packaged executable reports an unexpected sidecar version.'
    }
    $prefix = $packageRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $files = @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path = $_.FullName.Substring($prefix.Length).Replace('\', '/');
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
    $manifest = [ordered]@{ schema = 'PsyReaSFX-Neural-Package-v1'; version = $metadata.version;
        sidecarVersion = $metadata.sidecarVersion; releaseTag = $metadata.releaseTag;
        officialRelease = "https://github.com/Psysia/PsyReaSFX/releases/tag/$($metadata.releaseTag)"; files = $files }
    [IO.File]::WriteAllText((Join-Path $packageRoot 'package-manifest.json'), ($manifest | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    Compress-Archive -LiteralPath $packageRoot -DestinationPath $archive -CompressionLevel Optimal
    Copy-Item -LiteralPath $sidecar -Destination $sidecarAsset
    $checksums = @($archive, $sidecarAsset) | ForEach-Object {
        "{0}  {1}" -f (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant(), [IO.Path]::GetFileName($_)
    }
    [IO.File]::WriteAllLines((Join-Path $OutputDirectory "SHA256SUMS-neural-$($metadata.version).txt"), $checksums, [Text.UTF8Encoding]::new($false))
    Write-Host "Neural package $($metadata.version), sidecar $($metadata.sidecarVersion): $archive"
}
finally {
    $resolved = [IO.Path]::GetFullPath($workRoot)
    $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolved) -notmatch '^PsyReaSFX-neural-build-[a-f0-9]{32}$') { throw 'Unexpected neural build directory.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
