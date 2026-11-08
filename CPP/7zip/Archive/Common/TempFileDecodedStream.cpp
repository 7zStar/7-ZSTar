// TempFileDecodedStream.cpp -- 7-ZSTar: new file (M6b)
// See TempFileDecodedStream.h for the design.

#include "StdAfx.h"

#include "../../../Common/ComTry.h"

#ifndef Z7_NO_TAR_SNIFF
#include "../Tar/TarIn.h" // 7-ZSTar: M6b -- IsArc_Tar for TempFileDecodedStream_SniffTar()
#endif

#include "TempFileDecodedStream.h"

// Distinct prefix from this codebase's existing InOutTempBuffer.cpp
// ("7zt") so any leftover files (e.g. after a crash mid-decode -- the
// normal case is deleted via CTempFile's own destructor/Remove(), see the
// header comment on declaration order) are identifiable by origin.
#define kTempFilePrefixString FTEXT("7zsD")

namespace {

// 7-ZSTar: M6b -- a minimal local ISequentialOutStream wrapping a raw
// NIO::COutFile, just enough to hand decoder->Code() a write target.
// Deliberately not CPP/7zip/Common/FileStreams.h's own COutFileStream:
// that class (and the FileStreams.obj translation unit it lives in) has
// never been a dependency of the archive-format-handling code this file
// lives alongside (Format7zF.dll and friends decode/encode streams handed
// to them externally; writing extracted output to real files has always
// been the *caller's* job -- ArchiveExtractCallback.cpp et al, in a
// different link boundary) -- pulling in the whole class purely for this
// one Write() call would be a wider new dependency than this one small
// wrapper (mirrors what COutFileStream::Write() itself does).
Z7_CLASS_IMP_NOQIB_1(
  CLocalOutFileStream
  , ISequentialOutStream
)
public:
  NWindows::NFile::NIO::COutFile File;
};

Z7_COM7F_IMF(CLocalOutFileStream::Write(const void *data, UInt32 size, UInt32 *processedSize))
{
  UInt32 processed = 0;
#ifdef _WIN32
  const bool ok = File.Write(data, size, processed);
#else
  // 7-ZSTar: Linux port -- POSIX NIO::COutFile has write_full(), not Write().
  size_t p2 = 0;
  const ssize_t r = File.write_full(data, size, p2);
  const bool ok = (r != -1);
  processed = (UInt32)p2;
#endif
  if (processedSize)
    *processedSize = processed;
  return ok ? S_OK : GetLastError_noZero_HRESULT();
}


// 7-ZSTar: M6b fix (independent review Finding 2) -- fixed-size in-memory
// sink for TempFileDecodedStream_SniffTar()'s throwaway preview decode (see
// TempFileDecodedStream.h's comment on that function). Once full, Write()
// returns E_ABORT -- this codebase's standard "stop, the consumer doesn't
// want more" signal -- instead of copying anything further; the driving
// decoder is expected to (and, for every coder this is actually used with,
// does -- see the .h comment) treat that as a clean stop rather than a real
// I/O error.
const unsigned kSniffSize = 512;

Z7_CLASS_IMP_NOQIB_1(
  CSniffOutStream
  , ISequentialOutStream
)
public:
  Byte Buf[kSniffSize];
  UInt32 Got;
  CSniffOutStream(): Got(0) {}
};

Z7_COM7F_IMF(CSniffOutStream::Write(const void *data, UInt32 size, UInt32 *processedSize))
{
  if (Got >= kSniffSize)
  {
    if (processedSize)
      *processedSize = 0;
    return E_ABORT;
  }
  UInt32 cur = kSniffSize - Got;
  if (cur > size)
    cur = size;
  memcpy(Buf + Got, data, cur);
  Got += cur;
  if (processedSize)
    *processedSize = cur;
  return S_OK;
}

} // anonymous namespace


