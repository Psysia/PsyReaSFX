param(
    [string]$Version = "",
    [string]$OutputPath = "",
    [ValidateSet('imgui', 'webview')][string]$Ui = 'imgui'
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
    "11_ui_workspace.lua",
    "12_state_store.lua",
    "13_workspace_tabs.lua",
    "15_host_adapter.lua",
    "20_jobs_storage.lua",
    "25_ucs_catalog.lua",
    "30_catalog.lua",
    "35_incremental_results.lua",
    "36_asset_journal.lua",
    "37_catalog_caches.lua",
    "38_incremental_persistence.lua",
    "40_analysis.lua",
    "42_similarity.lua",
    "43_neural_similarity.lua",
    "44_ai_semantic_search.lua",
    "45_duplicate_confirmation.lua",
    "46_product_navigation.lua",
    "50_runtime_ui.lua"
)
if ($Ui -eq 'webview') {
    $modules = $modules[0..($modules.Count - 2)] + '48_webview.lua' + $modules[-1]
}
# Every module after the bootstrap is emitted inside its own `do ... end` block.
# Lua allows at most 200 active local variables per function, and one shared
# chunk used to pay for every module's top-level locals at once. A block frees
# them when the module ends, so a module may use locals freely as long as no
# later module refers to them; tools/check_lua_module_scopes.cjs enforces that
# (anything shared must be a global). The bootstrap stays outside any block
# because it holds the shared constants and the `@version` header, which must
# remain the first lines of the file.
$parts = for ($index = 0; $index -lt $modules.Count; $index++) {
    $module = $modules[$index]
    $path = Join-Path $sourceRoot $module
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing Lua module: $path" }
    $text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n").Replace("`r", "`n")
    if ($index -eq 0) { $text } else { "do`n" + $text + "`nend" }
}
$release = [string]::Join("`n", $parts)
if ($Ui -eq 'webview') {
    $release = $release.Replace('local WEBVIEW_MODE = false', 'local WEBVIEW_MODE = true')
}

$matches = [regex]::Matches($release, '(?m)^-- @version\s+[^\r\n]+$')
if ($matches.Count -ne 1) { throw "Expected exactly one Lua @version header; found $($matches.Count)." }
if (-not [string]::IsNullOrWhiteSpace($Version)) {
    if ($Version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') {
        throw "Invalid release version: $Version"
    }
    $release = [regex]::Replace($release, '(?m)^-- @version\s+[^\r\n]+$', "-- @version $Version", 1)
}

$releaseVersion = [regex]::Match($release, '(?m)^-- @version\s+(\S+)').Groups[1].Value
$release = [regex]::Replace($release, 'release_id = "PsyReaSFX/[^"\r\n]+"',
    'release_id = "PsyReaSFX/' + $releaseVersion + '"')

# The name shown in the title bar, About page and splash must follow @version.
# It used to be a hand-edited literal that went stale for two releases.
$displayVersion = if ($releaseVersion -match '-beta') { $releaseVersion -replace '-beta', ' Beta ' } else { "$releaseVersion Stable" }
$displayPattern = '(?m)^local VERSION = "[^"\r\n]*"'
if ([regex]::Matches($release, $displayPattern).Count -ne 1) {
    throw "Expected exactly one displayed-version literal."
}
$release = [regex]::Replace($release, $displayPattern, 'local VERSION = "' + $displayVersion + '"')
$provenancePattern = 'source_sha256 = "development"'
if ([regex]::Matches($release, $provenancePattern).Count -ne 1) {
    throw "Expected exactly one release provenance template."
}
# Hash the normalized assembled source before replacing its fingerprint placeholder.
# No timestamp, workstation path, user identifier or Git checkout state enters the digest.
$sourceHasher = [Security.Cryptography.SHA256]::Create()
try {
    $sourceDigest = [BitConverter]::ToString(
        $sourceHasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($release))
    ).Replace('-', '').ToLowerInvariant()
} finally { $sourceHasher.Dispose() }
$release = $release.Replace($provenancePattern, 'source_sha256 = "' + $sourceDigest + '"')

$parent = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($parent)) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
$temporary = "$OutputPath.tmp"
$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText($temporary, $release, $utf8)
Move-Item -LiteralPath $temporary -Destination $OutputPath -Force
Write-Host "Built Lua release: $OutputPath"
