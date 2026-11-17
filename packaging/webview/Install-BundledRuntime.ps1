[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ReaperResourcePath,
    [ValidatePattern('^[a-f0-9]{32}$')][string]$RequestId = '',
    [ValidateSet('auto', 'zh', 'en')][string]$Language = 'auto',
    [switch]$WaitForReaperExit,
    [switch]$Notify,
    [switch]$PlanOnly
)
. (Join-Path $PSScriptRoot 'installer-common.ps1')
if ($Language -eq 'auto') {
    $Language = if ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'zh') { 'zh' } else { 'en' }
}
function Get-SetupText([string]$Chinese, [string]$English) {
    if ($Language -eq 'zh') { return $Chinese }
    return $English
}
$setupTitle = Get-SetupText 'PsyReaSFX · 随包组件' 'PsyReaSFX · Bundled component'
$resource = Get-ResourcePath $ReaperResourcePath
$statusPath = if ($RequestId) { Get-ChildPath $resource "Data/PsyReaSFX-WebView/runtime-setup-$RequestId.txt" } else { '' }
function Publish-SetupStatus([string]$State, [string]$Message) {
    if ($statusPath) {
        [IO.Directory]::CreateDirectory((Split-Path -Parent $statusPath)) | Out-Null
        $temporaryStatus = "$statusPath.tmp"
        [IO.File]::WriteAllText($temporaryStatus, "$State`n$Message", (New-Object Text.UTF8Encoding($false)))
        for ($attempt = 0; ; $attempt++) {
            try {
                if (Test-Path -LiteralPath $statusPath) { [IO.File]::Replace($temporaryStatus, $statusPath, [NullString]::Value) }
                else { [IO.File]::Move($temporaryStatus, $statusPath) }
                break
            } catch [IO.IOException] {
                if ($attempt -ge 9) { throw }
                # The Lua poller closes its short-lived status read immediately.
                Start-Sleep -Milliseconds 20
            }
        }
    }
}
$guard = $null
try {
    $runtime = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'runtime-lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $policy = Read-BundledRuntimePolicy $PSScriptRoot $runtime
    if (-not $policy) { throw (Get-SetupText '随包组件的校验清单缺失或与本版程序不符。请重新安装完整 PRS 包。' 'Bundled runtime approval is missing or does not match this application. Reinstall the complete PRS package.') }
    $bundled = Join-Path $PSScriptRoot 'runtime/reawebapi/reaper_reawebapi-x64.dll'
    $source = Join-Path $PSScriptRoot 'sources/ReaWebAPI-source.zip'
    if ((Get-SHA256 $bundled) -cne $policy.binary_sha256 -or (Get-SHA256 $source) -cne $policy.source_sha256) {
        throw (Get-SetupText '随包组件或对应源码校验失败。请重新安装 PRS。' 'Bundled runtime or corresponding source failed checksum verification. Reinstall PRS.')
    }
    $plugin = Get-ChildPath $resource 'UserPlugins/reaper_reawebapi-x64.dll'
    $installed = if (Test-Path -LiteralPath $plugin) { Get-SHA256 $plugin } else { '' }
    $action = Get-RuntimeAction $installed $policy.binary_sha256 $policy
    if ($action -eq 'preserve-external') { throw (Get-SetupText '检测到未知来源的共享 ReaWebAPI，已保留原文件。如果决定替换，请使用完整 PRS 安装器并显式指定 -UseBundledRuntime。' 'An unknown shared ReaWebAPI is installed. It was preserved. Use the complete PRS installer with -UseBundledRuntime only if you choose to replace it.') }
    if ($PlanOnly) { return [pscustomobject]@{ Runtime = $action; Resource = $resource; Validation = $runtime.runtime_policy.validation_status } }
    $guard = Open-InstallerLock $resource
    $transactions = Get-ChildPath $resource 'Data/PsyReaSFX-WebView/transactions'
    if (Test-Path -LiteralPath $transactions) {
        foreach ($pendingFile in Get-ChildItem -LiteralPath $transactions -Filter receipt.json -File -Recurse) {
            $pending = Get-Content -LiteralPath $pendingFile.FullName -Raw | ConvertFrom-Json
            if ($pending.kind -ne 'runtime-only' -or $pending.status -ne 'installing') { continue }
            if ($installed -ceq $pending.installedRuntimeHash) {
                if ($pending.runtimeAction -eq 'replace' -and
                    (Get-SHA256 (Join-Path $pendingFile.DirectoryName 'previous-runtime.dll')) -cne $pending.previousRuntimeHash) { throw (Get-SetupText '中断安装的运行组件备份校验失败。请保留备份目录，并使用完整安装包修复。' 'The interrupted runtime backup failed checksum verification. Keep the backup folder and repair using the complete installer.') }
                $pending.status = 'installed'
            } elseif ($installed -ceq $pending.previousRuntimeHash) { $pending.status = 'restored' }
            else { throw (Get-SetupText '安装中断后检测到其他程序更新了组件，已保留该更新。请先处理原安装的恢复记录。' 'An external update followed an interrupted install. It was preserved. Resolve the interrupted installation before retrying.') }
            Write-Receipt $pendingFile.FullName $pending
        }
    }
    $waited = $false
    if ($action -eq 'replace') {
        $deadline = [DateTime]::UtcNow.AddMinutes(30)
        while (Get-Process -Name reaper -ErrorAction SilentlyContinue) {
            if (-not $WaitForReaperExit) { throw (Get-SetupText '请关闭所有 REAPER 窗口后，再更新随包组件。' 'Close all REAPER windows before updating the bundled component.') }
            if (-not $waited) { Publish-SetupStatus 'waiting' (Get-SetupText '请关闭所有 REAPER 窗口。随包组件会自动更新；出现完成提示后重新打开 REAPER。' 'Close all REAPER windows. The bundled component will update automatically. Reopen REAPER after the completion message appears.') }
            $waited = $true
            if ([DateTime]::UtcNow -gt $deadline) { throw (Get-SetupText '等待 REAPER 关闭超时。请重新运行 PRS 以重试。' 'Setup timed out waiting for REAPER to close. Run PRS again to retry.') }
            Start-Sleep -Milliseconds 500
        }
    }
    # Re-check under the installer lock after waiting; never overwrite an
    # intervening external update or operate on a previously classified file.
    $current = if (Test-Path -LiteralPath $plugin) { Get-SHA256 $plugin } else { '' }
    if ($current -cne $installed) { throw (Get-SetupText '安装期间共享组件发生变化，已保留其他程序的更新。请重新运行 PRS。' 'The shared runtime changed during setup. The other update was preserved; run PRS again.') }
    if ($action -ne 'reuse') {
        $id = [guid]::NewGuid().ToString('N')
        $transaction = Get-ChildPath $resource "Data/PsyReaSFX-WebView/transactions/$id"
        [IO.Directory]::CreateDirectory($transaction) | Out-Null
        if ($action -eq 'replace') {
            $backup = Join-Path $transaction 'previous-runtime.dll'
            Copy-Item -LiteralPath $plugin -Destination $backup
            if ((Get-SHA256 $backup) -cne $installed) { throw (Get-SetupText '备份期间运行组件发生变化。请等待其他更新完成后重试。' 'The runtime changed while preparing its backup. Wait for the other update to finish, then retry.') }
        }
        # Existing restore logic skips application moves for this runtime-only
        # receipt, including when the main script is managed by ReaPack.
        $receipt = [pscustomobject]@{
            schema = 'PsyReaSFX-WebView-Install-v1'; id = $id; packageId = ''; kind = 'runtime-only'
            status = 'installing'; created = [DateTime]::UtcNow.ToString('o'); appExisted = $true
            runtimeAction = $action; previousRuntimeHash = $installed; installedRuntimeHash = $policy.binary_sha256
        }
        $receiptPath = Join-Path $transaction 'receipt.json'
        Write-Receipt $receiptPath $receipt
        $staged = Get-ChildPath $resource "UserPlugins/.PsyReaSFX-install-$id.dll"
        [IO.Directory]::CreateDirectory((Split-Path -Parent $plugin)) | Out-Null
        try {
            Copy-Item -LiteralPath $bundled -Destination $staged
            $current = if (Test-Path -LiteralPath $plugin) { Get-SHA256 $plugin } else { '' }
            if ($current -cne $installed -or (Get-SHA256 $staged) -cne $policy.binary_sha256) { throw (Get-SetupText '安装期间组件发生变化。请等待其他更新完成后，重新运行 PRS。' 'The runtime changed during setup. Wait for the other update to finish, then run PRS again.') }
            if ($action -eq 'replace') { [IO.File]::Replace($staged, $plugin, [NullString]::Value) }
            else { [IO.File]::Move($staged, $plugin) }
            $receipt.status = 'installed'
            Write-Receipt $receiptPath $receipt
        }
        catch { Restore-Transaction $resource $id; throw }
        finally { if (Test-Path -LiteralPath $staged) { Remove-Item -LiteralPath $staged } }
    }
    Publish-SetupStatus 'ready' (Get-SetupText '随包组件已准备好，请完全退出并重新打开 REAPER，再运行 PRS。' 'The bundled component is ready. Fully close and reopen REAPER, then run PRS again.')
    if ($Notify -and $waited) {
        Add-Type -AssemblyName System.Windows.Forms
        [void][Windows.Forms.MessageBox]::Show((Get-SetupText 'PRS 随包组件更新完成，现在可以重新打开 REAPER。' 'The PRS bundled component has been updated. You can reopen REAPER now.'), $setupTitle)
    }
}
catch {
    $errorText = (Get-SetupText "组件准备未完成。请按以下说明处理后重试。`n`n" "Component setup did not finish. Follow the details below, then retry.`n`n") + $_.Exception.Message
    Publish-SetupStatus 'error' $errorText
    if ($Notify -and $waited) {
        Add-Type -AssemblyName System.Windows.Forms
        [void][Windows.Forms.MessageBox]::Show($errorText, $setupTitle)
    }
    throw
}
finally { if ($guard) { $guard.Dispose() } }
