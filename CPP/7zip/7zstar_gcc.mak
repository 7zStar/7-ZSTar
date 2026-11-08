# 7zstar_gcc.mak -- 7-ZSTar: new file (Linux gcc port).
#
# Adds the fork's own objects (new codecs, handlers, TarChain, vendored C
# libraries) to the upstream gcc build WITHOUT touching any upstream makefile.
# It must be included AFTER the bundle's makefile.gcc (see
# Bundles/Alone2/makefile.7zstar.gcc), because it
#   - uses $O, $(CC), $(CXX), $(CFLAGS), $(CXXFLAGS), $(PROGPATH), $(OBJS)
#     that 7zip_gcc.mak defines, and
#   - appends to OBJS after 7zip_gcc.mak already expanded its "$(PROGPATH): $(OBJS)"
#     and "$(PROGPATH_STATIC): $(OBJS)" rules (hence the two extra prerequisite lines below)
#     rule (so the new objects are added as extra prerequisites at the end of
#     this file; the link command itself reads $(OBJS) lazily and sees them).
#
# Paths are relative to CPP/7zip/Bundles/Alone2 (the directory make runs in),
# exactly like the upstream rules in 7zip_gcc.mak.

# ---- per-group compiler flags -------------------------------------------
# ZS_DEFS_ZSTD (-DZSTD_MULTITHREAD) is applied to the fork-own C++ objects that
# the rules below compile, and to the C/zstd objects. It is NOT applied to
# objects built by upstream's rules - ZstdDecoder.o, and the fork-own
# ZstdRegister.o, for which 7zip_gcc.mak already carries a rule - nor to the
# other vendored C directories. ZstdEncoder.h/ZstdDecoder.h must therefore not
# let the macro change class layout, or the two sides would disagree (ODR).
# Without it ZstdEncoder.cpp
# silently falls back to one thread. Windows parity: Arc.mak defines it for
# every TU of the bundle; 7zip.mak adds the fast-lzma2 and zstdmt flags only on
# those directories' inference rules.
ZS_DEFS_ZSTD = -DZSTD_MULTITHREAD
ZS_DEFS_FL2 = -DNO_XXHASH -DFL2_7ZIP_BUILD
ZS_INC_ZSTDMT = \
  -I ../../../../C/brotli \
  -I ../../../../C/hashes \
  -I ../../../../C/lizard \
  -I ../../../../C/lz4 \
  -I ../../../../C/lz5 \
  -I ../../../../C/zstd

# Vendored third-party C: relax only the warnings that warn_gcc.mak adds on top
# of -Wall -Wextra (all verified, see build/linux/DESIGN.md). Fork-own C++ is
# NOT relaxed.
ZS_WARN_VENDOR = -Wno-conversion -Wno-sign-conversion -Wno-implicit-fallthrough -Wno-cast-align -Wno-unused-macros
# C/zstdmt/memmt.h has "Compress/*Encoder.cpp" inside a block comment.
ZS_WARN_ZSTDMT = -Wno-comment

# ---- object lists: one per source directory --------------------------------
# Fork-own C++ (compiled with the static pattern rules below).
# CPP/7zip/Compress
ZS_CPP_COMPRESS_OBJS = \
  $O/ZstdEncoder.o \
  $O/ZstdEncoderProps.o \
  $O/BrotliDecoder.o \
  $O/BrotliEncoder.o \
  $O/BrotliRegister.o \
  $O/FastLzma2Encoder.o \
  $O/FastLzma2Register.o \
  $O/LizardDecoder.o \
  $O/LizardEncoder.o \
  $O/LizardRegister.o \
  $O/Lz4Decoder.o \
  $O/Lz4Encoder.o \
  $O/Lz4Register.o \
  $O/Lz5Decoder.o \
  $O/Lz5Encoder.o \
  $O/Lz5Register.o \

# CPP/7zip/Archive
ZS_CPP_ARCHIVE_OBJS = \
  $O/BrotliHandler.o \
  $O/LizardHandler.o \
  $O/Lz4Handler.o \
  $O/Lz5Handler.o \

# CPP/7zip/Archive/Common
ZS_CPP_ARCCOMMON_OBJS = \
  $O/RewindableDecodedStream.o \
  $O/TempFileDecodedStream.o \

# CPP/7zip/Archive/TarChain
ZS_CPP_TARCHAIN_OBJS = \
  $O/TarChainHandler.o \
  $O/TarChainRegister.o \

