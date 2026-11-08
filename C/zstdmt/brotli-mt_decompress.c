
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

#include <stdlib.h>
#include <string.h>

#include "decode.h"

#include "brotli-mt.h"
#include "memmt.h"
#include "threading.h"
#include "list.h"

/**
 * multi threaded brotli - multiple workers version
 *
 * - each thread works on his own
 * - no main thread which does reading and then starting the work
 * - needs a callback for reading / writing
 * - each worker does his:
 *   1) get read mutex and read some input
 *   2) release read mutex and do compression
 *   3) get write mutex and write result
 *   4) begin with step 1 again, until no input
 */

/* worker for compression */
typedef struct {
	BROTLIMT_DCtx *ctx;
	pthread_t pthread;
	BROTLIMT_Buffer in;
} cwork_t;

struct writelist;
struct writelist {
	size_t frame;
	BROTLIMT_Buffer out;
	struct list_head node;
};

struct BROTLIMT_DCtx_s {

	/* threads: 0, 1..BROTLIMT_THREAD_MAX */
	int threads;

	/* 7-ZSTar: non-zero when the caller pinned the decode mode instead of
	 * hinting a worker count; with threads == 0 it forces the raw decoder
	 * (the -mmt=0 escape hatch). See brotli-mt.h for why this needs its
	 * own field here but not in sebres' b4e36ba7. */
	int threadsset;

	/* should be used for read from input */
	size_t inputsize;

	/* statistic */
	size_t insize;
	size_t outsize;
	size_t curframe;
	size_t frames;

	/* 7-ZSTar: the whole 16-byte first frame header, read and validated
	 * by BROTLIMT_decompressDCtx()'s content probe; consumed by
	 * pt_read()'s frames == 0 special case instead of a second read.
	 * Written before any worker thread exists (pthread_create() is the
	 * ordering barrier), read under read_mutex. Only meaningful on the
	 * container path -- the raw path never looks at it. */
	unsigned char frame0_hdr[16];

	/* threading */
	cwork_t *cwork;

	/* reading input */
	pthread_mutex_t read_mutex;
	fn_read *fn_read;
	void *arg_read;

	/* writing output */
	pthread_mutex_t write_mutex;
	fn_write *fn_write;
	void *arg_write;

	/* lists for writing queue */
	struct list_head writelist_free;
	struct list_head writelist_busy;
	struct list_head writelist_done;
};

/* **************************************
 * Decompression
 ****************************************/

BROTLIMT_DCtx *BROTLIMT_createDCtx(int threads, int threadsset, int inputsize)
{
	BROTLIMT_DCtx *ctx;
	int t;

	/* check threads value */
	if (threads < 0 || threads > BROTLIMT_THREAD_MAX)
		return 0;

	/* allocate ctx */
	ctx = (BROTLIMT_DCtx *) malloc(sizeof(BROTLIMT_DCtx));
	if (!ctx)
		return 0;

	/* setup ctx */
	ctx->threads = threads;
	ctx->threadsset = threadsset;	/* 7-ZSTar: see brotli-mt.h */
	ctx->insize = 0;
	ctx->outsize = 0;
	ctx->frames = 0;
	ctx->curframe = 0;

	/* will be used for single stream only */
	if (inputsize)
		ctx->inputsize = inputsize;
	else
		ctx->inputsize = 1024 * 256; /* 256K buffer */

	/* Always initialize the mutexes/lists, even for threads==0: content
	 * based detection in BROTLIMT_decompressDCtx() may discover a
	 * brotli-mt container and promote ctx->threads to 1 after this call,
	 * at which point pt_read()/pt_write() need a valid read_mutex/
	 * write_mutex. The extra init/destroy cost for genuinely single
	 * threaded raw streams is negligible. */
	pthread_mutex_init(&ctx->read_mutex, NULL);
	pthread_mutex_init(&ctx->write_mutex, NULL);

	INIT_LIST_HEAD(&ctx->writelist_free);
	INIT_LIST_HEAD(&ctx->writelist_busy);
	INIT_LIST_HEAD(&ctx->writelist_done);

	if (!threads)
		threads = 1;

	ctx->cwork = (cwork_t *) malloc(sizeof(cwork_t) * threads);
	if (!ctx->cwork)
		goto err_cwork;

	for (t = 0; t < threads; t++) {
		cwork_t *w = &ctx->cwork[t];
		w->ctx = ctx;
	}

	return ctx;

 err_cwork:
	/* 7-ZSTar: the two mutexes are now initialized unconditionally above,
	   so this path has to destroy them; before that change threads == 0
	   never initialized them and a bare free(ctx) was correct. Not part of
	   upstream #541, which only made the init unconditional. */
	pthread_mutex_destroy(&ctx->read_mutex);
	pthread_mutex_destroy(&ctx->write_mutex);
	free(ctx);

	return 0;
}

