# 7-ZSTar Changelog

## 26.05.1 (2026-11-09)

Fork of 7-Zip 26.05 (commit
[b88c6bc](https://github.com/ip7z/7zip/commit/b88c6bc09339de32f7d18bbab900686b244f42ba)
in ip7z/7zip, 2026-10-21). The fork began at 26.02 (commit
[f9d78af](https://github.com/ip7z/7zip/commit/f9d78aff31a5f2521ae7ddbdc97c4a8855808959)
in ip7z/7zip, 2026-06-25).

- **`Add to <name>.tar.zst` in the right-click menu**, above `Add to <name>.7z`:
  one click, no dialog. The three email items now default to off; tick them
  under Tools > Options > 7-ZSTar to bring them back. If you have saved those
  options before, your saved choice stands, so turn the new item on there.
  `.tar.zst` has no update, so a second click on the same target shows an error
  and leaves the archive as it is; delete it first to make a new one.
- **About dialog.** The date there and in the console banners is now the
  build date, each copyright holder has its own line with its own years, and
  there are two buttons: **Website** opens the project's website, and the new
  **Donate** opens its donation section. Both labels are translated in 67 of
  the 92 languages (the words are in `Lang/donate.json`, written into the
  language files by `Lang/rebrand.py --inject-only`); the other 25 show
  English.
- **A Donate section in the README, which now comes in ten languages.** It
  says 7-ZSTar stays free to use and that a donation buys no features, help or
  promises. The README is now also in German, French, Spanish, Brazilian
  Portuguese, Japanese, Vietnamese and Esperanto, beside English and
  Traditional and Simplified Chinese. `.github/FUNDING.yml` makes GitHub link
  the website's donation section from the repository's Sponsor button.
- **Unsigned packages are now documented.** `docs/INSTALL.md` says that the
  packages are not code-signed, what SmartScreen and Smart App Control do
  about that, and how to check a download against `SHA256SUMS`. `SECURITY.md`
  says how to report a vulnerability privately.
- **Now based on 7-Zip 26.05** (26.03, 26.04 and 26.05 merged in).
  Brings upstream's fixes for CVE-2026-58052 (a crafted RAR5 archive could
  strip the Mark-of-the-Web from what it extracted, so SmartScreen never saw
  the download) and CVE-2026-104086 (SquashFS listings could return
  uninitialised memory as user and group ids), both fixed in 26.03, plus the
  further "bugs and vulnerabilities" 26.04 and 26.05 fixed without numbering
  them. The translations and the help file were re-vendored from 26.05's
  binary release: Lithuanian and Slovak picked up new strings, and the help
  file changed; upstream's licence statement did not. Japanese now keeps
  upstream's CRLF line endings, as every other vendored translation keeps
  upstream's bytes.
- **brotli 1.2.1** (was 1.2.0): fixes CVE-2026-111497, an out-of-bounds write
  in the brotli decoder that a crafted stream could trigger - opening a `.br`
  or `.tbr` file, or a `.7z` that uses the Brotli method, reached it. Such a
  stream is now rejected with a data error.
- **Fixed a use-after-free when extracting a standalone `.lz4`, `.lz5`,
  `.liz` or `.br` file**: the handler read the output size from a stream it
  had already released. Found and fixed in 7-Zip-zstd (gh-562); ported here
  as the reordering alone.
- **fast-lzma2 and lizard pick up their upstreams' unreleased fixes**: two
  compression-side out-of-bounds accesses in fast-lzma2's match finder and
  match table, and lizard's output-bound check for a 1-byte block. Neither
  project has a release after the versions vendored here (fast-lzma2 1.0.1,
  lizard 2.1), so the commits are applied as they are; `C/*/UPSTREAM.txt`
  lists them.
- **Clearer errors for broken `.lz4`, `.lz5`, `.liz` and `.br` files.** A
  truncated file now reports *Unexpected end of data* and a corrupt one
  *Data Error*, where lz4/lz5/lizard used to say *Unspecified error*; inside
  a `.7z`, data errors in these four methods report *Data Error* too. Every
  such file already failed - this only names the reason. Taken from
  7-Zip-zstd's #564, with the results mapped to 7-Zip's own conventions
  rather than that fork's. A truncated one-step `.tar.lz4`/`.tar.lz5`/
  `.tar.liz`/`.tar.br` used to extract nothing and say *Data Error*: the
  fallback to extracting the inner `.tar` as one file started reading where
  the failed one-step attempt had stopped. It now starts from the
  beginning, recovers what was decoded before the cut and says *Unexpected
  end of data*. How much that is depends on the codec: lz4, lz5 and lizard
  write decoded data in whole blocks, so a file cut inside its first block
  still yields nothing.
- **A truncated `.br` file keeps what was decoded before the cut.** It used
  to drop up to about 16 MiB of data it had already decoded, so a short
  truncated file gave nothing at all. It still reports *Unexpected end of
  data*.
- **Multi-threaded lz4, lz5, lizard and brotli streams no longer allocate
  whatever their frame headers ask for.** A frame header claiming more than
  about 256 MiB (packed or unpacked) is now a *Data Error*; a few bytes of
  header used to make each decoding thread try to allocate gigabytes.
  7-ZSTar and 7-Zip-zstd write at most 4 MiB per frame (brotli 11 MiB), so
  only files made with zstdmt's command-line tools and `-b` over 256 are
  refused. `.zst` is not affected.
- **The 7-ZSTar context menu shows next to official 7-Zip's.** With both
  installed, Explorer's classic menu used to show only "7-Zip", because the
  two shell extensions used the same command verbs (`SevenZip…`). 7-ZSTar's
  verbs now start with `SevenZSTar`.

- **zstd compression** (upstream 26.02 ships decompression only): standalone
  `.zst` archives and `-m0=zstd` inside `.7z`. Encoder implements the API
  surface upstream has already stubbed out; `.7z` coder id is
  7-Zip-zstd-compatible (0x4F71101); the WinZip id (0x4015D) is accepted on
  decode. Full GUI options (level, dictionary, chain dictionary, threads,
  memory estimate) enabled from upstream's stubbed CompressDialog code.
- **One-step `tar.zst` creation**: pick `tar.zst` in the compress dialog (or
  `-ttar.zst` on the command line) and multiple files become a single
  `.tar.zst` in one pass - no intermediate `.tar` on disk (streamed pipe,
  constant memory). Known limitation: updating an existing `.tar.zst`
  archive is not supported yet; delete and re-create.
- **One-step `.tar.zst` extraction**: `7z x`/`7z l`/GUI extraction and the
  file manager see straight through to the tar contents (upstream needs two
  steps). Non-tar `.zst` files behave exactly as before;
  `7z x -tzstd file.tar.zst` still extracts just the `.tar` if you want the
  old behavior.
- Archive type names may now contain a dot (`-ttar.zst`); upstream's
  dotted type-chain syntax for opening still works unchanged.
- **MSI installer and portable zip, for x64, x86 and arm64.** One `.wxs`
  covers all three - `ProgramFiles6432Folder` resolves per architecture, so
  x86 installs under `Program Files (x86)` and the 64-bit builds under
  `Program Files`. `installer\Build-Package.ps1` cuts both artifacts from one
  staging directory, so what the installer places and what the zip contains
  cannot drift apart. The MSI is per-machine, installs to
  `Program Files\7-ZSTar`, adds a Start menu entry, and registers the shell
  extension under its own CLSID with every context-menu key named `7-ZSTar` -
  installing or removing it leaves official 7-Zip's registration untouched.
  It deliberately does not claim `App Paths\7zFM.exe`, which both products
  would otherwise fight over. No package contains a `.sfx` stub. The zip
  needs no administrator and registers nothing; it also has no context menu.
  Identities are documented in `installer/GUIDS.md`; the UpgradeCode is
  permanent.
- **Per-user installer, `7-ZSTar-<version>-<arch>-user.msi`**, for an account
  without administrator rights: installs to `%LOCALAPPDATA%\Programs\7-ZSTar`
  with no UAC prompt, registers everything under `HKCU` and writes nothing to
  `HKLM` (Windows Installer's own bookkeeping aside). It has the classic right-click menu but not the Windows 11
  first-level entry, which needs a machine-wide certificate trust. It has its
  own permanent UpgradeCode, and it and the per-machine package each refuse to
  install while the other is installed. Built by
  `installer\Build-Package.ps1 -PerUser`; `docs/INSTALL.md` lists its limitations.
- **7-ZSTar appears in the Windows 11 context menu directly**, instead of only
  under *Show more options*. Windows 11 lists a shell extension in the
  first-level menu only when it arrives with package identity, so the MSI now
  ships an identity-only ("sparse") MSIX beside the binaries and registers it
  at install time; the classic registration stays in place and still serves
  Windows 10, the legacy menu, and anyone who has restored the old context
  menu. Upstream 7-Zip already implements `IExplorerCommand` and simply never
  registered it anywhere; the one C++ change is that, on Windows 11, the
  packaged entry hides itself under *Show more options*, where the classic
  handler already shows the same submenu, so the account that installed
  7-ZSTar no longer sees the entry twice there.
  The package is signed with a **self-signed** certificate, which the
  installer imports into `LocalMachine\TrustedPeople` (Windows will not deploy
  a package it cannot chain to something trusted); uninstalling removes both
  the package and the certificate. Builds without a certificate simply leave
  it out: the MSI still installs and still gets the classic menu. The CI
  builds do carry it: each run makes a throwaway certificate on the runner
  (`Build-Package.ps1 -CreateSigningCert`), so no signing key is kept in
  GitHub, every package (each architecture, each release) has a certificate of
  its own, and CI fails if
  the per-machine MSI comes out without the package. Release assets are only
  the `.msi` and `.zip` files (no `.wixpdb`).
  `Setup-ShellIntegration.ps1` is installed alongside so a second user account
  can register it by hand, since package registration is per user.
- **7-ZSTar is now a Default Programs application**, so its file types can be
  assigned from Settings > Apps > Default apps. This is the only route that
  works on Windows 11: an application writing a ProgID into
  `HKCU\Software\Classes\<ext>` - what Tools > Options > System does - is
  ignored for any extension the machine already knows, and `AssocQueryString`
  answers `Unknown` while Explorer draws the blank generic icon. Windows only
  honours a `UserChoice` stamped with a hash it alone can compute.
  The installer therefore registers what Windows needs to offer the choice: a
  ProgID per format carrying its icon index and open command, an entry in each
  extension's `OpenWithProgids`, and a `Capabilities` block listed in
  `RegisteredApplications`. It claims no file type - the ProgID table is
  generated from the same extension/icon STRINGTABLE the shell extension
  compiles, so the installer cannot disagree with the DLL about which icon a
  format gets.
- **Uninstalling now clears the file associations it set.** The associations
  are `7-ZSTar.<ext>` ProgIDs that Tools > Options > System writes per user,
  under the same names as the ones the installer advertises (and, for a
  per-user install, in the same hive) - but leaving them behind pointed every
  associated extension at a ProgID whose icon and open command were a deleted
  executable, which Explorer
  renders as a blank icon. The uninstall removes the uninstalling user's own,
  and only the file types still naming one of them, so a format since given to
  another program is untouched. The per-machine uninstall also leaves alone a
  ProgID that opens another copy of 7-ZSTar that still exists - a portable one,
  set up with that copy's own Tools > Options > System. Skipped for upgrades,
  which would otherwise reset associations on every version bump, and with
  `KEEPASSOC=1`. Other accounts can clear theirs with
  `Setup-ShellIntegration.ps1 -RemoveAssociations`.
- **The per-machine MSI always installs to `Program Files\7-ZSTar`.** Custom
  setup no longer offers a folder, and `INSTALLFOLDER` on the command line is
  overridden. That folder holds `Setup-ShellIntegration.ps1`, which the
  installer runs as SYSTEM - and as the installing administrator, elevated -
  at install, repair and uninstall, and `7-zip.dll`, which every user's
  Explorer loads. A folder made elsewhere inherits its parent's permissions:
  `C:\7-ZSTar` is writable by every user, and a standard user who replaced the
  script there had it run as SYSTEM at the administrator's next repair. The
  per-user MSI, which runs nothing with anyone else's rights, still lets you
  choose.
- **A lone `7z.exe`, `7zG.exe` or `7zFM.exe` now finds 7-ZSTar's `7z.dll`,
  not official 7-Zip's.** With no `7z.dll` next to it - a copy of just the
  executable, or a DLL removed by antivirus - the program looks its install
  folder up in the registry. It looked under official 7-Zip's key, so on a
  machine with both installed it loaded official 7-Zip's `7z.dll`, without
  zstd, brotli or the other added codecs; with only 7-ZSTar installed it
  found none. It now reads `Software\7-ZSTar`, where both installers record
  the folder.
- **The file manager's "Integrate 7-ZSTar to shell context menu" option
  (Tools > Options > 7-ZSTar) no longer touches official 7-Zip's context
  menu.** It used official 7-Zip's registry key names: with both installed,
  ticking it made official 7-Zip's submenu disappear from Explorer's context
  menu, and unticking did not bring it back. The box also showed unticked
  right after installation although the menu was there. It now uses the
  `7-ZSTar` keys the installer writes.
- `Setup-ShellIntegration.ps1 -UntrustCert` with a `CurrentUser` certificate
  store removes only the user's own copy. That store also lists
  `LocalMachine`'s, which it used to try to delete too - and fail, for a
  standard user, stopping the script.
- **The installer now has a wizard.** The first MSI had no `Dialog` table at
  all, so it flashed a progress window and vanished with nothing to read or
  agree to. It now runs WixUI's Mondo sequence - welcome, licence, setup type,
  feature tree under *Custom*, confirm, finish - over 7-ZSTar artwork, with a
  "launch the file manager" checkbox on the last page. The licence page is
  generated at package time from the same `LICENSE`/`COPYING` that ship in the
  package, so the wizard cannot show terms the installed files contradict.
  Quiet installs are unaffected: msiexec skips the whole UI sequence under
  `/qn` regardless of what the package authors. Building the MSI now needs
  `WixToolset.UI.wixext` and `WixToolset.Util.wixext`.
- **Apps & features shows the 7-ZSTar icon** instead of a generic package
  icon, and reports its install location. Neither was set before, so Windows
  had nothing to display.
- **Translated user interface, ~90 languages**, installed to `Lang\` (also in
  the portable zip) and selectable under Tools > Options > Language. No code
  change was needed - the machinery was always compiled in, upstream simply
  never ships translations in its source tree. Vendored from upstream's binary
  release (26.05 since the merge; 26.02 before) with the product name rewritten; provenance, the exact source
  archive and the rebranding rules are in `Lang/UPSTREAM.md`.
- **Context menu icons on by default.** Upstream defaults `MenuIcons` to off,
  so a fresh install shows a context menu with no icon at all and the setting
  that changes it is buried in Options. Both halves of the default flipped
  (`ZipRegistry.cpp`), and `MenuLogo.bmp` - which the icon work had missed and
  was still upstream's "7Z" - is now 7-ZSTar's mark, still 13x13 monochrome so
  it keeps following the menu's light/dark colours.
- **Own icon set.** New application icon (7zFM/7zG/shell extension), About
  dialog wordmark, and a full set of 41 archive-format association icons on a
  shared design: a navy plate, the format name, and a colour bar per format.
  Chained `tar.*` short extensions (`.tzst`, `.tbr`, `.tlz4`, ...) get a
  two-layer variant so they read differently from the plain single-codec
  extension. Upstream's own icon files are left byte-identical - the new set
  lives in `Archive/Icons/7zstar/` and the `.rc` files point at it - so
  merging a new 7-Zip release cannot conflict on them. Icons are generated
  from `docs/logo/icongen.py`; re-run it to regenerate.
- **Own toolbar art, sized for the screen.** The file manager's seven buttons
  were the last upstream art in the shipped binaries; they are now cardboard
  boxes, documents, a trash can and an info disc. Upstream draws them at fixed
  pixel sizes, so on a 200% display they came out smaller than the text under
  them. The buttons now follow the system DPI, using square bitmaps from 24 to
  96 pixels made ahead of time instead of scaling at run time, and large buttons
  are the default for anyone who has not chosen. Upstream's bitmaps stay
  byte-identical, behind an `#if 0` in `resource.rc`, so merging a new 7-Zip
  release cannot conflict on them.
- **About dialog finished.** The rebrand had left its English resource
  half-done: the title bar still read "About 7-Zip", and the link button was
  still labelled `www.7-zip.org` while already opening the project repository.
  Both corrected. The 7-ZSTar copyright line - longer than the one upstream
  sized the control for, so the display stopped after Igor Pavlov's name and
  the contributor credit was invisible - fits again. The dialog also says what
  the program is: an independent fork of 7-Zip, under the GNU LGPL v3 with
  exceptions (unRAR, BSD and public-domain files ship alongside, as
  `LICENSE-EXCEPTIONS.md` records), not affiliated with the 7-Zip project.
  That sentence is deliberately outside the localizable strings, so every
  language shows it rather than only the English fallback.
- **Help works again.** Every package now carries `7-zip.chm` - upstream's own
  help file, vendored unmodified from the same release `Lang/` comes from
  (`Help/UPSTREAM.md`), because the HTML it is compiled from exists only
  inside upstream's binary packages. *Help > Contents*, F1 and the About
  dialog's help topic open it. Until now they handed `HtmlHelp()` a path that
  could not resolve and nothing happened at all - no window, no error. If the
  file is missing anyway (someone copied a lone `7zFM.exe` out of the zip),
  those entries fall back to the project's online documentation. The help
  text describes 7-Zip's interface, which 7-ZSTar inherits; what this fork
  adds is in this file and the README.
- **Custom setup can pick individual languages.** The language pack used to be
  one all-or-nothing feature. Each of the 92 translations is now its own
  feature under *Languages*, titled with its English name and code, all
  selected by default - so a plain install is unchanged and *Custom* can trim
  it to the languages you actually read. `en.ttt` stays with the parent
  feature: it is not a language, it is what the language picker measures
  translation completeness against.
- **The About dialog's wordmark is legible.** It used to be drawn into the
  110x63 plate upstream's logo happened to occupy, and a square mark at full
  plate height left "7-ZSTar" at roughly ten pixels beside it. The plate is
  gone: the control already carried `SS_REALSIZEIMAGE`, so it takes whatever
  size the image is, and the lockup is now drawn at its natural proportions -
  246x68, mark and type both about twice their old size. 256 px is the
  ceiling, being all an ICO directory entry can address; the generator now
  refuses anything larger instead of writing a file Windows would misread.
- Apps & features carries the project, support and update links
  (`ARPURLINFOABOUT`, `ARPHELPLINK`, `ARPURLUPDATEINFO`).
- Rebranded to 7-ZSTar: product name, window class (`7-ZSTar::FM`), manifests,
  shell extension display name and **own shell-extension CLSID**
  ({E9471EF7-A2B2-46B9-95AB-E4421B50C777}) so 7-ZSTar and official 7-Zip can
  be installed side by side, context menu label, message-box titles.
- Own registry hive `Software\7-ZSTar` and file-association ProgID prefix
  `7-ZSTar.` (settings and associations do not collide with 7-Zip).
- Version scheme: `<upstream>.<revision>` (26.05.1 = upstream 26.05, rev 1).
- License: LGPL v3 (upstream is LGPL 2.1-or-later); added LICENSE, COPYING,
  LICENSE-EXCEPTIONS.md, NOTICE.
- Build: `build/Build.ps1` nmake driver (x64/x86/arm64 via VS2022).
- Vendored: zstd 1.5.7 (`C/zstd/`), xxHash (`C/hashes/`), each with
  UPSTREAM.txt provenance.
- **brotli, lz4, lz5, lizard, fast-lzma2 compression** (mcmilk/7-Zip-zstd
  parity, M6a): standalone archives (`-tbrotli`/`.br`, `-tlz4`/`.lz4`,
  `-tlz5`/`.lz5`, `-tlizard`/`.liz`) and `-m0=BROTLI`/`LZ4`/`LZ5`/`LIZARD`/
  `FLZMA2` inside `.7z`. Coder ids match mcmilk's own (0x4F71102/104/105/106);
  fast-lzma2 has no id/format of its own - it registers as an alternative,
  multi-threaded encoder for the official LZMA2 coder id (0x21), decodable
  by the unmodified official decoder. GUI: one method entry per codec
  (Lizard's 4 mcmilk mode/level sub-ranges simplified to one, full range
  still reachable via `-m0=lizard:x=NN` on the command line).
- **One-step `tar.br`/`tar.lz4`/`tar.lz5`/`tar.liz` creation**, same
  zero-intermediate-file design as `tar.zst`.
- Vendored: brotli 1.2.0 (`C/brotli/`), lz4 1.10.0 (`C/lz4/`), lz5 1.5.0
  (`C/lz5/`), lizard 2.1.0 (`C/lizard/`), fast-lzma2 1.0.1
  (`C/fast-lzma2/`), and zstdmt (`C/zstdmt/`, mcmilk's own multithreading
  wrapper used by brotli/lz4/lz5/lizard - zstd's own MT is self-contained
  and doesn't use it), each with UPSTREAM.txt provenance.
- **One-step extraction for every other supported single-file compressor
  wrapping a tar** (M6b): `.tar.gz`/`.tar.bz2`/`.tar.lzma`/`.tar.xz`/`.tar.Z`/
  `.tar.br`/`.tar.lz4`/`.tar.lz5`/`.tar.liz` (plus every short form GNU tar's
  own `suffix.c` recognizes for the official formats: `tgz`/`taz`, `tbz`/
  `tbz2`/`tz2`, `tlz`, `txz` - `taz`/`taZ` stay registered to `.Z`/gzip exactly
  as upstream had them; content-signature detection, not the extension,
  decides which codec actually opens a same-named file either way) now see
  straight through to the tar contents too, same as `.tar.zst`. `xz`
  reuses its own existing random-access block index when present (true for
  every standard-conforming `.xz`, including piped/streaming tools' output -
  the format's Index+Footer is mandatory, unlike zstd's optional
  Content_Size); `gzip`/`bzip2`/`lzma` reuse the same rewindable-decode
  mechanism `.tar.zst` introduced, generalized to any coder that supports it
  (`CRewindableDecodedStream`); `.Z`("compress")/brotli/lz4/lz5/lizard's
  decoders don't, so those five decode to a temp file once instead
  (`CTempFileDecodedStream`) - correct and simple, at the cost of using
  temporary disk space for the decoded size instead of zero-intermediate
  streaming (cleaned up automatically). Registered extensions gained `tz2`
  (bzip2) and `tlz` (lzma, which previously had no short-form/`.tar` mapping
  at all).
- **One-step `tar.gz`/`tar.bz2`/`tar.xz` creation** (M6b), same
  zero-intermediate-file design as `tar.zst`/`tar.br`/`tar.lz4`/`tar.lz5`/
  `tar.liz`. `tar.lzma` is not included: the plain `.lzma` format has no
  writer anywhere in this project (upstream registers it read-only) to
  build this on top of.
- Right-click "Extract to" / file-manager Extract now propose the fully
  stripped folder name for every format above - `foo.tar.zst` (or `.gz`/
  `.bz2`/...) proposes `foo\`, not `foo.tar\`; short forms (`foo.tgz`, ...)
  were already correct and are unaffected.
- **Bug fixes inherited from mcmilk/7-Zip-zstd**, reported upstream as
  issues #530-#532 and #536-#538 and carried here in the same shape:
  - **Truncated `.lz4`/`.lz5`/`.liz` are now reported as errors.** This is a
    behavior change worth knowing about: a raw-frame archive cut short used
    to pass `7z t` with "Everything is Ok" and extract to a silently short
    file. It now fails, matching what the multi-frame path in the same
    decoder, and the reference tools, have always done. An archive that
    "worked" before an upgrade and errors after was already damaged.
  - **Brotli archives no longer depend on `-mmt` matching between the run
    that wrote them and the run that reads them.** The decoder used to pick
    raw-vs-container decoding from the requested thread count instead of
    from the file; it now reads the stream's own first four bytes. This is
    also what makes one-step `.tar.br` extraction work at all - the entry
    above claimed it since M6b, but for brotli specifically it did not, and
    `7z l foo.tar.br` listed a single `foo.tar` entry. The other nine
    formats were unaffected.
  - **Brotli content detection hardened beyond the upstream fix** (7-ZSTar
    only). Raw brotli has no signature, so the four-byte probe above left
    a ~1-in-4-billion class of valid raw `.br` files that would be
    mistaken for the multi-threaded container and then fail - with no
    flag left to force raw decoding, such a file could not be extracted
    at all, and the error read `ERROR: Unspecified error`. The probe now
    checks the container's whole 16-byte first frame header before
    committing, so those files simply decode correctly (residual odds
    ~2^-80, and even that case still errors rather than producing wrong
    bytes). Brotli decode failures on genuinely damaged input now also
    report `Data Error` instead of `Unspecified error`.
  - **A way to override brotli content detection**: `7z x -mmt=0 file.br`
    reads the file as plain brotli without looking at its first bytes at
    all. Detection replaced the old "no `-mmt` means raw" selector, which
    left nothing to fall back on if a raw stream ever did collide with the
    container header; widening the probe makes that rarer, but a format
    with no signature cannot be detected with certainty at any probe width,
    so only this makes such a file recoverable. Every byte read while
    probing is handed back, so forcing raw returns exactly what detection
    would have on a file that was raw all along. `-mmt=0` is the only
    spelling that does this: every other `-mmt` form, including `off` and
    `-`, stays a thread count and leaves detection in charge, so files
    written by 7-Zip ZS with `-mmt` keep opening under all of them.
  - **Memory leaks on error and cancel paths**, in the multi-threaded
    brotli/lz4/lz5/lizard engine: the per-worker input buffer and the
    pending output queue were both abandoned when compression failed or was
    cancelled, and the single-threaded decompress path returned without
    running its cleanup at all. Measured with a heap checker over the real
    code: 65.6 MB per 500 cancelled compressions and 13.1 MB per 200 failed
    decompressions, now zero. Also fixed: the multi-threaded decoder context
    leaked once per opened archive, since 7-ZSTar's one-step-extraction
    sniff makes that error path routine rather than rare.
  - **Registered format signatures corrected** for `lz4`/`lz5`/`lizard`:
    they were the *text* "0x184D2204" rather than those bytes, and one
    signature cannot describe both the raw frame and the multi-threaded
    container these codecs also emit. Both are registered now; visible in
    `7z i`. This does not change which files open - detection for these
    three has always run through their own probe function.
  - **`-mx0` works for lz4 and lz5** (issue #543). Compression levels were
    clamped to each codec's maximum but never to its minimum, so
    `-m0=lz4 -mx0` and `-m0=lz5 -mx0` failed outright. Levels of 256 or
    more were also being truncated to a single byte *before* any clamping,
    which for codecs whose minimum is not 1 silently selected the wrong
    setting instead of failing; clamping now happens first.
  - **More leaks and crash paths in the multi-threaded engine** (issues
    #545, #547, and two we found here): every rejected `create*Ctx()` call
    leaked the context it had already allocated - which the `-mx0` failure
    above hit on any machine, not just under memory pressure; a failed
    writelist allocation crashed rather than reporting out of memory; a
    failed `realloc()` lost the old buffer and could hand another worker a
    buffer it believed was still valid; and the default thread count could
    exceed what the codecs accept on machines with more than 128 logical
    processors. Also removed a data race on brotli's read-failure path.
  - **Concatenated `.lz5` / `.liz` streams extract completely** (issue
    #549). Only the first frame was decoded, and the result was reported
    as success - so a multi-frame raw stream silently lost everything
    after the first frame. Files produced by 7-ZSTar were never affected
    (they always use the multi-frame container); this is about streams
    from other tools.
