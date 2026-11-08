<#
.SYNOPSIS
    Acceptance test for the Windows 11 sparse-package wiring in the MSI.

.DESCRIPTION
    Installs and uninstalls the built MSI for real and compares registry, file
    system, certificate store and Appx state across the phases. This is the
    only thing that can tell you the custom actions still work: the MSI does
    not capture what they print, they are Return="ignore", and a broken one
    costs the Windows 11 first-level context menu while everything else looks
    perfectly healthy.

        A  clean slate     uninstall any 7-ZSTar, drop the package and the
                           certificate, so what is measured afterwards can
                           only have come from this MSI
        B  BEFORE          baseline snapshot
        C  install         msiexec /i, then check the certificate was trusted
                           and the package registered
        D  uninstall       msiexec /x, then check for residue - including that
                           the certificate is gone again
        E  SPARSE=0        install with the opt-out, check that the files are
                           laid down but nothing is trusted or registered
        F  uninstall       residue check again
        G  reinstall       leaves the machine with 7-ZSTar installed normally

    Phase D also covers the uninstall-time cleanup of this user's file
    associations, which means it really does delete the 7-ZSTar.* ProgIDs set
    from Tools > Options > System. Phase A exports them and phase D puts
    them back as soon as it has checked they went, so the window in which they
    are absent is a few lines rather than the rest of the run. If something
    does interrupt it in there, the .reg files are in
    obj\sparse-test\assoc-backup and `reg import` on each one restores them;
    a re-run will not overwrite that backup with an empty one.

    Run it after any change to the four Sparse* custom actions, to their
    conditions or sequencing, or to Setup-ShellIntegration.ps1. It relaunches
    itself through UAC - msiexec cannot install a per-machine package without
    elevation.

    What it does NOT cover, and no script can: whether the entry actually
    appears in the first-level menu. Right-click a file and look.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File installer\Test-SparseIntegration.ps1
    powershell -ExecutionPolicy Bypass -File installer\Test-SparseIntegration.ps1 -Msi dist\7-ZSTar-26.05.1-x64.msi
#>
[CmdletBinding()]
param(
    # Defaults to the newest .msi in installer\dist.
    [string]$Msi,
    [string]$OutDir
)

$ErrorActionPreference = 'Stop'

$PackageName  = '7-ZSTar'
$CertSubject  = 'CN=7-ZSTar project'
$ShellExtId   = '{E9471EF7-A2B2-46B9-95AB-E4421B50C777}'
$InstallDir   = 'C:\Program Files\7-ZSTar'
$ProgIdPrefix = '7-ZSTar.'
$UserClasses  = 'Registry::HKEY_CURRENT_USER\Software\Classes'

# $PSScriptRoot is empty while parameter defaults are bound on PowerShell 5.1,
# so anything derived from this script's location is resolved here.
function Get-SelfPath {
    if ($PSCommandPath) { return $PSCommandPath }
    if ($MyInvocation.MyCommand.Path) { return $MyInvocation.MyCommand.Path }
    return $null
}
$self = Get-SelfPath
$selfDir = if ($self) { Split-Path -Parent $self } else { (Get-Location).Path }

if (-not $Msi) {
    # Newest .msi for THIS machine's architecture, not simply the newest one:
    # Build-Package.ps1 is usually run for all three in a row, so "newest"
    # is whichever was packaged last and would try to install an arm64
    # package on an x64 box.
    $hostArch = switch ($env:PROCESSOR_ARCHITECTURE) {
        'AMD64' { 'x64' }
        'ARM64' { 'arm64' }
        'x86'   { 'x86' }
        default { 'x64' }
    }
    $Msi = (Get-ChildItem (Join-Path $selfDir 'dist') -Filter "*-$hostArch.msi" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    if (-not $Msi) {
        throw ("No *-$hostArch.msi in installer\dist. Build one first: " +
               "pwsh installer\Build-Package.ps1 -Platform $hostArch")
    }
}
if (-not $OutDir) { $OutDir = Join-Path $selfDir 'obj\sparse-test' }
New-Item -ItemType Directory -Force $OutDir | Out-Null

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host 'Not elevated - relaunching through UAC...'
    # A PowerShell 7 parent exports its own PSModulePath, which makes a 5.1
    # child load PS7 core modules and fail to autoload PKI.
    $env:PSModulePath = "$env:ProgramFiles\WindowsPowerShell\Modules;" +
                        "$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules"
    # System32 powershell.exe, not the Store-provisioned pwsh: the WindowsApps
    # alias cannot be elevated and fails with a misleading "cancelled by user".
    $host51 = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    # Array form only; a single string gets re-parsed and paths keep quotes.
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $self,
                 '-Msi', $Msi, '-OutDir', $OutDir)
    $p = Start-Process -FilePath $host51 -Verb RunAs -ArgumentList $argList -Wait -PassThru
    Write-Host "elevated child exit=$($p.ExitCode)"
    $report = Join-Path $OutDir 'report.txt'
    if (Test-Path -LiteralPath $report) { Get-Content -LiteralPath $report }
    exit $p.ExitCode
}

