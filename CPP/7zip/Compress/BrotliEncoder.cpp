// BrotliEncoder.cpp -- 7-ZSTar: new file (M6a)
//
// Ported from mcmilk/7-Zip-zstd (C) 2017 Tino Reichardt.

#include "StdAfx.h"
#include "BrotliEncoder.h"
#include "BrotliDecoder.h"

#ifndef Z7_EXTRACT_ONLY
namespace NCompress {
namespace NBROTLI {

CEncoder::CEncoder():
  _processedIn(0),
  _processedOut(0),
  _inputSize(0),
  _numThreads(NWindows::NSystem::GetNumberOfProcessors()),
  _Long(-1),
  _WindowLog(-1),
  unpackSize(0),
  _ctx(NULL)
{
  // GetNumberOfProcessors() is uncapped and sums all processor groups, while
  // BROTLIMT_createCCtx() only accepts up to BROTLIMT_THREAD_MAX.
  // BrotliHandler does call SetNumberOfThreads(), but the default has to be
  // valid on its own.
  if (_numThreads > (UInt32)BROTLIMT_THREAD_MAX)
    _numThreads = (UInt32)BROTLIMT_THREAD_MAX;
  _props.clear();
}

CEncoder::~CEncoder()
{
  if (_ctx)
    BROTLIMT_freeCCtx(_ctx);
}

Z7_COM7F_IMF(CEncoder::SetCoderProperties(const PROPID * propIDs, const PROPVARIANT * coderProps, UInt32 numProps))
{
  _props.clear();

  for (UInt32 i = 0; i < numProps; i++)
  {
    const PROPVARIANT & prop = coderProps[i];
    PROPID propID = propIDs[i];
    UInt32 v = (UInt32)prop.ulVal;
    switch (propID)
    {
    case NCoderPropID::kLevel:
      {
        if (prop.vt != VT_UI4)
          return E_INVALIDARG;

        // clamp in UInt32: narrowing first would wrap, e.g. -mx256 -> 0
        UInt32 level = prop.ulVal;
        if (level > (UInt32)BROTLIMT_LEVEL_MAX)
          level = BROTLIMT_LEVEL_MAX;
        // BROTLIMT_LEVEL_MIN is 0, which an unsigned value always satisfies
        _props._level = static_cast < Byte > (level);

        break;
      }
    case NCoderPropID::kNumThreads:
      {
        SetNumberOfThreads(v);
        break;
      }
    case NCoderPropID::kLong:
      {
        /* like --long in zstd cli program */
        _Long = 1;
        if (v == 0) {
          if (prop.vt == VT_EMPTY) {
            // m0=brotli:long -> long=default
            _WindowLog = BROTLI_MAX_WINDOW_BITS; //BROTLI_DEFAULT_WINDOW;
          } else {
            // m0=brotli:long=0 -> long=auto
            _WindowLog = 0;
          }
        } else if (v < BROTLI_MIN_WINDOW_BITS) {
          // m0=brotli:long=9 -> long=10
          _WindowLog = BROTLI_MIN_WINDOW_BITS;
        } else if (v > BROTLI_LARGE_MAX_WINDOW_BITS) {
          // m0=brotli:long=33 -> long=max
          _WindowLog = BROTLI_LARGE_MAX_WINDOW_BITS;
        } else {
          // m0=brotli:long=15 -> long=value
          _WindowLog = v;
        }
        break;
      }
    case NCoderPropID::kWindowLog:
      {
        if (v < BROTLI_MIN_WINDOW_BITS) v = BROTLI_MIN_WINDOW_BITS;
        if (v > BROTLI_MAX_WINDOW_BITS) v = BROTLI_MAX_WINDOW_BITS;
        _WindowLog = v;
        break;
      }
    default:
      {
        break;
      }
    }
  }

  return S_OK;
}

Z7_COM7F_IMF(CEncoder::SetCoderPropertiesOpt(const PROPID *propIDs,
    const PROPVARIANT *coderProps, UInt32 numProps))
{
  for (UInt32 i = 0; i < numProps; i++)
  {
    const PROPVARIANT &prop = coderProps[i];
    const PROPID propID = propIDs[i];
    if (propID == NCoderPropID::kExpectedDataSize)
      if (prop.vt == VT_UI8 && prop.uhVal.QuadPart)
        unpackSize = prop.uhVal.QuadPart;
  }
  return S_OK;
}

Z7_COM7F_IMF(CEncoder::WriteCoderProperties(ISequentialOutStream * outStream))
{
  return WriteStream(outStream, &_props, sizeof (_props));
}

Z7_COM7F_IMF(CEncoder::Code(ISequentialInStream *inStream,
  ISequentialOutStream *outStream, const UInt64 * /*inSize*/ ,
  const UInt64 * /*outSize */, ICompressProgressInfo *progress))
{
  BROTLIMT_RdWr_t rdwr;
  size_t result;
  HRESULT res = S_OK;

  _processedIn = 0;
  _processedOut = 0;

  struct BrotliStream Rd;
  Rd.inStream = inStream;
  Rd.outStream = outStream;
  Rd.processedIn = &_processedIn;
  Rd.processedOut = &_processedOut;

  struct BrotliStream Wr;
  Wr.progress = progress;
  Wr.inStream = inStream;
  Wr.outStream = outStream;
  Wr.processedIn = &_processedIn;
  Wr.processedOut = &_processedOut;

  /* 1) setup read/write functions */
  rdwr.fn_read = ::BrotliRead;
  rdwr.fn_write = ::BrotliWrite;
  rdwr.arg_read = (void *)&Rd;
  rdwr.arg_write = (void *)&Wr;

  /* 2) create compression context, if needed */
  if (!_ctx)
    _ctx = BROTLIMT_createCCtx(_numThreads, unpackSize, _props._level, _inputSize,
      _WindowLog >= 0 ? _WindowLog : BROTLI_MAX_WINDOW_BITS);
  if (!_ctx)
    return S_FALSE;

  /* 4) compress */
  result = BROTLIMT_compressCCtx(_ctx, &rdwr);
  if (BROTLIMT_isError(result)) {
    if (result == (size_t)-BROTLIMT_error_canceled)
      return E_ABORT;
    return E_FAIL;
  }

  return res;
}

Z7_COM7F_IMF(CEncoder::SetNumberOfThreads(UInt32 numThreads))
{
  const UInt32 kNumThreadsMax = BROTLIMT_THREAD_MAX;
  // if single-threaded, retain artificial number set in BrotliHandler (always prefer .br format):
  if ((int)numThreads < 1) {
    numThreads = 0;
  }
  else
  if (numThreads > kNumThreadsMax) numThreads = kNumThreadsMax;
  _numThreads = numThreads;
  return S_OK;
}

}}


