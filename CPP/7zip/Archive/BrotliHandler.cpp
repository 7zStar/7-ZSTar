// BrotliHandler.cpp -- 7-ZSTar: new file (M6a)
//
// Ported from mcmilk/7-Zip-zstd's BrotliHandler.cpp. Unlike lz4/lz5/lizard/
// zstd, brotli has no reliable fixed signature (see IsArc_Brotli's own
// comment below, carried over from mcmilk unchanged) -- REGISTER_ARC_R
// (not REGISTER_ARC_IO) + kPureStartOpen|kByExtOnlyOpen is mcmilk's own
// established way of keeping that heuristic detection from mis-firing on
// arbitrary files during format auto-probing; kept as-is.
//
// One deliberate deviation from mcmilk's own file: AddExt is "* * .tar"
// here (nested-tar naming for the "tbr" extension, matching lz4/lz5/lizard/
// zstd's own AddExt pattern) where mcmilk's upstream file has no AddExt at
// all (NULL/0). One-step tar.br extraction (kpidMainSubfile) is still M6b
// like the other three; this only affects naming/recognition, requested
// explicitly for parity across all five M6a codecs (see the M6a task specs).

#include "StdAfx.h"

#include "../../../C/CpuArch.h"
#include "../../../C/brotli/decode.h"

#include "../../Common/ComTry.h"
#include "../../Common/Defs.h"

#include "../Common/ProgressUtils.h"
#include "../Common/RegisterArc.h"
#include "../Common/StreamUtils.h"

#include "../Compress/BrotliDecoder.h"
#include "../Compress/BrotliEncoder.h"
#include "../Compress/CopyCoder.h"

#include "Common/DummyOutStream.h"
#include "Common/HandlerOut.h"
#include "Common/TempFileDecodedStream.h" // 7-ZSTar: M6b -- CDecoder has no pull mode, see GetStream()

using namespace NWindows;

namespace NArchive {
namespace NBROTLI {

Z7_CLASS_IMP_CHandler_IInArchive_4(
  IArchiveOpenSeq,
  IOutArchive,
  ISetProperties,
  IInArchiveGetStream // 7-ZSTar: M6b -- kpidMainSubfile auto-drill-down (see GetStream())
)
  CMyComPtr<IInStream> _stream;
  CMyComPtr<ISequentialInStream> _seqStream;

  bool _isArc;
  bool _dataAfterEnd;
  bool _needMoreInput;

  bool _packSize_Defined;
  bool _unpackSize_Defined;
  bool _subStreamHandedOut; // 7-ZSTar: M6b -- GetStream() single-use guard, see there

  UInt64 _packSize;
  UInt64 _unpackSize;

  CSingleMethodProps _props;
};

static const Byte kProps[] =
{
  kpidSize,
  kpidPackSize
};

static const Byte kArcProps[] =
{
  kpidNumStreams,
  kpidNumBlocks
};

IMP_IInArchive_Props
IMP_IInArchive_ArcProps

Z7_COM7F_IMF(CHandler::GetArchiveProperty(PROPID propID, PROPVARIANT *value))
{
  NCOM::CPropVariant prop;
  switch (propID)
  {
    // 7-ZSTar: M6b -- see ZstdHandler.cpp's kpidMainSubfile case for the
    // full rationale (same mechanism, generalized in M6b).
    case kpidMainSubfile:
      if (_stream)
        prop = (UInt32)0;
      break;
    default: break;
  }
  prop.Detach(value);
  return S_OK;
}

Z7_COM7F_IMF(CHandler::GetNumberOfItems(UInt32 *numItems))
{
  *numItems = 1;
  return S_OK;
}

Z7_COM7F_IMF(CHandler::GetProperty(UInt32 /* index */, PROPID propID, PROPVARIANT *value))
{
  NCOM::CPropVariant prop;
  switch (propID)
  {
    case kpidPackSize: if (_packSize_Defined) prop = _packSize; break;
    case kpidSize: if (_unpackSize_Defined) prop = _unpackSize; break;
  }
  prop.Detach(value);
  return S_OK;
}

// Notes about Brotli .br detection
// - raw Brotli (RFC 7932) has no signature
// - framed Brotli (RFC 9841) has sig but isn't well deployed
// - variant 1: detect brotli by it's (mostly not used) signature
// - variant 2: try to decompress raw brotli stream
// - warning: most brotli compressed data is raw format
// /TR 28.12.2025
API_FUNC_static_IsArc IsArc_Brotli(const Byte *p, size_t size)
{
  if (size < 5)
    return k_IsArc_Res_NEED_MORE;

  // Brotli - https://github.com/madler/brotli/blob/master/br-format-v3.txt
  if (p[0] == 0xCE && p[1] == 0xB2 && p[2] == 0xCF && p[3] == 0x81)
    return k_IsArc_Res_YES;

  // Brotli (RFC 9841)
  if (p[0] == 0x91 && p[1] == 0x19 && p[2] == 0x62 && p[3] == 0x66)
    return k_IsArc_Res_YES;

  // try to detect raw brotli stream
  BrotliDecoderState *st = BrotliDecoderCreateInstance(NULL, NULL, NULL);
  if (!st)
    return k_IsArc_Res_NO;

  const uint8_t *next_in = p;
  size_t avail_in = size;
  uint8_t out[256];
  uint8_t *x = out;
  size_t avail_out = sizeof(out);
  BrotliDecoderResult r;
  r = BrotliDecoderDecompressStream(st, &avail_in, &next_in, &avail_out, &x, NULL);
  BrotliDecoderDestroyInstance(st);
  if (r == BROTLI_DECODER_RESULT_ERROR)
    return k_IsArc_Res_NO;

  // when we get here, the begin of some brotli stream was detected:
  // - BROTLI_DECODER_RESULT_SUCCESS
  // - BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT
  // - BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT
  return k_IsArc_Res_YES;
}
}

