param(
    [string]$Version = "",
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $repoRoot "src/lua"
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot "dist/PsyReaSFX.lua"
}

$modules = @(
    "00_bootstrap.lua",
    "10_ui_core.lua",
    "20_jobs_storage.lua",
    "30_catalog.lua",
    "35_incremental_results.lua",
    "36_asset_journal.lua",
    "37_catalog_caches.lua",
    "38_incremental_persistence.lua",
    "40_analysis.lua",
    "45_duplicate_confirmation.lua",
    "50_runtime_ui.lua"
)
$parts = foreach ($module in $modules) {
    $path = Join-Path $sourceRoot $module
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing Lua module: $path" }
    [IO.File]::ReadAllText($path).Replace("`r`n", "`n").Replace("`r", "`n")
}
$release = [string]::Join("`n", $parts)

$matches = [regex]::Matches($release, '(?m)^-- @version\s+[^\r\n]+$')
if ($matches.Count -ne 1) { throw "Expected exactly one Lua @version header; found $($matches.Count)." }
if (-not [string]::IsNullOrWhiteSpace($Version)) {
    if ($Version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') {
        throw "Invalid release version: $Version"
    }
    $release = [regex]::Replace($release, '(?m)^-- @version\s+[^\r\n]+$', "-- @version $Version", 1)
}

$parent = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($parent)) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
$temporary = "$OutputPath.tmp"
$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText($temporary, $release, $utf8)
Move-Item -LiteralPath $temporary -Destination $OutputPath -Force
Write-Host "Built Lua release: $OutputPath"
