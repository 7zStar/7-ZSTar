# Installing 7-ZSTar

The details behind the short version in the [README](../README.md): system requirements, the
SmartScreen warning, Smart App Control and how to check a download, the three packages, the Windows 11 right-click
menu, file associations and uninstalling.

## System requirements

**Windows 7 or Windows Server 2008 R2, x64 or x86. On arm64, Windows 10.**
Nothing else is needed: the C runtime is linked statically (`-MT`), so the
binaries import nothing but Windows' own DLLs - no redistributable, no .NET.

That floor is *derived* from what the packages require, not measured: nothing
older than Windows 11 has been tested here. It is also higher than upstream
7-Zip's, whose binaries still load on Windows XP. Three things put it there,
and the second is the one no build setting can undo:

- The `.msi` declares `InstallerVersion="500"`, and Windows Installer 5.0
  shipped "with Windows Server 2008 R2 and later and Windows 7 and later"
  ([Microsoft][msi-versions]). The portable `.zip` does not go through
  Windows Installer, but see the next two points.
- **zstd and fast-lzma2 use Vista-only synchronisation.** Both force
  `_WIN32_WINNT 0x0600` in their own headers and call
  `InitializeConditionVariable` / `SleepConditionVariableCS` directly, so
  `7z.dll` and `7za.exe` - the two binaries with the codecs compiled in -
  import four functions that Windows XP and Server 2003 do not have.
  Upstream's `7z.dll` imports none of them.
- The toolchain: these are built with Visual Studio 2022, whose supported
  target list is Windows 7 and later - Vista and Server 2008 are "No"
  ([Microsoft][vs-targeting]). The linked subsystem version is 6.0 on x64 and
  x86 and 6.2 on arm64, and Windows on arm64 begins at Windows 10 regardless.

Windows Vista and Server 2008 land in between: the binaries would load, but
the toolchain does not support them, the installer will not run there, and
7-ZSTar is not tested on them.

**Linux is supported as a command-line build only; macOS is not supported.**
The fork builds a native `7zz` (the `Alone2` console program) with gcc through
its own makefile, which includes upstream's and modifies none of them:
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
It has been built and tested only on Ubuntu 24.04 with gcc 13.3 (x86-64): the
build is warning-free under upstream's flags, the 77-check smoke test passes,
and the 25 Windows-made and 37 Linux-made interop vectors give the same
verdicts as on Windows. The two fork-owned files the port touched still build
unchanged on Windows (clean x64 build, smoke tests and interop read-back all
pass). There is no GUI. Upstream's other Linux targets (`7za`, `7zr`, `7z.so`)
are not supported: their gcc object lists lack what the fork's changes to the
upstream handlers need, so they are expected to fail to link. Other
architectures, distributions and compilers have not been verified, and macOS
has never been built, so no `MACOSX_DEPLOYMENT_TARGET` can be stated. Build
steps, tests and known limits are in `build/linux/README.md`;
interoperability with Linux tools is in `test/interop/REPORT.md`.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## Unsigned packages, SmartScreen and Smart App Control

**The installers and programs in a 7-ZSTar release are not code-signed by a
certificate authority**, and this project holds no code-signing certificate.
Windows therefore cannot tell who published the file, and when you run the
`.msi`, or a program from the `.zip`, for the first time, Microsoft Defender
SmartScreen may stop it with a warning. Microsoft's developer documentation
lists "No signature" as one of the cases that show a warning titled "Windows
protected your PC", where the user has to choose "Run anyway" before the app
runs ([Microsoft][smartscreen-rep]). Enterprise policy can remove that choice
altogether; on such a PC, ask whoever manages it.

