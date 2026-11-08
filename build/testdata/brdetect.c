/*
 * 7-ZSTar brotli 16-byte content-detection harness (ASCII only).
 *
 * Links the real production sources (C/zstdmt/brotli-mt_*.c plus the
 * vendored brotli library) and drives BROTLIMT_decompressDCtx() through
 * in-memory callbacks that keep a log of every read request, so the tests
 * can assert not just *what* came out but *which path* produced it (the
 * container path's telltale under the old 4-byte probe was a 12-byte
 * header-tail read right after the probe; the raw path's is one large
 * input top-up read).
 *
 * T10-T12 cover the forced-raw escape hatch (-mmt=0) instead. What they
 * cannot show is the hatch rescuing a real collision, because no raw stream
 * is known that survives the 16-byte probe -- the same limitation upstream
 * records for its own kit. They show the two properties that would make such
 * a stream recoverable if one existed: the hatch reaches the raw decoder
 * whatever the content looks like, and it returns exactly what detection
 * would have returned on a stream that was raw all along.
 *
 * Two modes (build instructions: README.md next to this file):
 *   brdetect              run the detection test suite against whatever
 *                         tree it was compiled from; exits non-zero on
 *                         any failure. Compiled against a pre-hardening
 *                         tree, exactly the probe-width/routing
 *                         assertions (T1b, T5b, T9b) fail - that
 *                         differential is the change's proof.
 *   brdetect --emit <dir> write the deterministic test vectors used by
 *                         build/Test-Smoke.ps1 (mt-brotli.br, its raw
 *                         payload, fake-magic.br, corrupt-hdr.br).
 */

#define _CRT_SECURE_NO_WARNINGS /* fopen() in emit_vector(); dev tool */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h> /* brotli-mt.h uses uint64_t but only includes stddef.h */

#include "brotli-mt.h"

#define PAYLOAD_LEN   200000   /* ~4 frames at the 64K chunk size below */
#define CHUNK_SIZE    (64 * 1024)
#define MT_THREADS    2
#define LEVEL         5
#define LGWIN         24       /* BROTLI_MAX_WINDOW_BITS, what the encoder wrapper passes */

static int g_fail;

static void check(int ok, const char *name, const char *detail)
{
	printf("  %s  %s%s%s\n", ok ? "PASS" : "FAIL", name,
	       (!ok && detail) ? " -- " : "", (!ok && detail) ? detail : "");
	if (!ok)
		g_fail++;
}

/* ---------------- in-memory decode stream with a read log ---------------- */

#define MAX_READS 512
static const unsigned char *g_in;
static size_t g_inLen, g_inPos;
static size_t g_readReq[MAX_READS];
static int g_reads;

static unsigned char *g_out;
static size_t g_outLen, g_outCap;

static int mem_read(void *arg, BROTLIMT_Buffer *in)
{
	size_t want = in->size;
	size_t have = g_inLen - g_inPos;
	(void)arg;
	if (g_reads < MAX_READS)
		g_readReq[g_reads] = in->size;
	g_reads++;
	if (want > have)
		want = have;
	memcpy(in->buf, g_in + g_inPos, want);
	g_inPos += want;
	in->size = want;
	return 0;
}

static int mem_write(void *arg, BROTLIMT_Buffer *out)
{
	(void)arg;
	if (g_outLen + out->size > g_outCap) {
		size_t want = (g_outLen + out->size) * 2 + 4096;
		unsigned char *p = (unsigned char *)realloc(g_out, want);
		if (!p)
			return -1;
		g_out = p;
		g_outCap = want;
	}
	memcpy(g_out + g_outLen, out->buf, out->size);
	g_outLen += out->size;
	return 0;
}

static size_t decode_ts(const unsigned char *in, size_t inLen, int threads,
			int threadsset)
{
	BROTLIMT_RdWr_t rdwr;
	BROTLIMT_DCtx *ctx;
	size_t r;

	g_in = in;
	g_inLen = inLen;
	g_inPos = 0;
	g_reads = 0;
	g_outLen = 0;

	rdwr.fn_read = mem_read;
	rdwr.fn_write = mem_write;
	rdwr.arg_read = NULL;
	rdwr.arg_write = NULL;

	ctx = BROTLIMT_createDCtx(threads, threadsset, 0);
	if (!ctx)
		return (size_t)-BROTLIMT_error_memory_allocation;
	r = BROTLIMT_decompressDCtx(ctx, &rdwr);
	BROTLIMT_freeDCtx(ctx);
	return r;
}

