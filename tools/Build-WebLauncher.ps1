param([string]$Version = '', [string]$OutputPath = '')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $Version) { $Version = (Get-Content (Join-Path $repoRoot 'src/web/app.json') -Raw | ConvertFrom-Json).version }
if ($Version -notmatch '^[0-9A-Za-z.\-]+$') { throw 'Invalid launcher version.' }
if (-not $OutputPath) { $OutputPath = Join-Path $repoRoot 'PsyReaSFX_Launcher.lua' }
$template = [IO.File]::ReadAllText((Join-Path $repoRoot 'src/launcher/PsyReaSFX.lua'))
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath), $template.Replace('@VERSION@', $Version).Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false))
Write-Host "Built WebView launcher: $OutputPath"
