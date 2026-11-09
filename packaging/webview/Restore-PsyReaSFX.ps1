[CmdletBinding()]
param([string]$ReaperResourcePath = '', [switch]$ChooseResourcePath, [string]$TransactionId = '')
. (Join-Path $PSScriptRoot 'installer-common.ps1')
$resource = Get-ResourcePath $ReaperResourcePath -Choose:$ChooseResourcePath
Assert-ReaperClosed
$guard = Open-InstallerLock $resource
try {
    if (-not $TransactionId) {
        $transactions = Get-ChildPath $resource 'Data/PsyReaSFX-WebView/transactions'
        $receipts = @(Get-ChildItem -LiteralPath $transactions -Filter receipt.json -File -Recurse | ForEach-Object {
            Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        } | Where-Object { $_.status -in @('installed', 'installing') } | Sort-Object created -Descending)
        if (-not $receipts.Count) { throw 'No installation is available to restore.' }
        $TransactionId = $receipts[0].id
    }
    Restore-Transaction $resource $TransactionId
    Write-Host "Restored transaction $TransactionId. Previous application and runtime have been recovered."
}
finally { $guard.Dispose() }
