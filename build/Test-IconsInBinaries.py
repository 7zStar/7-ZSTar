#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
Check that the icons in the source tree actually reached the built binaries.

A green build is not evidence here. nmake does not track the include graph of
resource.rc, so editing an .rc that is #included by another one leaves stale
.res files behind and every target still reports OK - that has happened in this
project twice. Deleting the outputs (-Clean) is the fix; this is the check that
the fix worked.

Method: an .ico stores each frame as a DIB, and the resource compiler copies
those DIB bytes into RT_ICON verbatim - no re-encoding. So the frame bytes from
the .ico must appear literally inside the .exe/.dll. Searching for them needs no
PE parser and cannot be fooled by a stale resource that merely has the right
size.

    uv run build\\Test-IconsInBinaries.py            # all three platforms
    uv run build\\Test-IconsInBinaries.py x64
"""
from __future__ import annotations

import struct
import sys
from pathlib import Path

SRC = Path(__file__).resolve().parents[1]

# icon source -> binaries that must contain it, relative to the platform's
# output directory.
EXPECT = {
    "CPP/7zip/UI/FileManager/7zstar.ico": [
        "CPP/7zip/UI/FileManager/{plat}/7zFM.exe",
        # The Explorer extension carries the app icon too:
        # IExplorerCommand::GetIcon hands the shell this DLL's path and lets it
        # take index 0, so this is the icon on the Windows 11 first-level menu
        # entry. It compiles the FileManager copy of the .ico, not its own.
        "CPP/7zip/UI/Explorer/{plat}/7-zip.dll",
    ],
    "CPP/7zip/UI/GUI/7zstar.ico": [
        "CPP/7zip/UI/GUI/{plat}/7zG.exe",
    ],
    # Two of the 41 format icons. All of them are compiled into 7z.dll through
    # Bundles/Format7zF/resource.rc, so samples are enough - and one of each
    # kind on purpose: zst.ico is a plain single-format icon, tzst.ico is one
    # of the chained tar.* variants with the extra tar band, which is a
    # different drawing path in icongen.py.
    "CPP/7zip/Archive/Icons/7zstar/zst.ico": [
        "CPP/7zip/Bundles/Format7zF/{plat}/7z.dll",
    ],
    "CPP/7zip/Archive/Icons/7zstar/tzst.ico": [
        "CPP/7zip/Bundles/Format7zF/{plat}/7z.dll",
    ],
}


def ico_frames(path: Path) -> list[bytes]:
    """Raw bytes of each frame in an .ico, in file order."""
    data = path.read_bytes()
    reserved, kind, count = struct.unpack_from("<HHH", data, 0)
    if reserved != 0 or kind != 1:
        raise ValueError(f"{path}: not an .ico (reserved={reserved}, type={kind})")
    frames = []
    for i in range(count):
        off = 6 + i * 16
        size, offset = struct.unpack_from("<II", data, off + 8)
        frames.append(data[offset:offset + size])
    return frames


def main(argv: list[str]) -> int:
    platforms = argv[1:] or ["x64", "x86", "arm64"]
    problems = 0
    for plat in platforms:
        print(f"--- {plat}")
        for ico_rel, targets in EXPECT.items():
            ico = SRC / ico_rel
            if not ico.is_file():
                print(f"  ! {ico_rel}: missing from the source tree")
                problems += 1
                continue
            frames = ico_frames(ico)
            for target_rel in targets:
                binary = SRC / target_rel.format(plat=plat)
                if not binary.is_file():
                    print(f"  ! {target_rel.format(plat=plat)}: not built")
                    problems += 1
                    continue
                blob = binary.read_bytes()
                # 256px frames are stored as PNG and can legitimately be
                # re-packed, so judge on the DIB frames only.
                dib = [f for f in frames if not f.startswith(b"\x89PNG")]
                hits = sum(1 for f in dib if f in blob)
                ok = hits == len(dib)
                if not ok:
                    problems += 1
                print(f"  [{'PASS' if ok else 'FAIL'}] {binary.name:<12} "
                      f"{hits}/{len(dib)} frames of {ico.name} found")
    print(f"{'OK' if problems == 0 else str(problems) + ' PROBLEM(S)'}")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
