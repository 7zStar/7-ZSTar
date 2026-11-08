// LzmaHandler.cpp

#include "StdAfx.h"

#include "../../../C/CpuArch.h"

#include "../../Common/ComTry.h"
#include "../../Common/IntToString.h"

#include "../../Windows/PropVariant.h"

#include "../Common/FilterCoder.h"
#include "../Common/ProgressUtils.h"
#include "../Common/RegisterArc.h"
#include "../Common/StreamUtils.h"

#include "../Compress/BcjCoder.h"
#include "../Compress/LzmaDecoder.h"

#include "Common/DummyOutStream.h"
#include "Common/RewindableDecodedStream.h" // 7-ZSTar: M6b -- kpidMainSubfile auto-drill-down (see GetStream())

using namespace NWindows;

namespace NArchive {
namespace NLzma {

static bool CheckDicSize(const Byte *p)
{
  UInt32 dicSize = GetUi32(p);
  if (dicSize == 1)
    return true;
  for (unsigned i = 0; i <= 30; i++)
    if (dicSize == ((UInt32)2 << i) || dicSize == ((UInt32)3 << i))
      return true;
  return (dicSize == 0xFFFFFFFF);
}

static const Byte kProps[] =
{
  kpidSize,
  kpidPackSize,
  kpidMethod
};

static const Byte kArcProps[] =
{
  kpidNumStreams,
  kpidMethod
};

struct CHeader
{
  UInt64 Size;
  Byte FilterID;
  Byte LzmaProps[5];

  Byte GetProp() const { return LzmaProps[0]; }
  UInt32 GetDicSize() const { return GetUi32(LzmaProps + 1); }
  bool HasSize() const { return (Size != (UInt64)(Int64)-1); }
  bool Parse(const Byte *buf, bool isThereFilter);
};

bool CHeader::Parse(const Byte *buf, bool isThereFilter)
{
  FilterID = 0;
  if (isThereFilter)
    FilterID = buf[0];
  const Byte *sig = buf + (isThereFilter ? 1 : 0);
  for (int i = 0; i < 5; i++)
    LzmaProps[i] = sig[i];
  Size = GetUi64(sig + 5);
  return
    LzmaProps[0] < 5 * 5 * 9 &&
    FilterID < 2 &&
    (!HasSize() || Size < ((UInt64)1 << 56))
    && CheckDicSize(LzmaProps + 1);
}

class CDecoder Z7_final
{
  CMyComPtr<ISequentialOutStream> _bcjStream;
  CFilterCoder *_filterCoder;
public:
  CMyComPtr2<ICompressCoder, NCompress::NLzma::CDecoder> _lzmaDecoder;

  ~CDecoder();
  HRESULT Create(bool filtered, ISequentialInStream *inStream);

  HRESULT Code(const CHeader &header, ISequentialOutStream *outStream, ICompressProgressInfo *progress);

  UInt64 GetInputProcessedSize() const { return _lzmaDecoder->GetInputProcessedSize(); }

  void ReleaseInStream() { if (_lzmaDecoder) _lzmaDecoder->ReleaseInStream(); }

