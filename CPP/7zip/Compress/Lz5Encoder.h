// Lz5Encoder.h -- 7-ZSTar: new file (M6a)
//
// Ported from mcmilk/7-Zip-zstd (C) 2016 Tino Reichardt; see Lz4Encoder.h's
// header comment (same style, same era, near-identical wrapper -- lz5 is
// mechanically lz4's own codebase forked and extended for a higher
// compression ratio at the cost of speed). Include guard added.

#ifndef ZIP7_INC_LZ5_ENCODER_H
#define ZIP7_INC_LZ5_ENCODER_H

#define LZ5_STATIC_LINKING_ONLY
#include "../../../C/Alloc.h"
#include "../../../C/Threads.h"
#include "../../../C/lz5/lz5.h"
#include "../../../C/zstdmt/lz5-mt.h"

#include "../../Common/Common.h"
#include "../../Common/MyCom.h"
#include "../ICoder.h"
#include "../Common/StreamUtils.h"

#ifndef Z7_EXTRACT_ONLY
namespace NCompress {
namespace NLZ5 {

struct CProps
{
  CProps() { clear (); }
  void clear ()
  {
    memset(this, 0, sizeof (*this));
    _ver_major = LZ5_VERSION_MAJOR;
    _ver_minor = LZ5_VERSION_MINOR;
    _level = 3;
  }

  Byte _ver_major;
  Byte _ver_minor;
  Byte _level;
  Byte _reserved[2];
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

  LZ5MT_CCtx *_ctx;

  CEncoder();
  ~CEncoder();
};

}}
#endif

#endif
