# 7-ZSTar release packaging (M7): portable .zip + .msi
#
# Usage:
#   pwsh installer\Build-Package.ps1                    # x64, zip + msi
#   pwsh installer\Build-Package.ps1 -Platform arm64
#   pwsh installer\Build-Package.ps1 -SkipMsi           # zip only (no WiX needed)
#   pwsh installer\Build-Package.ps1 -CreateSigningCert # first run on a machine
#   pwsh installer\Build-Package.ps1 -PerUser           # per-user .msi, no sparse, no zip
#
# Both artifacts are cut from the same staging directory, so what the MSI
# installs and what the .zip contains cannot drift apart. Build the binaries
# first with build\Build.ps1.
#
# Requires for the MSI: WiX v6 as a dotnet tool, plus two extensions - the
# wizard dialogs and the launch-on-finish custom action. Once per machine:
#   dotnet tool install --global wix --version 6.0.2
#   wix extension add -g WixToolset.UI.wixext/6.0.2
#   wix extension add -g WixToolset.Util.wixext/6.0.2

[CmdletBinding()]
param(
    [ValidateSet('x64', 'x86', 'arm64')]
    [string]$Platform = 'x64',

    [string]$OutputDir = (Join-Path $PSScriptRoot 'dist'),
    [switch]$SkipMsi,
    [switch]$SkipZip,

    # Build the per-user MSI variant (Scope="perUser", installs under
    # LocalAppDataFolder\Programs, per-user UpgradeCode, drops HKLM shell ext).
    # Passes -d PerUser=1 to `wix build`.
    [switch]$PerUser,

    # Sparse MSIX package for the Windows 11 first-level context menu. Built
    # into the MSI when a signing certificate is available; -SkipSparse (or no
    # certificate at all) produces a package that registers only the classic
    # context menu, which is what every Windows 10 install gets anyway.
    [switch]$SkipSparse,
    [switch]$CreateSigningCert,
    [string]$SigningCertThumbprint,

    # Include the sparse package in a per-user build. Only has an effect
    # together with -PerUser; passes -d SparseUser=1 to `wix build`.
    # With today's self-signed certificate this variant installs but never
    # gets the Windows 11 entry. Measured 2026-10-17 on Windows 11 26200: the
    # installing user, unelevated, imports the certificate into
    # CurrentUser\TrustedPeople and Add-AppxPackage still fails 0x800B0109;
    # the same certificate added to LocalMachine\TrustedPeople - which needs
    # elevation - makes the same unelevated registration succeed. So per-user
    # builds leave the package out by default, and this switch is kept only
    # for a certificate issued by a trusted CA, which Microsoft documents as
    # needing no local trust step at all (not measured here).
    [switch]$SparseUser,

    # Package binaries that carry no source stamp or a stamp that no longer
    # matches the source (build\SourceStamp.ps1). Off by default: packaging
    # then stops, because an old build would otherwise ship as if it were new.
    # Use only for a deliberate case; the skip is logged to
    # build\logs\freshness-skips.log, and no .srcstamp is written beside the
    # packages, so they cannot vouch for themselves later.
    [switch]$SkipFreshnessCheck
)

$ErrorActionPreference = 'Stop'

if ($SparseUser -and -not $PerUser) {
    throw "-SparseUser is only valid together with -PerUser."
}
if ($SparseUser -and $SkipSparse) {
    throw "-SparseUser and -SkipSparse contradict each other: -SparseUser is the request for the sparse package."
}
if ($SparseUser) {
    Write-Warning ("-SparseUser: with a self-signed certificate this package installs " +
                   "but does not get the Windows 11 first-level menu. Measured: " +
                   "CurrentUser\TrustedPeople is not trusted for deployment " +
                   "(Add-AppxPackage fails 0x800B0109) and LocalMachine needs " +
                   "elevation. Only worth building with a CA-issued certificate.")
}
$RepoRoot = Split-Path $PSScriptRoot -Parent
$Stage = Join-Path $PSScriptRoot "stage\$Platform"
. (Join-Path $RepoRoot 'build\SourceStamp.ps1')

# Identity/@Publisher in sparse\AppxManifest.xml is filled in from the signing
# certificate's subject, but the certificate has to be found by *something*, so
# this string is the search key when no thumbprint is given. It also has to
# match $CertSubject in Setup-ShellIntegration.ps1, which removes the
# certificate again on uninstall.
$SigningCertSubject = 'CN=7-ZSTar project'

# MakeAppx and SignTool ship with the Windows SDK, which is not on PATH and
# keeps one directory per SDK version. Newest wins; the x64 build of the tool
# is fine whatever we are packaging for, since neither looks at target
# architecture.
# Anything interpolated into a generated XML attribute goes through this, the
# same way the language fragment escapes its titles. The file-type table is
# plain ASCII today; a generator that only holds for today's input is a build
# break waiting for whoever adds a format. Ampersand first, or the later
# replacements would have their own ampersands escaped twice.
function ConvertTo-XmlAttr([string]$Text) {
    ((($Text -replace '&', '&amp;') -replace '<', '&lt;') -replace '>', '&gt;') -replace '"', '&quot;'
}

