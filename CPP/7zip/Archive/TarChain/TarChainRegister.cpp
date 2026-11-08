// TarChainRegister.cpp -- 7-ZSTar: new file (M4)
//
// Registers "tar.zst" as its own archive format. See TarChainHandler.h for
// the composite out-archive handler itself and for why CStubInArchive
// exists, and CPP/7zip/Guid.txt for the Byte Id registry entry (7-ZSTar
// reserves 0x20-0x2F for this TarChain format family).
//
// REGISTER_ARC_IO (RegisterArc.h) can't be used here: it hardcodes a
// no-argument "CHandler" as both the in- and out-archive class, but this
// format needs two *different*, purpose-built classes (CStubInArchive,
// CTarChainHandler) -- so the CArcInfo and its factory functions are
// written out by hand instead, following the same shape REGISTER_ARC_IO
// itself expands to.

#include "StdAfx.h"

#include "../../../Common/MyCom.h"

#include "../../Common/RegisterArc.h"

#include "TarChainHandler.h"

namespace NArchive {
namespace NTarChain {

// ---- CStubInArchive: see TarChainHandler.h's file header comment for why
//      this exists. Open() unconditionally returns S_FALSE ("not this
//      format"); every other method returns either a harmless empty/zero
//      value (informational queries) or E_NOTIMPL (real operations), since
//      none of them can ever be reached on an archive that never opens. ----

Z7_CLASS_IMP_COM_1(CStubInArchive, IInArchive)
};

Z7_COM7F_IMF(CStubInArchive::Open(IInStream *, const UInt64 *, IArchiveOpenCallback *))
{
  return S_FALSE;
}

Z7_COM7F_IMF(CStubInArchive::Close())
{
  return S_OK;
}

Z7_COM7F_IMF(CStubInArchive::GetNumberOfItems(UInt32 *numItems))
{
  *numItems = 0;
  return S_OK;
}

Z7_COM7F_IMF(CStubInArchive::GetProperty(UInt32, PROPID, PROPVARIANT *value))
{
  NWindows::NCOM::CPropVariant prop;
  prop.Detach(value);
  return S_OK;
}

Z7_COM7F_IMF(CStubInArchive::Extract(const UInt32 *, UInt32, Int32, IArchiveExtractCallback *))
{
  return E_NOTIMPL;
}

Z7_COM7F_IMF(CStubInArchive::GetArchiveProperty(PROPID, PROPVARIANT *value))
{
  NWindows::NCOM::CPropVariant prop;
  prop.Detach(value);
  return S_OK;
}

Z7_COM7F_IMF(CStubInArchive::GetNumberOfProperties(UInt32 *numProps))
{
  *numProps = 0;
  return S_OK;
}

Z7_COM7F_IMF(CStubInArchive::GetPropertyInfo(UInt32, BSTR *, PROPID *, VARTYPE *))
{
  return E_NOTIMPL;
}

Z7_COM7F_IMF(CStubInArchive::GetNumberOfArchiveProperties(UInt32 *numProps))
{
  *numProps = 0;
  return S_OK;
}

Z7_COM7F_IMF(CStubInArchive::GetArchivePropertyInfo(UInt32, BSTR *, PROPID *, VARTYPE *))
{
  return E_NOTIMPL;
}


// ---- format registration ----
//
// Func_CreateInArchive / Func_CreateOutArchive are bare `X *(*)()` (see
// IArchive.h) -- a factory function can't close over "which codec to use",
// so each TarChain-family format needs its own tiny pair of trampolines.
// With exactly one format in M4 this is a single pair; M6 adding a sibling
// (tar.br, tar.lz4, ...) means adding one more CreateArc*/CreateArcOut*
// pair + one more g_ArcInfo_*/CRegisterTarChain_* block below, not
// restructuring this file or CTarChainHandler.

static IInArchive *CreateArc_TarZst() { return new CStubInArchive(); }
static IOutArchive *CreateArcOut_TarZst() { return new CTarChainHandler(kCodec_Zstd); }

static IInArchive *CreateArc_TarBr() { return new CStubInArchive(); }
static IOutArchive *CreateArcOut_TarBr() { return new CTarChainHandler(kCodec_Brotli); }

// 7-ZSTar: M6a -- tar.lz4 sibling (see TarChainHandler.h's ETarChainCodec
// and this file's header comment for the "one CreateArc*/CreateArcOut* pair
// per family member" shape this was built for).
static IInArchive *CreateArc_TarLz4() { return new CStubInArchive(); }
static IOutArchive *CreateArcOut_TarLz4() { return new CTarChainHandler(kCodec_Lz4); }

static IInArchive *CreateArc_TarLz5() { return new CStubInArchive(); }
static IOutArchive *CreateArcOut_TarLz5() { return new CTarChainHandler(kCodec_Lz5); }

static IInArchive *CreateArc_TarLiz() { return new CStubInArchive(); }
static IOutArchive *CreateArcOut_TarLiz() { return new CTarChainHandler(kCodec_Lizard); }

// 7-ZSTar: M6b -- tar.gz/tar.bz2/tar.xz (official-format encoders; see
// TarChainHandler.h's ETarChainCodec comment for why tar.lzma has no
// sibling here).
static IInArchive *CreateArc_TarGz() { return new CStubInArchive(); }
static IOutArchive *CreateArcOut_TarGz() { return new CTarChainHandler(kCodec_Gzip); }

static IInArchive *CreateArc_TarBz2() { return new CStubInArchive(); }
static IOutArchive *CreateArcOut_TarBz2() { return new CTarChainHandler(kCodec_Bzip2); }

static IInArchive *CreateArc_TarXz() { return new CStubInArchive(); }
static IOutArchive *CreateArcOut_TarXz() { return new CTarChainHandler(kCodec_Xz); }

// 7-ZSTar reserves Byte Id 0x20-0x2F for the TarChain format family (see
// CPP/7zip/Guid.txt); tar.zst is the first (M4). M6a adds tar.br=0x21,
// tar.lz4=0x22, tar.lz5=0x23, tar.liz=0x24 (task-specified allocation; note
// this is the *archive-format* Byte Id namespace -- CArcInfo::Id, distinct
// from the .7z *internal coder-method* id namespace -- CCodecInfo::Id/
// CMethodId used by 7zHeader.h's k_LZMA2=0x21 and RegisterCodec.h -- so
// 0x21 appearing in both is not a collision). M6b adds tar.gz=0x25,
// tar.bz2=0x26, tar.xz=0x27 (0x28, earmarked for a future tar.lzma, is
// deliberately left unused -- see TarChainHandler.h).
static const Byte k_TarZst_Id = 0x20;
static const Byte k_TarBr_Id = 0x21;
static const Byte k_TarLz4_Id = 0x22;
static const Byte k_TarLz5_Id = 0x23;
static const Byte k_TarLiz_Id = 0x24;
static const Byte k_TarGz_Id = 0x25;
static const Byte k_TarBz2_Id = 0x26;
static const Byte k_TarXz_Id = 0x27;

static const CArcInfo g_ArcInfo_TarZst =
{
  // Flags: deliberately *not* kKeepName (tar.zst is a real multi-file
  // container format, unlike e.g. gzip/bzip2/xz's "keep the source file's
  // name" single-file-compressor convention) -- this is also what lets it
  // pass UpdateGUI.cpp's format-dropdown filter (`if (!oneFile &&
  // ai.Flags_KeepName()) continue;`) unmodified. kByExtOnlyOpen: harmless
  // no-op given CStubInArchive::Open() never succeeds regardless, but
  // avoids uselessly invoking it during format auto-detection for every
  // file that *doesn't* end in .tar.zst. kSymLinks/kHardLinks/kMTime/
  // kMTime_Default: copied from tar's own registration (TarRegister.cpp) --
  // tar.zst's *content* has exactly the same metadata capabilities as
  // plain tar, so it should advertise the same ones (unlike kStartOpen,
  // which is open-side-specific and doesn't apply here).
  NArcInfoFlags::kByExtOnlyOpen
    | NArcInfoFlags::kSymLinks
    | NArcInfoFlags::kHardLinks
    | NArcInfoFlags::kMTime
    | NArcInfoFlags::kMTime_Default,
  k_TarZst_Id,
  0, 0,                          // SignatureSize, SignatureOffset: no signature (Open() never succeeds anyway)
  NULL,                          // Signature
  "tar.zst",                     // Name
  "tar.zst",                     // Ext -- deliberately one token, not "tar.zst tzst": "tzst" is already
                                  // ZstdHandler.cpp's own extension (REGISTER_ARC_IO "zst tzst"); keeping
                                  // tar.zst's own Ext to just "tar.zst" avoids overlapping that.
  NULL,                          // AddExt
  TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::kWindows)
    | TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::kUnix)
    | TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::k1ns)
    | TIME_PREC_TO_ARC_FLAGS_TIME_DEFAULT (NFileTimeType::kUnix),
  CreateArc_TarZst,
  CreateArcOut_TarZst,
  NULL                           // IsArc: matches ZstdHandler.cpp's own "zstd" registration (also NULL) --
                                  // CStubInArchive never opens anything, so there's no quick pre-check to offer.
};

