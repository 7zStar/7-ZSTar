// Lz5Encoder.cpp -- 7-ZSTar: new file (M6a)
//
// Ported from mcmilk/7-Zip-zstd (C) 2016 Tino Reichardt. Note the
// _numThreads default: LZ5's encoder defaults to
// NWindows::NSystem::GetNumberOfProcessors() (all cores), unlike LZ4's
// encoder which defaults to 1 -- this is mcmilk's own upstream difference
// between the two files, kept, but capped at LZ5MT_THREAD_MAX in the
// constructor (upstream #545/PR #546): the raw processor count is uncapped
// and LZ5MT_createCCtx() rejects anything above that maximum.

#include "StdAfx.h"
#include "Lz5Encoder.h"
#include "Lz5Decoder.h"

#ifndef Z7_EXTRACT_ONLY
namespace NCompress {
namespace NLZ5 {

CEncoder::CEncoder():
  _processedIn(0),
  _processedOut(0),
  _inputSize(0),
  _numThreads(NWindows::NSystem::GetNumberOfProcessors()),
  _ctx(NULL)
{
  // GetNumberOfProcessors() is uncapped and sums all processor groups, while
  // LZ5MT_createCCtx() only accepts up to LZ5MT_THREAD_MAX. Lz5Handler never
  // calls SetNumberOfThreads(), so clamp here too.
  if (_numThreads > (UInt32)LZ5MT_THREAD_MAX)
    _numThreads = (UInt32)LZ5MT_THREAD_MAX;
  _props.clear();
}

CEncoder::~CEncoder()
{
  if (_ctx)
    LZ5MT_freeCCtx(_ctx);
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
        if (level > (UInt32)LZ5MT_LEVEL_MAX)
          level = LZ5MT_LEVEL_MAX;
        if (level < (UInt32)LZ5MT_LEVEL_MIN)
          level = LZ5MT_LEVEL_MIN;
        _props._level = static_cast < Byte > (level);

        break;
      }
    case NCoderPropID::kNumThreads:
      {
        SetNumberOfThreads(v);
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

Z7_COM7F_IMF(CEncoder::WriteCoderProperties(ISequentialOutStream * outStream))
{
  return WriteStream(outStream, &_props, sizeof (_props));
}

Z7_COM7F_IMF(CEncoder::Code(ISequentialInStream *inStream,
  ISequentialOutStream *outStream, const UInt64 * /*inSize*/ ,
  const UInt64 * /*outSize */, ICompressProgressInfo *progress))
{
  LZ5MT_RdWr_t rdwr;
  size_t result;
  HRESULT res = S_OK;

  struct Lz5Stream Rd;
  Rd.inStream = inStream;
  Rd.outStream = outStream;
  Rd.processedIn = &_processedIn;
  Rd.processedOut = &_processedOut;

  struct Lz5Stream Wr;
  if (_processedIn == 0)
    Wr.progress = progress;
  else
    Wr.progress = 0;
  Wr.inStream = inStream;
  Wr.outStream = outStream;
  Wr.processedIn = &_processedIn;
  Wr.processedOut = &_processedOut;

  /* 1) setup read/write functions */
  rdwr.fn_read = ::Lz5Read;
  rdwr.fn_write = ::Lz5Write;
  rdwr.arg_read = (void *)&Rd;
  rdwr.arg_write = (void *)&Wr;

  /* 2) create compression context, if needed */
  if (!_ctx)
    _ctx = LZ5MT_createCCtx(_numThreads, _props._level, _inputSize);
  if (!_ctx)
    return S_FALSE;

  /* 3) compress */
  result = LZ5MT_compressCCtx(_ctx, &rdwr);
  if (LZ5MT_isError(result)) {
    if (result == (size_t)-LZ5MT_error_canceled)
      return E_ABORT;
    return E_FAIL;
  }

  return res;
}

Z7_COM7F_IMF(CEncoder::SetNumberOfThreads(UInt32 numThreads))
{
  const UInt32 kNumThreadsMax = LZ5MT_THREAD_MAX;
  if (numThreads < 1) numThreads = 1;
  if (numThreads > kNumThreadsMax) numThreads = kNumThreadsMax;
  _numThreads = numThreads;
  return S_OK;
}

}}


// ------------------------- CreateTarChainCoder_Lz5 -------------------------
// See CPP/7zip/Archive/TarChain/TarChainCoderFactory.h for why this
// indirection exists.

#include "../Archive/TarChain/TarChainCoderFactory.h"

HRESULT CreateTarChainCoder_Lz5(const NArchive::CSingleMethodProps &props, CMyComPtr<ICompressCoder> &coder)
{
  NCompress::NLZ5::CEncoder *encoderSpec = new NCompress::NLZ5::CEncoder;
  coder = encoderSpec;
  return props.SetCoderProps(encoderSpec, NULL);
}

#endif
