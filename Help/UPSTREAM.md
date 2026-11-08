# Help/ provenance

`7-zip.chm` is **upstream 7-Zip's compiled help file, shipped verbatim**. It is
not built here and not written here.

## Why it is vendored rather than built

Upstream keeps the HTML the help file is compiled from **outside** the source
tree. `DOC/7zip.hhp` (the HTML Help project) is in the repository and lists
`start.htm`, `general\*.htm`, `cmdline\**\*.htm` and so on - but none of those
files exist here, in the source release, or in the git repository. Only the
compiled `.chm` in upstream's **binary** packages contains them. That is the
same situation as `Lang/`, and it has the same consequence: vendor, or ship
nothing.

## Where this came from

| | |
|---|---|
| Version | 7-Zip **26.05** (2026-10-21) - the same release this fork is based on |
| Source | `https://github.com/ip7z/7zip/releases/download/26.05/7z2605-x64.msi` |
| MSI SHA-256 | `3fe4ab99fa15629c652944309a2b2bc6e41fc933fc6b63f5df1ebcf3aea68263` |
| Extracted with | `msiexec /a <msi> /qn TARGETDIR=<dir>` (administrative install - unpacks only, installs nothing) |
| File | `Files\7-Zip\7-zip.chm`, 127,438 bytes |
| File SHA-256 | `a2804a30e3bda46b4d5e2aa3148c9e72bc76453cc10b6848978af9278640e4a9` |

The same download that `Lang/UPSTREAM.md` documents - one unpack supplies both.

`Lang/` can be re-checked against upstream with `rebrand.py --check`; a compiled
`.chm` has no such tool, so the hash above is the check:

```powershell
(Get-FileHash Help\7-zip.chm -Algorithm SHA256).Hash
```

## What was changed

**Nothing.** The file is byte-identical to upstream's. A `.chm` is a compiled
container; the `Lang/rebrand.py` trick of rewriting the product name is not
available here, and decompiling to rebrand would mean maintaining a fork of
7-Zip's entire manual.

## What that means for readers

The help file describes **7-Zip's** interface and options, and says "7-Zip"
throughout. Everything it documents that 7-ZSTar inherited behaves the same
way; what this fork adds - zstd/brotli/lz4/lz5/lizard compression, the
one-step `tar.*` formats - it does not mention at all. `README.md` and
`CHANGELOG.md` are the reference for those, and the README's *Documentation*
section says so.

## Keeping it in step

Re-vendor from the matching release whenever the fork rebases onto a new
upstream version, exactly as for `Lang/`. If a future release ever ships the
HTML sources in-tree, build it instead: `DOC/7zip.hhp` is ready to compile
with `hhc.exe` from HTML Help Workshop.

## How it is used

`CPP/7zip/UI/FileManager/HelpUtils.cpp` opens `<directory of the running
module>\7-zip.chm`, so the file has to sit next to `7zFM.exe` - which is why
`installer/Build-Package.ps1` stages it into the package root rather than a
subfolder. When it is absent (someone copied only the .exe out of the zip),
the same function falls back to the project's online documentation instead of
handing `HtmlHelp()` a path that cannot resolve.
