// ZHandler.cpp

#include "StdAfx.h"

#include "../../Common/ComTry.h"
// #include "../../Common/MyBuffer.h"

#include "../../Windows/PropVariant.h"

#include "../Common/ProgressUtils.h"
#include "../Common/RegisterArc.h"
#include "../Common/StreamUtils.h"

#include "../Compress/ZDecoder.h"

#include "Common/DummyOutStream.h"
#include "Common/TempFileDecodedStream.h" // 7-ZSTar: M6b -- NZ::Decode() has no pull mode, see GetStream()

namespace NArchive {
namespace NZ {

// 7-ZSTar: M6b -- the Z decoder (ZDecoder.h) is not a COM object: since
// 26.05 it is the free function NCompress::NZ::Decode() (before that, the
// plain class NZ::CDecoder), taking 3 args (no inSize/outSize) -- unlike
// every other decoder this project mounts kpidMainSubfile on, it
// implements neither the pull-mode trio (RewindableDecodedStream.h) nor
// even the standard 5-arg ICompressCoder interface CTempFileDecodedStream
// expects. This tiny adapter is only what's needed to bridge that gap for
// GetStream() below; the handler's own Extract() (further down) is
// upstream's and calls NZ::Decode() directly, unchanged.
Z7_CLASS_IMP_COM_1(
  CZCoderAdapter
  , ICompressCoder
)
};
Z7_COM7F_IMF(CZCoderAdapter::Code(ISequentialInStream *inStream, ISequentialOutStream *outStream,
    const UInt64 * /* inSize */, const UInt64 * /* outSize */, ICompressProgressInfo *progress))
{
  return NCompress::NZ::Decode(inStream, outStream, progress);
}


Z7_CLASS_IMP_CHandler_IInArchive_1(
  IInArchiveGetStream // 7-ZSTar: M6b -- kpidMainSubfile auto-drill-down (see GetStream())
)
  CMyComPtr<IInStream> _stream;
  UInt64 _packSize;
  // UInt64 _unpackSize;
  // bool _unpackSize_Defined;
  bool _subStreamHandedOut; // 7-ZSTar: M6b -- GetStream() single-use guard, see there

public:
  CHandler(): _subStreamHandedOut(false) {} // 7-ZSTar: M6b -- Open() below does not call Close() first, unlike every other handler in this project, so this cannot rely solely on a Close()-time reset
};

static const Byte kProps[] =
{
  kpidPackSize
};

IMP_IInArchive_Props
IMP_IInArchive_ArcProps_NO_Table

Z7_COM7F_IMF(CHandler::GetNumberOfItems(UInt32 *numItems))
{
  *numItems = 1;
  return S_OK;
}

Z7_COM7F_IMF(CHandler::GetArchiveProperty(PROPID propID, PROPVARIANT *value))
{
  NWindows::NCOM::CPropVariant prop;
  switch (propID)
  {
    case kpidPhySizeCantBeDetected: prop = true; break;
    // 7-ZSTar: M6b -- see ZstdHandler.cpp's kpidMainSubfile case for the
    // full rationale (same mechanism, generalized in M6b).
    case kpidMainSubfile:
      if (_stream)
        prop = (UInt32)0;
      break;
  }
  prop.Detach(value);
  return S_OK;
}

Z7_COM7F_IMF(CHandler::GetProperty(UInt32 /* index */, PROPID propID, PROPVARIANT *value))
{
  NWindows::NCOM::CPropVariant prop;
  switch (propID)
  {
    // case kpidSize: if (_unpackSize_Defined) prop = _unpackSize; break;
    case kpidPackSize: prop = _packSize; break;
  }
  prop.Detach(value);
  return S_OK;
}

/*
Z7_CLASS_IMP_COM_1(
  CCompressProgressInfoImp
  , ICompressProgressInfo
)
public:
  CMyComPtr<IArchiveOpenCallback> Callback;
  void Init(IArchiveOpenCallback *callback) { Callback = callback; }
};

Z7_COM7F_IMF(CCompressProgressInfoImp::SetRatioInfo(const UInt64 *inSize, const UInt64 *))
{
  if (Callback)
    return Callback->SetCompleted(NULL, inSize);
  return S_OK;
}
*/

API_FUNC_static_IsArc IsArc_Z(const Byte *p, size_t size)
{
  if (size < 3)
    return k_IsArc_Res_NEED_MORE;
  if (size > NCompress::NZ::kRecommendedCheckSize)
      size = NCompress::NZ::kRecommendedCheckSize;
  if (!NCompress::NZ::CheckStream(p, size))
    return k_IsArc_Res_NO;
  return k_IsArc_Res_YES;
}
}

