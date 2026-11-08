# Smoke-test vectors

Three sets: brotli content detection (this section), truncated streams
plus corrupt data inside a `.7z` (see *Truncated-stream and corrupt-data
vectors* below), and *Out-of-range header size vectors* at the end.

Deterministic inputs for `Test-Smoke.ps1`'s brotli content-detection
checks. The reader distinguishes raw brotli from mcmilk's multi-threaded
skippable-frame container by validating the container's whole 16-byte
first frame header - magic, the `size == 8` field at +4, and the `BR`
magicnumber at +12 - before committing to the container decode path
(7-ZSTar hardening of the fix for upstream mcmilk/7-Zip-zstd issue #538;
see `C/zstdmt/brotli-mt_decompress.c`).

| file | what it is | expectation |
|---|---|---|
| `mt-brotli.br` | genuine mt container: 2 worker threads, 64K chunks, level 5, deterministic 200000-byte payload (payload SHA-256 `0361E377A4D5213E4D2A7584912230EF7D706ECFFC59A486EC8BE53C7FA92EAF`) | extracts with no `-mmt` anywhere; payload hash matches |
| `corrupt-hdr.br` | the same container with header byte +4 XORed, so the 16-byte check fails past the magic | fails as `Data Error` (raw-path error), never `Unspecified error` |
| `fake-magic.br` | 64 bytes: the 4 container magic bytes a raw brotli stream could legitimately open with (~2^-32), then filler failing the rest of the check | same expectation |

## Provenance / regeneration

All three are emitted by `brdetect.c` in this directory - a self-contained
harness that links the production sources and needs no arguments to be
deterministic (`make_payload()` plus fixed parameters make every emission
byte-identical *for a given tree*; after re-vendoring `C/brotli` the
container bytes may legitimately change, which is fine - the smoke checks
pin the decoded payload's hash, not the container's). From a VS2022 x64
developer prompt, at the repo root:

```
cl /nologo /W3 /MT /O2 /I C\zstdmt /I C\brotli build\testdata\brdetect.c ^
   C\zstdmt\brotli-mt_compress.c C\zstdmt\brotli-mt_decompress.c ^
   C\zstdmt\brotli-mt_common.c C\zstdmt\zstd-mt_threading.c ^
   C\brotli\br_*.c /Fe:brdetect.exe
brdetect.exe --emit build\testdata
```

Run it with no arguments instead to execute its detection test suite
(raw/tiny/container round trips, probe-width and routing assertions,
truncation and garbage inputs, and the forced-raw escape hatch) against
whatever tree it was compiled from.

`mt-brotli.br` doubles as the container half of the escape-hatch checks,
in both the harness (T10) and `Test-Smoke.ps1`: an explicit `-mmt=0` has
to stop this file from decoding, which is what shows the flag really does
override content detection rather than merely agreeing with it on raw
input. The same vector pins the other direction too - every other `-mmt`
spelling must keep decoding it.

## Why committed files rather than generating them in the test script

The first version of these checks built `fake-magic.br`/`corrupt-hdr.br`
inside `Test-Smoke.ps1` with `WriteAllBytes`. A PowerShell script that
drops binary blobs and immediately runs an executable on them is exactly
the shape antivirus heuristics flag: an antivirus product quarantined the script
on a development machine minutes after that edit (and held the
filename locked). For a project whose reason to exist includes avoiding
AV false positives, the test suite must not look like a dropper - so the
binary inputs live here as inert data files instead.

## Truncated-stream and corrupt-data vectors

`Test-Smoke.ps1` requires the `trunc*` files to fail with `Unexpected end
of data` - not `Unspecified error`, which lz4/lz5/lizard reported before the
mcmilk #564 port, and not `Data Error`, which brotli reported - and the
`corrupt-*.7z` files to fail with `Data Error`.

Which zstdmt read path a stream takes - a plain stream through
`st_decompress()` or mcmilk's skippable-frame container through `pt_read()`
- is decided by the encoder, and each codec has its own copy of both paths.
The standalone formats (`.lz4`, `.br`, `.tar.*`) do not follow `-mmt`
there: lz4 and brotli always come out plain, lz5 and lizard always as the
container. Inside a `.7z` the coder does take the thread count: lz4 writes
the container whenever it is not 1, and brotli always does.

