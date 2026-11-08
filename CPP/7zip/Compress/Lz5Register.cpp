// Lz5Register.cpp -- 7-ZSTar: new file (M6a)
//
// Coder id 0x4F71105 matches mcmilk/7-Zip-zstd's own Lz5Register.cpp (C)
// 2016 Tino Reichardt.

#include "StdAfx.h"

#include "../Common/RegisterCodec.h"

#include "Lz5Decoder.h"

#ifndef Z7_EXTRACT_ONLY
#include "Lz5Encoder.h"
#endif

REGISTER_CODEC_E(
  LZ5,
  NCompress::NLZ5::CDecoder(),
  NCompress::NLZ5::CEncoder(),
  0x4F71105, "LZ5")
