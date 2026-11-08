# 7-ZSTar build script (nmake driver)
# Usage:
#   pwsh build\Build.ps1                       # build all targets, x64
#   pwsh build\Build.ps1 -Platform arm64       # cross-build arm64
#   pwsh build\Build.ps1 -Targets Alone7z      # build one bundle (name suffix match)
#   pwsh build\Build.ps1 -Clean                # remove per-target output dirs first
# Requires: VS2022 Build Tools with MSVC v143 (x64/x86; arm64 needs the ARM64 component).
# Output binaries land in <target-dir>\<Platform>\ (e.g. CPP\7zip\UI\Console\x64\7z.exe).

[CmdletBinding()]
param(
    [ValidateSet('x64', 'x86', 'arm64')]
    [string]$Platform = 'x64',

    # Empty = all targets. Otherwise suffix-matched against the target dir list below.
    [string[]]$Targets = @(),

    [switch]$Clean,
    [switch]$KeepGoing
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent

# Target directories (relative to repo root) in build order.
# Alone7z first: it is the smallest full bundle and acts as a toolchain canary.
$AllTargets = @(
    'CPP\7zip\Bundles\Alone7z'          # 7zr.exe
    'CPP\7zip\Bundles\Alone'            # 7za.exe
    'CPP\7zip\Bundles\Alone2'           # 7zz.exe
    'CPP\7zip\Bundles\Format7z'         # 7za.dll
    'CPP\7zip\Bundles\Format7zExtract'  # 7zxa.dll
    'CPP\7zip\Bundles\Format7zExtractR' # 7zxr.dll
    'CPP\7zip\Bundles\Format7zF'        # 7z.dll
    'CPP\7zip\Bundles\Format7zR'        # 7zra.dll
    'CPP\7zip\Bundles\Fm'               # 7zFM.exe (standalone variant)
    'CPP\7zip\Bundles\LzmaCon'          # lzma.exe
    'CPP\7zip\Bundles\SFXCon'           # 7zCon.sfx
    'CPP\7zip\Bundles\SFXSetup'         # 7zS.sfx
    'CPP\7zip\Bundles\SFXWin'           # 7z.sfx
    'CPP\7zip\UI\Console'               # 7z.exe
    'CPP\7zip\UI\Explorer'              # 7-zip.dll
    'CPP\7zip\UI\FileManager'           # 7zFM.exe (standard, uses 7z.dll)
    'CPP\7zip\UI\GUI'                   # 7zG.exe
)

function Import-VcEnv([string]$Arch) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { throw "vswhere.exe not found: $vswhere" }
    $vsPath = & $vswhere -latest -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath
    if (-not $vsPath) { throw 'No Visual Studio installation with MSVC v143 found' }
    $vcvars = Join-Path $vsPath 'VC\Auxiliary\Build\vcvarsall.bat'
    if (-not (Test-Path $vcvars)) { throw "vcvarsall.bat not found: $vcvars" }

    # Host is x64; use cross toolsets for the other targets.
    $archArg = switch ($Arch) {
        'x64'   { 'x64' }
        'x86'   { 'x64_x86' }
        'arm64' { 'x64_arm64' }
    }

    # NB: vcvarsall prints a harmless "'vswhere.exe' is not recognized" line on
    # Build Tools installs; ignore it. cmd's "echo X && y" emits "X " with a
    # trailing space, so match with Trim() rather than exact IndexOf.
    $marker = '__VCENV_BEGIN__'
    $lines = & cmd.exe /s /c "`"$vcvars`" $archArg && echo $marker && set"
    if ($LASTEXITCODE -ne 0) { throw "vcvarsall.bat $archArg failed (exit $LASTEXITCODE)" }
    $begin = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq $marker) { $begin = $i; break }
    }
    if ($begin -lt 0) { throw 'vcvarsall.bat produced no environment marker' }
    foreach ($line in $lines[($begin + 1)..($lines.Count - 1)]) {
        if ($line -match '^([^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
        }
    }
    # vcvarsall does NOT put LLVM on PATH (verified: no Llvm entry appears in
    # the PATH it exports, for any target arch). The arm64 build needs it
    # anyway: Asm/arm64/LzmaDecOpt.S is GNU-syntax assembly and CPP/Build.mak
    # assembles it by invoking a bare `clang-cl`. Without this the arm64 build
    # dies on its first target with "'clang-cl' is not recognized".
    # Harmless for x64/x86, which assemble with ml64/ml and never call clang.
    $llvmBin = @(
        (Join-Path $vsPath 'VC\Tools\Llvm\x64\bin'),   # x64 host
        (Join-Path $vsPath 'VC\Tools\Llvm\bin')        # 32-bit fallback
    ) | Where-Object { Test-Path (Join-Path $_ 'clang-cl.exe') } | Select-Object -First 1
    if ($llvmBin) {
        $env:PATH = "$llvmBin;$env:PATH"
    } elseif ($Arch -eq 'arm64') {
        throw ("clang-cl.exe not found under $vsPath\VC\Tools\Llvm. " +
               "arm64 needs the 'C++ Clang Compiler for Windows' component " +
               "(Microsoft.VisualStudio.Component.VC.Llvm.Clang) - see build\README.md.")
    }

    Write-Host "VC environment loaded: $archArg ($vsPath)"
}

# Resolve target selection.
$selected = if ($Targets.Count -eq 0) {
    $AllTargets
} else {
    $Targets | ForEach-Object {
        $want = $_
        $hit = $AllTargets | Where-Object { $_ -like "*$want" }
        if (-not $hit) { throw "Unknown target: $want" }
        $hit
    }
}

Import-VcEnv $Platform

# The date the About dialog and the console banners show. C\7zVersion.h picks
# this header up when it exists. It is rewritten only when the date changes,
# so its timestamp marks the change: nmake tracks no header dependencies, so
# objects older than it are removed below to make them pick up the new date.
# $dateObjects: the sources in the built targets that use MY_DATE or
# MY_COPYRIGHT_DATE.
$dateHeader = Join-Path $RepoRoot 'C\7zBuildDate.h'
$dateLine = '#define MY_DATE "{0}"' -f (Get-Date).ToString('yyyy-MM-dd', [cultureinfo]::InvariantCulture)
if (-not (Test-Path $dateHeader) -or (Get-Content $dateHeader -Raw).Trim() -ne $dateLine) {
    Set-Content -Path $dateHeader -Value $dateLine -Encoding ascii
}
$dateStamp = (Get-Item $dateHeader).LastWriteTime
$dateObjects = 'AboutDialog.obj', 'Main.obj', 'SfxCon.obj', 'LzmaAlone.obj'

$logDir = Join-Path $PSScriptRoot "logs\$Platform"
New-Item -ItemType Directory -Force $logDir | Out-Null

$results = @()
$sw = [System.Diagnostics.Stopwatch]::StartNew()
foreach ($t in $selected) {
    $dir = Join-Path $RepoRoot $t
    if (-not (Test-Path "$dir\makefile")) { throw "No makefile in $dir" }
    $name = $t -replace '.*\\', ''
    $log = Join-Path $logDir "$name.log"

    if ($Clean -and (Test-Path "$dir\$Platform")) {
        Remove-Item -Recurse -Force "$dir\$Platform"
    }

    if (Test-Path "$dir\$Platform") {
        Get-ChildItem "$dir\$Platform" -File |
            Where-Object { $_.Name -in $dateObjects -and $_.LastWriteTime -lt $dateStamp } |
            Remove-Item -Force
    }

    Write-Host ("[{0}/{1}] {2} ..." -f ($results.Count + 1), $selected.Count, $t) -NoNewline
    $t0 = $sw.Elapsed
    Push-Location $dir
    try {
        & nmake /NOLOGO PLATFORM=$Platform 2>&1 | Out-File -FilePath $log -Encoding utf8
        $ok = ($LASTEXITCODE -eq 0)
    } finally {
        Pop-Location
    }
    $dt = ($sw.Elapsed - $t0).TotalSeconds
    $results += [pscustomobject]@{ Target = $t; Ok = $ok; Seconds = [math]::Round($dt, 1); Log = $log }

    if ($ok) {
        Write-Host (" OK ({0}s)" -f [math]::Round($dt, 1))
    } else {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "---- last 50 lines of $log ----"
        Get-Content $log -Tail 50
        Write-Host '-------------------------------'
        if (-not $KeepGoing) { throw "Build failed: $t (see $log)" }
    }
}

Write-Host ''
Write-Host ("=== Build summary ({0}, {1}s total) ===" -f $Platform, [math]::Round($sw.Elapsed.TotalSeconds, 1))
$results | ForEach-Object {
    $mark = if ($_.Ok) { 'OK  ' } else { 'FAIL' }
    Write-Host ("{0} {1,-40} {2,6}s" -f $mark, $_.Target, $_.Seconds)
}
if ($results | Where-Object { -not $_.Ok }) { exit 1 }
