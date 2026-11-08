// ZstdRegister.cpp -- 7-ZSTar: new file (M2)
//
// Registers zstd as a *coder* usable inside container formats (.7z), via the
// generic RegisterCodec.h / CreateCoder.h coder-ID lookup mechanism.
//
// This is a separate registry from ZstdHandler.cpp's REGISTER_ARC_IO (which
// registers the standalone .zst *archive format*, and instantiates
// NCompress::NZstd::CDecoder directly without going through this coder
// registry at all). Before this file existed, zstd was not reachable as a 7z
// *coder* in either direction: neither decode nor encode of zstd-compressed
// entries inside a .7z container was possible.
//
// Two coder IDs are registered (see CPP/7zip/Archive/7z/7zHeader.h) :
//   0x4F71101 (k_ZSTD_mcmilk) : 7-ZSTar / mcmilk-compatible id -- decoder + encoder.
//   0x4015D   (k_ZSTD)        : WinZip zstd id -- decoder only for now (zstd
//                                frames are self-describing and our decoder
//                                ignores coder-properties content entirely, so
//                                decoding archives that used this id is safe;
//                                the WinZip .7z coder-properties format for
//                                *encoding* has not been verified, so we don't
//                                produce this id).

#include "StdAfx.h"

#include "../Common/RegisterCodec.h"

#include "ZstdDecoder.h"
#include "ZstdEncoder.h"

REGISTER_CODEC_CREATE(CreateDec, NCompress::NZstd::CDecoder)

#ifndef Z7_EXTRACT_ONLY
REGISTER_CODEC_CREATE(CreateEnc, NCompress::NZstd::CEncoder)
#endif

REGISTER_CODECS_VAR
{
#ifndef Z7_EXTRACT_ONLY
  { CreateDec, CreateEnc, 0x4F71101, "ZSTD", 1, false },
#else
  { CreateDec, NULL,      0x4F71101, "ZSTD", 1, false },
#endif
  // distinct name (not "ZSTD") so that name-based lookup for "-m0=zstd" is
  // never ambiguous between the two registered ids.
  { CreateDec, NULL,      0x4015D,   "ZSTD-WZ", 1, false },
};

REGISTER_CODECS(ZSTD)
