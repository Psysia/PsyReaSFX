$ErrorActionPreference = 'Stop'
$tool = Join-Path $PSScriptRoot 'Sync-ReaWebAPIFork.ps1'
$global:PsyReaSFXSyncTest = @{ Behind = $false; Mismatch = $false; Dispatched = 0 }
function Invoke-RestMethod($Uri, $Headers) {
    $f = $global:PsyReaSFXSyncTest
    if ($Uri -match '/commits/main$') { return @{ sha = $(if ($f.Behind -and $Uri -cmatch '/Psysia/') { 'b' * 40 } else { 'a' * 40 }) } }
    if ($Uri -match '/commits/v0.3.9.32$') { return @{ sha = 'c' * 40 } }
    if ($Uri -match '/releases/') {
        $assets = @('ReaWebAPI-windows-x64-v0.3.9.32.zip', 'reaper_reawebapi-x64.dll', 'mirror-manifest.json', 'ReaWebAPI-source.zip') | ForEach-Object {
            @{ name = $_; digest = 'sha256:' + $(if ($f.Mismatch -and $Uri -cmatch '/Psysia/') { 'd' * 64 } else { 'e' * 64 }) }
        }
        return @{ tag_name = 'v0.3.9.32'; draft = $false; assets = $assets }
    }
    throw "Unexpected test endpoint: $Uri"
}
function gh { $global:PsyReaSFXSyncTest.Dispatched++; $global:PsyReaSFXSyncTest.Behind = $false; $global:LASTEXITCODE = 0 }
function Start-Sleep { }
try {
    if ((& $tool -WaitSeconds 0) -cne 'v0.3.9.32' -or $global:PsyReaSFXSyncTest.Dispatched -ne 0) { throw 'Current mirror must avoid needless dispatch.' }
    $global:PsyReaSFXSyncTest.Behind = $true
    $failed = $false
    try { & $tool -ReadOnly -WaitSeconds 0 } catch { if ($_.Exception.Message -notlike '*No older runtime*') { throw }; $failed = $true }
    if (-not $failed -or $global:PsyReaSFXSyncTest.Dispatched -ne 0) { throw 'Read-only CI must not dispatch or silently use stale source.' }
    if ((& $tool -WaitSeconds 1) -cne 'v0.3.9.32' -or $global:PsyReaSFXSyncTest.Dispatched -ne 1) { throw 'Local development must request sync when behind.' }
    $global:PsyReaSFXSyncTest.Mismatch = $true
    $failed = $false
    try { & $tool -WaitSeconds 0 } catch { if ($_.Exception.Message -notlike '*differs from upstream*') { throw }; $failed = $true }
    if (-not $failed) { throw 'Mismatched mirror assets must be rejected.' }
    Write-Host 'Sync verified offline: current mirror, immediate dispatch, read-only timeout and upstream hash mismatch.'
}
finally { Remove-Variable -Name PsyReaSFXSyncTest -Scope Global }