/* content detection, i.e. no decode mode pinned by the caller */
static size_t decode(const unsigned char *in, size_t inLen, int threads)
{
	return decode_ts(in, inLen, threads, 0);
}

/* the forced-raw escape hatch: threadsset with a thread count of 0 */
static size_t decode_raw(const unsigned char *in, size_t inLen)
{
	return decode_ts(in, inLen, 0, 1);
}

/* ---------------- compress helper (production encoder) ---------------- */

static const unsigned char *g_cin;
static size_t g_cinLen, g_cinPos;
static unsigned char *g_arc;
static size_t g_arcLen, g_arcCap;

static int c_read(void *arg, BROTLIMT_Buffer *in)
{
	size_t want = in->size;
	size_t have = g_cinLen - g_cinPos;
	(void)arg;
	if (want > have)
		want = have;
	memcpy(in->buf, g_cin + g_cinPos, want);
	g_cinPos += want;
	in->size = want;
	return 0;
}

static int c_write(void *arg, BROTLIMT_Buffer *out)
{
	(void)arg;
	if (g_arcLen + out->size > g_arcCap) {
		size_t want = (g_arcLen + out->size) * 2 + 4096;
		unsigned char *p = (unsigned char *)realloc(g_arc, want);
		if (!p)
			return -1;
		g_arc = p;
		g_arcCap = want;
	}
	memcpy(g_arc + g_arcLen, out->buf, out->size);
	g_arcLen += out->size;
	return 0;
}

/* Returns a malloc'd stream (caller frees), or NULL. threads==0 -> raw. */
static unsigned char *build_stream(int threads, const unsigned char *payload,
				   size_t n, size_t *outLen)
{
	BROTLIMT_RdWr_t rdwr;
	BROTLIMT_CCtx *ctx;
	size_t r;
	unsigned char *result;

	g_cin = payload;
	g_cinLen = n;
	g_cinPos = 0;
	g_arc = NULL;
	g_arcLen = g_arcCap = 0;

	rdwr.fn_read = c_read;
	rdwr.fn_write = c_write;
	rdwr.arg_read = NULL;
	rdwr.arg_write = NULL;

	ctx = BROTLIMT_createCCtx(threads, n, LEVEL, CHUNK_SIZE, LGWIN);
	if (!ctx)
		return NULL;
	r = BROTLIMT_compressCCtx(ctx, &rdwr);
	BROTLIMT_freeCCtx(ctx);
	if (BROTLIMT_isError(r)) {
		free(g_arc);
		return NULL;
	}
	result = g_arc;
	*outLen = g_arcLen;
	g_arc = NULL;
	return result;
}

static unsigned char *make_payload(size_t n)
{
	unsigned char *p = (unsigned char *)malloc(n ? n : 1);
	size_t i;
	if (!p)
		return NULL;
	/* semi-compressible, deterministic */
	for (i = 0; i < n; i++)
		p[i] = (unsigned char)((i * 7) ^ (i >> 5) ^ (i >> 11));
	return p;
}

static int out_equals(const unsigned char *want, size_t n)
{
	return g_outLen == n && (n == 0 || memcmp(g_out, want, n) == 0);
}

/* ---------------- --emit mode ---------------- */

static int write_file(const char *dir, const char *name,
		      const unsigned char *data, size_t len)
{
	char path[1024];
	FILE *f;

	if (snprintf(path, sizeof(path), "%s\\%s", dir, name) >= (int)sizeof(path)) {
		fprintf(stderr, "emit: directory path too long\n");
		return 1;
	}
	f = fopen(path, "wb");
	if (!f || fwrite(data, 1, len, f) != len) {
		fprintf(stderr, "emit: cannot write %s\n", path);
		if (f)
			fclose(f);
		return 1;
	}
	fclose(f);
	printf("wrote %s (%u bytes)\n", path, (unsigned)len);
	return 0;
}