The one thing in a release that *is* signed is the small package that puts
7-ZSTar on the first level of the Windows 11 right-click menu, inside the
all-users `.msi`. Its certificate is self-signed and generated while that one
package is built, so it is not a certificate authority's signature and says
nothing about who built the package; see [the Windows 11 right-click
menu](#the-windows-11-right-click-menu) for what it does and how to decline it.

The warning is not proof that a file is bad, and its absence would not be proof
that a file is good. What you can check yourself is that your copy is exactly
the one published on the release page. Every release carries a file called
`SHA256SUMS`: one line per package, a SHA-256 hash followed by the file name.

1. Download the package and `SHA256SUMS` from the same release page, into the
   same folder.
2. Open PowerShell in that folder and compare. Replace the name with the file
   you downloaded:

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True` means the hashes are identical. To look at them yourself instead, run
   `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi` and find the same
   file name in `SHA256SUMS`; the comparison ignores upper and lower case.
3. If you get `False`, or the file name is not in `SHA256SUMS`, do not run it:
   delete the file and download it again. If it still does not match, please
   report it as described in [SECURITY.md](../SECURITY.md).

`SHA256SUMS` only covers the files uploaded to that release. Building the same
tag yourself gives different hashes (the right-click menu package is signed
with a new certificate on every build), and the source code is published with
every release if you would rather build it: see [build/README.md](../build/README.md).

Once the hashes match and you are happy with where the file came from:

- **`.msi`** - start it as usual. If SmartScreen stops it, choose the option to
  run it anyway ("Run anyway" on an English-language Windows; the warning
  window may need to be expanded first). The all-users `.msi` then asks for
  administrator approval like any other installer.
- **`.zip`** - extract it and start `7zFM.exe` or `7z.exe` from the folder. The
  programs inside are unsigned as well, so Windows may show the same warning the
  first time you start each one.

SmartScreen warns on how well known a file is, not only on signatures; a file
that has been downloaded by few people can trigger it even when signed. Nothing
here changes that, and nothing in the steps above turns SmartScreen off.

### Smart App Control on Windows 11

Some Windows 11 PCs have a stricter protection called **Smart App Control**
switched on. When it is on, Windows blocks unsigned files unless Microsoft's
cloud service can vouch for them, and a new release usually has no such record
([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). Unlike the SmartScreen
warning, the block has no option to run the file anyway, and Microsoft's FAQ says
there is no way to bypass Smart App Control for an individual app.

What happened when 7-ZSTar 26.05.1 was tried on Windows 11 Pro 25H2 (build
26200.8037) with Smart App Control turned on:

- **The `.msi` installers were blocked**, the all-users one and the per-user one
  alike. On a Traditional Chinese Windows, Windows Installer said
  「系統禁用此安裝。請連絡系統管理員。」, and a Windows Security notification said
  that Smart App Control had blocked the file because Windows could not tell who
  published it and it is not an app Windows knows. There was no option to
  continue, and `msiexec /i ... /qn` returned error 1625. The wording on an
  English-language Windows has not been checked.
- **A program from the `.zip` ran.** `7zFM.exe`, extracted from the portable
  `.zip`, started normally in the same test. Whether Windows lets an unsigned
  program run is its own judgement of that file, so this may be different on
  your PC.
- Just after Smart App Control was switched on, the `.msi` installed for a few
  minutes before it began to be blocked. The cause was not found, so a success
  right after switching it on does not mean the installer is allowed.

So on a PC where Smart App Control is on, **the installers cannot be installed**,
and checking `SHA256SUMS` does not change that. What does is turning Smart App
Control off in the Windows Security app's Smart App Control settings (on the
Traditional Chinese Windows tested: Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定).
In the test, choosing the off option took effect at once with no restart, and
the installers then installed. This is a setting for the whole PC and nothing
here asks you to change it: it is yours to decide, or your administrator's on a
managed PC.

Whether it can be turned back on is also worth knowing first. Microsoft's FAQ
says recent Windows updates allow Smart App Control to be turned on again
without a clean installation of Windows, so on a version without them, turning
it off may be permanent. On the build tested here the option to
turn it on was still offered after turning it off; that is a test result, not a
promise about your version.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## Installing

Three packages, all built by `installer\Build-Package.ps1` (the per-user one
with `-PerUser`):

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| Installs for | every account | the installing account | - |
| Explorer right-click menu | yes | yes, classic menu only ([below](#the-per-user-package)) | no |
| Start menu entry | yes | yes | no |
| Needs administrator | yes | no | no |
| Removal | Apps & features | Apps & features | delete the folder |

Use the packages that match Windows itself: x86 on 32-bit Windows, x64 on
64-bit Windows, arm64 on Windows on Arm (the arm64 packages are built but have
never been run). The x86 shell extension is 32-bit and 64-bit Explorer cannot
load it, so on 64-bit Windows the x86 `-user.msi` has no right-click menu at
all, and the x86 `.msi` has one only on Windows 11 and only for accounts that
registered its Windows 11 package (the installing one, or one that ran
`-Register`, below).

The MSI installs to `Program Files\7-ZSTar` - always: unlike the per-user
package it offers no choice of folder, and ignores `INSTALLFOLDER` on the
command line, because that folder holds a script the installer runs as SYSTEM
and a DLL every user's Explorer loads, and a folder made elsewhere (under
`C:\`, say) is writable by every user. It registers its own shell
extension CLSID and its own `Software\7-ZSTar` registry hive, and names every
context-menu key `7-ZSTar` - so it neither collides with nor removes official
7-Zip's. See [installer/GUIDS.md](../installer/GUIDS.md).

It runs a normal install wizard - welcome, licence, setup type, optional
feature tree, finish - and installing quietly still works unchanged
(`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`), because msiexec skips the
whole UI sequence in quiet mode.

### The Windows 11 right-click menu

On Windows 11 the entry is in the first-level menu, not buried under *Show
more options* where official 7-Zip and WinRAR still sit. Windows 11 only lists
a shell extension there when it comes with package identity, so the MSI ships
a small identity-only MSIX package next to the program and registers it during
install. The classic registration is kept as well, which is what keeps the
entry working on Windows 10 and for anyone who has restored the old context
menu.

That package is signed with a **self-signed certificate**, and the installer
puts it in `LocalMachine\TrustedPeople` - Windows will not deploy a package
whose signature it cannot chain to something trusted. Uninstalling removes the
certificate along with the package.

If you would rather not trust a self-signed certificate, decline just that
part and keep everything else:

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

You then get the same behaviour as Windows 10: 7-ZSTar is in the right-click
menu, under *Show more options*. To turn it on later, or to undo it after a
normal install:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

Trusting that certificate means Windows will also accept **any other** package
signed with the same key without warning. It is only ever used for this one
package, and uninstalling takes it back out, but that is what you are agreeing
to - `SPARSE=0` above is the way to decline it.

Package registration is per user, and the installer only runs it for whoever
installed. Two consequences:

- A second account on the same machine gets the classic menu only, until it
  runs that same script with `-Register`.
- Uninstalling only unregisters it for whoever uninstalls. If someone else
  registered it, their registration outlives the uninstall and points at a
  folder that is no longer there; that account clears it with
  `Get-AppxPackage 7-ZSTar | Remove-AppxPackage`.

**Known limitation: the first-level menu is only registered when the install
runs in an interactive, signed-in session.** Installing the all-users `.msi`
from a remote or non-interactive session - over SSH, or a silent deployment
from a management tool - still reports success, but the Windows 11 package is
not registered, so only the classic menu under *Show more options* appears. In
the test, `msiexec /i ... /qn` from an SSH session (session 0) exited with 0
while `Setup-ShellIntegration.ps1` reported `registration failed: 0x80070005`
(access denied); the same `.msi` installed from an administrator's console
session registered normally.

`-Status` prints what is and is not in place.

### The per-user package

`7-ZSTar-<version>-<arch>-user.msi` installs for the current account only, into
`%LOCALAPPDATA%\Programs\7-ZSTar`, with no UAC prompt. Everything it registers
goes under `HKCU`; the package writes nothing to `HKLM` (Windows Installer's own
bookkeeping aside). What it does not do the way the per-machine package does:

- **No Windows 11 first-level menu.** 7-ZSTar is in the right-click menu, under
  *Show more options*. The first-level entry needs the self-signed certificate
  trusted machine-wide, which takes an administrator: measured on Windows 11, a
  certificate in `CurrentUser\TrustedPeople` is not enough for Windows to
  deploy the package. So the per-user package leaves it out.
- **One of the two per machine.** Each package refuses to install while the
  other one is installed; uninstall one before installing the other. The
  per-machine package can only see the per-user copy of the account running
  it, so another account's per-user install is not detected.
- **Group policy can hide its menu.** Where `EnforceShellExtensionSecurity` is
  set, Explorer loads only shell extensions listed under the machine-wide
  *Approved* key, which a per-user install cannot write, so the right-click
  menu does not appear. Use the per-machine package there.
- **Clearing a format in Tools > Options > System also removes 7-ZSTar's offer
  for it.** When you clear a format there (click its cell until it is empty,
  then OK), the file manager deletes the whole
  `HKCU\Software\Classes\.<ext>` and `7-ZSTar.<ext>` keys - and for a per-user
  install those keys also hold what the package registered for Settings >
  Apps > Default apps and the *Open with* list. 7-ZSTar then drops out of
  *Open with* for that format, and Default apps shows a blank entry for it.
  Repairing the install puts it back (run the `.msi` again and choose
  *Repair*). Better, assign file types in Default apps rather than in the file
  manager. The per-machine package has the same weak spot in one place,
  described under file associations below.

### File associations, and what uninstalling does to them

**Set them in Settings > Apps > Default apps.** Type 7-ZSTar, and every format
it can open is listed there to assign. The installer registers 7-ZSTar as a
Default Programs application - a ProgID per format with its icon and open
command, an entry in each extension's *Open with* list, and the Capabilities
block Windows reads - but it deliberately claims no file type: which program
opens your archives is your decision, and it is what keeps 7-ZSTar and official
7-Zip out of each other's way.

**Tools > Options > System in the file manager mostly does not work on
Windows 11**, and that is a Windows rule rather than a bug here. It writes a
`7-ZSTar.<ext>` ProgID into `HKCU\Software\Classes`, and for any extension the
machine already knows - every archive format does - Windows ignores it:
`AssocQueryString` answers `Unknown` and Explorer draws the blank generic icon.
What Windows honours instead is a `UserChoice` key stamped with a hash only it
can compute, which is why the Settings UI is the only route. No application can
write one: not 7-ZSTar, not 7-Zip, not any installer.

**Clearing a format in its *All Users* column removes the per-machine
package's own registration for it.** That column writes
`HKLM\Software\Classes`, where the per-machine package keeps the ProgIDs and
*Open with* entries it advertises, and clearing a format there (which needs the
file manager run as administrator) deletes those keys whole - for every
account. Repairing restored the same keys for the per-user package; for this
one it was not measured.

**An icon that stays blank after changing anything** may also be Explorer's
icon cache, which does not notice that a DLL it already cached has been
replaced; `ie4uinit.exe -show` does not reliably clear it. Close Explorer,
delete `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db`, start it
again.

**Uninstalling removes the associations it can reach** - the `7-ZSTar.*`
ProgIDs belonging to whoever is uninstalling, and only the file types still
pointing at them, so a format handed to another program in the meantime is left
alone. Uninstalling the per-machine package also leaves alone a ProgID that
opens a copy of 7-ZSTar somewhere else that still exists - a portable one from
the `.zip`, set up with that copy's own **Tools > Options > System**. The
per-user package cannot: its ProgIDs are those same `HKCU` keys (see *The
per-user package* above), and uninstalling it removes them whoever wrote them
last. Leaving them behind would point those types at a ProgID whose icon and
command are a deleted executable, which is a blank icon and an error on
double-click. Other accounts' associations are out of reach; they can clear
their own with `Setup-ShellIntegration.ps1 -RemoveAssociations` before the
program goes. `msiexec /x ... KEEPASSOC=1` skips this, and an upgrade never
does it.

**Known limitation: other accounts keep the associations they set themselves.**
Uninstalling the per-machine package clears only what the account running the
uninstall set in its own column (headed with the account name) under
**Tools > Options > System** in the file manager. Any other account that set
associations there keeps them, pointing at the removed program, so
double-clicking a `.7z` file asks Windows which program to use. Each account
should clear its own **before** the uninstall, with

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

which removes only 7-ZSTar's entries, or afterwards assign the types again
under Settings > Apps > Default apps. Doing it in the file manager instead
means clicking each cell in its own column that shows 7-ZSTar until it is
empty, then OK; do not select all rows and press "+", which applies one state to every
selected row and so also clears formats that belong to another program, such
as official 7-Zip.

Associations set in the **All Users** column are not touched by the uninstall
clean-up at all, and are left pointing every account at the removed program.
An administrator who set any should clear those cells, from a file manager run
as administrator, then OK, before uninstalling; `-RemoveAssociations` does not
reach this column. Clearing it right before an uninstall is harmless even
though it deletes the package's own registration there (above), since the
uninstall removes that anyway. The per-user package does not have the
other-accounts problem, and official 7-Zip behaves the same way.

## Languages

Every package carries upstream's translations, 90-odd languages. Pick one under
**Tools > Options > Language**; the MSI also lets you leave them out under
*Custom* setup. 7-ZSTar tries to follow the system language on first run, but
that detection gives up and stays English when Windows' "language for
non-Unicode programs" and the regional format setting disagree - choosing a
language by hand always works.

Strings 7-ZSTar added itself - the zstd level and dictionary fields, the new
archive format names - have no upstream translation and stay English. The
exception is the About dialog's **Donate** and **Website** buttons: 67 of the
92 languages have a word for each, and the other 25 show English
(`Lang/UPSTREAM.md` lists them).
Translations are vendored, not written here: see [Lang/UPSTREAM.md](../Lang/UPSTREAM.md).
