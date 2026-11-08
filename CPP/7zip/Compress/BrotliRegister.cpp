// BrotliRegister.cpp -- 7-ZSTar: new file (M6a)
//
// Coder id 0x4F71102 matches mcmilk/7-Zip-zstd's own BrotliRegister.cpp (C)
// 2017 Tino Reichardt.

#include "StdAfx.h"

#include "../Common/RegisterCodec.h"

#include "BrotliDecoder.h"

#ifndef Z7_EXTRACT_ONLY
#include "BrotliEncoder.h"
#endif

REGISTER_CODEC_E(
  BROTLI,
  NCompress::NBROTLI::CDecoder(),
  NCompress::NBROTLI::CEncoder(),
  0x4F71102, "BROTLI")