  HRESULT ReadInput(Byte *data, UInt32 size, UInt32 *processedSize)
    { return _lzmaDecoder->ReadFromInputStream(data, size, processedSize); }
};

HRESULT CDecoder::Create(bool filteredMode, ISequentialInStream *inStream)
{
  _lzmaDecoder.Create_if_Empty();
  _lzmaDecoder->FinishStream = true;

  if (filteredMode)
  {
    if (!_bcjStream)
    {
      _filterCoder = new CFilterCoder(false);
      CMyComPtr<ICompressCoder> coder = _filterCoder;
      _filterCoder->Filter = new NCompress::NBcj::CCoder2(z7_BranchConvSt_X86_Dec);
      _bcjStream = _filterCoder;
    }
  }

  return _lzmaDecoder->SetInStream(inStream);
}

CDecoder::~CDecoder()
{
  ReleaseInStream();
}

HRESULT CDecoder::Code(const CHeader &header, ISequentialOutStream *outStream,
    ICompressProgressInfo *progress)
{
  if (header.FilterID > 1)
    return E_NOTIMPL;

  RINOK(_lzmaDecoder->SetDecoderProperties2(header.LzmaProps, 5))

  bool filteredMode = (header.FilterID == 1);

  if (filteredMode)
  {
    RINOK(_filterCoder->SetOutStream(outStream))
    outStream = _bcjStream;
    RINOK(_filterCoder->SetOutStreamSize(NULL))
  }

  const UInt64 *Size = header.HasSize() ? &header.Size : NULL;
  HRESULT res = _lzmaDecoder->CodeResume(outStream, Size, progress);

  if (filteredMode)
  {
    {
      HRESULT res2 = _filterCoder->OutStreamFinish();
      if (res == S_OK)
        res = res2;
    }
    HRESULT res2 = _filterCoder->ReleaseOutStream();
    if (res == S_OK)
      res = res2;
  }
  
  RINOK(res)

  if (header.HasSize())
    if (_lzmaDecoder->GetOutputProcessedSize() != header.Size)
      return S_FALSE;

  return S_OK;
}


Z7_CLASS_IMP_CHandler_IInArchive_2(
  IArchiveOpenSeq,
  IInArchiveGetStream // 7-ZSTar: M6b -- kpidMainSubfile auto-drill-down (see GetStream()); plain "lzma" only, never lzma86
)
  bool _lzma86;
  bool _isArc;
  bool _needSeekToStart;
  bool _dataAfterEnd;
  bool _needMoreInput;
  bool _unsupported;
  bool _dataError;

  bool _packSize_Defined;
  bool _unpackSize_Defined;
  bool _numStreams_Defined;
  bool _subStreamHandedOut; // 7-ZSTar: M6b -- GetStream() single-use guard, see there

  CHeader _header;
  CMyComPtr<IInStream> _stream;
  CMyComPtr<ISequentialInStream> _seqStream;
  
  UInt64 _packSize;
  UInt64 _unpackSize;
  UInt64 _numStreams;

  void GetMethod(NCOM::CPropVariant &prop) const;