# --- elevated from here ----------------------------------------------------

$lines = New-Object Collections.Generic.List[string]
function Say($text) { Write-Host $text; $lines.Add($text) | Out-Null }

function Get-Snapshot {
    $pkg = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
    $arp = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' `
                -ErrorAction SilentlyContinue |
           Where-Object { $_.DisplayName -eq '7-ZSTar' } | Select-Object -First 1
    [ordered]@{
        files        = if (Test-Path $InstallDir) { @(Get-ChildItem $InstallDir -File).Count } else { 0 }
        msix         = Test-Path (Join-Path $InstallDir '7-ZSTar.msix')
        cer          = Test-Path (Join-Path $InstallDir '7-ZSTar.cer')
        setupScript  = Test-Path (Join-Path $InstallDir 'Setup-ShellIntegration.ps1')
        package      = if ($pkg) { $pkg.PackageFullName } else { '' }
        trustedCerts = @(Get-ChildItem Cert:\LocalMachine\TrustedPeople -ErrorAction SilentlyContinue |
                         Where-Object { $_.Subject -eq $CertSubject }).Count
        clsidServer  = (Get-ItemProperty -LiteralPath "Registry::HKEY_CLASSES_ROOT\CLSID\$ShellExtId\InprocServer32" `
                            -ErrorAction SilentlyContinue).'(default)'
        # HKCR\*\... : the * is a real key name, not a wildcard, so this needs
        # -LiteralPath. Without it the provider enumerates the whole hive and
        # never returns.
        shellexFiles = (Get-ItemProperty -LiteralPath "Registry::HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers\7-ZSTar" `
                            -ErrorAction SilentlyContinue).'(default)'
        arpVersion   = if ($arp) { $arp.DisplayVersion } else { '' }
        startMenu    = Test-Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-ZSTar"
        # The Default Programs registration - 270-odd rows the installer writes
        # machine-wide. Counted rather than listed, but counted here on purpose:
        # without these three the "back to BEFORE state" comparison would report
        # a clean uninstall while leaving every ProgID behind.
        progIds      = @(Get-ChildItem 'Registry::HKEY_LOCAL_MACHINE\Software\Classes' -ErrorAction SilentlyContinue |
                         Where-Object { $_.PSChildName -like '7-ZSTar.*' }).Count
        capabilities = Test-Path 'Registry::HKEY_LOCAL_MACHINE\Software\7-ZSTar\Capabilities'
        registeredApp = (Get-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\RegisteredApplications' `
                            -ErrorAction SilentlyContinue).'7-ZSTar'
    }
}

function Show-Snapshot($name, $s) {
    Say "--- $name"
    foreach ($k in $s.Keys) { Say ("      {0,-14}{1}" -f $k, $s[$k]) }
}

function Invoke-Msi($mode, $logName, $extraArgs) {
    $log = Join-Path $OutDir $logName
    $argList = @($mode, $Msi) + @($extraArgs) + @('/qn', '/l*v', $log)
    $p = Start-Process msiexec.exe -ArgumentList $argList -Wait -PassThru
    Say ("    msiexec {0} {1}-> exit {2}   log={3}" -f $mode, (@($extraArgs) -join ' '), $p.ExitCode, $logName)
    return $p.ExitCode
}

$checks = [ordered]@{}
function Check($name, $ok) { $checks[$name] = [bool]$ok }

function Get-ProgIdCount {
    @(Get-ChildItem $UserClasses -ErrorAction SilentlyContinue |
      Where-Object { $_.PSChildName -like "$ProgIdPrefix*" }).Count
}

# File types still naming a 7-ZSTar ProgID that no longer exists. Counting the
# ProgIDs alone is not enough: deleting them while the extensions still point
# at them is precisely the blank-icon state the cleanup exists to avoid, and an
# earlier version of it did exactly that while this test reported green.
function Get-DanglingExtCount {
    $n = 0
    foreach ($k in Get-ChildItem $UserClasses -ErrorAction SilentlyContinue |
                   Where-Object { $_.PSChildName -like '.*' }) {
        $def = (Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue).'(default)'
        if ($def -like "$ProgIdPrefix*" -and
            -not (Test-Path -LiteralPath (Join-Path $UserClasses $def))) { $n++ }
    }
    return $n
}

