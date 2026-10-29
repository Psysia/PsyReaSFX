# Compatibility entry point for existing beta-release commands.
param(
    [string]$Version = "0.9.0-beta8.7",
    [string]$OutputDirectory = ""
)
$ErrorActionPreference = "Stop"
if ($Version -notmatch '^\d+\.\d+\.\d+-beta\d+(?:\.\d+)?$') { throw "Invalid beta version: $Version" }
& (Join-Path $PSScriptRoot "Build-Release.ps1") -Version $Version -OutputDirectory $OutputDirectory
