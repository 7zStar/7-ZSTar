// LizardEncoder.cpp -- 7-ZSTar: new file (M6a)
//
// Ported from mcmilk/7-Zip-zstd (C) 2017 Tino Reichardt. _numThreads
// defaults to NWindows::NSystem::GetNumberOfProcessors() (all cores),
// matching lz5's encoder (not lz4's, which defaults to 1) -- mcmilk's own
// upstream choice, kept, but capped at LIZARDMT_THREAD_MAX in the
// constructor (upstream #545/PR #546): the raw processor count is uncapped
// and LIZARDMT_createCCtx() rejects anything above that maximum.

#include "StdAfx.h"
#include "LizardEncoder.h"
#include "LizardDecoder.h"

#ifndef Z7_EXTRACT_ONLY
namespace NCompress {
namespace NLIZARD {

CEncoder::CEncoder():
  _processedIn(0),
  _processedOut(0),
  _inputSize(0),
  _numThreads(NWindows::NSystem::GetNumberOfProcessors()),
  _ctx(NULL)
{
  // GetNumberOfProcessors() is uncapped and sums all processor groups, while
  // LIZARDMT_createCCtx() only accepts up to LIZARDMT_THREAD_MAX.
  // LizardHandler never calls SetNumberOfThreads(), so clamp here too.
  if (_numThreads > (UInt32)LIZARDMT_THREAD_MAX)
    _numThreads = (UInt32)LIZARDMT_THREAD_MAX;
  _props.clear();
}

CEncoder::~CEncoder()
{
  if (_ctx)
    LIZARDMT_freeCCtx(_ctx);
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

        /* level 10..49: tens digit selects mode (fastLZ4/LIZv1, +/-Huffman),
           ones digit the within-mode level -- see LizardEncoder.h. A value
           below LIZARDMT_LEVEL_MIN (e.g. a naive 0..9 GUI slider value, see
           CompressDialog.cpp's g_Formats "Lizard" row comment) is not a
           valid mode+level encoding at all, hence the lower clamp. */
        // clamp in UInt32: narrowing first would wrap, e.g. -mx256 -> 0
        UInt32 level = prop.ulVal;
        if (level > (UInt32)LIZARDMT_LEVEL_MAX)
          level = LIZARDMT_LEVEL_MAX;
        if (level < (UInt32)LIZARDMT_LEVEL_MIN)
          level = LIZARDMT_LEVEL_MIN;
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
  LIZARDMT_RdWr_t rdwr;
  size_t result;
  HRESULT res = S_OK;

  struct LizardStream Rd;
  Rd.inStream = inStream;
  Rd.outStream = outStream;
  Rd.processedIn = &_processedIn;
  Rd.processedOut = &_processedOut;

  struct LizardStream Wr;
  if (_processedIn == 0)
    Wr.progress = progress;
  else
    Wr.progress = 0;
  Wr.inStream = inStream;
  Wr.outStream = outStream;
  Wr.processedIn = &_processedIn;
  Wr.processedOut = &_processedOut;

  /* 1) setup read/write functions */
  rdwr.fn_read = ::LizardRead;
  rdwr.fn_write = ::LizardWrite;
  rdwr.arg_read = (void *)&Rd;
  rdwr.arg_write = (void *)&Wr;

  /* 2) create compression context, if needed */
  if (!_ctx)
    _ctx = LIZARDMT_createCCtx(_numThreads, _props._level, _inputSize);
  if (!_ctx)
    return S_FALSE;

  /* 3) compress */
  result = LIZARDMT_compressCCtx(_ctx, &rdwr);
  if (LIZARDMT_isError(result)) {
    if (result == (size_t)-LIZARDMT_error_canceled)
      return E_ABORT;
    return E_FAIL;
  }

  return res;
}

Z7_COM7F_IMF(CEncoder::SetNumberOfThreads(UInt32 numThreads))
{
  const UInt32 kNumThreadsMax = LIZARDMT_THREAD_MAX;
  if (numThreads < 1) numThreads = 1;
  if (numThreads > kNumThreadsMax) numThreads = kNumThreadsMax;
  _numThreads = numThreads;
  return S_OK;
}

}}


// ----------------------- CreateTarChainCoder_Lizard -------------------------
// See CPP/7zip/Archive/TarChain/TarChainCoderFactory.h for why this
// indirection exists.

#include "../Archive/TarChain/TarChainCoderFactory.h"

HRESULT CreateTarChainCoder_Lizard(const NArchive::CSingleMethodProps &props, CMyComPtr<ICompressCoder> &coder)
{
  NCompress::NLIZARD::CEncoder *encoderSpec = new NCompress::NLIZARD::CEncoder;
  coder = encoderSpec;
  return props.SetCoderProps(encoderSpec, NULL);
}

#endif
