#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
Vendor upstream 7-Zip's translations into 7-ZSTar's Lang/ folder.

    uv run Lang/rebrand.py <upstream-Lang-dir>          # rewrite Lang/ in place
    uv run Lang/rebrand.py <upstream-Lang-dir> --check  # verify, change nothing
    uv run Lang/rebrand.py --inject-only                # sync Lang/'s Donate/Website words with donate.json
    uv run Lang/rebrand.py --inject-only --check        # verify Lang/ carries them, change nothing

Upstream ships these only inside its binary packages, never in the source tree.
See UPSTREAM.md for where the input came from and how to refresh it.

Why this is not a plain search-and-replace
------------------------------------------
Every language file carries the product name as string id 0, and
LangUtils.cpp:28 opens each one with CLang::Open(path, "7-Zip"), which compares
that string literally (Common/Lang.cpp:158). Rewrite id 0 and the file stops
loading altogether - the language silently disappears from the picker rather
than failing loudly. So id 0 has to survive verbatim while every *other*
mention of the product becomes 7-ZSTar.

Finding id 0 needs the real grammar, not "the first line that looks right".
From CLang::OpenFromString (Common/Lang.cpp:22-120), with all CR bytes already
stripped and the ";!@Lang2@!UTF-8!" signature consumed:

  * a blank / whitespace-only line advances the id and stores nothing
  * a line starting with ';' is a comment: advances the id, stores nothing
  * a line that is entirely digits *sets* the id (and must not move backwards)
  * anything else is the string for the current id, which then advances

7-ZSTar: strings 962 and 963 (the About dialog's "Donate" and "Website"
buttons) exist in no upstream file. donate.json holds one word pair per
language (key = file stem, "_en" = en.ttt) and inject_donate() writes them into
every file, between string 961 and the explicit "1003" line, after the
rebranding. They have to be injected here rather than edited into Lang/ by
hand because a refresh replaces all 92 files wholesale from the upstream MSI.
The control id of a dialog button is also its language id (LangSetDlgItems in LangUtils.cpp),
which is why the ids are fixed at 962/963. A language missing from donate.json
gets no lines, and the program shows the English resource text for it.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

SIGNATURE = ";!@Lang2@!UTF-8!"
OLD, NEW = "7-Zip", "7-ZSTar"
HERE = Path(__file__).resolve().parent

# 7-ZSTar: About-dialog button strings that upstream does not have. The ids are
# unused in all 92 upstream files and in every .h/.rc; AboutDialogRes.h binds
# the buttons to them (a control id IS a language id, so they cannot move).
DONATE_FILE = HERE / "donate.json"
ID_DONATE, ID_WEBSITE = 962, 963

# Several translators typed the product name lower case (bg, bn, ca, co, tk in
# the 26.02 set), so matching only the canonical spelling would leave those UIs
# saying "7-zip". Id 0 is matched literally against OLD elsewhere and is never
# touched here, so widening the case does not put the identity string at risk.
NAME_RE = re.compile(r"7-[Zz]ip")

# ...but a lower-case match is also how upstream's home page and help file are
# spelled. Renaming "7-zip.org" or "7-zip.chm" would produce a dead link rather
# than a rebrand, so those are reported instead of rewritten.
NAME_NOT_A_BRAND_RE = re.compile(r"7-[Zz]ip\s*\.\s*(org|chm|exe|dll|sfx)", re.I)


# Upstream parses an id line with ConvertStringToUInt32, which accepts ASCII
# 0-9 only - str.isdigit() would also accept Unicode digits and misread a
# translated string as an id line.
ASCII_DIGITS = set("0123456789")

# Lang.cpp:106 rejects the file outright above this, so an id line past it is
# not "a big id", it is a file the application will refuse to load.
MAX_ID = 1 << 30


