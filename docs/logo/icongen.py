#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10.0"]
# ///
"""
7-ZSTar icon generator.

Renders the whole icon system from a single source of truth:
  * the application icon (proposal B: white "7" + amber star on deep navy)
  * the horizontal wordmark
  * 41 archive-format association icons

Everything is drawn in a 128x128 design space and supersampled down to the
target size, so each raster size can carry its own optimised geometry
(small sizes drop detail and fatten strokes instead of just scaling).

Rendering alone writes only to ./out/ next to this script, which is gitignored
- so re-running this on its own will NOT change the icons the build uses.
Pass --install to also copy each artifact to the place the .rc files reference:

    uv run icongen.py --install

  ../../CPP/7zip/Archive/Icons/7zstar/*.ico      41 format icons (Format7zF)
  ../../CPP/7zip/UI/FileManager/7zstar.ico       app icon (7zFM + Explorer ext)
  ../../CPP/7zip/UI/GUI/7zstar.ico               app icon (7zG)
  ../../CPP/7zip/UI/FileManager/7zstarLogo.ico   About dialog wordmark plate
  ../../CPP/7zip/UI/Explorer/MenuLogo.bmp        13x13 1bpp context-menu mark
  ../../installer/wix-banner.bmp                 WixUI page banner  493x58
  ../../installer/wix-dialog.bmp                 WixUI welcome/finish  493x312
  ./wordmark-*.png, ./appicon-256.png            README assets

--install also checks the extension->icon-index table below against the
STRINGTABLE in Format7zF/resource.rc and reports any drift.
"""
from __future__ import annotations

import math
import struct
import sys
from dataclasses import dataclass, field
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent / "out"
# docs/logo -> docs -> src
SRC_ROOT = Path(__file__).resolve().parents[2]
RESOURCE_RC = SRC_ROOT / "CPP/7zip/Bundles/Format7zF/resource.rc"

# ---------------------------------------------------------------- palette --

NAVY = "#152238"      # brand base: every 7-ZSTar surface sits on this
AMBER = "#F6A609"     # the star
WHITE = "#FFFFFF"

FONT_CANDIDATES = [
    "C:/Windows/Fonts/segoeuib.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
    "C:/Windows/Fonts/calibrib.ttf",
]


def load_font(px: int) -> ImageFont.FreeTypeFont:
    for cand in FONT_CANDIDATES:
        if Path(cand).exists():
            return ImageFont.truetype(cand, px)
    raise RuntimeError("no bold sans font found; checked: " + ", ".join(FONT_CANDIDATES))


# ------------------------------------------------------------- primitives --


def star_points(cx: float, cy: float, r_out: float, r_in: float,
                n: int = 5, rot: float = -90.0) -> list[tuple[float, float]]:
    """Vertices of an n-pointed star, first point at `rot` degrees."""
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * (180.0 / n))
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def scaled(pts, s: float):
    return [(x * s, y * s) for x, y in pts]


