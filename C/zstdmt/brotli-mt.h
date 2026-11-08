
/**
 * Copyright (c) 2016 - 2017 Tino Reichardt
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 * You can contact the author at:
 * - zstdmt source repository: https://github.com/mcmilk/zstdmt
 */

/* ***************************************
 * Defines
 ****************************************/

#ifndef BROTLIMT_H
#define BROTLIMT_H

#if defined (__cplusplus)
extern "C" {
#endif

#include <stddef.h>   /* size_t */

/* current maximum the library will accept */
#define BROTLIMT_THREAD_MAX 128
#define BROTLIMT_LEVEL_MIN    0
#define BROTLIMT_LEVEL_MAX   11

#define BROTLIMT_MAGICNUMBER     0x5242U /* BR */
#define BROTLIMT_MAGIC_SKIPPABLE 0x184D2A50U

#define BROTLI_VERSION_MAJOR 1
#define BROTLI_VERSION_MINOR 0

/* **************************************
 * Error Handling
 ****************************************/

typedef enum {
  BROTLIMT_error_no_error,
  BROTLIMT_error_memory_allocation,
  BROTLIMT_error_read_fail,
  BROTLIMT_error_write_fail,
  BROTLIMT_error_data_error,
  BROTLIMT_error_end_of_data,
  BROTLIMT_error_frame_compress,
  BROTLIMT_error_frame_decompress,
  BROTLIMT_error_compressionParameter_unsupported,
  BROTLIMT_error_compression_library,
  BROTLIMT_error_canceled,
  BROTLIMT_error_maxCode
} BROTLIMT_ErrorCode;

#define PREFIX(name) BROTLIMT_error_##name
#define MT_ERROR(name)  ((size_t)-PREFIX(name))
extern unsigned BROTLIMT_isError(size_t code);
extern const char* BROTLIMT_getErrorString(size_t code);

/* **************************************
 * Structures
 ****************************************/

typedef struct {
	void *buf;		/* ptr to data */
	size_t size;		/* current filled in buf */
	size_t allocated;	/* length of buf */
} BROTLIMT_Buffer;

/**
 * reading and writing functions
 * - you can use stdio functions or plain read/write
 * - just write some wrapper on your own
 * - a sample is given in 7-Zip ZS or bromt.c
 * - the function should return -1 on error and zero on success
 * - the read or written bytes will go to in->size or out->size
 */
typedef int (fn_read) (void *args, BROTLIMT_Buffer * in);
typedef int (fn_write) (void *args, BROTLIMT_Buffer * out);

typedef struct {
	fn_read *fn_read;
	void *arg_read;
	fn_write *fn_write;
	void *arg_write;
} BROTLIMT_RdWr_t;

/* **************************************
 * Compression
 ****************************************/

typedef struct BROTLIMT_CCtx_s BROTLIMT_CCtx;

/**
 * 1) allocate new cctx
 * - return cctx or zero on error
 *
 * @level   - BROTLIMT_LEVEL_MIN .. BROTLIMT_LEVEL_MAX
 * @threads - 1 .. BROTLIMT_THREAD_MAX, or 0 to process a raw
 *            brotli stream single threaded (no mt container)
 * @inputsize - if zero, becomes some optimal value for the level
 *            - if nonzero, the given value is taken
 */
BROTLIMT_CCtx *BROTLIMT_createCCtx(int threads, uint64_t unpackSize, int level, int inputsize, int lgwin);

/**
 * 2) threaded compression
 * - errorcheck via 
 */
size_t BROTLIMT_compressCCtx(BROTLIMT_CCtx * ctx, BROTLIMT_RdWr_t * rdwr);

/**
 * 3) get some statistic
 */
size_t BROTLIMT_GetFramesCCtx(BROTLIMT_CCtx * ctx);
size_t BROTLIMT_GetInsizeCCtx(BROTLIMT_CCtx * ctx);
size_t BROTLIMT_GetOutsizeCCtx(BROTLIMT_CCtx * ctx);

/**
 * 4) free cctx
 * - no special return value
 */
void BROTLIMT_freeCCtx(BROTLIMT_CCtx * ctx);

/* **************************************
 * Decompression
 ****************************************/

typedef struct BROTLIMT_DCtx_s BROTLIMT_DCtx;

/**
 * 1) allocate new cctx
 * - return cctx or zero on error
 *
 * @threads - 1 .. BROTLIMT_THREAD_MAX, or 0 for "no thread count forced"
 *            7-ZSTar: on this decompression side 0 by itself no longer
 *            selects the raw stream -- BROTLIMT_decompressDCtx() decides
 *            raw vs. mt-container from the stream's own first 16 bytes (the
 *            whole first frame header) and promotes 0 to 1 when it finds the
 *            container. Only BROTLIMT_createCCtx()'s 0 still *selects*
 *            raw output.
 * @threadsset - non-zero when the caller is pinning the decode mode rather
 *            than merely hinting a worker count. 7-ZSTar: the pair
 *            (threadsset != 0, threads == 0) is the escape hatch -- it
 *            forces the raw brotli decoder and skips content detection
 *            entirely, so a raw stream that happens to collide with the
 *            container header can still be read. Ported from sebres'
 *            b4e36ba7 in mcmilk/7-Zip-zstd, which needs no such flag
 *            because that fork's -mmt=off already reaches this layer as
 *            threads == 0; 7-ZSTar builds on official 7-Zip, where a plain
 *            "nothing forced" also reaches us as 0, so the two have to be
 *            told apart here.
 *            (threadsset != 0, threads >= 1) is accepted and behaves like
 *            threadsset == 0: unlike sebres' branch, a forced *count* does
 *            not pin the container path, because in this project -mmt is
 *            official 7-Zip's CPU knob and must not change how a file is
 *            interpreted. Its only caller never emits that combination
 *            today, but a merge of sebres' commit would -- keep the routing
 *            as it is here if that happens.
 *            See CPP/7zip/Archive/BrotliHandler.cpp's ForceRawStream() for
 *            which command line reaches this, and why only that one.
 * @ inputsize - used for single threaded standard bro format without skippable frames
 */
BROTLIMT_DCtx *BROTLIMT_createDCtx(int threads, int threadsset, int inputsize);

/**
 * 2) threaded compression
 * - return -1 on error
 */
size_t BROTLIMT_decompressDCtx(BROTLIMT_DCtx * ctx, BROTLIMT_RdWr_t * rdwr);

/**
 * 3) get some statistic
 */
size_t BROTLIMT_GetFramesDCtx(BROTLIMT_DCtx * ctx);
size_t BROTLIMT_GetInsizeDCtx(BROTLIMT_DCtx * ctx);
size_t BROTLIMT_GetOutsizeDCtx(BROTLIMT_DCtx * ctx);

/**
 * 4) free cctx
 * - no special return value
 */
void BROTLIMT_freeDCtx(BROTLIMT_DCtx * ctx);

#if defined (__cplusplus)
}
#endif
#endif				/* BROTLIMT_H */
