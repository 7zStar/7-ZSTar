// RewindableDecodedStream.h -- 7-ZSTar: new file (M5; generalized M6b)
//
// CRewindableDecodedStream: wraps a seekable *compressed* IInStream as a
// seekable *decoded* IInStream, by driving any coder that implements the
// "pull" trio -- ICompressSetInStream + ICompressSetOutStreamSize +
// ISequentialInStream::Read -- confirmed (M6b) for:
//   NCompress::NZstd::CDecoder          (zstd,   M5)
//   NCompress::NDeflate::NDecoder::CCoder (gzip's raw deflate stream, M6b)
//   NCompress::NBZip2::CDecoder          (bzip2,  M6b)
//   NCompress::NLzma::CDecoder           (lzma alone, M6b)
// (every one of these is only compiled without its pull trio when
// Z7_NO_READ_FROM_CODER[_ZSTD] is defined -- true today only for the
// SFX-only bundles, which never link any Archive/*Handler.obj that could
// construct this class in the first place; see each handler's GetStream()
// for the QueryInterface that would surface E_NOINTERFACE if that ever
// changed).
//
// M5 originally hard-coded NCompress::NZstd::CDecoder as a member. M6b
// generalizes that away: this class now knows nothing about which coder is
// behind the three interface pointers it's given -- Init()'s caller
// (each format handler's own GetStream()) is responsible for constructing
// the concrete decoder object, performing whatever one-time setup *that*
// coder type needs before its first Read() (FinishMode/DisableHash for
// zstd; SetDecoderProperties2() for lzma; DecodeAllStreams for bzip2;
// nothing extra for gzip's raw deflate coder -- see each handler's
// GetStream() for the specifics), and then handing over the three
// interfaces via Init(). This class drives only SetInStream() (once) and
// SetOutStreamSize() (on every rewind) itself from then on -- callers must
// not call either of those two themselves after Init().
//
// This is what makes "one-step extraction of a tar wrapped in a supported
// single-file compressor" possible: it is the object each format handler's
// own CHandler::GetStream() hands to CArchiveLink::Open()'s kpidMainSubfile
// auto-drill-down (CPP/7zip/UI/Common/OpenArchive.cpp:~3232), so opening
// e.g. a *.tar.zst/*.tar.gz/*.tar.bz2/*.tar.lzma file drills straight into
// the tar layer -- no intermediate file, no buffering of the whole decoded
// stream.
//
// Compressed streams in general are not randomly seekable, so:
//   - Forward Seek() is lazy: only the caller-visible virtual position
//     (_virtPos) moves. The gap is decoded-and-discarded the next time real
//     bytes are actually needed (from Read(), or from a SEEK_END/GetSize()
//     that must first learn the total size).
//   - Backward Seek() (target < the physical decode position) rewinds the
//     *packed* stream back to _startPos and re-primes decode state from
//     scratch (via SetOutStreamSize(NULL) -- see the header comment on
//     _decoderSetOutSize below for why that call is what resets each
//     supported coder type fully), then re-decodes forward (lazily, as
//     above) up to the new position. There is no decoded-data cache of any
//     kind: memory use is O(1) -- one fixed-size scratch buffer -- decode
//     cost is O(bytes re-decoded across the stream's lifetime), i.e. every
//     rewind repays the *entire* prefix again. This is an accepted,
//     measured trade-off (see M5 CONTEXT/commit notes for the actual pass
//     counts), not an oversight -- avoiding it would mean caching decoded
//     output to disk, which is out of scope for this milestone.
//   - STREAM_SEEK_END *and* IStreamGetSize::GetSize() both need the total
//     decoded size. GetSize() matters in practice, not just as a nicety:
//     StreamUtils.h's InStream_AtBegin_GetSize() tries IStreamGetSize
//     first on _WIN32 (falling back to Seek(END) only if that QI fails),
//     and CPP/7zip/Archive/Tar/TarHandler.cpp's CHandler::Open2() calls
//     InStream_AtBegin_GetSize() as the very first thing it does on any
//     stream it opens -- so implementing only Seek(END) would leave the
//     common tar-opening path silently falling through to it anyway, but
//     implementing GetSize() is one extra trivial method and matches the
//     "normal" path exactly. Either way the total size is learned by
//     decoding to the real end at least once (frames/members written by
//     streaming/piped encoders -- bsdtar, `zstd < in`, etc. -- commonly
//     omit an upfront content size, so a format's self-declared size, if
//     any, cannot be trusted blindly -- see M0's "unknown-content-size"
//     finding and CFrameHeader in ZstdHandler.cpp) and is then cached for
//     the lifetime of this object.

#ifndef ZIP7_INC_REWINDABLE_DECODED_STREAM_H
#define ZIP7_INC_REWINDABLE_DECODED_STREAM_H

#include "../../../Common/MyBuffer.h"
#include "../../../Common/MyCom.h"

