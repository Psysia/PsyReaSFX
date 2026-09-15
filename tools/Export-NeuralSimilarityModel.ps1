param(
  [string]$OutputDirectory = "assets/neural/mn04_as_scene_320_v1",
  [switch]$KeepWorkDirectory
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$outputPath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputDirectory))
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$workDirectory = [IO.Path]::GetFullPath((Join-Path $temporaryRoot ("PsyReaSFX-neural-export-" + [guid]::NewGuid().ToString("N"))))
if (-not $workDirectory.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw "Unsafe temporary work directory: $workDirectory"
}

$upstreamCommit = "738e57daca70f2762f84f1af481c46dd8b7ebfe5"
$weightsUrl = "https://github.com/fschmid56/EfficientAT/releases/download/v0.0.1/mn04_as_mAP_432.pt"
$weightsSha256 = "899a8c6217063f6941793102a2780b3dd788ab11fce468d9cf5f0577c453321c"

try {
  New-Item -ItemType Directory -Path $workDirectory | Out-Null
  $upstreamPath = Join-Path $workDirectory "EfficientAT_HEAR"
  git clone --filter=blob:none https://github.com/fschmid56/EfficientAT_HEAR.git $upstreamPath
  git -C $upstreamPath checkout --detach $upstreamCommit

  $weightsPath = Join-Path $workDirectory "mn04_as_mAP_432.pt"
  Invoke-WebRequest -Uri $weightsUrl -OutFile $weightsPath
  $actualWeightsHash = (Get-FileHash -LiteralPath $weightsPath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualWeightsHash -cne $weightsSha256) {
    throw "EfficientAT weight hash mismatch: $actualWeightsHash"
  }

  $venvPath = Join-Path $workDirectory "venv"
  python -m venv $venvPath
  $python = Join-Path $venvPath "Scripts/python.exe"
  & $python -m pip install --upgrade pip
  & $python -m pip install torch==2.11.0 torchaudio==2.11.0 torchvision==0.26.0 --index-url https://download.pytorch.org/whl/cpu
  & $python -m pip install onnx==1.22.0 onnxruntime==1.30.0
  & $python (Join-Path $PSScriptRoot "export_neural_similarity_model.py") `
    --upstream-root $upstreamPath `
    --weights $weightsPath `
    --output-dir $outputPath
}
finally {
  if ($KeepWorkDirectory) {
    Write-Host "Kept neural export work directory: $workDirectory"
  }
  elseif (Test-Path -LiteralPath $workDirectory) {
    $resolvedWork = [IO.Path]::GetFullPath($workDirectory)
    if (-not $resolvedWork.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Refusing to remove unsafe path: $resolvedWork"
    }
    Remove-Item -LiteralPath $resolvedWork -Recurse -Force
  }
}