# Fork-own C++ that already has an explicit upstream rule in 7zip_gcc.mak
# ("$O/ZstdRegister.o"; the file name is shared with upstream). It is listed so
# it gets linked, but it must NOT get a rule here (overriding recipe).
# ZstdRegister.o registers the zstd coder (ids 0x4F71101 / 0x4015D); without it
# "7zz a -t7z -m0=zstd" answers E_INVALIDARG.
ZS_CPP_UPSTREAM_RULE_OBJS = \
  $O/ZstdRegister.o \

# Vendored third-party C (C/<dir>).
# C/zstd
ZS_C_ZSTD_OBJS = \
  $O/debug.o \
  $O/entropy_common.o \
  $O/error_private.o \
  $O/fse_compress.o \
  $O/fse_decompress.o \
  $O/hist.o \
  $O/huf_compress.o \
  $O/pool.o \
  $O/threading.o \
  $O/zstd_common.o \
  $O/zstd_compress.o \
  $O/zstd_compress_literals.o \
  $O/zstd_compress_sequences.o \
  $O/zstd_compress_superblock.o \
  $O/zstd_double_fast.o \
  $O/zstd_fast.o \
  $O/zstd_lazy.o \
  $O/zstd_ldm.o \
  $O/zstd_opt.o \
  $O/zstd_preSplit.o \
  $O/zstdmt_compress.o \

# C/hashes
ZS_C_HASHES_OBJS = \
  $O/xxhash.o \

# C/lz4
ZS_C_LZ4_OBJS = \
  $O/lz4.o \
  $O/lz4frame.o \
  $O/lz4hc.o \

# C/lz5
ZS_C_LZ5_OBJS = \
  $O/lz5.o \
  $O/lz5frame.o \
  $O/lz5hc.o \

# C/lizard
ZS_C_LIZARD_OBJS = \
  $O/liz_entropy_common.o \
  $O/liz_fse_compress.o \
  $O/liz_fse_decompress.o \
  $O/liz_huf_compress.o \
  $O/liz_huf_decompress.o \
  $O/lizard_compress.o \
  $O/lizard_decompress.o \
  $O/lizard_frame.o \

# C/brotli
ZS_C_BROTLI_OBJS = \
  $O/br_backward_references.o \
  $O/br_backward_references_hq.o \
  $O/br_bit_cost.o \
  $O/br_bit_reader.o \
  $O/br_block_splitter.o \
  $O/br_brotli_bit_stream.o \
  $O/br_cluster.o \
  $O/br_command.o \
  $O/br_compound_dictionary.o \
  $O/br_compress_fragment.o \
  $O/br_compress_fragment_two_pass.o \
  $O/br_constants.o \
  $O/br_context.o \
  $O/br_decode.o \
  $O/br_dictionary.o \
  $O/br_dictionary_hash.o \
  $O/br_encode.o \
  $O/br_encoder_dict.o \
  $O/br_entropy_encode.o \
  $O/br_fast_log.o \
  $O/br_histogram.o \
  $O/br_huffman.o \
  $O/br_literal_cost.o \
  $O/br_memory.o \
  $O/br_metablock.o \
  $O/br_platform.o \
  $O/br_prefix.o \
  $O/br_shared_dictionary.o \
  $O/br_state.o \
  $O/br_static_dict.o \
  $O/br_static_dict_lut.o \
  $O/br_static_init_dec.o \
  $O/br_static_init_enc.o \
  $O/br_transform.o \
  $O/br_utf8_util.o \

# C/zstdmt
ZS_C_ZSTDMT_OBJS = \
  $O/brotli-mt_common.o \
  $O/brotli-mt_compress.o \
  $O/brotli-mt_decompress.o \
  $O/lizard-mt_common.o \
  $O/lizard-mt_compress.o \
  $O/lizard-mt_decompress.o \
  $O/lz4-mt_common.o \
  $O/lz4-mt_compress.o \
  $O/lz4-mt_decompress.o \
  $O/lz5-mt_common.o \
  $O/lz5-mt_compress.o \
  $O/lz5-mt_decompress.o \
  $O/zstd-mt_threading.o \

# C/fast-lzma2
ZS_C_FL2_OBJS = \
  $O/dict_buffer.o \
  $O/fl2_common.o \
  $O/fl2_compress.o \
  $O/fl2_pool.o \
  $O/fl2_threading.o \
  $O/lzma2_enc.o \
  $O/radix_bitpack.o \
  $O/radix_mf.o \
  $O/radix_struct.o \
  $O/range_enc.o \
  $O/util.o \

