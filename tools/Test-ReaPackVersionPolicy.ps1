param([string]$IndexPath = "index.xml")

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
[xml]$document = [IO.File]::ReadAllText((Join-Path $repoRoot $IndexPath))
$bootstrap = [IO.File]::ReadAllText((Join-Path $repoRoot "src/lua/00_bootstrap.lua"))
$match = [regex]::Match($bootstrap, '(?m)^-- @version (\S+)')
if (-not $match.Success) { throw "Missing current Lua version" }
$latestBeta = $match.Groups[1].Value
if ($latestBeta -notmatch '^0\.9\.0-beta\d+(?:\.\d+)?$') {
    throw "Unexpected beta version: $latestBeta"
}

$packages = @($document.index.category.reapack)
foreach ($policy in @(
    @{ Name = "PsyReaSFX.lua"; Versions = @($latestBeta, "0.8.5", "0.7.23") },
    @{ Name = "PsyReaSFX Neural Similarity"; Versions = @($latestBeta) }
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
Write-Host "ReaPack version policy passed: latest Beta + 0.8.5 + 0.7.23; optional neural package latest Beta only."