Z7_COM7F_IMF(CHandler::Open(IInStream *stream, const UInt64 *, IArchiveOpenCallback *))
{
  COM_TRY_BEGIN
  Close();
  {
    _isArc = true;
    _stream = stream;
    _seqStream = stream;
  }
  return S_OK;
  COM_TRY_END
}

Z7_COM7F_IMF(CHandler::OpenSeq(ISequentialInStream *stream))
{
  Close();
  _isArc = true;
  _seqStream = stream;
  return S_OK;
}

Z7_COM7F_IMF(CHandler::Close())
{
  _isArc = false;
  _dataAfterEnd = false;
  _needMoreInput = false;

  _packSize_Defined = false;
  _unpackSize_Defined = false;
  _subStreamHandedOut = false; // 7-ZSTar: M6b -- re-arm GetStream() guard

  _packSize = 0;

  _seqStream.Release();
  _stream.Release();
  return S_OK;
}


// 7-ZSTar: did the user ask for this file to be read as plain brotli?
//
// This is the escape hatch out of container detection: it decodes the file
// as raw brotli whatever its first bytes look like. Detection replaced the
// old threads==0 selector, so without it a raw stream that ever collided
// with the brotli-mt container header would be unreadable by any means -
// ~2^-80 with the 16-byte probe, but raw brotli has no signature, so content
// detection cannot reach zero by construction. Ported from sebres' b4e36ba7
// in mcmilk/7-Zip-zstd; see CodeSpec() in BrotliDecoder.cpp.
//
// Deliberately just `-mmt=0`, and NOT the other spellings official 7-Zip
// also treats as "mt off". ParseMtProp2() maps -mmt=off and -mmt- onto a
// forced count of 1, which makes them indistinguishable from -mmt=1 by the
// time they reach here - so honouring them would stop `-mmt=1` from reading
// 7-Zip ZS's mt-brotli containers, which is a far likelier thing for someone
// to do (capping CPU while extracting) than hitting the collision this
// guards against. A forced count of 1 or more is therefore left as what it
// is everywhere else in 7-Zip: a worker count, not a format selector. That
// is also the second deliberate divergence from sebres, whose fork treats
// -mmt as brotli's format selector to begin with.
//
// Every decoder this handler builds for one open has to be told the same
// answer, the tar sniff below included: they all read the same file, so one
// of them honouring the hatch while another ignores it would drill into a
// file it then could not extract.
static bool ForceRawStream(const CSingleMethodProps &props)
{
  return props._numThreads_WasForced && props._numThreads == 0;
}


