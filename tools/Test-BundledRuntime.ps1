[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PackagePath, [Parameter(Mandatory=$true)][string]$FixtureDirectory)
$ErrorActionPreference = 'Stop'
$PackagePath = [IO.Path]::GetFullPath($PackagePath)
$FixtureDirectory = [IO.Path]::GetFullPath($FixtureDirectory)
if (Test-Path -LiteralPath $FixtureDirectory) { throw 'Use a fresh bundled-runtime fixture directory.' }
$package = Join-Path $FixtureDirectory 'package'
[IO.Directory]::CreateDirectory($package) | Out-Null
Copy-Item -Path (Join-Path $PackagePath '*') -Destination $package -Recurse
. (Join-Path $package 'installer-common.ps1')
$helper = Join-Path $package 'Install-BundledRuntime.ps1'
$restore = Join-Path $package 'Restore-PsyReaSFX.ps1'
$policyPath = Join-Path $package 'bundled-runtime.json'
$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$runtime = Get-Content -LiteralPath (Join-Path $package 'runtime-lock.json') -Raw | ConvertFrom-Json
if (-not (Read-BundledRuntimePolicy $package $runtime)) { throw 'Test the approved release bundle.' }
$global:BundledRuntimeFixture = @{ Running=$false; Sleeps=0; WaitingPath=''; ExternalChange='' }
function Get-Process([string]$Name, $ErrorAction) {
    if ($Name -cne 'reaper') { throw 'Installer queried an unrelated process.' }
    if ($global:BundledRuntimeFixture.Running) { [pscustomobject]@{ProcessName='reaper'} }
}
function Stop-Process { throw 'Installer must never terminate processes.' }
function Start-Sleep {
    $state = $global:BundledRuntimeFixture
    $state.Sleeps++
    if ((Get-Content -LiteralPath $state.WaitingPath -Raw) -notmatch '^waiting') { throw 'Missing close-REAPER instruction before wait.' }
    if ($state.ExternalChange) { [IO.File]::WriteAllText($state.ExternalChange, 'external update during wait') }
    $state.Running=$false
}
function Assert-True($Value, [string]$Message) { if (-not $Value) { throw $Message } }
function Reject([scriptblock]$Action) { $failed=$false; try { & $Action | Out-Null } catch { $failed=$true }; Assert-True $failed 'Expected setup rejection' }
function Resource([string]$Name) {
    $path=Join-Path $FixtureDirectory $Name
    [IO.Directory]::CreateDirectory($path) | Out-Null
    [IO.File]::WriteAllText((Join-Path $path 'reaper.ini'),'[reaper]')
    return $path
}
function Plugin([string]$Root) { return Join-Path $Root 'UserPlugins/reaper_reawebapi-x64.dll' }
function Put-Old([string]$Root, [string]$Value='synthetic previous PRS runtime') {
    [IO.Directory]::CreateDirectory((Join-Path $Root 'UserPlugins')) | Out-Null
    [IO.File]::WriteAllText((Plugin $Root),$Value)
    return Get-SHA256 (Plugin $Root)
}
try {
    $fresh=Resource 'fresh'
    Assert-True ((& $helper -ReaperResourcePath $fresh -PlanOnly).Runtime -ceq 'install') 'Fresh plan'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $fresh 'Data'))) 'Planning wrote install state'
    & $helper -ReaperResourcePath $fresh
    Assert-True ((Get-SHA256 (Plugin $fresh)) -ceq $policy.binary_sha256) 'Fresh bundled runtime was not installed'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $fresh 'Scripts'))) 'Runtime bootstrap changed the ReaPack application'
    $receiptFile=Get-ChildItem -LiteralPath (Join-Path $fresh 'Data') -Filter receipt.json -Recurse | Select-Object -First 1
    $receipt=Get-Content -LiteralPath $receiptFile.FullName -Raw | ConvertFrom-Json
    $receipt.status='installing'; Write-Receipt $receiptFile.FullName $receipt
    & $helper -ReaperResourcePath $fresh
    Assert-True ((Get-Content -LiteralPath $receiptFile.FullName -Raw | ConvertFrom-Json).status -ceq 'installed') 'Interrupted committed install was not finalized'
    & $restore -ReaperResourcePath $fresh
    Assert-True (-not (Test-Path -LiteralPath (Plugin $fresh))) 'Fresh runtime rollback failed'

    $known=Resource 'known'
    $oldHash=Put-Old $known
    $policy.replace_hashes=@($oldHash)
    [IO.File]::WriteAllText($policyPath,($policy | ConvertTo-Json -Depth 10),(New-Object Text.UTF8Encoding($false)))
    $global:BundledRuntimeFixture.Running=$true
    Reject { & $helper -ReaperResourcePath $known }
    Assert-True ((Get-SHA256 (Plugin $known)) -ceq $oldHash) 'Loaded runtime was modified'
    $request='1234567890abcdef1234567890abcdef'
    $global:BundledRuntimeFixture.WaitingPath=Join-Path $known "Data/PsyReaSFX-WebView/runtime-setup-$request.txt"
    & $helper -ReaperResourcePath $known -RequestId $request -WaitForReaperExit
    Assert-True ($global:BundledRuntimeFixture.Sleeps -eq 1) 'Expected one simulated REAPER exit wait'
    Assert-True ((Get-SHA256 (Plugin $known)) -ceq $policy.binary_sha256) 'Known PRS runtime not upgraded'
    & $restore -ReaperResourcePath $known
    Assert-True ((Get-SHA256 (Plugin $known)) -ceq $oldHash) 'Previous runtime backup was not restored'

    $locked=[IO.File]::Open((Plugin $known),'Open','Read','Read')
    try { Reject { & $helper -ReaperResourcePath $known } } finally { $locked.Dispose() }
    Assert-True ((Get-SHA256 (Plugin $known)) -ceq $oldHash) 'Locked replacement changed original runtime'
    $guard=Open-InstallerLock $known
    try { Reject { & $helper -ReaperResourcePath $known } } finally { $guard.Dispose() }

    $foreign=Resource 'foreign'
    $foreignHash=Put-Old $foreign 'unrecognized external component'
    Reject { & $helper -ReaperResourcePath $foreign }
    Assert-True ((Get-SHA256 (Plugin $foreign)) -ceq $foreignHash) 'Unknown shared component was overwritten'
    $global:BundledRuntimeFixture.Running=$true
    $global:BundledRuntimeFixture.ExternalChange=Plugin $known
    Reject { & $helper -ReaperResourcePath $known -RequestId $request -WaitForReaperExit }
    Assert-True (([IO.File]::ReadAllText((Plugin $known))) -ceq 'external update during wait') 'Concurrent updater was overwritten'
    $global:BundledRuntimeFixture.ExternalChange=''

    $bad=Resource 'tampered'
    [IO.File]::AppendAllText((Join-Path $package 'runtime/reawebapi/reaper_reawebapi-x64.dll'),'changed')
    Reject { & $helper -ReaperResourcePath $bad }
    Assert-True (-not (Test-Path -LiteralPath (Plugin $bad))) 'Tampered native payload was installed'
    Write-Host 'Bundled runtime verified: fresh/reuse, exact approval, deferred known upgrade, unknown preservation, shared lock, rollback, interrupted receipt, external race and tamper rejection.'
} finally { Remove-Variable -Name BundledRuntimeFixture -Scope Global }