#include "../../IStream.h"
#include "../../ICoder.h"

// 7-ZSTar: M6b fix (independent review Finding 1) -- optional per-format
// helper for compressed containers that support concatenated ("multi-
// member") streams: plain gzip and lzma-alone, confirmed (review3) to
// silently truncate after the first member without this, because
// CRewindableDecodedStream's Read()/SkipDecode() previously treated the
// wrapped decoder reporting "no more data" (0 bytes processed) as
// unconditional end-of-stream -- correct for a lone member, wrong for a
// second (or later) one still to come. bzip2 needs no such helper: its own
// NCompress::NBZip2::CDecoder handles concatenated streams internally via
// Base.DecodeAllStreams (see Bz2Handler.cpp's GetStream()); zstd's frame
// format is simply never produced multi-frame by this project's own
// pipelines. See GzHandler.cpp's and LzmaHandler.cpp's GetStream() for the
// concrete implementations, which mirror -- member-loop-iteration for
// member-loop-iteration -- what each format's own two-step Extract()
// already does to decode a second member with the same decoder object;
// that path is the proof the technique is correct.
//
// Ownership: CRewindableDecodedStream takes ownership of whatever is
// passed to Init() (deletes it in its own destructor).
class IRewindableMemberContinuation
{
public:
  virtual ~IRewindableMemberContinuation() {}

  // Called only when the wrapped decoder's Read() has just reported it has
  // no more data for the CURRENT member (0 bytes processed, S_OK) --
  // *before* CRewindableDecodedStream treats that as true end-of-stream.
  // Must determine, using only the *same* underlying decoder object it was
  // constructed with (never by touching the outer packed IInStream's raw
  // seek position directly -- compressed-format decoders commonly read
  // ahead into their own internal buffer, so the outer stream's physical
  // position is usually well past the true end of the just-finished
  // member; only the decoder's own buffered reader knows the real
  // boundary), whether a complete next member immediately follows.
  //
  // On S_OK: *hasNext == true means a next member's header was found and
  // parsed, AND the decoder has already been re-primed (per-member decode
  // state reset, the same primitive each format's own CodeResume() uses
  // internally for member 2+) so the very next _decoderRead->Read() call
  // decodes it. *hasNext == false means a clean end (no more members, or
  // trailing bytes that don't form a valid next header) -- not an error,
  // same convention as RewindableDecodedStream_SniffTar() below. A non-S_OK
  // return is a real I/O/decode error.
  virtual HRESULT TryStartNextMember(bool &hasNext) = 0;
};


