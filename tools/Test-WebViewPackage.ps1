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
if ($runtimeLock.runtime_policy.validation_status -cne 'native_accepted') {
    Expect-Failure { & $install -ReaperResourcePath $fresh } 'Unverified native runtime must be blocked by default'
    Assert-Equal (Test-Path -LiteralPath (Join-Path $fresh 'Data')) $false 'Runtime acceptance gate must run before install state is written'
}
$plan = & $install -AllowUnverifiedRuntime -ReaperResourcePath $fresh -PlanOnly
Assert-Equal $plan.Runtime 'install' 'Fresh runtime plan'
Assert-Equal (Test-Path -LiteralPath (Join-Path $fresh 'Data')) $false 'PlanOnly must be read-only'
$global:PsyReaSFXTestReaperRunning = $true
Expect-Failure { & $install -AllowUnverifiedRuntime -ReaperResourcePath $fresh } 'Running REAPER must block installation'
$global:PsyReaSFXTestReaperRunning = $false
& $install -AllowUnverifiedRuntime -ReaperResourcePath $fresh
Assert-Equal (Get-SHA256 (Plugin-Path $fresh)) $runtimeLock.binary.sha256 'Fresh runtime installed'
Read-Package (Join-Path $fresh 'Scripts/PsyReaSFX-WebView') | Out-Null
foreach ($asset in @('brand/psyreasfx-icon.png', 'ucs/ucs-8.2.1.tsv', 'neural/mn04_as_scene_320_v1/mn04_as_scene_320_v1.onnx')) {
    if (-not (Test-Path -LiteralPath (Join-Path $fresh "Scripts/PsyReaSFX-WebView/assets/$asset"))) { throw "Installed asset missing: $asset" }
}
$firstTransaction = Get-Content -LiteralPath (Join-Path $fresh 'Scripts/PsyReaSFX-WebView/.install-transaction') -Raw
& $install -AllowUnverifiedRuntime -ReaperResourcePath $fresh
Expect-Failure { & $restore -ReaperResourcePath $fresh -TransactionId $firstTransaction } 'Older transaction must not replace a more recent install of the same package'
& $restore -ReaperResourcePath $fresh
Assert-Equal (Get-SHA256 (Plugin-Path $fresh)) $runtimeLock.binary.sha256 'Reused runtime survives app rollback'
& $restore -ReaperResourcePath $fresh
Assert-Equal (Test-Path -LiteralPath (Plugin-Path $fresh)) $false 'Fresh runtime removed by rollback'
Assert-Equal (Test-Path -LiteralPath (Join-Path $fresh 'Scripts/PsyReaSFX-WebView')) $false 'Fresh app restored to absent'

$external = New-Resource 'r-shared'
$externalHash = Set-ExternalRuntime $external
& $install -AllowUnverifiedRuntime -ReaperResourcePath $external
Assert-Equal (Get-SHA256 (Plugin-Path $external)) $externalHash 'External runtime preserved by default'
& $install -AllowUnverifiedRuntime -ReaperResourcePath $external -UseBundledRuntime
Assert-Equal (Get-SHA256 (Plugin-Path $external)) $runtimeLock.binary.sha256 'Explicit runtime replacement'
& $restore -ReaperResourcePath $external
Assert-Equal (Get-SHA256 (Plugin-Path $external)) $externalHash 'Previous shared runtime restored'

$locked = New-Resource 'r-locked'
$lockedHash = Set-ExternalRuntime $locked
$handle = [IO.File]::Open((Plugin-Path $locked), 'Open', 'Read', 'Read')
try { Expect-Failure { & $install -AllowUnverifiedRuntime -ReaperResourcePath $locked -UseBundledRuntime } 'Locked DLL replacement must fail' }
finally { $handle.Dispose() }
Assert-Equal (Get-SHA256 (Plugin-Path $locked)) $lockedHash 'Failed install preserved runtime'
Assert-Equal (Test-Path -LiteralPath (Join-Path $locked 'Scripts/PsyReaSFX-WebView')) $false 'Failed install rolled back application'

$concurrent = New-Resource 'r-concurrent'
$guard = Open-InstallerLock $concurrent
try { Expect-Failure { & $install -AllowUnverifiedRuntime -ReaperResourcePath $concurrent } 'Exclusive installer lock must reject concurrent install' }
finally { $guard.Dispose() }
Assert-Equal (Test-Path -LiteralPath (Join-Path $concurrent 'Scripts')) $false 'Concurrent install must not write app'

$recovery = New-Resource 'r-recovery'
$recoveryHash = Set-ExternalRuntime $recovery
& $install -AllowUnverifiedRuntime -ReaperResourcePath $recovery -UseBundledRuntime
$receiptFile = Get-ChildItem -LiteralPath (Join-Path $recovery 'Data/PsyReaSFX-WebView/transactions') -Filter receipt.json -Recurse | Select-Object -First 1
$receipt = Get-Content -LiteralPath $receiptFile.FullName -Raw | ConvertFrom-Json
$receipt.status = 'installing'
Write-Receipt $receiptFile.FullName $receipt
& $install -AllowUnverifiedRuntime -ReaperResourcePath $recovery
Assert-Equal (Get-SHA256 (Plugin-Path $recovery)) $recoveryHash 'Interrupted installation recovered before next install'

$changed = New-Resource 'r-updated'
Set-ExternalRuntime $changed | Out-Null
& $install -AllowUnverifiedRuntime -ReaperResourcePath $changed -UseBundledRuntime
$changedHash = Set-ExternalRuntime $changed 'externally-updated-runtime'
Expect-Failure { & $restore -ReaperResourcePath $changed } 'Rollback must protect subsequent external updates'
Assert-Equal (Get-SHA256 (Plugin-Path $changed)) $changedHash 'Subsequent runtime update preserved'

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
Expect-Failure { & $install -AllowUnverifiedRuntime -ReaperResourcePath $deep } 'Unsupported deep resource paths must fail preflight'
Assert-Equal (Test-Path -LiteralPath (Join-Path $deep 'Data')) $false 'Deep path preflight must not write transaction state'
Remove-Variable -Name PsyReaSFXTestReaperRunning -Scope Global
Write-Host 'WebView package verified: archive, hashes, licenses/source, fresh/repeat install, external preservation, replacement/rollback, locked DLL failure, concurrency, interrupted recovery, external-update protection, tamper/path rejection.'
