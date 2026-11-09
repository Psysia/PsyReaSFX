[CmdletBinding()]
param(
    [string]$ReaperResourcePath = '',
    [switch]$ChooseResourcePath,
    [switch]$UseBundledRuntime,
    [switch]$AllowUnverifiedRuntime,
    [switch]$PlanOnly
)
. (Join-Path $PSScriptRoot 'installer-common.ps1')
$manifest = Read-Package $PSScriptRoot
$resource = Get-ResourcePath $ReaperResourcePath -Choose:$ChooseResourcePath
$app = Get-ChildPath $resource 'Scripts/PsyReaSFX-WebView'
$plugin = Get-ChildPath $resource 'UserPlugins/reaper_reawebapi-x64.dll'
$bundled = Join-Path $PSScriptRoot 'runtime/reawebapi/reaper_reawebapi-x64.dll'
$bundledHash = Get-SHA256 $bundled
$runtimePolicy = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'runtime-lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json).runtime_policy
if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -and $env:PROCESSOR_ARCHITEW6432 -ne 'AMD64') { throw 'This package requires Windows x64.' }
if ([IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\') -ieq $app) { throw 'Extract the release package outside the installed app before reinstalling.' }
$id = [guid]::NewGuid().ToString('N')
$transaction = Get-ChildPath $resource "Data/PsyReaSFX-WebView/transactions/$id"
$stage = Get-ChildPath $resource "Scripts/.psfx-$id"
foreach ($file in $manifest.files) {
    foreach ($directory in @($stage, (Join-Path $transaction 'previous-app'))) {
        if ((Get-ChildPath $directory $file.path).Length -gt 245) {
            throw 'Resource folder is too deep for Windows PowerShell 5.1 file operations. Use a shorter REAPER resource path.'
        }
    }
}
$installedHash = if (Test-Path -LiteralPath $plugin) { Get-SHA256 $plugin } else { '' }
$action = if (-not $installedHash) { 'install' } elseif ($installedHash -eq $bundledHash) { 'reuse' } elseif ($UseBundledRuntime) { 'replace' } else { 'preserve-external' }
if ($PlanOnly) {
    return [pscustomobject]@{ Resource = $resource; Application = $app; Runtime = $action; Version = $manifest.version; RuntimeValidation = $runtimePolicy.validation_status }
}
Assert-RuntimePolicy $action $runtimePolicy -AllowUnverified:$AllowUnverifiedRuntime
Assert-ReaperClosed
$guard = Open-InstallerLock $resource
try {
    $transactions = Get-ChildPath $resource 'Data/PsyReaSFX-WebView/transactions'
    [IO.Directory]::CreateDirectory($transactions) | Out-Null
    foreach ($file in Get-ChildItem -LiteralPath $transactions -Filter receipt.json -File -Recurse) {
        $pending = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($pending.status -eq 'installing') { Restore-Transaction $resource $pending.id }
    }
    $installedHash = if (Test-Path -LiteralPath $plugin) { Get-SHA256 $plugin } else { '' }
    $action = if (-not $installedHash) { 'install' } elseif ($installedHash -eq $bundledHash) { 'reuse' } elseif ($UseBundledRuntime) { 'replace' } else { 'preserve-external' }
    Assert-RuntimePolicy $action $runtimePolicy -AllowUnverified:$AllowUnverifiedRuntime
    [IO.Directory]::CreateDirectory($transaction) | Out-Null
    [IO.Directory]::CreateDirectory($stage) | Out-Null
    foreach ($file in $manifest.files) {
        $target = Get-ChildPath $stage $file.path
        [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
        Copy-Item -LiteralPath (Get-ChildPath $PSScriptRoot $file.path) -Destination $target
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'package-manifest.json') -Destination $stage
    [IO.File]::WriteAllText((Join-Path $stage '.install-transaction'), $id)
    Read-Package $stage | Out-Null
    if ($action -eq 'replace') {
        $backup = Join-Path $transaction 'previous-runtime.dll'
        Copy-Item -LiteralPath $plugin -Destination $backup
        if ((Get-SHA256 $backup) -cne $installedHash) { throw 'Shared runtime changed while preparing its backup. Retry after the other updater finishes.' }
    }
    $receipt = [pscustomobject]@{
        schema = 'PsyReaSFX-WebView-Install-v1'; id = $id; packageId = $manifest.id
        status = 'installing'; created = [DateTime]::UtcNow.ToString('o'); appExisted = (Test-Path -LiteralPath $app)
        runtimeAction = $action; previousRuntimeHash = $installedHash; installedRuntimeHash = $bundledHash
    }
    $receiptPath = Join-Path $transaction 'receipt.json'
    Write-Receipt $receiptPath $receipt
    try {
        if ($receipt.appExisted) {
            $previousApp = Get-ChildPath $resource "Data/PsyReaSFX-WebView/transactions/$id/previous-app"
            [IO.Directory]::Move($app, $previousApp)
        }
        [IO.Directory]::Move($stage, $app)
        if ($action -in @('install', 'replace')) {
            [IO.Directory]::CreateDirectory((Split-Path -Parent $plugin)) | Out-Null
            $stagedPlugin = Get-ChildPath $resource "UserPlugins/.PsyReaSFX-install-$id.dll"
            Copy-Item -LiteralPath $bundled -Destination $stagedPlugin
            $currentHash = if (Test-Path -LiteralPath $plugin) { Get-SHA256 $plugin } else { '' }
            if ($currentHash -cne $installedHash) { throw 'Shared runtime changed during installation. Its external update has been preserved.' }
            if ($action -eq 'replace') { [IO.File]::Replace($stagedPlugin, $plugin, [NullString]::Value) }
            else { [IO.File]::Move($stagedPlugin, $plugin) }
        }
        $receipt.status = 'installed'
        Write-Receipt $receiptPath $receipt
    }
    catch {
        $failure = $_
        try { Restore-Transaction $resource $id }
        catch { throw "Install failed ($failure). Recovery needs attention: $_" }
        throw $failure
    }
    Write-Host "Installed PsyReaSFX $($manifest.version). Runtime action: $action."
    Write-Host "REAPER Actions > Load ReaScript: $(Join-Path $app 'PsyReaSFX.lua')"
    if ($action -eq 'preserve-external') { Write-Host 'Existing runtime preserved. Its compatibility will be checked when the app starts.' }
    Write-Host "Rollback transaction: $id"
}
finally { $guard.Dispose() }
