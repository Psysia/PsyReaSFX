[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PackagePath,
    [Parameter(Mandatory = $true)][string]$FixtureDirectory,
    [string]$ArchivePath = ''
)
$ErrorActionPreference = 'Stop'
$FixtureDirectory = [IO.Path]::GetFullPath($FixtureDirectory)
if (Test-Path -LiteralPath $FixtureDirectory) { throw 'Choose a new isolated fixture directory.' }
[IO.Directory]::CreateDirectory($FixtureDirectory) | Out-Null
$PackagePath = [IO.Path]::GetFullPath($PackagePath)
if ($ArchivePath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $PackagePath = Join-Path $FixtureDirectory 'extracted-package'
    [IO.Compression.ZipFile]::ExtractToDirectory([IO.Path]::GetFullPath($ArchivePath), $PackagePath)
}
. (Join-Path $PackagePath 'installer-common.ps1')
$manifest = Read-Package $PackagePath
$webManifest = Get-Content -LiteralPath (Join-Path $PackagePath 'web/app.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($webManifest.id -cnotmatch '^[a-z0-9-]+$' -or $webManifest.version -cne $manifest.version) {
    throw 'Web runtime app ID or version is incompatible with the native package.'
}
$manifestPaths = @($manifest.files | ForEach-Object { $_.path })
foreach ($file in Get-ChildItem -LiteralPath $PackagePath -File -Recurse) {
    if ($file.Name -eq 'package-manifest.json') { continue }
    $relative = $file.FullName.Substring($PackagePath.TrimEnd('\').Length + 1).Replace('\', '/')
    if ($relative -cnotin $manifestPaths) { throw "Unlisted payload file: $relative" }
}
$runtimeLock = Get-Content -LiteralPath (Join-Path $PackagePath 'runtime-lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($required in @('licenses/reawebapi/COPYING', 'licenses/reawebapi/COPYING.LESSER', 'licenses/reawebapi/THIRD_PARTY.md', "sources/$($runtimeLock.source.file)")) {
    if (-not (Test-Path -LiteralPath (Join-Path $PackagePath $required))) { throw "Missing redistribution material: $required" }
}
if ((Get-SHA256 (Join-Path $PackagePath "sources/$($runtimeLock.source.file)")) -cne $runtimeLock.source.sha256) { throw 'Source archive checksum mismatch.' }
$install = Join-Path $PackagePath 'Install-PsyReaSFX.ps1'
$restore = Join-Path $PackagePath 'Restore-PsyReaSFX.ps1'
# Process state is simulated only in this disposable fixture test process.
$global:PsyReaSFXTestReaperRunning = $false
function Get-Process([string]$Name, $ErrorAction) {
    if ($Name -ne 'reaper') { throw 'Unexpected mocked process query.' }
    if ($global:PsyReaSFXTestReaperRunning) { return [pscustomobject]@{ ProcessName = 'reaper' } }
}
function Assert-Equal($Actual, $Expected, [string]$Message) {
    if ($Actual -cne $Expected) { throw "$Message. Expected $Expected, got $Actual" }
}
function Expect-Failure([scriptblock]$Action, [string]$Message) {
    $failed = $false
    try { & $Action | Out-Null } catch { $failed = $true }
    if (-not $failed) { throw $Message }
}
function New-Resource([string]$Name) {
    $path = Join-Path $FixtureDirectory $Name
    [IO.Directory]::CreateDirectory($path) | Out-Null
    [IO.File]::WriteAllText((Join-Path $path 'reaper.ini'), '[reaper]')
    return $path
}
function Plugin-Path([string]$Resource) { return Join-Path $Resource 'UserPlugins/reaper_reawebapi-x64.dll' }
function Set-ExternalRuntime([string]$Resource, [string]$Text = 'external-runtime') {
    $path = Plugin-Path $Resource
    [IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
    [IO.File]::WriteAllText($path, $Text)
    return Get-SHA256 $path
}

$fresh = New-Resource 'r-fresh'
$stableBaseline = $runtimeLock.runtime_policy.distribution_channel -ceq 'stable' -and
    $runtimeLock.runtime_policy.distribution_binary_sha256 -ceq $runtimeLock.binary.sha256
$installOptions = @{}
$bundledPolicy = Read-BundledRuntimePolicy $PackagePath $runtimeLock
if ($runtimeLock.runtime_policy.validation_status -cne 'native_accepted' -and -not $stableBaseline -and -not $bundledPolicy) {
    $installOptions.AllowUnverifiedRuntime = $true
    Expect-Failure { & $install -ReaperResourcePath $fresh } 'Unverified native runtime must be blocked by default'
    Assert-Equal (Test-Path -LiteralPath (Join-Path $fresh 'Data')) $false 'Runtime acceptance gate must run before install state is written'
}
$plan = & $install @installOptions -ReaperResourcePath $fresh -PlanOnly
Assert-Equal $plan.Runtime 'install' 'Fresh runtime plan'
Assert-Equal $plan.RuntimeValidation $runtimeLock.runtime_policy.validation_status 'Distribution must preserve native-acceptance diagnostics'
Assert-Equal $plan.RuntimeDistribution $runtimeLock.runtime_policy.distribution_channel 'Distribution channel is shown in the install plan'
Assert-Equal (Test-Path -LiteralPath (Join-Path $fresh 'Data')) $false 'PlanOnly must be read-only'
$global:PsyReaSFXTestReaperRunning = $true
Expect-Failure { & $install @installOptions -ReaperResourcePath $fresh } 'Running REAPER must block installation'
$global:PsyReaSFXTestReaperRunning = $false
& $install @installOptions -ReaperResourcePath $fresh
Assert-Equal (Get-SHA256 (Plugin-Path $fresh)) $runtimeLock.binary.sha256 'Fresh runtime installed'
Read-Package (Join-Path $fresh 'Scripts/PsyReaSFX-WebView') | Out-Null
foreach ($asset in @('brand/psyreasfx-icon.png', 'ucs/ucs-8.2.1.tsv', 'neural/mn04_as_scene_320_v1/mn04_as_scene_320_v1.onnx')) {
    if (-not (Test-Path -LiteralPath (Join-Path $fresh "Scripts/PsyReaSFX-WebView/assets/$asset"))) { throw "Installed asset missing: $asset" }
}
$firstTransaction = Get-Content -LiteralPath (Join-Path $fresh 'Scripts/PsyReaSFX-WebView/.install-transaction') -Raw
& $install @installOptions -ReaperResourcePath $fresh
Expect-Failure { & $restore -ReaperResourcePath $fresh -TransactionId $firstTransaction } 'Older transaction must not replace a more recent install of the same package'
& $restore -ReaperResourcePath $fresh
Assert-Equal (Get-SHA256 (Plugin-Path $fresh)) $runtimeLock.binary.sha256 'Reused runtime survives app rollback'
& $restore -ReaperResourcePath $fresh
Assert-Equal (Test-Path -LiteralPath (Plugin-Path $fresh)) $false 'Fresh runtime removed by rollback'
Assert-Equal (Test-Path -LiteralPath (Join-Path $fresh 'Scripts/PsyReaSFX-WebView')) $false 'Fresh app restored to absent'

$external = New-Resource 'r-shared'
$externalHash = Set-ExternalRuntime $external
& $install @installOptions -ReaperResourcePath $external
Assert-Equal (Get-SHA256 (Plugin-Path $external)) $externalHash 'External runtime preserved by default'
& $install @installOptions -ReaperResourcePath $external -UseBundledRuntime
Assert-Equal (Get-SHA256 (Plugin-Path $external)) $runtimeLock.binary.sha256 'Explicit runtime replacement'
& $restore -ReaperResourcePath $external
Assert-Equal (Get-SHA256 (Plugin-Path $external)) $externalHash 'Previous shared runtime restored'

$locked = New-Resource 'r-locked'
$lockedHash = Set-ExternalRuntime $locked
$handle = [IO.File]::Open((Plugin-Path $locked), 'Open', 'Read', 'Read')
try { Expect-Failure { & $install @installOptions -ReaperResourcePath $locked -UseBundledRuntime } 'Locked DLL replacement must fail' }
finally { $handle.Dispose() }
Assert-Equal (Get-SHA256 (Plugin-Path $locked)) $lockedHash 'Failed install preserved runtime'
Assert-Equal (Test-Path -LiteralPath (Join-Path $locked 'Scripts/PsyReaSFX-WebView')) $false 'Failed install rolled back application'

$concurrent = New-Resource 'r-concurrent'
$guard = Open-InstallerLock $concurrent
try { Expect-Failure { & $install @installOptions -ReaperResourcePath $concurrent } 'Exclusive installer lock must reject concurrent install' }
finally { $guard.Dispose() }
Assert-Equal (Test-Path -LiteralPath (Join-Path $concurrent 'Scripts')) $false 'Concurrent install must not write app'

$recovery = New-Resource 'r-recovery'
$recoveryHash = Set-ExternalRuntime $recovery
& $install @installOptions -ReaperResourcePath $recovery -UseBundledRuntime
$receiptFile = Get-ChildItem -LiteralPath (Join-Path $recovery 'Data/PsyReaSFX-WebView/transactions') -Filter receipt.json -Recurse | Select-Object -First 1
$receipt = Get-Content -LiteralPath $receiptFile.FullName -Raw | ConvertFrom-Json
$receipt.status = 'installing'
Write-Receipt $receiptFile.FullName $receipt
& $install @installOptions -ReaperResourcePath $recovery
Assert-Equal (Get-SHA256 (Plugin-Path $recovery)) $recoveryHash 'Interrupted installation recovered before next install'

$changed = New-Resource 'r-updated'
Set-ExternalRuntime $changed | Out-Null
& $install @installOptions -ReaperResourcePath $changed -UseBundledRuntime
$changedHash = Set-ExternalRuntime $changed 'externally-updated-runtime'
Expect-Failure { & $restore -ReaperResourcePath $changed } 'Rollback must protect subsequent external updates'
Assert-Equal (Get-SHA256 (Plugin-Path $changed)) $changedHash 'Subsequent runtime update preserved'

# Exercise the production installer with a repackaged candidate of the same
# binary. Its default rejection must precede creation of any transaction state.
$candidatePackage = Join-Path $FixtureDirectory 'candidate-package'
[IO.Directory]::CreateDirectory($candidatePackage) | Out-Null
Copy-Item -Path (Join-Path $PackagePath '*') -Destination $candidatePackage -Recurse
$candidateLockPath = Join-Path $candidatePackage 'runtime-lock.json'
$candidateLock = Get-Content -LiteralPath $candidateLockPath -Raw -Encoding UTF8 | ConvertFrom-Json
$candidateLock.runtime_policy.validation_status = 'native_acceptance_pending'
$candidateLock.runtime_policy | Add-Member -NotePropertyName distribution_channel -NotePropertyValue 'candidate' -Force
$candidateLock.runtime_policy.PSObject.Properties.Remove('distribution_binary_sha256')
$candidateApproval = Join-Path $candidatePackage 'bundled-runtime.json'
if (Test-Path -LiteralPath $candidateApproval) {
    $candidateApprovalValue = Get-Content -LiteralPath $candidateApproval -Raw | ConvertFrom-Json
    if ($bundledPolicy) {
        # Exercise the full offline installer's automatic predecessor upgrade,
        # using only a synthetic runtime and an approval in this fixture copy.
        $known = New-Resource 'r-known'
        $knownHash = Set-ExternalRuntime $known 'fixture previous PRS component'
        $candidateApprovalValue.replace_hashes = @($knownHash)
        [IO.File]::WriteAllText($candidateApproval, ($candidateApprovalValue | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
        $knownManifestPath = Join-Path $candidatePackage 'package-manifest.json'
        $knownManifest = Get-Content -LiteralPath $knownManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        ($knownManifest.files | Where-Object path -CEQ 'bundled-runtime.json').sha256 = Get-SHA256 $candidateApproval
        [IO.File]::WriteAllText($knownManifestPath, ($knownManifest | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
        & (Join-Path $candidatePackage 'Install-PsyReaSFX.ps1') -ReaperResourcePath $known
        Assert-Equal (Get-SHA256 (Plugin-Path $known)) $runtimeLock.binary.sha256 'Known PRS runtime upgraded without extra flags'
        & (Join-Path $candidatePackage 'Restore-PsyReaSFX.ps1') -ReaperResourcePath $known
        Assert-Equal (Get-SHA256 (Plugin-Path $known)) $knownHash 'Automatic predecessor upgrade preserves a usable backup'
    }
    $candidateApprovalValue.app_version = 'unapproved-candidate'
    [IO.File]::WriteAllText($candidateApproval, ($candidateApprovalValue | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
}
function Write-CandidateFixture {
    [IO.File]::WriteAllText($candidateLockPath, ($candidateLock | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
    $candidateManifestPath = Join-Path $candidatePackage 'package-manifest.json'
    $candidateManifest = Get-Content -LiteralPath $candidateManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    ($candidateManifest.files | Where-Object path -CEQ 'runtime-lock.json').sha256 = Get-SHA256 $candidateLockPath
    if (Test-Path -LiteralPath $candidateApproval) {
        ($candidateManifest.files | Where-Object path -CEQ 'bundled-runtime.json').sha256 = Get-SHA256 $candidateApproval
    }
    [IO.File]::WriteAllText($candidateManifestPath, ($candidateManifest | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
}
Write-CandidateFixture
$candidateInstall = Join-Path $candidatePackage 'Install-PsyReaSFX.ps1'
$candidateResource = New-Resource 'r-candidate'
Expect-Failure { & $candidateInstall -ReaperResourcePath $candidateResource } 'Candidate must require explicit opt-in even when binary equals the stable baseline'
Assert-Equal (Test-Path -LiteralPath (Join-Path $candidateResource 'Data')) $false 'Candidate rejection must not write transaction state'
& $candidateInstall -ReaperResourcePath $candidateResource -AllowUnverifiedRuntime
Assert-Equal (Get-SHA256 (Plugin-Path $candidateResource)) $runtimeLock.binary.sha256 'Explicit candidate testing remains available'
& (Join-Path $candidatePackage 'Restore-PsyReaSFX.ps1') -ReaperResourcePath $candidateResource
$candidateExternal = New-Resource 'r-candidate-shared'
$candidateExternalHash = Set-ExternalRuntime $candidateExternal
Expect-Failure { & $candidateInstall -ReaperResourcePath $candidateExternal -UseBundledRuntime } 'Candidate replacement must require explicit opt-in'
Assert-Equal (Get-SHA256 (Plugin-Path $candidateExternal)) $candidateExternalHash 'Rejected candidate replacement preserves external runtime'
Assert-Equal (Test-Path -LiteralPath (Join-Path $candidateExternal 'Data')) $false 'Rejected candidate replacement must not create install state'

$candidateLock.runtime_policy.distribution_channel = 'stable'
$candidateLock.runtime_policy | Add-Member -NotePropertyName distribution_binary_sha256 -NotePropertyValue ('0' * 64) -Force
Write-CandidateFixture
$unpinnedResource = New-Resource 'r-unpinned-stable'
Expect-Failure { & $candidateInstall -ReaperResourcePath $unpinnedResource } 'Stable label must not allow a different binary hash'
Assert-Equal (Test-Path -LiteralPath (Join-Path $unpinnedResource 'Data')) $false 'Unpinned stable rejection must not write transaction state'

# Mutate only the disposable extracted/copied payload.
$tampered = Join-Path $FixtureDirectory 'tampered-package'
[IO.Directory]::CreateDirectory($tampered) | Out-Null
Copy-Item -Path (Join-Path $PackagePath '*') -Destination $tampered -Recurse
[IO.File]::AppendAllText((Join-Path $tampered 'web/index.html'), 'tampered')
$tamperResource = New-Resource 'r-tamper'
Expect-Failure { & (Join-Path $tampered 'Install-PsyReaSFX.ps1') -ReaperResourcePath $tamperResource } 'Tampered package must fail before install'
Assert-Equal (Test-Path -LiteralPath (Join-Path $tamperResource 'Data')) $false 'Tampered package must not create transaction state'
Expect-Failure { Get-ChildPath $FixtureDirectory '../outside' } 'Path traversal must fail'
Expect-Failure { Get-ChildPath $FixtureDirectory 'C:\outside' } 'Absolute package paths must fail'
$deep = New-Resource ('long-resource-path-' + ('x' * 80))
Expect-Failure { & $install @installOptions -ReaperResourcePath $deep } 'Unsupported deep resource paths must fail preflight'
Assert-Equal (Test-Path -LiteralPath (Join-Path $deep 'Data')) $false 'Deep path preflight must not write transaction state'
Remove-Variable -Name PsyReaSFXTestReaperRunning -Scope Global
Write-Host 'WebView package verified: archive, hashes, licenses/source, default stable install, candidate opt-in, exact stable pin, fresh/repeat install, external preservation, replacement/rollback, locked DLL failure, concurrency, interrupted recovery, external-update protection, tamper/path rejection.'
