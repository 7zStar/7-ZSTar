# Lang/ provenance

Upstream 7-Zip's translations, rebranded for 7-ZSTar. **Not written here** -
every string except the ones naming the product comes from upstream verbatim.

Named `UPSTREAM.md` rather than `UPSTREAM.txt` like `C/zstdmt/UPSTREAM.txt`
on purpose: `installer/Build-Package.ps1` picks up `Lang/*.txt` wholesale, so a
`.txt` here would be installed as if it were a language file.

## Where these came from

| | |
|---|---|
| Version | 7-Zip **26.05** (2026-10-21) - the same release this fork is based on |
| Source | `https://github.com/ip7z/7zip/releases/download/26.05/7z2605-x64.msi` |
| SHA-256 | `3fe4ab99fa15629c652944309a2b2bc6e41fc933fc6b63f5df1ebcf3aea68263` |
| Size | 2,008,576 bytes |
| Extracted with | `msiexec /a <msi> /qn TARGETDIR=<dir>` (administrative install - unpacks only, installs nothing) |
| Contents | 92 `.txt` + `en.ttt`, all `;!@Lang2@!UTF-8!`, no README or other stowaways |

That download URL is what `https://www.7-zip.org/download.html` itself links
to: upstream now hosts its binaries on its own GitHub releases, which is also
the remote this fork tracks (`upstream` -> `ip7z/7zip`).

Upstream ships translations **only** in its binary packages - the source tree
and the git repo contain none - which is why they have to be vendored rather
than built.

## What was changed

`rebrand.py` rewrites the product name and nothing else:

* `7-Zip` -> `7-ZSTar` on every line **except the string with id 0**.
* `7-zip` -> `7-ZSTar` too. Five translators (bg, bn, ca, co, tk) typed it
  lower case; matching only the canonical spelling would leave those UIs
  half-rebranded.
* Anything that looks like a URL or filename (`7-zip.org`, `7-zip.chm`, ...)
  is reported and left alone - renaming those makes a dead link, not a brand.

**Id 0 must stay exactly `7-Zip`.** `LangUtils.cpp:28` opens every language
file with `CLang::Open(path, "7-Zip")` and `Common/Lang.cpp:158` compares that
string literally; rewrite it and `Open` returns false, so the language vanishes
from the picker with no error anywhere. `rebrand.py` locates id 0 by
implementing upstream's actual line grammar (`Common/Lang.cpp:22-120`), not by
pattern-matching, and re-parses its own output before writing.

Result on this set: **469 lines rewritten across 85 files**; the remaining 93
occurrences are exactly one id-0 line per file.

## What was added: strings 962 and 963

The About dialog has a **Donate** and a **Website** button. Neither word exists
in any upstream file, so `rebrand.py` adds them, from `donate.json`:

* `donate.json` - one `{"donate": ..., "website": ...}` pair per language, keyed
  by file stem; `_en` is `en.ttt`. Written by 7-ZSTar, not by upstream. A
  language with no entry gets nothing inserted and shows the English resource
  text ("Donate" / "Website") - that is the intended fallback, and it is how a
  translation that could not be checked was dropped.
* `rebrand.py` inserts `962`, the word, `963`, the word, right before the first
  explicit id line above 963 (`1003` in every file), after the rebranding,
  keeping the file's own line ending and BOM. It refuses a file that already has
  962 or 963, re-parses its output, and `verify()` asserts that 962/963 equal
  the JSON and that strings 961 and 1003 are unchanged.
* The ids are fixed: a button's control id is its language id
  (`LangUtils.cpp` `LangSetDlgItems`), so `AboutDialogRes.h` defines
  `IDB_ABOUT_DONATE 962` / `IDB_ABOUT_HOMEPAGE 963`. Both were unused in all 92
  upstream files, in every `.h` and in every `.rc`. **Before a refresh, grep
  the new release's files for lines `962` and `963`** - if upstream ever uses
  them, `rebrand.py` stops with an error and the ids have to move together with
  the two defines.

The full flow (the refresh below) injects them automatically. Without an
upstream MSI, `uv run Lang/rebrand.py --inject-only` makes the current `Lang/`
say what `donate.json` says: files without the words get them, files whose
words differ get just those two lines replaced, and files whose language is not
in the JSON lose the four lines. It works out and verifies every file first and
writes only if all of them pass, and running it again writes nothing.
`--inject-only --check` verifies without writing and says which of the three
a failing file needs.

### Changing or withdrawing a word

1. Edit `donate.json`: change the word, or delete the language's entry to
   withdraw it (that language then shows English).
2. `uv run Lang/rebrand.py --inject-only`
3. `uv run Lang/rebrand.py --inject-only --check`, and `build\Test-Smoke.ps1`.

`git diff` should show only the two string lines of a changed language, or four
removed lines for a withdrawn one.

### Languages that show English on both buttons

These 25 languages have no entry in `donate.json`, so the buttons read
"Donate" and "Website" in them:

`an`, `ba`, `co`, `ext`, `fur`, `io`, `kaa`, `kab`, `kk`, `ku`, `ku-ckb`, `ky`,
`lij`, `mng`, `mng2`, `ps`, `sa`, `sq`, `tg`, `tk`, `tt`, `ug`, `uz`, `uz-cyrl`,
`yo` (each is `Lang/<name>.txt`).

The words for the other languages were drafted by a model and then checked by a
second, independent pass. Wherever that pass could not confirm a word - small
languages with little reference material, a word that also means something
else (forgiveness, charity, technical support), or a doubtful way of writing
"website" - the language was left out rather than guessed at; a wrong word on a
button is worse than an English one. `mng2.txt` is left out for a different
reason: that file is written in a legacy private-use encoding (MenkCode), not
standard Unicode, so a standard Unicode word would show as blanks there.

To add one: put a `{"donate": ..., "website": ...}` entry for it into
`donate.json` (one short word each, no `&`, no colon; ideally confirmed by a
speaker of the language), then follow "Changing or withdrawing a word".

## Refreshing to a newer 7-Zip

1. Download the matching `7zXXXX-x64.msi` from the link the official download
   page lists. Record URL, size and SHA-256 in the table above.
2. Unpack it with `msiexec /a` into a scratch directory. Do not run it.
3. `uv run Lang/rebrand.py <unpacked>\Files\7-Zip\Lang` - this also writes
   strings 962/963 from `donate.json` (see above). If a language was dropped
   upstream it refuses to run until its `donate.json` entry is removed.
4. Read the "left alone" list it prints - a new URL-shaped string may need a
   decision rather than a silent skip. A new upstream language has no
   `donate.json` entry yet and will show English on both buttons; add its words
   and re-run.
5. If it reports stale files, delete them and re-run. Those are languages the
   new release dropped; `Build-Package.ps1` globs the whole folder, so leaving
   one behind ships that language at the *old* version while every other one
   moves forward.
6. `uv run Lang/rebrand.py <unpacked>\Files\7-Zip\Lang --check` re-verifies
   without writing; the same call belongs in CI if this ever needs guarding.

## Licensing

Same terms as the rest of upstream 7-Zip: LGPL. Recorded in `NOTICE` at the
repo root along with the other vendored components.

## Known limitation

Strings that 7-ZSTar added itself - the zstd level/dictionary fields in the
compression dialog, the new archive format names - have no upstream
translation and stay English in every language. The one exception is the
About dialog's Donate and Website buttons (962/963 above), whose words are
machine-assisted translations checked by a second pass, not by native speakers;
they are one word each, and a language whose word could not be confirmed is
simply absent from `donate.json` (the list is above).