/**
 * mt_error - return mt lib specific error code
 */
static size_t mt_error(int rv)
{
	switch (rv) {
	case -1:
		return MT_ERROR(read_fail);
	case -2:
		return MT_ERROR(canceled);
	case -3:
		return MT_ERROR(memory_allocation);
	}

	/* XXX, some catch all other errors */
	return MT_ERROR(read_fail);
}

/**
 * pt_write - queue for decompressed output
 */
static size_t pt_write(BROTLIMT_DCtx * ctx, struct writelist *wl)
{
	struct list_head *entry;

	/* move the entry to the done list */
	list_move(&wl->node, &ctx->writelist_done);
 again:
	/* check, what can be written ... */
	list_for_each(entry, &ctx->writelist_done) {
		wl = list_entry(entry, struct writelist, node);
		if (wl->frame == ctx->curframe) {
			int rv = ctx->fn_write(ctx->arg_write, &wl->out);
			if (rv != 0)
				return mt_error(rv);
			ctx->outsize += wl->out.size;
			ctx->curframe++;
			list_move(entry, &ctx->writelist_free);
			goto again;
		}
	}

	return 0;
}

/**
 * pt_read - read compressed output
 */
static size_t pt_read(BROTLIMT_DCtx * ctx, BROTLIMT_Buffer * in, size_t * frame, size_t * uncompressed)
{
	unsigned char hdrbuf[16];
	BROTLIMT_Buffer hdr;
	size_t result; int rv;

	/* read skippable frame (16 bytes; frame 0's arrives pre-read) */
	pthread_mutex_lock(&ctx->read_mutex);

	/* special case: the whole 16-byte header was already read (and its
	   fixed fields validated) by BROTLIMT_decompressDCtx()'s content
	   probe -- consume the parked copy instead of reading again.
	   7-ZSTar: the probe used to be 4 bytes wide, with the remaining 12
	   read here; see the detection comment in BROTLIMT_decompressDCtx(). */
	if (ctx->frames == 0) {
		memcpy(hdrbuf, ctx->frame0_hdr, 16);
		hdr.buf = hdrbuf;
		hdr.size = 16;
	} else {
		hdr.buf = hdrbuf;
		hdr.size = 16;
		rv = ctx->fn_read(ctx->arg_read, &hdr);
		if (rv != 0) {
			result = mt_error(rv);
			goto error;
		}
		/* eof reached ? */
		if (hdr.size == 0) {
			pthread_mutex_unlock(&ctx->read_mutex);
			in->size = 0;
			return 0;
		}
		if (hdr.size != 16) {
			result = hdr.size < 16 ? MT_ERROR(end_of_data) : MT_ERROR(read_fail);
			goto error;
		}
		if (MEM_readLE32((unsigned char *)hdr.buf + 0) !=
		    BROTLIMT_MAGIC_SKIPPABLE) {
			result = MT_ERROR(data_error);
			goto error;
		}
	}

	/* check header data */
	if (MEM_readLE32((unsigned char *)hdr.buf + 4) != 8) {
		result = MT_ERROR(data_error);
		goto error;
	}
	if (MEM_readLE16((unsigned char *)hdr.buf + 12) != BROTLIMT_MAGICNUMBER) {
		result = MT_ERROR(data_error);
		goto error;
	}

	/* get uncompressed size for output buffer */
	{
		U16 hintsize = MEM_readLE16((unsigned char *)hdr.buf + 14);
		/* 7-ZSTar: widen before shifting -- U16 promotes to int, so
		   a hint of 0x8000 or more overflowed it -- and bound the
		   result before pt_decompress() allocates it, see
		   MT_FRAME_SIZE_MAX in memmt.h. */
		*uncompressed = (size_t)hintsize << 16;
		if (*uncompressed > MT_FRAME_SIZE_MAX) {
			result = MT_ERROR(data_error);
			goto error;
		}
	}

	ctx->insize += 16;
	/* read new inputsize */
	{
		size_t toRead = MEM_readLE32((unsigned char *)hdr.buf + 8);
		/* 7-ZSTar: bound the compressed frame size before allocating
		   it; see MT_FRAME_CSIZE_MAX in memmt.h. */
		if (toRead > MT_FRAME_CSIZE_MAX) {
			result = MT_ERROR(data_error);
			goto error;
		}
		if (in->allocated < toRead) {
			/* need bigger input buffer */
			/* 7-ZSTar: realloc() leaves the old block allocated
			   when it fails, so assigning its result straight back
			   both loses that block and leaves in->allocated
			   describing a buffer that is now NULL -- the next
			   reuse of this cwork entry would read through it. Go
			   through a temporary and reset the pair together.
			   Not in any upstream PR yet. */
			void *newbuf;
			if (in->allocated)
				newbuf = realloc(in->buf, toRead);
			else
				newbuf = malloc(toRead);
			if (!newbuf) {
				free(in->buf);
				in->buf = 0;
				in->allocated = 0;
				result = MT_ERROR(memory_allocation);
				goto error;
			}
			in->buf = newbuf;
			in->allocated = toRead;
		}

		in->size = toRead;
		rv = ctx->fn_read(ctx->arg_read, in);
		/* generic read failure! */
		if (rv != 0) {
			result = mt_error(rv);
			goto error;
		}
		/* needed more bytes! */
		if (in->size != toRead) {
			result = in->size < toRead ? MT_ERROR(end_of_data) : MT_ERROR(data_error);
			goto error;
		}

		ctx->insize += in->size;
	}
	*frame = ctx->frames++;
	pthread_mutex_unlock(&ctx->read_mutex);

	/* done, no error */
	return 0;

 error:
	pthread_mutex_unlock(&ctx->read_mutex);
	return result;
}

