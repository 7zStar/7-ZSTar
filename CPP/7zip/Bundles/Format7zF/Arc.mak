# 7-ZSTar: required for zstd's own multithreaded compression (ZSTDMT, via
# ZSTD_c_nbWorkers); without it, ZSTD_CCtx_setParameter(..., ZSTD_c_nbWorkers, N>0)
# fails outright instead of silently degrading. Placed here (not per-bundle)
# because Arc.mak is shared by Format7zF, ../Alone2, and ../Fm (all three
# !include it) -- CPP/7zip/Bundles/Alone/makefile does not include Arc.mak, so
# it repeats this flag on its own CFLAGS line instead.
#
# -wd4710/-wd4711/-wd4820/-wd4464/-wd4574/-wd5045 : vendored C/zstd + C/hashes
# (xxHash) are compiled under this project's own -Wall -WX, but don't include
# this project's C/Compiler.h (which already disables 4710/4711/4820/4464/5045
# for our own code -- see there). 4574 (__has_builtin redefined) is a known
# MSVC-vs-zstd compiler.h interaction on newer Windows SDKs. None of these are
# correctness warnings; matches this project's own existing suppression
# policy, just extended to reach third-party TUs that don't share our
# pragmas. Confirmed exhaustive by probe-compiling every vendored .c under
# -Wall (no -WX) directly: only these 6 codes ever fire, across all 21 files.
#
# 7-ZSTar: M6a -- extended for C/brotli, C/lz4, C/lz5, C/lizard,
# C/fast-lzma2, C/zstdmt (see each dir's UPSTREAM.txt): -wd4061 (switch on
# enum not exhaustive; every such switch already has a default: case),
# -wd4191 (function pointer type cast; radix match-finder/util dispatch
# tables), -wd4255 (K&R-style '()' vs '(void)' prototype), -wd4668
# ('__INTEL_COMPILER' undefined, replaced with 0 in #if -- we never build
# with ICC). Same non-correctness rationale as the six above. Confirmed
# exhaustive by the same single-file /Wall (no -WX) probe method used for
# zstd, re-run across all 6 new library directories (110 .c files); the
# probe script itself is not kept in this repository.
#
# 7-ZSTar: M8 -- -wd4777 (printf format vs argument type). Both probes above
# were run on x64 only, and this one fires exclusively on x86:
# C/fast-lzma2/radix_engine.h passes (U32)pos to a "%X", which on x86 is a
# no-op cast because size_t and unsigned int are the same 32-bit type. MSVC
# then reports the argument under its original typedef name ("size_t") and
# warns, even though the format is correct for a 32-bit unsigned. On x64 the
# cast truncates for real, so the warning never appears there. The code is
# right either way; only the diagnostic differs. Lesson recorded because the
# comments above claim exhaustiveness that was in fact architecture-specific.
CFLAGS = $(CFLAGS) -DZSTD_MULTITHREAD -wd4710 -wd4711 -wd4820 -wd4464 -wd4574 -wd5045 -wd4061 -wd4191 -wd4255 -wd4668 -wd4777

COMMON_OBJS = \
  $O\CRC.obj \
  $O\CrcReg.obj \
  $O\DynLimBuf.obj \
  $O\IntToString.obj \
  $O\LzFindPrepare.obj \
  $O\Md5Reg.obj \
  $O\MyMap.obj \
  $O\MyString.obj \
  $O\MyVector.obj \
  $O\MyXml.obj \
  $O\NewHandler.obj \
  $O\Sha1Reg.obj \
  $O\Sha256Reg.obj \
  $O\Sha3Reg.obj \
  $O\Sha512Reg.obj \
  $O\Sha512Prepare.obj \
  $O\StringConvert.obj \
  $O\StringToInt.obj \
  $O\UTFConvert.obj \
  $O\Wildcard.obj \
  $O\Xxh64Reg.obj \
  $O\XzCrc64Init.obj \
  $O\XzCrc64Reg.obj \

WIN_OBJS = \
  $O\FileDir.obj \
  $O\FileFind.obj \
  $O\FileIO.obj \
  $O\FileName.obj \
  $O\PropVariant.obj \
  $O\PropVariantConv.obj \
  $O\PropVariantUtils.obj \
  $O\Synchronization.obj \
  $O\System.obj \
  $O\TimeUtils.obj \