struct CRegisterTarChain_TarZst { CRegisterTarChain_TarZst() { RegisterArc(&g_ArcInfo_TarZst); } };
static CRegisterTarChain_TarZst g_RegisterTarChain_TarZst;

// 7-ZSTar: M6a -- tar.br.
static const CArcInfo g_ArcInfo_TarBr =
{
  NArcInfoFlags::kByExtOnlyOpen
    | NArcInfoFlags::kSymLinks
    | NArcInfoFlags::kHardLinks
    | NArcInfoFlags::kMTime
    | NArcInfoFlags::kMTime_Default,
  k_TarBr_Id,
  0, 0,
  NULL,
  "tar.br",
  "tar.br",                      // Ext -- one token; "tbr" is BrotliHandler.cpp's own
                                  // extension (REGISTER_ARC_R "br brotli tbr").
  NULL,
  TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::kWindows)
    | TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::kUnix)
    | TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::k1ns)
    | TIME_PREC_TO_ARC_FLAGS_TIME_DEFAULT (NFileTimeType::kUnix),
  CreateArc_TarBr,
  CreateArcOut_TarBr,
  NULL
};

struct CRegisterTarChain_TarBr { CRegisterTarChain_TarBr() { RegisterArc(&g_ArcInfo_TarBr); } };
static CRegisterTarChain_TarBr g_RegisterTarChain_TarBr;