function Find-SdkTool([string]$Name) {
    $roots = @("${env:ProgramFiles(x86)}\Windows Kits\10\bin",
               "$env:ProgramFiles\Windows Kits\10\bin")
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        $hit = Get-ChildItem $root -Recurse -Filter $Name -ErrorAction SilentlyContinue |
               Where-Object { $_.DirectoryName -match '\\x64$' } |
               Sort-Object { try { [version]$_.Directory.Parent.Name } catch { [version]'0.0' } } -Descending |
               Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    throw ("$Name not found under any Windows Kits\10\bin. Install the Windows SDK, " +
           "or build with -SkipSparse to leave out the Windows 11 context menu package.")
}

# --- version ---------------------------------------------------------------

$verHeader = Join-Path $RepoRoot 'C\7zVersion.h'
$verText = Get-Content $verHeader -Raw
if ($verText -notmatch '#define\s+MY_VERSION_NUMBERS\s+"([0-9.]+)"') {
    throw "Could not read MY_VERSION_NUMBERS from $verHeader"
}
$Version = $Matches[1]

# The Apps & features links come from the same header the online-help fallback
# compiles against, so the MSI cannot point somewhere the program does not.
if ($verText -notmatch '#define\s+MY_PROJECT_URL\s+"([^"]+)"') {
    throw "Could not read MY_PROJECT_URL from $verHeader"
}
$ProjectUrl = $Matches[1]

# MSI ProductVersion wants plain numeric fields; "26.02.1" would carry a
# leading zero into the minor field. Keep the display string as-is for file
# names and normalise only what goes into the package.
#
# Windows Installer compares only the first three fields (major.minor.build)
# when deciding upgrades - a fourth field is accepted but ignored. If
# MY_VERSION_NUMBERS ever grows to four parts, two releases differing only in
# that last part would look identical to MajorUpgrade and fail to replace each
# other, so warn rather than let it pass silently.
$MsiVersion = (($Version -split '\.') | ForEach-Object { [int]$_ }) -join '.'
if (($Version -split '\.').Count -gt 3) {
    Write-Warning ("Version '$Version' has more than three fields; Windows " +
                   "Installer ignores everything after the third when " +
                   "comparing versions for upgrade.")
}

# An MSIX package version is always four fields, and Windows rejects anything
# else outright, so pad rather than reuse $MsiVersion.
$PkgFields = @(($MsiVersion -split '\.')) + @('0', '0', '0', '0')
$PkgVersion = ($PkgFields[0..3]) -join '.'
$scopeLabel = if ($PerUser) {
    if ($SparseUser) { 'per-user sparse' } else { 'per-user' }
} else {
    'per-machine'
}
Write-Host "7-ZSTar $Version ($Platform) [$scopeLabel]  msi-version=$MsiVersion  package-version=$PkgVersion"

# --- payload ---------------------------------------------------------------

# Binaries, relative to the repo root, keyed by their name in the package.
$Binaries = [ordered]@{
    '7zFM.exe'  = "CPP\7zip\UI\FileManager\$Platform\7zFM.exe"
    '7zG.exe'   = "CPP\7zip\UI\GUI\$Platform\7zG.exe"
    '7z.exe'    = "CPP\7zip\UI\Console\$Platform\7z.exe"
    '7za.exe'   = "CPP\7zip\Bundles\Alone\$Platform\7za.exe"
    '7z.dll'    = "CPP\7zip\Bundles\Format7zF\$Platform\7z.dll"
    '7-zip.dll' = "CPP\7zip\UI\Explorer\$Platform\7-zip.dll"
}

# Documents shipped alongside, taken from the repo root as-is. LICENSE-7-Zip.txt
# is upstream's own licence statement from its binary package, which that file
# requires binary redistributions to reproduce.
$Docs = @('LICENSE', 'COPYING', 'LICENSE-EXCEPTIONS.md', 'LICENSE-7-Zip.txt',
          'NOTICE', 'README.md', 'CHANGELOG.md')

# Upstream's translations, vendored at the repo root. LangUtils.cpp looks for
# them in "<directory of the running module>\Lang\", so the folder name and its
# position next to the executables are both load-bearing.
$LangSrc = Join-Path $RepoRoot 'Lang'

$missing = @()
foreach ($kv in $Binaries.GetEnumerator()) {
    if (-not (Test-Path (Join-Path $RepoRoot $kv.Value))) { $missing += $kv.Value }
}
foreach ($d in $Docs) {
    if (-not (Test-Path (Join-Path $RepoRoot $d))) { $missing += $d }
}
if ($missing) {
    throw ("Missing payload files (build them first with build\Build.ps1):`n  " +
           ($missing -join "`n  "))
}

