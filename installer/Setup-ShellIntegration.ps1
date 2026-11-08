<#
.SYNOPSIS
    Register (or remove) the sparse MSIX package that puts 7-ZSTar in the
    Windows 11 first-level context menu.

.DESCRIPTION
    Installed next to the program and driven by four MSI custom actions. It can
    also be run by hand - to repair the integration for a second user account,
    for instance, since package registration is per user and the MSI only ever
    runs it for whoever installed.

    Four steps, which combine, and run in this order whatever order they are
    written in:

      -TrustCert    import 7-ZSTar.cer into LocalMachine\TrustedPeople (or
                    -CertStore for per-user installs).
                    Needs elevation for LocalMachine. Appx deployment refuses
                    a package whose chain does not end in a trusted root, and
                    CurrentUser\TrustedPeople is not consulted: measured, with
                    the certificate there Add-AppxPackage still fails
                    0x800B0109. Re-measured 2026-10-17 on Windows 11 26200 as
                    the installing user, unelevated, in the interactive
                    session - the case one Microsoft page documents as working
                    - with the same result, while adding the same certificate
                    to LocalMachine\TrustedPeople made the same unelevated
                    registration succeed. So -CertStore with a CurrentUser
                    store is accepted but does not make registration work.
                    TrustedPeople rather than Root on purpose - a certificate
                    there is trusted for signed content only, not as a
                    general-purpose issuer.
      -Register     Add-AppxPackage -ExternalLocation <install folder>.
                    Per user, no elevation.
      -Unregister   Remove-AppxPackage. Per user.
      -UntrustCert  drop the certificate again. Needs elevation for
                    LocalMachine; with a CurrentUser -CertStore it removes
                    only the user's own copy, never LocalMachine's.

    And one step that is not about the sparse package at all:

      -RemoveAssociations
                    delete this user's 7-ZSTar.* ProgIDs and the file-type
                    entries still pointing at them. Tools > Options > System in
                    the file manager writes these, per user. The per-machine
                    MSI's own ProgIDs are in HKLM and out of reach here; the
                    per-user MSI's are in this same HKCU\Software\Classes, so
                    on a per-user install this removes those too. At uninstall
                    that is harmless; run by hand there, it takes 7-ZSTar out
                    of Default apps and Open with for every format until the
                    install is repaired. Leaving them behind after an uninstall
                    points every associated extension at a ProgID whose icon
                    and command are a deleted executable, which Explorer draws
                    as a blank icon. Only entries that still name one of our
                    ProgIDs are touched, so an extension handed to another
                    program in the meantime is left alone. So is a ProgID whose
                    open command names a 7zFM.exe outside this install that
                    still exists: another copy of 7-ZSTar - a portable one, say
                    - writes the same names, and its associations are not this
                    install's to remove. (When the per-user MSI is uninstalled,
                    Windows Installer deletes the open command of its own
                    ProgIDs - the same names - before this runs, so those are
                    removed whoever wrote them last.)

    -Status reports what is in place and changes nothing.

    The four sparse-package steps are no-ops below Windows 11 (build 22000):
    older systems have no first-level menu, and the classic shellex
    registration the MSI writes keeps working there unchanged.
    -RemoveAssociations and -Status run on every version, since file
    associations are not a Windows 11 feature.

    Nothing here removes the classic registration. Both are meant to coexist -
    that is what makes the entry survive the "restore classic context menu"
    registry tweak.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Setup-ShellIntegration.ps1 -Status
    powershell -ExecutionPolicy Bypass -File Setup-ShellIntegration.ps1 -TrustCert -Register
    powershell -ExecutionPolicy Bypass -File Setup-ShellIntegration.ps1 -Unregister -UntrustCert
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$TrustCert,
    [switch]$Register,
    [switch]$Unregister,
    [switch]$UntrustCert,
    [switch]$RemoveAssociations,
    [switch]$Status,

    # Where the program is installed - becomes the package's external location.
    # Resolved from this script's own directory when not given, which is what
    # the MSI custom actions rely on: a deferred custom action cannot expand
    # [INSTALLFOLDER] into its own command line.
    [string]$InstallFolder,
    [string]$MsixPath,
    [string]$CerPath,
    # Constrained for the same reason as $ClassesRoot: -TrustCert imports into
    # this store, and a slip to Root would trust the self-signed certificate
    # as a general-purpose issuer (see -TrustCert above).
    [ValidateSet('Cert:\LocalMachine\TrustedPeople', 'Cert:\CurrentUser\TrustedPeople')]
    [string]$CertStore = 'Cert:\LocalMachine\TrustedPeople',

    # Testability hook, not for normal use: which key under HKCU holds the
    # ProgIDs. -RemoveAssociations deletes every 7-ZSTar.* ProgID it finds, so
    # it cannot be exercised against the live hive without destroying the
    # user's real associations. Pointing it at a scratch key lets the actual
    # code be tested rather than a copy of it.
    # Constrained because this decides which subtree -RemoveAssociations
    # deletes from: a typo here is a typo with a Remove-Item behind it.
    [ValidatePattern('^Software\\[^\\]')]
    [string]$ClassesRoot = 'Software\Classes'
)