  unsigned GetHeaderSize() const { return 5 + 8 + (_lzma86 ? 1 : 0); }
public:
  CHandler(bool lzma86) { _lzma86 = lzma86; }
};

IMP_IInArchive_Props
IMP_IInArchive_ArcProps

Z7_COM7F_IMF(CHandler::GetArchiveProperty(PROPID propID, PROPVARIANT *value))
{
  NCOM::CPropVariant prop;
  switch (propID)
  {
    case kpidPhySize: if (_packSize_Defined) prop = _packSize; break;
    case kpidNumStreams: if (_numStreams_Defined) prop = _numStreams; break;
    case kpidUnpackSize: if (_unpackSize_Defined) prop = _unpackSize; break;
    case kpidMethod: GetMethod(prop); break;
    // 7-ZSTar: M6b -- see ZstdHandler.cpp's kpidMainSubfile case for the
    // full rationale (same mechanism, generalized in M6b). Plain "lzma"
    // only (_lzma86 false): the lzma86 variant is a 7-Zip-specific
    // BCJ-filtered extension of the alone format that GNU tar / suffix.c
    // never produces, so it is intentionally left unmounted -- see
    // GetStream() for the matching guard.
    case kpidMainSubfile:
      if (_stream && !_lzma86)
        prop = (UInt32)0;
      break;
    case kpidErrorFlags:
    {
      UInt32 v = 0;
      if (!_isArc) v |= kpv_ErrorFlags_IsNotArc;
      if (_needMoreInput) v |= kpv_ErrorFlags_UnexpectedEnd;
      if (_dataAfterEnd) v |= kpv_ErrorFlags_DataAfterEnd;
      if (_unsupported) v |= kpv_ErrorFlags_UnsupportedMethod;
      if (_dataError) v |= kpv_ErrorFlags_DataError;
      prop = v;
      break;
    }
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


static char * DictSizeToString(UInt32 val, char *s Z7_lifetimebound)
{
  for (unsigned i = 0; i < 32; i++)
    if (((UInt32)1 << i) == val)
      return ::ConvertUInt32ToString(i, s);
  char c = 'b';
       if ((val & ((1 << 20) - 1)) == 0) { val >>= 20; c = 'm'; }
  else if ((val & ((1 << 10) - 1)) == 0) { val >>= 10; c = 'k'; }
  s = ::ConvertUInt32ToString(val, s);
  *s++ = c;
  *s = 0;
  return s;
}

static char *AddProp32(char *s Z7_lifetimebound, const char *name, UInt32 v)
{
  *s++ = ':';
  s = MyStpCpy(s, name);
  return ::ConvertUInt32ToString(v, s);
}

void CHandler::GetMethod(NCOM::CPropVariant &prop) const
{
  if (!_stream)
    return;

  char sz[64];
  char *s = sz;
  if (_header.FilterID != 0)
    s = MyStpCpy(s, "BCJ ");
  s = MyStpCpy(s, "LZMA:");
  s = DictSizeToString(_header.GetDicSize(), s);
  
  UInt32 d = _header.GetProp();
  // if (d != 0x5D)
  {
    UInt32 lc = d % 9;
    d /= 9;
    UInt32 pb = d / 5;
    UInt32 lp = d % 5;
    if (lc != 3) s = AddProp32(s, "lc", lc);
    if (lp != 0) s = AddProp32(s, "lp", lp);
    if (pb != 2) /* s = */ AddProp32(s, "pb", pb);
  }
  prop = sz;
}


Z7_COM7F_IMF(CHandler::GetProperty(UInt32 /* index */, PROPID propID, PROPVARIANT *value))
{
  NCOM::CPropVariant prop;
  switch (propID)
  {
    case kpidSize: if (_stream && _header.HasSize()) prop = _header.Size; break;
    case kpidPackSize: if (_packSize_Defined) prop = _packSize; break;
    case kpidMethod: GetMethod(prop); break;
    default: break;
  }
  prop.Detach(value);
  return S_OK;
}

API_FUNC_static_IsArc IsArc_Lzma(const Byte *p, size_t size)
{
  const UInt32 kHeaderSize = 1 + 4 + 8;
  if (size < kHeaderSize)
    return k_IsArc_Res_NEED_MORE;
  if (p[0] >= 5 * 5 * 9)
    return k_IsArc_Res_NO;
  const UInt64 unpackSize = GetUi64(p + 1 + 4);
  if (unpackSize != (UInt64)(Int64)-1)
  {
    if (unpackSize >= ((UInt64)1 << 56))
      return k_IsArc_Res_NO;
  }
  if (unpackSize != 0)
  {
    if (size < kHeaderSize + 2)
      return k_IsArc_Res_NEED_MORE;
    if (p[kHeaderSize] != 0)
      return k_IsArc_Res_NO;
    if (unpackSize != (UInt64)(Int64)-1)
    {
      if ((p[kHeaderSize + 1] & 0x80) != 0)
        return k_IsArc_Res_NO;
    }
  }
  if (!CheckDicSize(p + 1))
    // return k_IsArc_Res_YES_LOW_PROB;
    return k_IsArc_Res_NO;
  return k_IsArc_Res_YES;
}
}

API_FUNC_static_IsArc IsArc_Lzma86(const Byte *p, size_t size)
{
  if (size < 1)
    return k_IsArc_Res_NEED_MORE;
  Byte filterID = p[0];
  if (filterID != 0 && filterID != 1)
    return k_IsArc_Res_NO;
  return IsArc_Lzma(p + 1, size - 1);
}
}



Z7_COM7F_IMF(CHandler::Open(IInStream *inStream, const UInt64 *, IArchiveOpenCallback *))
{
  Close();
  
  const unsigned headerSize = GetHeaderSize();
  const UInt32 kBufSize = 1 << 7;
  Byte buf[kBufSize];
  size_t processedSize = kBufSize;
  RINOK(ReadStream(inStream, buf, &processedSize))
  if (processedSize < headerSize + 2)
    return S_FALSE;
  if (!_header.Parse(buf, _lzma86))
    return S_FALSE;
  const Byte *start = buf + headerSize;
  if (start[0] != 0 /* || (start[1] & 0x80) != 0 */ ) // empty stream with EOS is not 0x80
    return S_FALSE;

  RINOK(InStream_GetSize_SeekToEnd(inStream, _packSize))

  SizeT srcLen = (SizeT)processedSize - headerSize;

  if (srcLen > 10
      && _header.Size == 0
      // && _header.FilterID == 0
      && _header.LzmaProps[0] == 0
      )
    return S_FALSE;

  const UInt32 outLimit = 1 << 11;
  Byte outBuf[outLimit];

  SizeT outSize = outLimit;
  if (outSize > _header.Size)
    outSize = (SizeT)_header.Size;
  SizeT destLen = outSize;
  ELzmaStatus status;
  
  SRes res = LzmaDecode(outBuf, &destLen, start, &srcLen,
      _header.LzmaProps, 5, LZMA_FINISH_ANY,
      &status, &g_Alloc);
  
  if (res != SZ_OK)
    if (res != SZ_ERROR_INPUT_EOF)
      return S_FALSE;

  _isArc = true;
  _stream = inStream;
  _seqStream = inStream;
  _needSeekToStart = true;
  return S_OK;
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
  _needSeekToStart = false;
  _dataAfterEnd = false;
  _needMoreInput = false;
  _unsupported = false;
  _dataError = false;

  _packSize_Defined = false;
  _unpackSize_Defined = false;
  _numStreams_Defined = false;
  _subStreamHandedOut = false; // 7-ZSTar: M6b -- re-arm GetStream() guard

  _packSize = 0;

  _stream.Release();
  _seqStream.Release();
   return S_OK;
}


// 7-ZSTar: M6b fix (independent review Finding 1) -- multi-member
// (concatenated) lzma-alone continuation for the one-step kpidMainSubfile
// path (GetStream() below). Mirrors, member-for-member, what
// CHandler::Extract() (further up) already does for a second (and later)
// member: read the next 13-byte alone-format header via the *same* decoder
// object's own buffered reader -- ReadFromInputStream(), which shares its
// _inBuf/_inPos/_inLim with pull-mode Read() (see LzmaDecoder.cpp), so
// continuing to read through it is exactly what already makes the packed
// IInStream's own read-ahead-driven raw position irrelevant here (same
// reasoning as CGzMemberContinuation in GzHandler.cpp) -- parse it, and
// (re)prime the decoder with that member's own props. Passing the parsed
// member's own Size (when present) to PrepareNextMember(), rather than
// NULL, matters here specifically: it's what tells the decoder exactly
// where *this* member's LZMA stream ends, the same way CDecoder::Code()
// (the Extract()-only helper class above) passes it to CodeResume() for
// every member including the first -- without it, a member whose encoder
// didn't also write an explicit end-of-payload marker could keep consuming
// input past its own true end and into the next member's header bytes,
// silently corrupting the tail of that member's decoded output before this
// continuation callback ever gets a chance to run.
class CLzmaMemberContinuation Z7_final: public IRewindableMemberContinuation
{
  NCompress::NLzma::CDecoder *_decoder; // not owned -- outlives this (same GetStream() call site)
public:
  CLzmaMemberContinuation(NCompress::NLzma::CDecoder *decoder): _decoder(decoder) {}

