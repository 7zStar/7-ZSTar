// TarChainHandler.h -- 7-ZSTar: new file (M4)
//
// CTarChainHandler: a composite IOutArchive that produces a one-step
// *.tar.zst archive -- zero intermediate .tar file, zero full-archive
// buffering. tar's own output stream is piped, via the existing
// CStreamBinder zero-copy rendezvous primitive (CPP/7zip/Common/StreamBinder.h),
// directly into a compression coder (zstd for M4) running on a worker
// thread, while the real NArchive::NTar::CHandler drives item enumeration
// and serialization on the calling thread exactly as it would for a plain
// "-ttar" archive (so callback/UI-thread affinity for
// IArchiveUpdateCallback is preserved). See TarChainHandler.cpp for the
// pipeline itself.
//
// This handler only ever appears as the *output* side of *.tar.zst. Opening
// existing *.tar.zst files is intentionally left entirely to the existing
// zstd format handler (Archive/ZstdHandler.cpp), which already opens any
// .zst stream and shows its one logical member; one-step *extraction* of
// the tar member is M5 territory. CStubInArchive (TarChainRegister.cpp)
// exists only because RegisterArc()'s CArcInfo contract requires a non-NULL
// CreateInArchive -- its Open() unconditionally returns S_FALSE so the two
// format handlers never compete to open the same file.
//
// See TarChainRegister.cpp for how *.tar.zst is registered as its own
// archive format (Byte Id 0x20; 7-ZSTar reserves 0x20-0x2F for this
// TarChain family -- see CPP/7zip/Guid.txt).

#ifndef ZIP7_INC_TAR_CHAIN_HANDLER_H
#define ZIP7_INC_TAR_CHAIN_HANDLER_H

#include "../../../Common/MyCom.h"

#include "../Common/HandlerOut.h"

#include "../Tar/TarHandler.h"

namespace NArchive {
namespace NTarChain {

// Which downstream compression coder UpdateItems() pipes tar's output
// through. M4 only ever constructs kCodec_Zstd; this enum (and the
// CTarChainHandler constructor parameter carrying it) exists so that M6 can
// add siblings (tar.br, tar.lz4, ...) by adding rows in
// TarChainRegister.cpp, without changing CTarChainHandler's shape.
// 7-ZSTar: M6a -- added kCodec_Lz4/Lz5/Lizard/Brotli (see TarChainHandler.cpp's
// UpdateItems() switch and TarChainRegister.cpp for the matching format rows).
// 7-ZSTar: M6b -- added kCodec_Gzip/Bzip2/Xz (official-format encoders, all
// three with a complete existing single-file out-archive path to mirror --
// GzHandler.cpp/Bz2Handler.cpp/XzHandler.cpp's own UpdateArchive()/
// UpdateItems(). kCodec_Lzma deliberately *not* added: LzmaHandler.cpp's
// plain "lzma" format is registered IInArchive-only (REGISTER_ARC_I_CLS_NO_SIG,
// no IOutArchive at all) -- there is no existing lzma-alone writer anywhere
// in this project to mirror, and hand-rolling one (the format's 13-byte
// header has to be written before the compressed body even starts) is a
// materially bigger, less-precedented undertaking than wiring up an
// already-complete path; left out of scope for this milestone, see M6b
// CONTEXT notes.
enum ETarChainCodec
{
  kCodec_Zstd,
  kCodec_Lz4,
  kCodec_Lz5,
  kCodec_Lizard,
  kCodec_Brotli,
  kCodec_Gzip,
  kCodec_Bzip2,
  kCodec_Xz
};

Z7_CLASS_IMP_COM_2(CTarChainHandler, IOutArchive, ISetProperties)

  const ETarChainCodec _codec;

  // The real tar producer: drives item enumeration/serialization (and
  // hence all calls back into the caller's IArchiveUpdateCallback) on
  // whichever thread calls this->UpdateItems(). Constructed once, up
  // front (CMyComPtr2_Create's default ctor), and reused across the
  // SetProperties() -> GetFileTimeType() -> UpdateItems() call sequence
  // the update engine makes on a freshly-created CTarChainHandler.
  CMyComPtr2_Create<IOutArchive, NArchive::NTar::CHandler> _tarHandler;
  CMyComPtr<ISetProperties> _tarSetProps;   // QI'd from _tarHandler once, in the constructor

  // Compression-side properties: collected by SetProperties(), consumed by
  // UpdateItems() when it constructs the coder for _codec.
  CSingleMethodProps _encProps;

public:
  explicit CTarChainHandler(ETarChainCodec codec);
};

}}

#endif
