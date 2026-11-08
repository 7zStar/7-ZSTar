// FastLzma2Register.cpp -- 7-ZSTar: new file (M6a)
//
// Registers Fast LZMA2 (C/fast-lzma2/, UPSTREAM.txt) as an *alternative
// encoder* under the official LZMA2 coder id (0x21, see 7zHeader.h
// k_LZMA2) rather than a coder id of its own -- matching
// mcmilk/7-Zip-zstd's own FastLzma2Register.cpp exactly. Two entries now
// exist in the codec registry for id 0x21: this one (name "FLZMA2",
// encoder = CFastEncoder) and the official one in Lzma2Register.cpp (name
// "LZMA2", encoder = the official single-threaded CEncoder) -- harmless,
// since:
//   - encoding is selected by *name* (-m0=FLZMA2 vs -m0=LZMA2), never
//     ambiguous;
//   - decoding is selected by *id*, and both entries decode via the same
//     unmodified NCompress::NLzma2::CDecoder class (Fast LZMA2 produces a
//     standard LZMA2 bitstream -- only the *encoder* differs, a
//     multi-threaded radix match finder instead of the official
//     single-threaded LzFind), so it doesn't matter which of the two
//     identical-behavior registrations the id-based lookup happens to pick.
// See CPP/7zip/Common/RegisterCodec.h's REGISTER_CODEC_E/REGISTER_CODECS_VAR
// macros -- a plain array of independent entries, no uniqueness
// requirement on Id.

#include "StdAfx.h"

#include "../Common/RegisterCodec.h"

#include "Lzma2Decoder.h"

#ifndef Z7_EXTRACT_ONLY
#include "FastLzma2Encoder.h"
#endif

REGISTER_CODEC_E(
  FLZMA2,
  NCompress::NLzma2::CDecoder(),
  NCompress::NLzma2::CFastEncoder(),
  0x21,
  "FLZMA2")