  HRESULT TryStartNextMember(bool &hasNext) Z7_override
  {
    hasNext = false;

    Byte buf[5 + 8]; // props(5) + size(8) -- plain lzma-alone only, never lzma86 (see GetStream())
    UInt32 processed = 0;
    RINOK(_decoder->ReadFromInputStream(buf, sizeof(buf), &processed))
    if (processed != sizeof(buf))
      return S_OK; // truncated header: clean end, not a decode error

    CHeader header;
    if (!header.Parse(buf, false))
      return S_OK; // trailing bytes aren't a valid next header: clean end

    RINOK(_decoder->SetDecoderProperties2(header.LzmaProps, 5))
    _decoder->PrepareNextMember(header.HasSize() ? &header.Size : NULL);
    hasNext = true;
    return S_OK;
  }
};


// 7-ZSTar: M6b -- see ZstdHandler.cpp's GetStream() for the full rationale;
// this is the same mechanism mounted on the plain lzma-alone format
// (never lzma86 -- see the kpidMainSubfile case above). startPos is
// GetHeaderSize() (13 bytes for the non-lzma86 variant: 5 props + 8 size):
// NCompress::NLzma::CDecoder decodes a raw LZMA stream and does not parse
// the alone-format header itself -- SetDecoderProperties2() must be called
// (once, here) with the 5 props bytes _header already captured in Open(),
// before this decoder ever sees any packed bytes. index is always 0 --
// GetNumberOfItems() always reports exactly one item.
Z7_COM7F_IMF(CHandler::GetStream(UInt32 index, ISequentialInStream **stream))
{
  COM_TRY_BEGIN

  *stream = NULL;

  if (index != 0)
    return E_INVALIDARG;
  if (_lzma86 || !_stream)
    return S_FALSE;
  if (_subStreamHandedOut)
    return S_FALSE;

  CMyComPtr2_Create<ISequentialInStream, NCompress::NLzma::CDecoder> decoder;
  decoder->FinishStream = true;
  RINOK(decoder->SetDecoderProperties2(_header.LzmaProps, 5))

  CMyComPtr<ISequentialInStream> decoderRead;
  CMyComPtr<ICompressSetInStream> decoderSetInStream;
  CMyComPtr<ICompressSetOutStreamSize> decoderSetOutSize;
  RINOK(RewindableDecodedStream_GetPullInterfaces(decoder.Interface(),
      decoderRead, decoderSetInStream, decoderSetOutSize))

  CMyComPtr2<IInStream, CRewindableDecodedStream> spec;
  spec.Create_if_Empty();
  // 7-ZSTar: M6b fix (Finding 1) -- decoder.ClsPtr() stays valid for the
  // continuation object's lifetime; see GzHandler.cpp's twin comment.
  RINOK(spec->Init(_stream, GetHeaderSize(), decoderRead, decoderSetInStream, decoderSetOutSize,
      new CLzmaMemberContinuation(decoder.ClsPtr())))

  bool isTar = false;
  RINOK(RewindableDecodedStream_SniffTar(spec.Interface(), isTar))
  if (!isTar)
    return S_FALSE;

  *stream = spec.Detach();
  _subStreamHandedOut = true;
  return S_OK;

  COM_TRY_END
}

Z7_CLASS_IMP_COM_1(
  CCompressProgressInfoImp,
  ICompressProgressInfo
)
  CMyComPtr<IArchiveOpenCallback> Callback;
public:
  UInt64 Offset;