# The file associations under test are the ones the user set by hand in the
# file manager, and phase D really deletes them - that is the behaviour being
# checked. Export them first and put them back in phase G, so running the
# acceptance test is not a destructive act.
function Backup-Associations($dir) {
    New-Item -ItemType Directory -Force $dir | Out-Null
    # Never overwrite a backup with an empty one. If a previous run was
    # interrupted after phase D, the associations are already gone and the .reg
    # files sitting here are the only copy of them - clearing those and then
    # exporting the now-empty hive would destroy the user's associations for
    # good.
    if ((Get-ProgIdCount) -eq 0) {
        $existing = @(Get-ChildItem $dir -Filter *.reg -ErrorAction SilentlyContinue)
        if ($existing.Count -gt 0) {
            Write-Host ("    keeping the $($existing.Count) .reg file(s) already in $dir - " +
                        "nothing is registered now, so they are probably from an interrupted run")
            return $existing.Count
        }
    }
    Get-ChildItem $dir -Filter *.reg -ErrorAction SilentlyContinue | Remove-Item -Force
    $keys = @()
    foreach ($k in Get-ChildItem $UserClasses -ErrorAction SilentlyContinue) {
        if ($k.PSChildName -like "$ProgIdPrefix*") { $keys += $k.PSChildName; continue }
        if ($k.PSChildName -notlike '.*') { continue }
        $def = (Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue).'(default)'
        $owp = Get-ItemProperty -LiteralPath (Join-Path $k.PSPath 'OpenWithProgids') -ErrorAction SilentlyContinue
        $hasOwp = $owp -and @($owp.PSObject.Properties | Where-Object { $_.Name -like "$ProgIdPrefix*" }).Count
        if (($def -like "$ProgIdPrefix*") -or $hasOwp) { $keys += $k.PSChildName }
    }
    $i = 0
    foreach ($k in $keys) {
        $null = & reg.exe export "HKCU\Software\Classes\$k" (Join-Path $dir ("k{0:d3}.reg" -f $i++)) /y 2>&1
    }
    return $keys.Count
}

function Restore-Associations($dir) {
    $n = 0
    foreach ($f in Get-ChildItem $dir -Filter *.reg -ErrorAction SilentlyContinue) {
        $null = & reg.exe import $f.FullName 2>&1
        $n++
    }
    return $n
}

Say "=== A. clean slate ==="
Say "    msi: $Msi"
$assocBackup = Join-Path $OutDir 'assoc-backup'
$progIdsBefore = Get-ProgIdCount
Say "    backing up $(Backup-Associations $assocBackup) association key(s), $progIdsBefore ProgID(s) -> $assocBackup"
$pkg = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
if ($pkg) { Remove-AppxPackage -Package $pkg.PackageFullName; Say "    removed package $($pkg.PackageFullName)" }
Get-ChildItem Cert:\LocalMachine\TrustedPeople -ErrorAction SilentlyContinue |
    Where-Object { $_.Subject -eq $CertSubject } |
    ForEach-Object { Remove-Item -LiteralPath $_.PSPath -Force; Say "    untrusted $($_.Thumbprint)" }
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -eq '7-ZSTar' } |
    ForEach-Object {
        $p = Start-Process msiexec.exe -ArgumentList @('/x', $_.PSChildName, '/qn') -Wait -PassThru
        Say "    uninstalled existing $($_.PSChildName) -> exit $($p.ExitCode)"
    }

Say ''
Say '=== B. snapshot BEFORE ==='
$before = Get-Snapshot
Show-Snapshot 'BEFORE' $before

Say ''
Say '=== C. install (default) ==='
Check 'install exit 0' ((Invoke-Msi '/i' 'install.log' @()) -eq 0)
$onC = Get-Snapshot
Show-Snapshot 'INSTALLED' $onC
Check 'msix installed'                 $onC.msix
Check 'cer installed'                  $onC.cer
Check 'setup script installed'         $onC.setupScript
Check 'certificate trusted on install' ($onC.trustedCerts -ge 1)
Check 'package registered on install'  ($onC.package -ne '')
Check 'classic menu still registered'  ($onC.shellexFiles -eq $ShellExtId)
Check 'ProgIDs registered machine-wide' ($onC.progIds -gt 0)
Check 'listed in Default apps'          ($onC.capabilities -and $onC.registeredApp)