ZS_CPP_OBJS = $(ZS_CPP_COMPRESS_OBJS) $(ZS_CPP_ARCHIVE_OBJS) $(ZS_CPP_ARCCOMMON_OBJS) $(ZS_CPP_TARCHAIN_OBJS) $(ZS_CPP_UPSTREAM_RULE_OBJS)
ZS_C_OBJS = $(ZS_C_ZSTD_OBJS) $(ZS_C_HASHES_OBJS) $(ZS_C_LZ4_OBJS) $(ZS_C_LZ5_OBJS) $(ZS_C_LIZARD_OBJS) $(ZS_C_BROTLI_OBJS) $(ZS_C_ZSTDMT_OBJS) $(ZS_C_FL2_OBJS)
ZS_OBJS = $(ZS_CPP_OBJS) $(ZS_C_OBJS)

# ---- rules (static pattern rules) ------------------------------------------
$(ZS_CPP_COMPRESS_OBJS): $O/%.o: ../../Compress/%.cpp
	$(CXX) $(CXXFLAGS) $(ZS_DEFS_ZSTD) $<
$(ZS_CPP_ARCHIVE_OBJS): $O/%.o: ../../Archive/%.cpp
	$(CXX) $(CXXFLAGS) $(ZS_DEFS_ZSTD) $<
$(ZS_CPP_ARCCOMMON_OBJS): $O/%.o: ../../Archive/Common/%.cpp
	$(CXX) $(CXXFLAGS) $(ZS_DEFS_ZSTD) $<
$(ZS_CPP_TARCHAIN_OBJS): $O/%.o: ../../Archive/TarChain/%.cpp
	$(CXX) $(CXXFLAGS) $(ZS_DEFS_ZSTD) $<

$(ZS_C_ZSTD_OBJS): $O/%.o: ../../../../C/zstd/%.c
	$(CC) $(CFLAGS) $(ZS_WARN_VENDOR) $(ZS_DEFS_ZSTD) $<
$(ZS_C_HASHES_OBJS): $O/%.o: ../../../../C/hashes/%.c
	$(CC) $(CFLAGS) $(ZS_WARN_VENDOR) $<
$(ZS_C_LZ4_OBJS): $O/%.o: ../../../../C/lz4/%.c
	$(CC) $(CFLAGS) $(ZS_WARN_VENDOR) $<
$(ZS_C_LZ5_OBJS): $O/%.o: ../../../../C/lz5/%.c
	$(CC) $(CFLAGS) $(ZS_WARN_VENDOR) $<
$(ZS_C_LIZARD_OBJS): $O/%.o: ../../../../C/lizard/%.c
	$(CC) $(CFLAGS) $(ZS_WARN_VENDOR) $<
$(ZS_C_BROTLI_OBJS): $O/%.o: ../../../../C/brotli/%.c
	$(CC) $(CFLAGS) $(ZS_WARN_VENDOR) $<
$(ZS_C_ZSTDMT_OBJS): $O/%.o: ../../../../C/zstdmt/%.c
	$(CC) $(CFLAGS) $(ZS_WARN_VENDOR) $(ZS_WARN_ZSTDMT) $(ZS_INC_ZSTDMT) $<
$(ZS_C_FL2_OBJS): $O/%.o: ../../../../C/fast-lzma2/%.c
	$(CC) $(CFLAGS) $(ZS_WARN_VENDOR) $(ZS_DEFS_FL2) $<

# ---- hook into the upstream link --------------------------------------------
# OBJS is a recursive ("=") variable in the bundle makefile, so += keeps it lazy:
# LFLAGS_ALL / DEL_OBJ_EXE (used by the link and by "clean") see the new objects.
# Guard: if upstream ever builds one of these objects itself, fail loudly with a
# clear message. Without it make would keep only the last recipe (an
# "overriding recipe" warning) and then list the object twice at link time.
ZS_UPSTREAM_DUP := $(filter $(ZS_OBJS),$(OBJS))
$(if $(ZS_UPSTREAM_DUP),$(error 7zstar_gcc.mak: upstream now builds $(ZS_UPSTREAM_DUP) -- drop them from the ZS_* lists))
OBJS += $(ZS_OBJS)
$(ZS_OBJS): | $(O)
# The upstream "$(PROGPATH): $(OBJS)" rules were expanded before OBJS grew, so
# add the new objects as prerequisites of both link targets (the static one is
# built with COMPL_STATIC=1).
$(PROGPATH): $(ZS_OBJS)
$(PROGPATH_STATIC): $(ZS_OBJS)
