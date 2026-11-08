#!/usr/bin/env bash
# 7-ZSTar functional smoke tests for the Linux gcc build of 7zz.
#
#   build/linux/test-smoke.sh                       # test CPP/7zip/Bundles/Alone2/b/g/7zz
#   build/linux/test-smoke.sh /path/to/7zz          # test another binary
#   SEVENZZ=/path/to/7zz build/linux/test-smoke.sh  # same, via the environment
#
# Port of build/Test-Smoke.ps1 (the Windows suite) to bash.  Every check prints
# one "PASS <name>" or "FAIL <name>: <reason>" line, the last line is
# "passed=N failed=M", and the exit status is 0 only when nothing failed.
# A "SKIP <name>: <reason>" line means a precondition (an optional apt tool, a
# source file) is missing; skips are neither passed nor failed.
#
# Not set -e on purpose: every check judges the exit code of the thing it runs.
#
# Same two habits as the PowerShell version:
#   * 7zz is invoked by explicit absolute path, never through PATH, and the
#     banner is asserted first so a different archiver cannot be tested by
#     accident.
#   * all binary inputs come from the committed build/testdata/ vectors; this
#     script only writes text and deterministic filler into a mktemp -d work
#     directory, which is removed on exit.

set -u

# ---------------------------------------------------------------------------
# Expected values (each states where it comes from)
# ---------------------------------------------------------------------------

# Test-Smoke.ps1 $FormatCeiling / $FormatFloor: kNumArcsMax in
# CPP/7zip/UI/Common/LoadCodecs.h is 96 and the table silently stops accepting
# registrations once full, so assert headroom; the floor catches a build that
# links almost no handlers.
FORMAT_CEILING=96
FORMAT_FLOOR=60
# Measured on the Linux build (G3, 2026-11-04): `7zz i` lists 73 entries in the
# Formats block, the pseudo-format "Hash" included (same counting rule as
# Test-Smoke.ps1: the lines of the block up to the first blank line).  Update
# this when a handler is added or removed on purpose.
FORMAT_COUNT_LINUX=73
# Test-Smoke.ps1 $brVectorPayloadSha: SHA-256 of mt-brotli.br's 200000-byte
# payload (build/testdata/README.md), lower-cased for sha256sum.
BR_VECTOR_PAYLOAD_SHA=0361e377a4d5213e4d2a7584912230ef7d706ecffc59a486ec8be53c7fa92eaf
# Test-Smoke.ps1 $peakLimitMB: the oversize-* vectors must fail as Data Error
# without the 1 GiB allocation.  Windows reads the peak commit charge from
# `7z -bt`; 7zz on Linux prints no memory statistic, so the same bound is
# enforced as an address-space cap (ulimit -v, in KiB) around the run: a
# decoder that really tried to allocate 1 GiB would die with "Can't allocate
# required memory" instead of Data Error. The runs pass -mmt=1: the cap is on
# virtual address space, and every extra decoder thread reserves its own stack
# (8 MB each), so on a many-core machine the control run
# below would fail by itself. A single worker still goes through the MT
# container parser, so the size cap under test is exercised either way.
PEAK_LIMIT_MB=256