static int emit_vector(const char *dir)
{
	unsigned char *payload = make_payload(PAYLOAD_LEN);
	unsigned char *arc;
	size_t arcLen;
	int err = 1;

	if (!payload) {
		fprintf(stderr, "emit: payload allocation failed\n");
		return 1;
	}
	arc = build_stream(MT_THREADS, payload, PAYLOAD_LEN, &arcLen);
	if (!arc) {
		fprintf(stderr, "emit: container construction failed\n");
		free(payload);
		return 1;
	}
	printf("container first bytes %02X %02X %02X %02X\n",
	       arc[0], arc[1], arc[2], arc[3]);

	if (write_file(dir, "mt-brotli.br", arc, arcLen))
		goto done;
	if (write_file(dir, "mt-brotli", payload, PAYLOAD_LEN))
		goto done;

	/* fake-magic.br: the 4 container magic bytes a raw brotli stream
	   could legitimately open with, followed by bytes that fail the
	   rest of the 16-byte check (not valid brotli either, so decoding
	   it must end in a data error -- the point is the error must come
	   from the *raw* path and read "Data Error", not "Unspecified").
	   Committed as a vector so Test-Smoke.ps1 never has to write raw
	   bytes from script (script-side byte dropping is exactly the
	   pattern that got the suite quarantined by AV heuristics). */
	{
		unsigned char fake[64];
		size_t i;
		fake[0] = 0x50; fake[1] = 0x2A; fake[2] = 0x4D; fake[3] = 0x18;
		for (i = 4; i < sizeof(fake); i++)
			fake[i] = (unsigned char)((i * 37 + 11) % 251);
		if (write_file(dir, "fake-magic.br", fake, sizeof(fake)))
			goto done;
	}

	/* corrupt-hdr.br: the genuine container with its size==8 header
	   field broken, so the 16-byte check fails past the magic. Same
	   committed-vector rationale as above. */
	arc[4] ^= 0xFF;
	err = write_file(dir, "corrupt-hdr.br", arc, arcLen);
	arc[4] ^= 0xFF;
	if (err)
		goto done;

	err = 0;
 done:
	free(arc);
	free(payload);
	return err;
}

/* ---------------- tests ---------------- */

