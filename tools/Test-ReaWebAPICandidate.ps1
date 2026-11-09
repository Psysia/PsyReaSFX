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
# Offline upstream fixtures exercise promotion rules without GitHub API availability.
$global:PsyReaSFXCandidateTest = @{ Lock = $lock; Cache = $CachePath; Corrupt = $false }
function Invoke-RestMethod($Uri, $Headers) {
    $fixture = $global:PsyReaSFXCandidateTest
    if ($Uri -match '/releases/tags/') {
        return [pscustomobject]@{ assets = @([pscustomobject]@{
            name = $fixture.Lock.archive.file
            browser_download_url = $fixture.Lock.archive.url
            digest = "sha256:$($fixture.Lock.archive.sha256)"
        }) }
    }
    if ($Uri -match '/commits/') { return [pscustomobject]@{ sha = $fixture.Lock.commit } }
    throw 'Unexpected metadata request.'
}
function Invoke-WebRequest($Uri, $OutFile, [switch]$UseBasicParsing) {
    $fixture = $global:PsyReaSFXCandidateTest
    $spec = if ($Uri -ceq $fixture.Lock.archive.url) { $fixture.Lock.archive } elseif ($Uri -ceq $fixture.Lock.source.url) { $fixture.Lock.source } else { throw 'Unexpected download URL.' }
    Copy-Item -LiteralPath (Join-Path $fixture.Cache $spec.file) -Destination $OutFile
    if ($fixture.Corrupt) { [IO.File]::AppendAllText($OutFile, 'corrupt') }
}
try {
    $tool = Join-Path $PSScriptRoot 'New-ReaWebAPICandidate.ps1'
    $output = Join-Path $FixtureDirectory 'candidate.lock.json'
    & $tool -Tag "v$($lock.version)" -OutputPath $output
    $candidate = Get-Content -LiteralPath $output -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($candidate.commit -cne $lock.commit -or $candidate.runtime_policy.validation_status -cne 'native_acceptance_pending') { throw 'Candidate metadata or acceptance state is incorrect.' }
    $failed = $false
    try { & $tool -Tag "v$($lock.version)" -OutputPath $activePath } catch { $failed = $true }
    if (-not $failed) { throw 'Candidate tool must reject active-lock output.' }
    $global:PsyReaSFXCandidateTest.Corrupt = $true
    $badOutput = Join-Path $FixtureDirectory 'corrupt.lock.json'
    $failed = $false
    try { & $tool -Tag "v$($lock.version)" -OutputPath $badOutput } catch { $failed = $true }
    if (-not $failed -or (Test-Path -LiteralPath $badOutput)) { throw 'Failed verification must not publish a candidate lock.' }
    if ((Get-FileHash -LiteralPath $activePath -Algorithm SHA256).Hash -cne $activeHash) { throw 'Candidate evaluation modified the active lock.' }
    Write-Host 'Candidate update verified offline: exact commit and digest, acceptance pending, active lock protected, corrupt download rejected before publication.'
}
finally { Remove-Variable -Name PsyReaSFXCandidateTest -Scope Global }
