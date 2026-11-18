$ErrorActionPreference = 'Stop'

function Get-ChildPath([string]$Root, [string]$Relative) {
    if ([IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)' -or $Relative.Contains(':')) {
        throw "Invalid package path: $Relative"
    }
    $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $path = [IO.Path]::GetFullPath((Join-Path $rootPath $Relative))
    if (-not $path.StartsWith($rootPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes its root: $Relative"
    }
    return $path
}

function Get-SHA256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-AuditionMessage([string]$English, [string]$Chinese) {
    if ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'zh') { return $Chinese }
    return $English
}

function Get-AuditionAction([string]$Plugin, [string]$Hash) {
    if (-not (Test-Path -LiteralPath $Plugin)) { return 'install' }
    if ((Get-SHA256 $Plugin) -ceq $Hash) { return 'reuse' }
    throw (Get-AuditionMessage 'The PRS audition component differs from this package. Move the existing file aside and retry.' '现有 PRS 试听组件与安装包不同。请先将该文件移至其他目录，再重试。')
}

function Read-Package([string]$Root) {
    $manifest = Get-Content -LiteralPath (Join-Path $Root 'package-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.schema -cne 'PsyReaSFX-WebView-Package-v1' -or $manifest.id -notmatch '^[a-f0-9]{32}$') {
        throw 'Unsupported package manifest.'
    }
    $seen = @{}
    foreach ($file in $manifest.files) {
        $path = Get-ChildPath $Root $file.path
        if ($seen.ContainsKey($path) -or $file.sha256 -notmatch '^[a-f0-9]{64}$') { throw 'Invalid manifest entry.' }
        $seen[$path] = $true
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-SHA256 $path) -cne $file.sha256) {
            throw "Package checksum mismatch: $($file.path)"
        }
    }
    foreach ($required in @(
        'PsyReaSFX.lua', 'web/index.html', 'web/app.json', 'web/soundminer.js', 'runtime-lock.json',
        'Install-BundledRuntime.ps1', 'runtime-setup.lua', 'bundled-runtime.json',
        'runtime/reawebapi/reaper_reawebapi-x64.dll',
        'runtime/audition/reaper_prs_audition.dll', 'licenses/audition/dr_libs.txt',
        'Install-PsyReaSFX.ps1', 'Restore-PsyReaSFX.ps1', 'installer-common.ps1',
        'assets/brand/psyreasfx-icon.png', 'assets/ucs/ucs-8.2.1.tsv',
        'assets/neural/mn04_as_scene_320_v1/manifest-v1.json', 'LICENSE'
    )) {
        if (-not $seen.ContainsKey((Get-ChildPath $Root $required))) { throw "Missing packaged file: $required" }
    }
    $runtime = Get-Content -LiteralPath (Join-Path $Root 'runtime-lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($runtime.binary.sha256 -cne (Get-SHA256 (Join-Path $Root 'runtime/reawebapi/reaper_reawebapi-x64.dll'))) {
        throw 'Runtime lock differs from packaged binary.'
    }
    if ($runtime.source.file -cne 'ReaWebAPI-source.zip' -or
        $runtime.source.sha256 -notmatch '^[a-f0-9]{64}$' -or
        -not $seen.ContainsKey((Get-ChildPath $Root ('sources/' + $runtime.source.file))) -or
        $runtime.source.sha256 -cne (Get-SHA256 (Join-Path $Root ('sources/' + $runtime.source.file)))) {
        throw 'Runtime lock differs from packaged matching source.'
    }
    return $manifest
}

function Get-ResourcePath([string]$Path, [switch]$Choose) {
    if ($Choose -or -not $Path) {
        Add-Type -AssemblyName System.Windows.Forms
        $picker = New-Object System.Windows.Forms.FolderBrowserDialog
        $picker.Description = 'Select the REAPER resource folder containing reaper.ini (Options > Show REAPER resource path).'
        $picker.SelectedPath = if ($Path) { $Path } else { Join-Path $env:APPDATA 'REAPER' }
        try {
            if ($picker.ShowDialog() -ne 'OK') { throw 'Folder selection cancelled.' }
            $Path = $picker.SelectedPath
        }
        finally { $picker.Dispose() }
    }
    $Path = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    if (-not (Test-Path -LiteralPath (Join-Path $Path 'reaper.ini') -PathType Leaf)) { throw 'Selected folder does not contain reaper.ini.' }
    return $Path
}

function Assert-ReaperClosed {
    if (Get-Process -Name reaper -ErrorAction SilentlyContinue) { throw 'Close REAPER before installing or restoring the native extension.' }
}

function Assert-RuntimePolicy([string]$Action, $Policy, [string]$BinarySha256 = '', [switch]$AllowUnverified) {
    # Distribution approval is tied to the exact packaged binary, independently
    # of native-acceptance evidence. Read-Package verifies its lock and payload.
    $stableBaseline = $Policy.distribution_channel -ceq 'stable' -and
        $Policy.distribution_binary_sha256 -cmatch '^[a-f0-9]{64}$' -and
        $Policy.distribution_binary_sha256 -ceq $BinarySha256
    if ($Action -in @('install', 'replace') -and $Policy.validation_status -cne 'native_accepted' -and
        -not $stableBaseline -and -not $AllowUnverified) {
        throw 'The bundled runtime has not passed native REAPER acceptance. Candidate testing requires an isolated REAPER profile and the explicit -AllowUnverifiedRuntime option.'
    }
}

