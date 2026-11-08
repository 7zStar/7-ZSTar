// TempFileDecodedStream.h -- 7-ZSTar: new file (M6b)
//
// CTempFileDecodedStream: for coders that only support "push" mode
// (ICompressCoder::Code(inStream, outStream, ...), no pull-mode
// ISequentialInStream of their own -- confirmed (M6b survey) for
// the compress/.Z decoder (ZDecoder.h: not even a COM object -- a bare
// Code() method of NCompress::NZ::CDecoder up to 26.04, the free function
// NCompress::NZ::Decode() since 26.05 -- no ICompressCoder at all) and the
// M6a NCompress::NBROTLI/NLZ4/NLZ5/NLizard::CDecoder classes (their
// CodeSpec() drives an internal zstdmt worker-thread pool via read/write
// callbacks; they expose ICompressSetInStream + SetOutStreamSize but *not*
// ISequentialInStream, so they cannot plug into
// RewindableDecodedStream.h's pull-mode contract -- see each one's own
// header comment)), CRewindableDecodedStream's approach isn't available.
//
// This wraps such a decoder differently, and much more simply: decode the
// *entire* packed stream to a temp file synchronously inside Init(), then
// hand back a plain seekable read view of that temp file. All the
// rewind/seek bookkeeping CRewindableDecodedStream has to implement itself
// (lazy forward skip, rewind-and-redecode from scratch, total-size
// tracking, ...) isn't needed here: once the decoded output is a real
// file, ordinary filesystem Seek()/GetLength() handle arbitrary access
// natively and correctly. The trade-off is the one-time cost of decoding
// fully upfront (no lazy/partial decode) and using temporary disk space
// for the full decoded size, for as long as this object is alive.
//
// Deliberately chosen over a worker-thread + CStreamBinder push-to-pull
// pipe adapter (the technique TarChainHandler.cpp's *encode* side uses:
// tar formatting on one thread pushing into a compressor's Code() pulling
// on another) for the formats this is actually used for: NZ (.Z/
// "compress", a legacy format with no encoder anywhere in this project)
// and the four M6a mcmilk codecs (brotli/lz4/lz5/lizard -- not a
// widely-used tar-chaining convention in practice, unlike gz/bz2/xz/zstd).
// A pipe adapter would need its thread+pipe torn down and rebuilt from
// scratch on *every* rewind -- and the kpidMainSubfile drill-down path
// performs several per open (tar sniff, GetSize scan, header parse; see
// RewindableDecodedStream.h's own header comment on M5's measured pass
// counts) -- which is meaningfully more failure-prone (thread lifecycle,
// cancellation, deadlock-on-error edge cases) than this, for a fallback
// path covering lower-traffic formats. "Zero intermediate file" (the
// actual point of CRewindableDecodedStream, for zstd/gzip/bzip2/lzma,
// whose real-world .tar.<ext> pipelines are extremely common) is
// deliberately not preserved here -- see the M6b commit/CONTEXT notes for
// the full trade-off writeup.

#ifndef ZIP7_INC_TEMP_FILE_DECODED_STREAM_H
#define ZIP7_INC_TEMP_FILE_DECODED_STREAM_H

#include "../../../Common/MyCom.h"

#include "../../../Windows/FileDir.h"

#include "../../IStream.h"
#include "../../ICoder.h"

class CTempFileDecodedStream Z7_final:
  public IInStream,
  public IStreamGetSize,
  public CMyUnknownImp
{
  Z7_COM_UNKNOWN_IMP_3(IInStream, ISequentialInStream, IStreamGetSize)
  Z7_IFACE_COM7_IMP(ISequentialInStream)
  Z7_IFACE_COM7_IMP(IInStream)
  Z7_IFACE_COM7_IMP(IStreamGetSize)

  // Declaration order is load-bearing: C++ destroys members in *reverse*
  // declaration order, and NWindows::NFile::NDir::CTempFile::~CTempFile()
  // deletes the file by *path* (DeleteFileAlways(), not handle-based) --
  // deleting a still-open file this way silently fails and leaks the temp
  // file. So _tempFile (declared first) must destruct *last*, after _file
  // (declared second, so it destructs *first* and closes the handle via
  // its own inherited CFileBase::~CFileBase()). Same ordering, same
  // reasoning, as this codebase's existing InOutTempBuffer.h.
  NWindows::NFile::NDir::CTempFile _tempFile;
  NWindows::NFile::NIO::CInFile _file;

public:
  // decoder: any fully-configured push-mode ICompressCoder (whatever
  // one-time setup that coder type needs -- props, thread count, etc --
  // already done by the caller, same convention as
  // RewindableDecodedStream.h's Init()). packedStream: the compressed
  // byte stream to decode; Code() consumes it starting from its current
  // position. By the time this returns S_OK, decoding is already fully
  // complete -- there is no lazy/background work left for Read()/Seek()
  // to do afterward.
  HRESULT Init(ICompressCoder *decoder, ISequentialInStream *packedStream);
};


// 7-ZSTar: M6b fix (independent review Finding 2) -- every one of this
// file's five callers (ZHandler.cpp, BrotliHandler.cpp, Lz4Handler.cpp,
// Lz5Handler.cpp, LizardHandler.cpp) used to call CTempFileDecodedStream::
// Init() -- a full, synchronous, unbounded decode to a temp file -- *before*
// checking (via RewindableDecodedStream_SniffTar(), on the now-fully-decoded
// result) whether the content was even a tar in the first place. For the
// common case of a large non-tar file in one of these five formats, that
// meant paying the full decode cost (and disk space, and an unresponsive
// UI/CLI -- no cancellation is wired through Code() here) just to then
// throw the result away and report "not a tar, show as a single file".
//
// This function peeks at only the first 512 decoded bytes -- via a throwaway
// decoder and a fixed-size in-memory sink that signals E_ABORT (this
// codebase's standard "the consumer doesn't want more, stop" HRESULT --
// e.g. every mcmilk-derived CDecoder's Write callback shim already maps it
// straight to that library's own cancellation path) once it has enough --
// and reports whether those 512 bytes look like a tar header block. It does
// NOT create a temp file, and for the four mcmilk/zstdmt-backed coders
// (brotli/lz4/lz5/lizard) it also forces single-threaded decode for this
// call specifically (see the .cpp) so the E_ABORT cutoff actually stops
// decode work promptly -- without that, those coders' worker-thread pools
// keep independently decoding (just not *writing*) the rest of a large file
// regardless of the abort, since only the one thread whose output happens
// to be "next in line" ever calls back into the sink that's signaling stop.
//
// `decoder` and `packedStream` are consumed by this call (an unknown,
// format-dependent number of bytes/decoder-internal-state) and must be
// discarded afterward either way -- construct fresh ones (and Seek()
// `packedStream` back to its start) for the real CTempFileDecodedStream::
// Init() call that follows when isTar comes back true. See each handler's
// GetStream() for the concrete before/after call pattern.
HRESULT TempFileDecodedStream_SniffTar(ICompressCoder *decoder,
    ISequentialInStream *packedStream, bool &isTar);

#endif
