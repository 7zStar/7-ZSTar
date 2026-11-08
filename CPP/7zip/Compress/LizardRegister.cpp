// LizardRegister.cpp -- 7-ZSTar: new file (M6a)
//
// Coder id 0x4F71106 matches mcmilk/7-Zip-zstd's own LizardRegister.cpp (C)
// 2017 Tino Reichardt.

#include "StdAfx.h"

#include "../Common/RegisterCodec.h"

#include "LizardDecoder.h"

#ifndef Z7_EXTRACT_ONLY
#include "LizardEncoder.h"
#endif

REGISTER_CODEC_E(
  LIZARD,
  NCompress::NLIZARD::CDecoder(),
  NCompress::NLIZARD::CEncoder(),
  0x4F71106, "LIZARD")