| file | what it is | path | the check |
|---|---|---|---|
| `trunc.lz4` | first half of a `.lz4` of `payload.txt` | lz4 plain | `Unexpected end of data` |
| `trunc.lz5` | first half of a `.lz5` | lz5 container | same |
| `trunc.liz` | first half of a `.liz` | lizard container | same |
| `trunc.br` | first half of a `.br` | brotli plain | same |
| `trunc-prefix.br` | first half of a `.br` of `payload-prefix.txt` | brotli plain | same, and `x` writes more than 1 MiB that is a prefix of the payload - see below |
| `trunc-mt.br` | first half of `mt-brotli.br` above | brotli container (its `pt_read()` was merged by hand in the #564 port) | same |
| `trunc.tar.lz4`, `.lz5`, `.liz`, `.br` | first 60% of a `.tar.*` of `payload-tar.txt` (`payload-tar-br.txt` for `.br`) | the tar sniff succeeds, the drill-down's decode-to-temp-file hits the cut, and 7-Zip falls back to the `.tar` as one file | `Unexpected end of data`, and `x` writes at least 512 bytes of `.tar` - only possible if `Extract()` starts from the beginning |
| `corrupt-lz4.7z` | `.7z`, `-m0=lz4 -mmt=1`, byte at len/2 XORed with 0xFF | lz4 plain | `Data Error`, never `Unspecified error` or Windows' "Reached the end of the file" |
| `corrupt-lz4mt.7z` | same, `-mmt=2` | lz4 container | same |
| `corrupt-lz5.7z` | same, `-m0=lz5` | lz5 container | same |
| `corrupt-liz.7z` | same, `-m0=lizard` | lizard container | same |
| `corrupt-br.7z` | same, `-m0=brotli` | brotli container | same |

lz4, lz5 and lizard only write output in whole units - lz4 a 64 KiB block,
lz5 and lizard a 4 MiB chunk - so a cut inside the first unit writes nothing,
not even with `-t<codec>`, and the tar sniff (which needs 512 decoded bytes)
then fails before any drill-down. `payload-tar.txt` is one line repeated
360,000 times (13,320,000 bytes): more than three chunks, yet small once
compressed, so a cut at 60% lands after the first chunk. brotli needs more,
for a different reason: that file is about 150 bytes as a `.tar.br`, and a 60%
cut of that decodes nothing. `payload-tar-br.txt` is the same line 1,400,000 times
(51,800,000 bytes, 199 bytes once cut), and that cut decodes 16 MiB. Any
regenerated `trunc.tar.*` has to pass both of these:

```
"$Z" e -so -t<codec> -mmt=1 trunc.tar.<e> | wc -c   # at least 512
"$Z" t trunc.tar.<e>                                # Unexpected end of data
```

No vector covers a plain lz5/lizard stream: nothing this project writes
produces one.

Plain brotli has no such unit: everything decoded before the cut is written,
then the error is reported. When the input ends, the decoder has moved only
what fits into the 1 MiB output buffer and holds the rest in its ring buffer,
so `st_drain_output()` in `C/zstdmt/brotli-mt_decompress.c` empties both.
`trunc-prefix.br` pins that: `payload-prefix.txt` is 100,000 numbered lines
(3,700,000 bytes), the cut keeps 42,585 bytes, and those decode to 1,921,997.
That is past 1 MiB on purpose, because flushing only the output buffer would
stop at exactly 1 MiB. The check rebuilds the payload text itself and compares
the result as a prefix, so the decoded length can move with the codec as long
as it stays above 1 MiB.

The vector stops short of the ring buffer's end (16 MiB at `-mx=5`), so the
wrap in `BrotliDecoderTakeOutput()` has no committed check: a vector that
reaches it is hundreds of KB. Check it by hand after re-vendoring `C/brotli`
or touching `st_drain_output()`. In Git Bash, in an empty directory, with `Z`
as under *Regenerating*:

```
seq -f '7-ZSTar truncation vector line %06g' 0 899999 | head -c 33000000 > payload-wrap.txt
"$Z" a -tbrotli -mx=5 -mmt=1 wrap.br payload-wrap.txt >/dev/null
s=$(stat -c %s wrap.br)
for p in 70 80 90 97; do
  head -c $(( s * p / 100 )) wrap.br > cut.br
  "$Z" e -so -tbrotli -mmt=1 cut.br 2>/dev/null > got.bin
  n=$(stat -c %s got.bin); cmp -n "$n" got.bin payload-wrap.txt && echo "$p% $n prefix"
done
```

All four lines have to print, each with `n` above 16,777,216. What passes is
being a prefix past the wrap, not an exact length; the last run gave
21,894,683, 25,847,593, 29,544,119 and 31,961,185.

### Regenerating

Made with the project's own `7zz.exe` (x64, 2026-10-23, src branch
`deps-2026-10`; `trunc-prefix.br` on 2026-11-06, from the 26.05.1 tree).
Paste this into Git Bash **in an empty directory**, with
`Z` set to the absolute path of `CPP\7zip\Bundles\Alone2\x64\7zz.exe` and
`T` to the absolute path of this directory (for `mt-brotli.br`). The
payloads get a fixed modification time because `.7z` and tar record it;
with that, two runs gave byte-identical files, equal to the ones committed
here. Copy back only `trunc*` and `corrupt-*.7z` - `payload*.txt`,
`full*` and `ok-*.7z` are intermediates.