7ZIP_COMMON_OBJS = \
  $O\CreateCoder.obj \
  $O\CWrappers.obj \
  $O\InBuffer.obj \
  $O\InOutTempBuffer.obj \
  $O\FilterCoder.obj \
  $O\LimitedStreams.obj \
  $O\LockedStream.obj \
  $O\MemBlocks.obj \
  $O\MethodId.obj \
  $O\MethodProps.obj \
  $O\OffsetStream.obj \
  $O\OutBuffer.obj \
  $O\OutMemStream.obj \
  $O\ProgressMt.obj \
  $O\ProgressUtils.obj \
  $O\PropId.obj \
  $O\StreamBinder.obj \
  $O\StreamObjects.obj \
  $O\StreamUtils.obj \
  $O\UniqBlocks.obj \
  $O\VirtThread.obj \

AR_OBJS = \
  $O\ApfsHandler.obj \
  $O\ApmHandler.obj \
  $O\ArHandler.obj \
  $O\ArjHandler.obj \
  $O\Base64Handler.obj \
  $O\Bz2Handler.obj \
  $O\ComHandler.obj \
  $O\CpioHandler.obj \
  $O\CramfsHandler.obj \
  $O\DeflateProps.obj \
  $O\DmgHandler.obj \
  $O\ElfHandler.obj \
  $O\ExtHandler.obj \
  $O\FatHandler.obj \
  $O\FlvHandler.obj \
  $O\GzHandler.obj \
  $O\GptHandler.obj \
  $O\HandlerCont.obj \
  $O\HfsHandler.obj \
  $O\IhexHandler.obj \
  $O\LpHandler.obj \
  $O\LzhHandler.obj \
  $O\LzmaHandler.obj \
  $O\MachoHandler.obj \
  $O\MbrHandler.obj \
  $O\MslzHandler.obj \
  $O\MubHandler.obj \
  $O\NtfsHandler.obj \
  $O\PeHandler.obj \
  $O\PpmdHandler.obj \
  $O\QcowHandler.obj \
  $O\RpmHandler.obj \
  $O\SparseHandler.obj \
  $O\SplitHandler.obj \
  $O\SquashfsHandler.obj \
  $O\SwfHandler.obj \
  $O\UefiHandler.obj \
  $O\VdiHandler.obj \
  $O\VhdHandler.obj \
  $O\VhdxHandler.obj \
  $O\VmdkHandler.obj \
  $O\XarHandler.obj \
  $O\XzHandler.obj \
  $O\ZHandler.obj \
  $O\ZstdHandler.obj \
  $O\Lz4Handler.obj \
  $O\Lz5Handler.obj \
  $O\LizardHandler.obj \
  $O\BrotliHandler.obj \

AR_COMMON_OBJS = \
  $O\CoderMixer2.obj \
  $O\DummyOutStream.obj \
  $O\FindSignature.obj \
  $O\InStreamWithCRC.obj \
  $O\ItemNameUtils.obj \
  $O\MultiStream.obj \
  $O\OutStreamWithCRC.obj \
  $O\OutStreamWithSha1.obj \
  $O\HandlerOut.obj \
  $O\ParseProperties.obj \
  $O\RewindableDecodedStream.obj \
  $O\TempFileDecodedStream.obj \

7Z_OBJS = \
  $O\7zCompressionMode.obj \
  $O\7zDecode.obj \
  $O\7zEncode.obj \
  $O\7zExtract.obj \
  $O\7zFolderInStream.obj \
  $O\7zHandler.obj \
  $O\7zHandlerOut.obj \
  $O\7zHeader.obj \
  $O\7zIn.obj \
  $O\7zOut.obj \
  $O\7zProperties.obj \
  $O\7zSpecStream.obj \
  $O\7zUpdate.obj \
  $O\7zRegister.obj \

CAB_OBJS = \
  $O\CabBlockInStream.obj \
  $O\CabHandler.obj \
  $O\CabHeader.obj \
  $O\CabIn.obj \
  $O\CabRegister.obj \

CHM_OBJS = \
  $O\ChmHandler.obj \
  $O\ChmIn.obj \

ISO_OBJS = \
  $O\IsoHandler.obj \
  $O\IsoHeader.obj \
  $O\IsoIn.obj \
  $O\IsoRegister.obj \

NSIS_OBJS = \
  $O\NsisDecode.obj \
  $O\NsisHandler.obj \
  $O\NsisIn.obj \
  $O\NsisRegister.obj \

RAR_OBJS = \
  $O\RarHandler.obj \
  $O\Rar5Handler.obj \

TAR_OBJS = \
  $O\TarHandler.obj \
  $O\TarHandlerOut.obj \
  $O\TarHeader.obj \
  $O\TarIn.obj \
  $O\TarOut.obj \
  $O\TarUpdate.obj \
  $O\TarRegister.obj \