def _srgb_lum(hexcolor: str) -> float:
    r, g, b = (int(hexcolor[i:i + 2], 16) / 255.0 for i in (1, 3, 5))
    f = lambda v: v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def pick_ink(bg: str) -> str:
    """Whichever of navy/white has more WCAG contrast against `bg`."""
    lb = _srgb_lum(bg)
    contrast = lambda l1, l2: (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    return NAVY if contrast(lb, _srgb_lum(NAVY)) >= contrast(lb, _srgb_lum(WHITE)) else WHITE


def draw_label(im: Image.Image, text: str, ink: str, cx: float, cy: float,
               max_w: float, cap_px: int) -> None:
    """
    Render `text` at a FIXED cap height, squeezing horizontally when it is too
    wide. Keeps 'LZMA' optically the same size as '7Z' instead of letting the
    long labels shrink away.
    """
    font = load_font(cap_px)
    probe = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    box = probe.textbbox((0, 0), text, font=font, anchor="lt")
    tw, th = box[2] - box[0], box[3] - box[1]
    if tw <= 0 or th <= 0:
        return

    layer = Image.new("RGBA", (tw + 4, th + 4), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((-box[0] + 2, -box[1] + 2), text, font=font,
                               fill=ink, anchor="lt")

    if layer.width > max_w:
        layer = layer.resize((int(max_w), layer.height), Image.LANCZOS)

    im.alpha_composite(layer, (round(cx - layer.width / 2),
                               round(cy - layer.height / 2)))


# --------------------------------------------------------------- app icon --

# The mark in the 128x128 design space: the "7" as a polygon, the star as
# (cx, cy, r_out, r_in), and the ink extents of the two together.
#
# Two tiers, because a mark thins out as it shrinks: BOLD fattens the 7's
# strokes and grows the star so both survive being rendered around 10-18 px.
# draw_app_icon's size tiers and every format icon read from these, so the app
# icon and the archive icons can only ever drift together.
MARK_SEVEN = [(22, 24), (88, 24), (88, 41), (66, 104), (42, 104), (64, 41), (22, 41)]
MARK_STAR = (86, 92, 26, 11)
MARK_BOX = (22, 24, 112, 118)

MARK_SEVEN_BOLD = [(16, 18), (74, 18), (74, 42), (54, 96), (26, 96), (50, 42), (16, 42)]
MARK_STAR_BOLD = (90, 91.5, 37.5, 15.9)
MARK_BOX_BOLD = (16, 18, 127.5, 129.0)

# Below this rendered height the mark is drawn from the bold tier.
MARK_BOLD_BELOW_PX = 20


def draw_mark(d: ImageDraw.ImageDraw, box: tuple[float, float, float, float],
              s: float, seven_fill: str = WHITE, star_fill: str = AMBER,
              keyline: str | None = NAVY, keyline_w: float = 7.0,
              bold: bool = False) -> None:
    """
    Draw the app icon's 7+star lockup fitted into `box` of the 128-space, then
    scaled by `s` onto the supersampled canvas.

    The keyline is what keeps the star a star: without it the amber melts into
    the warm format colours (7z is the star's own #F6A609), and on a navy plate
    it is what separates the star's arm from the stroke of the "7".
    """
    seven = MARK_SEVEN_BOLD if bold else MARK_SEVEN
    star = MARK_STAR_BOLD if bold else MARK_STAR
    x0, y0, x1, y1 = box
    mx0, my0, mx1, my1 = MARK_BOX_BOLD if bold else MARK_BOX
    k = min((x1 - x0) / (mx1 - mx0), (y1 - y0) / (my1 - my0))
    ox = x0 + ((x1 - x0) - (mx1 - mx0) * k) / 2 - mx0 * k
    oy = y0 + ((y1 - y0) - (my1 - my0) * k) / 2 - my0 * k
    place = lambda pts: [((x * k + ox) * s, (y * k + oy) * s) for x, y in pts]

    d.polygon(place(seven), fill=seven_fill)
    sp = place(star_points(*star))
    if keyline:
        d.line(sp + [sp[0]], fill=keyline,
               width=max(1, round(keyline_w * k * s)), joint="curve")
    d.polygon(sp, fill=star_fill)


def draw_app_icon(px: int) -> Image.Image:
    """Proposal B. Three geometry tiers: <=16, <=32, and full detail."""
    ss = 4 if px >= 256 else 8
    c = px * ss
    s = c / 128.0
    im = Image.new("RGBA", (c, c), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    if px <= 16:
        radius, seven = 24, MARK_SEVEN_BOLD
        star = star_points(*MARK_STAR_BOLD)
        stroke = 11
    elif px <= 32:
        radius, seven = 26, [(20, 22), (84, 22), (84, 41), (62, 102),
                             (36, 102), (60, 41), (20, 41)]
        star = star_points(88, 92, 30, 12.6)
        stroke = 9
    else:
        radius, seven = 28, MARK_SEVEN
        star = star_points(*MARK_STAR)
        stroke = 7

    d.rounded_rectangle([0, 0, c - 1, c - 1], radius=radius * s, fill=NAVY)
    d.polygon(scaled(seven, s), fill=WHITE)

    sp = scaled(star, s)
    d.line(sp + [sp[0]], fill=NAVY, width=max(1, round(stroke * s)), joint="curve")
    d.polygon(sp, fill=AMBER)

    return im.resize((px, px), Image.LANCZOS)


# ---------------------------------------------------------- format icons --


@dataclass
class Fmt:
    index: int
    name: str          # .ico filename stem
    label: str         # full label, used at >=48px
    short: str         # <=3 chars, used at 32px
    color: str
    exts: list[str] = field(default_factory=list)


def draw_format_icon(px: int, f: Fmt) -> Image.Image:
    """
    Every archive icon is the app icon's mark over a format caption, so a folder
    of archives reads as "these are 7-ZSTar's" first and "this one is a zip"
    second. The plate stays navy - the format colour is carried by the caption
    bar alone, which is what keeps 41 icons from turning an Explorer window into
    a colour chart.

    Two geometries, because the caption cannot survive 16px:

      >16px  mark in the upper two thirds, format colour caption bar below.
      <=16px mark fills the plate and the caption degrades to a colour band at
             the foot - no text, identity rides on the mark plus that band.

    Chained tar.* formats (tzst, tgz, ...) are deliberately identical to their
    plain counterparts: their labels already match, and Windows only ever
    associates the last extension, so .tar.zst and .zst share an icon no matter
    what we draw. Distinguishing only the short spellings bought inconsistency,
    not information.
    """
    ss = 8
    c = px * ss
    s = c / 128.0
    im = Image.new("RGBA", (c, c), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    # The navy plate is also what gives every icon a readable outline against a
    # white Explorer row.
    d.rounded_rectangle([0, 0, c - 1, c - 1], radius=22 * s, fill=NAVY)

    # Whether the mark needs the bold tier is decided by how tall it actually
    # lands, not by the icon size: the two layouts give it very different room.
    mark_px = lambda box: (box[3] - box[1]) / 128.0 * px

    if px <= 16:
        box = (10, 4, 118, 92)
        draw_mark(d, box, s, keyline_w=11, bold=mark_px(box) < MARK_BOLD_BELOW_PX)
        # Radius matches the plate's so the band's bottom corners sit exactly on
        # its outline; the square top edge is drawn back over it.
        d.rounded_rectangle([0, 96 * s, c - 1, c - 1], radius=22 * s, fill=f.color)
        d.rectangle([0, 96 * s, c - 1, 112 * s], fill=f.color)
        return im.resize((px, px), Image.LANCZOS)

    bar_top = 80 * s
    d.rounded_rectangle([8 * s, bar_top, 120 * s, 120 * s], radius=10 * s,
                        fill=f.color)
    box = (14, 6, 114, 74)
    bold = mark_px(box) < MARK_BOLD_BELOW_PX
    draw_mark(d, box, s, keyline_w=11 if bold else 9, bold=bold)

    # 32px falls back to the <=3 char spelling: at that size the bar is ~10px
    # tall and a squeezed "LZMA" is four smudges rather than four letters.
    label = f.short if px <= 32 else f.label
    draw_label(im, label, pick_ink(f.color), c / 2, (bar_top + 120 * s) / 2,
               104 * s, round((30 if len(label) <= 3 else 28) * s))

    return im.resize((px, px), Image.LANCZOS)


# ----------------------------------------------------------- ICO container --


def _png_bytes(im: Image.Image) -> bytes:
    buf = BytesIO()
    im.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def _dib_bytes(im: Image.Image) -> bytes:
    """32bpp bottom-up BGRA DIB plus a zeroed AND mask, as ICO expects."""
    w, h = im.size
    px = im.load()
    rows = []
    for y in range(h - 1, -1, -1):
        row = bytearray()
        for x in range(w):
            r, g, b, a = px[x, y]
            row += bytes((b, g, r, a))
        rows.append(bytes(row))
    xor = b"".join(rows)

    mask_stride = ((w + 31) // 32) * 4
    and_mask = b"\x00" * (mask_stride * h)

    header = struct.pack(
        "<IiiHHIIiiII",
        40, w, h * 2, 1, 32, 0, len(xor) + len(and_mask), 0, 0, 0, 0,
    )
    return header + xor + and_mask


def write_ico(path: Path, images: list[Image.Image], png_from: int = 48) -> int:
    """
    Sizes below `png_from` are stored as classic BMP/DIB for maximum
    compatibility; larger ones as PNG. These icons use 3-4 flat colours, so PNG
    turns a 9.5 KB 48px DIB into a few hundred bytes - across 41 format icons
    that is the difference between a ~520 KB and a ~130 KB 7z.dll increase.
    """
    images = sorted(images, key=lambda i: i.size[0])
    blobs, entries = [], []
    for im in images:
        w, h = im.size
        # An ICONDIRENTRY gives width and height one byte each, with 0 meaning
        # 256. Anything larger cannot be expressed: the entry below would write
        # (w & 0xFF) and Windows would read a wrong, small size for a correct
        # blob - a silent corruption, so refuse instead.
        if w > 256 or h > 256:
            raise ValueError(
                f"{path.name}: {w}x{h} exceeds the 256 px an ICO can address")
        blob = _png_bytes(im) if w >= png_from else _dib_bytes(im)
        blobs.append(blob)
        entries.append((w, h, len(blob)))

    offset = 6 + 16 * len(images)
    out = bytearray(struct.pack("<HHH", 0, 1, len(images)))
    for (w, h, size), _ in zip(entries, blobs):
        out += struct.pack(
            "<BBBBHHII",
            0 if w >= 256 else w, 0 if h >= 256 else h, 0, 0, 1, 32, size, offset,
        )
        offset += size
    for blob in blobs:
        out += blob

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(bytes(out))
    return len(out)


# ---------------------------------------------------------------- wordmark --


WORDMARK = "7-ZSTar"
WM_HEAD = "7-"          # amber, ties the wordmark back to the star
WM_TAIL = "ZSTar"


def draw_wordmark(height: int, width: int | None = None,
                  ink: str = NAVY) -> Image.Image:
    """
    Horizontal lockup: the proposal-B mark, then '7-ZSTar'.

    `width=None` sizes the canvas to the content and the mark takes the full
    height - that is the README lockup, where nothing is competing for width.

    Passing a width fits the lockup into a fixed plate (the About dialog needs
    exactly 110x63), and there the mark tracks the type size instead. A square
    mark at full plate height eats 63 of the 110 px on its own, leaving so
    little for '7-ZSTar' that the type shrinks to around 10 px - a mark with an
    illegible caption next to it. Shrinking both keeps the two legible and
    balanced, at the cost of leaving the plate vertically airy.
    """
    gap = max(2, round(height * 0.13))
    type_px = max(6, round(height * 0.64))

    def measure(type_px: int) -> tuple[int, ImageFont.FreeTypeFont, tuple, int]:
        mark = type_px if width is not None else height
        font = load_font(type_px)
        probe = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
        box = probe.textbbox((0, 0), WORDMARK, font=font, anchor="lt")
        return mark + gap + (box[2] - box[0]), font, box, mark

    total_w, font, box, mark_h = measure(type_px)
    if width is not None:
        while total_w > width - 2 and type_px > 6:
            type_px -= 1
            total_w, font, box, mark_h = measure(type_px)

    # Render onto a deliberately oversized canvas: ink extents understate the
    # right side bearing of the final glyph, so trailing letters get clipped if
    # the canvas is sized from the bbox alone.
    slack = max(8, type_px)
    W = (width if width is not None else total_w) + slack * 2
    im = Image.new("RGBA", (W, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    x = slack + ((width - total_w) // 2 if width is not None else 0)
    im.alpha_composite(draw_app_icon(mark_h), (x, (height - mark_h) // 2))

    tx = x + mark_h + gap - box[0]
    ty = (height - (box[3] - box[1])) / 2 - box[1]
    d.text((tx, ty), WM_HEAD, font=font, fill=AMBER, anchor="lt")
    # Measure the head *in context* so the kerning pair across the colour
    # change ("-Z") matches what a single-run render would produce.
    adv = d.textlength(WM_HEAD + WM_TAIL[0], font=font) - d.textlength(WM_TAIL[0], font=font)
    d.text((tx + adv, ty), WM_TAIL, font=font, fill=ink, anchor="lt")

    if width is not None:
        return im.crop((slack, 0, slack + width, height))

    bbox = im.getbbox()
    pad = max(2, round(height * 0.05))
    return im.crop((max(0, bbox[0] - pad), 0, min(W, bbox[2] + pad), height))


# ------------------------------------------------------- installer artwork --

# WixUI's two replaceable bitmaps. The sizes are fixed by WiX (it scales
# nothing): banner 493x58, welcome/finish background 493x312.
BANNER_SIZE = (493, 58)
DIALOG_SIZE = (493, 312)

# WixUI puts the dialog's own Title/Description text at X=135 dialog units on
# both the welcome and finish pages. The bitmaps are 493px across a 370 DU
# dialog, so that lands at ~180px: anything we draw right of ~175px would end
# up underneath black text.
DIALOG_BAND_W = 170


def _wordmark_type_width(d: ImageDraw.ImageDraw, type_px: int) -> float:
    """Width of the '7-ZSTar' lettering at this size, without drawing it."""
    return d.textlength(WORDMARK, font=load_font(type_px))


def _draw_wordmark_type(d: ImageDraw.ImageDraw, x: float, y: float,
                        type_px: int, ink: str) -> None:
    """Just the '7-ZSTar' lettering (no mark), top-left anchored."""
    font = load_font(type_px)
    d.text((x, y), WM_HEAD, font=font, fill=AMBER, anchor="lt")
    # Same trick as draw_wordmark: measure the head in context so the kerning
    # across the colour change matches a single-run render.
    adv = d.textlength(WM_HEAD + WM_TAIL[0], font=font) - d.textlength(WM_TAIL[0], font=font)
    d.text((x + adv, y), WM_TAIL, font=font, fill=ink, anchor="lt")


def draw_installer_banner() -> Image.Image:
    """Top banner for every wizard page except welcome/finish.

    White, because WixUI draws the page title over the left half of it in the
    system text colour. Our lockup goes hard right, out of the text's way.
    """
    w, h = BANNER_SIZE
    im = Image.new("RGB", (w, h), WHITE)
    wm = draw_wordmark(32)
    im.paste(wm, (w - wm.width - 18, (h - wm.height) // 2), wm)
    # Amber hairline along the bottom - the only brand colour that survives
    # being 1px tall, and it ties the banner to the star.
    ImageDraw.Draw(im).rectangle([0, h - 2, w, h], fill=AMBER)
    return im


def draw_installer_dialog() -> Image.Image:
    """Background for the welcome and finish pages: navy band left, white right."""
    w, h = DIALOG_SIZE
    im = Image.new("RGB", (w, h), WHITE)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, DIALOG_BAND_W, h], fill=NAVY)

    # Stacked and centred in the band, sitting above the vertical middle so the
    # lockup reads against the dialog's text rather than against its buttons.
    icon_px, icon_y = 96, 74
    type_px, type_y = 26, 192
    rule_w, rule_y = 40, 232

    icon = draw_app_icon(icon_px)
    im.paste(icon, ((DIALOG_BAND_W - icon_px) // 2, icon_y), icon)

    tw = _wordmark_type_width(d, type_px)
    _draw_wordmark_type(d, (DIALOG_BAND_W - tw) / 2, type_y, type_px, WHITE)

    d.rectangle([(DIALOG_BAND_W - rule_w) // 2, rule_y,
                 (DIALOG_BAND_W + rule_w) // 2, rule_y + 2], fill=AMBER)
    return im


def save_installer_bmp(im: Image.Image, path: Path) -> int:
    """8-bit palette BMP.

    BMP rather than PNG on purpose: WiX documents that modern Windows accepts
    PNG here, but a Bitmap control that silently renders blank is a defect the
    user sees and we would only catch by running the wizard by hand. 8bpp keeps
    these two out of the Binary table at a third of 24-bit's size - and the
    artwork is flat colour plus one antialiased icon, so 256 entries is plenty.
    """
    im.convert("P", palette=Image.ADAPTIVE, colors=256).save(path, format="BMP")
    return path.stat().st_size


# --------------------------------------------------------- menu logo (1bpp) --

# The bitmap the Explorer context menu shows next to each item
# (Explorer/MenuLogo.bmp, IDB_MENU_LOGO, loaded at ContextMenu.cpp:687 and
# handed to MENUITEMINFO.hbmpUnchecked).
#
# It has to stay 13x13 **monochrome**: Windows maps bit 0 to the current menu
# text colour and bit 1 to the menu background, which is what makes it follow
# light/dark mode. A colour bitmap would need hbmpItem instead - a change to
# upstream's menu code we deliberately are not making.
#
# Upstream's is "7Z" split across two plates: a black one holding a white 7,
# then a white one holding a black Z. Dropping the Z into that second plate and
# putting a star there instead does not work - at five pixels wide the star's
# arms touch the plate border on both sides and it reads as a bar, not a star
# (rendered and looked at; that is what out/menulogo-preview.png is for).
#
# So this is one plate instead of two, laid out like the app icon: white 7 upper
# left, white five-pointed star lower right, each with a pixel of clearance.
#
# '#' = bit 0 = drawn in the menu text colour;  '.' = bit 1 = menu background.
MENU_LOGO = [
    ".............",
    "#############",
    "#.....#######",  # 7: top bar
    "####..#######",
    "###..########",
    "##..#########",
    "##..#####.###",  # star: top point
    "##..###.....#",  # star: arms
    "##..####...##",
    "########.#.##",  # star: legs
    "#######.###.#",  # star: feet
    "#############",
    ".............",
]


def draw_menu_logo() -> Image.Image:
    """MENU_LOGO as a 1-bit image, ready to be written as a 1bpp BMP."""
    h, w = len(MENU_LOGO), len(MENU_LOGO[0])
    if h != 13 or w != 13:
        raise RuntimeError(f"MENU_LOGO must stay 13x13, got {w}x{h}")
    im = Image.new("1", (w, h), 1)
    px = im.load()
    for y, row in enumerate(MENU_LOGO):
        if len(row) != w:
            raise RuntimeError(f"MENU_LOGO row {y} is {len(row)} wide, expected {w}")
        for x, ch in enumerate(row):
            px[x, y] = 0 if ch == "#" else 1
    return im


def write_menu_logo(path: Path) -> int:
    """Save as 1bpp BMP and check the bytes, rather than trusting the writer.

    Every other container here is written by hand; this one delegates to
    Pillow, and the pillow>=10 floor has no ceiling. If a future release
    reordered the two palette entries, the menu icon would come out inverted -
    an entirely silent failure, since the file would still be a valid 13x13
    monochrome BMP. Assert what Windows is going to read.
    """
    draw_menu_logo().save(path, format="BMP")
    b = path.read_bytes()
    w, h = struct.unpack_from("<ii", b, 18)
    planes, bpp = struct.unpack_from("<HH", b, 26)
    offbits = struct.unpack_from("<I", b, 10)[0]
    palette = b[54:offbits]
    if (w, h, planes, bpp) != (13, 13, 1, 1):
        raise RuntimeError(f"expected 13x13 1bpp, got {w}x{h} planes={planes} bpp={bpp}")
    # Index 0 must be black and index 1 white: Windows paints bit 0 in the menu
    # text colour and bit 1 in the menu background, which is what makes the
    # mark follow light/dark mode. Swapped entries would invert it.
    if palette[:8] != b"\x00\x00\x00\x00\xff\xff\xff\x00":
        raise RuntimeError(f"unexpected palette {palette[:8]!r}; index 0 must be black")
    return len(b)


# ------------------------------------------------------------ format table --

FORMATS: list[Fmt] = [
    # --- upstream 7-Zip formats, indices 0-26 must keep their numbering ---
    Fmt(0,  "7z",       "7Z",   "7Z",  "#F6A609", exts=["7z"]),
    Fmt(1,  "zip",      "ZIP",  "ZIP", "#FACC15", exts=["zip"]),
    Fmt(2,  "bz2",      "BZ2",  "BZ2", "#F87171", exts=["bz2", "bzip2"]),
    Fmt(3,  "rar",      "RAR",  "RAR", "#A78BFA", exts=["rar"]),
    Fmt(4,  "arj",      "ARJ",  "ARJ", "#94A3B8", exts=["arj"]),
    Fmt(5,  "z",        "Z",    "Z",   "#7DD3FC", exts=["z"]),
    Fmt(6,  "lzh",      "LZH",  "LZH", "#94A3B8", exts=["lzh", "lha"]),
    Fmt(7,  "cab",      "CAB",  "CAB", "#94A3B8", exts=["cab"]),
    Fmt(8,  "iso",      "ISO",  "ISO", "#64748B", exts=["iso"]),
    Fmt(9,  "split",    "001",  "001", "#94A3B8", exts=["001"]),
    Fmt(10, "rpm",      "RPM",  "RPM", "#FB7185", exts=["rpm"]),
    Fmt(11, "deb",      "DEB",  "DEB", "#FB923C", exts=["deb"]),
    Fmt(12, "cpio",     "CPIO", "CPI", "#94A3B8", exts=["cpio"]),
    Fmt(13, "tar",      "TAR",  "TAR", "#CBD5E1", exts=["tar"]),
    Fmt(14, "gz",       "GZ",   "GZ",  "#4ADE80", exts=["gz", "gzip"]),
    Fmt(15, "wim",      "WIM",  "WIM", "#64748B", exts=["wim", "swm", "esd"]),
    Fmt(16, "lzma",     "LZMA", "LZM", "#6366F1", exts=["lzma"]),
    Fmt(17, "dmg",      "DMG",  "DMG", "#64748B", exts=["dmg"]),
    Fmt(18, "hfs",      "HFS",  "HFS", "#64748B", exts=["hfs"]),
    Fmt(19, "xar",      "XAR",  "XAR", "#94A3B8", exts=["xar"]),
    Fmt(20, "vhd",      "VHD",  "VHD", "#64748B", exts=["vhd", "vhdx"]),
    Fmt(21, "fat",      "FAT",  "FAT", "#64748B", exts=["fat"]),
    Fmt(22, "ntfs",     "NTFS", "NTF", "#64748B", exts=["ntfs"]),
    Fmt(23, "xz",       "XZ",   "XZ",  "#818CF8", exts=["xz"]),
    Fmt(24, "squashfs", "SQFS", "SQF", "#64748B", exts=["squashfs"]),
    Fmt(25, "apfs",     "APFS", "APF", "#64748B", exts=["apfs"]),
    Fmt(26, "zst",      "ZST",  "ZST", "#38BDF8", exts=["zst"]),
    # --- codecs 7-ZSTar adds (M6a) ---
    Fmt(27, "br",       "BR",   "BR",  "#C084FC", exts=["br", "brotli"]),
    Fmt(28, "lz4",      "LZ4",  "LZ4", "#34D399", exts=["lz4"]),
    Fmt(29, "lz5",      "LZ5",  "LZ5", "#2DD4BF", exts=["lz5"]),
    Fmt(30, "liz",      "LIZ",  "LIZ", "#F472B6", exts=["liz"]),
    # --- chained tar.* short extensions ---
    # Same label and colour as the codec they wrap, so these render byte-for-byte
    # like their plain counterparts (see draw_format_icon). They stay separate
    # entries because resource.rc maps each extension to an icon *index*: giving
    # tzst index 26 instead would mean editing that table, and the point of
    # keeping them is that .rc stays untouched.
    Fmt(31, "tgz",  "GZ",   "GZ",  "#4ADE80", exts=["tgz", "tpz"]),
    Fmt(32, "tbz2", "BZ2",  "BZ2", "#F87171", exts=["tbz2", "tbz", "tz2"]),
    Fmt(33, "txz",  "XZ",   "XZ",  "#818CF8", exts=["txz"]),
    Fmt(34, "tzst", "ZST",  "ZST", "#38BDF8", exts=["tzst"]),
    Fmt(35, "taz",  "Z",    "Z",   "#7DD3FC", exts=["taz"]),
    Fmt(36, "tlz",  "LZMA", "LZM", "#6366F1", exts=["tlz"]),
    Fmt(37, "tbr",  "BR",   "BR",  "#C084FC", exts=["tbr"]),
    Fmt(38, "tlz4", "LZ4",  "LZ4", "#34D399", exts=["tlz4"]),
    Fmt(39, "tlz5", "LZ5",  "LZ5", "#2DD4BF", exts=["tlz5"]),
    Fmt(40, "tliz", "LIZ",  "LIZ", "#F472B6", exts=["tliz"]),
]

FORMAT_SIZES = [16, 32, 48]
APP_SIZES = [16, 32, 48, 256]

# The three logos the sparse MSIX package has to carry (installer/sparse/).
# None of them is the context-menu icon: that one comes from
# IExplorerCommand::GetIcon, which hands Explorer the path of 7-zip.dll and
# lets it take icon index 0. These only ever surface in Settings > Apps, and
# MakeAppx refuses a manifest whose VisualElements point at missing files.
MSIX_LOGOS = {
    "Square44x44Logo.png": 44,
    "Square150x150Logo.png": 150,
    "StoreLogo.png": 50,
}


# ------------------------------------------------------------------ install --

# Where each rendered artifact has to land for the .rc files to pick it up.
INSTALL_MAP = {
    "FM.ico": "CPP/7zip/UI/FileManager/7zstar.ico",
    "FM.ico:gui": "CPP/7zip/UI/GUI/7zstar.ico",
    "7zstarLogo.ico": "CPP/7zip/UI/FileManager/7zstarLogo.ico",
    "MenuLogo.bmp": "CPP/7zip/UI/Explorer/MenuLogo.bmp",
    "wix-banner.bmp": "installer/wix-banner.bmp",
    "wix-dialog.bmp": "installer/wix-dialog.bmp",
    "Square44x44Logo.png": "installer/sparse/Assets/Square44x44Logo.png",
    "Square150x150Logo.png": "installer/sparse/Assets/Square150x150Logo.png",
    "StoreLogo.png": "installer/sparse/Assets/StoreLogo.png",
}
INSTALL_ICONS_DIR = "CPP/7zip/Archive/Icons/7zstar"


def expected_stringtable() -> dict[str, int]:
    """The ext -> icon index mapping implied by FORMATS."""
    return {e: f.index for f in FORMATS for e in f.exts}


def check_stringtable_drift() -> int:
    """
    Compare FORMATS against the STRINGTABLE actually compiled into 7z.dll.

    The table lives in resource.rc (it is resource data, not generated), so the
    two can silently diverge - a format added here but not there gets no icon
    association at all, with nothing failing at build time to say so.
    """
    if not RESOURCE_RC.is_file():
        print(f"  ! resource.rc not found at {RESOURCE_RC}, skipped drift check")
        return 0

    text = RESOURCE_RC.read_text(encoding="utf-8", errors="replace")
    start = text.find('100 "')
    if start < 0:
        print("  ! no STRINGTABLE entry 100 found, skipped drift check")
        return 0
    start += len('100 "')
    actual_raw = text[start:text.find('"', start)]

    actual: dict[str, int] = {}
    for pair in actual_raw.split():
        ext, _, idx = pair.partition(":")
        if idx.isdigit():
            actual[ext] = int(idx)

    expected = expected_stringtable()
    problems = 0
    for ext, idx in sorted(expected.items()):
        if ext not in actual:
            print(f"  ! {ext}: in icongen but missing from resource.rc")
            problems += 1
        elif actual[ext] != idx:
            print(f"  ! {ext}: icongen says {idx}, resource.rc says {actual[ext]}")
            problems += 1
    for ext in sorted(set(actual) - set(expected)):
        print(f"  ! {ext}:{actual[ext]} in resource.rc but not in icongen")
        problems += 1

    print(f"  STRINGTABLE: {len(expected)} mappings, "
          f"{'no drift' if not problems else f'{problems} MISMATCHES'}")
    return problems


def install() -> int:
    """Copy rendered artifacts to the paths the .rc files reference."""
    icons_dst = SRC_ROOT / INSTALL_ICONS_DIR
    icons_dst.mkdir(parents=True, exist_ok=True)
    n = 0
    for ico in sorted((OUT / "Icons").glob("*.ico")):
        (icons_dst / ico.name).write_bytes(ico.read_bytes())
        n += 1
    print(f"  {n} format icons -> {INSTALL_ICONS_DIR}/")

    for key, rel in INSTALL_MAP.items():
        srcname = key.split(":")[0]
        dst = SRC_ROOT / rel
        if not dst.parent.is_dir():
            print(f"  ! {rel}: target directory missing, skipped")
            return 1
        dst.write_bytes((OUT / srcname).read_bytes())
        print(f"  {srcname} -> {rel}")

    # README embeds these from next to the script, not from out/.
    readme_assets = ("wordmark-light.png", "wordmark-dark.png",
                     "wordmark-light@3x.png", "wordmark-dark@3x.png",
                     "appicon-256.png")
    for png in readme_assets:
        (OUT.parent / png).write_bytes((OUT / png).read_bytes())
    print(f"  {len(readme_assets)} README assets -> docs/logo/")

    return check_stringtable_drift()


# ------------------------------------------------------------------- main --


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    icons_dir = OUT / "Icons"
    icons_dir.mkdir(exist_ok=True)

    # App icon and About plate stay classic BMP except for the mandatory 256px
    # PNG frame - they are single files, so the space saved is not worth
    # deviating from what upstream 7-Zip ships.
    n = write_ico(OUT / "FM.ico", [draw_app_icon(s) for s in APP_SIZES],
                  png_from=256)
    print(f"FM.ico            {n:>7} bytes  sizes={APP_SIZES}")

    msix_bytes = 0
    for name, px in MSIX_LOGOS.items():
        draw_app_icon(px).save(OUT / name)
        msix_bytes += (OUT / name).stat().st_size
    print(f"msix logos        {msix_bytes:>7} bytes  {len(MSIX_LOGOS)} files, "
          f"sizes={sorted(MSIX_LOGOS.values())}")

    total = 0
    for f in FORMATS:
        imgs = [draw_format_icon(s, f) for s in FORMAT_SIZES]
        total += write_ico(icons_dir / f"{f.name}.ico", imgs)
    print(f"Icons/*.ico       {total:>7} bytes  {len(FORMATS)} files, sizes={FORMAT_SIZES}")

    # No fixed width: the About dialog's ICON control carries SS_REALSIZEIMAGE
    # and sizes itself to whatever this image is, so the lockup can be drawn at
    # its natural proportions - full-height mark, type to match - instead of
    # being squeezed into upstream's old 110x63 plate.
    #
    # 68 is the largest height that still fits: the lockup comes out 246 px
    # wide there, and an ICONDIRENTRY stores each dimension in a single byte,
    # so 256 is the hard ceiling (write_ico asserts it).
    wm = draw_wordmark(68)
    n = write_ico(OUT / "7zstarLogo.ico", [wm], png_from=256)
    print(f"7zstarLogo.ico    {n:>7} bytes  {wm.width}x{wm.height} (About dialog)")

    n = write_menu_logo(OUT / "MenuLogo.bmp")
    ml = draw_menu_logo()
    print(f"MenuLogo.bmp      {n:>7} bytes  {ml.width}x{ml.height} 1bpp (context menu)")
    # 20x nearest-neighbour blow-up: 13x13 monochrome is impossible to judge at
    # actual size, and this is the only artifact whose pixels are hand-authored.
    ml.convert("RGB").resize((ml.width * 20, ml.height * 20),
                             Image.NEAREST).save(OUT / "menulogo-preview.png")

    for name, im in (("wix-banner.bmp", draw_installer_banner()),
                     ("wix-dialog.bmp", draw_installer_dialog())):
        n = save_installer_bmp(im, OUT / name)
        print(f"{name:<18}{n:>7} bytes  {im.width}x{im.height} 8bpp (WixUI)")

    for scale, tag in ((1, ""), (3, "@3x")):
        draw_wordmark(64 * scale).save(OUT / f"wordmark-light{tag}.png")
        draw_wordmark(64 * scale, ink=WHITE).save(OUT / f"wordmark-dark{tag}.png")
    draw_app_icon(256).save(OUT / "appicon-256.png")
    wm1 = draw_wordmark(64)
    print(f"wordmark PNGs     light/dark, 1x + 3x  ({wm1.width}x{wm1.height} @1x)")

    # Each wordmark on the background it is actually for, plus the About plate.
    wl, wd = draw_wordmark(64), draw_wordmark(64, ink=WHITE)
    pw, ph = max(wl.width, wd.width) + 40, 64 + 20
    prev = Image.new("RGBA", (pw, ph * 2 + 63 + 30), (255, 255, 255, 255))
    ImageDraw.Draw(prev).rectangle([0, ph, pw, ph * 2], fill=NAVY)
    prev.alpha_composite(wl, (20, 10))
    prev.alpha_composite(wd, (20, ph + 10))
    ImageDraw.Draw(prev).rectangle([0, ph * 2, pw, ph * 2 + 63 + 30], fill="#F0F0F0")
    prev.alpha_composite(wm, (20, ph * 2 + 15))
    prev.resize((prev.width * 2, prev.height * 2), Image.NEAREST).save(
        OUT / "wordmark-preview.png")

    # Contact sheets on white, because that is what an Explorer row looks like.
    cols, pad = 8, 10
    rows = (len(FORMATS) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * (48 + pad) + pad,
                               rows * (48 + pad) + pad), (255, 255, 255, 255))
    for i, f in enumerate(FORMATS):
        sheet.alpha_composite(draw_format_icon(48, f),
                              (pad + (i % cols) * (48 + pad),
                               pad + (i // cols) * (48 + pad)))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(
        OUT / "contact-sheet-48.png")

    strip = Image.new("RGBA", (len(FORMATS) * 22 + 8, 30), (255, 255, 255, 255))
    for i, f in enumerate(FORMATS):
        strip.alpha_composite(draw_format_icon(16, f), (4 + i * 22, 7))
    strip.resize((strip.width * 4, strip.height * 4), Image.NEAREST).save(
        OUT / "contact-sheet-16.png")

    app = Image.new("RGBA", (250, 96), (255, 255, 255, 255))
    x = 12
    for sz in (16, 32, 48):
        app.alpha_composite(draw_app_icon(sz), (x, (96 - sz) // 2))
        x += sz + 16
    # 256 shown scaled to 72 so the sheet stays viewable
    app.alpha_composite(draw_app_icon(256).resize((72, 72), Image.LANCZOS), (x, 12))
    app.resize((app.width * 2, app.height * 2), Image.NEAREST).save(
        OUT / "appicon-sizes.png")
    print("contact sheets    48px grid + 16px strip + app icon sizes (white bg)")

    if "--install" in sys.argv:
        print("\ninstalling into the source tree:")
        return install()

    print("\nrendered to out/ only (gitignored). Pass --install to update the "
          "icons the build actually uses.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
