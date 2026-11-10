[CmdletBinding()]
param([string]$CachePath = '', [string]$FixtureDirectory = '')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$activePath = Join-Path $repoRoot 'dependencies/reawebapi/windows-x64.lock.json'
$activeHash = (Get-FileHash -LiteralPath $activePath -Algorithm SHA256).Hash
$lock = Get-Content -LiteralPath $activePath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $CachePath) { $CachePath = Join-Path $env:LOCALAPPDATA "PsyReaSFX/build-cache/reawebapi/$($lock.version)" }
if (-not $FixtureDirectory) { $FixtureDirectory = Join-Path $env:TEMP "PsyReaSFX-candidate-test-$([guid]::NewGuid().ToString('N'))" }
if (Test-Path -LiteralPath $FixtureDirectory) { throw 'Choose a new candidate fixture directory.' }
[IO.Directory]::CreateDirectory($FixtureDirectory) | Out-Null
$prefix = "https://github.com/Psysia/ReaWebAPI/releases/download/v$($lock.version)/"
$manifest = [ordered]@{
    schema = 'PsyReaSFX-ReaWebAPI-Mirror-v1'; repository = 'Psysia/ReaWebAPI'; upstream = 'zaibuyidao/ReaWebAPI'
    modified = $false; tag = "v$($lock.version)"; commit = $lock.commit
    contracts = @{ protocol = 1; runtime = 2; web = 1; max_message_bytes = 1048576 }
    files = @{ $lock.archive.file = $lock.archive.sha256; $lock.source.file = $lock.source.sha256; $lock.binary.file = $lock.binary.sha256 }
}
$global:PsyReaSFXCandidateTest = @{
    Lock = $lock; Cache = $CachePath; Prefix = $prefix; Manifest = $manifest
    ManifestPath = (Join-Path $FixtureDirectory 'mirror-manifest.json')
    Corrupt = $false; BadUrl = $false; BundleDownloads = 0
}
function Invoke-RestMethod($Uri, $Headers) {
    $f = $global:PsyReaSFXCandidateTest
    if ($Uri -cnotmatch '^https://api.github.com/repos/Psysia/ReaWebAPI/') { throw 'Candidate must use the owned fork.' }
    if ($Uri -match '/releases/(tags/[^/]+|latest)$') {
        [IO.File]::WriteAllText($f.ManifestPath, ($f.Manifest | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
        $assets = @($f.Lock.archive, $f.Lock.source, $f.Lock.binary, @{
            file = 'mirror-manifest.json'; sha256 = (Get-FileHash -LiteralPath $f.ManifestPath).Hash.ToLowerInvariant()
        }) | ForEach-Object { [pscustomobject]@{ name = $_.file; digest = "sha256:$($_.sha256)"; browser_download_url = $f.Prefix + $_.file } }
        if ($f.BadUrl) { $assets[0].browser_download_url = 'https://example.com/runtime.zip' }
        return [pscustomobject]@{ tag_name = "v$($f.Lock.version)"; draft = $false; assets = $assets }
    }
    if ($Uri -match '/commits/') { return [pscustomobject]@{ sha = $f.Lock.commit } }
    throw 'Unexpected metadata request.'
}
function Invoke-WebRequest($Uri, $OutFile, [switch]$UseBasicParsing) {
    $f = $global:PsyReaSFXCandidateTest
    if ($Uri -ceq ($f.Prefix + 'mirror-manifest.json')) { Copy-Item -LiteralPath $f.ManifestPath -Destination $OutFile; return }
    $spec = if ($Uri -ceq $f.Lock.archive.url) { $f.BundleDownloads++; $f.Lock.archive } elseif ($Uri -ceq $f.Lock.source.url) { $f.Lock.source } else { throw 'Unexpected download URL.' }
    Copy-Item -LiteralPath (Join-Path $f.Cache $spec.file) -Destination $OutFile
    if ($f.Corrupt) { [IO.File]::AppendAllText($OutFile, 'corrupt') }
}
function Assert-Rejected([string]$Name, [string]$Expected, [string]$Output = '') {
    if (-not $Output) { $Output = Join-Path $FixtureDirectory "$Name.lock.json" }
    $caught = $false
    try { & $tool -Tag latest -OutputPath $Output -CachePath (Join-Path $FixtureDirectory "$Name-cache") }
    catch { if ($_.Exception.Message -notlike "*$Expected*") { throw }; $caught = $true }
    if (-not $caught) { throw "Expected rejection: $Name" }
    if ($Output -ine $activePath -and (Test-Path -LiteralPath $Output)) { throw "Invalid candidate was published: $Name" }
}
try {
    $tool = Join-Path $PSScriptRoot 'New-ReaWebAPICandidate.ps1'
    $output = Join-Path $FixtureDirectory 'candidate.lock.json'
    $candidateCache = Join-Path $FixtureDirectory 'candidate-cache'
    & $tool -Tag latest -OutputPath $output -CachePath $candidateCache
    $candidate = Get-Content -LiteralPath $output -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($candidate.commit -cne $lock.commit -or $candidate.repository -cne 'https://github.com/Psysia/ReaWebAPI' -or
        $candidate.runtime_policy.validation_status -cne 'native_acceptance_pending') { throw 'Candidate metadata or acceptance state is incorrect.' }
    & $tool -Tag "v$($lock.version)" -OutputPath (Join-Path $FixtureDirectory 'repeat.lock.json') -CachePath $candidateCache
    if ($global:PsyReaSFXCandidateTest.BundleDownloads -ne 1) { throw 'Repeated evaluation should reuse the verified archive.' }
    Assert-Rejected 'active' 'separate from the active' $activePath
    $global:PsyReaSFXCandidateTest.Corrupt = $true
    Assert-Rejected 'corrupt' 'digest mismatch'
    $global:PsyReaSFXCandidateTest.Corrupt = $false
    $global:PsyReaSFXCandidateTest.BadUrl = $true
    Assert-Rejected 'foreign-url' 'Unexpected mirror download URL'
    $global:PsyReaSFXCandidateTest.BadUrl = $false
    $manifest.contracts.runtime = 99
    Assert-Rejected 'contract' 'contracts are incompatible'
    $manifest.contracts.runtime = 2
    $manifest.contracts.max_message_bytes = 100
    Assert-Rejected 'capacity' 'contracts are incompatible'
    $manifest.contracts.max_message_bytes = 1048576
    $manifest.commit = '0' * 40
    Assert-Rejected 'commit' 'provenance does not match'
    $manifest.commit = $lock.commit
    $manifest.files[$lock.binary.file] = '0' * 64
    Assert-Rejected 'manifest-hash' 'manifest digest mismatch'
    if ((Get-FileHash -LiteralPath $activePath -Algorithm SHA256).Hash -cne $activeHash) { throw 'Candidate evaluation modified the active lock.' }
    Write-Host 'Candidate verified offline: latest/pinned fork releases, cache reuse, provenance, contracts/capacity, hash failures and active-lock protection.'
}
finally { Remove-Variable -Name PsyReaSFXCandidateTest -Scope Global }
