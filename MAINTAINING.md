# Maintaining 7-ZSTar

This file is for whoever has to pull new code in from either upstream. It is
in the repository on purpose: anything a future maintainer must not get
wrong belongs here.

**Every command below runs from the root of this repository** - the directory
holding this file.

7-ZSTar has **two** upstreams:

| | Repository | What comes from it | Playbook |
|---|---|---|---|
| **Mainline** | `ip7z/7zip` (git remote `upstream`, baseline tag `upstream/26.05`) | the whole program | [Part 1](#part-1--merging-a-new-mainline-7-zip-release) |
| **7-Zip ZS** | `mcmilk/7-Zip-zstd` | `C/zstdmt/` and 22 ported C++ files | [Part 2](#part-2--re-vendoring-from-7-zip-zstd) |

Plus three assets vendored from 7-Zip's **binary** release rather than its
source tree: `Lang/`, `Help/7-zip.chm`, `LICENSE-7-Zip.txt`.

Read [Part 3](#part-3--landmines) before touching anything. It lists the
changes that a clean merge, a green build and a green test run will all fail
to protect you from.

---

## Part 1 — Merging a new mainline 7-Zip release

### The model

Merge, never rebase (`git merge upstream/<tag>` onto `main`). Rebase rewrites
every commit and loses the `// 7-ZSTar:` markers' association with their
reasons. The fork's discipline is that new functionality lives in new files
and upstream files get the smallest possible wiring, each edit tagged
`// 7-ZSTar:` so `git grep` can audit it.

### Step 0 — establish what you are merging into

```bash
git fetch upstream --tags
git diff --stat upstream/26.05..HEAD           # our whole divergence
git diff --stat upstream/26.05..upstream/<new> # what upstream changed
```

The intersection of those two lists is your actual work. Everything below is
about what the intersection does not show.

### Step 1 — the categories of divergence

**A. Branding literals — many, and mostly unmarked.** `"7-Zip"` → `"7-ZSTar"`
in message-box titles, window captions, dialog labels, manifests. A textual
conflict announces itself; the danger is the opposite case: a new upstream
release that *adds* a new `"7-Zip"` literal somewhere merges cleanly and ships
unbranded. To see the current set, and again after every merge:

```bash
git grep -n '"7-Zip"' -- CPP/ C/ | grep -v LangUtils   # see Part 3.1
```

**B. Registry paths — functional, and unmarked.** `Software\7-Zip` →
`Software\7-ZSTar` in `CPP/7zip/UI/FileManager/RegistryUtils.cpp`,
`ViewSettings.cpp` and `CPP/7zip/UI/Common/ZipRegistry.cpp`. These are not
display strings: getting them wrong makes 7-ZSTar read and write official
7-Zip's settings, breaking the side-by-side promise silently. One more, and
the first of two exceptions that carry a `// 7-ZSTar:` marker: `kRegistryPath` in
`CPP/7zip/UI/Common/LoadCodecs.cpp`, where the executables look up the install
`Path`/`Path64` value when no `7z.dll`, `Codecs\` or `Formats\` sits next to
them. Upstream's key there would load official 7-Zip's `7z.dll` on a machine
with both installed. That one was missed for months because upstream spells
it `"7-zip"`, lower case, which the case-sensitive grep in A does not match.
Upstream's own installer sources, `C/Util/7zipInstall/7zipInstall.c` and
`C/Util/7zipUninstall/7zipUninstall.c`, carry the key too and were changed the
same way, although 7-ZSTar neither builds nor ships them. After every merge
this must print nothing - it covers both spellings upstream uses for the key,
`TEXT("7-zip")` and `"Software\\7-Zip"`, in all of those files:

```bash
git grep -n -i -E 'TEXT\("7-zip"\)|"Software\\\\+7-zip' -- CPP/ C/
```

The second marked exception is the shell-extension handler key names:
`k_KeyPostfix_ContextMenu` and `k_KeyPostfix_DragDrop` in
`CPP/7zip/UI/Explorer/RegistryContextMenu.cpp` end in `\7-ZSTar`, the name
`installer/7-ZSTar.wxs` registers. 7zFM's "Integrate 7-ZSTar to shell
context menu" option writes and deletes them. Upstream's `\7-Zip` there meant
ticking the option overwrote all five of official 7-Zip's handler keys with
our CLSID, and the option never saw the keys our installer wrote, so the box
showed unchecked after every install. That was missed in the original rename
because the literal is a path suffix, not `"7-Zip"` on its own. This must
print nothing after every merge (case-insensitive, since registry key names
are):

```bash
git grep -n -i -E 'Handlers\\\\+7-Zip' -- CPP/ C/
```

It does not see upstream's installer sources, which append the name
separately (`CatAscii(destPath, "\\7-ZSTar")` in `7zipInstall.c` and
`7zipUninstall.c`); they are neither built nor shipped, so that is accepted.
`build/Test-Smoke.ps1` also checks the built `7zFM.exe` for the key names,
which catches what a source grep cannot, such as a name assembled at run time.

**C. Identity — window class, CLSID, manifests.** `7-Zip::FM` → `7-ZSTar::FM`
(`FM.cpp`), the shell-extension CLSID (see Part 3.3), the context-menu verb
prefix `SevenZip` → `SevenZSTar` (`ContextMenu.cpp`, see Part 3.11), and the
`assemblyIdentity` in the three `.manifest` files.

**D. Icons and the resource index tables.** Upstream's own `.ico` files are
byte-identical here on purpose; ours live in `CPP/7zip/Archive/Icons/7zstar/`
and the `.rc` files point at them. `Bundles/Format7zF/resource.rc` carries an
*indexed* icon table: **if upstream adds a format icon inside index 0-26, mirror
it into `Icons/7zstar/`; if upstream grows past index 26, our index 27
(`br.ico`) collides and the numbering must be redone by hand.**

The toolbar art works the same way. Upstream's 14 BMPs stay byte-identical and
out of the binary, behind an `#if 0` in `FileManager/resource.rc`; ours are the
35 square bitmaps in `FileManager/7zstar/`, listed in `7zstar/toolbar.rc` and
chosen by `Toolbar7zstar.h` from the system DPI. `App.cpp` calls it from
`CreateToolbar` and `AddButton`, and `App.h` makes large buttons the default.
IDs are indexed from `IDB_ADD`, so **a new or renumbered upstream toolbar button
needs art of its own**. `Toolbar7zstar.h` stops the build with `#error` if the
seven IDs it names are renumbered, and `build/Test-Smoke.ps1` fails if
`resource.h` gains a bitmap ID it does not know. To add a button, add its art in
every size to `7zstar/` and `7zstar/toolbar.rc`, then update both checks and the
bitmap count in the smoke test (buttons x sizes).

**E. Functional wiring — read the diff, do not re-apply blindly.** The
one-step `tar.*` support (`IInArchiveGetStream` + `kpidMainSubfile` in
`GzHandler.cpp`, `Bz2Handler.cpp`, `XzHandler.cpp`, `LzmaHandler.cpp`,
`ZHandler.cpp`, `ZstdHandler.cpp` and the four mcmilk codecs), the TarChain
family, the codec ids in `7zHeader.h`, `kNumArcsMax` (Part 3.4). The handlers
follow one consistent pattern - reconcile one carefully and use it as the
template for the rest. `GetState` in `CPP/7zip/UI/Explorer/ContextMenu.cpp`
belongs here too (Part 3.12).

**F. Un-commenting upstream's own stubs — invisible to a marker grep.** Eight
sites where the change is that upstream's commented-out code is now live
(`ICoder.h`, `MethodProps.cpp`, `CompressDialog.{rc,cpp}`, `ZipRegistry.*`,
`7zHandler.cpp`, `UpdateGUI.cpp`, `XzHandler.cpp`). **If upstream enables the
same block itself, a three-way merge can take both sides.** Only
`MethodProps.cpp` is protected by a `static_assert` that turns that into a
build break; the rest fail silently or duplicate. `ZipRegistry.cpp` also carries
the email-items default, which `build/Test-Smoke.ps1` checks (Part 3.13).

**G. Build files.** `CPP/Build.mak`, `7zip.mak`, the per-bundle makefiles
(codec object lists), and `build/Build.ps1`'s hand-maintained `$AllTargets`
list of 17 directories - **a new upstream bundle will not be built until it is
added there by hand.** The same file's `$dateObjects` is hand-maintained too: a
new source using `MY_DATE` or `MY_COPYRIGHT_DATE` keeps a stale date in
incremental builds until it is added.

**H. `C/7zVersion.h`.** Upstream bumps the version and the copyright year on
the same lines we changed, every release. Expect a conflict; keep upstream's
major/minor, keep our `MY_VER_BUILD` revision scheme (`<upstream>.<rev>`),
keep `MY_PRODUCT_NAME`, `MY_PROJECT_URL`, `MY_WEBSITE_URL`, the contributors line
in `MY_COPYRIGHT_CR`, the `#undef MY_DATE` near the top, and the build-date block
at the end of the file (the two are a pair). Take upstream's `MY_DATE` as it
comes: it is only the fallback. When upstream's year moves, change
`MY_COPYRIGHT_UPSTREAM` to match (`Test-Smoke.ps1` fails until you do) and the
upstream line of `NOTICE`, which no test reads. When the fork's own year moves, change it in `MY_COPYRIGHT_FORK`,
`MY_COPYRIGHT_CR` and `NOTICE`. See Part 3.6 for everything that has to move with it.

### Step 2 — re-vendor the three binary-release assets

They come from the **binary** package of the release you just merged, not from
its source tree. Each has its own procedure; follow it, do not improvise:

| Asset | Procedure |
|---|---|
| `Lang/` | `Lang/UPSTREAM.md` § "Refreshing to a newer 7-Zip" - download the matching `7zXXXX-x64.msi`, record URL/size/SHA-256, `msiexec /a` unpack, `uv run Lang/rebrand.py <dir>`, review what it left alone. The run also writes strings 962/963 (the About dialog's Donate and Website buttons) from `Lang/donate.json`, which is ours and is **not** replaced by the refresh; check it still matches the new language set (Part 3.14; 25 languages are absent from it on purpose, see `Lang/UPSTREAM.md`) |
| `Help/7-zip.chm` | `Help/UPSTREAM.md` § "Keeping it in step" - same MSI, byte-identical copy, update the recorded SHA-256 |
| `LICENSE-7-Zip.txt` | Same MSI, file `Files\7-Zip\License.txt`, copy byte-identical, **and update the SHA-256 recorded in `LICENSE-EXCEPTIONS.md`** - it is an attestation and goes stale silently (Part 3.5) |

`installer/Build-Package.ps1` refuses to package if `Lang/` or
`Help/7-zip.chm` is missing, but it cannot tell that they are the *old*
version. Nothing can. This step is manual and load-bearing.

### Step 3 — verify

```powershell
build\Build.ps1 -Clean        # all 17 targets OK, zero warnings
build\Test-Smoke.ps1          # every check PASS, "0 failed"
installer\Build-Package.ps1   # then install the .msi and look at it
```

(The suite's check count grows as checks are added; what matters is that
nothing fails, not the total.)

`-Clean` is not optional after a merge: nmake does not track the `.rc` include
graph, so a changed resource can leave a stale `.res` and a green build that
does not contain the change.

What the licence checks in the smoke suite mean when they go red:

- *"NOTICE quotes every vendored licence file accurately"* - a vendored
  library's copyright line moved. Update `NOTICE` to quote the file verbatim,
  and the `$licenceQuotes` table in `build/Test-Smoke.ps1` with it.
- *"vendored libraries are library-only"* - a re-vendor pulled in a
  `programs/` or `tests/` tree, which upstream projects license under the GPL.
  Remove it; the claim that nothing GPL is compiled in depends on this.
- *"upstream's own licence statement ships"* - `LICENSE-7-Zip.txt` is missing
  or no longer carries the clause that obliges us to reproduce it.

---

## Part 2 — Re-vendoring from 7-Zip ZS

Two separate problems with very different levels of support.

### 2a. `C/zstdmt/` — fully documented, follow the ledger

`C/zstdmt/UPSTREAM.txt` is the authority. Its `patches:` section is a
three-bucket ledger:

- **(a) merged upstream** - already in mcmilk's master; a re-vendor brings them
  back for free, drop our copy of the patch.
- **(b) sent, still open** - keep applying while the PR is open; drop each one
  when its PR merges.
- **(c) 7-ZSTar-only** - never coming from upstream; must be re-applied every
  time, forever.

Every deviation carries a `7-ZSTar:` marker in the C source, so this
enumerates what must survive:

```bash
git grep -n "7-ZSTar:" -- C/zstdmt/
```

Re-vendor, diff, re-apply buckets (b) and (c), update the ledger.

### 2b. The ported C++ files — no baseline was recorded

`CPP/7zip/Compress/{Brotli,Lz4,Lz5,Lizard,FastLzma2}*` and the matching
handlers under `CPP/7zip/Archive/` were hand-ported from mcmilk's fork during
M6a. The set is exactly what this lists - 22 files at the time of writing, and
`NOTICE` states the same number with `build/Test-Smoke.ps1` holding the two
together:

```bash
git grep -l "Ported from mcmilk/7-Zip-zstd"
```

Each header names Tino Reichardt, but **no baseline commit was written down**.

Do not use `git grep "7-Zip-zstd"` to find them: it returns 29 under `CPP/`
(45 across the repository, the rest being `C/zstdmt/` and the documents). The
seven extra files under `CPP/` - the five `*Register.cpp`, `MethodProps.cpp`
and `7zip.mak` - name the project to explain *id and property-name
compatibility* while being our own code, or upstream's. They are not ports and
a re-sync must not overwrite them.

The eight `C/*/UPSTREAM.txt` files all record `via: mcmilk/7-Zip-zstd checkout
260a6a7`, and the C++ port happened at the same time, so 260a6a7 is the
**presumed** baseline - verify it before relying on it (diff one ported file
against that checkout). If you re-sync these files, record the new baseline
here and in the file headers so the next maintainer does not have to guess again.

**These files differ from mcmilk on purpose, and a re-sync must keep it.**
The `// 7-ZSTar:` comments mark every site; `git grep -n "7-ZSTar:" --
CPP/7zip/Compress/{Brotli,Lz4,Lz5,Lizard}* CPP/7zip/Archive/{Brotli,Lz4,Lz5,Lizard}Handler.cpp`
lists them. The ones a straight copy of mcmilk's master would undo, all
from 2026-10:

| what | taken from | here | why not mcmilk's form |
|---|---|---|---|
| How the four decoders report errors (`*Decoder.cpp` `CodeSpec()`, `NeedsMoreInput()`; the handlers copy it into `_needMoreInput`) | #564: 3e1ea83, 82b8c37, 48a3721 | bad input is `S_FALSE`; a stream that ends early is `S_FALSE` with `NeedsMoreInput()` set, reported as *Unexpected end of data*; out-of-memory is `E_OUTOFMEMORY` | mcmilk returns the Win32 codes `ERROR_HANDLE_EOF` / `ERROR_INVALID_DATA` as HRESULTs. Both are success codes to `SUCCEEDED()`, and inside a `.7z` they reach the user as Windows' "Reached the end of the file" (mcmilk then fixed one regression of that in its own zstd decoder, f2233f1). The `corrupt-*.7z` smoke checks fail if that comes back. |
| The order of the two releases at the end of the four handlers' `Extract()` | bb11f57 (gh-562, use-after-free) | only the reordering: `ReleaseInStream()` / `outStream.Release()` after `outStreamSpec->GetSize()` | bb11f57 also turns the early `return result;` paths into `opRes = result`, handing an HRESULT to `SetOperationResult()`, which takes an `NExtract::NOperationResult` code. |
| `Extract()` rewinds `_stream` before decoding | - (not in mcmilk) | `if (_stream) RINOK(InStream_SeekToBegin(_stream))` | `GetStream()` leaves the shared stream at EOF when the one-step `tar.*` decode fails, and the single-file fallback then read nothing. The `trunc.tar.{lz4,lz5,liz,br}` smoke checks fail without it, in each of the four handlers (for brotli only the partial-`.tar` half of the check does). |

The zstdmt half of #564 is in `C/zstdmt/` and has its own ledger,
`C/zstdmt/UPSTREAM.txt`.

### 2c. What must not change — archive compatibility

These values are wire format. Changing them makes archives that 7-Zip-zstd
cannot read, and vice versa:

- `.7z` coder ids in `CPP/7zip/Archive/7z/7zHeader.h`: zstd `0x4F71101`
  (`k_ZSTD_mcmilk`), brotli `0x4F71102`, lz4 `0x4F71104`, lz5 `0x4F71105`,
  lizard `0x4F71106`; `0x4015D` is WinZip's zstd id, decode-only.
- The zstd coder-properties layout is **5 bytes**, matching mcmilk exactly -
  documented at `CPP/7zip/Compress/ZstdEncoder.cpp:333` and in `NOTICE`.
- The other four codecs have documented ids but no written properties spec -
  their compatibility rests on the ported code being unmodified. Treat any
  change to their `WriteCoderProperties` as a compatibility break until proven
  otherwise.
- Standalone-format Byte Ids: brotli `0x1F`, lz4 `0x0F`, lz5 `0x10`, lizard
  `0x11`, and `0x20-0x2F` reserved for the TarChain family
  (`CPP/7zip/Guid.txt`). See Part 3.2.

---

## Part 3 — Landmines

Each of these is invisible to a clean merge, a green build **and** a green
test run. That is what makes them worth a section.

### 3.1 The one `"7-Zip"` literal that must never be rebranded

`CPP/7zip/UI/FileManager/LangUtils.cpp:30`

```cpp
return lang.Open(fileName, "7-Zip");
```

That file is **byte-identical to upstream** and must stay that way. The string
is the key every `Lang/*.txt` file is indexed under (id 0 in each language
file is literally `7-Zip`, and `Lang/rebrand.py` deliberately leaves it
alone; `CPP/Common/Lang.cpp` compares it literally when opening a file).
Rename it and all 92 translations stop loading - with a green build and a
green test suite, because nothing in the suite loads a language file.

If a future branding sweep runs `sed`-style over `"7-Zip"`, **exclude this
file explicitly.**

### 3.2 Format Byte Id collision with a new upstream release

Upstream's own handler ids (unchanged from 26.02 through 26.05) stop at `0E`
(zstd) and jump to `BF` (LVM).
7-ZSTar inserted `0F`, `10`, `11`, `1F` and reserved `20-2F` in that gap. If a
new release claims any of those for its own handler, the merge is textually
clean, the build is green, the smoke suite is green, and one of the two
formats stops resolving. **After any merge, diff `CPP/7zip/Guid.txt` against
upstream's and check the gap by hand.**

### 3.3 The shell-extension CLSID has more sites than `installer/GUIDS.md` lists

`GUIDS.md` names four places for `{E9471EF7-A2B2-46B9-95AB-E4421B50C777}`.
The full set is ten, from `git grep -il "E9471EF7"`:

- `installer/7-ZSTar.wxs` (the `ShellExtId` define)
- **`installer/sparse/AppxManifest.xml`** — twice, once in
  `desktop5:Verb/@Clsid` and once in `com:Class/@Id`, and **both are written
  without braces**, so a search for the braced form misses them. This is the
  Windows 11 first-level context menu; get it wrong and that menu silently
  loses the entry while the classic one keeps working, which makes it look
  like a Windows problem rather than a typo.
- `DOC/7zip.wxs` (upstream's own installer definition, one line swapped)
- `CPP/7zip/Guid.txt` (the ledger)
- `CPP/7zip/UI/Explorer/DllExportsExplorer.cpp` (the `DEFINE_GUID` - a binary
  struct, so a search for the dashed form will not find it in that shape)
- `CPP/7zip/UI/Explorer/RegistryContextMenu.cpp`
- **`C/Util/7zipInstall/7zipInstall.c`** and
  **`C/Util/7zipUninstall/7zipUninstall.c`** - upstream's own installer
  utilities, which `GUIDS.md` does not mention at all
- `installer/GUIDS.md` and `CHANGELOG.md` (documentation)

Changing the CLSID means changing all of them; missing one produces a shell
extension that registers under one id and is instantiated under another.

### 3.4 `kNumArcsMax` is defined twice

`CPP/7zip/Archive/ArchiveExports.cpp:24` and
`CPP/7zip/UI/Common/LoadCodecs.cpp:117`, both `96` (upstream: 72). A merge
that resolves one back to 72 and leaves the other produces two builds that
register different format sets. The smoke suite asserts the *count* is under
the ceiling, not that the two constants agree.

### 3.5 `LICENSE-7-Zip.txt` is a version-pinned attestation

`LICENSE-EXCEPTIONS.md` records its SHA-256. After merging a new upstream
release that file is stale - wrong year at least, possibly changed clauses -
and the recorded hash becomes a false statement about what we ship. Nothing in
the tree notices. Refresh it with `Lang/` and `Help/` (Part 1 Step 2).

### 3.6 Nothing binds the version number to the things that quote it

`installer/Build-Package.ps1` derives the package version solely from
`C/7zVersion.h`, and `release.yml` fires on a `v*` tag. A merge that bumps the
header but not the docs leaves `README.md`/`CHANGELOG.md` asserting the old
version; a `v26.06` tag whose header bump was forgotten still produces files
named `7-ZSTar-26.05.1-*.msi`, and the release job publishes them with
matching checksums. Check all four together: the header, the two documents,
and the tag.

### 3.7 The installer's licence page is a fourth copy of the copyright lines

`installer/Build-Package.ps1` builds the wizard's licence page from a
hardcoded array that repeats the copyright lines the smoke suite pins in
`NOTICE`. Re-vendoring a codec whose copyright year moves turns the NOTICE
check red and leaves **the installer's licence page** - the one licence text an
end user is actually shown - quietly wrong. Update both.

### 3.8 No single grep enumerates the `7-ZSTar:` markers

The convention is the string `7-ZSTar:` inside a comment, and it exists in
four shapes, because the tree has four comment syntaxes (counts as of
2026-08-06, and they move):

| Form | Where | Then |
|---|---|---|
| `// Foo.cpp -- 7-ZSTar: new file (Mn)` | header line of a file we added | 41 files |
| `// 7-ZSTar: …` | inline in C++ | 257 lines / 63 files |
| `/* 7-ZSTar: …` and ` * 7-ZSTar: …` | C block comments, mostly `C/zstdmt/` | 30 lines / 10 files |
| `# 7-ZSTar: …` | makefiles (and, since 26.03 gave upstream one too, `.gitattributes`) | 28 lines / 5 files |

So both obvious commands are wrong in opposite directions:

- `git grep -l '// 7-ZSTar:' -- CPP/ C/` **misses** every C block comment and
  every makefile.
- `git grep -l '7-ZSTar:' -- CPP/ C/` catches all four shapes but **includes
  six** files where the string is product identity rather than a marker:
  `FM.cpp` (`L"7-ZSTar::FM"`), `Panel.cpp` (`L"7-ZSTar::Panel"`),
  `PanelDrag.cpp` (clipboard format), and the `CAPTION "7-ZSTar: …"` lines in
  `BrowseDialog.rc`, `BrowseDialog2.rc` and `MessagesDialog.rc`.

Use the second and skip those six knowingly. Do not "clean up" the six: they
are the coexistence identity that keeps 7-ZSTar and official 7-Zip apart.
Neither command looks at the repository root, so the one marker there - the
header of `.gitattributes` - needs its own look: add `.gitattributes` to the
pathspec.

### 3.9 Regenerating icons is a no-op without `--install`

`docs/logo/icongen.py` writes to a gitignored `out/` directory. Only
`uv run docs/logo/icongen.py --install` copies the results into the four
places the build actually reads, and only `--install` runs the drift check
against `resource.rc`'s STRINGTABLE. Running the script "to regenerate the
icons" without it changes nothing in the build.

**This has already happened once.** `draw_format_icon` was redesigned on
2026-08-05 - from a
format-coloured plate with a large caption to the navy plate carrying the app
mark over a coloured caption bar. `--install` was never re-run, so the 41 committed `.ico` files
stayed on the 2026-08-04 design and every shipped binary compiled that older
set, for four days, with nothing failing. It surfaced on 2026-08-09 only
because `build/Test-IconsInBinaries.py` was written to look.

Run that script after any icon change:

    uv run build/Test-IconsInBinaries.py

It takes each frame of an `.ico` and searches for those exact bytes inside the
built `.exe`/`.dll` - the resource compiler copies DIB frames verbatim, so a
hit is proof the current artwork reached the binary, and a miss is proof it did
not. That is a stronger check than re-running `--install` and looking for a
zero diff: `icongen.py` pins only `pillow>=10.0`, and font rasterisation moves
between Pillow and FreeType releases, so a clean `git diff` after regenerating
means the Pillow version happens to match, not that the artwork is current.

The toolbar art in `FileManager/7zstar/` has no generator in this repository; the
bitmaps are the source. nmake does not track them either, so after replacing one
rebuild the file manager with `Build.ps1 -Clean`, or the old `.res` is linked
again. `Test-IconsInBinaries.py` does not look at BMPs; `build/Test-Smoke.ps1`
does the same byte search for them.

### 3.9b The extension/icon STRINGTABLE now feeds the installer too

`CPP/7zip/Bundles/Format7zF/resource.rc`'s `STRINGTABLE` entry 100 - the
`ext:iconIndex` pairs - had two consumers: the shell extension at run time and
`docs/logo/icongen.py --install`'s drift check. `installer/Build-Package.ps1`
is now a third: it parses that string to generate the Default Programs
registration (a `7-ZSTar.<ext>` ProgID per format, each with
`DefaultIcon = 7z.dll,<index>`).

Adding a format therefore means adding it there, or the installer will not
offer it in Settings > Default apps. Reordering the icons in `resource.rc`
without updating the indices would point the installer's ProgIDs at the wrong
pictures, which is one more reason the icon declarations and the STRINGTABLE
move together. The generator refuses to run if it parses fewer than 20 file
types, so a mangled table fails the build rather than shipping a package that
registers nothing.

### 3.10 `build/testdata/` is never exercised by CI

The committed brotli detection vectors (`corrupt-hdr.br`, `fake-magic.br`,
`mt-brotli.br`) are consumed by the smoke suite, but `brdetect.c` - the
harness that regenerates them - is never compiled or run automatically.
Re-vendoring `C/zstdmt/` or `C/brotli/` can legitimately change the container
bytes those vectors encode; regenerate them by hand
(`build/testdata/README.md` has the command) rather than assuming a red test
means a code regression.

The truncated-stream and corrupt-data vectors beside them (`trunc*`,
`corrupt-*.7z`) need no harness - they are cut from `7zz.exe`'s own output,
by the commands in the same README - but they share the caveat: their bytes
follow the vendored codecs. The checks pin the error (*Unexpected end of
data* for `trunc*`, *Data Error* for `corrupt-*.7z`), plus their shape: each
`trunc.tar.*` must still decode at least 512 bytes before its
cut, or the tar sniff fails, no drill-down happens and the check that `x`
recovers a partial `.tar` goes red for the wrong reason. The README gives the
two commands that confirm it. `trunc-prefix.br` also has to decode past 1 MiB
before its cut, or its check stops telling a drained ring buffer from a flushed
output buffer (`st_drain_output()`, ledger in `C/zstdmt/UPSTREAM.txt`). No
committed vector reaches the ring buffer's wrap: after re-vendoring `C/brotli`,
run the hand check in the README's *Truncated-stream* section.

The `oversize-*` vectors are `full.lz5`, `full.liz` and `ok-lz4mt.7z` (the
intermediates of those commands) and `mt-brotli.br`, each with one
frame-header size field patched to 1 GiB (same README). They depend only on the header layout,
so a re-vendor leaves them valid; their check pins *Data Error* and a peak
commit under 256 MB, i.e. the `MT_FRAME_SIZE_MAX` bounds in
`C/zstdmt/memmt.h`.

### 3.11 The context-menu verbs must not equal official 7-Zip's

`CPP/7zip/UI/Explorer/ContextMenu.cpp` builds every verb from three
constants - `kMainVerb`, `kOpenCascadedVerb`, `kCheckSumCascadedVerb` - and
ours start with `SevenZSTar` where upstream's start with `SevenZip`. With both
products installed and the verbs equal, Explorer's classic menu showed only one
of the two submenus: the handler whose `*\shellex\ContextMenuHandlers` key
sorts first, which is official 7-Zip's (`7-Zip` < `7-ZSTar` compared
case-insensitively, as registry keys are). Each extension
alone, and both driven directly into one `HMENU`, were fine, so nothing short
of a machine with official 7-Zip installed shows it. A merge that takes
upstream's side of those three lines builds and tests green and brings the
bug back. Nothing else in the tree reads the verb strings (7zFM invokes by
offset; the sparse package's `CSevenZStarShell` is a separate id).

### 3.12 The packaged root hides itself from the classic menu

Windows 11 lists a packaged `IExplorerCommand` verb in the classic menu as well
as the first-level one. The per-machine MSI registers both the sparse package
and the shellex handler, so whoever installed saw two identical `7-ZSTar`
submenus under **Show more options**. Taking one registration away at a time
showed which was which: the entry with the DLL icon, under *Open with*, is the
packaged one; the entry with `MenuLogo.bmp`, under *Extract All*, is shellex.

`CZipExplorerCommand::GetState` in `CPP/7zip/UI/Explorer/ContextMenu.cpp` hides
the root when `fOkToBeSlow` is false. On Windows 11 26200.8037, logging every
call, the first-level menu asked the root with `TRUE` and the classic path with
`FALSE`, for a file, a folder, a multiple selection and a desktop item. The
classic menu of a user with the "restore the old context menu" registry tweak
also asked with `FALSE`, so shellex keeps the entry there too. Only the sparse
package reaches this code, so nothing changes on Windows 10 or 7, for a build
without the package (the default per-user MSI), or for an account the package
is not registered for.

The test is compiled only under `_WIN64`. Windows 11 is 64-bit only, so the x86
package always runs under a 64-bit Explorer, which cannot load its 32-bit shellex
handler: the packaged verb is the only classic entry it has, and hiding it would
leave none.

**This relies on behaviour Microsoft does not document, and it was measured on
that one build.** The only other evidence is Bandizip, whose developer described
the same test for the same reason in May 2024, on Windows 11 with no build named
(<https://www.voidtools.com/forum/viewtopic.php?t=15040>).

`FALSE` follows from one bit Explorer passes to `QueryContextMenu`,
`CMF_ASYNCVERBSTATE` (0x400): on its own it hid the entry, and taking it out of
Explorer's flags brought the entry back. A host that does not pass it gets
`TRUE`, so it keeps both entries exactly as it did before this change; with
`CMF_NORMAL`, `CMF_EXPLORE` and `CMF_EXTENDEDVERBS` a build with and a build
without this change dumped the same two entries. A dump shows the packaged one
as an empty submenu, which is not a bug in either: it is filled on
`WM_INITMENUPOPUP`, and sent that through `IContextMenu2` it had 12 items.

If a Windows build ever asks for the first-level menu with `FALSE`, the entry
leaves the first level and stays under *Show more options*. If one asks for the
classic menu with `TRUE`, the duplicate comes back. Nothing automated sees
either: `build/Test-Smoke.ps1` checks only that the line is still in the source,
which catches a merge taking upstream's side of it (Part 4 step 4 is the same
check by hand). Part 4 step 10 is the look at both menus.

Tried and rejected, so nobody repeats them:

- **Equal verb strings.** Setting `kMainVerb` to the manifest's
  `CSevenZStarShell` left both entries: the de-duplication in Part 3.11 is
  between shellex handlers and does not cover a packaged verb.
- **`E_PENDING` for `fOkToBeSlow=FALSE`**, the documented reply. Explorer asks
  again with `TRUE` straight away and shows the entry.
- **Hiding the shellex side instead,** in `QueryContextMenu` or with an `HKCU`
  override of the handler key. The menu `IShellFolder::GetUIObjectOf` returned
  to a small test harness had the shellex entry and not the packaged one, so a
  host that builds its menu that way would lose the entry for the installing
  user.

### 3.13 The `tar.zst` menu item and the email defaults

`Add to <name>.tar.zst` is one flag, `kCompressToTarZst`, spread over four
files: `ContextMenuFlags.h` (the bit), `ContextMenu.h` (the enum, which must have
the flag's name because `CMD_REC` pastes it into both), `ContextMenu.cpp` (the
command table, the name, the menu block, `InvokeCommand`) and
`FileManager/MenuPage.cpp` (the Options row and its text). `ContextMenu.cpp` also
raises the command-ID headroom test in `QueryContextMenu` by one, for the extra
item. The Windows 11 first-level menu builds from the same table and needs
nothing of its own.

- **Bit 14 is the next bit above the ones in use, not a reserved one.** If
  upstream takes it elsewhere in the file the merge is clean and both items share
  a checkbox, so diff `ContextMenuFlags.h` after a merge and move ours if it
  collides. Moving it costs anyone with a saved `ContextMenu` value their setting
  for the item.
- **Order is the block order.** The `tar.zst` block must stay above the 7z block
  in `QueryContextMenu`, and the `MenuPage.cpp` row above the 7z row.
- **`InvokeCommandCommon` needs its `postfix` line.** The name is rebuilt there
  with 16 or more items selected, and every time from the Windows 11 first-level
  menu, whose command objects never see `QueryContextMenu`. Without that line the
  archive has no extension.
- **A target that already exists is an error, not an update.** `tar.zst` is
  write-only here: the update opens the target as `tar.zst`, and the read side of
  that format is a stub (`CStubInArchive::Open` in `TarChainRegister.cpp`), so the
  second click on the same target fails and leaves the file as it was.
  `Add to <name>.7z` updates instead. Adding `tar.zst` to `g_ArcExts` in
  `ArchiveName.cpp` would not fix this: that list only decides the name when the
  selection itself holds such an archive.

The email items default to off because `ZipRegistry.cpp` enables upstream's own
commented-out lines in `CContextMenuInfo::Load` (Part 1 Step 1 F), with the
`#include` above them. Those lines read the same commented out, so no grep for
them shows which state they are in; `build/Test-Smoke.ps1` strips the comments
first. The default is `Flags` before the registry is read: someone with a saved
`ContextMenu` value keeps it, and the new item stays off for them until they
tick it under **Tools > Options > 7-ZSTar**.

### 3.14 A button's control id is its language-string id (Donate / Website)

`CPP/7zip/UI/FileManager/AboutDialogRes.h` defines `IDB_ABOUT_DONATE 962` and
`IDB_ABOUT_HOMEPAGE 963`, and `AboutDialog.cpp` lists both in `kLangIDs`.
`LangSetDlgItems` (`LangUtils.cpp`) calls `g_Lang.Get(id)` with the **control
id itself**, so there is no mapping table to keep in step: renumber a button
and it silently looks up another language string (or none, and stays English).
Upstream's Website button was 110, which no language file defines, so it was
never translated.

Those two strings exist in no upstream file; `Lang/rebrand.py` adds them from
`Lang/donate.json` on every refresh. The ways it goes wrong, all invisible to a
green build:

* The refresh is done by copying the MSI's files over `Lang/` instead of running
  `rebrand.py` - the buttons are English everywhere. `Test-Smoke.ps1` checks
  de, ja and zh-tw and that no 962/963 string names 7-Zip.
* Upstream starts using 962 or 963 in a new release - `rebrand.py` stops with
  "already exists"; move both ids and both defines together, nothing else.
* A new upstream language has no entry in `donate.json` - it shows English on
  both buttons until its words are added. The words are one short term each;
  do not invent one for a language you cannot check, leave it out. 25 of the
  current languages are left out on purpose (the list, and why, are in
  `Lang/UPSTREAM.md`); that is not a gap to fill by guessing.
* To change or withdraw a word without an upstream MSI: edit `donate.json`, run
  `uv run Lang/rebrand.py --inject-only`, then `--inject-only --check` and
  `Test-Smoke.ps1`. The command makes `Lang/` match the JSON in either
  direction and is atomic and repeatable.
* The Donate URL is `MY_WEBSITE_URL "/#donate"` in `AboutDialog.cpp` and opens the
  site's root page, not `/<language>/`; the label must stay "Donate" ("Support"
  reads as technical support, and `Test-Smoke.ps1` fails if it appears).

### 3.15 `docs/donate-qr.png` is generated, and nothing regenerates it

The README's donation QR code is a committed picture of the wallet address
printed in the same section. It was made with the `segno` Python package (error
correction M, 12 pixels per module, 2-module border, black on white), encoding
the **bare address** with no `ethereum:` prefix and no chain id, so every wallet
reads it the same way on both networks. Nothing in the build regenerates the
picture or decodes it, so if the address ever changes, the QR must be remade
**and decoded back** (OpenCV's `QRCodeDetector` works) and compared character
for character with the text, capitals included - they are the EIP-55 checksum.
What `Test-Smoke.ps1` does check ("all README*.md carry one identical donation
address and the QR picture") is that the ten READMEs print the same address
exactly once each and reference a non-empty `docs/donate-qr.png`; it neither
reads the picture nor verifies the checksum. A QR that scans to a different
address than the text beside it is the failure this guards against.

### 3.16 The freshness stamp only watches the paths it is told about

`build/SourceStamp.ps1` fingerprints a fixed list of paths (`$script:SrcStampKinds`):
`C`, `CPP`, `Asm` for binaries, plus `installer`, `Lang`, `Help` and the packed
documents for `.msi` / `.zip`. Anything outside the list can change without any
artifact going stale, so the list must follow the build: a new top-level source
directory that feeds a binary goes into `binary` **and** `package`; a new file
or directory that `installer/Build-Package.ps1` copies into the package (its
`$Docs` list, a new vendored folder) goes into `package`. Forgetting is silent -
nothing fails, the stamp just stops covering that input. After a mainline merge,
check whether upstream added a top-level directory (Part 4 step 12). One
built-in blind spot: `.gitignore` excludes every directory named `x86/`,
`arm64/`, `arm/` and so on (build output), which also matches `Asm/x86/`,
`Asm/arm64/` and `Asm/arm/`. Edits to tracked files
there are seen; a brand-new file there is not, until it is tracked with
`git add -f`. Second blind spot, latent: `git ls-files` prints non-ASCII file
names in the console's code page, so a name like that under `Lang/` or `Help/`
would give a different fingerprint under cp950 than under UTF-8 and make
artifacts look stale when producer and consumer ran in different consoles
(measured). None of the watched paths has one today; if one appears, fix
`Invoke-SrcStampGit` to force UTF-8 output before relying on the check - do
not drop `core.quotePath=false`, which would make such paths silently
unmatched. `build/Test-SourceStamp.ps1`
holds the rules' tests (scratch repo, exit codes only); it keeps its own copy of
the document list, so extend it together with the library.

---

## Part 4 — After any merge or re-vendor, in order

1. **After a mainline merge only:** re-vendor `Lang/`, `Help/7-zip.chm` and
   `LICENSE-7-Zip.txt` from the new release's *binary* package, and update the
   two recorded SHA-256 values (Part 1 Step 2). Nothing downstream detects a
   forgotten refresh - the packaging script only notices if they are *missing*.
2. `build\Build.ps1 -Clean` - all 17 targets, zero warnings. `-Clean` is not
   optional: nmake does not track the `.rc` include graph.
3. `build\Test-Smoke.ps1` - nothing may fail. Read Part 1 Step 3 for what the
   licence checks mean when they go red.
4. `git grep -n '"7-Zip"' -- CPP/ C/` - every hit is either
   `LangUtils.cpp:30` (correct, leave it) or something the merge missed.
   Then `git grep -n '"SevenZip' -- CPP/7zip/UI/Explorer/` - the only hit may
   be the `// 7-ZSTar:` comment in `ContextMenu.cpp` that names upstream's
   value: the context-menu verbs keep our own prefix (Part 3.11), and
   upstream's value coming back is invisible to the build and the smoke test.
   Then `git grep -n 'ECS_HIDDEN :' -- CPP/7zip/UI/Explorer/ContextMenu.cpp` -
   it must print one line (Part 3.12; plain `ECS_HIDDEN` also matches upstream's
   own definition, so it proves nothing).
   Then `git grep -c 'kCompressToTarZst' -- CPP/` - `ContextMenu.cpp` 5,
   `ContextMenu.h` 1, `ContextMenuFlags.h` 1, `MenuPage.cpp` 2 (Part 3.13), and
   diff `ContextMenuFlags.h` against upstream: a new upstream flag at bit 14
   shares a checkbox with ours and no grep shows it.
   Then the two registry-key greps in Part 1 Step 1 B - both must print
   nothing.
5. `git grep -n '7-ZSTar:' -- CPP/ C/` - spot-check that the markers you expect
   are still attached to the code they describe (Part 3.8 explains the six
   false positives).
6. Diff `CPP/7zip/Guid.txt` against upstream's for id collisions (Part 3.2).
7. `installer\Build-Package.ps1` and `installer\Build-Package.ps1 -PerUser`,
   then actually install the `.msi`, open the file manager, open
   **Help > About**, and look at it.
8. **After every packaging run:** `installer\Test-MsiRegistry.ps1` - seconds,
   no elevation, reads the built `.msi` files and checks the generated Default
   Programs registration against `resource.rc`. It exists mainly for one rule:
   the installer must never write the *default* value of `HKCR\.<ext>`. Doing
   so claims the file type machine-wide and takes it from official 7-Zip,
   which is the one thing the coexistence promise forbids - and it is a single
   forgotten `Name=` in a generator loop, invisible to a green build.
   It also checks that the two scopes' packages share no component GUID
   (`installer\GUIDS.md`), but only for an architecture whose per-machine and
   per-user packages are both in `dist\` - which is why step 7 builds both. A
   "NOT checked" warning means that half did not run.
9. **If anything under `installer/sparse/`, the five custom actions or
   `Setup-ShellIntegration.ps1` changed:** both of
   `installer\Test-RemoveAssociations.ps1` (seconds, no elevation - runs the
   association cleanup against a scratch registry key and checks it takes our
   entries and leaves other programs' alone) and
   `installer\Test-SparseIntegration.ps1` (installs and uninstalls for real and
   diffs machine state across six phases). Nothing else catches a broken custom
   action: the MSI does not log what they print and they are `Return="ignore"`,
   so a failure looks exactly like success. Then right-click a file, because
   whether the entry is in the Windows 11 first-level menu is the one thing no
   script can check.
10. **After every mainline merge, whenever a new Windows 11 release is out, and
   whenever step 9 ran:** install the per-machine `.msi` on Windows 11 and, as
   the installing user, right-click a file. The entry must be in the first-level
   menu, and **Show more options** must have it exactly once (Part 3.12).
11. Update `CHANGELOG.md`, and the version in `README.md` if it moved
   (Part 3.6 - the header, the two documents and the tag move together).
12. **After every mainline merge:** `git ls-tree -d --name-only HEAD` and compare
   the top-level directories with `$script:SrcStampKinds` in
   `build\SourceStamp.ps1` (Part 3.16). A new directory that feeds a binary or
   the package must be in the list; nothing fails if it is not, the freshness
   check just stops watching it. Then `build\Test-SourceStamp.ps1`.
