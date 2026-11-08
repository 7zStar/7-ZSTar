// ZstdEncoderProps.cpp -- 7-ZSTar: new file (M2)

#include "StdAfx.h"

#include <string.h>

#include "ZstdEncoderProps.h"

#define ZSTD_STATIC_LINKING_ONLY
#include "../../../C/zstd/zstd.h"

static UInt32 Zstd_Clamp(UInt32 v, UInt32 lo, UInt32 hi)
{
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

// dictSize is a byte size (not a log); 0 = auto, (UInt32)(Int32)-2 = "use max"
// (see comment on ZstdEncProps_Set_WindowSize in the header).
static UInt32 Zstd_BytesToLog(UInt32 dictSize, UInt32 minLog, UInt32 maxLog)
{
  UInt32 log;
  if (dictSize == 0)
    return 0;
  if (dictSize == (UInt32)(Int32)-2)
    return maxLog;
  log = minLog;
  while (log < maxLog && ((UInt32)1 << log) < dictSize)
    log++;
  return log;
}

void ZstdEncProps_Init(CZstdEncProps *p)
{
  memset(p, 0, sizeof(*p));
  p->level_7z = 5;
  p->level_zstd = 0; // auto : derive from level_7z in NormalizeFull
  p->useRowMatchFinder = k_ZSTD_ps_auto;
  p->contentSizeFlag = k_ZSTD_ps_enable;
  p->ldmParams.enableLdm = k_ZSTD_ps_auto;
  p->usePledgedSrcSize = 1;
  p->useSizeHintPledgedForSmall = 1;
}

void ZstdEncProps_Set_WindowSize(CZstdEncProps *p, UInt32 dictSize)
{
  p->windowLog = Zstd_BytesToLog(dictSize, ZSTD_WINDOWLOG_MIN, MY_ZSTD_WINDOWLOG_MAX);
}

void ZstdEncProps_Set_WindowChainSize(CZstdEncProps *p, UInt32 dictSize)
{
  p->windowLog_Chain = Zstd_BytesToLog(dictSize, ZSTD_HASHLOG_MIN, MY_ZSTD_CHAINLOG_MAX);
}

// 7z-style level (0..9, GUI slider / solid-block heuristics) -> native zstd level.
// No official mapping is specified anywhere in the (still-commented) upstream
// stub code; chosen so that level_7z==5 (7-Zip's global default, see
// CMethodProps::GetLevel()/CSingleMethodProps::GetLevel()) lands on a
// reasonably strong-but-not-extreme zstd level.
static Int32 Zstd_LevelFrom7z(Int32 level_7z)
{
  static const Byte k_Table[10] = { 1, 1, 3, 5, 7, 9, 13, 16, 19, 22 };
  if (level_7z < 0) level_7z = 0; // defensive: signed field, don't wrap to strongest
  UInt32 lv = (UInt32)level_7z;
  if (lv > 9) lv = 9;
  return (Int32)k_Table[lv];
}

void ZstdEncProps_NormalizeFull(CZstdEncProps *p)
{
  ZSTD_compressionParameters cp;
  int lvlForLookup;

  if (p->level_zstd == 0)
    p->level_zstd = Zstd_LevelFrom7z(p->level_7z);
  if (p->level_zstd > (Int32)MY_ZSTD_LEVEL_MAX)
    p->level_zstd = (Int32)MY_ZSTD_LEVEL_MAX;
  else if (p->level_zstd < -(Int32)1000)
    p->level_zstd = -(Int32)1000; // sane floor for "fast" levels

  lvlForLookup = (p->level_zstd > 0) ? (int)p->level_zstd : 1;
  cp = ZSTD_getCParams(lvlForLookup, 0, 0);

  if (p->windowLog == 0) p->windowLog = cp.windowLog;
  p->windowLog = Zstd_Clamp(p->windowLog, ZSTD_WINDOWLOG_MIN, MY_ZSTD_WINDOWLOG_MAX);

  // chainLog / windowLog_Chain are cross-derived : whichever the caller set
  // (either directly, or via ZstdEncProps_Set_WindowChainSize) wins; after
  // this call both fields hold the same, final, resolved value (this mirrors
  // how the still-commented CompressDialog.cpp reads back props.windowLog_Chain
  // as the "auto" suggestion for its second dictionary-size dropdown).
  if (p->chainLog == 0)
    p->chainLog = (p->windowLog_Chain != 0) ? p->windowLog_Chain : cp.chainLog;
  p->chainLog = Zstd_Clamp(p->chainLog, ZSTD_CHAINLOG_MIN, MY_ZSTD_CHAINLOG_MAX);
  p->windowLog_Chain = p->chainLog;

  if (p->hashLog == 0) p->hashLog = cp.hashLog;
  p->hashLog = Zstd_Clamp(p->hashLog, ZSTD_HASHLOG_MIN, ZSTD_HASHLOG_MAX);

  if (p->searchLog == 0) p->searchLog = cp.searchLog;
  {
    const UInt32 searchLogMax = p->windowLog > 1 ? p->windowLog - 1 : ZSTD_SEARCHLOG_MIN;
    p->searchLog = Zstd_Clamp(p->searchLog, ZSTD_SEARCHLOG_MIN, searchLogMax);
  }

  if (p->minMatch == 0) p->minMatch = cp.minMatch;
  p->minMatch = Zstd_Clamp(p->minMatch, ZSTD_MINMATCH_MIN, ZSTD_MINMATCH_MAX);

  if (p->targetLength == 0) p->targetLength = cp.targetLength;
  if (p->targetLength > ZSTD_TARGETLENGTH_MAX) p->targetLength = ZSTD_TARGETLENGTH_MAX;

  if (p->strategy == 0) p->strategy = (UInt32)cp.strategy;
  p->strategy = Zstd_Clamp(p->strategy, (UInt32)ZSTD_strategy_fast, (UInt32)ZSTD_strategy_btultra2);

  if (p->overlapLog > ZSTD_OVERLAPLOG_MAX) p->overlapLog = ZSTD_OVERLAPLOG_MAX;

  if (p->nbWorkers > MY_ZSTDMT_NBWORKERS_MAX)
    p->nbWorkers = MY_ZSTDMT_NBWORKERS_MAX;

  if (p->jobSize == 0 && p->nbWorkers > 0)
  {
    const UInt64 winSize = (UInt64)1 << p->windowLog;
    UInt64 js = winSize * 4;
    const UInt64 kJobSizeMin = (UInt64)512 << 10;
    if (js < kJobSizeMin) js = kJobSizeMin;
    p->jobSize = js;
  }

  // LDM sub-params : only need concrete values once LDM is (or might be) enabled;
  // k_ZSTD_ps_auto is left as-is so libzstd decides for itself at ZSTD_c_enableLongDistanceMatching==auto.
  if (p->ldmParams.enableLdm != k_ZSTD_ps_disable)
  {
    if (p->ldmParams.hashLog == 0) p->ldmParams.hashLog = ZSTD_LDM_HASHLOG_MAX < 20 ? ZSTD_LDM_HASHLOG_MAX : 20;
    p->ldmParams.hashLog = Zstd_Clamp(p->ldmParams.hashLog, ZSTD_LDM_HASHLOG_MIN, ZSTD_LDM_HASHLOG_MAX);

    if (p->ldmParams.minMatchLength == 0) p->ldmParams.minMatchLength = 64;
    p->ldmParams.minMatchLength = Zstd_Clamp(p->ldmParams.minMatchLength, ZSTD_LDM_MINMATCH_MIN, ZSTD_LDM_MINMATCH_MAX);

    if (p->ldmParams.bucketSizeLog == 0) p->ldmParams.bucketSizeLog = 3;
    p->ldmParams.bucketSizeLog = Zstd_Clamp(p->ldmParams.bucketSizeLog, ZSTD_LDM_BUCKETSIZELOG_MIN, ZSTD_LDM_BUCKETSIZELOG_MAX);

    if (p->ldmParams.hashRateLog == 0)
    {
      p->ldmParams.hashRateLog = p->windowLog > p->ldmParams.hashLog
          ? p->windowLog - p->ldmParams.hashLog : 0;
    }
    if (p->ldmParams.hashRateLog > ZSTD_LDM_HASHRATELOG_MAX)
      p->ldmParams.hashRateLog = ZSTD_LDM_HASHRATELOG_MAX;
  }
}

// Rough fallback estimate (window + match-finder tables + fixed overhead),
// used only if the real libzstd estimator call fails for some reason.
static UInt64 Zstd_ApproxMemUsage_1Ctx(const CZstdEncProps *p)
{
  const UInt64 winSize = (UInt64)1 << p->windowLog;
  const UInt64 chainMem = (UInt64)1 << p->chainLog;
  const UInt64 hashMem = (UInt64)1 << p->hashLog;
  return winSize + chainMem * 4 + hashMem * 4 + (2 << 20);
}

UInt64 ZstdEncProps_GetMemUsage(CZstdEncProps *p)
{
  UInt64 res;
  ZSTD_CCtx_params *params = ZSTD_createCCtxParams();

  if (!params)
    res = Zstd_ApproxMemUsage_1Ctx(p);
  else
  {
    size_t est;
    ZSTD_CCtxParams_setParameter(params, ZSTD_c_compressionLevel, (int)p->level_zstd);
    ZSTD_CCtxParams_setParameter(params, ZSTD_c_windowLog, (int)p->windowLog);
    ZSTD_CCtxParams_setParameter(params, ZSTD_c_chainLog, (int)p->chainLog);
    ZSTD_CCtxParams_setParameter(params, ZSTD_c_hashLog, (int)p->hashLog);
    ZSTD_CCtxParams_setParameter(params, ZSTD_c_searchLog, (int)p->searchLog);
    ZSTD_CCtxParams_setParameter(params, ZSTD_c_minMatch, (int)p->minMatch);
    ZSTD_CCtxParams_setParameter(params, ZSTD_c_targetLength, (int)p->targetLength);
    ZSTD_CCtxParams_setParameter(params, ZSTD_c_strategy, (int)p->strategy);
    if (p->ldmParams.enableLdm == k_ZSTD_ps_enable)
      ZSTD_CCtxParams_setParameter(params, ZSTD_c_enableLongDistanceMatching, 1);
    // NOTE: nbWorkers must stay 0 here; ZSTD_estimateCCtxSize_usingCCtxParams()
    // errors out for nbWorkers >= 1 (that path needs ZSTDMT-side accounting,
    // approximated separately below).

    est = ZSTD_estimateCCtxSize_usingCCtxParams(params);
    res = ZSTD_isError(est) ? Zstd_ApproxMemUsage_1Ctx(p) : (UInt64)est;
    ZSTD_freeCCtxParams(params);
  }

  if (p->nbWorkers > 1)
  {
    const UInt64 winSize = (UInt64)1 << p->windowLog;
    const UInt64 jobSize = p->jobSize != 0 ? p->jobSize : winSize * 4;
    // approximate : each extra worker holds roughly one job's worth of
    // buffered data plus a fraction of window-sized match-finder state.
    res += (UInt64)(p->nbWorkers - 1) * (jobSize + (winSize >> 2) + (1 << 20));
  }
  return res;
}

UInt32 ZstdEncProps_GetNumThreads_for_MemUsageLimit(CZstdEncProps *p, UInt64 memUsageLimit, UInt32 numThreads)
{
  UInt32 n = numThreads;
  if (n > MY_ZSTDMT_NBWORKERS_MAX)
    n = MY_ZSTDMT_NBWORKERS_MAX;

  for (; n > 1; n--)
  {
    CZstdEncProps tmp = *p;
    tmp.nbWorkers = n;
    if (tmp.windowLog == 0 || tmp.chainLog == 0 || tmp.hashLog == 0)
      ZstdEncProps_NormalizeFull(&tmp);
    if (ZstdEncProps_GetMemUsage(&tmp) <= memUsageLimit)
      return n;
  }
  return 1;
}