def string_line_ids(lines: list[str]) -> dict[int, int]:
    """Map line index -> string id, for the lines that carry strings."""
    out: dict[int, int] = {}
    ident = -1024
    for i, raw in enumerate(lines):
        line = raw.rstrip("\n")
        if not line.strip(" \t"):
            ident += 1
        elif line.startswith(";"):
            ident += 1
        elif line and set(line) <= ASCII_DIGITS:
            # Mirror both of upstream's rejections (Lang.cpp:106) so malformed
            # input fails here, loudly, instead of at runtime as a language that
            # quietly never appears in the picker.
            if int(line) > MAX_ID:
                raise ValueError(f"line {i + 1}: id {line} exceeds upstream's {MAX_ID} limit")
            if int(line) < ident:
                raise ValueError(f"line {i + 1}: id {line} moves backwards from {ident}")
            ident = int(line)
        else:
            if ident < 0:
                raise ValueError(f"line {i + 1}: string before any id")
            out[i] = ident
            ident += 1
    return out


def split_file(path: Path) -> tuple[bool, list[str]]:
    """(had_bom, lines-with-terminators). CRLF is preserved as written."""
    raw = path.read_bytes()
    bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig" if bom else "utf-8")
    return bom, text.splitlines(keepends=True)


def load_donate() -> dict[str, dict[str, str]]:
    """donate.json -> {file stem: {"donate": ..., "website": ...}}, validated."""
    import json
    data = json.loads(DONATE_FILE.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("donate.json must be an object of {language: {donate, website}}")
    for key, pair in data.items():
        if not isinstance(pair, dict):
            raise ValueError(f"donate.json[{key!r}] must be an object")
        if set(pair) != {"donate", "website"}:
            raise ValueError(f"donate.json[{key!r}] must have exactly donate+website, has {sorted(pair)}")
        for name, word in pair.items():
            if not isinstance(word, str) or not word.strip():
                raise ValueError(f"donate.json[{key!r}].{name} is empty")
            if word != word.strip() or "\n" in word or "\r" in word:
                raise ValueError(f"donate.json[{key!r}].{name} has stray whitespace or a newline")
            # Either of these would be parsed as a comment or an id line, not a string.
            if word.startswith(";") or set(word) <= ASCII_DIGITS:
                raise ValueError(f"donate.json[{key!r}].{name} would parse as a comment/id line")
            if NAME_RE.search(word):
                raise ValueError(f"donate.json[{key!r}].{name} names the product")
    return data


def inject_donate(text: str, pair: dict[str, str] | None) -> str:
    """Insert ids 962/963 before the first explicit id line above 963.

    `text` is a whole language file as rebrand() returns it (BOM char kept).
    Nothing is inserted when the language has no words. Line endings follow the
    line before the insertion point, so ja.txt-style CRLF files stay CRLF.
    """
    if pair is None:
        return text
    bom = text.startswith("\ufeff")
    lines = (text[1:] if bom else text).splitlines(keepends=True)
    ids = string_line_ids([ln.replace("\r", "") for ln in lines])
    if {ID_DONATE, ID_WEBSITE} & set(ids.values()):
        # Reached from the full refresh, where the input is an upstream file.
        # (--inject-only goes through sync_donate(), which handles files that
        # already carry our words.)
        raise ValueError("string 962 or 963 already exists in this file - if it came from an "
                         "upstream MSI, upstream has started using these ids: move "
                         "IDB_ABOUT_DONATE and IDB_ABOUT_HOMEPAGE (MAINTAINING.md 3.14)")
    # Find the insertion line with the same grammar string_line_ids() uses.
    ident = -1024
    at = -1
    for i, raw in enumerate(lines):
        line = raw.replace("\r", "").rstrip("\n")
        if not line.strip(" \t") or line.startswith(";"):
            ident += 1
        elif set(line) <= ASCII_DIGITS:
            if int(line) > ID_WEBSITE:
                if ident > ID_DONATE:
                    raise ValueError(f"line {i + 1}: id {ident} is already past {ID_DONATE}")
                at = i
                break
            ident = int(line)
        else:
            ident += 1
    if at < 0:
        raise ValueError("no explicit id line above 963 to insert before")
    nl = "\r\n" if lines[at - 1].endswith("\r\n") else "\n"
    new = [f"{ID_DONATE}{nl}", f"{pair['donate']}{nl}",
           f"{ID_WEBSITE}{nl}", f"{pair['website']}{nl}"]
    out = "".join(lines[:at] + new + lines[at:])
    return ("\ufeff" + out) if bom else out


def donate_block(lines: list[str]) -> int | None:
    """Index of the "962" line of our four-line block, or None if neither id is present.

    The block is exactly what inject_donate() writes: id line 962, its string,
    id line 963, its string. Present in any other shape (only one of the two,
    separated, in a different order) is a ValueError - rewriting that by
    machine would be a guess.
    """
    ids = string_line_ids([ln.replace("\r", "") for ln in lines])
    has = {v for v in ids.values()} & {ID_DONATE, ID_WEBSITE}
    if not has:
        return None
    by_id = {v: k for k, v in ids.items()}
    k = by_id.get(ID_DONATE)
    if (ID_DONATE not in has or ID_WEBSITE not in has
            or by_id[ID_WEBSITE] != k + 2
            or lines[k - 1].strip() != str(ID_DONATE)
            or lines[k + 1].strip() != str(ID_WEBSITE)):
        raise ValueError("962/963 are present but not as the four consecutive lines "
                         "'962 / word / 963 / word' - fix this file by hand")
    return k - 1


def strip_donate(text: str) -> str:
    """The file without our 962/963 block (unchanged if it has none)."""
    bom = text.startswith("\ufeff")
    lines = (text[1:] if bom else text).splitlines(keepends=True)
    at = donate_block(lines)
    if at is not None:
        del lines[at:at + 4]
    out = "".join(lines)
    return ("\ufeff" + out) if bom else out


def sync_donate(text: str, pair: dict[str, str] | None) -> str:
    """Bring the file's 962/963 block in line with donate.json (the --inject-only rule).

    no block, no words  -> unchanged
    no block, words     -> inject (inject_donate)
    block, same words   -> unchanged
    block, other words  -> the two string lines are replaced in place
    block, no words     -> the four lines are removed (the language falls back to English)
    """
    bom = text.startswith("\ufeff")
    lines = (text[1:] if bom else text).splitlines(keepends=True)
    at = donate_block(lines)
    if at is None:
        return inject_donate(text, pair)
    if pair is None:
        return strip_donate(text)
    for off, word in ((1, pair["donate"]), (3, pair["website"])):
        nl = "\r\n" if lines[at + off].endswith("\r\n") else "\n"
        if lines[at + off].rstrip("\r\n") != word:
            lines[at + off] = word + nl
    out = "".join(lines)
    return ("\ufeff" + out) if bom else out


def rebrand(path: Path) -> tuple[str, int, str, list[str]]:
    """Returns (new text, lines changed, the id-0 string, skipped-link lines)."""
    bom, lines = split_file(path)
    # CLang strips every CR before parsing, so the grammar never sees them.
    ids = string_line_ids([ln.replace("\r", "") for ln in lines])

    id0 = [i for i, v in ids.items() if v == 0]
    if len(id0) != 1:
        raise ValueError(f"expected exactly one id-0 string, found {len(id0)}")
    id0_line = id0[0]
    if lines[id0_line].strip() != OLD:
        raise ValueError(f"id 0 is {lines[id0_line].strip()!r}, expected {OLD!r}")

    changed = 0
    skipped: list[str] = []
    for i, line in enumerate(lines):
        if i == id0_line or not NAME_RE.search(line):
            continue
        if NAME_NOT_A_BRAND_RE.search(line):
            skipped.append(f"{path.name}:{i + 1}: {line.strip()}")
            continue
        lines[i] = NAME_RE.sub(NEW, line)
        changed += 1

    text = "".join(lines)
    return ("﻿" + text if bom else text), changed, lines[id0_line].strip(), skipped


def verify(text: str, pair: dict[str, str] | None = None, before: str | None = None) -> None:
    """Re-parse the output the way the application will and assert on it.

    7-ZSTar: `pair` is the language's donate.json entry (None = no words). When
    given, 962/963 must equal it; when None, 962/963 must not exist. `before`,
    if supplied, is the text prior to injection: strings 961 and 1003 must be
    identical to it, so the insertion cannot have shifted its neighbours.
    """
    body = text.lstrip("﻿")
    if not body.startswith(SIGNATURE):
        raise ValueError("signature line was lost")
    lines = body.replace("\r", "").splitlines(keepends=True)
    ids = string_line_ids(lines)
    by_id = {v: k for k, v in ids.items()}
    if 0 not in by_id:
        raise ValueError("no id-0 string after rewrite")
    if lines[by_id[0]].strip() != OLD:
        raise ValueError(f"id 0 became {lines[by_id[0]].strip()!r} - the file would not load")
    for i, line in enumerate(lines):
        if i != by_id[0] and NAME_RE.search(line) and not NAME_NOT_A_BRAND_RE.search(line):
            raise ValueError(f"line {i + 1} still says {line.strip()!r}")
    got = {k: lines[v].strip() for k, v in by_id.items() if k in (ID_DONATE, ID_WEBSITE, 961, 1003)}
    if pair is None:
        if ID_DONATE in got or ID_WEBSITE in got:
            raise ValueError("962/963 are present but donate.json has no words for this "
                             "language (run --inject-only to remove them)")
    elif ID_DONATE not in got and ID_WEBSITE not in got:
        raise ValueError("no 962/963 in this file although donate.json has words for it "
                         "(run --inject-only to add them)")
    elif got.get(ID_DONATE) != pair["donate"] or got.get(ID_WEBSITE) != pair["website"]:
        raise ValueError(f"962/963 are {got.get(ID_DONATE)!r}/{got.get(ID_WEBSITE)!r}, "
                         f"donate.json says {pair['donate']!r}/{pair['website']!r} "
                         f"(run --inject-only to replace them)")
    for k in (961, 1003):
        if k not in got:
            raise ValueError(f"string {k} is missing")
    if before is not None:
        b = before.lstrip("\ufeff").replace("\r", "").splitlines(keepends=True)
        bby = {v: b[k].strip() for k, v in string_line_ids(b).items()}
        for k in (961, 1003):
            if bby.get(k) != got[k]:
                raise ValueError(f"string {k} changed by the injection: {bby.get(k)!r} -> {got[k]!r}")


def stem_key(p: Path) -> str:
    """donate.json key for a language file: its stem, or "_en" for en.ttt."""
    return "_en" if p.suffix == ".ttt" else p.stem


def inject_only(check: bool) -> int:
    """Add (or, with --check, verify) the 962/963 words in the Lang/ folder itself."""
    try:
        donate = load_donate()
    except (OSError, ValueError) as exc:
        print(f"  ! cannot use {DONATE_FILE.name}: {exc}", file=sys.stderr)
        return 1
    files = sorted(p for p in HERE.iterdir()
                   if p.is_file() and p.suffix in (".txt", ".ttt"))
    unknown = sorted(set(donate) - {stem_key(p) for p in files})
    if unknown:
        print(f"  ! donate.json has keys with no Lang/ file: {', '.join(unknown)}", file=sys.stderr)
        return 1
    # The rule is "make Lang/ say what donate.json says" (sync_donate), so this is
    # also how a word is changed or withdrawn: edit donate.json, run this.
    # Two phases - work out and verify every file first, write only if all of
    # them pass - so a failure cannot leave Lang/ half done. Running it again
    # when everything already matches writes nothing.
    done = skipped = 0
    added = replaced = removed = 0
    pending: list[tuple[Path, str]] = []
    for p in files:
        pair = donate.get(stem_key(p))
        text = p.read_bytes().decode("utf-8")  # a BOM, if any, survives as U+FEFF
        try:
            if check:
                verify(text, pair)
            else:
                new = sync_donate(text, pair)
                verify(new, pair, before=strip_donate(text))
                if new != text:
                    pending.append((p, new))
                    had = "\n962\n" in text.replace("\r", "")
                    if pair is None:
                        removed += 1
                    elif had:
                        replaced += 1
                    else:
                        added += 1
        except (ValueError, UnicodeDecodeError) as exc:
            print(f"  ! {p.name}: {exc}", file=sys.stderr)
            return 1
        if pair is None:
            skipped += 1
        else:
            done += 1
    for p, new in pending:
        p.write_bytes(new.encode("utf-8"))
    if check:
        print(f"checked {done} files (Donate/Website, ids {ID_DONATE}/{ID_WEBSITE}); "
              f"{skipped} file(s) have no words in donate.json and show English")
    else:
        print(f"synced Lang/ with donate.json: {added} added, {replaced} replaced, "
              f"{removed} removed, {len(files) - len(pending)} already matched "
              f"({done} languages have words, {skipped} show English)")
    return 0


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 2
    # An unknown flag used to fall through into the writing mode silently
    # (--chek would have rewritten Lang/ instead of checking it).
    known = {"--check", "--inject-only"}
    bad = [a for a in argv if a.startswith("-") and a not in known]
    if bad:
        print(f"unknown option(s): {' '.join(bad)}\n"
              f"usage: rebrand.py <upstream-Lang-dir> [--check]\n"
              f"       rebrand.py --inject-only [--check]", file=sys.stderr)
        return 2
    if "--inject-only" in argv:
        extra = [a for a in argv if not a.startswith("-")]
        if extra:
            print(f"--inject-only takes no directory (got {extra[0]}); it works on Lang/ itself",
                  file=sys.stderr)
            return 2
        return inject_only("--check" in argv)
    if argv[0].startswith("-"):
        print("missing <upstream-Lang-dir>; usage: rebrand.py <upstream-Lang-dir> [--check]",
              file=sys.stderr)
        return 2
    src = Path(argv[0]).resolve()
    check = "--check" in argv[1:]
    try:
        donate = load_donate()
    except (OSError, ValueError) as exc:
        print(f"  ! cannot use {DONATE_FILE.name}: {exc}", file=sys.stderr)
        return 1
    if not src.is_dir():
        print(f"not a directory: {src}", file=sys.stderr)
        return 1

    files = sorted(p for p in src.iterdir()
                   if p.is_file() and p.suffix in (".txt", ".ttt"))
    if not files:
        print(f"no .txt/.ttt files under {src}", file=sys.stderr)
        return 1

    unknown = sorted(set(donate) - {stem_key(p) for p in files})
    if unknown:
        print(f"  ! donate.json has keys with no upstream file: {', '.join(unknown)} "
              f"(language dropped upstream? remove it)", file=sys.stderr)
        return 1

    total_lines = total_files = drift = 0
    all_skipped: list[str] = []
    # Two phases, as in inject_only(): generate and verify every file first and
    # write only if all of them pass. Writing inside this loop left Lang/ half
    # old and half new when a later file (alphabetically) failed, e.g. upstream
    # starting to use 962/963 - the very error this tool is meant to stop on.
    pending: list[tuple[Path, bytes]] = []
    for p in files:
        try:
            text, changed, id0, skipped = rebrand(p)
            # 7-ZSTar: the Donate/Website words go in after the rebranding.
            branded = text
            pair = donate.get(stem_key(p))
            text = inject_donate(text, pair)
            verify(text, pair, before=branded)
        except (ValueError, UnicodeDecodeError) as exc:
            print(f"  ! {p.name}: {exc}", file=sys.stderr)
            return 1
        dst = HERE / p.name
        data = text.encode("utf-8")
        if check:
            if not dst.is_file() or dst.read_bytes() != data:
                print(f"  ! {p.name}: differs from Lang/{p.name}")
                drift += 1
        else:
            pending.append((dst, data))
        if changed:
            total_files += 1
            total_lines += changed
        all_skipped += skipped
        assert id0 == OLD

    for dst, data in pending:
        dst.write_bytes(data)

    # Files this run did not write, but which are sitting in Lang/ anyway. They
    # are left over from an older upstream release that still shipped that
    # language, and Build-Package.ps1 globs the whole directory - so without
    # this check a refresh would quietly package one language at 26.02 while
    # every other one moved on.
    written = {p.name for p in files}
    orphans = sorted(p.name for p in HERE.iterdir()
                     if p.is_file() and p.suffix in (".txt", ".ttt")
                     and p.name not in written)

    verb = "checked" if check else "wrote"
    print(f"{verb} {len(files)} files; {OLD} -> {NEW} on {total_lines} lines "
          f"across {total_files} files; id 0 left as {OLD!r} in all of them")
    if orphans:
        print(f"  ! {len(orphans)} file(s) in Lang/ are not in this upstream set - "
              f"stale, from an older release. Delete them:")
        for o in orphans:
            print(f"    {o}")
        return 1
    if all_skipped:
        print(f"  {len(all_skipped)} line(s) left alone (upstream URL/filename, "
              f"not a brand mention):")
        for s in all_skipped:
            print(f"    {s}")
    if check and drift:
        print(f"  {drift} file(s) out of date - re-run without --check")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