Say ''
Say '=== D. uninstall ==='
Check 'uninstall exit 0' ((Invoke-Msi '/x' 'uninstall.log' @()) -eq 0)
$onD = Get-Snapshot
Show-Snapshot 'UNINSTALLED' $onD
Check 'package gone after uninstall'    ($onD.package -eq '')
Check 'certificate gone after uninstall' ($onD.trustedCerts -eq 0)
Check 'files gone after uninstall'      ($onD.files -eq 0)
Check 'clsid gone after uninstall'      ([string]::IsNullOrEmpty($onD.clsidServer))
Check 'ARP gone after uninstall'        ($onD.arpVersion -eq '')
Check 'ProgIDs gone after uninstall'    ($onD.progIds -eq 0)
Check 'Default apps entry gone'         (-not $onD.capabilities -and -not $onD.registeredApp)
Check 'back to BEFORE state'            (($onD | ConvertTo-Json -Compress) -eq ($before | ConvertTo-Json -Compress))
# Only meaningful when there were associations to clear in the first place.
$progIdsAfterD = Get-ProgIdCount
$danglingAfterD = Get-DanglingExtCount
Say "    7-ZSTar ProgIDs: $progIdsBefore before -> $progIdsAfterD after uninstall"
Say "    file types left pointing at a missing ProgID: $danglingAfterD"
if ($progIdsBefore -gt 0) {
    Check 'user associations removed on uninstall' ($progIdsAfterD -eq 0)
    Check 'no file type left pointing at a deleted ProgID' ($danglingAfterD -eq 0)
} else {
    Say '    (no associations were set, so those checks are skipped)'
}

# Restored here, immediately, and not at the end of the run. Everything after
# this point is more msiexec, and anything that stops the script in the middle
# of it - a hang, Ctrl-C, a reboot - would otherwise leave the user's file
# associations deleted with only the .reg files to show for it.
if ($progIdsBefore -gt 0) {
    Say "    re-imported $(Restore-Associations $assocBackup) association key(s)"
    $progIdsRestored = Get-ProgIdCount
    Say "    7-ZSTar ProgIDs restored: $progIdsRestored (was $progIdsBefore)"
    Check 'associations restored after the check' ($progIdsRestored -eq $progIdsBefore)
}

Say ''
Say '=== E. install with SPARSE=0 (the documented opt-out) ==='
Check 'SPARSE=0 install exit 0' ((Invoke-Msi '/i' 'install-sparse0.log' @('SPARSE=0')) -eq 0)
$onE = Get-Snapshot
Show-Snapshot 'INSTALLED (SPARSE=0)' $onE
Check 'SPARSE=0 still installs the program' ($onE.files -gt 0)
Check 'SPARSE=0 keeps the classic menu'     ($onE.shellexFiles -eq $ShellExtId)
Check 'SPARSE=0 trusts nothing'             ($onE.trustedCerts -eq 0)
Check 'SPARSE=0 registers nothing'          ($onE.package -eq '')

Say ''
Say '=== F. uninstall after SPARSE=0 ==='
# KEEPASSOC=1: the association cleanup was already exercised in phase D, and
# there is nothing left to clear. Passing it here also covers the opt-out
# reaching the elevated half of the install (it is in SecureCustomProperties).
Check 'SPARSE=0 uninstall exit 0' ((Invoke-Msi '/x' 'uninstall-sparse0.log' @('KEEPASSOC=1')) -eq 0)
$onF = Get-Snapshot
Show-Snapshot 'UNINSTALLED (after SPARSE=0)' $onF
Check 'SPARSE=0 leaves no residue' (($onF | ConvertTo-Json -Compress) -eq ($before | ConvertTo-Json -Compress))

Say ''
Say '=== verdict ==='
$fail = 0
foreach ($k in $checks.Keys) {
    if (-not $checks[$k]) { $fail++ }
    Say ("  [{0}] {1}" -f $(if ($checks[$k]) { 'PASS' } else { 'FAIL' }), $k)
}
Say ("  {0}/{1} checks passed" -f ($checks.Count - $fail), $checks.Count)
Say '  (the first-level menu itself is not machine-checkable: right-click a file)'

Say ''
Say '=== G. reinstall, leaving the machine with 7-ZSTar installed ==='
$null = Invoke-Msi '/i' 'reinstall.log' @()
Say "    7-ZSTar ProgIDs: $(Get-ProgIdCount) (was $progIdsBefore before the run)"
Show-Snapshot 'FINAL' (Get-Snapshot)

$lines | Set-Content (Join-Path $OutDir 'report.txt') -Encoding utf8
exit $fail