HRESULT TempFileDecodedStream_SniffTar(ICompressCoder *decoder,
    ISequentialInStream *packedStream, bool &isTar)
{
  isTar = false;

  // 7-ZSTar: M6b fix (Finding 2) -- force single-threaded decode for this
  // throwaway preview, if the coder supports it (the mcmilk/zstdmt-backed
  // brotli/lz4/lz5/lizard decoders do; the NZ::Decode() adapter has no MT
  // concept at all and simply doesn't implement ICompressSetCoderMt, so the
  // QueryInterface below fails harmlessly and this is a no-op for it).
  // Without this, an MT coder's worker-thread pool keeps every *other*
  // thread independently reading and decoding more input regardless of the
  // E_ABORT below -- only the one thread whose decoded frame currently
  // happens to be "next in line" to actually flush ever calls the write
  // callback that can signal stop (see e.g. C/zstdmt/lz4-mt_decompress.c's
  // pt_write()/pt_decompress() frame-ordering queue) -- so decode of the
  // rest of a large file would proceed anyway, just without writing it
  // anywhere, defeating the point of sniffing before committing to a full
  // decode. Forced to 1 thread, the same worker-loop code runs synchronously
  // on the calling thread instead (no pthread_create() at all -- see
  // LZ4MT_decompressDCtx() and its lz5/lizard/brotli twins), so the E_ABORT
  // below stops it immediately.
  {
    CMyComPtr<ICompressSetCoderMt> setMt;
    decoder->QueryInterface(IID_ICompressSetCoderMt, (void **)&setMt);
    if (setMt)
      setMt->SetNumberOfThreads(1);
  }

  CMyComPtr2_Create<ISequentialOutStream, CSniffOutStream> sink;

  const HRESULT hresCode = decoder->Code(packedStream, sink.Interface(), NULL, NULL, NULL);
  // 7-ZSTar: M6b fix (Finding 2) -- E_ABORT is *this function's own*
  // "got enough, stop" signal (CSniffOutStream::Write() above), not a real
  // error: swallow it, the same way RewindableDecodedStream_SniffTar()
  // swallows a decode error encountered while sniffing -- a genuine decode
  // error surfaces again, correctly, when the format is later opened as a
  // plain single-file archive instead of drilled into (see this function's
  // own .h comment). Any *other* non-S_OK is swallowed the same way and for
  // the same reason: a real decode error here just means "can't tell, so
  // not a tar", never a hard failure of the GetStream() call this feeds.
  if (hresCode == S_OK || hresCode == E_ABORT)
  {
#ifndef Z7_NO_TAR_SNIFF
    if (sink->Got == kSniffSize)
      isTar = (NArchive::NTar::IsArc_Tar(sink->Buf, sink->Got) == k_IsArc_Res_YES);
    // else: fewer than kSniffSize decoded bytes total -- too short to be a
    // valid tar (which always starts with one full 512-byte header block)
    // -- isTar stays false.
#endif
  }
  return S_OK;
}


HRESULT CTempFileDecodedStream::Init(ICompressCoder *decoder, ISequentialInStream *packedStream)
{
  CMyComPtr2_Create<ISequentialOutStream, CLocalOutFileStream> outStream;
#ifndef _WIN32
  // 7-ZSTar: the temp file holds decoded plaintext; keep it private to the user
  // (the default creation mode is 0666 & ~umask).
  outStream->File.mode_for_Create = 0600;
#endif
  if (!_tempFile.CreateRandomInTempFolder(kTempFilePrefixString, &outStream->File))
    return GetLastError_noZero_HRESULT();

  const HRESULT hresCode = decoder->Code(packedStream, outStream.Interface(), NULL, NULL, NULL);
  const bool closeOk = outStream->File.Close();
  RINOK(hresCode)
  if (!closeOk)
    return GetLastError_noZero_HRESULT();

  if (!_file.Open(_tempFile.GetPath()))
    return GetLastError_noZero_HRESULT();

  return S_OK;
}


Z7_COM7F_IMF(CTempFileDecodedStream::Read(void *data, UInt32 size, UInt32 *processedSize))
{
  COM_TRY_BEGIN
  UInt32 processed = 0;
#ifdef _WIN32
  const bool ok = _file.Read(data, size, processed);
#else
  // 7-ZSTar: Linux port -- POSIX NIO::CInFile has read_part(), not Read().
  // A short read is allowed by ISequentialInStream::Read.
  const ssize_t r = _file.read_part(data, size);
  const bool ok = (r != -1);
  if (ok) processed = (UInt32)r;
#endif
  if (processedSize)
    *processedSize = processed;
  return ok ? S_OK : GetLastError_noZero_HRESULT();
  COM_TRY_END
}


Z7_COM7F_IMF(CTempFileDecodedStream::Seek(Int64 offset, UInt32 seekOrigin, UInt64 *newPosition))
{
  COM_TRY_BEGIN
  if (seekOrigin >= 3)
    return STG_E_INVALIDFUNCTION;
  UInt64 realNewPosition = 0;
#ifdef _WIN32
  const bool ok = _file.Seek(offset, seekOrigin, realNewPosition);
#else
  // 7-ZSTar: Linux port -- POSIX CFileBase::seek(); origin 0/1/2 == SEEK_SET/CUR/END.
  const off_t r = _file.seek((off_t)offset, (int)seekOrigin);
  const bool ok = (r != (off_t)-1);
  if (ok) realNewPosition = (UInt64)r;
#endif
  if (newPosition)
    *newPosition = realNewPosition;
  return ok ? S_OK : GetLastError_noZero_HRESULT();
  COM_TRY_END
}


Z7_COM7F_IMF(CTempFileDecodedStream::GetSize(UInt64 *size))
{
  COM_TRY_BEGIN
  return _file.GetLength(*size) ? S_OK : GetLastError_noZero_HRESULT();
  COM_TRY_END
}
