// TarChainHandler.cpp -- 7-ZSTar: new file (M4)
//
// See TarChainHandler.h for the overall design. This file implements:
//   - SetProperties(): routes each incoming property to either the internal
//     tar handler (cp/m/tm/ta/tc/tp*) or the compression coder (everything
//     else: x/mt/memuse/d/zf/ldm/wlog/...).
//   - GetFileTimeType(): delegates to the internal tar handler.
//   - UpdateItems(): the actual "pipe tar's output through a compressor
//     with zero intermediate file" logic.

#include "StdAfx.h"

#include "../../../Common/ComTry.h"
#include "../../../Common/MyCom.h"
#include "../../../Common/MyString.h"
#include "../../../Common/MyVector.h"

#include "../../../../C/CpuArch.h" // 7-ZSTar: M6b -- SetUi32() for the gzip footer

#include "../../../Windows/Thread.h"

#include "../../Common/StreamBinder.h"
#include "../../Common/StreamUtils.h" // 7-ZSTar: M6b -- WriteStream() for the gzip header/footer

#include "../../Compress/ZstdEncoder.h"
#include "../../Compress/ZstdEncoderProps.h"
#include "../../Compress/BZip2Encoder.h" // 7-ZSTar: M6b
#include "../../Compress/DeflateEncoder.h" // 7-ZSTar: M6b
#include "../../Compress/XzEncoder.h" // 7-ZSTar: M6b

#include "../Common/InStreamWithCRC.h" // 7-ZSTar: M6b -- CSequentialInStreamWithCRC for the gzip footer

#include "TarChainHandler.h"
#include "TarChainCoderFactory.h" // 7-ZSTar: M6a -- see this header's comment for why
                                  // lz4/lz5/lizard/brotli go through factory functions
                                  // instead of #including their own EncoderXxx.h here

using namespace NWindows;

namespace NArchive {
namespace NTarChain {

namespace {

// RAII holder for a contiguous PROPVARIANT array. ISetProperties::SetProperties()
// needs raw-array-of-PROPVARIANT layout, which neither CObjectVector (an
// array of *pointers* to heap-allocated elements, not a contiguous array of
// values) nor a bare new[]/delete[] pair straddling several RINOK-guarded
// early returns can safely give us. Mirrors the file-local
// CPropPropetiesVector in CPP/7zip/UI/Common/SetProperties.cpp.
struct CPropVariantArray
{
  NWindows::NCOM::CPropVariant *Data;
  explicit CPropVariantArray(unsigned num): Data(new NWindows::NCOM::CPropVariant[num]) {}
  ~CPropVariantArray() { delete [] Data; }
private:
  CPropVariantArray(const CPropVariantArray &);
  CPropVariantArray &operator=(const CPropVariantArray &);
};


struct CEncodeThreadParams
{
  ICompressCoder *Encoder;
  CMyComPtr<ISequentialInStream> InStream;
  ISequentialOutStream *OutStream;
  HRESULT Result;

