[CmdletBinding()]
param([string]$OutputDirectory = '')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
[xml]$project = Get-Content -LiteralPath (Join-Path $repoRoot 'desktop/PsyReaSFX.Desktop/PsyReaSFX.Desktop.csproj') -Raw
$version = [string]$project.Project.PropertyGroup.Version
if ($version -notmatch '^0\.7\.23-desktop-alpha\.8-light-rc\.(\d+)$') { throw 'Unexpected Desktop package version.' }
$revision = $Matches[1]
$releaseTag = "desktop-v0.7.23-alpha8-light-rc$revision"
$packageName = "PsyReaSFX_Desktop_v0_7_23_Alpha_8_Light_RC$revision"
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repoRoot 'dist/desktop-current' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$archive = Join-Path $OutputDirectory "$packageName.zip"
if (Test-Path -LiteralPath $archive) { throw 'Choose a fresh Desktop archive output.' }
$workRoot = Join-Path ([IO.Path]::GetTempPath()) ('PsyReaSFX-desktop-build-' + [guid]::NewGuid().ToString('N'))
$packageRoot = Join-Path $workRoot $packageName
try {
    dotnet publish (Join-Path $repoRoot 'desktop/PsyReaSFX.Desktop/PsyReaSFX.Desktop.csproj') `
        -c Release -r win-x64 --self-contained false -o $packageRoot
    if ($LASTEXITCODE -ne 0) { throw "Desktop publish failed: $LASTEXITCODE" }
    foreach ($file in @('README.md', 'THIRD_PARTY_NOTICES.md', 'FEATURE_PARITY_0_7_23.md',
        'FEATURE_PARITY_0_7_23_zh-CN.md', 'ALPHA8_REAPER_BRIDGE_AUDIT.md', 'PsyReaSFX_REAPER_Bridge.lua')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot "desktop/$file") -Destination $packageRoot
    }
    Copy-Item -LiteralPath (Join-Path $repoRoot 'LICENSE') -Destination (Join-Path $packageRoot 'LICENSE-PsyReaSFX.txt')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'neural/package/LICENSE-NAudio.txt') -Destination $packageRoot
    Copy-Item -LiteralPath (Join-Path $repoRoot 'desktop/licenses') -Destination $packageRoot -Recurse
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/WEBVIEW_HARDENING_BETA18_zh-CN.md') -Destination $packageRoot
    $report = Join-Path $packageRoot 'self-test.json'
    $exe = Join-Path $packageRoot 'PsyReaSFX.Desktop.exe'
    $process = Start-Process -FilePath $exe -ArgumentList '--self-test', ('"' + $report + '"') -PassThru -WindowStyle Hidden
    try {
        if (-not $process.WaitForExit(60000)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw 'Packaged Desktop self-test timed out.'
        }
        if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $report) -or
            -not (Get-Content -LiteralPath $report -Raw | ConvertFrom-Json).passed) {
            throw "Packaged Desktop self-test failed: $($process.ExitCode)"
        }
    }
    finally { $process.Dispose() }
    $prefix = $packageRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $files = @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path = $_.FullName.Substring($prefix.Length).Replace('\', '/');
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
    $manifest = [ordered]@{ schema = 'PsyReaSFX-Desktop-Package-v1'; version = $version;
        releaseTag = $releaseTag; runtime = '.NET 8 Desktop Runtime / Windows x64'; files = $files }
    [IO.File]::WriteAllText((Join-Path $packageRoot 'package-manifest.json'), ($manifest | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    Compress-Archive -LiteralPath $packageRoot -DestinationPath $archive -CompressionLevel Optimal
    $checksum = "{0}  {1}" -f (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant(), [IO.Path]::GetFileName($archive)
    [IO.File]::WriteAllText((Join-Path $OutputDirectory "SHA256SUMS-$releaseTag.txt"), $checksum + "`n", [Text.UTF8Encoding]::new($false))
    Write-Host "Desktop $version built and self-tested: $archive"
}
finally {
    if (Test-Path -LiteralPath $workRoot) {
        $resolved = [IO.Path]::GetFullPath($workRoot)
        $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        if (-not $resolved.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or
            [IO.Path]::GetFileName($resolved) -notmatch '^PsyReaSFX-desktop-build-[a-f0-9]{32}$') { throw 'Unexpected Desktop build directory.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
