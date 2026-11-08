// Lz4Register.cpp -- 7-ZSTar: new file (M6a)
//
// Coder id 0x4F71104 matches mcmilk/7-Zip-zstd's own Lz4Register.cpp (C)
// 2016 Tino Reichardt, so .7z archives written by mcmilk with -m0=lz4
// decode here unchanged, and vice versa.

#include "StdAfx.h"

#include "../Common/RegisterCodec.h"

#include "Lz4Decoder.h"
#if !defined(Z7_EXTRACT_ONLY) && !defined(Z7_LZ4_EXTRACT_ONLY)
#include "Lz4Encoder.h"
#endif

namespace NCompress {
namespace NLZ4 {

REGISTER_CODEC_E(
  LZ4,
  NCompress::NLZ4::CDecoder(),
  NCompress::NLZ4::CEncoder(),
  0x4F71104, "LZ4")

}}
