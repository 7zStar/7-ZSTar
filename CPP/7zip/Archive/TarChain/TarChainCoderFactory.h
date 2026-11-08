// TarChainCoderFactory.h -- 7-ZSTar: new file (M6a)
//
// Factory functions letting TarChainHandler.cpp obtain an lz4/lz5/lizard/
// brotli ICompressCoder without directly #including that codec's own
// CPP/7zip/Compress/XxxEncoder.h.
//
// Why this indirection is needed (not just style): every codec built on
// mcmilk's MT wrapper library (C/zstdmt/lz4-mt.h, lz5-mt.h, lizard-mt.h,
// brotli-mt.h) declares process-global, *unprefixed* `fn_read`/`fn_write`
// function-pointer typedefs, each with a codec-specific (and mutually
// incompatible) buffer-struct parameter type -- e.g. lz4-mt.h has
// `typedef int (fn_read)(void*, LZ4MT_Buffer*)` and lz5-mt.h has
// `typedef int (fn_read)(void*, LZ5MT_Buffer*)`. mcmilk's own codebase never
// #includes two of these headers in the same translation unit (each
// codec's Encoder/Decoder/Handler/Register.cpp only ever pulls in its own),
// so the collision never surfaces upstream. TarChainHandler.cpp is the one
// place in this project that needs more than one of these codecs available
// together (its UpdateItems() switches on _codec at runtime) -- directly
// #including e.g. both Lz4Encoder.h and Lz5Encoder.h there redefines
// `fn_read`/`fn_write` with incompatible signatures (MSVC C2116 "declared
// argument lists differ"), a hard compile error, not a warning.
//
// Fix: keep each codec's own Encoder.h (and therefore its *-mt.h) confined
// to its own .cpp file, same as upstream's own usage pattern. Each function
// below is implemented at the bottom of that codec's own EncoderXxx.cpp
// (Lz4Encoder.cpp, Lz5Encoder.cpp, ...), mirroring this project's own
// existing precedent for the identical "keep a codec-specific header out of
// a shared/consumer translation unit" problem: ZstdEncoder.cpp's trailing
// COneMethodInfo::Set_PropsTo_zstd (declared in the codec-agnostic
// Common/MethodProps.h, defined in ZstdEncoder.cpp) -- same rationale,
// applied to producing a coder *instance* instead of filling a properties
// struct. zstd itself needs no entry here: it doesn't use C/zstdmt/ at all
// (its own built-in ZSTDMT has no such header), so TarChainHandler.cpp's
// existing direct construction of NCompress::NZstd::CEncoder is unaffected
// and unchanged.
//
// Only bundles that actually link TarChainHandler.obj (Format7zF, Alone2,
// Fm; see Arc.mak's TARCHAIN_OBJS) pull these functions in; the codec
// Encoder.cpp files that define them are already linked into those bundles
// regardless (COMPRESS_OBJS), so this adds no new link-time dependency.

#ifndef ZIP7_INC_TAR_CHAIN_CODER_FACTORY_H
#define ZIP7_INC_TAR_CHAIN_CODER_FACTORY_H

#include "../../../Common/MyCom.h"

#include "../../ICoder.h"

#include "../Common/HandlerOut.h" // CSingleMethodProps

// CSingleMethodProps is NArchive::CSingleMethodProps (HandlerOut.h wraps its
// whole content in `namespace NArchive`); this header is deliberately at
// global scope (included from Lz4Encoder.cpp etc, which aren't in that
// namespace), so the qualification is required here even though
// TarChainHandler.cpp's own call sites (inside namespace NArchive::NTarChain)
// can and do use the bare, unqualified name.
HRESULT CreateTarChainCoder_Lz4(const NArchive::CSingleMethodProps &props, CMyComPtr<ICompressCoder> &coder);
HRESULT CreateTarChainCoder_Lz5(const NArchive::CSingleMethodProps &props, CMyComPtr<ICompressCoder> &coder);
HRESULT CreateTarChainCoder_Lizard(const NArchive::CSingleMethodProps &props, CMyComPtr<ICompressCoder> &coder);
HRESULT CreateTarChainCoder_Brotli(const NArchive::CSingleMethodProps &props, CMyComPtr<ICompressCoder> &coder);

#endif