static void *pt_decompress(void *arg)
{
	cwork_t *w = (cwork_t *) arg;
	BROTLIMT_Buffer *in = &w->in;
	BROTLIMT_DCtx *ctx = w->ctx;
	size_t result = 0;
	struct writelist *wl;

	for (;;) {
		struct list_head *entry;
		BROTLIMT_Buffer *out;
		int rv;

		/* allocate space for new output */
		pthread_mutex_lock(&ctx->write_mutex);
		if (!list_empty(&ctx->writelist_free)) {
			/* take unused entry */
			entry = list_first(&ctx->writelist_free);
			wl = list_entry(entry, struct writelist, node);
			list_move(entry, &ctx->writelist_busy);
		} else {
			/* allocate new one */
			wl = (struct writelist *)
			    malloc(sizeof(struct writelist));
			if (!wl) {
				result = MT_ERROR(memory_allocation);
				/* @wl was never acquired, nothing to give back */
				goto error_unlock_nowl;
			}
			wl->out.buf = 0;
			wl->out.size = 0;
			wl->out.allocated = 0;
			list_add(&wl->node, &ctx->writelist_busy);
		}
		pthread_mutex_unlock(&ctx->write_mutex);
		out = &wl->out;

		/* zero should not happen here! */
		result = pt_read(ctx, in, &wl->frame, &wl->out.size);
		if (BROTLIMT_isError(result)) {
			goto error_lock;
		}

		if (in->size == 0)
			break;

		if (out->allocated < out->size) {
			/* 7-ZSTar: same realloc() handling as in pt_read()
			   above, and here it is not only a leak -- this buffer
			   belongs to a writelist entry that goes straight back
			   on the free list via error_lock, so leaving
			   out->allocated non-zero next to a NULL out->buf hands
			   the next worker an entry it believes is usable. */
			void *newbuf;
			if (out->allocated)
				newbuf = realloc(out->buf, out->size);
			else
				newbuf = malloc(out->size);
			if (!newbuf) {
				free(out->buf);
				out->buf = 0;
				out->allocated = 0;
				result = MT_ERROR(memory_allocation);
				goto error_lock;
			}
			out->buf = newbuf;
			out->allocated = out->size;
		}

		rv =
		    BrotliDecoderDecompress(in->size, in->buf, &out->size,
					    out->buf);

		if (rv != BROTLI_DECODER_RESULT_SUCCESS) {
			result = MT_ERROR(frame_decompress);
			goto error_lock;
		}

		/* write result */
		pthread_mutex_lock(&ctx->write_mutex);
		result = pt_write(ctx, wl);
		if (BROTLIMT_isError(result))
			goto error_unlock;
		pthread_mutex_unlock(&ctx->write_mutex);
	}

	/* everything is okay */
	result = 0;

 error_lock:
	pthread_mutex_lock(&ctx->write_mutex);
 error_unlock:
	list_move(&wl->node, &ctx->writelist_free);
 error_unlock_nowl:
	pthread_mutex_unlock(&ctx->write_mutex);
	if (in->allocated)
		free(in->buf);
	return (void *)result;
}

