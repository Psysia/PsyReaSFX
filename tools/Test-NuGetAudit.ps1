[CmdletBinding()]
param(
    [string[]]$Projects = @(
        'desktop/PsyReaSFX.Desktop/PsyReaSFX.Desktop.csproj',
        'neural/PsyReaSFX.NeuralSidecar/PsyReaSFX.NeuralSidecar.csproj'
    ),
    [string]$OutputDirectory = '',
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'

function Assert-CleanAudit($Report) {
    if ($Report.version -ne 1 -or @($Report.projects).Count -lt 1) {
        throw 'NuGet audit returned an incomplete report.'
    }
    if ($Report.errors -or $Report.problems -or ($Report.logs -and @($Report.logs | Where-Object { $_.level -ne 'Information' }).Count)) {
        throw 'NuGet audit could not verify every dependency.'
    }
    foreach ($project in $Report.projects) {
        if (-not $project.path -or $project.errors) { throw 'NuGet audit returned an invalid project.' }
        foreach ($framework in $project.frameworks) {
            foreach ($package in @($framework.topLevelPackages) + @($framework.transitivePackages)) {
                if ($package.vulnerabilities) { throw "Vulnerable dependency: $($package.id)" }
            }
        }
    }
}

if ($SelfTest) {
    Assert-CleanAudit ('{"version":1,"projects":[{"path":"fixture.csproj"}]}' | ConvertFrom-Json)
    foreach ($invalid in @(
        '{"version":1,"projects":[{"path":"fixture.csproj","frameworks":[{"transitivePackages":[{"id":"fixture","vulnerabilities":[{"severity":"High"}]}]}]}]}',
        '{"version":1,"projects":[]}',
        '{"version":1,"projects":[{"path":"fixture.csproj"}],"logs":[{"level":"Warning","message":"Feed unavailable"}]}'
    )) {
        $rejected = $false
        try { Assert-CleanAudit ($invalid | ConvertFrom-Json) } catch { $rejected = $true }
        if (-not $rejected) { throw 'Dependency audit accepted an unverified or vulnerable fixture.' }
    }
    Write-Output 'NuGet audit regression passed: transitive vulnerabilities and unavailable feeds fail closed.'
    return
}

if ($OutputDirectory) { [IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($OutputDirectory)) | Out-Null }
foreach ($project in $Projects) {
    $lines = & dotnet list $project package --vulnerable --include-transitive --format json --output-version 1 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Dependency audit command failed for $project`: $($lines -join [Environment]::NewLine)" }
    $json = $lines -join [Environment]::NewLine
    $report = $json | ConvertFrom-Json
    Assert-CleanAudit $report
    if ($OutputDirectory) {
        $name = [IO.Path]::GetFileNameWithoutExtension($project) + '.nuget-audit.json'
        [IO.File]::WriteAllText((Join-Path $OutputDirectory $name), $json, [Text.UTF8Encoding]::new($false))
    }
    Write-Output "Dependency vulnerability audit passed: $project"
}