// 7-ZSTar: M6a -- tar.lz4. Same rationale as g_ArcInfo_TarZst for every
// field except Id/Name/Ext (see that struct's comments); one-step
// extraction (kpidMainSubfile) is M6b for this family member too, same as
// Lz4Handler.cpp's own standalone ".lz4" format.
static const CArcInfo g_ArcInfo_TarLz4 =
{
  NArcInfoFlags::kByExtOnlyOpen
    | NArcInfoFlags::kSymLinks
    | NArcInfoFlags::kHardLinks
    | NArcInfoFlags::kMTime
    | NArcInfoFlags::kMTime_Default,
  k_TarLz4_Id,
  0, 0,
  NULL,
  "tar.lz4",
  "tar.lz4",                     // Ext -- one token, not "tar.lz4 tar.tlz4": "tlz4" is
                                  // Lz4Handler.cpp's own extension (REGISTER_ARC_IO "lz4 tlz4").
  NULL,
  TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::kWindows)
    | TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::kUnix)
    | TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::k1ns)
    | TIME_PREC_TO_ARC_FLAGS_TIME_DEFAULT (NFileTimeType::kUnix),
  CreateArc_TarLz4,
  CreateArcOut_TarLz4,
  NULL
};

struct CRegisterTarChain_TarLz4 { CRegisterTarChain_TarLz4() { RegisterArc(&g_ArcInfo_TarLz4); } };
static CRegisterTarChain_TarLz4 g_RegisterTarChain_TarLz4;

// 7-ZSTar: M6a -- tar.lz5.
static const CArcInfo g_ArcInfo_TarLz5 =
{
  NArcInfoFlags::kByExtOnlyOpen
    | NArcInfoFlags::kSymLinks
    | NArcInfoFlags::kHardLinks
    | NArcInfoFlags::kMTime
    | NArcInfoFlags::kMTime_Default,
  k_TarLz5_Id,
  0, 0,
  NULL,
  "tar.lz5",
  "tar.lz5",                     // Ext -- one token; "tlz5" is Lz5Handler.cpp's own
                                  // extension (REGISTER_ARC_IO "lz5 tlz5").
  NULL,
  TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::kWindows)
    | TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::kUnix)
    | TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::k1ns)
    | TIME_PREC_TO_ARC_FLAGS_TIME_DEFAULT (NFileTimeType::kUnix),
  CreateArc_TarLz5,
  CreateArcOut_TarLz5,
  NULL
};

struct CRegisterTarChain_TarLz5 { CRegisterTarChain_TarLz5() { RegisterArc(&g_ArcInfo_TarLz5); } };
static CRegisterTarChain_TarLz5 g_RegisterTarChain_TarLz5;

// 7-ZSTar: M6a -- tar.liz.
static const CArcInfo g_ArcInfo_TarLiz =
{
  NArcInfoFlags::kByExtOnlyOpen
    | NArcInfoFlags::kSymLinks
    | NArcInfoFlags::kHardLinks
    | NArcInfoFlags::kMTime
    | NArcInfoFlags::kMTime_Default,
  k_TarLiz_Id,
  0, 0,
  NULL,
  "tar.liz",
  "tar.liz",                     // Ext -- one token; "tliz" is LizardHandler.cpp's own
                                  // extension (REGISTER_ARC_IO "liz tliz").
  NULL,
  TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::kWindows)
    | TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::kUnix)
    | TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::k1ns)
    | TIME_PREC_TO_ARC_FLAGS_TIME_DEFAULT (NFileTimeType::kUnix),
  CreateArc_TarLiz,
  CreateArcOut_TarLiz,
  NULL
};

