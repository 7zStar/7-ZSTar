// Lz5Decoder.h -- 7-ZSTar: new file (M6a)
//
// Ported from mcmilk/7-Zip-zstd (C) 2016 Tino Reichardt; see Lz4Decoder.h's
// header comment. Include guard added.

#ifndef ZIP7_INC_LZ5_DECODER_H
#define ZIP7_INC_LZ5_DECODER_H

#define LZ5_STATIC_LINKING_ONLY
#include "../../../C/Alloc.h"
#include "../../../C/Threads.h"
#include "../../../C/lz5/lz5.h"
#include "../../../C/zstdmt/lz5-mt.h"

#include "../../Windows/System.h"
#include "../../Common/Common.h"
#include "../../Common/MyCom.h"
#include "../ICoder.h"
#include "../Common/StreamUtils.h"
#include "../Common/RegisterCodec.h"
#include "../Common/ProgressMt.h"

struct Lz5Stream {
  ISequentialInStream *inStream;
  ISequentialOutStream *outStream;
  ICompressProgressInfo *progress;
  UInt64 *processedIn;
  UInt64 *processedOut;
};

extern int Lz5Read(void *Stream, LZ5MT_Buffer * in);
extern int Lz5Write(void *Stream, LZ5MT_Buffer * in);

namespace NCompress {
namespace NLZ5 {

struct DProps
{
  DProps() { clear (); }
  void clear ()
  {
    memset(this, 0, sizeof (*this));
    _ver_major = LZ5_VERSION_MAJOR;
    _ver_minor = LZ5_VERSION_MINOR;
    _level = 1;
  }

  Byte _ver_major;
  Byte _ver_minor;
  Byte _level;
  Byte _reserved[2];
};

class CDecoder Z7_final:
  public ICompressCoder,
  public ICompressSetDecoderProperties2,
  public ICompressSetCoderMt,
  public CMyUnknownImp
{
  CMyComPtr < ISequentialInStream > _inStream;

public:
  DProps _props;

  UInt64 _processedIn;
  UInt64 _processedOut;
  UInt32 _inputSize;
  UInt32 _numThreads;
  // 7-ZSTar: see NeedsMoreInput()
  bool _needMoreInput;

  HRESULT CodeSpec(ISequentialInStream *inStream, ISequentialOutStream *outStream, ICompressProgressInfo *progress);
  HRESULT CodeResume(ISequentialOutStream * outStream, const UInt64 * outSize, ICompressProgressInfo * progress);
  HRESULT SetOutStreamSizeResume(const UInt64 *outSize);

  Z7_COM_QI_BEGIN2(ICompressCoder)
  Z7_COM_QI_ENTRY(ICompressSetDecoderProperties2)
  Z7_COM_QI_ENTRY(ICompressSetCoderMt)
  Z7_COM_QI_END
  Z7_COM_ADDREF_RELEASE

  Z7_IFACE_COM7_IMP(ICompressCoder)
  Z7_IFACE_COM7_IMP(ICompressSetDecoderProperties2)
public:
  Z7_IFACE_COM7_IMP(ICompressSetCoderMt)
  Z7_COM7F_IMF(SetOutStreamSize(const UInt64 *outSize));
#ifndef Z7_NO_READ_FROM_CODER
  Z7_COM7F_IMF(SetInStream(ISequentialInStream *inStream));
  Z7_COM7F_IMF(ReleaseInStream());
  UInt64 GetInputProcessedSize() const { return _processedIn; }
#endif
  // 7-ZSTar: true after CodeSpec() returned S_FALSE because the input
  // ended before the stream did (#564); the standalone handler reports
  // that as Unexpected end of data rather than Data Error.
  bool NeedsMoreInput() const { return _needMoreInput; }

public:
  CDecoder();
  ~CDecoder();
};

}}

#endif