  void Init(IArchiveOpenCallback *callback) { Callback = callback; }
};

Z7_COM7F_IMF(CCompressProgressInfoImp::SetRatioInfo(const UInt64 *inSize, const UInt64 * /* outSize */))
{
  if (Callback)
  {
    const UInt64 files = 0;
    const UInt64 val = Offset + *inSize;
    return Callback->SetCompleted(&files, &val);
  }
  return S_OK;
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
    RINOK(extractCallback->SetTotal(_packSize))
    
  Int32 opResult;
 {
  CMyComPtr<ISequentialOutStream> realOutStream;
  const Int32 askMode = testMode ?
      NExtract::NAskMode::kTest :
      NExtract::NAskMode::kExtract;
  RINOK(extractCallback->GetStream(0, &realOutStream, askMode))
  if (!testMode && !realOutStream)
    return S_OK;
  
  RINOK(extractCallback->PrepareOperation(askMode))

  CMyComPtr2_Create<ISequentialOutStream, CDummyOutStream> outStream;
  outStream->SetStream(realOutStream);
  outStream->Init();
  realOutStream.Release();

  CMyComPtr2_Create<ICompressProgressInfo, CLocalProgress> lps;
  lps->Init(extractCallback, true);

  if (_needSeekToStart)
  {
    if (!_stream)
      return E_FAIL;
    RINOK(InStream_SeekToBegin(_stream))
  }
  else
    _needSeekToStart = true;

  CDecoder decoder;
  RINOK(decoder.Create(_lzma86, _seqStream))
 
  bool firstItem = true;

  UInt64 packSize = 0;
  UInt64 unpackSize = 0;
  UInt64 numStreams = 0;

  bool dataAfterEnd = false;
  
  HRESULT hres = S_OK;

  for (;;)
  {
    lps->InSize = packSize;
    lps->OutSize = unpackSize;
    RINOK(lps->SetCur())

    const UInt32 kBufSize = 1 + 5 + 8;
    Byte buf[kBufSize];
    const UInt32 headerSize = GetHeaderSize();
    UInt32 processed;
    RINOK(decoder.ReadInput(buf, headerSize, &processed))
    if (processed != headerSize)
    {
      if (processed != 0)
        dataAfterEnd = true;
      break;
    }
  
    CHeader st;
    if (!st.Parse(buf, _lzma86))
    {
      dataAfterEnd = true;
      break;
    }
    numStreams++;
    firstItem = false;

    hres = decoder.Code(st, outStream, lps);

    packSize = decoder.GetInputProcessedSize();
    unpackSize = outStream->GetSize();
    
    if (hres == E_NOTIMPL)
    {
      _unsupported = true;
      hres = S_FALSE;
      break;
    }
    if (hres == S_FALSE)
      break;
    RINOK(hres)
  }

  if (firstItem)
  {
    _isArc = false;
    hres = S_FALSE;
  }
  else if (hres == S_OK || hres == S_FALSE)
  {
    if (dataAfterEnd)
      _dataAfterEnd = true;
    else if (decoder._lzmaDecoder->NeedsMoreInput())
      _needMoreInput = true;

    _packSize = packSize;
    _unpackSize = unpackSize;
    _numStreams = numStreams;
  
    _packSize_Defined = true;
    _unpackSize_Defined = true;
    _numStreams_Defined = true;
  }
  
  opResult = NExtract::NOperationResult::kOK;

  if (!_isArc)
    opResult = NExtract::NOperationResult::kIsNotArc;
  else if (_needMoreInput)
    opResult = NExtract::NOperationResult::kUnexpectedEnd;
  else if (_unsupported)
    opResult = NExtract::NOperationResult::kUnsupportedMethod;
  else if (_dataAfterEnd)
    opResult = NExtract::NOperationResult::kDataAfterEnd;
  else if (hres == S_FALSE)
    opResult = NExtract::NOperationResult::kDataError;
  else if (hres != S_OK)
    return hres;

  // outStream.Release();
 }
  return extractCallback->SetOperationResult(opResult);

  COM_TRY_END
}

namespace NLzmaAr {

// 2, { 0x5D, 0x00 },

REGISTER_ARC_I_CLS_NO_SIG(
  CHandler(false),
  "lzma", "lzma tlz", "* .tar", 0xA, // 7-ZSTar: M6b -- added "tlz" (GNU tar suffix.c: tlz = lzma) + ".tar" AddExt mapping
  0,
  NArcInfoFlags::kStartOpen |
  NArcInfoFlags::kKeepName,
  IsArc_Lzma)
 
}

namespace NLzma86Ar {

REGISTER_ARC_I_CLS_NO_SIG(
  CHandler(true),
  "lzma86", "lzma86", NULL, 0xB,
  0,
  NArcInfoFlags::kKeepName,
  IsArc_Lzma86)
 
}

}}
