// LizardEncoder.h -- 7-ZSTar: new file (M6a)
//
// Ported from mcmilk/7-Zip-zstd (C) 2017 Tino Reichardt; see Lz4Encoder.h's
// header comment (same wrapper shape/era). Include guard added.
//
// Note: Lizard's valid level range is 10..49 (LIZARDMT_LEVEL_MIN..MAX),
// encoding both a compression *mode* (fastLZ4/LIZv1, +/-Huffman -- the
// tens digit) and a within-mode level (the ones digit), unlike lz4/lz5's
// plain 1..N scale -- see SetCoderProperties() in the .cpp for the level
// clamp (both bounds; mcmilk's own upstream file only clamps the upper
// one, see that function's comment) and CompressDialog.cpp's g_Formats
// "Lizard" row comment for how this project's single-method-entry GUI
// simplification (mcmilk's own GUI splits this into 4 separate method
// entries, one per mode) interacts with the level scale.

#ifndef ZIP7_INC_LIZARD_ENCODER_H
#define ZIP7_INC_LIZARD_ENCODER_H

#define LIZARD_STATIC_LINKING_ONLY
#include "../../../C/Alloc.h"
#include "../../../C/Threads.h"
#include "../../../C/lizard/lizard_compress.h"
#include "../../../C/lizard/lizard_frame.h"
#include "../../../C/zstdmt/lizard-mt.h"

#include "../../Common/Common.h"
#include "../../Common/MyCom.h"
#include "../ICoder.h"
#include "../Common/StreamUtils.h"

#ifndef Z7_EXTRACT_ONLY
namespace NCompress {
namespace NLIZARD {

struct CProps
{
  CProps() { clear (); }
  void clear ()
  {
    memset(this, 0, sizeof (*this));
    _ver_major = LIZARD_VERSION_MAJOR;
    _ver_minor = LIZARD_VERSION_MINOR;
    _level = LIZARDMT_LEVEL_MIN;
  }

  Byte _ver_major;
  Byte _ver_minor;
  Byte _level;
};

Z7_CLASS_IMP_COM_4(
  CEncoder,
  ICompressCoder,
  ICompressSetCoderMt,
  ICompressSetCoderProperties,
  ICompressWriteCoderProperties
)
public:
  CProps _props;

  UInt64 _processedIn;
  UInt64 _processedOut;
  UInt32 _inputSize;
  UInt32 _numThreads;

  LIZARDMT_CCtx *_ctx;

  CEncoder();
  ~CEncoder();
};

}}
#endif

#endif
