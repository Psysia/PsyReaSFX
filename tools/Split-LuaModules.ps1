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
    @{ File = "12_state_store.lua"; Marker = "-- Controlled mutation boundary for new modules." },
    @{ File = "15_host_adapter.lua"; Marker = "-- Injectable boundary for REAPER, SWS and ReaImGui host APIs." },
    @{ File = "20_jobs_storage.lua"; Marker = "-- Background jobs, atomic storage, recovery and cache maintenance." },
    @{ File = "30_catalog.lua"; Marker = "-- Catalog identity, metadata, configuration and library persistence." },
    @{ File = "35_incremental_results.lua"; Marker = "-- Incremental result construction keeps large catalogs out of a single UI" },
    @{ File = "36_asset_journal.lua"; Marker = "-- Generation-bound asset journal codec. Decoding validates the complete" },
    @{ File = "37_catalog_caches.lua"; Marker = "-- Sparse activity indexes and frame-budgeted aggregate caches for large" },
    @{ File = "38_incremental_persistence.lua"; Marker = "-- Frame-budgeted serializers for large auxiliary catalogs." },
    @{ File = "40_analysis.lua"; Marker = "-- Region, loudness, channel and transient analysis services." },
    @{ File = "45_duplicate_confirmation.lua"; Marker = "local DUPLICATE_COMPARE_CHUNK_SIZE = 256 * 1024" },
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