# 7-ZSTar: M4 -- TarChain (tar.zst one-step composite out-handler; pipes
# Tar's output through the zstd encoder via CStreamBinder). Depends on both
# TAR_OBJS (above) and COMPRESS_OBJS' ZstdEncoder*.obj (below).
TARCHAIN_OBJS = \
  $O\TarChainHandler.obj \
  $O\TarChainRegister.obj \

UDF_OBJS = \
  $O\UdfHandler.obj \
  $O\UdfIn.obj \

WIM_OBJS = \
  $O\WimHandler.obj \
  $O\WimHandlerOut.obj \
  $O\WimIn.obj \
  $O\WimRegister.obj \

ZIP_OBJS = \
  $O\ZipAddCommon.obj \
  $O\ZipHandler.obj \
  $O\ZipHandlerOut.obj \
  $O\ZipIn.obj \
  $O\ZipItem.obj \
  $O\ZipOut.obj \
  $O\ZipUpdate.obj \
  $O\ZipRegister.obj \

COMPRESS_OBJS = \
  $O\Bcj2Coder.obj \
  $O\Bcj2Register.obj \
  $O\BcjCoder.obj \
  $O\BcjRegister.obj \
  $O\BitlDecoder.obj \
  $O\BranchMisc.obj \
  $O\BranchRegister.obj \
  $O\ByteSwap.obj \
  $O\BZip2Crc.obj \
  $O\BZip2Decoder.obj \
  $O\BZip2Encoder.obj \
  $O\BZip2Register.obj \
  $O\CopyCoder.obj \
  $O\CopyRegister.obj \
  $O\Deflate64Register.obj \
  $O\DeflateDecoder.obj \
  $O\DeflateEncoder.obj \
  $O\DeflateRegister.obj \
  $O\DeltaFilter.obj \
  $O\ImplodeDecoder.obj \
  $O\LzfseDecoder.obj \
  $O\LzhDecoder.obj \
  $O\Lzma2Decoder.obj \
  $O\Lzma2Encoder.obj \
  $O\Lzma2Register.obj \
  $O\LzmaDecoder.obj \
  $O\LzmaEncoder.obj \
  $O\LzmaRegister.obj \
  $O\LzmsDecoder.obj \
  $O\LzOutWindow.obj \
  $O\LzxDecoder.obj \
  $O\PpmdDecoder.obj \
  $O\PpmdEncoder.obj \
  $O\PpmdRegister.obj \
  $O\PpmdZip.obj \
  $O\QuantumDecoder.obj \
  $O\Rar1Decoder.obj \
  $O\Rar2Decoder.obj \
  $O\Rar3Decoder.obj \
  $O\Rar3Vm.obj \
  $O\Rar5Decoder.obj \
  $O\RarCodecsRegister.obj \
  $O\ShrinkDecoder.obj \
  $O\XpressDecoder.obj \
  $O\XzDecoder.obj \
  $O\XzEncoder.obj \
  $O\ZlibDecoder.obj \
  $O\ZlibEncoder.obj \
  $O\ZDecoder.obj \
  $O\ZstdDecoder.obj \
  $O\ZstdEncoder.obj \
  $O\ZstdEncoderProps.obj \
  $O\ZstdRegister.obj \
  $O\Lz4Decoder.obj \
  $O\Lz4Encoder.obj \
  $O\Lz4Register.obj \
  $O\Lz5Decoder.obj \
  $O\Lz5Encoder.obj \
  $O\Lz5Register.obj \
  $O\LizardDecoder.obj \
  $O\LizardEncoder.obj \
  $O\LizardRegister.obj \
  $O\BrotliDecoder.obj \
  $O\BrotliEncoder.obj \
  $O\BrotliRegister.obj \
  $O\FastLzma2Encoder.obj \
  $O\FastLzma2Register.obj \

CRYPTO_OBJS = \
  $O\7zAes.obj \
  $O\7zAesRegister.obj \
  $O\HmacSha1.obj \
  $O\HmacSha256.obj \
  $O\MyAes.obj \
  $O\MyAesReg.obj \
  $O\Pbkdf2HmacSha1.obj \
  $O\RandGen.obj \
  $O\Rar20Crypto.obj \
  $O\Rar5Aes.obj \
  $O\RarAes.obj \
  $O\WzAes.obj \
  $O\ZipCrypto.obj \
  $O\ZipStrong.obj \

