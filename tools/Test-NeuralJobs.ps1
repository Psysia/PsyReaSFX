param(
    [Parameter(Mandatory = $true)]
    [string]$SidecarPath,
    [Parameter(Mandatory = $true)]
    [string]$ModelDirectory,
    [Parameter(Mandatory = $true)]
    [string]$FixtureDirectory
)

$ErrorActionPreference = 'Stop'
$sidecar = (Resolve-Path -LiteralPath $SidecarPath).Path
$model = (Resolve-Path -LiteralPath $ModelDirectory).Path
$fixture = [IO.Path]::GetFullPath($FixtureDirectory)
New-Item -ItemType Directory -Path $fixture -Force | Out-Null

$signatures = @(
    '0000000000000001',
    '0000000000000002',
    '0000000000000003'
)
$audioNames = @(
    'chirp_impulse_1p5s.wav',
    'modulated_texture_3s.wav',
    'evolving_scene_12s.wav'
)
$cachePath = Join-Path $fixture 'embeddings.bin'
$assetsPath = Join-Path $fixture 'assets.tsv'
$buildRequestPath = Join-Path $fixture 'build.request.json'
$buildStatusPath = Join-Path $fixture 'build.status.json'
$buildResultPath = Join-Path $fixture 'build.result.json'

$assetLines = for ($index = 0; $index -lt $audioNames.Count; $index++) {
    $audioPath = (Resolve-Path -LiteralPath (Join-Path $model $audioNames[$index])).Path
    $info = Get-Item -LiteralPath $audioPath
    $encodedPath = ConvertTo-Json $audioPath -Compress
    "$($signatures[$index])`t$($info.Length)`t$($info.LastWriteTimeUtc.Ticks)`t$encodedPath"
}
$assetLines | Set-Content -LiteralPath $assetsPath -Encoding utf8

@{
    schema = 'PsyReaSFX-Neural-Job-v1'
    requestId = 'ci-build'
    operation = 'build-cache'
    cachePath = $cachePath
    statusPath = $buildStatusPath
    resultPath = $buildResultPath
    cancelPath = (Join-Path $fixture 'build.cancel')
    assetsFile = $assetsPath
} | ConvertTo-Json | Set-Content -LiteralPath $buildRequestPath -Encoding utf8

