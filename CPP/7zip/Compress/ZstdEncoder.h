// ZstdEncoder.h -- 7-ZSTar: new file (M2)
//
// zstd compression coder, implemented on top of vendored libzstd (C/zstd/,
// compression side only -- decoding still goes through the official
// from-scratch C/ZstdDec.c decoder in ZstdDecoder.h/.cpp, unchanged).
//
// Interface/macro style follows CPP/7zip/Compress/Lzma2Encoder.h (Z7_CLASS_IMP_COM_N),
// not mcmilk's older manual QueryInterface style.

#ifndef ZIP7_INC_ZSTD_ENCODER_H
#define ZIP7_INC_ZSTD_ENCODER_H

#include "../../../C/zstd/zstd.h"

#include "../../Common/MyCom.h"
#include "../ICoder.h"

#include "ZstdEncoderProps.h"

class CMethodProps; // ../Common/MethodProps.h; forward-declared to keep that header out of here

namespace NCompress {
namespace NZstd {

// Wraps the C-style CZstdEncProps for the two upstream-stub call sites that
// need to build one from a property list without going through the COM
// SetCoderProperties() array (7zHandlerOut.cpp's solid-block sizing code via
// COneMethodInfo::Set_PropsTo_zstd(), and ZstdHandler.cpp's own MT setup).
struct CEncoderProps
{
  CZstdEncProps EncProps;

  CEncoderProps() { ZstdEncProps_Init(&EncProps); }

  HRESULT SetProp(PROPID propID, const PROPVARIANT &prop);
  HRESULT SetFromMethodProps(const CMethodProps &props);
};

Z7_CLASS_IMP_COM_5(
  CEncoder
  , ICompressCoder
  , ICompressSetCoderMt
  , ICompressSetCoderProperties
  , ICompressSetCoderPropertiesOpt
  , ICompressWriteCoderProperties
)
  ZSTD_CCtx *_ctx;
  Byte *_srcBuf;
  Byte *_dstBuf;
  size_t _srcBufSize;
  size_t _dstBufSize;
  bool _propsNormalized;

  HRESULT Prepare();

public:
  CEncoderProps _props;

  // set directly by ZstdHandler.cpp (CHandler::UpdateItems) right before Code();
  // also settable via ICompressSetCoderPropertiesOpt (NCoderPropID::kExpectedDataSize).
  // (UInt64)(Int64)-1 = unknown.
  UInt64 SrcSizeHint64;

  CEncoder();
  ~CEncoder();
};

}}

#endif
