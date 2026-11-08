<#
.SYNOPSIS
    Check the Registry table of a built .msi against the rules the package is
    supposed to obey. Reads the file; installs nothing; needs no elevation.

.DESCRIPTION
    The Default Programs registration is 270-odd registry rows generated from
    the shell extension's own extension/icon STRINGTABLE, and one of the rules
    it follows is a promise rather than a preference:

        the installer must never write the default value of HKCR\.<ext>

    Writing it would claim the file type machine-wide, which is exactly what
    the coexistence promise with official 7-Zip rules out - and on a machine
    that has 7-Zip installed it would take its associations away. That is one
    forgotten Name= attribute in a generator loop, and nothing else in the
    build would notice: the package would build, install and look fine to
    whoever made the change.

    So it is checked here, on the artifact, where a mistake cannot hide behind
    a green build.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File installer\Test-MsiRegistry.ps1
    powershell -ExecutionPolicy Bypass -File installer\Test-MsiRegistry.ps1 -Msi dist\7-ZSTar-26.05.1-arm64.msi
#>
[CmdletBinding()]
param(
    # Defaults to every .msi in installer\dist, so one run covers all three
    # architectures.
    [string[]]$Msi,

    # Also require every per-machine package to carry the signed sparse MSIX
    # (7-ZSTar.msix) and its certificate (7-ZSTar.cer). Build-Package.ps1 only
    # warns when it has no certificate to sign with and then builds a package
    # without them - minus the Windows 11 first-level menu - so a CI run that
    # lost its certificate step would stay green. Per-user packages are left
    # alone: they carry no sparse package by default.
    [switch]$RequireSparse
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot is not populated during parameter binding on 5.1.
$selfDir = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
           elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
           else { (Get-Location).Path }
if (-not $Msi) {
    $Msi = @(Get-ChildItem (Join-Path $selfDir 'dist') -Filter '*.msi' -ErrorAction SilentlyContinue |
             ForEach-Object { $_.FullName })
    if (-not $Msi) { throw "No .msi in installer\dist. Build one first: pwsh installer\Build-Package.ps1" }
}

# The authority for which file types exist and which icon each one uses. The
# installer generates its ProgIDs from this same string, so comparing against
# it is what makes the check meaningful rather than circular.
$rcPath = Join-Path (Split-Path $selfDir -Parent) 'CPP\7zip\Bundles\Format7zF\resource.rc'
$rcText = Get-Content $rcPath -Raw
if ($rcText -notmatch '(?m)^\s*100\s+"([^"]+)"') { throw "No STRINGTABLE entry 100 in $rcPath" }
$expected = @{}
foreach ($pair in ($Matches[1] -split '\s+')) {
    $e, $i = $pair -split ':'
    if ($e -and $i -match '^\d+$') { $expected[$e] = [int]$i }
}
Write-Host "resource.rc: $($expected.Count) file types"

function Get-MsiRows([string]$path, [string]$sql, [int]$columns) {
    $installer = New-Object -ComObject WindowsInstaller.Installer
    function IM($o, $n, $t, $a) { $o.GetType().InvokeMember($n, [Reflection.BindingFlags]$t, $null, $o, $a) }
    $db = IM $installer 'OpenDatabase' 'InvokeMethod' @($path, 0)
    # A package without a given table (no AppSearch, say) fails OpenView;
    # that is "no rows", which the checks below report as a failure.
    try { $view = IM $db 'OpenView' 'InvokeMethod' @($sql) } catch { return @() }
    $null = IM $view 'Execute' 'InvokeMethod' @($null)
    $rows = @()
    while ($true) {
        $rec = IM $view 'Fetch' 'InvokeMethod' @($null)
        if (-not $rec) { break }
        $vals = @()
        for ($i = 1; $i -le $columns; $i++) { $vals += IM $rec 'StringData' 'GetProperty' @($i) }
        $rows += , $vals
    }
    $null = IM $view 'Close' 'InvokeMethod' @($null)
    return $rows
}

# Backticks: Key and Value are reserved words in MSI SQL.
function Get-RegistryTable([string]$path) {
    Get-MsiRows $path 'SELECT `Root`, `Key`, `Name`, `Value` FROM `Registry`' 4
}

$fail = 0
foreach ($path in $Msi) {
    Write-Host ''
    Write-Host "=== $(Split-Path $path -Leaf)"
    $rows = Get-RegistryTable $path
    $checks = [ordered]@{}

    # THE promise. A row keyed on a bare extension with no value name is a
    # write to that extension's default, i.e. claiming the file type.
    $claims = @($rows | Where-Object { $_[1] -match '^\.[A-Za-z0-9]+$' -and [string]::IsNullOrEmpty($_[2]) })
    $checks['claims no file type'] = ($claims.Count -eq 0)
    foreach ($c in $claims) { Write-Host "    ** would claim $($c[1]) = $($c[3])" }

    $progIcons = @{}
    foreach ($r in $rows) {
        # Two separate -match calls, and the first capture read out before the
        # second runs: $Matches is a single automatic variable, so chaining the
        # two with -and leaves $Matches[1] holding the icon index instead of the
        # extension, and every comparison below silently misses.
        if ($r[1] -match '^7-ZSTar\.(.+)\\DefaultIcon$') {
            $ext = $Matches[1]
            if ($r[3] -match ',(\d+)$') { $progIcons[$ext] = [int]$Matches[1] }
        }
    }
    $checks['a ProgID icon per file type'] = ($progIcons.Count -eq $expected.Count)

    # Every icon index must be the one the DLL's own table says, or the
    # installer and the shell extension disagree about what a .gz looks like.
    $wrong = @($expected.Keys | Where-Object { $progIcons[$_] -ne $expected[$_] })
    $checks['icon indices match resource.rc'] = ($wrong.Count -eq 0)
    foreach ($w in $wrong) { Write-Host "    ** $w : msi=$($progIcons[$w]) rc=$($expected[$w])" }

    $owp = @($rows | Where-Object { $_[1] -match '^\.[A-Za-z0-9]+\\OpenWithProgids$' })
    $checks['an OpenWithProgids entry per file type'] = ($owp.Count -eq $expected.Count)

    $fa = @($rows | Where-Object { $_[1] -match 'Capabilities\\FileAssociations$' })
    $checks['a Capabilities entry per file type'] = ($fa.Count -eq $expected.Count)

    $checks['registered in RegisteredApplications'] =
        @($rows | Where-Object { $_[1] -match 'RegisteredApplications$' -and $_[2] -eq '7-ZSTar' }).Count -eq 1
    $checks['Capabilities has ApplicationName'] =
        @($rows | Where-Object { $_[1] -match 'Capabilities$' -and $_[2] -eq 'ApplicationName' }).Count -eq 1

    # Every open command has to point inside the install folder; a hard-coded
    # path would survive a change of install location and launch nothing.
    $badCmd = @($rows | Where-Object { $_[1] -match '\\shell\\open\\command$' -and $_[3] -notmatch '^\"\[INSTALLFOLDER\]' })
    $checks['open commands use [INSTALLFOLDER]'] = ($badCmd.Count -eq 0)

    # Per-machine and per-user must not be installed side by side, and each
    # package can only tell by the Path value the other one writes (see the
    # comment above OTHERSCOPEDETECTED in 7-ZSTar.wxs). So the value has to be
    # written, and searched for in the other scope's hive: HKCU (1) from the
    # per-machine package, HKLM (2) in both views from the per-user one.
    # Scope="perMachine" is what puts ALLUSERS=1 in the Property table.
    $perMachine = @(Get-MsiRows $path 'SELECT `Value` FROM `Property` WHERE `Property` = ''ALLUSERS''' 1).Count -eq 1
    $checks['writes HKMU Software\7-ZSTar\Path'] =
        @($rows | Where-Object { $_[0] -eq '-1' -and $_[1] -eq 'Software\7-ZSTar' -and $_[2] -eq 'Path' }).Count -eq 1
    $searched = @(Get-MsiRows $path 'SELECT `Signature_` FROM `AppSearch` WHERE `Property` = ''OTHERSCOPEDETECTED''' 1 |
                  ForEach-Object { $_[0] })
    # Type: 2 is a raw value, plus 16 for the 64-bit view.
    $views = @(Get-MsiRows $path 'SELECT `Signature_`, `Root`, `Key`, `Name`, `Type` FROM `RegLocator`' 5 |
               Where-Object { $searched -contains $_[0] -and $_[2] -eq 'Software\7-ZSTar' -and $_[3] -eq 'Path' } |
               ForEach-Object { '{0}:{1}' -f $_[1], ([int]$_[4] -band 16) } | Sort-Object)
    # HKCU\Software is one key in both views, so the per-machine search does
    # not care which view it is in.
    $okViews = if ($perMachine) { $views.Count -eq 1 -and $views[0] -like '1:*' }
               else { ($views -join ',') -eq '2:0,2:16' }
    $checks['searches the other scope for its Path'] = $okViews
    if (-not $okViews) { Write-Host "    ** OTHERSCOPEDETECTED searches: $($views -join ', ')" }
    $checks['blocked on it, except in maintenance'] =
        @(Get-MsiRows $path 'SELECT `Condition` FROM `LaunchCondition`' 1 |
          Where-Object { $_[0] -eq 'Installed OR NOT OTHERSCOPEDETECTED' }).Count -eq 1

    # Where it installs - a security property, not a preference (see the
    # comment above the Main feature in 7-ZSTar.wxs): the folder holds a
    # script the per-machine package runs as SYSTEM, and a folder made outside
    # Program Files can be writable by every user. Per-machine: no folder
    # choice in Custom setup, and SetINSTALLFOLDER - after CostFinalize, so it
    # wins over INSTALLFOLDER from the command line - pins Program Files.
    # Per-user keeps the choice.
    $main = @(Get-MsiRows $path 'SELECT `Feature`, `Directory_` FROM `Feature` WHERE `Feature` = ''Main''' 2)
    if ($perMachine -and $RequireSparse) {
        # File.FileName is "short|long" when the long name is not a valid 8.3
        # name, so compare the part after the bar.
        $names = @(Get-MsiRows $path 'SELECT `FileName` FROM `File`' 1 |
                   ForEach-Object { ($_[0] -split '\|')[-1] })
        $checks['carries the sparse package (7-ZSTar.msix)'] = ($names -contains '7-ZSTar.msix')
        $checks['carries its certificate (7-ZSTar.cer)'] = ($names -contains '7-ZSTar.cer')
    }
    if ($perMachine) {
        $checks['Main feature offers no folder choice'] =
            ($main.Count -eq 1 -and [string]::IsNullOrEmpty($main[0][1]))
        $setDir = @(Get-MsiRows $path 'SELECT `Type`, `Source`, `Target` FROM `CustomAction` WHERE `Action` = ''SetINSTALLFOLDER''' 3)
        $checks['SetINSTALLFOLDER pins Program Files'] =
            ($setDir.Count -eq 1 -and $setDir[0][0] -eq '35' -and $setDir[0][1] -eq 'INSTALLFOLDER' -and
             $setDir[0][2] -eq '[ProgramFiles6432Folder]7-ZSTar\')
        foreach ($table in 'InstallExecuteSequence', 'InstallUISequence') {
            $seq = @{}
            foreach ($r in (Get-MsiRows $path ('SELECT `Action`, `Sequence` FROM `' + $table + '`') 2)) {
                $seq[$r[0]] = $r[1]
            }
            $checks["SetINSTALLFOLDER after CostFinalize ($table)"] =
                ($seq['SetINSTALLFOLDER'] -and $seq['CostFinalize'] -and
                 [int]$seq['SetINSTALLFOLDER'] -gt [int]$seq['CostFinalize'])
        }
    } else {
        $checks['Main feature lets the user pick the folder'] =
            ($main.Count -eq 1 -and $main[0][1] -eq 'INSTALLFOLDER')
    }

    foreach ($k in $checks.Keys) {
        if (-not $checks[$k]) { $fail++ }
        Write-Host ("  [{0}] {1}" -f $(if ($checks[$k]) { 'PASS' } else { 'FAIL' }), $k)
    }
}

# A component GUID shared by the two scopes' packages makes Windows Installer
# keep that component when either one is uninstalled with the other present,
# leaving its registry values behind (see ComponentGuids.wxi). Checked per
# architecture, on whichever pairs are among the packages given. A package
# without its other-scope partner is reported as not checked rather than
# passed over in silence: a run on per-machine packages alone must not read as
# if this rule had been verified.
$isUserMsi = { param($p) $p -like '*-user.msi' -or $p -like '*-user-sparse.msi' }
$paired = @{}
foreach ($userMsi in @($Msi | Where-Object { & $isUserMsi $_ })) {
    # The per-machine package has the same name with or without its sparse
    # package (Build-Package.ps1), so both per-user variants pair with it.
    $machineMsi = $userMsi -replace '-user(-sparse)?\.msi$', '.msi'
    if (-not ($Msi -contains $machineMsi)) {
        Write-Warning "$(Split-Path $userMsi -Leaf): no $(Split-Path $machineMsi -Leaf) given - component GUID sharing NOT checked."
        continue
    }
    $paired[$machineMsi] = $true
    Write-Host ''
    Write-Host "=== $(Split-Path $userMsi -Leaf) vs $(Split-Path $machineMsi -Leaf)"
    $ids = { param($p) @(Get-MsiRows $p 'SELECT `Component`, `ComponentId` FROM `Component`' 2) }
    $machineIds = @{}
    foreach ($r in (& $ids $machineMsi)) { $machineIds[$r[1]] = $r[0] }
    $shared = @(& $ids $userMsi | Where-Object { $machineIds.ContainsKey($_[1]) })
    foreach ($s in $shared) { Write-Host "    ** $($s[0]) $($s[1])" }
    # An unreadable Component table must not pass as "nothing shared".
    $ok = ($machineIds.Count -gt 0 -and $shared.Count -eq 0)
    if (-not $ok) { $fail++ }
    Write-Host ("  [{0}] no component GUID shared between the scopes" -f $(if ($ok) { 'PASS' } else { 'FAIL' }))
}
foreach ($machineMsi in @($Msi | Where-Object { -not (& $isUserMsi $_) -and -not $paired.ContainsKey($_) })) {
    Write-Warning ("$(Split-Path $machineMsi -Leaf): no per-user package given - component GUID " +
                   "sharing NOT checked. Build both scopes (Build-Package.ps1 and -PerUser) to check it.")
}

Write-Host ''
Write-Host $(if ($fail -eq 0) { 'OK' } else { "$fail FAILED CHECK(S)" })
exit $fail
