// ZstdEncoderProps.h -- 7-ZSTar: new file (M2)
//
// C-style zstd encoder properties, mirroring the naming/shape of the
// still-commented "pre-embedded" stub API referenced from:
//   - CPP/7zip/Archive/7z/7zHandlerOut.cpp (solid-block sizing, thread calc)
//   - CPP/7zip/UI/GUI/CompressDialog.cpp   (level/dict/thread/memory UI, M3)
// The struct/function shapes here are designed so that code compiles once
// those comments are uncommented in a future milestone; only this milestone
// (M2) actually calls into them (via NCompress::NZstd::CEncoder/CEncoderProps).
//
// Pattern mirrors C/Lzma2Enc.h's CLzma2EncProps + Lzma2EncProps_Init/Normalize
// (a plain C struct + C-style free functions, usable from C++ without issue).

#ifndef ZIP7_INC_ZSTD_ENCODER_PROPS_H
#define ZIP7_INC_ZSTD_ENCODER_PROPS_H

#include "../../../C/7zTypes.h"

EXTERN_C_BEGIN

// ---- GUI/CLI-facing constants (kept independent of C/zstd/zstd.h so that
//      files which must not depend on libzstd's headers, e.g. CompressDialog.cpp,
//      can still reference them). Values mirror libzstd 1.5.x exactly. ----

#define MY_ZSTD_WINDOWLOG_MAX    ((unsigned)(sizeof(size_t) == 4 ? 30 : 31))
#define MY_ZSTD_CHAINLOG_MAX     ((unsigned)(sizeof(size_t) == 4 ? 29 : 30))
#define MY_ZSTD_LEVEL_MAX        22
#define MY_ZSTDMT_NBWORKERS_MAX  ((unsigned)(sizeof(void*) == 4 ? 64 : 256))

// 7-ZSTar: same limit, "engine-internal" name -- this is the spelling the
// (already-active, not commented) multithreading setup in ZstdHandler.cpp's
// CHandler::UpdateItems() actually references; MY_ZSTDMT_NBWORKERS_MAX above
// is the GUI-facing spelling used by the still-commented CompressDialog.cpp /
// ZipUpdate.cpp stub code. Single source of truth, two names.
#define Z7_ZSTDMT_NBWORKERS_MAX  MY_ZSTDMT_NBWORKERS_MAX

// mirrors libzstd's ZSTD_strategy enum values (zstd.h), renamed with a
// "ZSTD_strategy_" prefix so callers don't need zstd.h just to compare strategy tiers.
enum
{
  ZSTD_strategy_fast     = 1,
  ZSTD_strategy_dfast    = 2,
  ZSTD_strategy_greedy   = 3,
  ZSTD_strategy_lazy     = 4,
  ZSTD_strategy_lazy2    = 5,
  ZSTD_strategy_btlazy2  = 6,
  ZSTD_strategy_btopt    = 7,
  ZSTD_strategy_btultra  = 8,
  ZSTD_strategy_btultra2 = 9
};

// mirrors libzstd's ZSTD_paramSwitch_e (zstd.h) exactly (same numeric values),
// under 7-Zip naming conventions (k_ constant prefix).
typedef enum
{
  k_ZSTD_ps_auto    = 0,
  k_ZSTD_ps_enable  = 1,
  k_ZSTD_ps_disable = 2
} E_ZSTD_paramSwitch_e;

typedef struct
{
  E_ZSTD_paramSwitch_e enableLdm;
  UInt32 hashLog;          // 0 = auto
  UInt32 bucketSizeLog;    // 0 = auto
  UInt32 minMatchLength;   // 0 = auto
  UInt32 hashRateLog;      // 0 = auto (zstd default : windowLog - hashLog)
} CZstdLdmParams;

// All UInt32 tuning fields use 0 as the "not set / auto" sentinel (this matches
// libzstd's own convention for several ZSTD_c_* parameters, e.g. windowLog,
// targetLength : "value 0 means use default"). level_zstd uses 0 the same way
// (real zstd levels are never 0; negative = "fast" level -N).
typedef struct
{
  Int32 level_7z;      // 0..9, 7z-style level (GUI slider). Default 5.
  Int32 level_zstd;    // 0 = auto (derive from level_7z); >0 = zstd level 1..22; <0 = fast level -N

  UInt32 windowLog;         // 0 = auto
  UInt32 windowLog_Chain;   // 0 = auto; GUI-facing companion of windowLog for the "Chain" dictionary control
  UInt32 chainLog;          // 0 = auto (final, normalized value used for ZSTD_c_chainLog)
  UInt32 hashLog;           // 0 = auto
  UInt32 searchLog;         // 0 = auto
  UInt32 minMatch;          // 0 = auto
  UInt32 targetLength;      // 0 = auto ("use default targetLength")
  UInt32 strategy;          // 0 = auto; else one of the ZSTD_strategy_* values above

  UInt32 overlapLog;        // 0 = auto (0 is also a legal explicit "no overlap" value to zstd itself)
  UInt32 targetPrefixSize;  // reserved / advanced, currently informational only

  E_ZSTD_paramSwitch_e useRowMatchFinder;
  E_ZSTD_paramSwitch_e contentSizeFlag;

  UInt32 nbWorkers;    // 0 = single-threaded
  UInt64 jobSize;      // 0 = auto

  CZstdLdmParams ldmParams;

  // src-size-hint application policy (NCoderPropID::kUsePledged / kUseSizeHint*);
  // stored for forward-compat with the GUI (M3); CEncoder currently applies a
  // conservative fixed policy (see ZstdEncoder.cpp) regardless of these flags.
  Byte usePledgedSrcSize;
  Byte useSizeHintPledgedForSmall;
  Byte useSizeHintForEach;
  Byte useSizeHintGlobal;

  UInt32 paramSelectMode; // reserved for future precedence control between level_7z / explicit fields
} CZstdEncProps;

void ZstdEncProps_Init(CZstdEncProps *p);

// Resolves every "auto" (0) field to a concrete value (via libzstd's own
// ZSTD_getCParams() level table), clamps explicit values to legal ranges,
// and cross-derives windowLog_Chain <-> chainLog. Idempotent.
void ZstdEncProps_NormalizeFull(CZstdEncProps *p);

// dictSize is a byte size (not a log). 0 = auto/default. k_ZstdDictSize_UseMax
// means "requested size didn't fit UInt32 -> use max" (mirrors the convention
// used by the CompressDialog.cpp helper that feeds this function from a
// UInt64 dictionary-size spec).
#define k_ZstdDictSize_UseMax ((UInt32)(Int32)-2)
void ZstdEncProps_Set_WindowSize(CZstdEncProps *p, UInt32 dictSize);
void ZstdEncProps_Set_WindowChainSize(CZstdEncProps *p, UInt32 dictSize);

// Approximate/estimated memory usage of one CCtx at the current (should already
// be Normalize'd) settings, scaled for p->nbWorkers. Uses libzstd's own
// ZSTD_estimateCCtxSize_usingCCtxParams() for the single-thread base cost.
UInt64 ZstdEncProps_GetMemUsage(CZstdEncProps *p);

// Reduces numThreads (>=1) so that nbWorkers-scaled memory usage fits memUsageLimit.
// Never returns 0 (returns 1 if even single-threaded doesn't fit under the limit).
UInt32 ZstdEncProps_GetNumThreads_for_MemUsageLimit(CZstdEncProps *p, UInt64 memUsageLimit, UInt32 numThreads);

EXTERN_C_END

#endif