  CEncodeThreadParams(): Encoder(NULL), OutStream(NULL), Result(E_FAIL) {}
};

THREAD_FUNC_DECL EncodeThreadProc(void *pParam)
{
  CEncodeThreadParams *p = (CEncodeThreadParams *)pParam;
  // Exception boundary for this thread (same pattern as CoderMixer2.cpp's
  // CCoderMT::Execute()): COM_TRY on the calling thread's stack does not
  // cover us, and an escaping exception here (e.g. bad_alloc under MT
  // encode) would hit noexcept frames and std::terminate() the process.
  try
  {
    p->Result = p->Encoder->Code(p->InStream, p->OutStream, NULL, NULL, NULL);
  }
  catch (...)
  {
    p->Result = E_FAIL;
  }
  // Release our only reference to the pipe's read end from *inside this
  // (the worker) thread*, right now -- see the long comment in
  // CTarChainHandler::UpdateItems() for why this must not be deferred until
  // whenever the calling thread's CEncodeThreadParams instance eventually
  // goes out of scope: if Code() failed early while tar (on the calling
  // thread) is still blocked inside pipeOut->Write(), this is what
  // unblocks it. Waiting for the calling thread to release its own
  // reference would deadlock, because the calling thread is the one that's
  // stuck.
  p->InStream.Release();
  return THREAD_FUNC_RET_ZERO;
}

// Mirrors CoderMixer2.cpp's own file-local GetError(): prefer a "real"
// error over CStreamBinder's internal "the other side of the pipe closed"
// signal (k_My_HRESULT_WritingWasCut), which by itself says nothing about
// *why* the pipe was cut short.
HRESULT CombineResults(HRESULT res, HRESULT res2)
{
  if (res == res2)
    return res;
  if (res == S_OK)
    return res2;
  if (res == k_My_HRESULT_WritingWasCut)
  {
    if (res2 != S_OK)
      return res2;
  }
  return res;
}

} // anonymous namespace


CTarChainHandler::CTarChainHandler(ETarChainCodec codec):
    _codec(codec)
{
  // CSingleMethodProps's own default constructor only runs InitSingle()
  // (not InitCommon()/Clear()), so without this call _encProps._numThreads
  // et al. would be uninitialized garbage until/unless SetProperties() is
  // called -- and the update engine only calls SetProperties() at all when
  // the user passed at least one -m switch. UpdateItems() always reads
  // _encProps unconditionally, so it must always be in a valid, fully
  // Init()-ed state by construction, not just after a SetProperties() call
  // that may never come.
  _encProps.Init();

  _tarHandler.Interface()->QueryInterface(IID_ISetProperties, (void **)&_tarSetProps);
}


Z7_COM7F_IMF(CTarChainHandler::GetFileTimeType(UInt32 *type))
{
  // NArchive::NTar::CHandler::GetFileTimeType() derives its answer from
  // _handlerTimeOptions, which our own SetProperties() (if called at all)
  // already forwarded time-related props into -- so a plain delegation
  // keeps this in sync automatically instead of duplicating the logic.
  return _tarHandler.Interface()->GetFileTimeType(type);
}


Z7_COM7F_IMF(CTarChainHandler::SetProperties(const wchar_t * const *names, const PROPVARIANT *values, UInt32 numProps))
{
  COM_TRY_BEGIN

  if (!_tarSetProps)
    return E_FAIL;

  _encProps.Init();

  UStringVector tarNames;
  CPropVariantArray tarValues(numProps == 0 ? 1 : numProps);
  unsigned tarCount = 0;

  for (UInt32 i = 0; i < numProps; i++)
  {
    UString name = names[i];
    name.MakeLower_Ascii();

    // Tar-relevant names, exactly the set NArchive::NTar::CHandler::SetProperties()
    // itself recognizes (TarHandlerOut.cpp) beyond 'x'/'mt'/'memuse' (which
    // tar treats as no-ops it silently accepts -- those, and every other
    // name, are compression-side and go to _encProps below instead):
    //   cp        - codepage
    //   m         - "pax"/"posix"/"gnu"
    //   tm/ta/tc  - write mtime/atime/ctime (CHandlerTimeOptions::Parse)
    //   tp*       - time precision (CHandlerTimeOptions::Parse)
    const bool isTarProp =
           name.IsEqualTo("cp")
        || name.IsEqualTo("m")
        || name.IsEqualTo("tm")
        || name.IsEqualTo("ta")
        || name.IsEqualTo("tc")
        || name.IsPrefixedBy_Ascii_NoCase("tp");

    if (isTarProp)
    {
      tarNames.Add(names[i]);
      tarValues.Data[tarCount] = values[i];
      tarCount++;
    }
    else
    {
      RINOK(_encProps.SetProperty(names[i], values[i]))
    }
  }

  CRecordVector<const wchar_t *> tarNamePtrs;
  for (unsigned i = 0; i < tarNames.Size(); i++)
    tarNamePtrs.Add((const wchar_t *)tarNames[i]);

  return _tarSetProps->SetProperties(tarNamePtrs.ConstData(), tarValues.Data, tarCount);

  COM_TRY_END
}


Z7_COM7F_IMF(CTarChainHandler::UpdateItems(ISequentialOutStream *outStream, UInt32 numItems,
    IArchiveUpdateCallback *callback))
{
  COM_TRY_BEGIN

  // ---- 1. build the coder for the configured codec ----

  CMyComPtr2_Create<ICompressCoder, NCompress::NZstd::CEncoder> zstdEncoder;
  CMyComPtr<ICompressCoder> factoryEncoder;  // 7-ZSTar: M6a -- holds the result for
                                              // whichever CreateTarChainCoder_Xxx() case runs
                                              // below (see TarChainCoderFactory.h)
  // 7-ZSTar: M6b -- gzip/bzip2/xz are official-format encoders with no
  // zstdmt-header collision risk (see TarChainCoderFactory.h's own comment
  // for the collision this sidesteps for lz4/lz5/lizard/brotli instead),
  // so these are constructed directly here just like zstdEncoder above.
  CMyComPtr2_Create<ICompressCoder, NCompress::NBZip2::CEncoder> bzip2Encoder;
  CMyComPtr2_Create<ICompressCoder, NCompress::NXz::CEncoder> xzEncoder;
  CMyComPtr2_Create<ICompressCoder, NCompress::NDeflate::NEncoder::CCOMCoder> gzipEncoder;
  ICompressCoder *encoder = NULL;

  // 7-ZSTar: M6b -- gzip is the one codec here whose *container* format
  // (not just its compressed payload) needs data only known after encoding
  // finishes: an 8-byte trailer (CRC32 + byte count of the *uncompressed*
  // tar stream, RFC 1952) written after the compressed body -- mirrors
  // GzHandler.cpp's own CItem::WriteHeader()/WriteFooter() split for
  // single-file gzip (see the kCodec_Gzip case and step 4 below for the
  // header/footer writes themselves). gzipCrcStream, when used, sits
  // *between* the pipe's read end and the encoder (step 2) so its CRC/size
  // reflect the tar stream the encoder actually consumed, not the
  // compressed bytes it produced.
  // (declared below, right after `binder` -- see the lifetime note there)
  bool isGzip = false;

  switch (_codec)
  {
    // 7-ZSTar: M6a -- lz4/lz5 (and lizard/brotli, added alongside their own
    // ports) go through a factory function rather than being constructed
    // directly here: see TarChainCoderFactory.h for why (their C/zstdmt/
    // *-mt.h headers can't be #included together in this translation unit).
    // Neither has a SrcSizeHint64-equivalent field (unlike zstd, they don't
    // use a size hint to decide frame-content-size flags), and the
    // numThreads auto-fill block in the kCodec_Zstd case below is
    // zstd-specific (memory-usage-aware shrink) tuning these codecs don't
    // have an equivalent of -- their own SetNumberOfThreads() clamps
    // (LZ4MT_THREAD_MAX / LZ5MT_THREAD_MAX) are applied generically via
    // ICompressSetCoderMt regardless, through _encProps's own default
    // (all-cores) numThreads unless the user passed -mmt=N.
    case kCodec_Brotli:
    {
      RINOK(CreateTarChainCoder_Brotli(_encProps, factoryEncoder))
      encoder = factoryEncoder.Interface();
      break;
    }
    case kCodec_Lizard:
    {
      RINOK(CreateTarChainCoder_Lizard(_encProps, factoryEncoder))
      encoder = factoryEncoder.Interface();
      break;
    }
    case kCodec_Lz5:
    {
      RINOK(CreateTarChainCoder_Lz5(_encProps, factoryEncoder))
      encoder = factoryEncoder.Interface();
      break;
    }
    case kCodec_Lz4:
    {
      RINOK(CreateTarChainCoder_Lz4(_encProps, factoryEncoder))
      encoder = factoryEncoder.Interface();
      break;
    }
    case kCodec_Zstd:
    {
#ifndef Z7_ST
      // _encProps._numThreads defaults to the detected processor count
      // (CCommonMethodProps::InitCommon(), run via _encProps.Init() in the
      // constructor and again in SetProperties()) unless the user passed
      // an explicit -mmt=N, which SetCommonProperty() already folded into
      // the same field -- so this one AddProp_NumThreads() call is enough
      // to cover both "user asked for N threads" and "use all cores by
      // default", matching plain -tzstd's behavior. (Unlike
      // ZstdHandler.cpp's own UpdateItems(), this does not additionally
      // shrink the thread count to fit a memory-usage budget -- M4 keeps
      // that auto-tuning out of scope; -mmt=N and the all-cores default
      // both still work correctly.)
      if (_encProps.FindProp(NCoderPropID::kNumThreads) < 0)
      {
        UInt32 numThreads = _encProps._numThreads;
        if (numThreads > Z7_ZSTDMT_NBWORKERS_MAX)
          numThreads = Z7_ZSTDMT_NBWORKERS_MAX;
        _encProps.AddProp_NumThreads(numThreads);
      }
#endif
      RINOK(_encProps.SetCoderProps(zstdEncoder.ClsPtr(), NULL))
      // Unknown ahead of time: unlike ZstdHandler.cpp's own UpdateItems()
      // (which compresses one already-sized file), our source is tar's
      // *compressed stream output*, whose final byte count depends on
      // header/padding overhead we don't precompute. Matches "7z a -so"
      // (streaming to stdout) semantics, which this project already
      // accepts as the precedent for "unknown output size" (see
      // TarUpdate.cpp's IOutStream-seek requirement note).
      zstdEncoder->SrcSizeHint64 = (UInt64)(Int64)-1;
      encoder = zstdEncoder.Interface();
      break;
    }

    // 7-ZSTar: M6b -- bzip2/xz: the "BZh" signature and block CRCs (bzip2)
    // / stream header, Index and footer (xz) are all written by the coder
    // itself as part of Code() -- exactly like zstd above, a single Code()
    // call over the whole tar stream is a complete, valid archive with no
    // extra framing this function needs to add (compare kCodec_Gzip just
    // below, which does need extra framing). _encProps.SetCoderProps()
    // (the same generic property-setting call zstd/bzip2's own
    // single-file UpdateArchive() already use) is enough to configure a
    // valid encoder; XzHandler.cpp's own UpdateItems() additionally tunes
    // thread-group/block-size/reduceSize using the *known* input size of a
    // single file being compressed, which we deliberately don't replicate
    // here -- our source is tar's live streaming output, so there is no
    // upfront size to tune against in the first place (same "unknown size"
    // situation as zstd's SrcSizeHint64=-1 above), and the generic props
    // path still produces a correct, if less finely tuned, xz stream.
    case kCodec_Bzip2:
    {
      RINOK(_encProps.SetCoderProps(bzip2Encoder.ClsPtr(), NULL))
      encoder = bzip2Encoder.Interface();
      break;
    }
    case kCodec_Xz:
    {
      RINOK(_encProps.SetCoderProps(xzEncoder.ClsPtr(), NULL))
      encoder = xzEncoder.Interface();
      break;
    }

    case kCodec_Gzip:
    {
      // gzip header (RFC 1952): fixed 10 bytes, FLG=0 (no name/comment/
      // extra/header-CRC -- unlike GzHandler.cpp's own single-file gzip,
      // there is no one meaningful inner filename to embed: this wraps a
      // whole tar stream, matching TarChainRegister.cpp's g_ArcInfo_TarGz
      // "not kKeepName" rationale), MTIME=0 ("not available", same as
      // GzHandler.cpp's own item.Time==0 convention -- tar's own per-entry
      // mtimes are the meaningful ones for a multi-file archive; the outer
      // gzip wrapper's single mtime field would be misleading), XFL=0,
      // OS=0xFF ("unknown", the gzip spec's own value for "not specified").
      {
        const Byte header[10] = { 0x1F, 0x8B, 8, 0,  0, 0, 0, 0,  0, 0xFF };
        RINOK(WriteStream(outStream, header, 10))
      }
      RINOK(_encProps.SetCoderProps(gzipEncoder.ClsPtr(), NULL))
      encoder = gzipEncoder.Interface();
      isGzip = true;
      break;
    }

    default:
      return E_NOTIMPL;
  }

  // ---- 2. wire up the zero-copy pipe between tar's output and the coder's input ----

  CStreamBinder binder;
  RINOK(binder.Create_ReInit())

  // 7-ZSTar: gzipCrcStream holds a reference to the pipe's read end
  // (pipeIn, via SetStream below), and ~CBinderInStream calls back into
  // binder.CloseRead_CallOnce(). Locals are destroyed in reverse order of
  // declaration, so gzipCrcStream must be declared AFTER binder: it is then
  // destroyed first, while binder is still alive. (Declared before binder it
  // was destroyed after it -> use of a destroyed CSemaphore, reported by
  // TSan as "use of an invalid mutex"; tar.gz only.) It is still in scope
  // for the step 4 trailer, which reads GetCRC()/GetSize() before return.
  CMyComPtr2_Create<ISequentialInStream, CSequentialInStreamWithCRC> gzipCrcStream;

  CEncodeThreadParams threadParams;
  CMyComPtr<ISequentialOutStream> pipeOut;
  {
    CMyComPtr<ISequentialInStream> pipeIn;
    binder.CreateStreams2(pipeIn, pipeOut);
    if (isGzip)
    {
      // 7-ZSTar: M6b -- splice the CRC/size tracker between the pipe's
      // read end and the encoder, so gzipCrcStream ends up measuring
      // exactly the uncompressed tar bytes the encoder consumed (step 4
      // below reads GetCRC()/GetSize() back out of it after the thread
      // joins).
      gzipCrcStream->SetStream(pipeIn);
      gzipCrcStream->Init();
      threadParams.InStream = gzipCrcStream.Interface();
    }
    else
      threadParams.InStream = pipeIn;
  }
  threadParams.Encoder = encoder;
  threadParams.OutStream = outStream;

  // ---- 3. run the coder on a worker thread; tar drives item enumeration
  //         (and hence every call back into `callback`) on this thread ----

  NWindows::CThread thread;
  const WRes wres = thread.Create(EncodeThreadProc, &threadParams);
  if (wres != 0)
  {
    // No thread was ever started: nothing to join, and pipeOut/threadParams.InStream
    // unwind normally via their own destructors on the way out. Not a
    // deadlock risk -- there is no second thread to be stuck waiting on us.
    return HRESULT_FROM_WIN32(wres);
  }

  // pipeOut->Write() (called from inside tar's own UpdateItems()) blocks
  // here whenever the worker thread's Read() hasn't caught up yet -- that
  // is CStreamBinder's intended zero-copy back-pressure, not a bug.
  // Progress is reported solely through tar's own calls into `callback`
  // (the coder's own progress parameter is NULL below), so the progress
  // bar never appears to move backwards or jump between two independent
  // sources.
  const HRESULT hresTar = _tarHandler.Interface()->UpdateItems(pipeOut, numItems, callback);

  // Whatever just happened above -- clean finish, a tar-side error, or a
  // mid-stream cancellation (callback returning E_ABORT) -- the write end
  // must be closed *now*, unconditionally: it is the only way the encoder
  // thread's blocked (or future) Read() call will ever see EOF instead of
  // waiting forever. This is the most deadlock-prone point in this
  // function, so it is done two ways for defense in depth:
  //   (a) release our only reference to pipeOut, which triggers
  //       CBinderOutStream's destructor -> CStreamBinder::CloseWrite();
  //   (b) call CloseWrite() directly on the binder we own on our own stack,
  //       which is safe to call unconditionally/more-than-once (unlike
  //       CloseRead_CallOnce(), it just resets a couple of fields and
  //       signals an event -- see StreamBinder.h) -- so this is a no-op if
  //       (a) already did the job, but is what actually saves us if
  //       NArchive::NTar::CHandler ever starts retaining its own reference
  //       to the outStream pointer it was handed (which would otherwise
  //       keep pipeOut's refcount above zero and silently skip its
  //       destructor).
  pipeOut.Release();
  binder.CloseWrite();

  // Join unconditionally: even on the error paths above, the thread must
  // still be running Code() (or about to return from it) at this point,
  // and thread.Wait_Close() is what establishes the happens-before
  // relationship that makes reading threadParams.Result below safe.
  thread.Wait_Close();

  const HRESULT hresCombined = CombineResults(hresTar, threadParams.Result);

  // ---- 4. gzip only: append the 8-byte trailer now that gzipCrcStream has
  //         seen every byte the encoder consumed (CRC32 + uncompressed
  //         size, RFC 1952 -- see the kCodec_Gzip case above for the header
  //         half). Only on a clean result: a half-written gzip member is
  //         already unusable regardless of whether a trailer follows it,
  //         so there is nothing worth finalizing on top of a known-failed
  //         or mid-stream-cancelled encode (matches this function's
  //         existing error-propagation shape -- errors already short-
  //         circuit via RINOK everywhere else in this function). ----
  if (isGzip && hresCombined == S_OK)
  {
    Byte footer[8];
    SetUi32(footer, gzipCrcStream->GetCRC())
    SetUi32(footer + 4, (UInt32)gzipCrcStream->GetSize())
    RINOK(WriteStream(outStream, footer, 8))
  }

  return hresCombined;

  COM_TRY_END
}

}}
