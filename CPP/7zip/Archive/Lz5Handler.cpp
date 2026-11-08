// Lz5Handler.cpp -- 7-ZSTar: new file (M6a)
//
// Ported from mcmilk/7-Zip-zstd's Lz5Handler.cpp; see Lz4Handler.cpp's
// header comment (same standalone-format shape, AddExt "* .tar" pattern,
// one-step tar.lz5 extraction added in M6b).

#include "StdAfx.h"

#include "../../../C/CpuArch.h"
#include "../../Common/ComTry.h"
#include "../../Common/Defs.h"

#include "../Common/ProgressUtils.h"
#include "../Common/RegisterArc.h"
#include "../Common/StreamUtils.h"

#include "../Compress/Lz5Decoder.h"
#include "../Compress/Lz5Encoder.h"
#include "../Compress/CopyCoder.h"

#include "Common/DummyOutStream.h"
#include "Common/HandlerOut.h"
#include "Common/TempFileDecodedStream.h" // 7-ZSTar: M6b -- CDecoder has no pull mode, see GetStream()

using namespace NWindows;

namespace NArchive {
namespace NLZ5 {

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

static const unsigned kSignatureCheckSize = 4;

API_FUNC_static_IsArc IsArc_lz5(const Byte *p, size_t size)
{
  if (size < 4)
    return k_IsArc_Res_NEED_MORE;

  UInt32 magic = GetUi32(p);

  // skippable frames
  if (magic >= 0x184D2A50 && magic <= 0x184D2A5F) {
    if (size < 16)
      return k_IsArc_Res_NEED_MORE;
    magic = GetUi32(p+12);
  }

  // Lz5 Magic
  if (magic == 0x184D2205)
    return k_IsArc_Res_YES;

  return k_IsArc_Res_NO;
}
}

Z7_COM7F_IMF(CHandler::Open(IInStream *stream, const UInt64 *, IArchiveOpenCallback *))
{
  COM_TRY_BEGIN
  Close();
  {
    Byte buf[kSignatureCheckSize];
    RINOK(ReadStream_FALSE(stream, buf, kSignatureCheckSize));
    if (IsArc_lz5(buf, kSignatureCheckSize) == k_IsArc_Res_NO)
      return S_FALSE;
    _isArc = true;
    _stream = stream;
    _seqStream = stream;
    RINOK(_stream->Seek(0, STREAM_SEEK_SET, NULL));
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


// 7-ZSTar: M6b -- see ZstdHandler.cpp's GetStream() for the full rationale;
// this is the same mechanism mounted on lz5, via CTempFileDecodedStream
// (TempFileDecodedStream.h) instead of CRewindableDecodedStream: lz5's
// CDecoder has no pull mode (its CodeSpec() drives an internal zstdmt
// worker-thread pool via read/write callbacks, not ISequentialInStream::
// Read() -- see Lz5Decoder.h). No explicit thread-count setup here,
// matching Extract()'s own decoder construction (relies on the decoder's
// constructor default, same as Extract() does). index is always 0 --
// GetNumberOfItems() always reports exactly one item.
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
  // TempFileDecodedStream.h's TempFileDecodedStream_SniffTar() comment).
  bool isTar = false;
  RINOK(InStream_SeekToBegin(_stream))
  {
    CMyComPtr2_Create<ICompressCoder, NCompress::NLZ5::CDecoder> sniffDecoder;
    RINOK(TempFileDecodedStream_SniffTar(sniffDecoder.Interface(), _stream, isTar))
  }
  // Unconditional, regardless of isTar -- see Lz4Handler.cpp's twin comment:
  // _stream is shared with Extract()'s _seqStream, so a return without first
  // rewinding here would leave that shared position corrupted for it.
  RINOK(InStream_SeekToBegin(_stream))
  if (!isTar)
    return S_FALSE;

  CMyComPtr2_Create<ICompressCoder, NCompress::NLZ5::CDecoder> decoder;

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

  NCompress::NLZ5::CDecoder *decoderSpec = new NCompress::NLZ5::CDecoder;
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
  NCompress::NLZ5::CEncoder *encoderSpec = new NCompress::NLZ5::CEncoder;
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

// 7-ZSTar: see Lz4Handler.cpp's twin fix for the full rationale. Two
// defects: the value was the *string literal* "0x184D2205" rather than the
// LZ5 frame magic (LZ5FMT_MAGICNUMBER, C/zstdmt/lz5-mt.h), and a single
// signature cannot describe this format anyway -- lz5-mt_compress.c has no
// single-threaded branch, so every chunk is always wrapped in zstdmt's
// skippable frame, and CEncoder defaults to all cores. The skippable magic
// is therefore what LZ5 archives *normally* start with; the bare frame
// magic only shows up inside that wrapper (offset 12) or in foreign output.
// Both are registered via kMultiSignature ("length byte + bytes").
// The signature does not decide whether a file opens: this handler
// registers an IsArcFunc, so the content-detection loop calls IsArc_lz5()
// and skips the signature comparison entirely (OpenArchive.cpp:2175-2185).
// It is not wholly inert either -- the embedded-archive Parser scan builds
// a candidate-offset hash from it; see Lz4Handler.cpp's twin comment for
// that path and why it still cannot cause a false-positive open.
// File-byte order, matching IsArc_lz5's GetUi32(p) read.
static const Byte k_Signature[] = {
    4, 0x05, 0x22, 0x4D, 0x18,    // LZ5FMT_MAGICNUMBER     0x184D2205
    4, 0x50, 0x2A, 0x4D, 0x18 };  // LZ5FMT_MAGIC_SKIPPABLE 0x184D2A50

REGISTER_ARC_IO(
  "lz5", "lz5 tlz5", "* .tar", 0x10,
  k_Signature,
  0,
  NArcInfoFlags::kKeepName | NArcInfoFlags::kMultiSignature,
  0,
  IsArc_lz5)

}}