// ----------------------- CreateTarChainCoder_Brotli -------------------------
// See CPP/7zip/Archive/TarChain/TarChainCoderFactory.h for why this
// indirection exists.

#include "../Archive/TarChain/TarChainCoderFactory.h"

HRESULT CreateTarChainCoder_Brotli(const NArchive::CSingleMethodProps &props, CMyComPtr<ICompressCoder> &coder)
{
  NCompress::NBROTLI::CEncoder *encoderSpec = new NCompress::NBROTLI::CEncoder;
  coder = encoderSpec;
  // 7-ZSTar: M6a -- mirrors Archive/BrotliHandler.cpp's own UpdateArchive(),
  // which forces single-threaded/plain framing here for the same reason:
  // CEncoder's constructor defaults _numThreads to all cores (unlike the
  // lz4/lz5/lizard cases in TarChainHandler.cpp, which don't need this --
  // their MT wrappers don't produce a non-standard framing when threaded),
  // and TarChainHandler.cpp doesn't run the zstd-style numThreads auto-fill
  // for any non-zstd codec, so without this override a tar.br archive
  // would silently get brotli's own multi-thread frame format applied to
  // an unknown-total-size (tar) stream -- unlike BrotliHandler.cpp's own
  // plain-file callers, TarChainHandler.cpp never sets unpackSize either
  // (tar's compressed output size isn't known ahead of time, same
  // "matches -7z a -so streaming semantics" situation as the kCodec_Zstd
  // case's own SrcSizeHint64=-1 comment above), so MT mode's chunk-planning
  // has nothing valid to plan against. Confirmed by testing: without this
  // line, `a -ttar.br` succeeds but the result can't be opened again at
  // all (S_FALSE from Open()) -- with it, round-trips correctly.
  encoderSpec->SetNumberOfThreads(0);
  return props.SetCoderProps(encoderSpec, NULL);
}

#endif
