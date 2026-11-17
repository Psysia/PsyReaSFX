[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ReaperResourcePath,
    [ValidatePattern('^[a-f0-9]{32}$')][string]$RequestId = '',
    [switch]$WaitForReaperExit,
    [switch]$Notify,
    [switch]$PlanOnly
)
. (Join-Path $PSScriptRoot 'installer-common.ps1')
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
    if (-not $policy) { throw 'Bundled runtime approval is missing or does not match this application. Reinstall the complete PRS package.' }
    $bundled = Join-Path $PSScriptRoot 'runtime/reawebapi/reaper_reawebapi-x64.dll'
    $source = Join-Path $PSScriptRoot 'sources/ReaWebAPI-source.zip'
    if ((Get-SHA256 $bundled) -cne $policy.binary_sha256 -or (Get-SHA256 $source) -cne $policy.source_sha256) {
        throw 'Bundled runtime or corresponding source failed checksum verification. Reinstall PRS.'
    }
    $plugin = Get-ChildPath $resource 'UserPlugins/reaper_reawebapi-x64.dll'
    $installed = if (Test-Path -LiteralPath $plugin) { Get-SHA256 $plugin } else { '' }
    $action = Get-RuntimeAction $installed $policy.binary_sha256 $policy
    if ($action -eq 'preserve-external') { throw 'An unknown shared ReaWebAPI is installed. It was preserved. Use the complete PRS installer with -UseBundledRuntime only if you choose to replace it.' }
    if ($PlanOnly) { return [pscustomobject]@{ Runtime = $action; Resource = $resource; Validation = $runtime.runtime_policy.validation_status } }
    $guard = Open-InstallerLock $resource
    $transactions = Get-ChildPath $resource 'Data/PsyReaSFX-WebView/transactions'
    if (Test-Path -LiteralPath $transactions) {
        foreach ($pendingFile in Get-ChildItem -LiteralPath $transactions -Filter receipt.json -File -Recurse) {
            $pending = Get-Content -LiteralPath $pendingFile.FullName -Raw | ConvertFrom-Json
            if ($pending.kind -ne 'runtime-only' -or $pending.status -ne 'installing') { continue }
            if ($installed -ceq $pending.installedRuntimeHash) {
                if ($pending.runtimeAction -eq 'replace' -and
                    (Get-SHA256 (Join-Path $pendingFile.DirectoryName 'previous-runtime.dll')) -cne $pending.previousRuntimeHash) { throw 'Interrupted runtime backup failed checksum verification.' }
                $pending.status = 'installed'
            } elseif ($installed -ceq $pending.previousRuntimeHash) { $pending.status = 'restored' }
            else { throw 'An external update followed an interrupted install. It was preserved.' }
            Write-Receipt $pendingFile.FullName $pending
        }
    }
    $waited = $false
    if ($action -eq 'replace') {
        $deadline = [DateTime]::UtcNow.AddMinutes(30)
        while (Get-Process -Name reaper -ErrorAction SilentlyContinue) {
            if (-not $WaitForReaperExit) { throw 'Close all REAPER windows before updating the bundled component.' }
            if (-not $waited) { Publish-SetupStatus 'waiting' '请关闭所有 REAPER 窗口。随包组件会自动更新；出现完成提示后重新打开 REAPER。' }
            $waited = $true
            if ([DateTime]::UtcNow -gt $deadline) { throw 'Setup timed out waiting for REAPER to close. Run PRS again to retry.' }
            Start-Sleep -Milliseconds 500
        }
    }
    # Re-check under the installer lock after waiting; never overwrite an
    # intervening external update or operate on a previously classified file.
    $current = if (Test-Path -LiteralPath $plugin) { Get-SHA256 $plugin } else { '' }
    if ($current -cne $installed) { throw 'The shared runtime changed during setup. The other update was preserved; run PRS again.' }
    if ($action -ne 'reuse') {
        $id = [guid]::NewGuid().ToString('N')
        $transaction = Get-ChildPath $resource "Data/PsyReaSFX-WebView/transactions/$id"
        [IO.Directory]::CreateDirectory($transaction) | Out-Null
        if ($action -eq 'replace') {
            $backup = Join-Path $transaction 'previous-runtime.dll'
            Copy-Item -LiteralPath $plugin -Destination $backup
            if ((Get-SHA256 $backup) -cne $installed) { throw 'Runtime changed while preparing its backup.' }
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
            if ($current -cne $installed -or (Get-SHA256 $staged) -cne $policy.binary_sha256) { throw 'Runtime changed during setup.' }
            if ($action -eq 'replace') { [IO.File]::Replace($staged, $plugin, [NullString]::Value) }
            else { [IO.File]::Move($staged, $plugin) }
            $receipt.status = 'installed'
            Write-Receipt $receiptPath $receipt
        }
        catch { Restore-Transaction $resource $id; throw }
        finally { if (Test-Path -LiteralPath $staged) { Remove-Item -LiteralPath $staged } }
    }
    Publish-SetupStatus 'ready' '随包组件已准备好，请完全退出并重新打开 REAPER，再运行 PRS。'
    if ($Notify -and $waited) {
        Add-Type -AssemblyName System.Windows.Forms
        [void][Windows.Forms.MessageBox]::Show('PRS 随包组件更新完成，现在可以重新打开 REAPER。', 'PsyReaSFX')
    }
}
catch {
    Publish-SetupStatus 'error' $_.Exception.Message
    if ($Notify -and $waited) {
        Add-Type -AssemblyName System.Windows.Forms
        [void][Windows.Forms.MessageBox]::Show($_.Exception.Message, 'PsyReaSFX setup')
    }
    throw
}
finally { if ($guard) { $guard.Dispose() } }