// 7-ZSTar: M6b -- see ZstdHandler.cpp's GetStream() for the full rationale;
// this is the same mechanism mounted on brotli, via CTempFileDecodedStream
// (TempFileDecodedStream.h) instead of CRewindableDecodedStream: brotli's
// CDecoder has no pull mode (its CodeSpec() drives an internal zstdmt
// worker-thread pool via read/write callbacks, not ISequentialInStream::
// Read() -- see BrotliDecoder.h). SetNumberOfThreads() mirrors Extract()'s
// own setup (0 unless the user explicitly forced a thread count via -mmt=N
// when the archive was opened); since the container-detection fix that
// value is only a hint, because brotli-mt_decompress.c now picks raw vs.
// framed from the stream's own first sixteen bytes (the whole first frame
// header). index is always 0 -- GetNumberOfItems() always reports exactly
// one item.
//
// This drill-down was dead code for brotli until that fix: the sniff below
// forces the throwaway decoder to one thread, while the old
// BROTLIMT_decompressDCtx() entered the raw-brotli path *only* at
// threads == 0. Every .tar.br we can produce is raw brotli (both writers
// force 0 threads: UpdateArchive below, and CreateTarChainCoder_Brotli in
// BrotliEncoder.cpp:210), so the sniff always failed with a data error,
// isTar stayed false, and `7z l foo.tar.br` listed one "foo.tar" item
// instead of drilling in -- while the other nine mounted formats drilled
// in correctly. Measured on the pre-fix build, then again after.
Z7_COM7F_IMF(CHandler::GetStream(UInt32 index, ISequentialInStream **stream))
{
  COM_TRY_BEGIN

  *stream = NULL;

  if (index != 0)
    return E_INVALIDARG;
  if (!_stream)
    return S_FALSE;
  if (_subStreamHandedOut)
    return S_FALSE;

  // 7-ZSTar: M6b fix (independent review Finding 2) -- sniff first, with a
  // throwaway decoder, *before* paying for a full decode-to-temp-file (see
  // TempFileDecodedStream.h's comment on that function). The thread count is
  // not worth mirroring here (TempFileDecodedStream_SniffTar() pins it to 1
  // internally anyway), but the forced-raw hatch is: it decides which
  // *format* this sniff reads, so leaving it out would let the sniff and the
  // real decoder below disagree about the same file.
  bool isTar = false;
  RINOK(InStream_SeekToBegin(_stream))
  {
    CMyComPtr2_Create<ICompressCoder, NCompress::NBROTLI::CDecoder> sniffDecoder;
    sniffDecoder->_forceRawStream = ForceRawStream(_props);
    RINOK(TempFileDecodedStream_SniffTar(sniffDecoder.Interface(), _stream, isTar))
  }
  // Unconditional, regardless of isTar -- see Lz4Handler.cpp's twin comment:
  // _stream is shared with Extract()'s _seqStream, so a return without first
  // rewinding here would leave that shared position corrupted for it.
  RINOK(InStream_SeekToBegin(_stream))
  if (!isTar)
    return S_FALSE;

  CMyComPtr2_Create<ICompressCoder, NCompress::NBROTLI::CDecoder> decoder;
  decoder->_forceRawStream = ForceRawStream(_props);
  decoder->SetNumberOfThreads(!_props._numThreads_WasForced ? 0 : _props._numThreads);

  CMyComPtr2<IInStream, CTempFileDecodedStream> spec;
  spec.Create_if_Empty();
  RINOK(spec->Init(decoder.Interface(), _stream))

  *stream = spec.Detach();
  _subStreamHandedOut = true;
  return S_OK;

  COM_TRY_END
}

