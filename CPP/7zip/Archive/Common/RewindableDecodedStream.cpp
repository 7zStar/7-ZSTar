// RewindableDecodedStream.cpp -- 7-ZSTar: new file (M5; generalized M6b)
// See RewindableDecodedStream.h for the design.

#include "StdAfx.h"

#include "../../../Common/ComTry.h"

#include "../../Common/StreamUtils.h"

#ifndef Z7_NO_TAR_SNIFF
#include "../Tar/TarIn.h" // 7-ZSTar: IsArc_Tar for RewindableDecodedStream_SniffTar()
#endif

#include "RewindableDecodedStream.h"

// Fixed-size scratch buffer used only for decode-and-discard (forward
// skip, and the decode-to-real-end pass that measures total size). Never
// grows regardless of how much data is skipped/measured -- memory use for
// this whole object stays O(1) in the archive size.
static const UInt32 kSkipBufSize = (UInt32)1 << 20; // 1 MiB


HRESULT RewindableDecodedStream_GetPullInterfaces(IUnknown *decoder,
    CMyComPtr<ISequentialInStream> &decoderRead,
    CMyComPtr<ICompressSetInStream> &decoderSetInStream,
    CMyComPtr<ICompressSetOutStreamSize> &decoderSetOutSize)
{
  RINOK(decoder->QueryInterface(IID_ISequentialInStream, (void **)&decoderRead))
  if (!decoderRead)
    return E_NOINTERFACE;
  RINOK(decoder->QueryInterface(IID_ICompressSetInStream, (void **)&decoderSetInStream))
  if (!decoderSetInStream)
    return E_NOINTERFACE;
  RINOK(decoder->QueryInterface(IID_ICompressSetOutStreamSize, (void **)&decoderSetOutSize))
  if (!decoderSetOutSize)
    return E_NOINTERFACE;
  return S_OK;
}


HRESULT RewindableDecodedStream_SniffTar(IInStream *decodedStream, bool &isTar)
{
  isTar = false;
#ifndef Z7_NO_TAR_SNIFF
  Byte buf[512];
  UInt32 got = 0;
  while (got < 512)
  {
    UInt32 cur = 0;
    const HRESULT hres = decodedStream->Read(buf + got, 512 - got, &cur);
    if (hres != S_OK || cur == 0)
      break; // decode error or early EOF -> deliberately swallowed: it just
             // means "not a tar" here; a genuinely broken file still shows
             // its real error on the normal single-file open path.
    got += cur;
  }
  if (got == 512 && NArchive::NTar::IsArc_Tar(buf, got) == k_IsArc_Res_YES)
    isTar = true;
#endif
  // 7-ZSTar: M6b -- Z7_NO_TAR_SNIFF builds (bundles that never register the
  // Tar format at all -- see Alone7z/makefile) skip the read above entirely
  // and report "not a tar" unconditionally: correct, since no drill-down
  // could ever succeed there regardless (no Tar handler to recognize the
  // decoded content), and cheaper than decoding a header block just to
  // throw the answer away. Either way position must come back to 0 for the
  // caller to hand the same stream onward unconditionally.
  UInt64 newPos = 0;
  RINOK(decodedStream->Seek(0, STREAM_SEEK_SET, &newPos))
  return S_OK;
}


HRESULT CRewindableDecodedStream::Init(IInStream *packedStream, UInt64 startPos,
    ISequentialInStream *decoderRead,
    ICompressSetInStream *decoderSetInStream,
    ICompressSetOutStreamSize *decoderSetOutSize,
    IRewindableMemberContinuation *continuation)
{
  _packedStream = packedStream;
  _startPos = startPos;
  _virtPos = 0;
  _decodedPos = 0;
  _primed = false;
  _totalSizeKnown = false;
  _totalSize = 0;
  _skipBuf.Alloc(kSkipBufSize);

  // 7-ZSTar: M6b fix (independent review Finding 1) -- ownership transfers
  // right away, before anything below can fail, so a failed Init() (the
  // SetInStream() call at the end) still leaves the continuation object
  // owned by (and eventually deleted by) *this*, not leaked. delete any
  // prior one first: Init() is documented as a one-shot setup call (never
  // actually re-invoked on a live object in this codebase), but this keeps
  // repeated-Init() safe rather than merely unused.
  delete _continuation;
  _continuation = continuation;

  _decoderRead = decoderRead;
  _decoderSetInStream = decoderSetInStream;
  _decoderSetOutSize = decoderSetOutSize;

  return _decoderSetInStream->SetInStream(packedStream);
}