C_OBJS = \
  $O\7zBuf2.obj \
  $O\7zStream.obj \
  $O\Alloc.obj \
  $O\Bcj2.obj \
  $O\Bcj2Enc.obj \
  $O\Blake2s.obj \
  $O\Bra.obj \
  $O\Bra86.obj \
  $O\BraIA64.obj \
  $O\BwtSort.obj \
  $O\CpuArch.obj \
  $O\Delta.obj \
  $O\HuffEnc.obj \
  $O\LzFind.obj \
  $O\LzFindMt.obj \
  $O\Lzma2Dec.obj \
  $O\Lzma2DecMt.obj \
  $O\Lzma2Enc.obj \
  $O\LzmaDec.obj \
  $O\LzmaEnc.obj \
  $O\Md5.obj \
  $O\MtCoder.obj \
  $O\MtDec.obj \
  $O\Ppmd7.obj \
  $O\Ppmd7Dec.obj \
  $O\Ppmd7aDec.obj \
  $O\Ppmd7Enc.obj \
  $O\Ppmd8.obj \
  $O\Ppmd8Dec.obj \
  $O\Ppmd8Enc.obj \
  $O\Sha3.obj \
  $O\Sha512.obj \
  $O\Sha512Opt.obj \
  $O\SwapBytes.obj \
  $O\Threads.obj \
  $O\Xxh64.obj \
  $O\Xz.obj \
  $O\XzDec.obj \
  $O\XzEnc.obj \
  $O\XzIn.obj \
  $O\ZstdDec.obj \

# 7-ZSTar: vendored libzstd 1.5.7 (C/zstd/, UPSTREAM.txt) -- compression side only.
# Decoding still goes entirely through ZstdDec.obj above (the official
# from-scratch decoder); these objects are pulled in transitively by
# ZstdEncoder.obj/ZstdEncoderProps.obj. Excludes decompress-only and legacy
# (pre-1.0 format) sources: zstd_decompress*.c, zstd_ddict.c, huf_decompress*.c,
# zstd_v01..v07.c are never referenced from the compression call graph.
ZSTD_ENC_OBJS = \
  $O\debug.obj \
  $O\entropy_common.obj \
  $O\error_private.obj \
  $O\fse_compress.obj \
  $O\fse_decompress.obj \
  $O\hist.obj \
  $O\huf_compress.obj \
  $O\pool.obj \
  $O\threading.obj \
  $O\zstd_common.obj \
  $O\zstd_compress.obj \
  $O\zstd_compress_literals.obj \
  $O\zstd_compress_sequences.obj \
  $O\zstd_compress_superblock.obj \
  $O\zstd_double_fast.obj \
  $O\zstd_fast.obj \
  $O\zstd_lazy.obj \
  $O\zstd_ldm.obj \
  $O\zstd_opt.obj \
  $O\zstd_preSplit.obj \
  $O\zstdmt_compress.obj \
  $O\xxhash.obj \

C_OBJS = $(C_OBJS) $(ZSTD_ENC_OBJS)

# 7-ZSTar: M6a -- vendored lz4 1.10.0 (C/lz4/, UPSTREAM.txt) + mcmilk's MT
# wrapper (C/zstdmt/lz4-mt_*.c, UPSTREAM.txt). zstd-mt_threading.obj is
# zstdmt's shared Windows pthread_create/_pthread_join shim (threading.h) --
# not zstd-specific despite the filename (zstd's own MT is self-contained in
# ZSTD_ENC_OBJS above and doesn't use C/zstdmt/ at all); every *-mt_*.c
# consumer needs it linked in exactly once, added here since lz4 is the
# first of the four zstdmt-based codecs this project vendors.
LZ4_ENC_OBJS = \
  $O\lz4.obj \
  $O\lz4frame.obj \
  $O\lz4hc.obj \
  $O\lz4-mt_common.obj \
  $O\lz4-mt_compress.obj \
  $O\lz4-mt_decompress.obj \
  $O\zstd-mt_threading.obj \

C_OBJS = $(C_OBJS) $(LZ4_ENC_OBJS)

# 7-ZSTar: M6a -- vendored lz5 1.5.0 (C/lz5/, UPSTREAM.txt) + mcmilk's MT
# wrapper (C/zstdmt/lz5-mt_*.c). zstd-mt_threading.obj already linked via
# LZ4_ENC_OBJS above, not repeated here.
LZ5_ENC_OBJS = \
  $O\lz5.obj \
  $O\lz5frame.obj \
  $O\lz5hc.obj \
  $O\lz5-mt_common.obj \
  $O\lz5-mt_compress.obj \
  $O\lz5-mt_decompress.obj \