Z7_COM7F_IMF(CHandler::Extract(const UInt32 *indices, UInt32 numItems,
    Int32 testMode, IArchiveExtractCallback *extractCallback))
{
  COM_TRY_BEGIN
  if (numItems == 0)
    return S_OK;
  if (numItems != (UInt32)(Int32)-1 && (numItems != 1 || indices[0] != 0))
    return E_INVALIDARG;

  if (_packSize_Defined)
    extractCallback->SetTotal(_packSize);

  CMyComPtr<ISequentialOutStream> realOutStream;
  Int32 askMode = testMode ?
      NExtract::NAskMode::kTest :
      NExtract::NAskMode::kExtract;
  RINOK(extractCallback->GetStream(0, &realOutStream, askMode));
  if (!testMode && !realOutStream)
    return S_OK;

  extractCallback->PrepareOperation(askMode);

  Int32 opRes;

  {

  NCompress::NBROTLI::CDecoder *decoderSpec = new NCompress::NBROTLI::CDecoder;
  /*
   * Pass 0 here unless the user explicitly forced a thread count via -mmt.
   * This is only a lower bound / hint: BROTLIMT_decompressDCtx() (see
   * C/zstdmt/brotli-mt_decompress.c) always peeks the stream's own content
   * for the brotli-mt container's whole 16-byte first frame header (magic
   * plus every fixed field) and decides raw-st vs. framed-mt decoding from
   * that, promoting threads from 0 to 1 by itself if the container is
   * present - regardless of what is passed here. So a file produced with
   * -mmt can still be read correctly even when -mmt is not given on this
   * extract/test invocation, and a raw stream that merely opens with the
   * 4 magic bytes still decodes as raw. Forcing a higher count via -mmt
   * is still honored when the container is present.
   *
   * The one thing that does override detection is an explicit -mmt=0,
   * which forces the raw decoder. That is the escape hatch for the residual
   * chance of a raw stream colliding with the container header; it travels
   * separately from the thread count because an unforced 0 and a forced one
   * mean opposite things here. See ForceRawStream() above and CodeSpec() in
   * BrotliDecoder.cpp.
   */
  decoderSpec->_forceRawStream = ForceRawStream(_props);
  decoderSpec->SetNumberOfThreads(!_props._numThreads_WasForced ? 0 : _props._numThreads);
  CMyComPtr<ICompressCoder> decoder = decoderSpec;
  // 7-ZSTar: rewind first. _seqStream is the same object as _stream, and
  // GetStream() leaves it at EOF when its decode-to-temp-file fails (a
  // .tar.* cut off after its first compressed unit). The single-file extract
  // 7-Zip then falls back to used to start there, read nothing and
  // report Data Error. This also makes a second Extract() on the same
  // open archive start from the beginning. Upstream's Z, Xz and Bz2
  // handlers rewind before every Extract() of an archive opened from an
  // IInStream as well (Xz and Bz2 through _needSeekToStart, which their
  // Open() sets).
  if (_stream)
    RINOK(InStream_SeekToBegin(_stream))
  decoderSpec->SetInStream(_seqStream);

  CDummyOutStream *outStreamSpec = new CDummyOutStream;
  CMyComPtr<ISequentialOutStream> outStream(outStreamSpec);
  outStreamSpec->SetStream(realOutStream);
  outStreamSpec->Init();

  realOutStream.Release();

  CLocalProgress *lps = new CLocalProgress;
  CMyComPtr<ICompressProgressInfo> progress = lps;
  lps->Init(extractCallback, true);

  UInt64 packSize = 0;
  UInt64 unpackedSize = 0;

  HRESULT result = S_OK;

  for (;;)
  {
    lps->InSize = packSize;
    lps->OutSize = unpackedSize;

    RINOK(lps->SetCur());
    result = decoderSpec->CodeResume(outStream, &unpackedSize, progress);
    UInt64 streamSize = decoderSpec->GetInputProcessedSize();

    if (result != S_FALSE && result != S_OK)
      return result;

    if (unpackedSize == 0)
      break;

    if (streamSize == packSize)
    {
      // no new bytes in input stream, So it's good end of archive.
      result = S_OK;
      break;
    }

    if (packSize > streamSize)
      return E_FAIL;

    if (result != S_OK)
      break;
  }

  // 7-ZSTar: the decoder flags a stream that ended early (#564, see its
  // NeedsMoreInput()). Until it did, nothing set _needMoreInput and the
  // kUnexpectedEnd branch below could not be taken.
  _needMoreInput = decoderSpec->NeedsMoreInput();

  if (!_isArc)
    opRes = NExtract::NOperationResult::kIsNotArc;
  else if (_needMoreInput)
    opRes = NExtract::NOperationResult::kUnexpectedEnd;
  else if (_dataAfterEnd)
    opRes = NExtract::NOperationResult::kDataAfterEnd;
  else if (result == S_FALSE)
    opRes = NExtract::NOperationResult::kDataError;
  else if (result == S_OK) {
    _unpackSize = outStreamSpec->GetSize();
    _unpackSize_Defined = true;
    opRes = NExtract::NOperationResult::kOK;
  } else
    return result;

  // 7-ZSTar: release only now, after outStreamSpec->GetSize() above:
  // outStream holds the only reference, so releasing it first left that
  // call reading a freed object (mcmilk/7-Zip-zstd bb11f57, gh-562).
  decoderSpec->ReleaseInStream();
  outStream.Release();

  }

  return extractCallback->SetOperationResult(opRes);

  COM_TRY_END
}

