# 7-ZSTar build

## Prerequisites

- Visual Studio 2022 Build Tools (or full VS) with **MSVC v143** (x64/x86).
- Windows SDK (installed with the above; provides rc.exe).
- No NASM/YASM needed: 7-Zip's x86/x64 asm uses MASM (ml64/ml, shipped with MSVC).
- **arm64 needs two components, not one:**
  - `Microsoft.VisualStudio.Component.VC.Tools.ARM64` - MSVC v143 ARM64 build tools
  - `Microsoft.VisualStudio.Component.VC.Llvm.Clang` - C++ Clang for Windows

  The second one is easy to miss. `Asm/arm64/LzmaDecOpt.S` is GNU-syntax
  assembly, and upstream's arm64 makefile assembles it with `clang-cl`, not
  armasm64 - without Clang the arm64 build fails on the very first target with
  `'clang-cl' is not recognized`. Install both with:

  ```powershell
  $vsi = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe"
  $path = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools"
  # Quote the path: Start-Process joins array arguments with spaces without
  # quoting them, and vs_installer would otherwise see only "C:\Program".
  Start-Process $vsi -Wait -Verb RunAs -ArgumentList @(
      'modify', '--installPath', "`"$path`"",
      '--add', 'Microsoft.VisualStudio.Component.VC.Tools.ARM64',
      '--add', 'Microsoft.VisualStudio.Component.VC.Llvm.Clang',
      '--quiet', '--norestart')
  ```

  GitHub's `windows-2022` runner already has both, so CI needs no extra step.

## Build

```powershell
pwsh build\Build.ps1                    # all 17 targets, x64
pwsh build\Build.ps1 -Platform x86      # cross-build x86 (host x64)
pwsh build\Build.ps1 -Platform arm64    # cross-build arm64 (needs ARM64 component)
pwsh build\Build.ps1 -Targets Alone7z   # single bundle (suffix match)
pwsh build\Build.ps1 -Clean             # wipe per-target <Platform>\ output dirs first
pwsh build\Build.ps1 -KeepGoing         # do not stop at first failure
```

Per-target logs: `build\logs\<Platform>\<Target>.log`.
Binaries land in `<target-dir>\<Platform>\` (e.g. `CPP\7zip\UI\Console\x64\7z.exe`).

The date in the About dialog and the console banners comes from `C\7zBuildDate.h` (not
tracked), which `Build.ps1` keeps at the build date. Without that header they show
upstream's release date, as the Linux `7zz` does: the Linux build has no such step.

## Test

```powershell
pwsh build\Test-Smoke.ps1                 # functional suite against the x64 build
pwsh build\Test-Smoke.ps1 -BinDir <dir> -SkipFreshnessCheck   # or against an unpacked release (it has no stamp)
```

`-BinDir` tests that directory as it is: its `7z.exe` and its own `7z.dll`
(missing one is an error), with nothing copied in. Only the default, the
Console build output, borrows `Format7zF`'s `7z.dll`.

Round trips every codec, checks that one-step `tar.*` archives really drill
down to their contents rather than showing a bare `.tar`, cross-checks against
Windows' bundled bsdtar, and asserts the registered format count stays under
the compiled-in ceiling. Exits non-zero on any failure; CI gates on it.

Runs against x64 and x86 (32-bit binaries execute on an x64 host through
WOW64). arm64 is cross-built and cannot be executed here, so it is verified
by compiling and packaging only.

The script imports the VC environment via
`VC\Auxiliary\Build\vcvarsall.bat <x64|x64_x86|x64_arm64>` and then runs
`nmake /NOLOGO PLATFORM=<plat>` in each target directory (the platform is passed
explicitly on the nmake command line; `CPP/Build.mak` selects ml64/ml/armasm64
from it). On Build Tools installs vcvarsall prints a harmless
`'vswhere.exe' is not recognized` line; ignore it.

## Freshness stamps

A binary or package built from yesterday's source looks exactly like one built
from today's. So the producers record which source they were made from, and the
consumers refuse anything that no longer matches:

| Producer | Writes | Consumers that check it |
|---|---|---|
| `build\Build.ps1` | `<target>\<Platform>\.srcstamp` for each target that built | `installer\Build-Package.ps1` (the six binaries it packs), `Test-Smoke.ps1`, `Test-Interop.ps1` |
| `installer\Build-Package.ps1` | `<file>.srcstamp` beside each `.msi` / `.zip` | `installer\Test-MsiRegistry.ps1`, `installer\Test-SparseIntegration.ps1` |

The stamp is a content fingerprint of the **work tree** (uncommitted edits and
new untracked files count; untracked files that `.gitignore` matches do not,
while tracked ones count even where it matches), not a commit id:
binaries cover `C`, `CPP`, `Asm`; packages add `installer` (except `Test-*.ps1`
and `GUIDS.md`), `Lang`, `Help` and the documents `Build-Package.ps1` packs.
Nothing outside those paths is read, and a change outside them (the website, `docs\`,
`build\`) leaves artifacts fresh. The root `README.md` and `CHANGELOG.md` are
packed, so editing them stales the packages but not the binaries; the codec
READMEs under `C\` are part of the binary set and stale both.

A target's stamp lists one file: the one its makefile names on its literal
`PROG = <file>` line (`Get-TargetArtifact` in `SourceStamp.ps1`), with its
length and SHA256. Anything else in the output directory is left out - notably
the `7z.dll` that `Test-Smoke.ps1` and `Test-Interop.ps1` copy from `Format7zF`
into the Console directory - and a consumer handed such a file refuses it as
"not listed in its stamp". To check `7z.dll`, check
`CPP\7zip\Bundles\Format7zF\<Platform>\7z.dll`. A makefile without exactly one
literal `PROG` line stops `Build.ps1`; a target that built but left no `PROG`
file gets a warning and no stamp.

A mismatch, a missing stamp (anything built before the stamps existed
included), or a file whose length or SHA256 differs from what the stamp lists
(an old build copied back over a new one, even with its old modification time
kept) makes the consumer throw. The fix is to rebuild.

`Build-Package.ps1` checks the six binaries, copies them into its staging
directory, then holds each copy to the stamp it checked: if a binary's
`.srcstamp` changed in between, or a staged copy's length or SHA256 differs
from what that stamp lists, it throws ("Package again"). A package stamp thus
vouches for the bytes that were packed - and `Build-Package.ps1` must not run
alongside `Build.ps1` on the same tree. `Test-SparseIntegration.ps1` checks
before its UAC prompt; the elevated copy it relaunches does not check again,
but installs only an `.msi` with the exact length and SHA256 the first run saw
(handed over through a one-time file in `-OutDir`). No parameter declares the
check done; `-SkipFreshnessCheck` stays the only way past, and it is logged.

Two things that trip people: after `Build.ps1 -Targets X` only X is stamped
current, so a consumer that reads other targets (`Test-Smoke` reads the console,
`Format7zF` and `FileManager` outputs) refuses until those are rebuilt too; and
`Test-MsiRegistry.ps1` with no `-Msi` checks every `.msi` in `installer\dist`, so
one stale or unstamped package there stops the run - pass `-Msi` for one file,
or rebuild all platforms.

`-SkipFreshnessCheck` on any consumer lets one through on purpose (an unpacked
release, a downloaded `.msi`): it warns and appends a line to
`build\logs\freshness-skips.log`. `Build-Package.ps1` writes no stamp beside
packages it cut with the check skipped.

For anything that picks artifacts up outside these scripts - a VM acceptance run
copying an `.msi` to a guest, say - gate on the exit code:

```powershell
pwsh build\Assert-Fresh.ps1 installer\dist\7-ZSTar-26.05.1-x64.msi   # 0 fresh, 1 stale/unverifiable, 2 the check itself failed
pwsh build\Test-SourceStamp.ps1                                       # the check's own tests
```

CI runs `Test-SourceStamp.ps1` on the x64 leg of `.github/workflows/build.yml`
(pushes to `main` and pull requests), before the build; `release.yml` does not
repeat it.

What a stamp does **not** prove: that nmake rebuilt everything it should have.
It proves `Build.ps1` ran on this source. For edits nmake is known to miss
(headers pulled in by `.rc` files, precompiled headers) use `Build.ps1 -Clean`.

## Targets (17)

| Directory (under CPP\7zip) | Output |
|---|---|
| Bundles\Alone7z | 7zr.exe (7z-format-only CLI; smallest, toolchain canary) |
| Bundles\Alone | 7za.exe |
| Bundles\Alone2 | 7zz.exe |
| Bundles\Format7z | 7za.dll |
| Bundles\Format7zExtract | 7zxa.dll |
| Bundles\Format7zExtractR | 7zxr.dll |
| Bundles\Format7zF | 7z.dll (full formats; ships with 7z.exe/7zFM/7zG) |
| Bundles\Format7zR | 7zra.dll |
| Bundles\Fm | 7zFM.exe (standalone variant; not shipped) |
| Bundles\LzmaCon | lzma.exe |
| Bundles\SFXCon | 7zCon.sfx (built, NOT shipped in releases) |
| Bundles\SFXSetup | 7zS.sfx (built, NOT shipped in releases) |
| Bundles\SFXWin | 7z.sfx (built, NOT shipped in releases) |
| UI\Console | 7z.exe |
| UI\Explorer | 7-zip.dll (shell extension) |
| UI\FileManager | 7zFM.exe (standard, uses 7z.dll) |
| UI\GUI | 7zG.exe |

SFX modules stay buildable but are excluded from release packages by design:
"stub exe + appended payload" self-extractors are the primary antivirus
false-positive trigger this project exists to avoid.

## Baseline record (2026-08-02)

- Toolchain: VS2022 Build Tools 17.14.35 (June 2026), MSVC 14.44.35207, host x64.
- Upstream 7-Zip 26.02 (commit f9d78af, unmodified): all 17 targets built OK,
  192.8 s total on the reference machine.
- Functional check with the freshly built 7z.exe + 7z.dll:
  - `.7z` create/extract roundtrip: 3 files, SHA-256 all match.
  - `.tar.zst` (bsdtar 3.8.4 / libzstd 1.5.7): `7z l` shows Type=zstd,
    extract yields `t.tar`; extracting that tar reproduces all 3 files,
    SHA-256 all match. (Two-step at that point; one-step extraction came later.)