// 7-ZSTar: M6b fix (independent review Finding 1) -- thin wrapper so
// SkipDecode()/Read() don't each need their own NULL check.
HRESULT CRewindableDecodedStream::TryContinueToNextMember(bool &hasNext)
{
  hasNext = false;
  if (!_continuation)
    return S_OK;
  return _continuation->TryStartNextMember(hasNext);
}


// Seeks the packed stream back to _startPos and re-primes decoder state
// from scratch. After this, _decodedPos == 0 and the next Read()/SkipDecode()
// will decode the very first bytes of the wrapped stream again.
HRESULT CRewindableDecodedStream::Rewind()
{
  RINOK(InStream_SeekSet(_packedStream, _startPos))
  // NULL outSize: we don't know the decoded size up front (and, per M0,
  // often can't trust a format's self-declared size even when present --
  // see RewindableDecodedStream.h) -- SetOutStreamSize() re-initializes the
  // decoder's internal state regardless of whether the size is known, for
  // every coder type this class is used with (confirmed by reading each
  // one's SetOutStreamSize()/SetOutStreamSizeResume(): zstd's Prepare(),
  // deflate's m_OutWindowStream.Init()+_remainLen=kLenIdNeedInit, bzip2's
  // InitOutSize()+InitInputBuffer()+StartNewStream(), lzma's
  // LzmaDec_Init() -- none of them require SetInStream() to be re-called,
  // only their one-time setup done by the caller before Init() to still be
  // in effect, which it is since nothing here touches it), so this doubles
  // as our "reset" primitive.
  RINOK(_decoderSetOutSize->SetOutStreamSize(NULL))
  _decodedPos = 0;
  _primed = true;
  return S_OK;
}


// Decodes-and-discards up to `count` bytes from the current physical
// decode position, advancing _decodedPos. Stops early (without error) once
// the decoder has no more data to give *and* (for multi-member formats) no
// further member follows either -- callers detect that by comparing
// _decodedPos against what they expected afterward.
HRESULT CRewindableDecodedStream::SkipDecode(UInt64 count)
{
  while (count != 0)
  {
    const UInt32 cur = (UInt32)(count < kSkipBufSize ? count : (UInt64)kSkipBufSize);
    UInt32 processed = 0;
    RINOK(_decoderRead->Read(_skipBuf.NonConstData(), cur, &processed))
    _decodedPos += processed;
    if (processed != 0)
    {
      count -= processed;
      continue;
    }
    // 7-ZSTar: M6b fix (independent review Finding 1) -- processed == 0:
    // this member reports it's out of data. For a multi-member format
    // (gzip, lzma-alone), that's only the *current* member ending, not
    // necessarily the whole logical stream -- give the continuation (if
    // any) a chance to find and prime a next member before accepting this
    // as the real end. See IRewindableMemberContinuation's contract.
    bool hasNext = false;
    RINOK(TryContinueToNextMember(hasNext))
    if (!hasNext)
      break; // real end of decoded data (single-member format, or a clean multi-member end)
    // else: decoder is now primed for the next member -- loop and keep
    // decoding-and-discarding toward `count` from there.
  }
  return S_OK;
}


// Makes the physical decoder state consistent with the caller-visible
// _virtPos: rewinds if we've been asked to go backward, or decodes-and-
// discards the gap if we've been asked to skip forward. After this call,
// either _decodedPos == _virtPos (ready to deliver real bytes), or
// _decodedPos < _virtPos (the requested position is past the real end of
// the decoded data -- Read() turns that into a clean 0-bytes-read result).
HRESULT CRewindableDecodedStream::SyncDecoderTo_VirtPos()
{
  if (!_primed || _virtPos < _decodedPos)
  {
    RINOK(Rewind())
  }
  if (_virtPos > _decodedPos)
  {
    RINOK(SkipDecode(_virtPos - _decodedPos))
  }
  return S_OK;
}


