param(
    [string]$Lua = 'lua',
    [string]$FixtureDirectory = '',
    [string]$SidecarExecutable = '',
    [string]$ModelDirectory = ''
)
$ErrorActionPreference = 'Stop'
if (-not $FixtureDirectory) { $FixtureDirectory = Join-Path $env:TEMP ('PsyReaSFX-hidden-' + [guid]::NewGuid().ToString('N')) }
$fixture = [IO.Path]::GetFullPath($FixtureDirectory)
[IO.Directory]::CreateDirectory($fixture) | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
$probeSource = Join-Path $fixture 'console-probe.cs'
$probe = Join-Path $fixture 'console-probe.exe'
$resultPath = Join-Path $fixture 'probe-result.txt'
$launcher = Join-Path $fixture 'launch.lua'
$module = Join-Path $PSScriptRoot '../src/lua/43_neural_similarity.lua'
[IO.File]::WriteAllText($probeSource, @'
using System;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;
class Probe {
  [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
  static void Main(string[] args) {
    File.WriteAllLines(args[0], new[] {
      GetConsoleWindow().ToInt64().ToString(),
      Convert.ToBase64String(Encoding.UTF8.GetBytes(args[1]))
    });
  }
}
'@, $utf8)
[IO.File]::WriteAllText($launcher, @'
dofile(arg[1])
local payload = assert(io.open(arg[3], "rb"))
local arguments = neural_json_decode(payload:read("*a"))
payload:close()
local file = assert(io.open(arg[2], "wb"))
file:write(neural_windows_hidden_command(arguments))
file:close()
'@, $utf8)
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $compiler /nologo /target:exe "/out:$probe" $probeSource
if ($LASTEXITCODE -ne 0) { throw 'Console probe compilation failed.' }
function Invoke-HiddenFixture([string[]]$Arguments, [string]$ExpectedOutput) {
    $commandFile = Join-Path $fixture ('command-' + [guid]::NewGuid().ToString('N') + '.txt')
    # REAPER supplies UTF-8 Lua strings. Stock Windows lua.exe uses ANSI argv,
    # so load UTF-8 fixture data from disk instead of losing Unicode in argv.
    $argumentsFile = $commandFile + '.json'
    [IO.File]::WriteAllText($argumentsFile, (ConvertTo-Json -InputObject @($Arguments) -Compress), $utf8)
    & $Lua $launcher $module $commandFile $argumentsFile
    if ($LASTEXITCODE -ne 0) { throw 'Lua launcher generation failed.' }
    $command = [IO.File]::ReadAllText($commandFile)
    if ($command -notmatch '^powershell\.exe (-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand [A-Za-z0-9+/=]+)$') { throw 'Unexpected launcher command.' }
    $process = Start-Process powershell.exe -ArgumentList $Matches[1] -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not (Test-Path -LiteralPath $ExpectedOutput)) {
        if ([DateTime]::UtcNow -ge $deadline) { throw 'Hidden child did not produce its output.' }
        Start-Sleep -Milliseconds 100
    }
    if (-not $process.WaitForExit(5000)) { throw 'Launcher did not exit after spawning its child.' }
    if ($process.ExitCode -ne 0) { throw "Launcher exited with $($process.ExitCode)." }
}
# All metacharacters are argument data, including Unicode, embedded quotes and
# a trailing backslash. Neither PowerShell nor cmd may interpret this payload.
$argument = '声音 unicode %name% $(not-code) & | < > ^ ` "quoted" trailing\'
Invoke-HiddenFixture -Arguments @($probe, $resultPath, $argument) -ExpectedOutput $resultPath
$lines = [IO.File]::ReadAllLines($resultPath)
if ($lines[0] -cne '0') { throw "Child unexpectedly owns a console window: $($lines[0])" }
$actual = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($lines[1]))
if ($actual -cne $argument) { throw 'Hidden launcher corrupted its argument data.' }
if ($SidecarExecutable) {
    if (-not $ModelDirectory) { throw 'ModelDirectory is required for the optional installed-sidecar check.' }
    $capabilities = Join-Path $fixture 'installed-sidecar-capabilities.json'
    Invoke-HiddenFixture -Arguments @($SidecarExecutable, 'capabilities', $ModelDirectory, $capabilities) -ExpectedOutput $capabilities
    $data = Get-Content -LiteralPath $capabilities -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($data.schema -cne 'PsyReaSFX-Neural-Capabilities-v1' -or $data.protocolVersion -ne 1) { throw 'Installed sidecar handshake failed.' }
    Write-Host 'Installed console sidecar handshake passed through the hidden launcher.'
}
Write-Host 'Hidden console launch passed: no console window; Unicode and metacharacters preserved.'
