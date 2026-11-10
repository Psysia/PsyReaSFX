[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PackagePath,
    [string]$IndexPath = 'index.xml',
    [string]$FixtureDirectory = '',
    [switch]$Online
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$PackagePath = [IO.Path]::GetFullPath($PackagePath)
if (-not $FixtureDirectory) { $FixtureDirectory = Join-Path $env:TEMP "psfx-index-$([guid]::NewGuid().ToString('N').Substring(0,8))" }
$FixtureDirectory = [IO.Path]::GetFullPath($FixtureDirectory)
if (Test-Path -LiteralPath $FixtureDirectory) { throw 'Use a new ReaPack fixture directory.' }
[IO.Directory]::CreateDirectory($FixtureDirectory) | Out-Null
[xml]$index = Get-Content -LiteralPath (Join-Path $repoRoot $IndexPath) -Raw -Encoding UTF8
$app = Get-Content -LiteralPath (Join-Path $repoRoot 'src/web/app.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$lock = Get-Content -LiteralPath (Join-Path $repoRoot 'dependencies/reawebapi/windows-x64.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$rawPrefix = "https://raw.githubusercontent.com/Psysia/PsyReaSFX/v$($app.version)/"
$packages = @($index.index.category.reapack)
$script = $packages | Where-Object { $_.name -eq 'PsyReaSFX.lua' }
$runtime = $packages | Where-Object { $_.name -eq 'PsyReaSFX WebView Runtime.ext' }
$webVersion = @($script.version | Where-Object { $_.name -ceq $app.version })
$runtimeVersion = @($runtime.version | Where-Object { $_.name -ceq ($lock.version + '-beta1') })
if ($webVersion.Count -ne 1 -or $runtimeVersion.Count -ne 1 -or $runtime.type -cne 'extension') { throw 'Missing WebView beta or runtime extension package.' }
$binarySource = @($runtimeVersion[0].source | Where-Object { $_.type -ceq 'extension' -and $_.file -ceq 'reaper_reawebapi-x64.dll' })
if ($binarySource.Count -ne 1 -or $binarySource[0].InnerText -cnotmatch '^https://github\.com/Psysia/PsyReaSFX/releases/download/(v\d+\.\d+\.\d+-beta\d+(?:\.\d+)?)/reaper_reawebapi-x64\.dll$') {
    throw 'Runtime binary must use a pinned project beta release.'
}
$runtimeTag = $Matches[1]
$assetPrefix = "https://github.com/Psysia/PsyReaSFX/releases/download/$runtimeTag/"
$runtimeRawPrefix = "https://raw.githubusercontent.com/Psysia/PsyReaSFX/$runtimeTag/"
if ($app.version -notmatch '-beta' -or $runtimeVersion[0].name -notmatch '-beta') { throw 'Experimental WebView packages must be pre-releases.' }
if (-not ($script.version | Where-Object { $_.name -ceq '0.9.2-beta4' }) -or -not ($script.version | Where-Object { $_.name -ceq '0.9.1' })) { throw 'Legacy rollback versions are missing.' }

function Resolve-Payload([string]$Url) {
    foreach ($prefix in @($rawPrefix, $runtimeRawPrefix)) {
        if ($Url.StartsWith($prefix, [StringComparison]::Ordinal)) {
            $relative = $Url.Substring($prefix.Length)
            if ($relative -match '(^|/)\.\.(/|$)' -or $relative.Contains(':')) { throw 'Unsafe repository source path.' }
            return Join-Path $repoRoot $relative
        }
    }
    if ($Url -ceq ($assetPrefix + 'reaper_reawebapi-x64.dll')) { return Join-Path $PackagePath 'runtime/reawebapi/reaper_reawebapi-x64.dll' }
    if ($Url -ceq ($assetPrefix + 'ReaWebAPI-source.zip')) { return Join-Path $PackagePath 'sources/ReaWebAPI-source.zip' }
    throw "Unpinned ReaPack URL: $Url"
}

function Payload-Hash([string]$Path) {
    if ([IO.Path]::GetExtension($Path) -in @('.lua','.js','.ts','.css','.html','.json','.md','.txt','.tsv','.h','.hpp') -or [IO.Path]::GetExtension($Path) -eq '') {
        $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n")
        $hash = [Security.Cryptography.SHA256]::Create()
        try { return [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))) }
        finally { $hash.Dispose() }
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

$installed = @{}
foreach ($item in @(
    @{ Package = $script; Version = $webVersion[0] },
    @{ Package = $runtime; Version = $runtimeVersion[0] }
)) {
    foreach ($source in $item.Version.source) {
        if ($source.platform -cne 'win64') { throw 'Every WebView beta payload must declare its Windows x64 platform.' }
        $type = if ($source.type) { [string]$source.type } else { [string]$item.Package.type }
        $folder = switch ($type) { 'script' { 'Scripts/Psysia' } 'extension' { 'UserPlugins' } 'data' { 'Data' } default { throw "Unexpected source type: $type" } }
        $relative = [string]$source.file
        if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)' -or $relative.Contains(':')) { throw 'Unsafe ReaPack target.' }
        $target = [IO.Path]::GetFullPath((Join-Path $FixtureDirectory "$folder/$relative"))
        if (-not $target.StartsWith($FixtureDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or $installed.ContainsKey($target)) { throw 'Duplicate or escaping ReaPack target.' }
        $origin = Resolve-Payload ([string]$source.InnerText)
        if (-not (Test-Path -LiteralPath $origin -PathType Leaf)) { throw "Missing release source: $origin" }
        [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
        if ($Online) { Invoke-WebRequest -Uri $source.InnerText -OutFile $target -UseBasicParsing }
        else { Copy-Item -LiteralPath $origin -Destination $target }
        if ((Payload-Hash $origin) -cne (Payload-Hash $target)) { throw "Downloaded payload differs: $relative" }
        $installed[$target] = $true
    }
}
$main = Join-Path $FixtureDirectory 'Scripts/Psysia/PsyReaSFX.lua'
$generated = Join-Path $PackagePath 'PsyReaSFX.lua'
if ((Payload-Hash $main) -cne (Payload-Hash $generated)) { throw 'ReaPack main script differs from the assembled WebView release.' }
$text = Get-Content -LiteralPath $main -Raw -Encoding UTF8
if ($text -notmatch 'local WEBVIEW_MODE = true' -or $text -notmatch ('(?m)^-- @version ' + [regex]::Escape($app.version) + '\r?$')) { throw 'ReaPack entry is not the expected WebView beta.' }
foreach ($required in @('web/index.html','web/app.json','web/host.js','web/app.js','web/settings.js','web/icons.js','web/styles.css','runtime-lock.json','assets/brand/psyreasfx-icon.png','assets/ucs/ucs-8.2.1.tsv')) {
    if (-not (Test-Path -LiteralPath (Join-Path $FixtureDirectory "Scripts/Psysia/$required"))) { throw "Missing script asset: $required" }
}
if ((Get-FileHash -LiteralPath (Join-Path $FixtureDirectory 'UserPlugins/reaper_reawebapi-x64.dll')).Hash.ToLowerInvariant() -cne $lock.binary.sha256) { throw 'Native extension checksum mismatch.' }
if ((Get-FileHash -LiteralPath (Join-Path $FixtureDirectory 'Data/PsyReaSFX-WebView/ReaWebAPI/sources/ReaWebAPI-source.zip')).Hash.ToLowerInvariant() -cne $lock.source.sha256) { throw 'Matching source archive checksum mismatch.' }
Write-Host "ReaPack WebView verified: $($app.version), $($installed.Count) pinned payloads, native extension and source/license materials, rollback entries retained. Online=$Online"