struct CRegisterTarChain_TarLiz { CRegisterTarChain_TarLiz() { RegisterArc(&g_ArcInfo_TarLiz); } };
static CRegisterTarChain_TarLiz g_RegisterTarChain_TarLiz;

// 7-ZSTar: M6b -- tar.gz. Same rationale as g_ArcInfo_TarZst for every
// field except Id/Name/Ext (see that struct's comments).
static const CArcInfo g_ArcInfo_TarGz =
{
  NArcInfoFlags::kByExtOnlyOpen
    | NArcInfoFlags::kSymLinks
    | NArcInfoFlags::kHardLinks
    | NArcInfoFlags::kMTime
    | NArcInfoFlags::kMTime_Default,
  k_TarGz_Id,
  0, 0,
  NULL,
  "tar.gz",
  "tar.gz",                      // Ext -- deliberately one token, not "tar.gz tgz": "tgz" is
                                  // already GzHandler.cpp's own extension (REGISTER_ARC_IO
                                  // "gz gzip tgz tpz apk"); the short forms' one-step
                                  // *extraction* is handled by GzHandler.cpp's own
                                  // kpidMainSubfile (M6b) regardless of which format "owns"
                                  // the extension for open/icon purposes.
  NULL,
  TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::kWindows)
    | TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::kUnix)
    | TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::k1ns)
    | TIME_PREC_TO_ARC_FLAGS_TIME_DEFAULT (NFileTimeType::kUnix),
  CreateArc_TarGz,
  CreateArcOut_TarGz,
  NULL
};

struct CRegisterTarChain_TarGz { CRegisterTarChain_TarGz() { RegisterArc(&g_ArcInfo_TarGz); } };
static CRegisterTarChain_TarGz g_RegisterTarChain_TarGz;

// 7-ZSTar: M6b -- tar.bz2.
static const CArcInfo g_ArcInfo_TarBz2 =
{
  NArcInfoFlags::kByExtOnlyOpen
    | NArcInfoFlags::kSymLinks
    | NArcInfoFlags::kHardLinks
    | NArcInfoFlags::kMTime
    | NArcInfoFlags::kMTime_Default,
  k_TarBz2_Id,
  0, 0,
  NULL,
  "tar.bz2",
  "tar.bz2",                     // Ext -- one token; "tbz2"/"tbz" are Bz2Handler.cpp's own
                                  // extensions (REGISTER_ARC_IO "bz2 bzip2 tbz2 tbz tz2").
  NULL,
  TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::kWindows)
    | TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::kUnix)
    | TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::k1ns)
    | TIME_PREC_TO_ARC_FLAGS_TIME_DEFAULT (NFileTimeType::kUnix),
  CreateArc_TarBz2,
  CreateArcOut_TarBz2,
  NULL
};

struct CRegisterTarChain_TarBz2 { CRegisterTarChain_TarBz2() { RegisterArc(&g_ArcInfo_TarBz2); } };
static CRegisterTarChain_TarBz2 g_RegisterTarChain_TarBz2;

// 7-ZSTar: M6b -- tar.xz.
static const CArcInfo g_ArcInfo_TarXz =
{
  NArcInfoFlags::kByExtOnlyOpen
    | NArcInfoFlags::kSymLinks
    | NArcInfoFlags::kHardLinks
    | NArcInfoFlags::kMTime
    | NArcInfoFlags::kMTime_Default,
  k_TarXz_Id,
  0, 0,
  NULL,
  "tar.xz",
  "tar.xz",                      // Ext -- one token; "txz" is XzHandler.cpp's own extension.
  NULL,
  TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::kWindows)
    | TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::kUnix)
    | TIME_PREC_TO_ARC_FLAGS_MASK (NFileTimeType::k1ns)
    | TIME_PREC_TO_ARC_FLAGS_TIME_DEFAULT (NFileTimeType::kUnix),
  CreateArc_TarXz,
  CreateArcOut_TarXz,
  NULL
};

struct CRegisterTarChain_TarXz { CRegisterTarChain_TarXz() { RegisterArc(&g_ArcInfo_TarXz); } };
static CRegisterTarChain_TarXz g_RegisterTarChain_TarXz;

}}