function Read-BundledRuntimePolicy([string]$Root, $Runtime) {
    $path = Join-Path $Root 'bundled-runtime.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    $policy = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $app = Get-Content -LiteralPath (Join-Path $Root 'web/app.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($policy.schema -cne 'PsyReaSFX-Bundled-Runtime-v1' -or $policy.app_version -cne $app.version -or
        $policy.binary_sha256 -cne $Runtime.binary.sha256 -or $policy.source_sha256 -cne $Runtime.source.sha256 -or
        $policy.binary_sha256 -cnotmatch '^[a-f0-9]{64}$' -or $policy.source_sha256 -cnotmatch '^[a-f0-9]{64}$') { return $null }
    foreach ($hash in $policy.replace_hashes) {
        if ($hash -cnotmatch '^[a-f0-9]{64}$') { throw 'Invalid bundled runtime predecessor hash.' }
    }
    return $policy
}

function Get-RuntimeAction([string]$InstalledHash, [string]$BundledHash, $BundledPolicy, [switch]$Replace) {
    if (-not $InstalledHash) { return 'install' }
    if ($InstalledHash -ceq $BundledHash) { return 'reuse' }
    if ($Replace -or ($BundledPolicy -and $InstalledHash -cin $BundledPolicy.replace_hashes)) { return 'replace' }
    return 'preserve-external'
}

function Write-Receipt([string]$Path, $Receipt) {
    $temporary = "$Path.tmp"
    [IO.File]::WriteAllText($temporary, ($Receipt | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temporary, $Path, [NullString]::Value) }
    else { [IO.File]::Move($temporary, $Path) }
}

function Open-InstallerLock([string]$Resource) {
    $directory = Get-ChildPath $Resource 'Data/PsyReaSFX-WebView'
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    try { return [IO.File]::Open((Join-Path $directory 'installer.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { throw 'Another PsyReaSFX install or restore is running.' }
}

function Restore-Transaction([string]$Resource, [string]$Id) {
    if ($Id -notmatch '^[a-f0-9]{32}$') { throw 'Invalid transaction ID.' }
    $transaction = Get-ChildPath $Resource "Data/PsyReaSFX-WebView/transactions/$Id"
    $receiptPath = Join-Path $transaction 'receipt.json'
    $receipt = Get-Content -LiteralPath $receiptPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($receipt.schema -cne 'PsyReaSFX-WebView-Install-v1' -or $receipt.id -cne $Id) { throw 'Invalid transaction receipt.' }
    if ($receipt.status -eq 'restored') { return }
    $app = Get-ChildPath $Resource 'Scripts/PsyReaSFX-WebView'
    $previousApp = Get-ChildPath $Resource "Data/PsyReaSFX-WebView/transactions/$Id/previous-app"
    $retainedApp = Get-ChildPath $Resource "Data/PsyReaSFX-WebView/transactions/$Id/restored-app"
    $plugin = Get-ChildPath $Resource 'UserPlugins/reaper_reawebapi-x64.dll'
    $audition = Get-ChildPath $Resource 'UserPlugins/reaper_prs_audition.dll'
    $removeAudition = $receipt.auditionAction -eq 'install' -and (Test-Path -LiteralPath $audition)
    if ($removeAudition -and (Get-SHA256 $audition) -cne $receipt.auditionHash) {
        throw (Get-AuditionMessage 'The PRS audition component changed after installation. Restore its installed version before rollback.' '安装后的 PRS 试听组件已更改。请还原安装时的组件后再回滚。')
    }
    if (((Test-Path -LiteralPath $previousApp) -or -not $receipt.appExisted) -and (Test-Path -LiteralPath $app)) {
        $installed = Get-Content -LiteralPath (Join-Path $app 'package-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $installedTransaction = Get-Content -LiteralPath (Join-Path $app '.install-transaction') -Raw
        if ($installed.id -cne $receipt.packageId -or $installedTransaction -cne $Id) { throw 'Application changed after this transaction. Restore the most recent installation first.' }
    }
    if ($receipt.runtimeAction -in @('install', 'replace')) {
        $current = if (Test-Path -LiteralPath $plugin) { Get-SHA256 $plugin } else { '' }
        if ($current -ne $receipt.installedRuntimeHash -and $current -ne $receipt.previousRuntimeHash) {
            throw 'Runtime changed after this transaction. Restore is paused to preserve that external change.'
        }
        if ($current -eq $receipt.installedRuntimeHash) {
            if ($receipt.previousRuntimeHash) {
                $backup = Join-Path $transaction 'previous-runtime.dll'
                if ((Get-SHA256 $backup) -cne $receipt.previousRuntimeHash) { throw 'Runtime backup checksum mismatch.' }
                $staged = Get-ChildPath $Resource "UserPlugins/.PsyReaSFX-restore-$Id.dll"
                Copy-Item -LiteralPath $backup -Destination $staged -Force
                [IO.File]::Replace($staged, $plugin, [NullString]::Value)
            }
            else { Remove-Item -LiteralPath $plugin }
        }
    }
    if ($removeAudition) { Remove-Item -LiteralPath $audition }
    if ((Test-Path -LiteralPath $previousApp) -or -not $receipt.appExisted) {
        if (Test-Path -LiteralPath $app) {
            [IO.Directory]::Move($app, $retainedApp)
        }
        if (Test-Path -LiteralPath $previousApp) { [IO.Directory]::Move($previousApp, $app) }
    }
    $receipt.status = 'restored'
    Write-Receipt $receiptPath $receipt
}
