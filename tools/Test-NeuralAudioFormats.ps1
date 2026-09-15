param(
    [Parameter(Mandatory = $true)]
    [string]$SidecarPath,
    [Parameter(Mandatory = $true)]
    [string]$ModelDirectory,
    [Parameter(Mandatory = $true)]
    [string]$FixtureDirectory
)

$ErrorActionPreference = "Stop"
$sidecar = (Resolve-Path -LiteralPath $SidecarPath).Path
$model = (Resolve-Path -LiteralPath $ModelDirectory).Path
$fixture = [IO.Path]::GetFullPath($FixtureDirectory)
New-Item -ItemType Directory -Path $fixture -Force | Out-Null

$capabilitiesPath = Join-Path $fixture "capabilities.json"
& dotnet $sidecar capabilities $model $capabilitiesPath
if ($LASTEXITCODE -ne 0) { throw "Neural capabilities failed: $LASTEXITCODE" }
$capabilities = Get-Content -LiteralPath $capabilitiesPath -Raw | ConvertFrom-Json
$profile = $capabilities.profiles | Where-Object profile -EQ 'mn04_as_scene_320_v1'
if ($profile.decoderVersion -lt 1 -or $profile.supportedExtensions -notcontains 'wav') {
    throw "Neural decoder capabilities are incomplete."
}

$dotnet = (Get-Command dotnet).Source
$savedPath = $env:PATH
try {
    $env:PATH = Split-Path $dotnet
    $windowsOnlyPath = Join-Path $fixture "capabilities-windows-only.json"
    & $dotnet $sidecar capabilities $model $windowsOnlyPath
    if ($LASTEXITCODE -ne 0) { throw "Windows-only neural capabilities failed: $LASTEXITCODE" }
    $windowsOnly = Get-Content -LiteralPath $windowsOnlyPath -Raw | ConvertFrom-Json
    $windowsProfile = $windowsOnly.profiles | Where-Object profile -EQ 'mn04_as_scene_320_v1'
    if ($windowsProfile.ffmpegFallback -or
        $windowsProfile.supportedExtensions -contains 'ogg' -or
        $windowsProfile.supportedExtensions -notcontains 'flac') {
        throw "Windows-only decoder capabilities are inaccurate."
    }
}
finally {
    $env:PATH = $savedPath
}

$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($null -eq $ffmpeg) {
    Write-Output "FFmpeg is unavailable; built-in WAV resampling remains covered by sidecar self-test."
    exit 0
}

$source = Join-Path $model "chirp_impulse_1p5s.wav"
$formats = @(
    @{ Name = 'test-48000-pcm24.wav'; Codec = 'pcm_s24le'; Rate = 48000 },
    @{ Name = 'test-48000.flac'; Codec = 'flac'; Rate = 48000 },
    @{ Name = 'test-44100.mp3'; Codec = 'libmp3lame'; Rate = 44100 },
    @{ Name = 'test-48000.ogg'; Codec = 'libvorbis'; Rate = 48000 },
    @{ Name = 'test-48000.opus'; Codec = 'libopus'; Rate = 48000 },
    @{ Name = 'test-48000.wv'; Codec = 'wavpack'; Rate = 48000 },
    @{ Name = 'test-44100.aiff'; Codec = 'pcm_s24be'; Rate = 44100 },
    @{ Name = 'test-48000.caf'; Codec = 'pcm_s24le'; Rate = 48000 },
    @{ Name = 'test-48000.m4a'; Codec = 'aac'; Rate = 48000 }
)

foreach ($format in $formats) {
    $audioPath = Join-Path $fixture $format.Name
    & $ffmpeg.Source -v error -y -i $source -ar $format.Rate -ac 2 -c:a $format.Codec $audioPath
    if ($LASTEXITCODE -ne 0) { throw "Could not create fixture: $($format.Name)" }
    $resultPath = "$audioPath.embedding.json"
    & dotnet $sidecar embed $model $audioPath $resultPath
    if ($LASTEXITCODE -ne 0) { throw "Could not embed fixture: $($format.Name)" }
    $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    if ($result.schema -ne 'PsyReaSFX-Neural-Embedding-v1' -or
        $result.sampleRate -ne 32000 -or $result.samples -lt 47000 -or
        $result.embedding.Count -ne 320) {
        throw "Unexpected embedding result for $($format.Name): $($result | ConvertTo-Json -Compress)"
    }
}

Write-Output "Neural audio-format test passed: $($formats.Count) resampled formats."