& dotnet $sidecar run-job $model $buildRequestPath
if ($LASTEXITCODE -ne 0) { throw "Neural build-cache job failed: $LASTEXITCODE" }
$build = Get-Content -LiteralPath $buildResultPath -Raw | ConvertFrom-Json
if ($build.schema -ne 'PsyReaSFX-Neural-Job-Result-v1' -or
    $build.requested -ne 3 -or $build.written -ne 3 -or
    $build.embedded -ne 3 -or $build.reused -ne 0 -or $build.failed -ne 0 -or
    $build.cancelled) {
    throw "Unexpected neural build-cache result: $($build | ConvertTo-Json -Compress)"
}
if ((Get-FileHash -LiteralPath $cachePath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $build.cacheSha256) {
    throw 'Neural cache hash does not match the build result.'
}

$offlineAssetsPath = Join-Path $fixture 'offline-assets.tsv'
$offlineLines = for ($index = 0; $index -lt $assetLines.Count; $index++) {
    $fields = $assetLines[$index].Split("`t", 4)
    $offlinePath = ConvertTo-Json (Join-Path $fixture "offline-$index.wav") -Compress
    "$($fields[0])`t$($fields[1])`t$($fields[2])`t$offlinePath"
}
$offlineLines | Set-Content -LiteralPath $offlineAssetsPath -Encoding utf8
$reuseRequestPath = Join-Path $fixture 'reuse.request.json'
$reuseResultPath = Join-Path $fixture 'reuse.result.json'
@{
    schema = 'PsyReaSFX-Neural-Job-v1'
    requestId = 'ci-reuse'
    operation = 'build-cache'
    cachePath = $cachePath
    statusPath = (Join-Path $fixture 'reuse.status.json')
    resultPath = $reuseResultPath
    cancelPath = (Join-Path $fixture 'reuse.cancel')
    assetsFile = $offlineAssetsPath
} | ConvertTo-Json | Set-Content -LiteralPath $reuseRequestPath -Encoding utf8

& dotnet $sidecar run-job $model $reuseRequestPath
if ($LASTEXITCODE -ne 0) { throw "Neural reuse job failed: $LASTEXITCODE" }
$reuse = Get-Content -LiteralPath $reuseResultPath -Raw | ConvertFrom-Json
if ($reuse.written -ne 3 -or $reuse.reused -ne 3 -or $reuse.embedded -ne 0 -or $reuse.failed -ne 0) {
    throw "Unexpected neural reuse result: $($reuse | ConvertTo-Json -Compress)"
}

$cacheBytes = [IO.File]::ReadAllBytes($cachePath)
[IO.File]::WriteAllBytes($cachePath, $cacheBytes[0..($cacheBytes.Length - 2)])
$repairRequestPath = Join-Path $fixture 'repair.request.json'
$repairResultPath = Join-Path $fixture 'repair.result.json'
@{
    schema = 'PsyReaSFX-Neural-Job-v1'
    requestId = 'ci-repair'
    operation = 'build-cache'
    cachePath = $cachePath
    statusPath = (Join-Path $fixture 'repair.status.json')
    resultPath = $repairResultPath
    cancelPath = (Join-Path $fixture 'repair.cancel')
    assetsFile = $assetsPath
} | ConvertTo-Json | Set-Content -LiteralPath $repairRequestPath -Encoding utf8

& dotnet $sidecar run-job $model $repairRequestPath
if ($LASTEXITCODE -ne 0) { throw "Neural cache repair job failed: $LASTEXITCODE" }
$repair = Get-Content -LiteralPath $repairResultPath -Raw | ConvertFrom-Json
if ($repair.written -ne 3 -or $repair.embedded -ne 3 -or $repair.reused -ne 0 -or
    $repair.failed -ne 0 -or [string]::IsNullOrWhiteSpace($repair.rejectedCacheError)) {
    throw "Unexpected neural cache repair result: $($repair | ConvertTo-Json -Compress)"
}

$candidatesPath = Join-Path $fixture 'candidates.txt'
$signatures | Set-Content -LiteralPath $candidatesPath -Encoding utf8
$queryRequestPath = Join-Path $fixture 'query.request.json'
$queryResultPath = Join-Path $fixture 'query.result.json'
@{
    schema = 'PsyReaSFX-Neural-Job-v1'
    requestId = 'ci-query'
    operation = 'query'
    cachePath = $cachePath
    statusPath = (Join-Path $fixture 'query.status.json')
    resultPath = $queryResultPath
    cancelPath = (Join-Path $fixture 'query.cancel')
    referenceSignature = $signatures[0]
    candidateSignaturesFile = $candidatesPath
    topK = 2
} | ConvertTo-Json | Set-Content -LiteralPath $queryRequestPath -Encoding utf8

& dotnet $sidecar run-job $model $queryRequestPath
if ($LASTEXITCODE -ne 0) { throw "Neural query job failed: $LASTEXITCODE" }
$query = Get-Content -LiteralPath $queryResultPath -Raw | ConvertFrom-Json
if ($query.cancelled -or $query.matches.Count -ne 2 -or
    $query.matches[0].signature -eq $signatures[0] -or
    $query.matches[1].signature -eq $signatures[0] -or
    $query.matches[0].score -lt $query.matches[1].score) {
    throw "Unexpected neural query result: $($query | ConvertTo-Json -Depth 5 -Compress)"
}

Write-Output "Neural job smoke test passed: embedded=$($build.embedded), reused=$($reuse.reused), repaired=$($repair.embedded), matches=$($query.matches.Count)"