int main(int argc, char **argv)
{
	unsigned char *payload, *raw, *mt;
	size_t rawLen, mtLen, r;
	unsigned char tinyPayload[1] = { 'A' };
	unsigned char *tiny;
	size_t tinyLen;

	if (argc == 3 && strcmp(argv[1], "--emit") == 0)
		return emit_vector(argv[2]);

	payload = make_payload(PAYLOAD_LEN);
	if (!payload) {
		printf("OOM\n");
		return 2;
	}

	raw = build_stream(0, payload, PAYLOAD_LEN, &rawLen);
	mt = build_stream(MT_THREADS, payload, PAYLOAD_LEN, &mtLen);
	tiny = build_stream(0, tinyPayload, 1, &tinyLen);
	if (!raw || !mt || !tiny) {
		printf("stream construction failed\n");
		return 2;
	}

	/* sanity on the fixtures themselves */
	check(!(rawLen >= 4 && raw[0] == 0x50 && raw[1] == 0x2A &&
		raw[2] == 0x4D && raw[3] == 0x18),
	      "fixture: raw stream does not open with the container magic", NULL);
	check(mtLen >= 16 && mt[0] == 0x50 && mt[1] == 0x2A &&
	      mt[2] == 0x4D && mt[3] == 0x18,
	      "fixture: mt stream opens with the container magic", NULL);
	check(tinyLen > 0 && tinyLen < 16,
	      "fixture: tiny raw stream is shorter than the 16-byte probe", NULL);

	/* T1a: raw round-trip, threads unforced */
	r = decode(raw, rawLen, 0);
	check(!BROTLIMT_isError(r) && out_equals(payload, PAYLOAD_LEN),
	      "T1a raw stream decodes correctly (threads 0)", NULL);

	/* T1b: the probe asks for the whole 16-byte header up front */
	check(g_reads >= 1 && g_readReq[0] == 16,
	      "T1b first read request is the 16-byte header probe",
	      "first request was not 16 bytes (4 = pre-change probe)");

	/* T2: raw stream still decodes when a thread count is forced */
	r = decode(raw, rawLen, 8);
	check(!BROTLIMT_isError(r) && out_equals(payload, PAYLOAD_LEN),
	      "T2 raw stream decodes correctly (threads 8)", NULL);

	/* T3: mt container, threads unforced (0 -> promoted internally) */
	r = decode(mt, mtLen, 0);
	check(!BROTLIMT_isError(r) && out_equals(payload, PAYLOAD_LEN),
	      "T3 mt container decodes correctly (threads 0)", NULL);

	/* T4: mt container, several workers racing for the parked header */
	r = decode(mt, mtLen, 4);
	check(!BROTLIMT_isError(r) && out_equals(payload, PAYLOAD_LEN),
	      "T4 mt container decodes correctly (threads 4)", NULL);

	/* T5: raw-looking garbage that passes only the 4-byte magic:
	   must be routed to the raw decoder (big single-stream top-up read
	   follows the probe), not to the container path (whose telltale is
	   a 12-byte header-tail read after a 4-byte probe). */
	{
		unsigned char fake[64];
		size_t i;
		fake[0] = 0x50; fake[1] = 0x2A; fake[2] = 0x4D; fake[3] = 0x18;
		for (i = 4; i < sizeof(fake); i++)
			fake[i] = (unsigned char)((i * 37 + 11) % 251);
		r = decode(fake, sizeof(fake), 0);
		check(BROTLIMT_isError(r) &&
		      r == (size_t)-BROTLIMT_error_data_error,
		      "T5a fake-magic garbage fails with data_error", NULL);
		check(g_reads >= 2 && g_readReq[0] == 16 && g_readReq[1] > 64,
		      "T5b fake-magic garbage was routed to the raw decoder",
		      "read log shows the container path (4 then 12), not raw");
	}

	/* T9: passes magic and the +4==8 field, fails the +12 magicnumber */
	{
		unsigned char fake[64];
		size_t i;
		memset(fake, 0, sizeof(fake));
		fake[0] = 0x50; fake[1] = 0x2A; fake[2] = 0x4D; fake[3] = 0x18;
		fake[4] = 0x08;                     /* LE32 +4 == 8 */
		fake[8] = 0x10;                     /* plausible size field */
		/* +12/+13 left 0x0000 != BROTLIMT_MAGICNUMBER (0x5242) */
		for (i = 16; i < sizeof(fake); i++)
			fake[i] = (unsigned char)((i * 53 + 7) % 249);
		r = decode(fake, sizeof(fake), 0);
		check(BROTLIMT_isError(r),
		      "T9a magic+size match, wrong magicnumber: still an error", NULL);
		check(g_reads >= 2 && g_readReq[0] == 16 && g_readReq[1] > 64,
		      "T9b ...and was routed to the raw decoder",
		      "read log shows the container path, not raw");
	}

	/* T6: genuine container truncated inside its first header */
	r = decode(mt, 10, 0);
	check(BROTLIMT_isError(r),
	      "T6 container truncated inside the first header errors out", NULL);

	/* T7: tiny raw stream, shorter than the probe */
	r = decode(tiny, tinyLen, 0);
	check(!BROTLIMT_isError(r) && out_equals(tinyPayload, 1),
	      "T7 tiny raw stream (shorter than the probe) decodes", NULL);

	/* T8: empty input is an error (no crash, no false success) */
	r = decode(raw, 0, 0);
	check(BROTLIMT_isError(r),
	      "T8 empty input reports an error", NULL);

	/* T10-T12: the forced-raw escape hatch (-mmt=0). Together these are
	   the property that makes a header collision survivable: the hatch
	   reaches the raw decoder whatever the content says (T10), and it
	   gives back exactly what detection would have, so nothing is lost by
	   reaching for it (T11, T12). */

	/* T10a: a genuine container, forced raw, must NOT be decoded as a
	   container -- otherwise detection is still in charge and the hatch is
	   decorative. Reading a skippable frame header as brotli fails. */
	r = decode_raw(mt, mtLen);
	check(BROTLIMT_isError(r),
	      "T10a hatch overrides detection on a real container", NULL);
	/* T10b: ...and it got there via the raw decoder's one large top-up
	   read, not the container path (same telltale as T5b/T9b). */
	check(g_reads >= 2 && g_readReq[0] == 16 && g_readReq[1] > 64,
	      "T10b container under the hatch was routed to the raw decoder",
	      "read pattern does not match the raw path");

	/* T11: a raw stream decodes identically with the hatch and without,
	   i.e. every probed byte is handed back intact. */
	r = decode_raw(raw, rawLen);
	check(!BROTLIMT_isError(r) && out_equals(payload, PAYLOAD_LEN),
	      "T11 raw stream decodes correctly under the hatch", NULL);

	/* T12: including one shorter than the probe itself (cf. T7). */
	r = decode_raw(tiny, tinyLen);
	check(!BROTLIMT_isError(r) && out_equals(tinyPayload, 1),
	      "T12 tiny raw stream decodes under the hatch", NULL);

	printf("%s\n", g_fail ? "FAILURES PRESENT" : "ALL OK");
	free(raw); free(mt); free(tiny); free(payload); free(g_out);
	return g_fail ? 1 : 0;
}