class CRewindableDecodedStream Z7_final:
  public IInStream,
  public IStreamGetSize,
  public CMyUnknownImp
{
  Z7_COM_UNKNOWN_IMP_3(IInStream, ISequentialInStream, IStreamGetSize)
  Z7_IFACE_COM7_IMP(ISequentialInStream)
  Z7_IFACE_COM7_IMP(IInStream)
  Z7_IFACE_COM7_IMP(IStreamGetSize)

  CMyComPtr<IInStream> _packedStream;
  UInt64 _startPos;

  // The caller-supplied decoder, reached only through these three
  // interfaces -- never through a concrete class pointer (this class does
  // not know, and does not need to know, the concrete decoder type).
  // Holding _decoderRead (any *one* of a COM object's supported interfaces
  // keeps the whole object alive, under this codebase's shared-refcount
  // CMyUnknownImp/Z7_COM_UNKNOWN_IMP_* convention -- there is no
  // per-interface sub-object refcounting here) is what keeps the decoder
  // object alive for the lifetime of this wrapper; callers do not need to
  // (and should not) keep their own reference just for that purpose.
  CMyComPtr<ISequentialInStream> _decoderRead;
  CMyComPtr<ICompressSetInStream> _decoderSetInStream;
  CMyComPtr<ICompressSetOutStreamSize> _decoderSetOutSize;

  UInt64 _virtPos;     // caller-visible logical position in the decoded stream
  UInt64 _decodedPos;  // physical position the decoder has actually reached
                        // since the last (re)start; always <= real total size
  bool _primed;        // false until _packedStream has been positioned at
                        // _startPos and the decoder (re)initialized at least once

  bool _totalSizeKnown;
  UInt64 _totalSize;

  CByteBuffer _skipBuf; // fixed-size scratch buffer for decode-and-discard;
                         // never grows to hold more than kSkipBufSize bytes
                         // regardless of how much is skipped/measured

  // 7-ZSTar: M6b fix (independent review Finding 1) -- optional, owned
  // (deleted by ~CRewindableDecodedStream()); NULL for formats with no
  // multi-member concept (or that handle it internally -- bzip2) that never
  // pass one to Init(). See IRewindableMemberContinuation above.
  IRewindableMemberContinuation *_continuation;

  HRESULT Rewind();
  HRESULT SkipDecode(UInt64 count);
  HRESULT SyncDecoderTo_VirtPos();
  HRESULT EnsureTotalSizeKnown();
  HRESULT TryContinueToNextMember(bool &hasNext); // wraps _continuation (NULL check + the call)

public:
  CRewindableDecodedStream():
      _startPos(0),
      _virtPos(0),
      _decodedPos(0),
      _primed(false),
      _totalSizeKnown(false),
      _totalSize(0),
      _continuation(NULL)
      {}

  ~CRewindableDecodedStream() { delete _continuation; }

  // packedStream: the compressed byte stream, seekable; startPos is the
  // byte offset in it where the *decoder's own expected input* begins --
  // NOT necessarily offset 0. This varies by format and is the caller's
  // (each handler's GetStream()) responsibility to get right:
  //   - zstd, bzip2: 0 -- these decoders parse their own format's framing
  //     (frame header / "BZh" signature) as part of decoding, so they
  //     expect the raw file from the very first byte.
  //   - gzip: the handler's already-computed header-end offset (see
  //     GzHandler.cpp's _headerSize, produced by CItem::ReadHeader()
  //     through the *same* decoder-object-as-byte-reader trick the normal
  //     Open()/Extract() path already uses) -- NCompress::NDeflate's coder
  //     is a *raw deflate* decoder with no knowledge of the gzip
  //     header/trailer wrapper around it.
  //   - lzma (alone format): the handler's fixed header size (13 bytes:
  //     5-byte props + 8-byte size, for the plain non-lzma86 variant) --
  //     NCompress::NLzma::CDecoder decodes a raw LZMA stream and expects
  //     SetDecoderProperties2() to have already been called (once, by the
  //     caller, before Init()) with the 5 props bytes read from that
  //     header; it does not parse them itself.
  //
  // decoderRead/decoderSetInStream/decoderSetOutSize: the three pull-mode
  // interfaces of a single already-constructed decoder object, obtained via
  // QueryInterface (see RewindableDecodedStream_GetPullInterfaces() below
  // for a shared helper that does this with the right E_NOINTERFACE
  // fallback). The object must already be fully configured for anything
  // *other* than SetInStream/SetOutStreamSize -- this class calls only
  // those two (SetInStream once, here in Init(); SetOutStreamSize on every
  // (re)start, including this first one) and Read() repeatedly.
  //
  // continuation: optional (default NULL); see IRewindableMemberContinuation
  // above. Pass one only for formats that support concatenated multi-member
  // streams and need help detecting/resuming across the boundary (gzip,
  // lzma-alone today); leave NULL for everything else (single-member-only
  // formats, and bzip2 which handles it without this). Ownership transfers
  // to this object immediately (even if this call goes on to fail).
  HRESULT Init(IInStream *packedStream, UInt64 startPos,
      ISequentialInStream *decoderRead,
      ICompressSetInStream *decoderSetInStream,
      ICompressSetOutStreamSize *decoderSetOutSize,
      IRewindableMemberContinuation *continuation = NULL);
};


// Shared helper for each format handler's GetStream(): QueryInterface the
// three pull-mode interfaces off a freshly-constructed decoder object in
// one place, with the same "return E_NOINTERFACE if any is missing" policy
// M5 originally had inline in CRewindableDecodedStream::Init() itself.
// Unreachable in practice for every coder type actually passed to this
// today (see the file header comment), but checked anyway rather than risk
// a null-pointer call if that ever changes.
HRESULT RewindableDecodedStream_GetPullInterfaces(IUnknown *decoder,
    CMyComPtr<ISequentialInStream> &decoderRead,
    CMyComPtr<ICompressSetInStream> &decoderSetInStream,
    CMyComPtr<ICompressSetOutStreamSize> &decoderSetOutSize);


// Shared helper for each format handler's GetStream(): decides whether a
// freshly-Init()-ed decoded stream (positioned at 0) looks like a tar
// archive, by decoding one 512-byte header block and checking it with
// NArchive::NTar::IsArc_Tar() (magic + checksum, so V7 tars pass too) --
// *before* handing the stream to CArchiveLink::Open()'s drill-down
// machinery, which starts with a GetSize() (a full decode-to-end pass) and
// can rewind again per failing sub-format probe. For the common "just a
// compressed file, not a tar" case that full-decode cost is pure waste, and
// it is not cancellable from the UI -- one decoded 512-byte block decides
// it instead. Restores position to 0 on either outcome (S_OK, isTar either
// way) so the caller can hand the same stream onward unconditionally.
// Decode errors during the sniff read are deliberately swallowed (they just
// mean "not a tar"; a broken file still reports its real error on the
// normal single-file open path -- same policy as
// TempFileDecodedStream_SniffTar). Non-S_OK only means the position-restore
// Seek itself failed.
HRESULT RewindableDecodedStream_SniffTar(IInStream *decodedStream, bool &isTar);

#endif