$ErrorActionPreference = 'Stop'

# Must match Identity/@Name in sparse\AppxManifest.xml.
$PackageName = '7-ZSTar'
# Must match Identity/@Publisher, which is the signing certificate's subject,
# and $SigningCertSubject in Build-Package.ps1. See installer\GUIDS.md.
$CertSubject = 'CN=7-ZSTar project'
# The ProgID prefix the file manager writes when you tick a format under
# Tools > Options > System. Chosen in M1 precisely so that 7-ZSTar and
# official 7-Zip ("7-Zip.*") never share one.
$ProgIdPrefix = '7-ZSTar.'
$UserClasses  = "Registry::HKEY_CURRENT_USER\$ClassesRoot"
$MinBuild    = 22000

# $PSScriptRoot is not populated while parameter defaults are bound on
# PowerShell 5.1 (measured: empty, which made an earlier version die inside
# Join-Path), so paths are resolved here instead.
function Get-SelfDir {
    if ($PSCommandPath) { return (Split-Path -Parent $PSCommandPath) }
    if ($MyInvocation.MyCommand.Path) { return (Split-Path -Parent $MyInvocation.MyCommand.Path) }
    return (Get-Location).Path
}

if (-not $InstallFolder) { $InstallFolder = Get-SelfDir }
$InstallFolder = $InstallFolder.TrimEnd('\')
if (-not $MsixPath) { $MsixPath = Join-Path $InstallFolder '7-ZSTar.msix' }
if (-not $CerPath)  { $CerPath  = Join-Path $InstallFolder '7-ZSTar.cer' }

function Test-Win11 {
    [Environment]::OSVersion.Version.Build -ge $MinBuild
}

function Get-TrustedCerts([string]$Store = $CertStore) {
    @(Get-ChildItem $Store -ErrorAction SilentlyContinue |
      Where-Object { $_.Subject -eq $CertSubject })
}

# Cert:\CurrentUser\<store> is a logical view that also lists every
# certificate in the LocalMachine store of the same name - measured: with one
# copy in each TrustedPeople store, Cert:\CurrentUser\TrustedPeople listed the
# certificate twice. -Status wants the user's own copies, which live in the
# user's profile - under HKCU\Software\Microsoft\SystemCertificates for most
# stores, but as files under AppData for some (measured: CurrentUser\My is
# file-backed) - so both places are checked.
function Get-OwnUserCerts([string]$StoreName) {
    $reg  = "Registry::HKEY_CURRENT_USER\Software\Microsoft\SystemCertificates\$StoreName\Certificates"
    # Empty for an account without a profile; Join-Path would throw on it and
    # take the rest of -Status down with it.
    $appData = [Environment]::GetFolderPath('ApplicationData')
    $file = if ($appData) { Join-Path $appData "Microsoft\SystemCertificates\$StoreName\Certificates" }
    @(Get-TrustedCerts "Cert:\CurrentUser\$StoreName" |
      Where-Object { (Test-Path -LiteralPath (Join-Path $reg $_.Thumbprint)) -or
                     ($file -and (Test-Path -LiteralPath (Join-Path $file $_.Thumbprint))) } |
      Sort-Object Thumbprint -Unique)
}

function Get-Package {
    Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
}

# Measured, Windows 11 25H2 (26200): the Appx cmdlets used below work from a
# 32-bit PowerShell on 64-bit Windows - -Status, -Register and -Unregister were
# all run through SysWOW64\...\powershell.exe and behaved identically. That
# matters because the x86 MSI's custom actions run under WOW64, where a bare
# "powershell.exe" resolves to the 32-bit host, and because Windows 11 has no
# 32-bit edition, every x86 install is that case. No Sysnative re-launch is
# needed; if a future Windows breaks this, that is where the fix goes.
# (Still untested end to end: an actual x86 MSI installing on 64-bit Windows.)

# The MSI does NOT capture what a Directory-type custom action writes to
# stdout - measured: none of these lines reach an /l*v log. Since the custom
# actions are Return="ignore" so that a failed Windows 11 registration cannot
# fail the whole install, this file is the only trace of what happened.
# %TEMP% because it is the one location writable in every context this runs
# in: the elevated half lands in C:\Windows\Temp, the per-user half in the
# user's own temp directory. Program Files is not writable by the
# unelevated custom action.
$LogPath = Join-Path $env:TEMP '7-ZSTar-shell-setup.log'

# Write-Host, not Write-Output: on the output stream these progress notes
# would end up mixed into the functions' return values below.
function Write-Step($text) {
    $line = "[7-ZSTar shell] $text"
    Write-Host $line
    try {
        Add-Content -LiteralPath $LogPath -Encoding utf8 `
            -Value ("{0} {1}" -f (Get-Date -Format 's'), $line)
    } catch {
        # Logging must never be the reason shell integration fails.
    }
}

function Invoke-TrustCert {
    if (-not (Test-Path -LiteralPath $CerPath)) {
        Write-Step "certificate not found: $CerPath"
        return 1
    }
    # Re-importing the same certificate is harmless, but skipping keeps the
    # store free of duplicates across repair and upgrade runs.
    $thumb = (New-Object Security.Cryptography.X509Certificates.X509Certificate2 $CerPath).Thumbprint
    if (Get-TrustedCerts | Where-Object { $_.Thumbprint -eq $thumb }) {
        Write-Step "certificate $thumb already trusted"
        return 0
    }
    $imported = Import-Certificate -FilePath $CerPath -CertStoreLocation $CertStore
    Write-Step "trusted $($imported.Thumbprint) ($($imported.Subject))"
    return 0
}

function Invoke-UntrustCert {
    # A CurrentUser store also lists LocalMachine's copies (Get-OwnUserCerts
    # above), and those belong to a per-machine install or to whoever trusted
    # the certificate by hand: leave them. Only the user's own are ours to drop.
    $found = if ($CertStore -like 'Cert:\CurrentUser\*') {
        Get-OwnUserCerts (Split-Path -Leaf $CertStore)
    } else {
        Get-TrustedCerts
    }
    foreach ($c in $found) {
        Remove-Item -LiteralPath $c.PSPath -Force
        Write-Step "untrusted $($c.Thumbprint)"
    }
    if ($found.Count -eq 0) { Write-Step 'no certificate to remove' }
    return 0
}

function Invoke-Register {
    if (-not (Test-Path -LiteralPath $MsixPath)) {
        Write-Step "package not found: $MsixPath"
        return 1
    }
    # No -ForceApplicationShutdown. It was here at one point to head off a
    # "the DLL is in use" failure that has never actually been observed - the
    # first manual registration and every run since worked without it - and it
    # gives deployment permission to close the user's windows. An error message
    # is the better failure.
    try {
        Add-AppxPackage -Path $MsixPath -ExternalLocation $InstallFolder -ErrorAction Stop
    } catch {
        # Reported, not thrown: the classic context menu is already in place by
        # the time this runs, so a failure here costs the Windows 11
        # first-level entry and nothing else.
        Write-Step "registration failed: $($_.Exception.Message)"
        return 1
    }
    $pkg = Get-Package
    if ($pkg) {
        Write-Step "registered $($pkg.PackageFullName) -> $InstallFolder"
    } else {
        # Add-AppxPackage reported success and the package is not there: worth
        # saying so rather than logging a blank name.
        Write-Step "registration reported success but no package is registered"
        return 1
    }
    return 0
}

function Invoke-Unregister {
    $pkg = Get-Package
    if (-not $pkg) {
        Write-Step 'package not registered for this user'
        return 0
    }
    try {
        Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
        Write-Step "removed $($pkg.PackageFullName)"
    } catch {
        Write-Step "removal failed: $($_.Exception.Message)"
        return 1
    }
    return 0
}

function Get-OurProgIds {
    @(Get-ChildItem $UserClasses -ErrorAction SilentlyContinue |
      Where-Object { $_.PSChildName -like "$ProgIdPrefix*" })
}

# The program a ProgID's open command starts, or '' when it has none. The file
# manager writes "<folder>\7zFM.exe" "%1".
function Get-OpenCommandExe([string]$ProgIdPath) {
    $cmd = (Get-ItemProperty -LiteralPath "$ProgIdPath\shell\open\command" -ErrorAction SilentlyContinue).'(default)'
    if (-not $cmd) { return '' }
    $cmd = $cmd.Trim()
    if ($cmd.StartsWith('"')) {
        $end = $cmd.IndexOf('"', 1)
        if ($end -gt 1) { return $cmd.Substring(1, $end - 1) }
        return ''
    }
    return ($cmd -split '\s+', 2)[0]
}

# Every copy of 7-ZSTar writes the same ProgID names - the installed one and a
# portable one alike - so a name says nothing about whose it is; the open
# command does. One naming a 7zFM.exe outside this install that is still there
# belongs to another copy, and the user set it up with that copy: left alone.
# Pointing into this install, at a file that is gone, or at anything else, it
# is ours or dangling, and goes.
#
# One existence check per program, not per ProgID: a copy sets up dozens of
# types that all name the same 7zFM.exe, and on a network share that is offline
# each check can wait for a connection timeout.
$OtherCopyExists = @{}
function Test-OtherCopyProgId($Key) {
    $exe = Get-OpenCommandExe $Key.PSPath
    if (-not $exe -or (Split-Path -Leaf $exe) -ne '7zFM.exe') { return $false }
    try {
        $full = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($exe))
        $mine = [IO.Path]::GetFullPath($InstallFolder).TrimEnd('\') + '\'
    } catch {
        return $false
    }
    if ($full.StartsWith($mine, [StringComparison]::OrdinalIgnoreCase)) { return $false }
    if (-not $OtherCopyExists.ContainsKey($full)) {
        $OtherCopyExists[$full] = Test-Path -LiteralPath $full -PathType Leaf
    }
    return $OtherCopyExists[$full]
}

# Remove-ItemProperty cannot delete a key's unnamed (default) value. Measured
# on 5.1 and on 7: it returns without an error and the value is still there,
# so the ProgID would go while every file type kept pointing at it - exactly
# the dangling state this whole step exists to prevent. The .NET API does it,
# and it has to be a real deletion rather than setting the value to "", or the
# "is the key empty now" test below never fires.
function Remove-DefaultValue([string]$SubKeyUnderHkcu) {
    $rk = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($SubKeyUnderHkcu, $true)
    if (-not $rk) { return $false }
    try {
        $rk.DeleteValue('', $false)   # $false: do not throw when it is absent
        return $true
    } finally {
        $rk.Close()
    }
}

function Invoke-RemoveAssociations {
    $all = Get-OurProgIds
    $keptNames = @($all | Where-Object { Test-OtherCopyProgId $_ } | ForEach-Object { $_.PSChildName })
    foreach ($k in $keptNames) {
        Write-Step "kept $k (opens $(Get-OpenCommandExe "$UserClasses\$k"), another copy's)"
    }
    $progIds = @($all | Where-Object { $keptNames -notcontains $_.PSChildName })
    $names = @($progIds | ForEach-Object { $_.PSChildName })
    if ($names.Count -eq 0) {
        Write-Step "no 7-ZSTar ProgIDs of this install registered for this user ($($keptNames.Count) kept)"
        return 0
    }

    # Extensions before ProgIDs, deliberately. Deleting the ProgID keys while a
    # file type still names one leaves that type pointing at nothing, and an
    # extension whose ProgID does not resolve is exactly the blank icon this
    # step exists to prevent.
    $exts = 0
    foreach ($k in Get-ChildItem $UserClasses -ErrorAction SilentlyContinue |
                   Where-Object { $_.PSChildName -like '.*' }) {
        $touched = $false

        # Only when it still names one of ours: an extension the user has since
        # given to another program must be left exactly as it is.
        $def = (Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue).'(default)'
        if ($def -and ($names -contains $def)) {
            if ($PSCmdlet.ShouldProcess("$($k.PSChildName) (default = $def)", 'Clear file type')) {
                $null = Remove-DefaultValue "$ClassesRoot\$($k.PSChildName)"
            }
            $touched = $true
        }

        # OpenWithProgids only lists us as a candidate rather than the default,
        # but a candidate that no longer exists still shows up in "Open with".
        # Any of ours except another copy's - including a name whose ProgID is
        # already gone, once there is anything of this install's to clear.
        $owp = Join-Path $k.PSPath 'OpenWithProgids'
        $vals = Get-ItemProperty -LiteralPath $owp -ErrorAction SilentlyContinue
        if ($vals) {
            foreach ($p in @($vals.PSObject.Properties |
                             Where-Object { $_.Name -like "$ProgIdPrefix*" -and $keptNames -notcontains $_.Name })) {
                if ($PSCmdlet.ShouldProcess("$($k.PSChildName)\OpenWithProgids\$($p.Name)", 'Remove')) {
                    Remove-ItemProperty -LiteralPath $owp -Name $p.Name -Force -ErrorAction SilentlyContinue
                }
                $touched = $true
            }
        }

        if ($touched) {
            $exts++
            # Drop the extension key itself only once it holds nothing at all,
            # so any other program's entries under it survive.
            $owpKey = Get-Item -LiteralPath $owp -ErrorAction SilentlyContinue
            if ($owpKey -and $owpKey.ValueCount -eq 0 -and $owpKey.SubKeyCount -eq 0 -and
                $PSCmdlet.ShouldProcess("$($k.PSChildName)\OpenWithProgids (now empty)", 'Remove key')) {
                Remove-Item -LiteralPath $owp -Force -ErrorAction SilentlyContinue
            }
            $key = Get-Item -LiteralPath $k.PSPath -ErrorAction SilentlyContinue
            if ($key -and $key.ValueCount -eq 0 -and $key.SubKeyCount -eq 0 -and
                $PSCmdlet.ShouldProcess("$($k.PSChildName) (now empty)", 'Remove key')) {
                Remove-Item -LiteralPath $k.PSPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    foreach ($p in $progIds) {
        if ($PSCmdlet.ShouldProcess($p.PSChildName, 'Remove ProgID')) {
            Remove-Item -LiteralPath $p.PSPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Counted as candidates, not as completed deletions, so the figure means
    # the same thing under -WhatIf as it does in a real run.
    Write-Step "$($names.Count) ProgID(s), $exts file type entr(ies), $($keptNames.Count) kept"
    return 0
}

# --- dispatch --------------------------------------------------------------

$doAny = $TrustCert -or $Register -or $Unregister -or $UntrustCert -or $RemoveAssociations

if ($Status -or -not $doAny) {
    Write-Step "os build      : $([Environment]::OSVersion.Version.Build) (needs >= $MinBuild)"
    Write-Step "installFolder : $InstallFolder"
    Write-Step "msix          : $MsixPath (exists=$(Test-Path -LiteralPath $MsixPath))"
    Write-Step "cer           : $CerPath (exists=$(Test-Path -LiteralPath $CerPath))"
    Write-Step "trusted (LM)  : $((Get-TrustedCerts 'Cert:\LocalMachine\TrustedPeople').Count) matching '$CertSubject' in LocalMachine\TrustedPeople"
    Write-Step "trusted (CU)  : $((Get-OwnUserCerts 'TrustedPeople').Count) matching '$CertSubject' in this user's own CurrentUser\TrustedPeople (LocalMachine copies not counted)"
    Write-Step "log           : $LogPath"
    Write-Step "associations  : $((Get-OurProgIds).Count) '$ProgIdPrefix*' ProgIDs under HKCU\$ClassesRoot"
    $pkg = Get-Package
    if ($pkg) {
        Write-Step "package       : $($pkg.PackageFullName)  status=$($pkg.Status)"
    } else {
        Write-Step "package       : not registered for $env:USERNAME"
    }
    if (-not $doAny) { exit 0 }
}

$rc = 0

# File associations are not a Windows 11 feature, so this runs above the build
# gate: a Windows 10 uninstall has exactly the same stale-ProgID problem.
if ($RemoveAssociations) { $rc = [Math]::Max($rc, (Invoke-RemoveAssociations)) }

$sparseWanted = $TrustCert -or $Register -or $Unregister -or $UntrustCert
if ($sparseWanted -and -not (Test-Win11)) {
    Write-Step ("Windows build $([Environment]::OSVersion.Version.Build) is below $MinBuild " +
                "- no sparse package to manage, the classic context menu registration " +
                "covers this system")
    exit $rc
}

# Fixed order, so that -TrustCert -Register and -Unregister -UntrustCert each
# do their two halves the only way round that works.
if ($TrustCert)   { $rc = [Math]::Max($rc, (Invoke-TrustCert)) }
if ($Register)    { $rc = [Math]::Max($rc, (Invoke-Register)) }
if ($Unregister)  { $rc = [Math]::Max($rc, (Invoke-Unregister)) }
if ($UntrustCert) { $rc = [Math]::Max($rc, (Invoke-UntrustCert)) }
exit $rc
