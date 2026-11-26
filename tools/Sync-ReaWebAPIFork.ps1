[CmdletBinding()]
param(
    [switch]$ReadOnly,
    [ValidateRange(0, 1800)][int]$WaitSeconds = 600
)
$ErrorActionPreference = 'Stop'
$headers = @{ 'User-Agent' = 'PsyReaSFX-runtime-sync'; Accept = 'application/vnd.github+json' }
if ($env:GH_TOKEN) { $headers.Authorization = "Bearer $env:GH_TOKEN" }
elseif ($env:GITHUB_TOKEN) { $headers.Authorization = "Bearer $env:GITHUB_TOKEN" }
$githubCli = Get-Command gh -ErrorAction SilentlyContinue
function Get-Metadata([string]$Path, [switch]$Optional) {
    # A local preflight uses the same signed-in account for reads and writes.
    # CI can continue to use its explicit read-only token.
    if ($githubCli -and -not $headers.Authorization) {
        $response = & gh api --method GET "repos/$Path" 2>&1
        $message = $response -join [Environment]::NewLine
        if ($LASTEXITCODE -eq 0) { return $message | ConvertFrom-Json }
        if ($Optional -and $message -match '\(HTTP 404\)') { return $null }
        throw "Could not read GitHub metadata for $Path. Check gh auth status. / 无法读取 GitHub 元数据，请检查登录状态。 $message"
    }
    try { return Invoke-RestMethod -Uri "https://api.github.com/repos/$Path" -Headers $headers }
    catch {
        if ($Optional -and $_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) { return $null }
        throw
    }
}
$upstream = Get-Metadata 'zaibuyidao/ReaWebAPI/releases/latest'
$tag = [string]$upstream.tag_name
if ($tag -notmatch '^v\d+(\.\d+){2,3}$' -or $upstream.draft) { throw 'Unexpected upstream release.' }
$commit = (Get-Metadata "zaibuyidao/ReaWebAPI/commits/$tag").sha
$sourceHead = (Get-Metadata 'zaibuyidao/ReaWebAPI/commits/main').sha
if ($commit -notmatch '^[a-f0-9]{40}$' -or $sourceHead -notmatch '^[a-f0-9]{40}$') { throw 'Invalid upstream source commit.' }
function Test-MirrorReady {
    $mirror = Get-Metadata "Psysia/ReaWebAPI/releases/tags/$tag" -Optional
    if (-not $mirror -or $mirror.draft) { return $false }
    foreach ($name in @("ReaWebAPI-windows-x64-$tag.zip", 'reaper_reawebapi-x64.dll')) {
        $original = @($upstream.assets | Where-Object name -CEQ $name)
        $copied = @($mirror.assets | Where-Object name -CEQ $name)
        if ($original.Count -ne 1 -or $original[0].digest -notmatch '^sha256:[a-f0-9]{64}$') { throw "Upstream asset is not ready: $name" }
        if ($copied.Count -ne 1 -or $copied[0].digest -cne $original[0].digest) { throw "Published fork asset differs from upstream: $name" }
    }
    foreach ($name in @('ReaWebAPI-source.zip', 'mirror-manifest.json')) {
        if (@($mirror.assets | Where-Object name -CEQ $name).Count -ne 1) { throw "Published mirror is incomplete: $name" }
    }
    if ((Get-Metadata "Psysia/ReaWebAPI/commits/$tag").sha -cne $commit) { throw 'Fork tag does not match upstream.' }
    $forkHead = (Get-Metadata 'Psysia/ReaWebAPI/commits/main').sha
    if ($forkHead -ceq $sourceHead) { return $true }
    # The author can publish another source commit while the sync job is queued.
    return $forkHead -ceq (Get-Metadata 'zaibuyidao/ReaWebAPI/commits/main').sha
}
if (Test-MirrorReady) {
    Write-Host "Fork is current: $tag ($commit)."
    return $tag
}
if (-not $ReadOnly) {
    if (-not $githubCli) { throw 'Install GitHub CLI and sign in with access to the fork. / 请安装 GitHub CLI 并登录有 fork 权限的账号。' }
    $forkHead = (Get-Metadata 'Psysia/ReaWebAPI/commits/main').sha
    if ($forkHead -notmatch '^[a-f0-9]{40}$') { throw 'Invalid fork source commit.' }
    if ($forkHead -cne $sourceHead) {
        $comparison = Get-Metadata "Psysia/ReaWebAPI/compare/${forkHead}...zaibuyidao:${sourceHead}"
        if ($comparison.status -cne 'ahead' -or $comparison.behind_by -ne 0 -or
            $comparison.merge_base_commit.sha -cne $forkHead) {
            throw 'Fork main has diverged. Review the commits before synchronizing. / fork main 已分叉，请核对提交。'
        }
        $updated = & gh api --method PATCH repos/Psysia/ReaWebAPI/git/refs/heads/main -f "sha=$sourceHead" -F force=false --jq '.object.sha'
        if ($LASTEXITCODE -ne 0 -or $updated -cne $sourceHead) {
            throw 'Could not fast-forward fork main with the signed-in GitHub account. / 当前 GitHub 账号无法快进 fork main。'
        }
        if (Test-MirrorReady) { Write-Host "Fork synchronized: $tag ($commit)."; return $tag }
    }
    $dispatch = & gh workflow run sync-upstream.yml --repo Psysia/ReaWebAPI --ref psyreasfx -f "tag=$tag" -f 'publish_only=true'
    if ($LASTEXITCODE -ne 0) { throw 'Could not request the verified tag mirror. / 无法请求镜像发布。' }
    Write-Host "Requested fork sync for $tag. $dispatch"
}
else { Write-Host "Waiting for the fork scheduled sync of $tag (read-only CI credential)." }
$deadline = [DateTime]::UtcNow.AddSeconds($WaitSeconds)
while ([DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Seconds ([Math]::Min(15, [Math]::Max(1, [int]($deadline - [DateTime]::UtcNow).TotalSeconds)))
    if (Test-MirrorReady) { Write-Host "Fork synchronized: $tag ($commit)."; return $tag }
}
throw "Fork sync has not completed. Inspect https://github.com/Psysia/ReaWebAPI/actions/workflows/sync-upstream.yml and retry. No older runtime was substituted for $tag."
