$ErrorActionPreference = 'Stop'
$tool = Join-Path $PSScriptRoot 'Sync-ReaWebAPIFork.ps1'
$global:PsyReaSFXSyncTest = @{
    Behind = $false; Pending = $false; Diverged = $false; Mismatch = $false
    Advanced = 0; Dispatched = 0
}
function Invoke-RestMethod($Uri, $Headers) {
    $f = $global:PsyReaSFXSyncTest
    if ($Uri -match '/commits/main$') {
        return @{ sha = $(if ($f.Behind -and $Uri -cmatch '/Psysia/') { 'b' * 40 } else { 'a' * 40 }) }
    }
    if ($Uri -match '/compare/') {
        if ($Uri -cnotlike ("*/compare/" + ('b' * 40) + "...zaibuyidao:" + ('a' * 40))) {
            throw 'Unexpected ref comparison.'
        }
        return @{
            status = $(if ($f.Diverged) { 'diverged' } else { 'ahead' })
            behind_by = [int]$f.Diverged
            merge_base_commit = @{ sha = 'b' * 40 }
        }
    }
    if ($Uri -match '/commits/v0.3.9.32$') { return @{ sha = 'c' * 40 } }
    if ($Uri -match '/releases/') {
        $assets = @('ReaWebAPI-windows-x64-v0.3.9.32.zip', 'reaper_reawebapi-x64.dll', 'mirror-manifest.json', 'ReaWebAPI-source.zip') | ForEach-Object {
            @{ name = $_; digest = 'sha256:' + $(if ($f.Mismatch -and $Uri -cmatch '/Psysia/') { 'd' * 64 } else { 'e' * 64 }) }
        }
        return @{ tag_name = 'v0.3.9.32'; draft = $f.Pending -and $Uri -cmatch '/Psysia/'; assets = $assets }
    }
    throw "Unexpected test endpoint: $Uri"
}
function gh {
    $f = $global:PsyReaSFXSyncTest
    $global:LASTEXITCODE = 0
    if ($args[0] -ceq 'api') {
        if ('GET' -cin $args) {
            $endpoint = $args[3]
            return (Invoke-RestMethod ('https://api.github.com/' + $endpoint) $null | ConvertTo-Json -Depth 5 -Compress)
        }
        if ('repos/Psysia/ReaWebAPI/git/refs/heads/main' -cnotin $args -or 'force=false' -cnotin $args -or
            ('sha=' + ('a' * 40)) -cnotin $args) { throw 'Expected a non-forced update to the checked source only.' }
        $f.Advanced++
        $f.Behind = $false
        return ('a' * 40)
    }
    if ($args[0] -ceq 'workflow') {
        if ('publish_only=true' -cnotin $args -or 'tag=v0.3.9.32' -cnotin $args) { throw 'Unexpected mirror request.' }
        $f.Dispatched++
        $f.Pending = $false
        return
    }
    throw 'Unexpected GitHub CLI call.'
}
function Start-Sleep { }
try {
    $f = $global:PsyReaSFXSyncTest
    if ((& $tool -WaitSeconds 0) -cne 'v0.3.9.32' -or $f.Advanced -ne 0 -or $f.Dispatched -ne 0) {
        throw 'Current mirror must avoid writes.'
    }
    $f.Behind = $true
    $f.Pending = $true
    $failed = $false
    try { & $tool -ReadOnly -WaitSeconds 0 } catch { if ($_.Exception.Message -notlike '*No older runtime*') { throw }; $failed = $true }
    if (-not $failed -or $f.Advanced -ne 0 -or $f.Dispatched -ne 0) { throw 'Read-only mode attempted to write or used stale source.' }
    if ((& $tool -WaitSeconds 1) -cne 'v0.3.9.32' -or $f.Advanced -ne 1 -or $f.Dispatched -ne 1) {
        throw 'Local preflight must fast-forward and request the tag when both are behind.'
    }
    $f.Pending = $true
    if ((& $tool -WaitSeconds 1) -cne 'v0.3.9.32' -or $f.Advanced -ne 1 -or $f.Dispatched -ne 2) {
        throw 'When source is current the preflight should request only the tag.'
    }
    $f.Behind = $true
    $f.Diverged = $true
    $failed = $false
    try { & $tool -WaitSeconds 0 } catch { if ($_.Exception.Message -notlike '*has diverged*') { throw }; $failed = $true }
    if (-not $failed -or $f.Advanced -ne 1 -or $f.Dispatched -ne 2) { throw 'The preflight must reject a divergent fork.' }
    $f.Mismatch = $true
    $failed = $false
    try { & $tool -WaitSeconds 0 } catch { if ($_.Exception.Message -notlike '*differs from upstream*') { throw }; $failed = $true }
    if (-not $failed) { throw 'Mismatched mirror assets must be rejected.' }
    Write-Host 'Runtime preflight verified offline for an up-to-date mirror, a fast-forward, deferral, divergence and asset mismatch.'
}
finally { Remove-Variable -Name PsyReaSFXSyncTest -Scope Global }