Z7_COM7F_IMF(CHandler::Open(IInStream *stream,
    const UInt64 * /* maxCheckStartPosition */,
    IArchiveOpenCallback * /* openCallback */))
{
  COM_TRY_BEGIN
  {
#if 1 // 0 for debug
    Byte buffer[NCompress::NZ::kRecommendedCheckSize];
    size_t size = NCompress::NZ::kRecommendedCheckSize;
#else
    size_t size = 1 << 26; // for debug
    CByteBuffer buffer;
    buffer.Alloc(size);
#endif
    RINOK(ReadStream(stream, buffer, &size))
    // for (int y = 0; y < 10; y++)
    if (!NCompress::NZ::CheckStream(buffer, size))
      return S_FALSE;

    UInt64 endPos;
    RINOK(InStream_GetSize_SeekToEnd(stream, endPos))
    _packSize = endPos;
/*
    // bool fullCheck = false;
    // if (fullCheck)
    {
      CMyComPtr2_Create<ICompressProgressInfo, CCompressProgressInfoImp> compressProgress;
      compressProgress->Callback = openCallback;
      CMyComPtr2_Create<ISequentialOutStream, CDummyOutStream> outStream;
      outStream->SetStream(NULL);
      outStream->Init();
      // decoderSpec->SetProp(_prop);
      if (openCallback)
        RINOK(openCallback->SetTotal(NULL, &endPos));
      RINOK(InStream_SeekToBegin(stream))
      HRESULT res = NCompress::NZ::Decode(stream, outStream, openCallback ? compressProgress.Interface() : NULL);
      if (res != S_OK)
        return S_FALSE;
      // _packSize = decoderSpec->PackSize;
      _unpackSize = outStream->GetSize();
      _unpackSize_Defined = true;
    }
*/
    _stream = stream;
    _subStreamHandedOut = false; // 7-ZSTar: M6b -- re-arm GetStream() guard (see CHandler() ctor comment)
  }
  return S_OK;
  COM_TRY_END
}

Z7_COM7F_IMF(CHandler::Close())
{
  _packSize = 0;
  // _unpackSize_Defined = false;
  _subStreamHandedOut = false; // 7-ZSTar: M6b -- re-arm GetStream() guard
  _stream.Release();
  return S_OK;
}


// 7-ZSTar: M6b -- see ZstdHandler.cpp's GetStream() for the full rationale;
// this is the same mechanism mounted on compress/.Z, via
// CTempFileDecodedStream (TempFileDecodedStream.h) instead of
// CRewindableDecodedStream: NZ::Decode() has no pull mode at all (see
// CZCoderAdapter's comment above), so this decodes the whole stream to a
// temp file synchronously right here, then hands back a plain seekable
// view of it. index is always 0 -- GetNumberOfItems() always reports
// exactly one item.
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
  // NZ::Decode() has no thread-count concept at all (see CZCoderAdapter's
  // comment above) -- TempFileDecodedStream_SniffTar()'s ICompressSetCoderMt
  // QueryInterface simply fails for it and is skipped, harmlessly.
  bool isTar = false;
  RINOK(InStream_SeekToBegin(_stream))
  {
    CMyComPtr2_Create<ICompressCoder, CZCoderAdapter> sniffAdapter;
    RINOK(TempFileDecodedStream_SniffTar(sniffAdapter.Interface(), _stream, isTar))
  }
  // Unconditional, regardless of isTar -- see Lz4Handler.cpp's twin comment
  // (this file's own Extract() happens to already reseek _stream itself
  // before decoding, so this specific handler may not strictly need it, but
  // GetStream() leaving a shared stream's position wherever it last touched
  // it is the wrong contract to rely on regardless -- keep all five
  // handlers in this fix consistent and defend the invariant here too).
  RINOK(InStream_SeekToBegin(_stream))
  if (!isTar)
    return S_FALSE;

  CMyComPtr2_Create<ICompressCoder, CZCoderAdapter> adapter;
  CMyComPtr2<IInStream, CTempFileDecodedStream> spec;
  spec.Create_if_Empty();
  RINOK(spec->Init(adapter.Interface(), _stream))

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
  RINOK(extractCallback->SetTotal(_packSize))
  
  int opRes;
  {
    CMyComPtr<ISequentialOutStream> realOutStream;
    const Int32 askMode = testMode ?
        NExtract::NAskMode::kTest :
        NExtract::NAskMode::kExtract;
    RINOK(extractCallback->GetStream(0, &realOutStream, askMode))
    if (!testMode && !realOutStream)
      return S_OK;
    RINOK(extractCallback->PrepareOperation(askMode))
    /*
    // NZ::Decode() supports (outStream == NULL)
    CMyComPtr2_Create<ISequentialOutStream, CDummyOutStream> outStream;
    outStream->SetStream(realOutStream);
    outStream->Init();
    // realOutStream.Release();
    */
    CMyComPtr2_Create<ICompressProgressInfo, CLocalProgress> lps;
    lps->Init(extractCallback, true);
    RINOK(InStream_SeekToBegin(_stream))
    const HRESULT hres = NCompress::NZ::Decode(_stream, realOutStream, lps);
    if (hres == S_FALSE)
      opRes = NExtract::NOperationResult::kDataError;
    else
    {
      RINOK(hres)
      opRes = NExtract::NOperationResult::kOK;
    }
    // _unpackSize = outStream->GetSize();
    // _unpackSize_Defined = true;
  }
  return extractCallback->SetOperationResult(opRes);
  COM_TRY_END
}

static const Byte k_Signature[] = { 0x1F, 0x9D };

REGISTER_ARC_I(
  "Z", "z taz", "* .tar", 5,
  k_Signature,
  0,
  0,
  IsArc_Z)

}}