# The binaries exist - but were they built from the source as it is now? An
# old build packs just as happily as a new one. Fingerprint the packaging
# inputs now, before anything is staged, so the stamp written beside each
# package at the end says which source it was cut from; with the check skipped
# nothing was verified, so no stamp is written and the package cannot vouch
# for itself later.
Assert-ArtifactFresh -Path @($Binaries.Values | ForEach-Object { Join-Path $RepoRoot $_ }) `
    -Skip:$SkipFreshnessCheck -Caller 'Build-Package.ps1'
$pkgFp = $null
if (-not $SkipFreshnessCheck) { $pkgFp = Get-SourceFingerprint -Kind package -RepoRoot $RepoRoot }

# Checked separately from $missing so the message can say where these come
# from - they are not build output and rebuilding will not produce them.
# *.ttt as well as *.txt: en.ttt is not a selectable language, it is the
# reference upstream measures translation completeness against.
$LangFiles = @()
if (Test-Path $LangSrc) {
    $LangFiles = @(Get-ChildItem $LangSrc -File |
                   Where-Object { $_.Extension -in '.txt', '.ttt' })
}
if (-not $LangFiles) {
    throw ("No language files under $LangSrc. They are vendored from an " +
           "upstream 7-Zip binary release, not built - see Lang\UPSTREAM.md.")
}

# The help file, from the same upstream release as Lang\ (see Help\UPSTREAM.md).
# HelpUtils.cpp opens "<directory of the running module>\7-zip.chm", so it goes
# in the package root, not a subfolder.
$HelpFile = Join-Path $RepoRoot 'Help\7-zip.chm'
if (-not (Test-Path $HelpFile)) {
    throw ("Help file missing: $HelpFile. It is vendored from an upstream " +
           "7-Zip binary release, not built - see Help\UPSTREAM.md.")
}

if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
New-Item -ItemType Directory -Force $Stage | Out-Null
New-Item -ItemType Directory -Force $OutputDir | Out-Null

foreach ($kv in $Binaries.GetEnumerator()) {
    Copy-Item (Join-Path $RepoRoot $kv.Value) (Join-Path $Stage $kv.Key) -Force
}
foreach ($d in $Docs) {
    Copy-Item (Join-Path $RepoRoot $d) (Join-Path $Stage $d) -Force
}
Copy-Item $HelpFile (Join-Path $Stage '7-zip.chm') -Force

$StageLang = Join-Path $Stage 'Lang'
New-Item -ItemType Directory -Force $StageLang | Out-Null
foreach ($f in $LangFiles) {
    Copy-Item $f.FullName (Join-Path $StageLang $f.Name) -Force
}

# Only the .zip carries this note; the .wxs does not reference it, so it
# never reaches the MSI.
@"
7-ZSTar $Version ($Platform) - portable package
===============================================

This is the no-install package. Unzip anywhere and run 7zFM.exe.

What you do NOT get compared to the .msi installers:

  * No Explorer context menu ("7-ZSTar" on right-click). That needs a
    registered shell extension, which needs a real install. Without
    administrator rights, the per-user installer (-user.msi) provides it
    for your own account. Use the one matching Windows (x86 on 32-bit
    Windows, x64 on 64-bit, arm64 on Windows on Arm): the x86 shell
    extension cannot load into 64-bit Explorer.
  * No Start menu entry and no file associations.
  * Nothing is written to the registry by unzipping. 7-ZSTar will still
    create its own settings under HKCU\Software\7-ZSTar the first time you
    change a setting in the GUI.

Translations are included: keep the Lang\ folder next to 7zFM.exe and pick a
language under Tools > Options > Language.

To remove it, delete this folder.

7-ZSTar installs side by side with official 7-Zip and does not touch its
settings, its file associations or its context menu.

Licensing: LGPL v3, with exceptions listed in LICENSE-EXCEPTIONS.md
(the RAR decompression code carries the unRAR restriction). Full text in
LICENSE and COPYING. Third-party notices in NOTICE.
"@ | Set-Content (Join-Path $Stage 'portable.txt') -Encoding utf8

$stagedCount = (Get-ChildItem $Stage -File).Count
Write-Host ("  staged $stagedCount files + $($LangFiles.Count) language files " +
            "-> installer\stage\$Platform")

# --- zip -------------------------------------------------------------------

# The portable .zip is scope-independent; skip rebuilding it for per-user runs.
if (-not $SkipZip -and -not $PerUser) {
    $zipPath = Join-Path $OutputDir "7-ZSTar-$Version-$Platform.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Remove-SourceStamp (Get-SourceStampPath $zipPath)
    # Compress-Archive rather than the 7z.exe we just built: packaging must not
    # depend on the payload being runnable, so that a broken build still
    # produces an artifact to examine instead of failing at the packaging step.
    Compress-Archive -Path (Join-Path $Stage '*') -DestinationPath $zipPath -CompressionLevel Optimal
    $zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
    Write-Host "  zip  $([IO.Path]::GetFileName($zipPath))  ${zipSize} MB"
    if ($pkgFp) { Write-SourceStamp -StampPath (Get-SourceStampPath $zipPath) -Fingerprint $pkgFp }
}

# --- msi -------------------------------------------------------------------

if (-not $SkipMsi) {
    $wix = Get-Command wix -ErrorAction SilentlyContinue
    $wixPath = if ($wix) { $wix.Source } else { Join-Path $env:USERPROFILE '.dotnet\tools\wix.exe' }
    if (-not (Test-Path $wixPath)) {
        throw ("WiX not found. Install it with:`n" +
               "  dotnet tool install --global wix --version 6.0.2")
    }

    $msiLeaf = if ($PerUser) {
        if ($SparseUser) { "7-ZSTar-$Version-$Platform-user-sparse.msi" } else { "7-ZSTar-$Version-$Platform-user.msi" }
    } else {
        "7-ZSTar-$Version-$Platform.msi"
    }
    $msiPath = Join-Path $OutputDir $msiLeaf
    if (Test-Path $msiPath) { Remove-Item $msiPath -Force }
    Remove-SourceStamp (Get-SourceStampPath $msiPath)

    # --- sparse package (Windows 11 first-level context menu) --------------
    #
    # Windows 11 shows a shell extension in the first-level menu only when it
    # comes with package identity; a classic shellex registration is always
    # demoted to "Show more options". So the MSI carries an identity-only MSIX
    # alongside the binaries and registers it at install time. See
    # sparse\AppxManifest.xml for what it declares and why, and
    # Setup-ShellIntegration.ps1 for what the custom actions do with it.
    #
    # Optional on purpose: without a signing certificate this step is skipped
    # and the MSI still builds, minus the Windows 11 entry. Signing is not
    # something a clean clone or a CI runner can do.
    # Under -PerUser, sparse is only built if -SparseUser is explicitly requested.
    $SparseDir = $null
    $buildSparse = -not $SkipSparse -and (-not $PerUser -or $SparseUser)
    if ($buildSparse) {
        $sparseSrc = Join-Path $PSScriptRoot 'sparse'

        $cert = $null
        if ($SigningCertThumbprint) {
            $cert = @(Get-ChildItem Cert:\CurrentUser\My |
                      Where-Object { $_.Thumbprint -eq $SigningCertThumbprint })[0]
            if (-not $cert) {
                throw "No certificate with thumbprint $SigningCertThumbprint in Cert:\CurrentUser\My"
            }
        } else {
            # Newest usable one wins if a previous certificate has been left
            # behind; identity is the subject, which they share.
            $cert = @(Get-ChildItem Cert:\CurrentUser\My |
                      Where-Object { $_.Subject -eq $SigningCertSubject -and $_.HasPrivateKey } |
                      Sort-Object NotAfter -Descending)[0]
        }

        if (-not $cert -and $CreateSigningCert) {
            # Self-signed, so end users have to be told to trust it - the MSI
            # imports it into TrustedPeople (LocalMachine, or CurrentUser for
            # -SparseUser). Swapping in a
            # CA-issued certificate later needs no change here or in the
            # manifest: only the subject string above, and only if it differs.
            $cert = New-SelfSignedCertificate -Type CodeSigningCert `
                        -Subject $SigningCertSubject `
                        -KeyUsage DigitalSignature `
                        -FriendlyName '7-ZSTar package signing (self-signed)' `
                        -CertStoreLocation Cert:\CurrentUser\My `
                        -NotAfter (Get-Date).AddYears(5) `
                        -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3')
            Write-Host "  cert  created $($cert.Thumbprint) ($SigningCertSubject)"
        }

        if (-not $cert -and $SparseUser) {
            # -SparseUser asks for nothing but the sparse package; quietly
            # dropping it would leave a "-user-sparse.msi" without one.
            throw ("-SparseUser: no signing certificate for '$SigningCertSubject' in " +
                   "Cert:\CurrentUser\My. Re-run with -CreateSigningCert, or drop -SparseUser.")
        }
        if (-not $cert) {
            Write-Warning ("No signing certificate for '$SigningCertSubject' in " +
                           "Cert:\CurrentUser\My - building without the sparse package. " +
                           "The MSI will register only the classic context menu, so on " +
                           "Windows 11 7-ZSTar stays under `"Show more options`". " +
                           "Re-run with -CreateSigningCert to make one.")
        } else {
            $SparseDir = Join-Path $PSScriptRoot "obj\sparse\$Platform"
            if (Test-Path $SparseDir) { Remove-Item $SparseDir -Recurse -Force }
            $pkgStage = Join-Path $SparseDir 'pkg'
            New-Item -ItemType Directory -Force (Join-Path $pkgStage 'Assets') | Out-Null
            Copy-Item (Join-Path $sparseSrc 'Assets\*') (Join-Path $pkgStage 'Assets') -Force

            # Publisher must equal the certificate subject byte for byte or
            # deployment fails; taking it from the certificate is what keeps
            # the two from drifting.
            $manifest = (Get-Content (Join-Path $sparseSrc 'AppxManifest.xml') -Raw).
                            Replace('%PUBLISHER%', [Security.SecurityElement]::Escape($cert.Subject)).
                            Replace('%VERSION%', $PkgVersion)
            if ($manifest -match '%[A-Z_]+%') {
                throw "Unsubstituted token $($Matches[0]) left in AppxManifest.xml"
            }
            [IO.File]::WriteAllText((Join-Path $pkgStage 'AppxManifest.xml'), $manifest,
                                    (New-Object Text.UTF8Encoding $false))

            $makeappx = Find-SdkTool 'makeappx.exe'
            $signtool = Find-SdkTool 'signtool.exe'
            $msixPath = Join-Path $SparseDir '7-ZSTar.msix'

            # /nv skips semantic validation: the manifest names files that are
            # deliberately not in the package (7zFM.exe, 7-zip.dll), which is
            # the whole point of an external-location package.
            # Output captured rather than discarded: both tools report what is
            # actually wrong (a malformed manifest, an unusable certificate) on
            # stdout, and swallowing it leaves only an exit code to go on.
            $toolOut = & $makeappx pack /d $pkgStage /p $msixPath /nv /o 2>&1
            if ($LASTEXITCODE -ne 0) {
                $toolOut | ForEach-Object { Write-Host "    $_" }
                throw "makeappx pack failed with exit code $LASTEXITCODE"
            }

            $toolOut = & $signtool sign /fd SHA256 /sha1 $cert.Thumbprint $msixPath 2>&1
            if ($LASTEXITCODE -ne 0) {
                $toolOut | ForEach-Object { Write-Host "    $_" }
                throw "signtool sign failed with exit code $LASTEXITCODE"
            }

            # The .cer travels with the MSI: the install-time custom action
            # imports this exact public key, so it cannot disagree with the
            # signature above.
            Export-Certificate -Cert $cert -FilePath (Join-Path $SparseDir '7-ZSTar.cer') -Type CERT | Out-Null

            Write-Host ("  sparse  7-ZSTar.msix $((Get-Item $msixPath).Length) bytes, " +
                        "signed by $($cert.Thumbprint)")
        }
    }

    # --- licence page ------------------------------------------------------
    #
    # WixUI's LicenseAgreementDlg reads RTF, and only RTF, through a RichEdit
    # control.
    #
    # What it shows is a summary: this product's licence and every component's,
    # component by component. It used to be the LGPL v3 and GPL v3 texts in
    # full, 47 KB of them, which is exactly the wall of legalese nobody reads -
    # and reading it would still not have answered "what is this package made
    # of". The full texts are not lost: LICENSE, COPYING, LICENSE-EXCEPTIONS.md,
    # LICENSE-7-Zip.txt and NOTICE are all installed with the program and are
    # in the .zip and the repository as well.
    #
    # Keep this list in step with LICENSE-EXCEPTIONS.md and NOTICE - those are
    # the authority; this is the readable digest of them.
    #
    # Deliberately the dumbest RTF that can express the text: one font, one
    # size, a \par per line. WiX documents that RichEdit renders elaborate RTF
    # (anything Word saved, typically) as a blank page on some Windows versions
    # - a failure that only shows up when a user is looking at the wizard.
    $rtfDir = Join-Path $PSScriptRoot 'obj'
    New-Item -ItemType Directory -Force $rtfDir | Out-Null
    $rtfPath = Join-Path $rtfDir 'License.rtf'

    $rtf = [Text.StringBuilder]::new()
    [void]$rtf.Append('{\rtf1\ansi\ansicpg1252\deff0')
    [void]$rtf.Append('{\fonttbl{\f0\fswiss\fcharset0 Segoe UI;}}')
    [void]$rtf.Append('\fs18 ')

    $body = @(
        '7-ZSTar - licence summary',
        '',
        '7-ZSTar is free software. It is an independent fork of 7-Zip by Igor',
        'Pavlov, and the program as a whole is distributed under the GNU Lesser',
        'General Public License, version 3.',
        '',
        'You can use it on any computer, including one in a commercial',
        'organisation. There is nothing to register and nothing to pay.',
        '',
        'Parts of the package carry their own terms:',
        '',
        '   RAR decompression - GNU LGPL plus the unRAR restriction: the code',
        '   may not be used to develop a RAR (WinRAR) compatible archiver.',
        '',
        '   LZFSE and the zstd decoder - BSD 3-Clause. Copyright (c) 2015-2016,',
        '   Apple Inc.; Copyright (c) Facebook, Inc.; Copyright (c) 2023-2026',
        '   Igor Pavlov.',
        '',
        '   XXH64 - BSD 2-Clause. Copyright (c) 2012-2021 Yann Collet;',
        '   Copyright (c) 2023-2026 Igor Pavlov.',
        '',
        '   The LZMA SDK and many other files from 7-Zip - public domain.',
        '',
        'The compression libraries bundled with it:',
        '',
        '   zstd - BSD 3-Clause. Copyright (c) Meta Platforms, Inc. and',
        '   affiliates. (Dual-licensed with GPLv2; the BSD branch is used.)',
        '',
        '   brotli - MIT. Copyright (c) 2009, 2010, 2013-2016 by the Brotli',
        '   Authors.',
        '',
        '   lz4 - BSD 2-Clause. Copyright (c) 2011-2020, Yann Collet.',
        '',
        '   lz5 - BSD 2-Clause. Copyright (c) 2011-2015, Yann Collet.',
        '',
        '   lizard - BSD 2-Clause. Copyright (C) 2011-2016, Yann Collet;',
        '   Copyright (C) 2016-2017, Przemyslaw Skibinski.',
        '',
        '   fast-lzma2 - BSD 3-Clause. Copyright 2018-present Conor McCarthy.',
        '   (Dual-licensed with GPLv2; the BSD branch is used.)',
        '',
        '   xxHash - BSD 2-Clause. Copyright (C) 2012-2023 Yann Collet.',
        '',
        '   zstdmt multithreading wrappers - BSD 2-Clause.',
        '   Copyright (c) 2016 - 2017, Tino Reichardt.',
        '',
        'The C++ code driving brotli, lz4, lz5, lizard and fast-lzma2 was',
        'ported from 7-Zip-zstd by Tino Reichardt, which is LGPL v2.1-or-later',
        'like 7-Zip itself. The translations and the help file come from',
        "7-Zip's binary release and are under its GNU LGPL.",
        '',
        'The full texts are installed with the program. To read them before',
        'installing anything, they are also in the portable .zip package and in',
        'the source repository:',
        '',
        # Not column-aligned with spaces: this is rendered in a proportional
        # font, where padded columns come out ragged.
        '   LICENSE - the GNU LGPL v3 text',
        '   COPYING - the GNU GPL v3 text, which the LGPL refers to',
        '   LICENSE-EXCEPTIONS.md - every exception above, file by file',
        "   LICENSE-7-Zip.txt - 7-Zip's own licence statement",
        '   NOTICE - third-party copyright notices',
        '')

    foreach ($line in $body) {
        # Order matters: the backslash escape has to run before the ones that
        # introduce backslashes, or it would double-escape them.
        $esc = $line -replace '\\', '\\' -replace '\{', '\{' -replace '\}', '\}'
        # Printable ASCII only. Anything else needs an RTF control word this
        # generator does not emit - \tab for a tab, \'xx for a high byte - so
        # fail the build rather than silently write an RTF that renders wrong.
        if ($esc -match '[^\x20-\x7E]') {
            throw ("Licence text contains a character this RTF generator " +
                   "cannot express (tab or non-ASCII): $line")
        }
        [void]$rtf.Append($esc + '\par' + "`r`n")
    }
    [void]$rtf.Append('}')
    # ASCII, not UTF-8: \ansi says the bytes are a single-byte codepage, and a
    # UTF-8 BOM at the front stops RichEdit recognising the file as RTF at all.
    [IO.File]::WriteAllText($rtfPath, $rtf.ToString(), [Text.Encoding]::ASCII)
    Write-Host "  license  $([math]::Round((Get-Item $rtfPath).Length / 1KB)) KB -> installer\obj\License.rtf"

    # --- one feature per language (generated) ------------------------------
    #
    # Custom setup lets you pick individual languages, which means one Feature,
    # one Component and one File element per .txt - 90-odd of each. Generated
    # into obj\ beside License.rtf rather than hand-maintained in the .wxs:
    # the list is upstream's and changes with every release we re-vendor.
    #
    # Titles are ASCII on purpose. The MSI string pool is a single-byte code
    # page (1252 here), so a native name like the Devanagari one three files
    # carry would not survive it. Each language file's first entry (id 0) is
    # product name / English name / native name; three translators appended
    # the native script to the English field ("Hindi, Indian, ..."), hence the
    # comma split.
    # Per-architecture name: the <File Source=...> paths below point into
    # stage\<arch>\, so two concurrent local builds for different architectures
    # would otherwise overwrite each other's fragment.
    $langWxs = Join-Path $rtfDir "Languages-$Platform.wxs"
    $xml = [Text.StringBuilder]::new()
    [void]$xml.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
    [void]$xml.AppendLine('<!-- GENERATED by installer\Build-Package.ps1. Do not edit; do not commit. -->')
    [void]$xml.AppendLine('<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">')
    [void]$xml.AppendLine('  <Fragment>')
    [void]$xml.AppendLine('    <FeatureGroup Id="LanguageFeatures">')

    $langTxt = @($LangFiles | Where-Object { $_.Extension -eq '.txt' } |
                 Sort-Object BaseName)
    $groups = [Text.StringBuilder]::new()
    foreach ($f in $langTxt) {
        # Feature/ComponentGroup ids allow letters, digits, underscore and dot.
        $id = 'Lang_' + ($f.BaseName -replace '[^A-Za-z0-9]', '_')

        $name = $null
        $head = Get-Content -LiteralPath $f.FullName -Encoding utf8 -TotalCount 40
        for ($i = 0; $i -lt $head.Count - 2; $i++) {
            if ($head[$i].Trim() -eq '0') { $name = $head[$i + 2].Trim(); break }
        }
        if ($name) { $name = (($name -split ',')[0] -replace '[^\x20-\x7E]', '').Trim() }
        if (-not $name) { $name = $f.BaseName }
        # &amp; first: the later replacements introduce ampersands of their own.
        # The quote matters because Title is written as an XML attribute - a
        # future re-vendor could bring a name containing one.
        $title = ("{0} ({1})" -f $name, $f.BaseName) `
                 -replace '&', '&amp;' -replace '<', '&lt;' -replace '"', '&quot;'

        [void]$xml.AppendLine(('      <Feature Id="{0}" Title="{1}" Level="1">' -f $id, $title))
        [void]$xml.AppendLine(('        <ComponentGroupRef Id="{0}_c" />' -f $id))
        [void]$xml.AppendLine('      </Feature>')

        [void]$groups.AppendLine(('    <ComponentGroup Id="{0}_c" Directory="LANGFOLDER">' -f $id))
        [void]$groups.AppendLine('      <Component>')
        [void]$groups.AppendLine(('        <File Source="{0}" KeyPath="yes" />' -f (Join-Path $StageLang $f.Name)))
        [void]$groups.AppendLine('      </Component>')
        [void]$groups.AppendLine('    </ComponentGroup>')
    }

    [void]$xml.AppendLine('    </FeatureGroup>')
    [void]$xml.AppendLine('  </Fragment>')
    [void]$xml.AppendLine('  <Fragment>')
    [void]$xml.Append($groups.ToString())
    [void]$xml.AppendLine('  </Fragment>')
    [void]$xml.AppendLine('</Wix>')
    [IO.File]::WriteAllText($langWxs, $xml.ToString(), (New-Object Text.UTF8Encoding $false))
    Write-Host "  features $($langTxt.Count) selectable languages -> installer\obj\$(Split-Path $langWxs -Leaf)"

    # --- Default Programs registration (generated) -------------------------
    #
    # Windows will not honour a ProgID that an application writes straight into
    # HKCU\Software\Classes\<ext> for a file type the machine already knows -
    # measured on 25H2: AssocQueryString(ASSOCSTR_PROGID, ".gz") answers
    # "Unknown" and Explorer draws the blank generic icon, while ".7z", set
    # through the Windows UI and carrying a hash-signed UserChoiceLatest,
    # resolves correctly. Only Windows itself can write that hash.
    #
    # So the supported route is Default Programs: advertise what we can open
    # and let the Settings UI do the assigning. That needs three things, and
    # all three are generated here rather than hand-written:
    #   * a real ProgID per format under HKCR, with its icon and open command,
    #     because Capabilities pointing at ProgIDs that do not exist gives a
    #     Settings page full of blanks;
    #   * our ProgID added to each extension's OpenWithProgids - additive, so
    #     it advertises without taking the file type from anyone;
    #   * Capabilities\FileAssociations plus the RegisteredApplications entry
    #     that makes 7-ZSTar appear as an app in Settings > Default apps.
    #
    # Deliberately NOT written: the default value of HKCR\.<ext>. Claiming file
    # types at install time is what the coexistence promise rules out, and on
    # Windows 11 it would not work anyway.
    #
    # The ext -> icon index map is read from the STRINGTABLE the shell
    # extension itself uses, so the installer cannot drift from the icons in
    # the DLL. docs/logo/icongen.py --install checks that same table.
    $rcPath = Join-Path $RepoRoot 'CPP\7zip\Bundles\Format7zF\resource.rc'
    $rcText = Get-Content $rcPath -Raw
    # Anchored to the start of a line so it cannot latch onto some other
    # literal 100 that happens to appear earlier in the file.
    if ($rcText -notmatch '(?m)^\s*100\s+"([^"]+)"') {
        throw "Could not read the extension/icon STRINGTABLE (entry 100) from $rcPath"
    }
    $assoc = [ordered]@{}
    foreach ($pair in ($Matches[1] -split '\s+')) {
        $ext, $idx = $pair -split ':'
        if ($ext -and $idx -match '^\d+$') { $assoc[$ext] = [int]$idx }
    }
    if ($assoc.Count -lt 20) { throw "Only $($assoc.Count) file types parsed from $rcPath; expected the full table" }

    $assocWxs = Join-Path $rtfDir "Associations-$Platform.wxs"
    $ax = [Text.StringBuilder]::new()
    [void]$ax.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
    [void]$ax.AppendLine('<!-- GENERATED by installer\Build-Package.ps1. Do not edit; do not commit. -->')
    [void]$ax.AppendLine('<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">')
    # The per-scope component GUIDs; this file is preprocessed on its own, so
    # it cannot see the defines 7-ZSTar.wxs includes.
    [void]$ax.AppendLine(('  <?include {0} ?>' -f (Join-Path $PSScriptRoot 'ComponentGuids.wxi')))
    [void]$ax.AppendLine('  <Fragment>')
    [void]$ax.AppendLine('    <ComponentGroup Id="Associations" Directory="INSTALLFOLDER">')

    # One component per concern rather than per file type: these values have no
    # independent lifetime, and 150-odd single-value components would bloat the
    # tables for nothing.
    [void]$ax.AppendLine('      <Component Id="AssocProgIds" Guid="$(var.AssocProgIdsGuid)">')
    $first = $true
    foreach ($ext in $assoc.Keys) {
        $x = ConvertTo-XmlAttr $ext
        $progId = "7-ZSTar.$x"
        $key = if ($first) { ' KeyPath="yes"' } else { '' }
        $first = $false
        [void]$ax.AppendLine(('        <RegistryValue Root="HKCR" Key="{0}" Type="string" Value="{1} Archive"{2} />' -f $progId, $x, $key))
        [void]$ax.AppendLine(('        <RegistryValue Root="HKCR" Key="{0}\DefaultIcon" Type="string" Value="[INSTALLFOLDER]7z.dll,{1}" />' -f $progId, $assoc[$ext]))
        # The quotes here are deliberate markup, not data, so they are written
        # as entities rather than passed through the escaper.
        [void]$ax.AppendLine(('        <RegistryValue Root="HKCR" Key="{0}\shell\open\command" Type="string" Value="&quot;[INSTALLFOLDER]7zFM.exe&quot; &quot;%1&quot;" />' -f $progId))
    }
    [void]$ax.AppendLine('      </Component>')

    [void]$ax.AppendLine('      <Component Id="AssocOpenWith" Guid="$(var.AssocOpenWithGuid)">')
    $first = $true
    foreach ($ext in $assoc.Keys) {
        $x = ConvertTo-XmlAttr $ext
        $key = if ($first) { ' KeyPath="yes"' } else { '' }
        $first = $false
        [void]$ax.AppendLine(('        <RegistryValue Root="HKCR" Key=".{0}\OpenWithProgids" Name="7-ZSTar.{0}" Type="string" Value=""{1} />' -f $x, $key))
    }
    [void]$ax.AppendLine('      </Component>')

    [void]$ax.AppendLine('      <Component Id="AssocCapabilities" Guid="$(var.AssocCapabilitiesGuid)">')
    [void]$ax.AppendLine('        <RegistryValue Root="HKMU" Key="Software\7-ZSTar\Capabilities" Name="ApplicationName" Type="string" Value="7-ZSTar" KeyPath="yes" />')
    $appDesc = ConvertTo-XmlAttr 'Archive manager with zstd, brotli, lz4, lz5, lizard and one-step tar.* support.'
    [void]$ax.AppendLine(('        <RegistryValue Root="HKMU" Key="Software\7-ZSTar\Capabilities" Name="ApplicationDescription" Type="string" Value="{0}" />' -f $appDesc))
    [void]$ax.AppendLine('        <RegistryValue Root="HKMU" Key="Software\7-ZSTar\Capabilities" Name="ApplicationIcon" Type="string" Value="[INSTALLFOLDER]7zFM.exe,0" />')
    foreach ($ext in $assoc.Keys) {
        $x = ConvertTo-XmlAttr $ext
        [void]$ax.AppendLine(('        <RegistryValue Root="HKMU" Key="Software\7-ZSTar\Capabilities\FileAssociations" Name=".{0}" Type="string" Value="7-ZSTar.{0}" />' -f $x))
    }
    # The entry that makes Settings list us at all.
    [void]$ax.AppendLine('        <RegistryValue Root="HKMU" Key="SOFTWARE\RegisteredApplications" Name="7-ZSTar" Type="string" Value="Software\7-ZSTar\Capabilities" />')
    [void]$ax.AppendLine('      </Component>')

    [void]$ax.AppendLine('    </ComponentGroup>')
    [void]$ax.AppendLine('  </Fragment>')
    [void]$ax.AppendLine('</Wix>')
    [IO.File]::WriteAllText($assocWxs, $ax.ToString(), (New-Object Text.UTF8Encoding $false))
    Write-Host "  assoc    $($assoc.Count) file types -> installer\obj\$(Split-Path $assocWxs -Leaf)"

    # --- build -------------------------------------------------------------
    #
    # Four bind paths, in the order WiX searches them. -ext needs the matching
    # `wix extension add -g <id>/<version>` to have been run once per machine.
    # Built as an array so the sparse-package inputs can be left out entirely
    # when there was no certificate to sign with: the .wxs gates its sparse
    # components on IncludeSparse (set by Sparse=1 or SparseUser=1), and
    # their Source files resolve through the extra bind path.
    $wixArgs = @(
        'build', (Join-Path $PSScriptRoot '7-ZSTar.wxs'), $langWxs, $assocWxs,
        '-arch', $Platform,
        '-d', "Version=$MsiVersion",
        '-d', "ProjectUrl=$ProjectUrl",
        '-d', "StageDir=$Stage",
        '-ext', 'WixToolset.UI.wixext/6.0.2',
        '-ext', 'WixToolset.Util.wixext/6.0.2',
        '-bindpath', $Stage,
        '-bindpath', $PSScriptRoot,
        '-bindpath', $rtfDir,
        '-bindpath', (Join-Path $RepoRoot 'CPP\7zip\UI\FileManager')
    )
    if ($PerUser) {
        $wixArgs += @('-d', 'PerUser=1')
    }
    if ($SparseDir) {
        if ($PerUser) {
            $wixArgs += @('-d', 'SparseUser=1', '-bindpath', $SparseDir)
        } else {
            $wixArgs += @('-d', 'Sparse=1', '-bindpath', $SparseDir)
        }
    }
    $wixArgs += @('-o', $msiPath)

    & $wixPath @wixArgs
    if ($LASTEXITCODE -ne 0) {
        throw ("wix build failed with exit code $LASTEXITCODE. If it could not " +
               "load an extension, run these once:`n" +
               "  wix extension add -g WixToolset.UI.wixext/6.0.2`n" +
               "  wix extension add -g WixToolset.Util.wixext/6.0.2")
    }

    $msiSize = [math]::Round((Get-Item $msiPath).Length / 1MB, 2)
    Write-Host "  msi  $([IO.Path]::GetFileName($msiPath))  ${msiSize} MB"
    if ($pkgFp) { Write-SourceStamp -StampPath (Get-SourceStampPath $msiPath) -Fingerprint $pkgFp }
}

$produced = @()
if (-not $SkipZip -and -not $PerUser) { $produced += [IO.Path]::GetFileName($zipPath) }
if (-not $SkipMsi) { $produced += $msiLeaf }

if ($produced.Count -eq 0) {
    Write-Host "staging only - no artifacts produced"
} else {
    Write-Host "done ($($produced -join ', ')) -> $OutputDir"
}
