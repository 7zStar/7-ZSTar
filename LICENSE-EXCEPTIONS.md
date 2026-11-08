# 7-ZSTar License Exceptions

7-ZSTar as a whole is distributed under the **GNU Lesser General Public License
version 3** (see `LICENSE`; the GPLv3 text it references is in `COPYING`).

The upstream 7-Zip code base is licensed "LGPL 2.1 or (at your option) any later
version" (see upstream statement preserved in `DOC/License.txt`), which permits
this distribution under LGPL v3. The files listed below carry additional or
different licenses that continue to apply.

## Files with the unRAR license restriction

The RAR decompression code was developed using source code of the unRAR
program. In addition to the LGPL, the following restriction applies to these
files (full text in `DOC/unRarLicense.txt`):

> The unRAR sources cannot be used to re-create the RAR compression algorithm,
> which is proprietary. Distribution of modified unRAR sources in separate form
> or as a part of other software is permitted, provided that it is clearly
> stated in the documentation and source comments that the code may not be used
> to develop a RAR (WinRAR) compatible archiver.

Affected files (11):

- `CPP/7zip/Compress/Rar1Decoder.cpp` / `.h`
- `CPP/7zip/Compress/Rar2Decoder.cpp` / `.h`
- `CPP/7zip/Compress/Rar3Decoder.cpp` / `.h`
- `CPP/7zip/Compress/Rar3Vm.cpp` / `.h`
- `CPP/7zip/Compress/Rar5Decoder.cpp` / `.h`
- `CPP/7zip/Compress/RarCodecsRegister.cpp`

