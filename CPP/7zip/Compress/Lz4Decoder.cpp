// Lz4Decoder.cpp -- 7-ZSTar: new file (M6a)
//
// Ported from mcmilk/7-Zip-zstd (C) 2016 Tino Reichardt.

#include "StdAfx.h"
#include "Lz4Decoder.h"

int Lz4Read(void *arg, LZ4MT_Buffer * in)
{
  struct Lz4Stream *x = (struct Lz4Stream*)arg;
  size_t size = in->size;

  HRESULT res = ReadStream(x->inStream, in->buf, &size);

  /* catch errors */
  switch (res) {
  case E_ABORT:
    return -2;
  case E_OUTOFMEMORY:
    return -3;
  }

  /* some other error -> read_fail */
  if (res != S_OK)
    return -1;

  in->size = size;
  *x->processedIn += size;

  return 0;
}

int Lz4Write(void *arg, LZ4MT_Buffer * out)
{
  struct Lz4Stream *x = (struct Lz4Stream*)arg;
  UInt32 todo = (UInt32)out->size;
  UInt32 done = 0;

  while (todo != 0)
  {
    UInt32 block;
    HRESULT res = x->outStream->Write((char*)out->buf + done, todo, &block);

    /* catch errors */
    switch (res) {
    case E_ABORT:
      return -2;
    case E_OUTOFMEMORY:
      return -3;
    }

    done += block;
    if (res == k_My_HRESULT_WritingWasCut)
      break;
    /* some other error -> write_fail */
    if (res != S_OK)
      return -1;

    if (block == 0)
      return -1;
    todo -= block;
  }

  *x->processedOut += done;
  /* we need no lock here, cause only one thread can write... */
  if (x->progress)
    x->progress->SetRatioInfo(x->processedIn, x->processedOut);

  return 0;
}

namespace NCompress {
namespace NLZ4 {

CDecoder::CDecoder():
  _processedIn(0),
  _processedOut(0),
  _inputSize(0),
  _numThreads(NWindows::NSystem::GetNumberOfProcessors()),
  _needMoreInput(false)
{
  // GetNumberOfProcessors() is uncapped and sums all processor groups, while
  // LZ4MT_createDCtx() only accepts up to LZ4MT_THREAD_MAX. Lz4Handler never
  // calls SetNumberOfThreads(), so clamp here too.
  if (_numThreads > (UInt32)LZ4MT_THREAD_MAX)
    _numThreads = (UInt32)LZ4MT_THREAD_MAX;
  _props.clear();
}

CDecoder::~CDecoder()
{
}

Z7_COM7F_IMF(CDecoder::SetDecoderProperties2(const Byte * prop, UInt32 size))
{
  DProps *pProps = (DProps *)prop;

  if (size != sizeof(DProps))
    return E_NOTIMPL;

  memcpy(&_props, pProps, sizeof (DProps));
  return S_OK;
}

Z7_COM7F_IMF(CDecoder::SetNumberOfThreads(UInt32 numThreads))
{
  const UInt32 kNumThreadsMax = LZ4MT_THREAD_MAX;
  if (numThreads < 1) numThreads = 1;
  if (numThreads > kNumThreadsMax) numThreads = kNumThreadsMax;
  _numThreads = numThreads;
  return S_OK;
}

HRESULT CDecoder::SetOutStreamSizeResume(const UInt64 * /*outSize*/)
{
  _processedOut = 0;
  return S_OK;
}

Z7_COM7F_IMF(CDecoder::SetOutStreamSize(const UInt64 * outSize))
{
  _processedIn = 0;
  RINOK(SetOutStreamSizeResume(outSize))
  return S_OK;
}

HRESULT CDecoder::CodeSpec(ISequentialInStream * inStream,
  ISequentialOutStream * outStream, ICompressProgressInfo * progress)
{
  _needMoreInput = false; // 7-ZSTar: see NeedsMoreInput()
  LZ4MT_RdWr_t rdwr;
  size_t result;
  HRESULT res = S_OK;

  struct Lz4Stream Rd;
  Rd.inStream = inStream;
  Rd.processedIn = &_processedIn;

  struct Lz4Stream Wr;
  Wr.progress = progress;
  Wr.outStream = outStream;
  Wr.processedIn = &_processedIn;
  Wr.processedOut = &_processedOut;

  /* 1) setup read/write functions */
  rdwr.fn_read = ::Lz4Read;
  rdwr.fn_write = ::Lz4Write;
  rdwr.arg_read = (void *)&Rd;
  rdwr.arg_write = (void *)&Wr;

  /* 2) create decompression context */
  LZ4MT_DCtx *ctx = LZ4MT_createDCtx(_numThreads, _inputSize);
  if (!ctx)
      return S_FALSE;

  /* 3) decompress */
  result = LZ4MT_decompressDCtx(ctx, &rdwr);

  /* 4) free resources */
  // 7-ZSTar: free before the error check (mcmilk leaks the DCtx on the
  // error returns; harmless there because E_ABORT meant "user canceled",
  // but our tar sniff aborts via E_ABORT on every open of a >=512B
  // non-tar file, which would leak one context per archive opened).
  LZ4MT_freeDCtx(ctx);
  if (LZ4MT_isError(result)) {
    if (result == (size_t)-LZ4MT_error_canceled)
      return E_ABORT;
    // 7-ZSTar: a stream that ends early (mcmilk #564, 3e1ea83) is S_FALSE,
    // the data-error result every caller already handles (see
    // BrotliDecoder.cpp), with NeedsMoreInput() set so the standalone
    // handler can say Unexpected end of data. mcmilk instead returns the
    // Win32 codes ERROR_HANDLE_EOF / ERROR_INVALID_DATA as HRESULTs: both
    // are success codes to SUCCEEDED(), and inside a .7z they surface as
    // Windows' own "Reached the end of the file".
    if (result == (size_t)-LZ4MT_error_end_of_data) {
      _needMoreInput = true;
      return S_FALSE;
    }
    // 7-ZSTar: the rest follows BrotliDecoder.cpp: bad input is S_FALSE,
    // reported as Data Error instead of E_FAIL's "Unspecified error";
    // compression_library is the codec rejecting the input (mcmilk
    // 48a3721); frame_decompress is a frame that did not end where the
    // container said. Out-of-memory keeps its own HRESULT.
    if (result == (size_t)-LZ4MT_error_memory_allocation)
      return E_OUTOFMEMORY;
    if (result == (size_t)-LZ4MT_error_data_error ||
        result == (size_t)-LZ4MT_error_compression_library ||
        result == (size_t)-LZ4MT_error_frame_decompress)
      return S_FALSE;
    return E_FAIL;
  }
  return res;
}

Z7_COM7F_IMF(CDecoder::Code(ISequentialInStream * inStream, ISequentialOutStream * outStream,
  const UInt64 * /*inSize */, const UInt64 *outSize, ICompressProgressInfo * progress))
{
  SetOutStreamSize(outSize);
  return CodeSpec(inStream, outStream, progress);
}

#ifndef Z7_NO_READ_FROM_CODER
Z7_COM7F_IMF(CDecoder::SetInStream(ISequentialInStream * inStream))
{
  _inStream = inStream;
  return S_OK;
}

Z7_COM7F_IMF(CDecoder::ReleaseInStream())
{
  _inStream.Release();
  return S_OK;
}
#endif

HRESULT CDecoder::CodeResume(ISequentialOutStream * outStream, const UInt64 * outSize, ICompressProgressInfo * progress)
{
  RINOK(SetOutStreamSizeResume(outSize))
  return CodeSpec(_inStream, outStream, progress);
}

}}
