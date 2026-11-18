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
$audition = Get-ChildPath $resource 'UserPlugins/reaper_prs_audition.dll'
$auditionFile = Join-Path $PSScriptRoot 'runtime/audition/reaper_prs_audition.dll'
$auditionHash = Get-SHA256 $auditionFile
$runtimeLock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'runtime-lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$runtimePolicy = $runtimeLock.runtime_policy
$bundledPolicy = Read-BundledRuntimePolicy $PSScriptRoot $runtimeLock
$allowPackaged = $AllowUnverifiedRuntime -or $null -ne $bundledPolicy
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
$action = Get-RuntimeAction $installedHash $bundledHash $bundledPolicy -Replace:$UseBundledRuntime
if ($PlanOnly) {
    return [pscustomobject]@{ Resource = $resource; Application = $app; Runtime = $action; Audition = (Get-AuditionAction $audition $auditionHash); Version = $manifest.version; RuntimeValidation = $runtimePolicy.validation_status; RuntimeDistribution = $runtimePolicy.distribution_channel }
}
Assert-RuntimePolicy $action $runtimePolicy -BinarySha256 $bundledHash -AllowUnverified:$allowPackaged
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
    $action = Get-RuntimeAction $installedHash $bundledHash $bundledPolicy -Replace:$UseBundledRuntime
    $auditionAction = Get-AuditionAction $audition $auditionHash
    Assert-RuntimePolicy $action $runtimePolicy -BinarySha256 $bundledHash -AllowUnverified:$allowPackaged
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
        auditionAction = $auditionAction; auditionHash = $auditionHash
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
        if ($auditionAction -eq 'install') {
            [IO.Directory]::CreateDirectory((Split-Path -Parent $audition)) | Out-Null
            $stagedAudition = Join-Path $transaction 'audition-stage.dll'
            Copy-Item -LiteralPath $auditionFile -Destination $stagedAudition
            if ((Get-SHA256 $stagedAudition) -cne $auditionHash) { throw (Get-AuditionMessage 'The copied PRS audition component failed verification. Extract the package again.' '复制的 PRS 试听组件未通过校验。请重新解压安装包。') }
            [IO.File]::Move($stagedAudition, $audition)
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