C_OBJS = $(C_OBJS) $(LZ5_ENC_OBJS)

# 7-ZSTar: M6a -- vendored lizard 2.1.0 (C/lizard/, UPSTREAM.txt: 8 objects,
# core codec + its own vendored FSE/HUF entropy backend) + mcmilk's MT
# wrapper (C/zstdmt/lizard-mt_*.c). zstd-mt_threading.obj already linked via
# LZ4_ENC_OBJS above, not repeated here.
LIZARD_ENC_OBJS = \
  $O\lizard_compress.obj \
  $O\lizard_decompress.obj \
  $O\lizard_frame.obj \
  $O\liz_entropy_common.obj \
  $O\liz_fse_compress.obj \
  $O\liz_fse_decompress.obj \
  $O\liz_huf_compress.obj \
  $O\liz_huf_decompress.obj \
  $O\lizard-mt_common.obj \
  $O\lizard-mt_compress.obj \
  $O\lizard-mt_decompress.obj \

C_OBJS = $(C_OBJS) $(LIZARD_ENC_OBJS)

# 7-ZSTar: M6a -- vendored brotli 1.2.1 (C/brotli/, UPSTREAM.txt: 35
# br_*.obj -- flat, prefixed copy of upstream's common/dec/enc trees) +
# mcmilk's MT wrapper (C/zstdmt/brotli-mt_*.c). zstd-mt_threading.obj
# already linked via LZ4_ENC_OBJS above, not repeated here.
BROTLI_ENC_OBJS = \
  $O\br_backward_references.obj \
  $O\br_backward_references_hq.obj \
  $O\br_bit_cost.obj \
  $O\br_bit_reader.obj \
  $O\br_block_splitter.obj \
  $O\br_brotli_bit_stream.obj \
  $O\br_cluster.obj \
  $O\br_command.obj \
  $O\br_compound_dictionary.obj \
  $O\br_compress_fragment.obj \
  $O\br_compress_fragment_two_pass.obj \
  $O\br_constants.obj \
  $O\br_context.obj \
  $O\br_decode.obj \
  $O\br_dictionary.obj \
  $O\br_dictionary_hash.obj \
  $O\br_encode.obj \
  $O\br_encoder_dict.obj \
  $O\br_entropy_encode.obj \
  $O\br_fast_log.obj \
  $O\br_histogram.obj \
  $O\br_huffman.obj \
  $O\br_literal_cost.obj \
  $O\br_memory.obj \
  $O\br_metablock.obj \
  $O\br_platform.obj \
  $O\br_prefix.obj \
  $O\br_shared_dictionary.obj \
  $O\br_state.obj \
  $O\br_static_dict.obj \
  $O\br_static_dict_lut.obj \
  $O\br_static_init_dec.obj \
  $O\br_static_init_enc.obj \
  $O\br_transform.obj \
  $O\br_utf8_util.obj \
  $O\brotli-mt_common.obj \
  $O\brotli-mt_compress.obj \
  $O\brotli-mt_decompress.obj \

C_OBJS = $(C_OBJS) $(BROTLI_ENC_OBJS)

# 7-ZSTar: M6a -- vendored fast-lzma2 1.0.1 (C/fast-lzma2/, UPSTREAM.txt).
# No zstdmt/*-mt wrapper (fast-lzma2 has its own built-in multithreading,
# FL2_createCStreamMt) and no Handler.obj (no standalone archive format --
# alternative .7z-internal LZMA2 encoder only, see FastLzma2Register.cpp).
# -DNO_XXHASH -DFL2_7ZIP_BUILD applied via 7zip.mak's C/fast-lzma2
# inference rule (matches mcmilk's own flags exactly).
FASTLZMA2_ENC_OBJS = \
  $O\dict_buffer.obj \
  $O\fl2_common.obj \
  $O\fl2_compress.obj \
  $O\fl2_pool.obj \
  $O\fl2_threading.obj \
  $O\lzma2_enc.obj \
  $O\radix_bitpack.obj \
  $O\radix_mf.obj \
  $O\radix_struct.obj \
  $O\range_enc.obj \
  $O\util.obj \

C_OBJS = $(C_OBJS) $(FASTLZMA2_ENC_OBJS)

!include "../../Aes.mak"
!include "../../Crc.mak"
!include "../../Crc64.mak"
!include "../../LzFindOpt.mak"
!include "../../LzmaDec.mak"
!include "../../Sha1.mak"
!include "../../Sha256.mak"
!include "../../Sort.mak"
