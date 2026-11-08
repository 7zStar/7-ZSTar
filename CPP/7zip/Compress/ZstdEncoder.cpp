// ZstdEncoder.cpp -- 7-ZSTar: new file (M2)

#include "StdAfx.h"

#define ZSTD_STATIC_LINKING_ONLY
#include "../../../C/zstd/zstd.h"

#include "../../../C/Alloc.h"

#include "../Common/MethodProps.h"
#include "../Common/StreamUtils.h"

#include "ZstdEncoder.h"

namespace NCompress {
namespace NZstd {

// ============================= CEncoderProps =============================

HRESULT CEncoderProps::SetProp(PROPID propID, const PROPVARIANT &prop)
{
  switch (propID)
  {
    case NCoderPropID::kLevel:
      // kLevel carries 7-Zip's generic 0..9 scale (HandlerOut's SetGlobalLevelTo
      // injects it archive-wide); NormalizeFull maps it to a native zstd level
      // via Zstd_LevelFrom7z. Raw zstd levels (1..22) go through kNativeLevel.
      if (prop.vt != VT_UI4) return E_INVALIDARG;
      EncProps.level_7z = (Int32)prop.ulVal;
      break;

    case NCoderPropID::kNumThreads:
      if (prop.vt != VT_UI4) return E_INVALIDARG;
      EncProps.nbWorkers = prop.ulVal <= 1 ? 0 : prop.ulVal;
      break;

    case NCoderPropID::kDictionarySize:
    {
      UInt32 v;
      if (prop.vt == VT_UI4) v = prop.ulVal;
      else if (prop.vt == VT_UI8) v = prop.uhVal.QuadPart > (UInt64)0xFFFFFFFF ? k_ZstdDictSize_UseMax : (UInt32)prop.uhVal.QuadPart;
      else return E_INVALIDARG;
      ZstdEncProps_Set_WindowSize(&EncProps, v);
      break;
    }

    case NCoderPropID::kChainSize:
    {
      UInt32 v;
      if (prop.vt == VT_UI4) v = prop.ulVal;
      else if (prop.vt == VT_UI8) v = prop.uhVal.QuadPart > (UInt64)0xFFFFFFFF ? k_ZstdDictSize_UseMax : (UInt32)prop.uhVal.QuadPart;
      else return E_INVALIDARG;
      ZstdEncProps_Set_WindowChainSize(&EncProps, v);
      break;
    }

    case NCoderPropID::kNativeLevel:
      if (prop.vt != VT_UI4) return E_INVALIDARG;
      EncProps.level_zstd = (Int32)prop.ulVal;
      break;

    case NCoderPropID::kFast:
    {
      if (prop.vt != VT_UI4) return E_INVALIDARG;
      {
        UInt32 v = prop.ulVal;
        if (v < 1) v = 1;
        EncProps.level_zstd = -(Int32)v;
      }
      break;
    }

    case NCoderPropID::kMinMatch:
      if (prop.vt != VT_UI4) return E_INVALIDARG;
      EncProps.minMatch = prop.ulVal;
      break;

    case NCoderPropID::kOverlapLog:
      if (prop.vt != VT_UI4) return E_INVALIDARG;
      EncProps.overlapLog = prop.ulVal;
      break;

    case NCoderPropID::kRowMatchFinder:
    {
      bool v;
      RINOK(PROPVARIANT_to_bool(prop, v))
      EncProps.useRowMatchFinder = v ? k_ZSTD_ps_enable : k_ZSTD_ps_disable;
      break;
    }

    case NCoderPropID::kLdmEnable:
    {
      bool v;
      RINOK(PROPVARIANT_to_bool(prop, v))
      EncProps.ldmParams.enableLdm = v ? k_ZSTD_ps_enable : k_ZSTD_ps_disable;
      break;
    }

    case NCoderPropID::kLdmWindowSize:
    {
      // mirrors "--long=N" in the reference zstd CLI: sets the main window
      // and force-enables long-distance-matching (zstd has no independent
      // LDM-only window; LDM always rides on the main windowLog).
      UInt32 v;
      if (prop.vt == VT_UI4) v = prop.ulVal;
      else if (prop.vt == VT_UI8) v = prop.uhVal.QuadPart > (UInt64)0xFFFFFFFF ? k_ZstdDictSize_UseMax : (UInt32)prop.uhVal.QuadPart;
      else return E_INVALIDARG;
      ZstdEncProps_Set_WindowSize(&EncProps, v);
      EncProps.ldmParams.enableLdm = k_ZSTD_ps_enable;
      break;
    }

    case NCoderPropID::kLdmHashLog:
      if (prop.vt != VT_UI4) return E_INVALIDARG;
      EncProps.ldmParams.hashLog = prop.ulVal;
      break;

    case NCoderPropID::kLdmMinMatchLength:
      if (prop.vt != VT_UI4) return E_INVALIDARG;
      EncProps.ldmParams.minMatchLength = prop.ulVal;
      break;

    case NCoderPropID::kLdmBucketSizeLog:
      if (prop.vt != VT_UI4) return E_INVALIDARG;
      EncProps.ldmParams.bucketSizeLog = prop.ulVal;
      break;

    case NCoderPropID::kLdmHashRateLog:
      if (prop.vt != VT_UI4) return E_INVALIDARG;
      EncProps.ldmParams.hashRateLog = prop.ulVal;
      break;

    case NCoderPropID::kWriteUnpackSizeFlag:
    {
      bool v;
      RINOK(PROPVARIANT_to_bool(prop, v))
      EncProps.contentSizeFlag = v ? k_ZSTD_ps_enable : k_ZSTD_ps_disable;
      break;
    }

    case NCoderPropID::kUsePledged:
    {
      bool v;
      RINOK(PROPVARIANT_to_bool(prop, v))
      EncProps.usePledgedSrcSize = v ? 1 : 0;
      break;
    }

    case NCoderPropID::kUseSizeHintPledgedForSmall:
    {
      bool v;
      RINOK(PROPVARIANT_to_bool(prop, v))
      EncProps.useSizeHintPledgedForSmall = v ? 1 : 0;
      break;
    }

    case NCoderPropID::kUseSizeHintForEach:
    {
      bool v;
      RINOK(PROPVARIANT_to_bool(prop, v))
      EncProps.useSizeHintForEach = v ? 1 : 0;
      break;
    }

    case NCoderPropID::kUseSizeHintGlobal:
    {
      bool v;
      RINOK(PROPVARIANT_to_bool(prop, v))
      EncProps.useSizeHintGlobal = v ? 1 : 0;
      break;
    }

    case NCoderPropID::kParamSelectMode:
      if (prop.vt != VT_UI4) return E_INVALIDARG;
      EncProps.paramSelectMode = prop.ulVal;
      break;

    default:
      break; // unknown / not-applicable props are ignored (matches sibling encoders)
  }
  return S_OK;
}

HRESULT CEncoderProps::SetFromMethodProps(const CMethodProps &props)
{
  ZstdEncProps_Init(&EncProps);
  FOR_VECTOR (i, props.Props)
  {
    RINOK(SetProp(props.Props[i].Id, props.Props[i].Value))
  }
  return S_OK;
}


// =============================== helpers ==================================

// deliberately non-exhaustive (many ZSTD_ErrorCode values have no better
// HRESULT than the E_FAIL default; -Wall would otherwise flag every one of
// them individually via C4061 even though a default: case is present).
#ifdef _MSC_VER // 7-ZSTar: Linux port -- gcc -Werror=unknown-pragmas
#pragma warning(push)
#pragma warning(disable : 4061)
#endif
static HRESULT Zstd_GetErrorHRESULT(size_t zstdErrCode)
{
  switch (ZSTD_getErrorCode(zstdErrCode))
  {
    case ZSTD_error_memory_allocation:
      return E_OUTOFMEMORY;
    case ZSTD_error_version_unsupported:
    case ZSTD_error_frameParameter_unsupported:
      return E_NOTIMPL;
    case ZSTD_error_frameParameter_windowTooLarge:
    case ZSTD_error_parameter_unsupported:
    case ZSTD_error_parameter_outOfBound:
    case ZSTD_error_srcSize_wrong:
      return E_INVALIDARG;
    default:
      return E_FAIL;
  }
}
#ifdef _MSC_VER // 7-ZSTar: Linux port
#pragma warning(pop)
#endif

static HRESULT Zstd_ApplyParam(ZSTD_CCtx *ctx, ZSTD_cParameter param, int value)
{
  const size_t err = ZSTD_CCtx_setParameter(ctx, param, value);
  return ZSTD_isError(err) ? Zstd_GetErrorHRESULT(err) : S_OK;
}

static HRESULT Zstd_ApplyEncProps(const CZstdEncProps &p, ZSTD_CCtx *ctx)
{
  RINOK(Zstd_ApplyParam(ctx, ZSTD_c_compressionLevel, (int)(p.level_zstd != 0 ? p.level_zstd : ZSTD_CLEVEL_DEFAULT)))
  RINOK(Zstd_ApplyParam(ctx, ZSTD_c_windowLog, (int)p.windowLog))
  RINOK(Zstd_ApplyParam(ctx, ZSTD_c_chainLog, (int)p.chainLog))
  RINOK(Zstd_ApplyParam(ctx, ZSTD_c_hashLog, (int)p.hashLog))
  RINOK(Zstd_ApplyParam(ctx, ZSTD_c_searchLog, (int)p.searchLog))
  RINOK(Zstd_ApplyParam(ctx, ZSTD_c_minMatch, (int)p.minMatch))
  RINOK(Zstd_ApplyParam(ctx, ZSTD_c_targetLength, (int)p.targetLength))
  RINOK(Zstd_ApplyParam(ctx, ZSTD_c_strategy, (int)p.strategy))
  RINOK(Zstd_ApplyParam(ctx, ZSTD_c_contentSizeFlag, p.contentSizeFlag == k_ZSTD_ps_disable ? 0 : 1))
  RINOK(Zstd_ApplyParam(ctx, ZSTD_c_overlapLog, (int)p.overlapLog))

  if (p.useRowMatchFinder != k_ZSTD_ps_auto)
    RINOK(Zstd_ApplyParam(ctx, ZSTD_c_useRowMatchFinder, (int)p.useRowMatchFinder))

  if (p.ldmParams.enableLdm != k_ZSTD_ps_auto)
    RINOK(Zstd_ApplyParam(ctx, ZSTD_c_enableLongDistanceMatching, p.ldmParams.enableLdm == k_ZSTD_ps_enable ? 1 : 0))

  if (p.ldmParams.enableLdm == k_ZSTD_ps_enable)
  {
    RINOK(Zstd_ApplyParam(ctx, ZSTD_c_ldmHashLog, (int)p.ldmParams.hashLog))
    RINOK(Zstd_ApplyParam(ctx, ZSTD_c_ldmMinMatch, (int)p.ldmParams.minMatchLength))
    RINOK(Zstd_ApplyParam(ctx, ZSTD_c_ldmBucketSizeLog, (int)p.ldmParams.bucketSizeLog))
    RINOK(Zstd_ApplyParam(ctx, ZSTD_c_ldmHashRateLog, (int)p.ldmParams.hashRateLog))
  }

  {
    UInt32 nb = p.nbWorkers;
#ifndef ZSTD_MULTITHREAD
    nb = 0; // defensive fallback; build should always define ZSTD_MULTITHREAD (see Arc.mak / Alone makefile / 7zstar_gcc.mak)
#endif
    RINOK(Zstd_ApplyParam(ctx, ZSTD_c_nbWorkers, (int)nb))
    if (nb > 0 && p.jobSize != 0)
    {
      UInt64 js = p.jobSize;
      if (js > 0x7FFFFFFF) js = 0x7FFFFFFF;
      RINOK(Zstd_ApplyParam(ctx, ZSTD_c_jobSize, (int)js))
    }
  }
  return S_OK;
}


// =============================== CEncoder ==================================

CEncoder::CEncoder():
    _ctx(NULL),
    _srcBuf(NULL),
    _dstBuf(NULL),
    _srcBufSize(0),
    _dstBufSize(0),
    _propsNormalized(false),
    SrcSizeHint64((UInt64)(Int64)-1)
{
}

CEncoder::~CEncoder()
{
  if (_ctx)
    ZSTD_freeCCtx(_ctx);
  ::MidFree(_srcBuf);
  ::MidFree(_dstBuf);
}


Z7_COM7F_IMF(CEncoder::SetCoderProperties(const PROPID *propIDs,
    const PROPVARIANT *coderProps, UInt32 numProps))
{
  ZstdEncProps_Init(&_props.EncProps);
  for (UInt32 i = 0; i < numProps; i++)
  {
    RINOK(_props.SetProp(propIDs[i], coderProps[i]))
  }
  ZstdEncProps_NormalizeFull(&_props.EncProps);
  _propsNormalized = true;
  return S_OK;
}


Z7_COM7F_IMF(CEncoder::SetCoderPropertiesOpt(const PROPID *propIDs,
    const PROPVARIANT *coderProps, UInt32 numProps))
{
  for (UInt32 i = 0; i < numProps; i++)
  {
    const PROPVARIANT &prop = coderProps[i];
    if (propIDs[i] == NCoderPropID::kExpectedDataSize)
      if (prop.vt == VT_UI8)
        SrcSizeHint64 = prop.uhVal.QuadPart;
  }
  return S_OK;
}


Z7_COM7F_IMF(CEncoder::SetNumberOfThreads(UInt32 numThreads))
{
  if (numThreads > MY_ZSTDMT_NBWORKERS_MAX)
    numThreads = MY_ZSTDMT_NBWORKERS_MAX;
  _props.EncProps.nbWorkers = numThreads <= 1 ? 0 : numThreads;
  return S_OK;
}


Z7_COM7F_IMF(CEncoder::WriteCoderProperties(ISequentialOutStream *outStream))
{
  // mcmilk-compatible .7z coder-properties layout (5 bytes). Level byte follows
  // mcmilk's encoding exactly: 1..22 for normal levels, 255 for "ultimate",
  // and fast (negative) levels as fast_value + 32 (Z7_ZSTD_FAST_LEV_INC in
  // mcmilk's ICoder.h; fast clamped to 1..64 like their kFast handler).
  // Content is informational only - the zstd frame is self-describing and
  // decoders (ours and mcmilk's) don't require it - but we match the format.
  if (!_propsNormalized)
  {
    ZstdEncProps_NormalizeFull(&_props.EncProps); // level_zstd may still be 0 (auto) before normalize
    _propsNormalized = true;
  }
  Byte buf[5];
  buf[0] = (Byte)ZSTD_VERSION_MAJOR;
  buf[1] = (Byte)ZSTD_VERSION_MINOR;
  {
    const Int32 lv = _props.EncProps.level_zstd;
    if (lv >= 0)
      buf[2] = (Byte)(lv > 255 ? 255 : lv);
    else
    {
      Int32 fast = -lv;
      if (fast > 64) fast = 64;
      buf[2] = (Byte)(fast + 32);
    }
  }
  buf[3] = 0;
  buf[4] = 0;
  return WriteStream(outStream, buf, sizeof(buf));
}


HRESULT CEncoder::Prepare()
{
  if (!_propsNormalized)
  {
    ZstdEncProps_NormalizeFull(&_props.EncProps);
    _propsNormalized = true;
  }

  if (!_ctx)
  {
    _ctx = ZSTD_createCCtx();
    if (!_ctx)
      return E_OUTOFMEMORY;
  }
  else
  {
    const size_t err = ZSTD_CCtx_reset(_ctx, ZSTD_reset_session_and_parameters);
    if (ZSTD_isError(err))
      return Zstd_GetErrorHRESULT(err);
  }

  RINOK(Zstd_ApplyEncProps(_props.EncProps, _ctx))

  if (SrcSizeHint64 != (UInt64)(Int64)-1)
  {
    const size_t err = ZSTD_CCtx_setPledgedSrcSize(_ctx, SrcSizeHint64);
    if (ZSTD_isError(err))
      return Zstd_GetErrorHRESULT(err);
  }

  if (!_srcBuf || !_dstBuf)
  {
    _srcBufSize = ZSTD_CStreamInSize();
    _dstBufSize = ZSTD_CStreamOutSize();
    ::MidFree(_srcBuf); _srcBuf = (Byte *)::MidAlloc(_srcBufSize);
    ::MidFree(_dstBuf); _dstBuf = (Byte *)::MidAlloc(_dstBufSize);
    if (!_srcBuf || !_dstBuf)
      return E_OUTOFMEMORY;
  }
  return S_OK;
}


Z7_COM7F_IMF(CEncoder::Code(ISequentialInStream *inStream, ISequentialOutStream *outStream,
    const UInt64 * /* inSize */, const UInt64 * /* outSize */, ICompressProgressInfo *progress))
{
  RINOK(Prepare())

  UInt64 processedIn = 0;
  UInt64 processedOut = 0;
  ZSTD_EndDirective endOp = ZSTD_e_continue;
  bool inputFinished = false;

  for (;;)
  {
    ZSTD_inBuffer inBuf;
    size_t srcSize = 0;

    if (!inputFinished)
    {
      srcSize = _srcBufSize;
      RINOK(ReadStream(inStream, _srcBuf, &srcSize))
      processedIn += srcSize;
      if (srcSize < _srcBufSize)
      {
        inputFinished = true;
        endOp = ZSTD_e_end;
      }
    }
    inBuf.src = _srcBuf;
    inBuf.size = srcSize;
    inBuf.pos = 0;

    for (;;)
    {
      ZSTD_outBuffer outBuf;
      outBuf.dst = _dstBuf;
      outBuf.size = _dstBufSize;
      outBuf.pos = 0;

      const size_t rem = ZSTD_compressStream2(_ctx, &outBuf, &inBuf, endOp);
      if (ZSTD_isError(rem))
        return Zstd_GetErrorHRESULT(rem);

      if (outBuf.pos)
      {
        RINOK(WriteStream(outStream, _dstBuf, outBuf.pos))
        processedOut += outBuf.pos;
      }
      if (progress)
      {
        RINOK(progress->SetRatioInfo(&processedIn, &processedOut))
      }

      if (endOp == ZSTD_e_end)
      {
        if (rem == 0)
          return S_OK; // fully flushed : frame epilogue (and checksum, if any) written
        continue;       // keep draining buffered output
      }
      // ZSTD_e_continue : stop feeding once this chunk has been fully consumed
      // (inBuf.pos is advanced by zstd itself across calls; only re-filled from
      // the input stream by the outer loop once it reaches inBuf.size).
      if (inBuf.pos >= inBuf.size)
        break;
    }
  }
}

}}


// ------------------------- COneMethodInfo::Set_PropsTo_zstd -------------------------
// Defined here (not in Common/MethodProps.cpp) so that bundles which don't link
// the zstd encoder (ZstdEncoder.obj / this translation unit) never reference
// NCompress::NZstd::CEncoderProps::SetFromMethodProps() at all: MethodProps.cpp
// stays free of any zstd dependency, and this function is simply absent (not just
// unresolved) from those builds. Nothing in M2 calls it yet (only the still-commented
// stub code in 7zHandlerOut.cpp does), so its absence there is harmless.

HRESULT COneMethodInfo::Set_PropsTo_zstd(NCompress::NZstd::CEncoderProps &props) const
{
  return props.SetFromMethodProps(*this);
}
