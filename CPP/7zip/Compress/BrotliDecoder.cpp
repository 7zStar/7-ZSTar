// BrotliDecoder.cpp -- 7-ZSTar: new file (M6a)
//
// Ported from mcmilk/7-Zip-zstd (C) 2017 Tino Reichardt.

#include "StdAfx.h"
#include "BrotliDecoder.h"

int BrotliRead(void *arg, BROTLIMT_Buffer * in)
{
  struct BrotliStream *x = (struct BrotliStream*)arg;
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

int BrotliWrite(void *arg, BROTLIMT_Buffer * out)
{
  struct BrotliStream *x = (struct BrotliStream*)arg;
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
namespace NBROTLI {

CDecoder::CDecoder():
  _processedIn(0),
  _processedOut(0),
  _inputSize(0),
  _numThreads(NWindows::NSystem::GetNumberOfProcessors()),
  // 7-ZSTar: false unless a caller says otherwise, so every decoder built
  // for internal use -- 7zDecode.cpp's, and the tar sniff in
  // TempFileDecodedStream.cpp -- keeps content detection rather than
  // tripping the forced-raw hatch in CodeSpec().
  _forceRawStream(false),
  _needMoreInput(false)
{
  // GetNumberOfProcessors() is uncapped and sums all processor groups, while
  // BROTLIMT_createDCtx() only accepts up to BROTLIMT_THREAD_MAX.
  // BrotliHandler does call SetNumberOfThreads(), but the default has to be
  // valid on its own.
  if (_numThreads > (UInt32)BROTLIMT_THREAD_MAX)
    _numThreads = (UInt32)BROTLIMT_THREAD_MAX;
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
  const UInt32 kNumThreadsMax = BROTLIMT_THREAD_MAX;
  // Preserve the 0 that BrotliHandler passes, rather than clamping it up to
  // 1 the way the other MT decoders do -- 0 stays a distinct value here.
  // 7-ZSTar: mcmilk's wording for that used to be "always prefer .br
  // format", because 0 was what selected raw-brotli decoding. It no longer
  // selects anything: BROTLIMT_decompressDCtx() reads the stream's first
  // sixteen bytes (the whole first frame header, all fixed fields) and
  // picks raw vs. mt-container from those, promoting 0 to 1 itself when it
  // finds the container (see C/zstdmt/brotli-mt_decompress.c and
  // BrotliHandler.cpp's Extract()/GetStream()). 0 now means only "no thread
  // count was forced", i.e. a lower bound of one worker. Raw decoding is
  // selected by _forceRawStream, which this deliberately does not touch:
  // callers such as TempFileDecodedStream_SniffTar() pin a thread count on
  // decoders whose routing has already been decided, and must not change it.
  if ((int)numThreads < 1) {
    numThreads = 0;
  }
  else
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
  BROTLIMT_RdWr_t rdwr;
  size_t result;
  HRESULT res = S_OK;

  struct BrotliStream Rd;
  Rd.inStream = inStream;
  Rd.processedIn = &_processedIn;

  struct BrotliStream Wr;
  Wr.progress = progress;
  Wr.outStream = outStream;
  Wr.processedIn = &_processedIn;
  Wr.processedOut = &_processedOut;

  /* 1) setup read/write functions */
  rdwr.fn_read = ::BrotliRead;
  rdwr.fn_write = ::BrotliWrite;
  rdwr.arg_read = (void *)&Rd;
  rdwr.arg_write = (void *)&Wr;

  /* 2) create decompression context */
  // 7-ZSTar: _forceRawStream is the escape hatch ported from sebres'
  // b4e36ba7 in mcmilk/7-Zip-zstd; the C layer takes it as the pair
  // (threadsset != 0, threads == 0). BrotliHandler sets it for an explicit
  // -mmt=0 and nothing else -- see ForceRawStream() there for why the other
  // spellings official 7-Zip also reads as "mt off" are deliberately left
  // out. Every other case, forced count or not, passes threadsset == 0 and
  // leaves content detection in charge, so a thread count stays a thread
  // count here as it is everywhere else in 7-Zip.
  BROTLIMT_DCtx *ctx = BROTLIMT_createDCtx(_forceRawStream ? 0 : _numThreads,
      _forceRawStream ? 1 : 0, _inputSize);
  if (!ctx)
      return S_FALSE;

  /* 3) decompress */
  result = BROTLIMT_decompressDCtx(ctx, &rdwr);

  /* 4) free resources */
  // 7-ZSTar: free before the error check (see Lz4Decoder.cpp -- the tar
  // sniff makes E_ABORT a hot path; mcmilk's order leaked the DCtx).
  BROTLIMT_freeDCtx(ctx);
  if (BROTLIMT_isError(result)) {
    if (result == (size_t)-BROTLIMT_error_canceled)
      return E_ABORT;
    // 7-ZSTar: a stream that ends early (mcmilk #564, 3e1ea83) is S_FALSE,
    // the data-error result every caller already handles (see the comment
    // below), with NeedsMoreInput() set so the standalone handler can say
    // Unexpected end of data. mcmilk instead returns the Win32 codes
    // ERROR_HANDLE_EOF / ERROR_INVALID_DATA as HRESULTs: both are success
    // codes to SUCCEEDED(), and inside a .7z they surface as Windows' own
    // "Reached the end of the file".
    if (result == (size_t)-BROTLIMT_error_end_of_data) {
      _needMoreInput = true;
      return S_FALSE;
    }
    // 7-ZSTar: surface bad-input failures as S_FALSE -- this codebase's
    // convention for "data error" -- so the CLI reports "Data Error"
    // instead of E_FAIL's "ERROR: Unspecified error", which named nothing
    // useful when e.g. a genuine mt-container had a corrupted frame
    // header. Out-of-memory likewise keeps its own HRESULT. Every caller
    // is ready for S_FALSE: Extract() maps it to kDataError,
    // TempFileDecodedStream_SniffTar() swallows any non-S_OK as "not a
    // tar", and CTempFileDecodedStream::Init() RINOKs it out to
    // GetStream(), which then reports no sub-stream.
    if (result == (size_t)-BROTLIMT_error_memory_allocation)
      return E_OUTOFMEMORY;
    // 7-ZSTar: compression_library too -- the brotli decoder itself
    // rejected the input (mcmilk counts it as a data error, 48a3721).
    if (result == (size_t)-BROTLIMT_error_data_error ||
        result == (size_t)-BROTLIMT_error_frame_decompress ||
        result == (size_t)-BROTLIMT_error_compression_library)
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