// Learns the true total decoded size by decoding-and-discarding from
// wherever the physical decoder currently is, all the way to the real end
// -- without touching _virtPos (SEEK_END/GetSize() can be asked regardless
// of the current logical read position). Cached from then on.
HRESULT CRewindableDecodedStream::EnsureTotalSizeKnown()
{
  if (_totalSizeKnown)
    return S_OK;
  if (!_primed)
  {
    RINOK(Rewind())
  }
  RINOK(SkipDecode(~(UInt64)0)) // "infinite": stops at the real end regardless
  _totalSize = _decodedPos;
  _totalSizeKnown = true;
  return S_OK;
}


Z7_COM7F_IMF(CRewindableDecodedStream::Read(void *data, UInt32 size, UInt32 *processedSize))
{
  COM_TRY_BEGIN

  if (processedSize)
    *processedSize = 0;
  if (size == 0)
    return S_OK;

  RINOK(SyncDecoderTo_VirtPos())

  if (_virtPos > _decodedPos)
  {
    // _virtPos is at/past the real end of the decoded data: a read at or
    // past end-of-stream returns S_OK with 0 bytes (IStream.h's
    // ISequentialInStream::Read() contract).
    return S_OK;
  }

  // 7-ZSTar: M6b fix (independent review Finding 1) -- loop instead of a
  // single Read() call: a multi-member format's decoder reporting 0
  // processed bytes (S_OK) might only mean the *current* member ended, not
  // the whole logical stream -- see TryContinueToNextMember(). Every branch
  // out of this loop returns immediately, so this never spins beyond what a
  // caller's single Read() call would otherwise have blocked for.
  for (;;)
  {
    UInt32 processed = 0;
    const HRESULT hres = _decoderRead->Read(data, size, &processed);
    if (processed != 0 || hres != S_OK)
    {
      _decodedPos += processed;
      _virtPos += processed;
      if (processedSize)
        *processedSize = processed;
      return hres;
    }
    bool hasNext = false;
    RINOK(TryContinueToNextMember(hasNext))
    if (!hasNext)
      return S_OK; // *processedSize already 0: real end (single-member format, or a clean multi-member end)
    // else: decoder is now primed for the next member -- retry the same
    // Read(data, size, ...) call from the top of the loop.
  }

  COM_TRY_END
}


Z7_COM7F_IMF(CRewindableDecodedStream::Seek(Int64 offset, UInt32 seekOrigin, UInt64 *newPosition))
{
  COM_TRY_BEGIN

  UInt64 target;
  switch (seekOrigin)
  {
    case STREAM_SEEK_SET:
      if (offset < 0)
        return HRESULT_WIN32_ERROR_NEGATIVE_SEEK;
      target = (UInt64)offset;
      break;

    case STREAM_SEEK_CUR:
    {
      const Int64 t = (Int64)_virtPos + offset;
      if (t < 0)
        return HRESULT_WIN32_ERROR_NEGATIVE_SEEK;
      target = (UInt64)t;
      break;
    }

    case STREAM_SEEK_END:
    {
      RINOK(EnsureTotalSizeKnown())
      const Int64 t = (Int64)_totalSize + offset;
      if (t < 0)
        return HRESULT_WIN32_ERROR_NEGATIVE_SEEK;
      target = (UInt64)t;
      break;
    }

    default:
      return STG_E_INVALIDFUNCTION;
  }

  _virtPos = target; // lazy: physical decode catches up in Read()/EnsureTotalSizeKnown()
  if (newPosition)
    *newPosition = _virtPos;
  return S_OK;

  COM_TRY_END
}


Z7_COM7F_IMF(CRewindableDecodedStream::GetSize(UInt64 *size))
{
  COM_TRY_BEGIN
  RINOK(EnsureTotalSizeKnown())
  *size = _totalSize;
  return S_OK;
  COM_TRY_END
}