The first ten carry the restriction in their own file headers ("According to
unRAR license..."). `RarCodecsRegister.cpp` does not - it is registration glue
with no unRAR-derived code in it - and is listed because it exists only to
register those decoders, so treating it as part of the same unit is the
conservative reading.

Because of this restriction, a binary distribution of 7-ZSTar that includes RAR
extraction support is not purely LGPL v3.

## BSD-licensed files (from upstream 7-Zip)

- `CPP/7zip/Compress/LzfseDecoder.cpp` - BSD 3-Clause
  (derived from Apple's LZFSE compression library)
- `C/ZstdDec.c` - BSD 3-Clause
  (developed using the original zstd decoder by Facebook/Meta as reference)
- `C/Xxh64.c` - BSD 2-Clause
  (derived from the original XXH64 code by Yann Collet)

Full texts are preserved in upstream's `DOC/License.txt`.

## Public-domain files (from upstream 7-Zip)

Some files state "Public domain" in the source file itself (e.g. parts of the
LZMA SDK such as `C/LzmaEnc.c`). That status is unchanged.

## Code ported from 7-Zip-zstd

The C++ layer that drives brotli, lz4, lz5, lizard and fast-lzma2 - `Brotli*`,
`Lz4*`, `Lz5*`, `Lizard*` and `FastLzma2*` under `CPP/7zip/Compress/`, plus
the matching handlers under `CPP/7zip/Archive/`, **22 files** - was ported
from [mcmilk/7-Zip-zstd](https://github.com/mcmilk/7-Zip-zstd) by Tino
Reichardt. That project is a fork of 7-Zip and licenses itself "the same as
the Mainline 7-Zip, which means most of the code is GNU LGPL v2.1-or-later",
so the code arrives under terms this LGPL v3 distribution can carry.

Every ported file says so in its own header, and
`git grep -l "Ported from mcmilk/7-Zip-zstd"` produces exactly that list -
`build/Test-Smoke.ps1` checks the count against the number stated in `NOTICE`,
so the two cannot drift. This is attribution, not an exception: the terms are
the same LGPL the rest of the program is under.

Do not use `git grep "7-Zip-zstd"` for this: seven further files name the
project without being ports of it - the five `*Register.cpp`, `MethodProps.cpp`
and `7zip.mak` - because they match mcmilk's coder ids and property names for
archive interoperability. Those are this project's own code, or upstream's.

**The zstd files are not part of that set**, and the distinction matters for
anyone tracing provenance:

| File | Origin |
|---|---|
| `CPP/7zip/Compress/ZstdDecoder.*`, `CPP/7zip/Archive/ZstdHandler.cpp` | upstream 7-Zip's own (already in 26.02, where this fork began) - it decodes zstd |
| `CPP/7zip/Compress/ZstdEncoder.*`, `ZstdEncoderProps.*`, `ZstdRegister.cpp` | written for this project, against the encoder API upstream had stubbed out |

The encoder matches 7-Zip-zstd's `.7z` coder id (`0x4F71101`) and its
five-byte coder-properties layout so that archives interoperate. That is
format compatibility, deliberately chosen; no code was taken.

### Could those 27 files come from the original libraries instead, under their
### BSD/MIT terms?

No, and the reason is what the files contain. They are not compression code.
Each is an implementation of 7-Zip's own COM interfaces - `ICompressCoder`,
`ICompressSetCoderProperties`, `PROPVARIANT`, `NCoderPropID`, the
`REGISTER_CODEC` machinery - that forwards to the multithreading wrappers in
`C/zstdmt/` (`LZ4MT_*`, `BROTLIMT_*`, ...). The compression itself is already
taken from the original libraries, and already under their own terms:
`C/lz4/`, `C/lz5/`, `C/lizard/`, `C/brotli/`, `C/fast-lzma2/` are BSD or MIT,
and `C/zstdmt/` is BSD 2-Clause.

lz4's own headers know nothing about `ICompressCoder`, so no version of these
files could be derived from them. Rewriting the 27 from scratch would change
who is credited, not what licence applies: the result would still implement
7-Zip's LGPL interfaces and still be compiled into `7z.dll`, which is an LGPL
work. The current arrangement is therefore already the permissive one - the
libraries under BSD/MIT, and only the 7-Zip-shaped glue under the LGPL that
7-Zip imposes anyway.

For completeness, there is a theoretical route: 7-Zip can load codecs from
separate DLLs (`Z7_EXTERNAL_CODECS`), and a codec that merely *uses* the LGPL
library, rather than being compiled into it, is not bound to the LGPL in the
same way. Taking it would mean shipping the added formats as loose DLLs
outside `7z.dll` - a different product shape, more moving parts at install
time, and no benefit to anyone who is not relicensing. It is noted here so
that the option is on record, not because it is recommended.

## Licence choices, and where the floor is

This project takes the most permissive option wherever one exists, so that
relicensing later stays possible:

| Component | Options | Taken | Lower available? |
|---|---|---|---|
| zstd | BSD 3-Clause or GPLv2 | BSD 3-Clause | no |
| fast-lzma2 | BSD 3-Clause or GPLv2 | BSD 3-Clause | no |
| lz4, lz5, lizard, xxHash, zstdmt | BSD 2-Clause only | BSD 2-Clause | no |
| brotli | MIT only | MIT | no |
| 7-Zip code this fork builds on | LGPL 2.1 **or any later version** | LGPL v3 for the fork as a whole | **yes - LGPL 2.1** |
| 7-Zip-zstd code (the 27 files) | LGPL 2.1-or-later | same as the fork | same as above |
| RAR decoders | LGPL + unRAR restriction | unchanged | no - the restriction is not ours to remove |

The one lever that remains is the last-but-two row. Upstream offers "version
2.1 of the License, or (at your option) any later version"; this fork
exercises the "later version" half and ships under LGPL v3. Distributing under
**LGPL 2.1-or-later** instead would be strictly more permissive and would
leave the v3 option open to anyone downstream. Nothing in the vendored
libraries or the ported code prevents it - they are BSD, MIT and
LGPL 2.1-or-later respectively.

**Decided 2026-08-06: 7-ZSTar stays on LGPL v3.** The lever is recorded, not
taken. Nothing here needs revisiting unless the project chooses otherwise;
what follows is what that choice would cost if it is ever made.

**What would close that lever, permanently:** accepting a contribution
licensed under LGPL v3 *only*. Everything in the tree today is either this
project's own work or LGPL 2.1-or-later, which is why moving down is still
possible; one v3-only file makes it impossible for as long as that file stays.
Anyone merging outside contributions should ask which it is - the decision is
one-way.

What cannot be lowered: anything derived from 7-Zip stays under the LGPL,
because that is the licence Igor Pavlov offers it under, and the RAR
decompression restriction stays because it is Alexander Roshal's condition.

## Third-party libraries vendored by 7-ZSTar

Each vendored library keeps its original license file in its own directory.
`NOTICE` quotes each copyright line verbatim from those files; this table is
the summary (all LGPLv3-compatible):

| Path | Library | License |
|---|---|---|
| `C/zstd/` | zstd | BSD 3-Clause, dual-licensed with GPLv2; BSD branch chosen |
| `C/hashes/` | xxHash | BSD 2-Clause (stated in `xxhash.h`; no separate license file) |
| `C/brotli/` | brotli | MIT |
| `C/lz4/` | lz4 | BSD 2-Clause |
| `C/lz5/` | lz5 | BSD 2-Clause |
| `C/lizard/` | lizard | BSD 2-Clause |
| `C/fast-lzma2/` | fast-lzma2 | BSD 3-Clause, dual-licensed with GPLv2; BSD branch chosen |
| `C/zstdmt/` | zstdmt (MT wrappers) | BSD 2-Clause |

Two things worth stating explicitly, because both are easy to get wrong when
auditing a tree like this:

* **Only library sources are vendored.** lz4, lizard and others put GPL terms
  on their `programs/` and `tests/` trees; none of those directories exists
  here, and every object the makefiles build resolves to a file in the flat
  library directories above. No GPL-licensed file is compiled into 7-ZSTar.
* **`C/lizard/` has a dangling reference.** Seven of its files (`fse.h`,
  `huf.h`, `liz_fse_*.c`, `liz_huf_*.c`, `liz_entropy_common.c`) carry the
  zstd-style header offering "BSD or GPLv2 (found in the COPYING file)" - but
  upstream lizard ships no `COPYING`, so the GPLv2 half of that offer points
  at nothing. It changes nothing here: `C/lizard/LICENSE` grants BSD 2-Clause
  outright, and that is the branch this project uses.

## AI-generated toolbar art

The bitmaps in `CPP/7zip/UI/FileManager/7zstar/` were cut from an image made with
an AI image generator. Purely AI-generated material may not be protected by
copyright at all, so this project claims no exclusive right in the generated
image. Anything protected in these files, such as the selection and processing
done here, is under the LGPL with the rest of 7-ZSTar.

## Upstream assets taken from 7-Zip's binary release

Three things here come out of upstream's **binary** package rather than its
source tree, because that is the only place upstream publishes them:

| Path | What | State |
|---|---|---|
| `Lang/` | the translations | upstream's, with only the strings naming the product rewritten (`Lang/UPSTREAM.md`) |
| `Help/7-zip.chm` | the help file | byte-identical to upstream's (`Help/UPSTREAM.md`) |
| `LICENSE-7-Zip.txt` | upstream's own licence statement | byte-identical; see below |

**Their terms are the binary package's terms, not the source tree's**, and the
two documents differ. `LICENSE-7-Zip.txt` is what shipped in
`7z2605-x64.msi` (byte-identical to 26.02's); it lists the licences per file of the binary distribution
and says of everything that is not `7z.dll`:

> All other files: the "GNU LGPL".

which is the clause that covers `7-zip.chm` and `Lang\*.txt`. The same
document then requires, of anyone redistributing binaries:

> Redistributions in binary form must reproduce related license information
> from this file.

That is why `LICENSE-7-Zip.txt` is installed with 7-ZSTar rather than merely
referenced: reproducing it is an obligation we inherit by shipping binaries
built from that code and assets taken from that package. (`DOC/License.txt`,
the source tree's own licence file, stays where upstream put it and is a
different document - it describes the *source*, file by file.)

SHA-256 of `LICENSE-7-Zip.txt`, as extracted:
`519ac0a4bded9c18ea02e0afb71f663d8c47373bd9facd3ac96a79f51d77765d`

They are listed here rather than under the table above because they are
**not** exceptions - the entry exists so that a reader who notices two
directories of upstream material in the package does not have to wonder.
