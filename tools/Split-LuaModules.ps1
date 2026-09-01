param(
    [string]$InputPath = "",
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($InputPath)) {
    $InputPath = Join-Path $repoRoot "PsyReaSFX_v0_7_23_Stable.lua"
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot "src/lua"
}

$source = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $InputPath))
$source = $source.Replace("`r`n", "`n").Replace("`r", "`n")
$boundaries = @(
    @{ File = "00_bootstrap.lua"; Marker = "" },
    @{ File = "10_ui_core.lua"; Marker = "function translate_ui_text(value)" },
    @{ File = "20_jobs_storage.lua"; Marker = "function Jobs.begin(" },
    @{ File = "30_catalog.lua"; Marker = "function parse_ucs_filename(filename)" },
    @{ File = "40_analysis.lua"; Marker = "function asset_regions(asset)" },
    @{ File = "50_runtime_ui.lua"; Marker = "function load_database()" }
)

$positions = @(0)
for ($index = 1; $index -lt $boundaries.Count; $index++) {
    $marker = $boundaries[$index].Marker
    $position = $source.IndexOf($marker, [StringComparison]::Ordinal)
    if ($position -lt 0) { throw "Lua module marker was not found: $marker" }
    if ($source.IndexOf($marker, $position + $marker.Length, [StringComparison]::Ordinal) -ge 0) {
        throw "Lua module marker is not unique: $marker"
    }
    $positions += $position
}
$positions += $source.Length

[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
for ($index = 0; $index -lt $boundaries.Count; $index++) {
    $length = $positions[$index + 1] - $positions[$index]
    $content = $source.Substring($positions[$index], $length).TrimEnd("`n") + "`n"
    [IO.File]::WriteAllText((Join-Path $OutputDirectory $boundaries[$index].File), $content, $utf8)
}

Write-Host "Split Lua source into $($boundaries.Count) deterministic modules."