# ---------------------------------------------------------------------------
# Locate things
# ---------------------------------------------------------------------------

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$SCRIPT_DIR/../.." && pwd)
SZ=${1:-${SEVENZZ:-$REPO/CPP/7zip/Bundles/Alone2/b/g/7zz}}
case $SZ in
    /*) ;;
    *) SZ=$PWD/$SZ ;;
esac
if [ ! -x "$SZ" ]; then
    echo "7zz not found or not executable: $SZ" >&2
    echo "build it first: cd CPP/7zip/Bundles/Alone2 && make -j\$(nproc) -f makefile.7zstar.gcc" >&2
    exit 2
fi
TESTDATA=$REPO/build/testdata

WORK=$(mktemp -d "${TMPDIR:-/tmp}/7zstar-smoke.XXXXXX") || { echo "mktemp failed" >&2; exit 2; }
cleanup() { rm -rf -- "$WORK"; }
trap cleanup EXIT
case $WORK in
    /*) ;;
    *) echo "mktemp returned a relative path: $WORK" >&2; exit 2 ;;
esac

# fd 3 = the real stdout, for informational lines printed from inside a check
# (check captures the check function's own stdout/stderr as its failure reason)
exec 3>&1

PASS=0
FAIL=0

# check <name> <function> [args...]
# The function prints a reason on stdout to fail; printing nothing passes.
# It runs in a subshell, so it must not rely on setting globals.
check() {
    local name=$1 reason
    shift
    reason=$("$@" 2>&1)
    if [ -z "$reason" ]; then
        echo "PASS $name"
        PASS=$((PASS + 1))
    else
        # one line, bounded: keep the log greppable
        reason=$(printf '%s' "$reason" | tr '\n' ' ' | cut -c1-600)
        echo "FAIL $name: $reason"
        FAIL=$((FAIL + 1))
    fi
}

skip() { echo "SKIP $1: $2"; }

# sz <args...>: run 7zz, leave combined stdout+stderr in OUT and the exit code
# in RC.  szat <dir> <args...> does the same from inside <dir> so member names
# stay relative.
sz() { OUT=$("$SZ" "$@" 2>&1); RC=$?; }
szat() { local d=$1; shift; OUT=$(cd "$d" && "$SZ" "$@" 2>&1); RC=$?; }
sha() { sha256sum -- "$1" | cut -d' ' -f1; }
fsize() { stat -c %s -- "$1"; }
hex4() { od -An -tx1 -N4 -- "$1" | tr -d ' \n'; }

echo "7-ZSTar Linux smoke tests"
echo "  binary: $SZ"
echo "  work:   $WORK"
echo

# ---------------------------------------------------------------------------
# test data
# ---------------------------------------------------------------------------

SRC=$WORK/src
mkdir -p "$SRC"
# Mixed compressibility so codecs are actually exercised.
for _ in $(seq 1 500); do printf 'the quick brown fox '; done > "$SRC/text.txt"
echo >> "$SRC/text.txt"
# Incompressible data.  Fixed seed so a size-sensitive failure reproduces on the
# same perl.  The number is the one Test-Smoke.ps1 passes to .NET Random, but the
# two generators give different bytes, so the data is not byte-identical to the
# Windows run.  perl is in the base system; fall back to /dev/urandom (not
# reproducible) rather than fail when it is not.
if command -v perl > /dev/null 2>&1; then
    perl -e 'srand(20260805); print pack("C*", map { int(rand(256)) } 1..65536)' > "$SRC/random.bin"
else
    head -c 65536 /dev/urandom > "$SRC/random.bin"
fi
EXP_TEXT=$(sha "$SRC/text.txt")
EXP_RANDOM=$(sha "$SRC/random.bin")

# expected_of <name>: sha256 of a member of $SRC
expected_of() {
    case $1 in
        text.txt) echo "$EXP_TEXT" ;;
        random.bin) echo "$EXP_RANDOM" ;;
    esac
}

# members_match <dir> <name>...: every named file exists in <dir> with its original hash
members_match() {
    local d=$1 n
    shift
    for n in "$@"; do
        [ -f "$d/$n" ] || { echo "missing after extract: $n"; return; }
        [ "$(sha "$d/$n")" = "$(expected_of "$n")" ] || { echo "hash mismatch: $n"; return; }
    done
}

# ---------------------------------------------------------------------------
# identity
# ---------------------------------------------------------------------------

t_banner() {
    sz i
    printf '%s\n' "$OUT" | grep -q '7-ZSTar' || echo "banner was: $(printf '%s\n' "$OUT" | grep -v '^$' | head -1)"
}
check "banner identifies 7-ZSTar (not another archiver)" t_banner

# ---------------------------------------------------------------------------
# licence documents (Test-Smoke.ps1 "licence documents" block, same rules)
# ---------------------------------------------------------------------------
# NOTICE quotes each vendored library's copyright line from that library's own
# licence file; re-vendoring moves those lines and nothing else would notice.
# Both sides are wrapped prose, so compare with whitespace flattened.

flat() { tr -s '[:space:]' ' ' < "$1" | sed 's/^ //; s/ $//'; }

LIC_LIBS='zstd|C/zstd/LICENSE|Copyright (c) Meta Platforms, Inc. and affiliates.
xxHash|C/hashes/xxhash.h|Copyright (C) 2012-2023 Yann Collet
brotli|C/brotli/LICENSE|Copyright (c) 2009, 2010, 2013-2016 by the Brotli Authors.
lz4|C/lz4/LICENSE|Copyright (c) 2011-2020, Yann Collet
lz5|C/lz5/LICENSE|Copyright (c) 2011-2015, Yann Collet
lizard|C/lizard/LICENSE|Copyright (C) 2016-2017, Przemyslaw Skibinski
fast-lzma2|C/fast-lzma2/LICENSE|Copyright 2018-present Conor McCarthy
zstdmt|C/zstdmt/LICENSE|Copyright (c) 2016 - 2017, Tino Reichardt'

t_notice_quotes() {
    local bad="" lib src line srcflat noticeflat
    noticeflat=$(flat "$REPO/NOTICE")
    while IFS='|' read -r lib src line; do
        [ -f "$REPO/$src" ] || { bad="$bad $lib: $src is missing;"; continue; }
        srcflat=$(flat "$REPO/$src")
        case $srcflat in
            *"$line"*) ;;
            *) bad="$bad $lib: not in $src - '$line';"; continue ;;
        esac
        case $noticeflat in
            *"$line"*) ;;
            *) bad="$bad $lib: in the licence file but not in NOTICE - '$line';" ;;
        esac
    done <<< "$LIC_LIBS"
    [ -z "$bad" ] || echo "$bad"
}

t_library_only() {
    local found="" d sub
    for d in zstd hashes brotli lz4 lz5 lizard fast-lzma2 zstdmt; do
        for sub in programs tests; do
            [ -d "$REPO/C/$d/$sub" ] && found="$found C/$d/$sub"
        done
    done
    [ -z "$found" ] || echo "GPL-bearing trees present:$found"
}

t_ported_count() {
    local noticeflat stated ported
    noticeflat=$(flat "$REPO/NOTICE")
    if [[ $noticeflat =~ ([0-9]+)\ encoder,\ decoder\ and\ handler\ files ]]; then
        stated=${BASH_REMATCH[1]}
    else
        echo "NOTICE no longer states a ported-file count in the expected form"
        return
    fi
    ported=$(grep -rlE 'Ported from mcmilk/7-Zip-zstd' --include='*.cpp' --include='*.h' "$REPO/CPP" | wc -l)
    [ "$ported" -eq "$stated" ] || echo "NOTICE says $stated ported files; $ported carry the header"
}

t_upstream_licence() {
    local f=$REPO/LICENSE-7-Zip.txt
    [ -f "$f" ] || { echo "LICENSE-7-Zip.txt is missing from the repository root"; return; }
    case $(flat "$f") in
        *"Redistributions in binary form must reproduce related license information from this file."*) ;;
        *) echo "LICENSE-7-Zip.txt does not carry upstream's reproduction clause"; return ;;
    esac
    grep -qF 'All other files: the "GNU LGPL".' "$f" || echo 'LICENSE-7-Zip.txt does not carry the clause covering Lang/ and the .chm'
}

if [ -f "$REPO/C/zstd/LICENSE" ] && [ -f "$REPO/NOTICE" ]; then
    check "NOTICE quotes every vendored licence file accurately" t_notice_quotes
    check "vendored libraries are library-only (no GPL programs/tests trees)" t_library_only
    check "NOTICE's count of ported files matches the files themselves" t_ported_count
    check "upstream's own licence statement ships with the package" t_upstream_licence
else
    skip "licence document checks" "vendored sources or NOTICE not in $REPO"
fi

# ---------------------------------------------------------------------------
# format registry
# ---------------------------------------------------------------------------

FORMAT_INFO=$("$SZ" i 2>&1)
# Name column of every row in the Formats block (the block ends at the first
# blank line after its header).  Column positions are not parsed: the first
# column is a variable flag string without spaces, the second is the name.
FORMAT_NAMES=$(printf '%s\n' "$FORMAT_INFO" | awk '/^Formats:/ {f = 1; next} f && /^[[:space:]]*$/ {exit} f {print $2}')
FORMAT_COUNT=$(printf '%s\n' "$FORMAT_NAMES" | grep -c .)
CODEC_BLOCK=$(printf '%s\n' "$FORMAT_INFO" | awk '/^Codecs:/ {f = 1; next} f && /^[[:space:]]*$/ {exit} f')

t_codec_formats() {
    local missing="" f
    for f in zstd brotli lz4 lz5 lizard; do
        printf '%s\n' "$FORMAT_NAMES" | grep -qxF -- "$f" || missing="$missing $f"
    done
    [ -z "$missing" ] || echo "not registered:$missing"
}
check "codecs 7-ZSTar adds are all registered as formats" t_codec_formats

t_chain_formats() {
    local missing="" f
    for f in tar.zst tar.br tar.gz tar.bz2 tar.xz tar.lz4 tar.lz5 tar.liz; do
        printf '%s\n' "$FORMAT_NAMES" | grep -qxF -- "$f" || missing="$missing $f"
    done
    [ -z "$missing" ] || echo "not registered:$missing"
}
check "chained tar.* out-formats are registered" t_chain_formats

t_codec_table() {
    local missing="" c
    for c in ZSTD BROTLI LZ4 LZ5 LIZARD FLZMA2; do
        printf '%s\n' "$CODEC_BLOCK" | grep -qw -- "$c" || missing="$missing $c"
    done
    [ -z "$missing" ] || echo "not in the Codecs table:$missing"
}
check "codec table lists ZSTD BROTLI LZ4 LZ5 LIZARD FLZMA2" t_codec_table

t_format_ceiling() {
    echo "        ($FORMAT_COUNT formats registered)" >&3
    [ "$FORMAT_COUNT" -ge "$FORMAT_FLOOR" ] || { echo "only $FORMAT_COUNT formats registered - expected $FORMAT_FLOOR+"; return; }
    [ "$FORMAT_COUNT" -lt "$FORMAT_CEILING" ] || echo "$FORMAT_COUNT formats - at or over the $FORMAT_CEILING ceiling"
}
check "format count is under the compiled-in ceiling ($FORMAT_CEILING)" t_format_ceiling

t_format_exact() {
    [ "$FORMAT_COUNT" -eq "$FORMAT_COUNT_LINUX" ] || echo "$FORMAT_COUNT formats registered, the Linux build measured $FORMAT_COUNT_LINUX (update FORMAT_COUNT_LINUX if intended)"
}
check "format count equals the measured Linux value ($FORMAT_COUNT_LINUX)" t_format_exact

# ---------------------------------------------------------------------------
# round trips
# ---------------------------------------------------------------------------
# Archive extension per format.  Single-member formats do not record the file
# name: the extracted name is the archive name minus its extension, so the
# archive must be "<name>.<ext>".  brotli registers as extension-only-open
# (raw brotli has no signature), so it cannot be opened without ".br".

arc_ext() {
    case $1 in
        7z) echo 7z ;; zip) echo zip ;; zstd) echo zst ;; brotli) echo br ;;
        lz4) echo lz4 ;; lz5) echo lz5 ;; lizard) echo liz ;; xz) echo xz ;;
        gzip) echo gz ;; bzip2) echo bz2 ;;
    esac
}

t_roundtrip() {
    local fmt=$1 ext single inputs arc outdir
    ext=$(arc_ext "$fmt")
    case $fmt in
        7z|zip) single=0; inputs="text.txt random.bin"; arc=$WORK/rt-$fmt.$ext ;;
        *)      single=1; inputs="text.txt"; arc=$WORK/text.txt.$ext ;;
    esac
    outdir=$WORK/rt-$fmt-out
    # shellcheck disable=SC2086
    szat "$SRC" a "-t$fmt" "$arc" $inputs
    [ "$RC" -eq 0 ] || { echo "compress failed (rc=$RC): $OUT"; return; }
    sz x "$arc" "-o$outdir" -y
    [ "$RC" -eq 0 ] || { echo "extract failed (rc=$RC): $OUT"; return; }
    # shellcheck disable=SC2086
    members_match "$outdir" $inputs
}
for fmt in 7z zip zstd brotli lz4 lz5 lizard xz gzip bzip2; do
    check "round trip: -t$fmt" t_roundtrip "$fmt"
done

# `.7z` with each added codec as the only method: round trip, and the listing
# must name the codec (so a silent fallback to LZMA2 cannot pass).  flzma2 is
# the exception: Fast LZMA2 writes ordinary LZMA2 streams, so the listing prints
# "LZMA2" for it and for the stock encoder alike, and this check only proves the
# round trip for it, not that the Fast LZMA2 encoder was the one used.
t_7z_codec() {
    local codec=$1 want=$2 arc outdir
    arc=$WORK/m0-$codec.7z
    outdir=$WORK/m0-$codec-out
    szat "$SRC" a -t7z "-m0=$codec" "$arc" text.txt random.bin
    [ "$RC" -eq 0 ] || { echo "compress failed (rc=$RC): $OUT"; return; }
    sz t "$arc"
    [ "$RC" -eq 0 ] || { echo "test failed (rc=$RC): $OUT"; return; }
    sz l -slt "$arc"
    printf '%s\n' "$OUT" | grep -E '^Method = ' | grep -q "$want" || { echo "Method line does not mention $want: $(printf '%s\n' "$OUT" | grep -E '^Method = ' | head -1)"; return; }
    sz x "$arc" "-o$outdir" -y
    [ "$RC" -eq 0 ] || { echo "extract failed (rc=$RC): $OUT"; return; }
    members_match "$outdir" text.txt random.bin
}
check "7z round trip: -m0=zstd"   t_7z_codec zstd ZSTD
check "7z round trip: -m0=brotli" t_7z_codec brotli BROTLI
check "7z round trip: -m0=lz4"    t_7z_codec lz4 LZ4
check "7z round trip: -m0=lz5"    t_7z_codec lz5 LZ5
check "7z round trip: -m0=lizard" t_7z_codec lizard LIZARD
check "7z round trip: -m0=flzma2" t_7z_codec flzma2 LZMA2

# Container magic by format.  Pins the fork's wire format (build/testdata/
# README.md): .zst/.lz4/.br are written as plain frames whatever -mmt says,
# .lz5/.liz always as the skippable-frame container.
t_magic() {
    local fmt=$1 want=$2 arc got
    arc=$WORK/magic.$(arc_ext "$fmt")
    szat "$SRC" a "-t$fmt" "$arc" text.txt
    [ "$RC" -eq 0 ] || { echo "compress failed (rc=$RC): $OUT"; return; }
    got=$(hex4 "$arc")
    [ "$got" = "$want" ] || echo "header $got, expected $want"
}
check "stream header: .zst is a plain zstd frame (28b52ffd)"            t_magic zstd 28b52ffd
check "stream header: .lz4 is a plain LZ4 frame (04224d18)"             t_magic lz4 04224d18
check "stream header: .lz5 is the skippable container (502a4d18)"       t_magic lz5 502a4d18
check "stream header: .liz is the skippable container (502a4d18)"       t_magic lizard 502a4d18

# ---------------------------------------------------------------------------
# one-step chained archives
# ---------------------------------------------------------------------------

t_chain() {
    local fmt=$1 arc outdir
    arc=$WORK/chain.$fmt
    outdir=$WORK/chain-${fmt//./_}-out
    szat "$SRC" a "-t$fmt" "$arc" text.txt random.bin
    [ "$RC" -eq 0 ] || { echo "compress failed (rc=$RC): $OUT"; return; }
    [ -f "$arc" ] || { echo "archive not created"; return; }
    # The point of the feature: listing must show the tar members, not a
    # single .tar entry.
    sz l "$arc"
    if ! printf '%s\n' "$OUT" | grep -q 'text\.txt' || ! printf '%s\n' "$OUT" | grep -q 'random\.bin'; then
        echo "no drill-down - listing showed a bare .tar instead of its contents: $OUT"
        return
    fi
    printf '%s\n' "$OUT" | grep -q '^Type = tar$' || { echo "listing has no 'Type = tar' layer"; return; }
    sz x "$arc" "-o$outdir" -y
    [ "$RC" -eq 0 ] || { echo "extract failed (rc=$RC): $OUT"; return; }
    members_match "$outdir" text.txt random.bin
}
for fmt in tar.zst tar.br tar.gz tar.bz2 tar.xz tar.lz4 tar.lz5 tar.liz; do
    check "one-step create + drill-down: $fmt" t_chain "$fmt"
done

# ---------------------------------------------------------------------------
# interop with independent implementations (apt packages; skipped when absent)
# ---------------------------------------------------------------------------

if command -v bsdtar > /dev/null 2>&1; then
    t_bsdtar_reads_ours() {
        local arc=$WORK/interop-ours.tar.gz outdir=$WORK/interop-ours-out
        szat "$SRC" a -ttar.gz "$arc" text.txt
        [ "$RC" -eq 0 ] || { echo "compress failed (rc=$RC): $OUT"; return; }
        mkdir -p "$outdir"
        bsdtar -xf "$arc" -C "$outdir" 2>&1 || { echo "bsdtar could not read our archive"; return; }
        [ -f "$outdir/text.txt" ] || { echo "bsdtar produced no file"; return; }
        [ "$(sha "$outdir/text.txt")" = "$EXP_TEXT" ] || echo "hash mismatch after bsdtar extract"
    }
    check "interop: bsdtar reads our tar.gz" t_bsdtar_reads_ours

    t_we_drill_bsdtar() {
        local arc=$WORK/interop-theirs.tar.gz
        bsdtar -czf "$arc" -C "$SRC" text.txt 2>&1 || { echo "bsdtar could not create the archive"; return; }
        sz l "$arc"
        printf '%s\n' "$OUT" | grep -q 'text\.txt' || echo "no drill-down into bsdtar's archive"
    }
    check "interop: we drill into bsdtar's tar.gz" t_we_drill_bsdtar
else
    skip "interop: bsdtar" "bsdtar not installed (apt install libarchive-tools)"
fi

# The standalone CLIs read what 7zz writes (plain frames), and 7zz reads what
# they write.  Fuller matrix: build/linux/interop-check.sh.
t_cli_reads_ours() {
    local fmt=$1 cli_cmd=$2 arc got
    arc=$WORK/cli-ours.$(arc_ext "$fmt")
    szat "$SRC" a "-t$fmt" "$arc" text.txt
    [ "$RC" -eq 0 ] || { echo "compress failed (rc=$RC): $OUT"; return; }
    got=$($cli_cmd "$arc" | sha256sum | cut -d' ' -f1)
    [ "$got" = "$EXP_TEXT" ] || echo "$cli_cmd output hash $got != $EXP_TEXT"
}
t_ours_reads_cli() {
    local ext=$1 enc=$2 arc=$WORK/cli-theirs.$1 outdir=$WORK/cli-theirs-$1-out
    $enc "$SRC/text.txt" > "$arc" || { echo "$enc failed"; return; }
    sz t "$arc"
    [ "$RC" -eq 0 ] || { echo "7zz t failed (rc=$RC): $OUT"; return; }
    sz x "$arc" "-o$outdir" -y
    [ "$RC" -eq 0 ] || { echo "7zz x failed (rc=$RC): $OUT"; return; }
    [ "$(sha "$outdir/cli-theirs")" = "$EXP_TEXT" ] || echo "hash mismatch after 7zz x"
}
if command -v zstd > /dev/null 2>&1; then
    check "interop: zstd -dc reads our .zst" t_cli_reads_ours zstd "zstd -dc"
    check "interop: we read zstd's .zst"     t_ours_reads_cli zst "zstd -qc"
else
    skip "interop: zstd" "zstd not installed"
fi
if command -v brotli > /dev/null 2>&1; then
    check "interop: brotli -dc reads our .br" t_cli_reads_ours brotli "brotli -dc"
    check "interop: we read brotli's .br"     t_ours_reads_cli br "brotli -c"
else
    skip "interop: brotli" "brotli not installed"
fi
if command -v lz4 > /dev/null 2>&1; then
    check "interop: lz4 -dc reads our .lz4" t_cli_reads_ours lz4 "lz4 -dc"
    check "interop: we read lz4's .lz4"     t_ours_reads_cli lz4 "lz4 -c"
else
    skip "interop: lz4" "lz4 not installed"
fi

# ---------------------------------------------------------------------------
# non-tar regression
# ---------------------------------------------------------------------------

t_nontar() {
    local arc=$WORK/plain.zst
    szat "$SRC" a -tzstd "$arc" random.bin
    [ "$RC" -eq 0 ] || { echo "compress failed (rc=$RC): $OUT"; return; }
    sz l "$arc"
    if printf '%s\n' "$OUT" | grep -q 'text\.txt'; then echo "unexpected drill-down into a non-tar payload"; fi
}
check "non-tar .zst still lists as a single item (drill-down does not misfire)" t_nontar

# ---------------------------------------------------------------------------
# brotli raw/mt-container content detection (see build/testdata/README.md)
# ---------------------------------------------------------------------------
# Genuine mcmilk containers keep decoding with no -mmt anywhere; anything
# failing the 16-byte header check decodes as raw brotli and fails with "Data
# Error", never "Unspecified error"; and an explicit -mmt=0 overrides
# detection.

if [ -f "$TESTDATA/mt-brotli.br" ]; then

t_mt_container() {
    local outdir=$WORK/brmt-out
    sz x "$TESTDATA/mt-brotli.br" "-o$outdir" -y
    [ "$RC" -eq 0 ] || { echo "extract failed (rc=$RC): $OUT"; return; }
    [ -f "$outdir/mt-brotli" ] || { echo "no output file"; return; }
    [ "$(sha "$outdir/mt-brotli")" = "$BR_VECTOR_PAYLOAD_SHA" ] || echo "payload hash mismatch"
}
check "mt-brotli container (mcmilk wire format) extracts without -mmt" t_mt_container

t_br_data_error() {
    local file=$1
    sz t "$TESTDATA/$file"
    [ "$RC" -ne 0 ] || { echo "bad input unexpectedly passed"; return; }
    if printf '%s\n' "$OUT" | grep -q 'Unspecified'; then echo "regressed to Unspecified error"; return; fi
    printf '%s\n' "$OUT" | grep -q 'Data Error' || echo "expected Data Error, got: $OUT"
}
check "corrupted mt-brotli header fails as Data Error, not Unspecified"  t_br_data_error corrupt-hdr.br
check "raw .br faking the container magic fails as Data Error, not Unspecified" t_br_data_error fake-magic.br

# --- the -mmt=0 escape hatch out of content detection ----------------------
# Only that spelling: official ParseMtProp2() maps -mmt=off and -mmt- onto a
# forced count of 1, indistinguishable from -mmt=1, so those must keep
# reading mt containers.  Requiring the container to *stop* decoding under
# -mmt=0 is what shows the flag really overrides detection.
BR_SRC=$WORK/hatch-src.txt
for _ in $(seq 1 400); do printf '7-ZSTar brotli escape hatch. '; done > "$BR_SRC"
BR_SRC_SHA=$(sha "$BR_SRC")
BR_RAW=$WORK/hatch.br
sz a -tbrotli "$BR_RAW" "$BR_SRC"
MKRAW_RC=$RC
MKRAW_OUT=$OUT

t_hatch() {
    local outdir=$WORK/hatch-out
    [ "$MKRAW_RC" -eq 0 ] || { echo "could not build the raw .br: $MKRAW_OUT"; return; }
    sz x "$BR_RAW" "-o$outdir" -y -mmt=0
    [ "$RC" -eq 0 ] || { echo "-mmt=0 failed on raw brotli: $OUT"; return; }
    [ -f "$outdir/hatch" ] || { echo "-mmt=0 produced no output file"; return; }
    [ "$(sha "$outdir/hatch")" = "$BR_SRC_SHA" ] || { echo "-mmt=0 changed the bytes"; return; }
    sz t "$TESTDATA/mt-brotli.br" -mmt=0
    [ "$RC" -ne 0 ] || { echo "-mmt=0 still decoded the mt container"; return; }
    if printf '%s\n' "$OUT" | grep -q 'Unspecified'; then echo "-mmt=0 reported Unspecified error"; fi
}
check "-mmt=0 forces raw decoding: bytes unchanged, container refused" t_hatch

t_mmt_spellings() {
    local flag
    [ "$MKRAW_RC" -eq 0 ] || { echo "could not build the raw .br: $MKRAW_OUT"; return; }
    for flag in -mmt -mmt+ -mmt=on -mmt=off -mmt- -mmt=1 -mmt=4; do
        sz t "$BR_RAW" "$flag"
        [ "$RC" -eq 0 ] || { echo "$flag broke raw brotli: $OUT"; return; }
        sz t "$TESTDATA/mt-brotli.br" "$flag"
        [ "$RC" -eq 0 ] || { echo "$flag broke the mt container: $OUT"; return; }
    done
}
check "every other -mmt spelling leaves detection alone" t_mmt_spellings

# Brotli inside a .7z is always an mt container and 7zDecode never sets the
# hatch, so -mmt=0 must not reach in and break it.
t_hatch_in_7z() {
    local arc=$WORK/hatch-in-7z.7z outdir=$WORK/hatch7z-out
    sz a -t7z -m0=brotli "$arc" "$BR_SRC"
    [ "$RC" -eq 0 ] || { echo "could not build the .7z: $OUT"; return; }
    sz x "$arc" "-o$outdir" -y -mmt=0
    [ "$RC" -eq 0 ] || { echo "-mmt=0 broke .7z extraction: $OUT"; return; }
    [ "$(sha "$outdir/hatch-src.txt")" = "$BR_SRC_SHA" ] || echo "-mmt=0 changed the bytes"
}
check "-mmt=0 does not reach brotli inside a .7z" t_hatch_in_7z

# The hatch is set on all three decoders one .br open creates, including the
# throwaway one that sniffs for a tar; pin that drill-down survives it.
t_hatch_tar_br() {
    local tdir=$WORK/hatch-tar tbr=$WORK/hatch-drill.tar.br flag n
    mkdir -p "$tdir"
    echo alpha > "$tdir/inner-a.txt"
    echo beta > "$tdir/inner-b.txt"
    szat "$tdir" a -ttar.br "$tbr" inner-a.txt inner-b.txt
    [ "$RC" -eq 0 ] || { echo "could not build the .tar.br: $OUT"; return; }
    for flag in -mmt=0 -mmt=4; do
        sz l "$tbr" "$flag"
        [ "$RC" -eq 0 ] || { echo "$flag failed to list: $OUT"; return; }
        for n in inner-a.txt inner-b.txt; do
            printf '%s\n' "$OUT" | grep -qF -- "$n" || { echo "$flag listed the .tar instead of drilling in: $OUT"; return; }
        done
    done
}
check "-mmt=0 does not break .tar.br drill-down" t_hatch_tar_br

else
    skip "brotli detection vectors" "build/testdata not present"
fi

# ---------------------------------------------------------------------------
# truncated lz4 / lz5 / lizard / brotli streams
# ---------------------------------------------------------------------------
# A file cut short must say "Unexpected end of data" (not "Unspecified error",
# which lz4/lz5/lizard reported before the mcmilk #564 port, and not "Data
# Error", which brotli reported).

t_trunc() {
    local p=$TESTDATA/$1
    [ -f "$p" ] || { echo "vector missing: $p"; return; }
    sz t "$p"
    [ "$RC" -ne 0 ] || { echo "truncated input unexpectedly passed"; return; }
    if printf '%s\n' "$OUT" | grep -q 'Unspecified'; then echo "regressed to Unspecified error"; return; fi
    printf '%s\n' "$OUT" | grep -q 'Unexpected end of data' || echo "expected Unexpected end of data, got: $OUT"
}
for v in trunc.lz4 trunc.lz5 trunc.liz trunc.br trunc-prefix.br trunc-mt.br; do
    check "truncated $v fails as Unexpected end of data" t_trunc "$v"
done

# A plain brotli stream cut short still has to fail, but only after handing
# over what decoded before the cut.  When the input ends that data sits in two
# places: the 1 MiB output buffer and, past it, brotli's ring buffer
# (st_drain_output() in C/zstdmt/brotli-mt_decompress.c).  This vector decodes
# to almost 2 MB, so more than 1 MiB out means the ring buffer was drained too.
# That 1 MiB is st_decompress()'s ctx->inputsize * 4, with the 256 KiB default
# from BROTLIMT_createDCtx(); if it grows past 2 MB, this check needs a larger
# vector.  Same judgement as Test-Smoke.ps1.
t_trunc_prefix() {
    local p=$TESTDATA/trunc-prefix.br outdir=$WORK/x-trunc-prefix
    local got=$WORK/x-trunc-prefix/trunc-prefix want=$WORK/trunc-prefix.want n
    [ -f "$p" ] || { echo "vector missing: $p"; return; }
    sz x "$p" "-o$outdir" -y
    [ "$RC" -eq 2 ] || { echo "expected exit code 2, got $RC: $OUT"; return; }
    printf '%s\n' "$OUT" | grep -q 'Unexpected end of data' || { echo "expected Unexpected end of data, got: $OUT"; return; }
    [ -f "$got" ] || { echo "nothing extracted"; return; }
    n=$(fsize "$got")
    [ "$n" -gt 1048576 ] || { echo "only $n bytes decoded - the ring buffer was not drained"; return; }
    # the payload of build/testdata/README.md; printf reuses the format per number
    printf '7-ZSTar truncation vector line %05d\n' $(seq 0 99999) > "$want"
    [ "$n" -lt "$(fsize "$want")" ] || { echo "decoded the whole payload from a cut stream"; return; }
    head -c "$n" "$want" | cmp -s - "$got" || { echo "the $n decoded bytes are not a prefix of the payload"; return; }
    echo "        (decoded $n of $(fsize "$want") bytes)" >&3
}
check "truncated trunc-prefix.br keeps its decoded prefix and still fails" t_trunc_prefix

# A .tar.* cut off after its first compressed unit: the tar sniff succeeds,
# the drill-down's decode fails, and 7-Zip falls back to extracting the .tar
# as one file.  Extract() must start from the beginning, so the fallback has
# to write at least one tar block (512 bytes).
t_trunc_tar() {
    local v=$1 p=$TESTDATA/$1 outdir=$WORK/x-$1
    [ -f "$p" ] || { echo "vector missing: $p"; return; }
    sz t "$p"
    [ "$RC" -ne 0 ] || { echo "truncated input unexpectedly passed"; return; }
    printf '%s\n' "$OUT" | grep -q 'Unexpected end of data' || { echo "expected Unexpected end of data, got: $OUT"; return; }
    sz x "$p" "-o$outdir" -y
    [ -f "$outdir/trunc.tar" ] || { echo "no .tar written by the fallback"; return; }
    [ "$(fsize "$outdir/trunc.tar")" -ge 512 ] || echo "fallback wrote $(fsize "$outdir/trunc.tar") bytes - Extract() did not start from the beginning"
}
for v in trunc.tar.lz4 trunc.tar.lz5 trunc.tar.liz trunc.tar.br; do
    check "truncated $v falls back to a partial .tar, Unexpected end of data" t_trunc_tar "$v"
done

# ---------------------------------------------------------------------------
# corrupt data inside a .7z
# ---------------------------------------------------------------------------
# One byte flipped mid-stream must report "Data Error" (the decoders return
# S_FALSE, #564 port) - not "Unspecified error", and not a Win32 code leaking
# out as an HRESULT ("Reached the end of the file" on Windows).

t_corrupt() {
    local p=$TESTDATA/$1
    [ -f "$p" ] || { echo "vector missing: $p"; return; }
    sz t "$p"
    [ "$RC" -ne 0 ] || { echo "corrupt input unexpectedly passed"; return; }
    if printf '%s\n' "$OUT" | grep -q 'Unspecified'; then echo "regressed to Unspecified error"; return; fi
    if printf '%s\n' "$OUT" | grep -q 'end of the file'; then echo "Win32 code surfaced as an HRESULT: $OUT"; return; fi
    printf '%s\n' "$OUT" | grep -q 'Data Error' || echo "expected Data Error, got: $OUT"
}
for v in corrupt-lz4.7z corrupt-lz4mt.7z corrupt-lz5.7z corrupt-liz.7z corrupt-br.7z; do
    check "$v (one byte flipped) fails as Data Error" t_corrupt "$v"
done

# ---------------------------------------------------------------------------
# regression: header size field out of range
# ---------------------------------------------------------------------------
# Each vector is a valid container with one frame-header size field set to
# 1 GiB, past the 256 MiB bound checked before allocating.  It must fail as
# "Data Error" without the allocation.  See PEAK_LIMIT_MB at the top: the bound
# is an address-space cap here.

t_cap_control() {
    # Without this the cap could be what makes everything "fail": a valid
    # container must still decode under it.
    local out rc
    out=$(ulimit -v $((PEAK_LIMIT_MB * 1024)); "$SZ" t -mmt=1 "$TESTDATA/mt-brotli.br" 2>&1); rc=$?
    [ "$rc" -eq 0 ] || echo "valid mt-brotli.br does not decode under a ${PEAK_LIMIT_MB} MB address-space cap (rc=$rc): $out"
}
check "address-space cap of $PEAK_LIMIT_MB MB leaves a valid container decodable" t_cap_control

t_oversize() {
    local p=$TESTDATA/$1 out rc
    [ -f "$p" ] || { echo "vector missing: $p"; return; }
    out=$(ulimit -v $((PEAK_LIMIT_MB * 1024)); "$SZ" t -mmt=1 "$p" 2>&1); rc=$?
    [ "$rc" -ne 0 ] || { echo "out-of-range header unexpectedly passed"; return; }
    if printf '%s\n' "$out" | grep -qi "allocate"; then echo "tried to allocate under the ${PEAK_LIMIT_MB} MB cap: $out"; return; fi
    printf '%s\n' "$out" | grep -q 'Data Error' || echo "expected Data Error, got: $out"
}
for v in oversize-packed-lz4mt.7z oversize-content-lz4mt.7z \
         oversize-packed.lz5 oversize-content.lz5 \
         oversize-packed.liz oversize-content.liz \
         oversize-packed-mt.br oversize-hint-mt.br; do
    check "$v fails as Data Error under $PEAK_LIMIT_MB MB" t_oversize "$v"
done

# ---------------------------------------------------------------------------
# summary
# ---------------------------------------------------------------------------

echo
echo "passed=$PASS failed=$FAIL"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
