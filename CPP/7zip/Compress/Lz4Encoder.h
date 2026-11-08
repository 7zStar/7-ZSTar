// Lz4Encoder.h -- 7-ZSTar: new file (M6a)
//
// Ported from mcmilk/7-Zip-zstd (C) 2016 Tino Reichardt. Already used the
// modern Z7_CLASS_IMP_COM_N macro style upstream (mcmilk periodically syncs
// its codec wrappers against newer official 7-Zip macro conventions), so
// this port is a near-verbatim copy -- see CPP/7zip/Compress/ZstdEncoder.h's
// header comment for the style this repo's own codec ports follow. Include
// guard added (mcmilk's original has none; harmless, matches this repo's
// own ZstdEncoder.h/ZstdDecoder.h convention).

#ifndef ZIP7_INC_LZ4_ENCODER_H
#define ZIP7_INC_LZ4_ENCODER_H

#define LZ4_STATIC_LINKING_ONLY
#include "../../../C/Alloc.h"
#include "../../../C/Threads.h"
#include "../../../C/lz4/lz4.h"
#include "../../../C/zstdmt/lz4-mt.h"

#include "../../Common/Common.h"
#include "../../Common/MyCom.h"
#include "../ICoder.h"
#include "../Common/StreamUtils.h"

#ifndef Z7_EXTRACT_ONLY
namespace NCompress {
namespace NLZ4 {

struct CProps
{
  CProps() { clear (); }
  void clear ()
  {
    memset(this, 0, sizeof (*this));
    _ver_major = LZ4_VERSION_MAJOR;
    _ver_minor = LZ4_VERSION_MINOR;
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

  LZ4MT_CCtx *_ctx;

  CEncoder();
  ~CEncoder();
};

}}
#endif

#endif
