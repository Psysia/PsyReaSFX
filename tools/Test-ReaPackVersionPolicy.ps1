param([string]$IndexPath = "index.xml")

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
[xml]$document = [IO.File]::ReadAllText((Join-Path $repoRoot $IndexPath))
$bootstrap = [IO.File]::ReadAllText((Join-Path $repoRoot "src/lua/00_bootstrap.lua"))
$match = [regex]::Match($bootstrap, '(?m)^-- @version (\S+)')
if (-not $match.Success) { throw "Missing current Lua version" }
$currentVersion = $match.Groups[1].Value
if ($currentVersion -notmatch '^0\.9\.\d+(?:-beta\d+(?:\.\d+)?)?$') {
    throw "Unexpected current version: $currentVersion"
}

# The version shown in the title bar and About page is a literal in the source.
# The release build rewrites it from @version, but the source must agree too so
# unbuilt runs and the tracked script never show a stale number.
$expectedDisplay = if ($currentVersion -match '-beta') { $currentVersion -replace '-beta', ' Beta ' } else { "$currentVersion Stable" }
$displayMatch = [regex]::Match($bootstrap, '(?m)^local VERSION = "([^"\r\n]*)"')
if (-not $displayMatch.Success -or $displayMatch.Groups[1].Value -cne $expectedDisplay) {
    throw "Displayed version '$($displayMatch.Groups[1].Value)' must be '$expectedDisplay' to match @version $currentVersion."
}

# The optional neural component is versioned independently: script-only
# releases (e.g. 0.9.1) keep the 0.9.0 component, whose protocol is unchanged.
$neuralVersion = "0.9.0"
$webVersion = (Get-Content -LiteralPath (Join-Path $repoRoot 'src/web/app.json') -Raw -Encoding UTF8 | ConvertFrom-Json).version
if ($webVersion -notmatch '^0\.9\.\d+-beta\d+(?:\.\d+)?$') { throw "Unexpected WebView beta version: $webVersion" }
# The legacy renderer remains available while the independently versioned WebView beta is evaluated.
$mainVersions = @($webVersion, '0.9.3-beta6', $currentVersion)
$runtimeVersion = (Get-Content -LiteralPath (Join-Path $repoRoot 'dependencies/reawebapi/windows-x64.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json).version + '-beta1'
foreach ($archived in @("0.9.1", "0.9.0", "0.8.5", "0.7.23")) {
    if ($mainVersions -notcontains $archived) { $mainVersions += $archived }
}

$packages = @($document.index.category.reapack)
foreach ($policy in @(
    @{ Name = "PsyReaSFX.lua"; Versions = $mainVersions },
    @{ Name = "PsyReaSFX Neural Similarity"; Versions = @($neuralVersion) }
    @{ Name = "PsyReaSFX WebView Runtime.ext"; Versions = @($runtimeVersion) }
)) {
    $package = @($packages | Where-Object { $_.name -eq $policy.Name })
    if ($package.Count -ne 1) { throw "Expected one package: $($policy.Name)" }
    $actual = @($package[0].version | ForEach-Object { [string]$_.name })
    if (($actual -join ',') -cne ($policy.Versions -join ',')) {
        throw "Version list for $($policy.Name) must be $($policy.Versions -join ', '); got $($actual -join ', ')"
    }
    foreach ($version in @($package[0].version)) {
        if (@($version.source).Count -eq 0) { throw "Version has no download sources: $($version.name)" }
    }
}
Write-Host "ReaPack version policy passed: $($mainVersions -join ' + '); optional neural package $neuralVersion only."