/*
 * st_prime_input - seed @in with the @prefixSize bytes already consumed
 * from the stream by BROTLIMT_decompressDCtx() while probing for the
 * brotli-mt container magic, then top up with a fresh read for the rest
 * of the buffer. Called once, before st_decompress()'s main loop starts,
 * so this priming logic does not add to that loop's complexity. Mirrors
 * the "we have read already 4 bytes" prefix handling in LZ4MT
 * st_decompress() (lz4-mt_decompress.c).
 *
 * On return, in->size holds the total number of valid bytes now sitting
 * in in->buf. Returns 0 on success, or an MT_ERROR() code if the
 * underlying read fails.
 */
static size_t st_prime_input(BROTLIMT_DCtx *ctx, BROTLIMT_Buffer *in, const unsigned char *prefix, size_t prefixSize)
{
	int rv;

	memcpy(in->buf, prefix, prefixSize);
	in->size = prefixSize;

	if (in->allocated > prefixSize) {
		BROTLIMT_Buffer tail;
		tail.buf = (unsigned char *)in->buf + prefixSize;
		tail.size = in->allocated - prefixSize;
		tail.allocated = tail.size;
		rv = ctx->fn_read(ctx->arg_read, &tail);
		if (rv != 0)
			return mt_error(rv);
		in->size += tail.size;
	}

	return 0;
}

/*
 * st_finish_decompress - after st_decompress()'s main loop exits, check
 * the stream finished cleanly and flush whatever output is still sitting
 * in the output buffer. Split out (pre-existing logic, not new in this
 * change) so it doesn't add to the main loop function's complexity either.
 */
static size_t st_finish_decompress(BROTLIMT_DCtx *ctx, BROTLIMT_Buffer *out, uint8_t *next_out, BrotliDecoderResult bres)
{
	int rv;

	if (bres != BROTLI_DECODER_RESULT_SUCCESS) {
		return MT_ERROR(data_error); // corrupt input
	}

	out->size = next_out - (uint8_t *)out->buf;
	if (out->size != 0) {
		rv = ctx->fn_write(ctx->arg_write, out);
		if (rv != 0)
			return mt_error(rv);
	}

	return 0;
}

/*
 * 7-ZSTar: st_drain_output - the input ended before the stream did, so hand
 * over everything decoded so far; st_decompress() reports end_of_data after
 * this returns. Two places hold it: @out up to @next_out, and the decoder's
 * ring buffer. The second matters because, on NEEDS_MORE_INPUT, the decoder
 * pushes only what fits in @out and keeps the rest (it drops the
 * NEEDS_MORE_OUTPUT of that push, see BrotliDecoderDecompressStream()), so
 * flushing @out alone stops at one buffer's worth. TakeOutput rather than
 * another DecompressStream call, because that push never wraps the ring
 * buffer and TakeOutput does. Not in any upstream PR yet.
 */