static HRESULT UpdateArchive(
    UInt64 unpackSize,
    ISequentialOutStream *outStream,
    const CProps &props,
    IArchiveUpdateCallback *updateCallback)
{
  RINOK(updateCallback->SetTotal(unpackSize));
  CMyComPtr<ISequentialInStream> fileInStream;
  RINOK(updateCallback->GetStream(0, &fileInStream));
  CLocalProgress *localProgressSpec = new CLocalProgress;
  CMyComPtr<ICompressProgressInfo> localProgress = localProgressSpec;
  localProgressSpec->Init(updateCallback, true);
  NCompress::NBROTLI::CEncoder *encoderSpec = new NCompress::NBROTLI::CEncoder;
  encoderSpec->unpackSize = unpackSize;
  encoderSpec->SetNumberOfThreads(0); /* .br - single threaded processing (without header/mt-frames) */
  CMyComPtr<ICompressCoder> encoder = encoderSpec;
  RINOK(props.SetCoderProps(encoderSpec, NULL));
  RINOK(encoder->Code(fileInStream, outStream, NULL, NULL, localProgress));
  return updateCallback->SetOperationResult(NArchive::NUpdate::NOperationResult::kOK);
}

Z7_COM7F_IMF(CHandler::GetFileTimeType(UInt32 *type))
{
  *type = NFileTimeType::kUnix;
  return S_OK;
}

Z7_COM7F_IMF(CHandler::UpdateItems(ISequentialOutStream *outStream, UInt32 numItems,
    IArchiveUpdateCallback *updateCallback))
{
  COM_TRY_BEGIN

  if (numItems != 1)
    return E_INVALIDARG;

  Int32 newData, newProps;
  UInt32 indexInArchive;
  if (!updateCallback)
    return E_FAIL;
  RINOK(updateCallback->GetUpdateItemInfo(0, &newData, &newProps, &indexInArchive));

  if ((newProps))
  {
    {
      NCOM::CPropVariant prop;
      RINOK(updateCallback->GetProperty(0, kpidIsDir, &prop));
      if (prop.vt != VT_EMPTY)
        if (prop.vt != VT_BOOL || prop.boolVal != VARIANT_FALSE)
          return E_INVALIDARG;
    }
  }

  if ((newData))
  {
    UInt64 size;
    {
      NCOM::CPropVariant prop;
      RINOK(updateCallback->GetProperty(0, kpidSize, &prop));
      if (prop.vt != VT_UI8)
        return E_INVALIDARG;
      size = prop.uhVal.QuadPart;
    }
    return UpdateArchive(size, outStream, _props, updateCallback);
  }

  if (indexInArchive != 0)
    return E_INVALIDARG;

  CLocalProgress *lps = new CLocalProgress;
  CMyComPtr<ICompressProgressInfo> progress = lps;
  lps->Init(updateCallback, true);

  CMyComPtr<IArchiveUpdateCallbackFile> opCallback;
  updateCallback->QueryInterface(IID_IArchiveUpdateCallbackFile, (void **)&opCallback);
  if (opCallback)
  {
    RINOK(opCallback->ReportOperation(
        NEventIndexType::kInArcIndex, 0,
        NUpdateNotifyOp::kReplicate))
  }

  if (_stream)
    RINOK(_stream->Seek(0, STREAM_SEEK_SET, NULL));

  return NCompress::CopyStream(_stream, outStream, progress);

  COM_TRY_END
}

Z7_COM7F_IMF(CHandler::SetProperties(const wchar_t * const *names, const PROPVARIANT *values, UInt32 numProps))
{
  return _props.SetProperties(names, values, numProps);
}

IMP_CreateArcIn
IMP_CreateArcOut
REGISTER_ARC_R(
  "brotli", "br brotli tbr", "* * .tar", 0x1F,
  0, NULL,
  0,
  NArcInfoFlags::kKeepName | NArcInfoFlags::kPureStartOpen | NArcInfoFlags::kByExtOnlyOpen,
  0,
  CreateArc, CreateArcOut,
  IsArc_Brotli)
}}