```
for i in $(seq 0 1499); do printf '7-ZSTar truncation vector line %05d\n' $i; done > payload.txt
yes '7-ZSTar truncation vector line 00000' | head -n 360000 > payload-tar.txt
yes '7-ZSTar truncation vector line 00000' | head -n 1400000 > payload-tar-br.txt
for i in $(seq 0 99999); do printf '7-ZSTar truncation vector line %05d\n' $i; done > payload-prefix.txt
touch -d '2026-10-23 00:00:00 UTC' payload.txt payload-tar.txt payload-tar-br.txt payload-prefix.txt
keepfirst() { s=$(stat -c %s "$1"); head -c $(( s * $2 / 10 )) "$1" > "$3"; }
flipmid() {
  o=$(( $(stat -c %s "$1") / 2 )); cp "$1" "$2"
  b=$(od -An -tu1 -j$o -N1 "$1")
  printf "$(printf '\\%03o' $(( b ^ 255 )))" | dd of="$2" bs=1 seek=$o conv=notrunc status=none
}
for p in lz4:lz4 lz5:lz5 lizard:liz brotli:br; do
  t=${p%%:*}; e=${p##*:}
  "$Z" a -t$t -mx=5 -mmt=1 full.$e payload.txt >/dev/null
  keepfirst full.$e 5 trunc.$e
done
for e in lz4 lz5 liz; do
  "$Z" a "-ttar.$e" -mx=5 -mmt=1 full.tar.$e payload-tar.txt >/dev/null
  keepfirst full.tar.$e 6 trunc.tar.$e
done
"$Z" a -ttar.br -mx=5 -mmt=1 full.tar.br payload-tar-br.txt >/dev/null
keepfirst full.tar.br 6 trunc.tar.br
"$Z" a -tbrotli -mx=5 -mmt=1 full-prefix.br payload-prefix.txt >/dev/null
keepfirst full-prefix.br 5 trunc-prefix.br
keepfirst "$T/mt-brotli.br" 5 trunc-mt.br
for p in lz4:lz4:1 lz4:lz4mt:2 lz5:lz5:1 lizard:liz:1 brotli:br:1; do
  m=${p%%:*}; r=${p#*:}; e=${r%%:*}; n=${r##*:}
  "$Z" a -t7z -m0=$m -mx=5 -mmt=$n ok-$e.7z payload.txt >/dev/null
  flipmid ok-$e.7z corrupt-$e.7z
done
```

`payload.txt` is 55,500 bytes (SHA-256
`36a82f6e205217433ad042c594b74ae707228f55f44d376b3216bf325bd49460`).
The byte flipped is deep in the compressed data, and there every vector
gives `Data Error`. Elsewhere the result varies, which matters only if a
regeneration lands somewhere else: brotli has no checksum, so some bytes
decode to wrong data and 7-Zip reports `CRC Failed` (10 of the 1,414
positions in `corrupt-br.7z`'s packed stream, in review); a plain lz4
stream can report `CRC Failed` together with `Data Error`; and in the
lz4/lz5/lizard container, the high bytes of a frame header's content-size
field gave "Can't allocate required memory" until those fields were bounded
(they now give `Data Error`; see the last section). None of those is a #564
regression - flip a different byte.

The exact bytes follow the vendored codec versions, so a re-vendor may
change them; the checks pin the errors and the partial `.tar`, not the
bytes. Regenerate by hand rather than in the test script, for the reason
above.

## Out-of-range header size vectors

`oversize-*`: a container from the set above with one frame-header size
field set to 1 GiB. `Test-Smoke.ps1` requires `Data Error` with a peak
commit charge under 256 MB.

| file | made from | field |
|---|---|---|
| `oversize-packed-lz4mt.7z`, `oversize-content-lz4mt.7z` | `ok-lz4mt.7z` (packed stream at +32) | compressed size / content size |
| `oversize-packed.lz5`, `oversize-content.lz5` | `full.lz5` | same |
| `oversize-packed.liz`, `oversize-content.liz` | `full.liz` | same |
| `oversize-packed-mt.br`, `oversize-hint-mt.br` | `mt-brotli.br` | compressed size / size hint |

In the same directory, right after the block above (which leaves
`full.lz5`, `full.liz` and `ok-lz4mt.7z` behind):

```
# regression: header size field out of range
cp "$T/mt-brotli.br" mt-brotli.br
setbytes() { cp "$1" "$2"; printf "$4" | dd of="$2" bs=1 seek=$3 conv=notrunc status=none; }
G='\000\000\000\100'
setbytes ok-lz4mt.7z oversize-packed-lz4mt.7z 40 "$G"
setbytes ok-lz4mt.7z oversize-content-lz4mt.7z 50 "$G\000\000\000\000"
for e in lz5 liz; do
  setbytes full.$e oversize-packed.$e 8 "$G"
  setbytes full.$e oversize-content.$e 18 "$G\000\000\000\000"
done
setbytes mt-brotli.br oversize-packed-mt.br 8 "$G"
setbytes mt-brotli.br oversize-hint-mt.br 14 '\000\100'
```