static size_t st_drain_output(BROTLIMT_DCtx *ctx, BrotliDecoderState *state, BROTLIMT_Buffer *out, uint8_t *next_out)
{
	int rv;

	out->size = next_out - (uint8_t *)out->buf;
	if (out->size != 0) {
		rv = ctx->fn_write(ctx->arg_write, out);
		if (rv != 0)
			return mt_error(rv);
	}

	while (BrotliDecoderHasMoreOutput(state)) {
		BROTLIMT_Buffer rest;
		size_t size = 0;	/* any amount; one call may not return it all */
		const uint8_t *data = BrotliDecoderTakeOutput(state, &size);

		if (size == 0)
			break;
		rest.buf = (void *)data;	/* fn_write only reads it */
		rest.size = size;
		rest.allocated = size;
		rv = ctx->fn_write(ctx->arg_write, &rest);
		if (rv != 0)
			return mt_error(rv);
	}

	return 0;
}

/*
 * single threaded (standard brotli stream, without header/mt-frames)
 *
 * @prefix/@prefixSize: bytes already consumed from the stream (by
 * BROTLIMT_decompressDCtx() while probing for the brotli-mt container
 * magic) that must be fed back as the beginning of the decoded data;
 * see st_prime_input() above.
 */
static size_t st_decompress(BROTLIMT_DCtx *ctx, const unsigned char *prefix, size_t prefixSize)
{
	BrotliDecoderResult bres;
	cwork_t *w = &ctx->cwork[0];
	BROTLIMT_Buffer Out;
	BROTLIMT_Buffer *out = &Out;
	BROTLIMT_Buffer *in = &w->in;
	BrotliDecoderState *state;
	const uint8_t* next_in;
	uint8_t* next_out;
	int rv;
	size_t retval = 0;
	size_t allocSize = ctx->inputsize;

	/* allocate space for input buffer; must be able to hold at least the
	   already-consumed prefix bytes, in case ctx->inputsize was configured
	   smaller than prefixSize (7-ZSTar: prefixSize is at most 16 today --
	   the whole-header width of the widened container probe in
	   BROTLIMT_decompressDCtx(); it was at most 4 upstream) */
	if (allocSize < prefixSize)
		allocSize = prefixSize;
	in->allocated = allocSize;
	in->size = allocSize;
	in->buf = malloc(in->size);
	if (!in->buf)
		return MT_ERROR(memory_allocation);

	/* allocate space for output buffer */
	out->allocated = out->size = ctx->inputsize * 4;
	out->buf = malloc(out->size);
	if (!out->buf) {
		free(in->buf);
		return MT_ERROR(memory_allocation);
	}
	next_out = out->buf;

	state = BrotliDecoderCreateInstance(NULL, NULL, NULL);
	if (!state) {
		free(in->buf);
		free(out->buf);
	  return MT_ERROR(memory_allocation);
	}
	BrotliDecoderSetParameter(state, BROTLI_DECODER_PARAM_LARGE_WINDOW, 1);

	/* prime the input buffer with whatever was already consumed while
	   probing for the container magic, then start the loop by feeding
	   it straight to the decoder (rather than reading again) */
	retval = st_prime_input(ctx, in, prefix, prefixSize);
	if (BROTLIMT_isError(retval))
		goto done;
	next_in = in->buf;

	while (1) {
		bres = BrotliDecoderDecompressStream(state, &in->size, &next_in, &out->size, &next_out, 0);

		if (bres == BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT) {
			in->size = in->allocated;
			rv = ctx->fn_read(ctx->arg_read, in);
			if (in->size == 0) {
				/* 7-ZSTar: keep what decoded before the cut; a
				   failed write outranks end_of_data, as it does
				   on every other write in this loop. */
				retval = st_drain_output(ctx, state, out, next_out);
				if (!BROTLIMT_isError(retval))
					retval = MT_ERROR(end_of_data); // unexpected end of data
				goto done;
			}
			if (rv != 0) {
				retval = mt_error(rv);
				goto done;
			}
			next_in = in->buf;
		} else if (bres == BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT) {
			out->size = next_out - (uint8_t*)out->buf;
			rv = ctx->fn_write(ctx->arg_write, out);
			if (rv != 0) {
				retval = mt_error(rv);
				goto done;
			}
			next_out = out->buf;
		} else {
			break;
		}
	}

	retval = st_finish_decompress(ctx, out, next_out, bres);

 done:
		free(in->buf);
		free(out->buf);
		BrotliDecoderDestroyInstance(state);
		return retval;
}

