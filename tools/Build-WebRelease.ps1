param(
    [ValidateSet('reaper', 'desktop')][string]$Target = 'reaper',
    [string]$OutputPath = '',
    [string]$Version = '',
    [string]$DependencyLockPath = (Join-Path $PSScriptRoot '../dependencies/reawebapi/windows-x64.lock.json'),
    [string]$ArchivePath = ''
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $Version) {
    $Version = (Get-Content -LiteralPath (Join-Path $repoRoot 'src/web/app.json') -Raw -Encoding UTF8 | ConvertFrom-Json).version
}
if ($Version -notmatch '^[0-9A-Za-z.\-]+$') { throw 'Invalid release version.' }
if (-not $OutputPath) { $OutputPath = Join-Path $repoRoot "dist/webview/$Target-package" }
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $OutputPath) {
    if (Get-ChildItem -LiteralPath $OutputPath -Force | Select-Object -First 1) {
        throw "Build output must be empty. Choose a fresh -OutputPath: $OutputPath"
    }
}
$webPath = Join-Path $OutputPath 'web'
[IO.Directory]::CreateDirectory($webPath) | Out-Null
Copy-Item -Path (Join-Path $repoRoot 'src/web/*') -Destination $webPath -Recurse -Force
$appManifestPath = Join-Path $webPath 'app.json'
$appManifest = Get-Content -LiteralPath $appManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$appManifest.version = $Version
[IO.File]::WriteAllText($appManifestPath, ($appManifest | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
Copy-Item -LiteralPath (Join-Path $repoRoot 'LICENSE') -Destination (Join-Path $OutputPath 'LICENSE')
if ($Target -eq 'reaper') {
    & (Join-Path $PSScriptRoot 'Build-LuaRelease.ps1') -Ui webview -Version $Version -OutputPath (Join-Path $OutputPath 'PsyReaSFX_Runtime.lua')
    & (Join-Path $PSScriptRoot 'Build-WebLauncher.ps1') -Version $Version -OutputPath (Join-Path $OutputPath 'PsyReaSFX.lua')
    & (Join-Path $PSScriptRoot 'Get-ReaWebAPIRuntime.ps1') -LockPath $DependencyLockPath -Destination $OutputPath
    Copy-Item -Path (Join-Path $repoRoot 'packaging/webview/*') -Destination $OutputPath -Force
}
$assetDirectories = if ($Target -eq 'reaper') { @('ucs', 'brand', 'neural') } else { @('brand') }
foreach ($directory in $assetDirectories) {
    $destination = Join-Path $OutputPath "assets/$directory"
    [IO.Directory]::CreateDirectory($destination) | Out-Null
    Copy-Item -Path (Join-Path $repoRoot "assets/$directory/*") -Destination $destination -Recurse -Force
}
if ($Target -eq 'reaper') {
    $documentation = Join-Path $OutputPath 'docs'
    [IO.Directory]::CreateDirectory($documentation) | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/WEBVIEW_ACCEPTANCE_0_9_3_zh-CN.md') -Destination $documentation
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/WEBVIEW_CORE_AUDIT_0_9_3_BETA10_zh-CN.md') -Destination $documentation
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/WEBVIEW_PERFORMANCE_BETA14_zh-CN.md') -Destination $documentation
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/WEBVIEW_UNDOCK_BETA15_zh-CN.md') -Destination $documentation
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/WEBVIEW_HARDENING_BETA18_zh-CN.md') -Destination $documentation
    $prefix = $OutputPath.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $files = @(Get-ChildItem -LiteralPath $OutputPath -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{
            path = $_.FullName.Substring($prefix.Length).Replace('\', '/')
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    })
    $manifest = [ordered]@{
        schema = 'PsyReaSFX-WebView-Package-v1'; id = [guid]::NewGuid().ToString('N')
        version = $Version; files = $files
    }
    [IO.File]::WriteAllText((Join-Path $OutputPath 'package-manifest.json'), ($manifest | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
    if (-not $ArchivePath) { $ArchivePath = Join-Path (Split-Path -Parent $OutputPath) "PsyReaSFX_WebView_${Version}_win_x64.zip" }
    $ArchivePath = [IO.Path]::GetFullPath($ArchivePath)
    if ($ArchivePath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Release archive must be outside its payload folder.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Directory]::CreateDirectory((Split-Path -Parent $ArchivePath)) | Out-Null
    [IO.Compression.ZipFile]::CreateFromDirectory($OutputPath, $ArchivePath)
    Write-Host "Offline installer archive: $ArchivePath"
}
Write-Host "Web frontend target $Target built at $OutputPath"
if ($Target -eq 'desktop') { Write-Host 'Desktop frontend assets require a host implementing the shared RPC contract.' }