size_t BROTLIMT_decompressDCtx(BROTLIMT_DCtx * ctx, BROTLIMT_RdWr_t * rdwr)
{
	/* 7-ZSTar: sized to the whole first frame header; the content probe
	   below validates all of it, not just the 4-byte magic. */
	unsigned char buf[16];
	int t, rv;
	cwork_t *w;
	BROTLIMT_Buffer *in;
	void *retval_of_thread = 0;

	/* 7-ZSTar: the NULL check has to come before the initializers below,
	   which read ctx->cwork and so dereference ctx -- a NULL ctx crashed
	   here instead of returning the error this check exists to return.
	   Not in any upstream PR yet; same shape in all four siblings. */
	if (!ctx)
		return MT_ERROR(compressionParameter_unsupported);

	w = &ctx->cwork[0];
	in = &w->in;

	/* init reading and writing functions */
	ctx->fn_read = rdwr->fn_read;
	ctx->fn_write = rdwr->fn_write;
	ctx->arg_read = rdwr->arg_read;
	ctx->arg_write = rdwr->arg_write;

	/*
	 * Always peek the stream head and decide raw-vs-mt-container from the
	 * *file content*, regardless of the caller-requested thread count
	 * (ctx->threads) and of whether -mmt was passed for *this* invocation.
	 * This mirrors what e.g. LZ4MT_decompressDCtx() already does for
	 * lz4/lz5/lizard in this same directory (see lz4-mt_decompress.c).
	 *
	 * 7-ZSTar: unless the caller pinned the mode. (threadsset != 0,
	 * threads == 0) means "decode this as raw brotli, whatever it looks
	 * like" and skips the probe below -- the escape hatch ported from
	 * sebres' b4e36ba7, reached from an explicit -mmt=0 (see
	 * CPP/7zip/Archive/BrotliHandler.cpp's ForceRawStream()). It is the
	 * only way out if a raw stream ever does collide with the container
	 * header, since detection replaced the old threads == 0 selector and
	 * the probe below, however wide, cannot reach zero on a format with no
	 * signature (see upstream #538). The head is still
	 * read first so the hatch loses nothing: every probed byte is handed
	 * straight back to the raw decoder below, and a stream shorter than the
	 * probe still round-trips.
	 *
	 * 7-ZSTar: the probe covers the whole 16-byte first frame header, not
	 * just the 4 magic bytes, and requires *all* the fixed fields that
	 * pt_read() would go on to check anyway (offset +0 == skippable
	 * magic, +4 == 8, +12 == BROTLIMT_MAGICNUMBER) before committing to
	 * the container path. Rationale: unlike lz4/lz5/lizard, raw Brotli
	 * has no signature of its own, so with the previous 4-byte probe a
	 * raw stream coincidentally starting with the magic (~2^-32, and
	 * reachable: the first byte's low bit is 0 for lgwin 16, so 0x50 is a
	 * legal opening byte) was routed to the container path and died there
	 * with a data error, at a time when content detection had replaced the
	 * old threads==0 selector and nothing re-routed such a file to the raw
	 * decoder (the hatch above is the answer to that; this probe width is
	 * what keeps anyone from needing it). Requiring all 80 fixed
	 * header bits makes that stream fall through to the raw decoder and
	 * simply decode correctly; the residual chance of a valid raw stream
	 * still entering the container path drops to ~2^-80, and even that
	 * one fails hard on the frame payload rather than silently handing
	 * back wrong bytes. A genuine container truncated inside its first
	 * header now also lands in the raw decoder (and still fails with a
	 * data error, just via a different path than before).
	 */
	in->buf = buf;
	in->size = sizeof(buf);
	rv = ctx->fn_read(ctx->arg_read, in);
	if (rv != 0)
		return mt_error(rv);

	if ((ctx->threadsset && ctx->threads == 0) /* 7-ZSTar: forced raw */
	    || in->size != sizeof(buf)
	    || MEM_readLE32(buf) != BROTLIMT_MAGIC_SKIPPABLE
	    || MEM_readLE32(buf + 4) != 8
	    || MEM_readLE16(buf + 12) != BROTLIMT_MAGICNUMBER) {
		/* raw single threaded brotli stream (no header, no mt-frames):
		   hand back whatever bytes we already consumed above. */
		return st_decompress(ctx, buf, in->size);
	}

	/* 7-ZSTar: park the validated header for pt_read()'s frames == 0
	   special case, which used to read its tail 12 bytes itself when the
	   probe was only 4 bytes wide. */
	memcpy(ctx->frame0_hdr, buf, sizeof(buf));

	/*
	 * brotli-mt container detected: make sure we actually use the
	 * framed/multithreaded decode path, even if the caller asked for
	 * threads==0 (e.g. testing/extracting without -mmt). read_mutex/
	 * write_mutex/writelist_* are always initialized in
	 * BROTLIMT_createDCtx() now, so this promotion is safe even when the
	 * context was originally created with threads==0.
	 */
	if (ctx->threads == 0)
		ctx->threads = 1;

	/* mark unused */
	in->buf = 0;
	in->size = 0;
	in->allocated = 0;

	/* single threaded, but with known sizes */
	if (ctx->threads == 1) {
		/* no pthread_create() needed! */
		void *p = pt_decompress(w);
		if (p)
			retval_of_thread = p;
		goto done;
	}

	/* multi threaded */
	for (t = 0; t < ctx->threads; t++) {
		cwork_t *wt = &ctx->cwork[t];
		wt->in.buf = 0;
		wt->in.size = 0;
		wt->in.allocated = 0;
		pthread_create(&wt->pthread, NULL, pt_decompress, wt);
	}

	/* wait for all workers */
	for (t = 0; t < ctx->threads; t++) {
		cwork_t *wt = &ctx->cwork[t];
		void *p = 0;
		pthread_join(wt->pthread, &p);
		if (p)
			retval_of_thread = p;
	}

 done:
	/* move remaining done/busy entries to free list */
	while (!list_empty(&ctx->writelist_done)) {
		struct list_head *entry = list_first(&ctx->writelist_done);
		list_move(entry, &ctx->writelist_free);
	}
	while (!list_empty(&ctx->writelist_busy)) {
		struct list_head* entry = list_first(&ctx->writelist_busy);
		list_move(entry, &ctx->writelist_free);
	}
	/* clean up the buffers */
	while (!list_empty(&ctx->writelist_free)) {
		struct writelist *wl;
		struct list_head *entry;
		entry = list_first(&ctx->writelist_free);
		wl = list_entry(entry, struct writelist, node);
		free(wl->out.buf);
		list_del(&wl->node);
		free(wl);
	}

	return (size_t) retval_of_thread;
}

/* returns current uncompressed data size */
size_t BROTLIMT_GetInsizeDCtx(BROTLIMT_DCtx * ctx)
{
	if (!ctx)
		return 0;

	return ctx->insize;
}

/* returns the current compressed data size */
size_t BROTLIMT_GetOutsizeDCtx(BROTLIMT_DCtx * ctx)
{
	if (!ctx)
		return 0;

	return ctx->outsize;
}

/* returns the current compressed frames */
size_t BROTLIMT_GetFramesDCtx(BROTLIMT_DCtx * ctx)
{
	if (!ctx)
		return 0;

	return ctx->curframe;
}

void BROTLIMT_freeDCtx(BROTLIMT_DCtx * ctx)
{
	if (!ctx)
		return;

	/* read_mutex/write_mutex are now always initialized in
	 * BROTLIMT_createDCtx(), regardless of the initial threads value
	 * (see comment there), so always destroy them here too. */
	pthread_mutex_destroy(&ctx->read_mutex);
	pthread_mutex_destroy(&ctx->write_mutex);
	free(ctx->cwork);
	free(ctx);
	ctx = 0;

	return;
}
