# Linux gcc 移植設計（G1 探勘與設計）

> 文中的 G1～G6 是這次 Linux 移植各階段的代號（G1 探勘與設計、G2／G3 實作、G4 驗證）。

> 2026-11-04 移植時的設計紀錄；實作以 repo 內的檔案為準，本檔的行號與數字對應當時的原始碼。第二輪 R1.3 把 `7zstar_gcc.mak` 的 `ZS_T1_*`／`ZS_T2_*` 清單合併成每個來源目錄一份（`ZS_CPP_{COMPRESS,ARCHIVE,ARCCOMMON,TARCHAIN,UPSTREAM_RULE}_OBJS`、`ZS_C_{ZSTD,HASHES,LZ4,LZ5,LIZARD,BROTLI,ZSTDMT,FL2}_OBJS`）並加了上游重複物件的護欄；下文表格裡的 `ZS_T1_*`／`ZS_T2_*` 是當時的變數名，物件集合不變。 另兩處已過期：結論摘要第 7 點「`-DZSTD_MULTITHREAD` 對所有新物件生效」——實際只套在 fork 自有 C++（不含由上游規則編譯的 `ZstdRegister.o`）與 `C/zstd`；`ZS_CPP_ZSTDREG_OBJS` 等彙總變數第二輪已改為每目錄一份清單。

- 撰寫：G1 階段，2026-11-04 UTC。
- 環境：Ubuntu 24.04、gcc／g++ 13.3.0、GNU Make 4.3、clang 18.1.3（只用於交叉比對）、4 核（`nproc`）。
- 本檔所有「已實測」都附指令與輸出摘要；沒有跑過的寫在「附錄 B 未做／未驗證」。
- G1 沒有改任何 repo 內的原始碼或 makefile。為了驗證方案，我在暫存目錄複製了一份樹（`CPP/`、`C/`、`Asm/`）做實驗；本檔列出的 makefile 骨架與原始碼補丁都是在那份樹上**實際建置通過**的內容，G2／G3 可原樣套用。

## 結論摘要

1. **零改動官方建置檔可行，已實測。** `7zip_gcc.mak`、`Arc_gcc.mak`、`Alone2/makefile.gcc`、`var_gcc*.mak`、`warn_gcc.mak` 全部不動。做法：fork 的 bundle makefile 先 `include` 上游的 `makefile.gcc`，再 `include` fork 自己的 `7zstar_gcc.mak`，在其中用 `OBJS +=`、靜態 pattern rule 與額外 prerequisite 把新物件接進同一個連結目標。
2. **缺 120 個物件**（Windows 側有、gcc 側沒列）：25 個 C++（codec、handler、register、TarChain、Common 串流）＋95 個 vendored C。
   - **層級 1 = 27 個**（原列 26；G2 勘誤：`ZstdRegister.o` 須在層級 1）（4 個 C++ ＋ 22 個 C）：讓上游 `7zz` 連結成功。實測最小閉包 24 個物件，另加 `debug.o`、`threading.o` 與 Windows 清單對齊（兩者在 Linux 上幾乎是空檔）。
   - **層級 2 = 93 個**（原列 94）：其餘 codec／handler／register／TarChain。
3. **C/zstdmt（mcmilk 的多執行緒容器封裝）不在層級 1。** 層級 1 拉進來的是 `C/zstd/zstdmt_compress.c`（libzstd 自己的 MT，名字相近但是另一個檔）。
4. **必須改的 fork 自有檔只有 1 個：** `CPP/7zip/Archive/Common/TempFileDecodedStream.cpp` 用了 Windows 版 `NIO::CInFile/COutFile` 的 `Read/Write/Seek`，POSIX 版 `FileIO.h` 沒有這些成員，編譯失敗（3 處）。另 `CPP/7zip/Compress/ZstdEncoder.cpp` 的 `#pragma warning` 在 `-Werror` 下失敗，建議用 `#ifdef _MSC_VER` 包起來（也可改用旗標，不動原始碼）。兩者都是 fork 新增的檔，不屬於官方檔。
5. **vendored 函式庫沒有不帶保護的 Windows 相依**：95 個 C 檔在 gcc 與 clang 都編得過，不需要改任何 vendored 檔。需要的只是 per-group 編譯旗標（fast-lzma2 的 `-DNO_XXHASH -DFL2_7ZIP_BUILD`、zstdmt 的 `-I`、zstd 的 `-DZSTD_MULTITHREAD`）與警告放寬。
6. **警告陷阱（重要）：** 上游官方入口 `make -f ../../cmpl_gcc.mak`（`var_gcc.mak`＋`warn_gcc.mak`＋`makefile.gcc`）比 REPORT 用的 `make -f makefile.gcc` 多帶一大串警告旗標（`-Wconversion`、`-Wunused-macros`、`-Wcast-align`、`-Wimplicit-fallthrough=5` 等，搭配 `-Werror`）。用官方旗標時 95 個 vendored C 有 56 個失敗；對 vendored C 加 5 個 `-Wno-…` 後全過。fork 自己的 C++ 不需要放寬。
7. **實證：** 依本檔骨架在乾淨目錄 `make -j4 -f makefile.7zstar.gcc`：exit 0、0 警告、442 個物件（322＋120）、約 44 秒、`7zz` 4,910,392 bytes；冒煙測試（zstd／brotli／lz4／tar.zst 與 Linux 工具互通、6 種 `.7z` 內 codec）全數通過，見附錄 A。

## 物件清單差集

### 計數方法（可重現）

```bash
cd CPP/7zip/Bundles/Alone2
# gcc 側實際連結的物件：用 make -n 取 -o 目標（322 個）
make -f makefile.gcc -n | grep -o -- '-o _o/[^ ]*\.o ' | sed 's/-o _o\///;s/\.o //' | sort -u > gcc_objs.txt
# Windows 側：Arc.mak + Alone2/makefile + UI/Console/Console.mak 內的 $O\xxx.obj（unique 432 個）
cat ../Format7zF/Arc.mak makefile ../../UI/Console/Console.mak | grep -o '\$O\\[^ ]*\.obj' | sed 's/\$O\\//;s/\.obj//' | sort -u > win_objs.txt
comm -23 win_objs.txt gcc_objs.txt     # Windows 有、gcc 沒有：125 個
comm -13 win_objs.txt gcc_objs.txt     # gcc 有、Windows 清單沒有：15 個
```

- Windows 有、gcc 沒有的 125 個中，**5 個是 Windows 專屬**（`DLL`、`DllSecur`、`FileSystem`、`MemoryLock`、`Registry`；上游 gcc 只在 `IS_MINGW` 時才用），**不需要補**。其餘 **120 個**就是本檔的差集（下方逐檔列出）。
- gcc 有、Windows 清單沒有的 15 個（`7zCrc`、`7zCrcOpt`、`Aes`、`AesOpt`、`LzFindOpt`、`MyWindows`、`Sha1`、`Sha1Opt`、`Sha1Prepare`、`Sha256`、`Sha256Opt`、`Sha256Prepare`、`Sort`、`XzCrc64`、`XzCrc64Opt`）只是 Windows 把它們放在 `Aes.mak`、`Crc.mak` 等子 makefile 裡，我的抽取沒掃那些；`MyWindows` 是 POSIX 專用。交叉驗算：432 − 5 − 120 ＝ 307 ＝ 322 − 15，吻合。
- **與原先估計的數字不符：** 原先估計「Arc.mak 373 個、gcc 側 330 個」。實測 `Arc.mak` 單檔 unique `.obj` 為 386 個，`Arc_gcc.mak` 單檔 unique `.o` 為 282 個（整體連結 322 個含 Alone2 與子 makefile）。差集 120 以實測為準。
- 命名唯一性：新舊合計 442 個物件在同一個 `$(O)` 目錄下沒有重名（實際建出 442 個 `.o`）。Windows 側的 `br_*`、`liz_*` 前綴已經避開 zstd／lizard／brotli 的同名檔（`entropy_common` 與 `liz_entropy_common` 等）。

### 層級 1：讓上游 `7zz` 連結成功（26 個）

兩個前提：(a) `TempFileDecodedStream.cpp` 要先做 POSIX 修正（見「官方檔改動清單」），(b) `ZstdEncoder.cpp` 要處理 `#pragma warning`。

| # | 原始檔 | 物件 | 群組變數 |
|---|---|---|---|
| 1 | `CPP/7zip/Archive/Common/RewindableDecodedStream.cpp` | `RewindableDecodedStream.o` | `ZS_T1_CPP_ARCCOMMON_OBJS` |
| 2 | `CPP/7zip/Archive/Common/TempFileDecodedStream.cpp` | `TempFileDecodedStream.o` | `ZS_T1_CPP_ARCCOMMON_OBJS` |
| 3 | `CPP/7zip/Compress/ZstdEncoder.cpp` | `ZstdEncoder.o` | `ZS_T1_CPP_COMPRESS_OBJS` |
| 4 | `CPP/7zip/Compress/ZstdEncoderProps.cpp` | `ZstdEncoderProps.o` | `ZS_T1_CPP_COMPRESS_OBJS` |
| 5 | `C/hashes/xxhash.c` | `xxhash.o` | `ZS_T1_C_HASHES_OBJS` |
| 6 | `C/zstd/debug.c` | `debug.o` | `ZS_T1_C_ZSTD_OBJS` |
| 7 | `C/zstd/entropy_common.c` | `entropy_common.o` | `ZS_T1_C_ZSTD_OBJS` |
| 8 | `C/zstd/error_private.c` | `error_private.o` | `ZS_T1_C_ZSTD_OBJS` |
| 9 | `C/zstd/fse_compress.c` | `fse_compress.o` | `ZS_T1_C_ZSTD_OBJS` |
| 10 | `C/zstd/fse_decompress.c` | `fse_decompress.o` | `ZS_T1_C_ZSTD_OBJS` |
| 11 | `C/zstd/hist.c` | `hist.o` | `ZS_T1_C_ZSTD_OBJS` |
| 12 | `C/zstd/huf_compress.c` | `huf_compress.o` | `ZS_T1_C_ZSTD_OBJS` |
| 13 | `C/zstd/pool.c` | `pool.o` | `ZS_T1_C_ZSTD_OBJS` |
| 14 | `C/zstd/threading.c` | `threading.o` | `ZS_T1_C_ZSTD_OBJS` |
| 15 | `C/zstd/zstd_common.c` | `zstd_common.o` | `ZS_T1_C_ZSTD_OBJS` |
| 16 | `C/zstd/zstd_compress.c` | `zstd_compress.o` | `ZS_T1_C_ZSTD_OBJS` |
| 17 | `C/zstd/zstd_compress_literals.c` | `zstd_compress_literals.o` | `ZS_T1_C_ZSTD_OBJS` |
| 18 | `C/zstd/zstd_compress_sequences.c` | `zstd_compress_sequences.o` | `ZS_T1_C_ZSTD_OBJS` |
| 19 | `C/zstd/zstd_compress_superblock.c` | `zstd_compress_superblock.o` | `ZS_T1_C_ZSTD_OBJS` |
| 20 | `C/zstd/zstd_double_fast.c` | `zstd_double_fast.o` | `ZS_T1_C_ZSTD_OBJS` |
| 21 | `C/zstd/zstd_fast.c` | `zstd_fast.o` | `ZS_T1_C_ZSTD_OBJS` |
| 22 | `C/zstd/zstd_lazy.c` | `zstd_lazy.o` | `ZS_T1_C_ZSTD_OBJS` |
| 23 | `C/zstd/zstd_ldm.c` | `zstd_ldm.o` | `ZS_T1_C_ZSTD_OBJS` |
| 24 | `C/zstd/zstd_opt.c` | `zstd_opt.o` | `ZS_T1_C_ZSTD_OBJS` |
| 25 | `C/zstd/zstd_preSplit.c` | `zstd_preSplit.o` | `ZS_T1_C_ZSTD_OBJS` |
| 26 | `C/zstd/zstdmt_compress.c` | `zstdmt_compress.o` | `ZS_T1_C_ZSTD_OBJS` |

**證明（實測）：**

1. 基線（未加新物件）連結失敗，12 個不同的未定義符號，與 `test/interop/REPORT.md` 第 2 節一致：

```text
CRewindableDecodedStream::Init            CTempFileDecodedStream::Init
NCompress::NZstd::CEncoder::CEncoder      NCompress::NZstd::CEncoderProps::SetFromMethodProps
RewindableDecodedStream_GetPullInterfaces RewindableDecodedStream_SniffTar
TempFileDecodedStream_SniffTar            ZstdEncProps_GetNumThreads_for_MemUsageLimit
ZstdEncProps_Init                         ZstdEncProps_NormalizeFull
vtable for CRewindableDecodedStream       vtable for CTempFileDecodedStream
```

2. 對 120 個新物件各自跑 `nm -g`，以「未定義符號 → 提供者」做傳遞閉包，起點是那 4 個檔，只往「新物件」展開（腳本在 暫存目錄，不入庫；邏輯：`nm -g` 的 `U` 符號找哪個新 `.o` 有對應的已定義符號）。輸出：

```text
TIER1 closure over NEW objects (24):
RewindableDecodedStream TempFileDecodedStream ZstdEncoder ZstdEncoderProps
entropy_common error_private fse_compress fse_decompress hist huf_compress pool xxhash
zstd_common zstd_compress zstd_compress_literals zstd_compress_sequences zstd_compress_superblock
zstd_double_fast zstd_fast zstd_lazy zstd_ldm zstd_opt zstd_preSplit zstdmt_compress
zstdmt objs in closure: []                       # C/zstdmt/*-mt_*.c 一個都沒被拉進來
RewindableDecodedStream -> []                    # 只依賴已在 gcc 清單內的物件
TempFileDecodedStream   -> []
ZstdEncoder      -> ZstdEncoderProps + 上列 19 個 C/zstd 物件 + xxhash
ZstdEncoderProps -> 同上（同一批 C/zstd 物件）
zstd+hash objs not in closure: ['debug', 'threading']
```

3. 只加這 24 個物件（`debug`、`threading` 都不加）實際連結：成功（`7zz_t1` 3,390,000 bytes，`7zz_t1 a -tzstd` 產出的 `.zst` 通過 `zstd -t`）。**負向對照：** 從清單拿掉 `zstdmt_compress.o`，連結出現 11 個 `undefined reference`，證明閉包不是多算的。
4. `debug.o` 只提供 `g_debuglevel`（`DEBUGLEVEL>=2` 才被引用，`-DNDEBUG` 下不會）；`threading.o` 在 Linux 上只剩 `g_ZSTD_threading_useless_symbol`（POSIX 下 `threading.h` 直接用 `<pthread.h>`，`threading.c` 的內容整段在 `_WIN32` 內）。兩者與 Windows 的 `ZSTD_ENC_OBJS` 對齊而保留，編譯成本可忽略。
5. 完整層級 1 骨架（26 個物件，下方 `7zstar_gcc.mak` 的 `ZS_T2_*` 全部清空）在官方旗標下單獨建置：`make -j4 -f <T1 版 bundle> O=b/t1` exit 0（約 33 秒），348 個物件（322＋26），`7zz` 3,390,000 bytes，`7zz i` 有 `zstd` 格式，`a -tzstd` 輸出通過 `zstd -t`。

### 層級 2：其餘 codec、handler、register、TarChain（94 個）

| # | 原始檔 | 物件 | 群組變數 |
|---|---|---|---|
| 1 | `CPP/7zip/Archive/BrotliHandler.cpp` | `BrotliHandler.o` | `ZS_T2_CPP_ARCHIVE_OBJS` |
| 2 | `CPP/7zip/Archive/LizardHandler.cpp` | `LizardHandler.o` | `ZS_T2_CPP_ARCHIVE_OBJS` |
| 3 | `CPP/7zip/Archive/Lz4Handler.cpp` | `Lz4Handler.o` | `ZS_T2_CPP_ARCHIVE_OBJS` |
| 4 | `CPP/7zip/Archive/Lz5Handler.cpp` | `Lz5Handler.o` | `ZS_T2_CPP_ARCHIVE_OBJS` |
| 5 | `CPP/7zip/Compress/BrotliDecoder.cpp` | `BrotliDecoder.o` | `ZS_T2_CPP_COMPRESS_OBJS` |
| 6 | `CPP/7zip/Compress/BrotliEncoder.cpp` | `BrotliEncoder.o` | `ZS_T2_CPP_COMPRESS_OBJS` |
| 7 | `CPP/7zip/Compress/BrotliRegister.cpp` | `BrotliRegister.o` | `ZS_T2_CPP_COMPRESS_OBJS` |
| 8 | `CPP/7zip/Compress/FastLzma2Encoder.cpp` | `FastLzma2Encoder.o` | `ZS_T2_CPP_COMPRESS_OBJS` |
| 9 | `CPP/7zip/Compress/FastLzma2Register.cpp` | `FastLzma2Register.o` | `ZS_T2_CPP_COMPRESS_OBJS` |
| 10 | `CPP/7zip/Compress/LizardDecoder.cpp` | `LizardDecoder.o` | `ZS_T2_CPP_COMPRESS_OBJS` |
| 11 | `CPP/7zip/Compress/LizardEncoder.cpp` | `LizardEncoder.o` | `ZS_T2_CPP_COMPRESS_OBJS` |
| 12 | `CPP/7zip/Compress/LizardRegister.cpp` | `LizardRegister.o` | `ZS_T2_CPP_COMPRESS_OBJS` |
| 13 | `CPP/7zip/Compress/Lz4Decoder.cpp` | `Lz4Decoder.o` | `ZS_T2_CPP_COMPRESS_OBJS` |
| 14 | `CPP/7zip/Compress/Lz4Encoder.cpp` | `Lz4Encoder.o` | `ZS_T2_CPP_COMPRESS_OBJS` |
| 15 | `CPP/7zip/Compress/Lz4Register.cpp` | `Lz4Register.o` | `ZS_T2_CPP_COMPRESS_OBJS` |
| 16 | `CPP/7zip/Compress/Lz5Decoder.cpp` | `Lz5Decoder.o` | `ZS_T2_CPP_COMPRESS_OBJS` |
| 17 | `CPP/7zip/Compress/Lz5Encoder.cpp` | `Lz5Encoder.o` | `ZS_T2_CPP_COMPRESS_OBJS` |
| 18 | `CPP/7zip/Compress/Lz5Register.cpp` | `Lz5Register.o` | `ZS_T2_CPP_COMPRESS_OBJS` |
| 19 | `CPP/7zip/Archive/TarChain/TarChainHandler.cpp` | `TarChainHandler.o` | `ZS_T2_CPP_TARCHAIN_OBJS` |
| 20 | `CPP/7zip/Archive/TarChain/TarChainRegister.cpp` | `TarChainRegister.o` | `ZS_T2_CPP_TARCHAIN_OBJS` |
| 21 | `CPP/7zip/Compress/ZstdRegister.cpp` | `ZstdRegister.o` | `ZS_T2_CPP_ZSTDREG_OBJS（不給規則）` |
| 22 | `C/brotli/br_backward_references.c` | `br_backward_references.o` | `ZS_T2_C_BROTLI_OBJS` |
| 23 | `C/brotli/br_backward_references_hq.c` | `br_backward_references_hq.o` | `ZS_T2_C_BROTLI_OBJS` |
| 24 | `C/brotli/br_bit_cost.c` | `br_bit_cost.o` | `ZS_T2_C_BROTLI_OBJS` |
| 25 | `C/brotli/br_bit_reader.c` | `br_bit_reader.o` | `ZS_T2_C_BROTLI_OBJS` |
| 26 | `C/brotli/br_block_splitter.c` | `br_block_splitter.o` | `ZS_T2_C_BROTLI_OBJS` |
| 27 | `C/brotli/br_brotli_bit_stream.c` | `br_brotli_bit_stream.o` | `ZS_T2_C_BROTLI_OBJS` |
| 28 | `C/brotli/br_cluster.c` | `br_cluster.o` | `ZS_T2_C_BROTLI_OBJS` |
| 29 | `C/brotli/br_command.c` | `br_command.o` | `ZS_T2_C_BROTLI_OBJS` |
| 30 | `C/brotli/br_compound_dictionary.c` | `br_compound_dictionary.o` | `ZS_T2_C_BROTLI_OBJS` |
| 31 | `C/brotli/br_compress_fragment.c` | `br_compress_fragment.o` | `ZS_T2_C_BROTLI_OBJS` |
| 32 | `C/brotli/br_compress_fragment_two_pass.c` | `br_compress_fragment_two_pass.o` | `ZS_T2_C_BROTLI_OBJS` |
| 33 | `C/brotli/br_constants.c` | `br_constants.o` | `ZS_T2_C_BROTLI_OBJS` |
| 34 | `C/brotli/br_context.c` | `br_context.o` | `ZS_T2_C_BROTLI_OBJS` |
| 35 | `C/brotli/br_decode.c` | `br_decode.o` | `ZS_T2_C_BROTLI_OBJS` |
| 36 | `C/brotli/br_dictionary.c` | `br_dictionary.o` | `ZS_T2_C_BROTLI_OBJS` |
| 37 | `C/brotli/br_dictionary_hash.c` | `br_dictionary_hash.o` | `ZS_T2_C_BROTLI_OBJS` |
| 38 | `C/brotli/br_encode.c` | `br_encode.o` | `ZS_T2_C_BROTLI_OBJS` |
| 39 | `C/brotli/br_encoder_dict.c` | `br_encoder_dict.o` | `ZS_T2_C_BROTLI_OBJS` |
| 40 | `C/brotli/br_entropy_encode.c` | `br_entropy_encode.o` | `ZS_T2_C_BROTLI_OBJS` |
| 41 | `C/brotli/br_fast_log.c` | `br_fast_log.o` | `ZS_T2_C_BROTLI_OBJS` |
| 42 | `C/brotli/br_histogram.c` | `br_histogram.o` | `ZS_T2_C_BROTLI_OBJS` |
| 43 | `C/brotli/br_huffman.c` | `br_huffman.o` | `ZS_T2_C_BROTLI_OBJS` |
| 44 | `C/brotli/br_literal_cost.c` | `br_literal_cost.o` | `ZS_T2_C_BROTLI_OBJS` |
| 45 | `C/brotli/br_memory.c` | `br_memory.o` | `ZS_T2_C_BROTLI_OBJS` |
| 46 | `C/brotli/br_metablock.c` | `br_metablock.o` | `ZS_T2_C_BROTLI_OBJS` |
| 47 | `C/brotli/br_platform.c` | `br_platform.o` | `ZS_T2_C_BROTLI_OBJS` |
| 48 | `C/brotli/br_prefix.c` | `br_prefix.o` | `ZS_T2_C_BROTLI_OBJS` |
| 49 | `C/brotli/br_shared_dictionary.c` | `br_shared_dictionary.o` | `ZS_T2_C_BROTLI_OBJS` |
| 50 | `C/brotli/br_state.c` | `br_state.o` | `ZS_T2_C_BROTLI_OBJS` |
| 51 | `C/brotli/br_static_dict.c` | `br_static_dict.o` | `ZS_T2_C_BROTLI_OBJS` |
| 52 | `C/brotli/br_static_dict_lut.c` | `br_static_dict_lut.o` | `ZS_T2_C_BROTLI_OBJS` |
| 53 | `C/brotli/br_static_init_dec.c` | `br_static_init_dec.o` | `ZS_T2_C_BROTLI_OBJS` |
| 54 | `C/brotli/br_static_init_enc.c` | `br_static_init_enc.o` | `ZS_T2_C_BROTLI_OBJS` |
| 55 | `C/brotli/br_transform.c` | `br_transform.o` | `ZS_T2_C_BROTLI_OBJS` |
| 56 | `C/brotli/br_utf8_util.c` | `br_utf8_util.o` | `ZS_T2_C_BROTLI_OBJS` |
| 57 | `C/fast-lzma2/dict_buffer.c` | `dict_buffer.o` | `ZS_T2_C_FL2_OBJS` |
| 58 | `C/fast-lzma2/fl2_common.c` | `fl2_common.o` | `ZS_T2_C_FL2_OBJS` |
| 59 | `C/fast-lzma2/fl2_compress.c` | `fl2_compress.o` | `ZS_T2_C_FL2_OBJS` |
| 60 | `C/fast-lzma2/fl2_pool.c` | `fl2_pool.o` | `ZS_T2_C_FL2_OBJS` |
| 61 | `C/fast-lzma2/fl2_threading.c` | `fl2_threading.o` | `ZS_T2_C_FL2_OBJS` |
| 62 | `C/fast-lzma2/lzma2_enc.c` | `lzma2_enc.o` | `ZS_T2_C_FL2_OBJS` |
| 63 | `C/fast-lzma2/radix_bitpack.c` | `radix_bitpack.o` | `ZS_T2_C_FL2_OBJS` |
| 64 | `C/fast-lzma2/radix_mf.c` | `radix_mf.o` | `ZS_T2_C_FL2_OBJS` |
| 65 | `C/fast-lzma2/radix_struct.c` | `radix_struct.o` | `ZS_T2_C_FL2_OBJS` |
| 66 | `C/fast-lzma2/range_enc.c` | `range_enc.o` | `ZS_T2_C_FL2_OBJS` |
| 67 | `C/fast-lzma2/util.c` | `util.o` | `ZS_T2_C_FL2_OBJS` |
| 68 | `C/lizard/liz_entropy_common.c` | `liz_entropy_common.o` | `ZS_T2_C_LIZARD_OBJS` |
| 69 | `C/lizard/liz_fse_compress.c` | `liz_fse_compress.o` | `ZS_T2_C_LIZARD_OBJS` |
| 70 | `C/lizard/liz_fse_decompress.c` | `liz_fse_decompress.o` | `ZS_T2_C_LIZARD_OBJS` |
| 71 | `C/lizard/liz_huf_compress.c` | `liz_huf_compress.o` | `ZS_T2_C_LIZARD_OBJS` |
| 72 | `C/lizard/liz_huf_decompress.c` | `liz_huf_decompress.o` | `ZS_T2_C_LIZARD_OBJS` |
| 73 | `C/lizard/lizard_compress.c` | `lizard_compress.o` | `ZS_T2_C_LIZARD_OBJS` |
| 74 | `C/lizard/lizard_decompress.c` | `lizard_decompress.o` | `ZS_T2_C_LIZARD_OBJS` |
| 75 | `C/lizard/lizard_frame.c` | `lizard_frame.o` | `ZS_T2_C_LIZARD_OBJS` |
| 76 | `C/lz4/lz4.c` | `lz4.o` | `ZS_T2_C_LZ4_OBJS` |
| 77 | `C/lz4/lz4frame.c` | `lz4frame.o` | `ZS_T2_C_LZ4_OBJS` |
| 78 | `C/lz4/lz4hc.c` | `lz4hc.o` | `ZS_T2_C_LZ4_OBJS` |
| 79 | `C/lz5/lz5.c` | `lz5.o` | `ZS_T2_C_LZ5_OBJS` |
| 80 | `C/lz5/lz5frame.c` | `lz5frame.o` | `ZS_T2_C_LZ5_OBJS` |
| 81 | `C/lz5/lz5hc.c` | `lz5hc.o` | `ZS_T2_C_LZ5_OBJS` |
| 82 | `C/zstdmt/brotli-mt_common.c` | `brotli-mt_common.o` | `ZS_T2_C_ZSTDMT_OBJS` |
| 83 | `C/zstdmt/brotli-mt_compress.c` | `brotli-mt_compress.o` | `ZS_T2_C_ZSTDMT_OBJS` |
| 84 | `C/zstdmt/brotli-mt_decompress.c` | `brotli-mt_decompress.o` | `ZS_T2_C_ZSTDMT_OBJS` |
| 85 | `C/zstdmt/lizard-mt_common.c` | `lizard-mt_common.o` | `ZS_T2_C_ZSTDMT_OBJS` |
| 86 | `C/zstdmt/lizard-mt_compress.c` | `lizard-mt_compress.o` | `ZS_T2_C_ZSTDMT_OBJS` |
| 87 | `C/zstdmt/lizard-mt_decompress.c` | `lizard-mt_decompress.o` | `ZS_T2_C_ZSTDMT_OBJS` |
| 88 | `C/zstdmt/lz4-mt_common.c` | `lz4-mt_common.o` | `ZS_T2_C_ZSTDMT_OBJS` |
| 89 | `C/zstdmt/lz4-mt_compress.c` | `lz4-mt_compress.o` | `ZS_T2_C_ZSTDMT_OBJS` |
| 90 | `C/zstdmt/lz4-mt_decompress.c` | `lz4-mt_decompress.o` | `ZS_T2_C_ZSTDMT_OBJS` |
| 91 | `C/zstdmt/lz5-mt_common.c` | `lz5-mt_common.o` | `ZS_T2_C_ZSTDMT_OBJS` |
| 92 | `C/zstdmt/lz5-mt_compress.c` | `lz5-mt_compress.o` | `ZS_T2_C_ZSTDMT_OBJS` |
| 93 | `C/zstdmt/lz5-mt_decompress.c` | `lz5-mt_decompress.o` | `ZS_T2_C_ZSTDMT_OBJS` |
| 94 | `C/zstdmt/zstd-mt_threading.c` | `zstd-mt_threading.o` | `ZS_T2_C_ZSTDMT_OBJS` |

註：`ZstdRegister.o` 在上游 `7zip_gcc.mak:828` 已經有規則（`$O/ZstdRegister.o: ../../Compress/ZstdRegister.cpp`），但沒有列進 `Arc_gcc.mak` 的 `COMPRESS_OBJS`。fork 只需把 `$O/ZstdRegister.o` 加進 `OBJS`，**不可以再給規則**（再給會出現 `overriding recipe` 警告）。

## makefile 方案與檔案佈局

### 上游機制（G1 步驟 1 的答案）

| 問題 | 答案（檔案:行為 CRLF 工作樹下的行號） |
|---|---|
| 入口 | 官方 Linux 入口是 `cd Bundles/Alone2 && make -f ../../cmpl_gcc.mak`（`cmpl_gcc.mak` 三行：`include ../../var_gcc.mak`、`include ../../warn_gcc.mak`、`include makefile.gcc`）。`cmpl_gcc_x64.mak` 等改 include `var_gcc_x64.mak`，會 `IS_X64=1`＋`USE_ASM=1`，需要 `asmc`／`jwasm` 組譯器，本環境沒有（`Error 127`）。REPORT 用的是直接 `make -f makefile.gcc`（沒有 `var_gcc.mak`／`warn_gcc.mak`）。 |
| 物件清單怎麼組 | `Alone2/makefile.gcc` 先 `include ../Format7zF/Arc_gcc.mak`（它再 `include ../../LzmaDec_gcc.mak`，並定義 `C_OBJS`、`COMMON_OBJS`、`AR_OBJS`、`COMPRESS_OBJS`…，最後組成 `ARC_OBJS`），接著定義 `UI_COMMON_OBJS`、`CONSOLE_OBJS`、…，最後 `OBJS = $(ARC_OBJS) $(SYS_OBJS) … $(CONSOLE_OBJS)`（**遞迴展開 `=`**），**最後一行才** `include ../../7zip_gcc.mak`。 |
| 規則怎麼定義 | `7zip_gcc.mak` 約 1,300 行**逐檔明確規則**，沒有 pattern rule：`$O/Alloc.o: ../../../../C/Alloc.c` ＋ `$(CC) $(CFLAGS) $<`，C++ 則 `$(CXX) $(CXXFLAGS) $<`。`-o $@` 已寫在 `CFLAGS`／`CXXFLAGS` 裡（`7zip_gcc.mak:171`、`:212`）。清單裡有物件但**沒有**對應規則 → make 會用內建規則亂猜；清單裡沒有但有規則（例如 `ZstdRegister.o`）→ 規則存在但不被使用。 |
| 旗標怎麼生效 | `CFLAGS`／`CXXFLAGS`（`=`，遞迴）內含 `$(LOCAL_FLAGS)`（`Alone2/makefile.gcc` 定義：`$(LOCAL_FLAGS_SYS) $(LOCAL_FLAGS_ST)`）與 `$(CFLAGS_BASE)`（`:53`，內含 `$(CFLAGS_WARN_WALL)`＝`-Werror -Wall -Wextra`（`:27`）與 `$(CFLAGS_WARN)`）。`CFLAGS_WARN` 只有 `warn_gcc.mak` 會設，所以直接 `make -f makefile.gcc` 時是空的。全部都是**執行配方時才展開**，所以 include 之後再改仍然有效。 |
| 目標的 prerequisites 何時展開 | `all: $(O) $(PROGPATH) …`（`:220`）、`$(OBJS): | $(O)`（`:223`）、`$(PROGPATH): $(OBJS)`（`:266`）這幾行的 prerequisites 在**讀到那一行時立即展開**，所以 `7zip_gcc.mak` 被 include 之後才追加的物件不會自動成為 prerequisite；但連結配方 `$(CXX) -o $(PROGPATH) $(LFLAGS_ALL)` 的 `LFLAGS_ALL`（`:260`，`=`）在配方執行時才展開，**會看到**之後追加的 `OBJS`。`clean`（`:1375`）的 `DEL_OBJ_EXE` 同理是遞迴變數。 |
| 預設目標 | `.DEFAULT_GOAL = all`（實測 `make -p`），`include` 順序不影響。 |
| 輸出目錄 | `O`：`makefile.gcc` 直接用時是 `_o`（`7zip_gcc.mak` 的 `ifndef O`）；經 `var_gcc.mak` 是 `b/g`。命令列 `O=…` 皆可覆寫。 |
| 連結函式庫 | `LIB2 = -lpthread -ldl`（`:164`）：fork 的 pthread 路徑（zstd MT、fast-lzma2、zstdmt）不需要額外連結旗標。 |
| 換行 | 工作樹內 `7zip_gcc.mak`、`Arc_gcc.mak` 是 CRLF（`.gitattributes`: `* text=auto eol=crlf`），只有 `makefile.gcc` 與 `*.S` 被指定 LF。實測 GNU Make 4.3 對 CRLF 的 `.mak` 與本檔骨架（轉成 CRLF）都能正常運作。 |

### 方案比較

| 方案 | 內容 | 結論 |
|---|---|---|
| A | 直接改 `Arc_gcc.mak`（加清單）＋ `7zip_gcc.mak`（加規則） | 違反預設「零改動官方建置檔」，且之後合併上游更新會衝突。**不採用。** |
| B | fork 自己的 bundle makefile `include` 上游 `makefile.gcc`，再 `include` fork 的 `.mak` 補清單與規則 | **已實測可行，採用。** |
| C | 複製整份 `7zip_gcc.mak`（1,376 行）到 fork 檔再改 | 重複大量上游內容、上游更新時不會跟著更新。不採用。 |

### 選定方案 B：檔案佈局

兩個新檔，都不屬於官方檔：

```text
CPP/7zip/Bundles/Alone2/makefile.7zstar.gcc    # fork 的 bundle 入口（4 行有效內容）
CPP/7zip/7zstar_gcc.mak                          # fork 的物件清單、規則、旗標、接上連結
```

建置指令（在 `CPP/7zip/Bundles/Alone2` 目錄執行；相對路徑與上游一樣依賴這個 cwd）：

```bash
cd CPP/7zip/Bundles/Alone2
make -j"$(nproc)" -f makefile.7zstar.gcc        # 輸出 b/g/7zz（O 可用 O=… 覆寫）
make -f makefile.7zstar.gcc clean               # 會清掉 442 個物件（實測 make -n clean 計 442 個 .o）
```

#### `makefile.7zstar.gcc`（原樣使用，已實測）

> 完整內容見實際檔案 `CPP/7zip/Bundles/Alone2/makefile.7zstar.gcc`（內嵌副本已移除，理由同下）。

`include` 順序與理由：`var_gcc.mak`／`warn_gcc.mak` 必須在 `makefile.gcc` 之前（和 `cmpl_gcc.mak` 一樣），`7zstar_gcc.mak` 必須在 `makefile.gcc` **之後**，因為它要用 `$O`、`$(CC)`、`$(CXXFLAGS)`、`$(PROGPATH)`，而且 `$(ZS_OBJS): | $(O)` 與 `$(PROGPATH): $(ZS_OBJS)` 必須在上游的 `all`／`$(PROGPATH)` 規則之後追加。此檔刻意採用官方的 `cmpl_gcc.mak` 組合（含 `warn_gcc.mak`），讓 fork 的程式碼達到和上游一樣的警告基準。

#### `7zstar_gcc.mak`（完整內容，已實測）

G2 填寫 `ZS_T1_*`（層級 1）區段與規則；G3 補上 `ZS_T2_*`（層級 2）區段。為了讓兩階段都不改規則，骨架已把兩層都寫好；G2 時把 `ZS_T2_*` 區塊清空（寫成 `ZS_T2_X_OBJS =`）即可（實測：清空 T2 後建置成功，見上方「層級 1 證明」第 5 點；GNU Make 4.3 接受空目標清單的靜態 pattern rule）。

> 完整內容見實際檔案 `CPP/7zip/7zstar_gcc.mak`。本檔原本內嵌的副本是 G1 原型，與 G2／G3 的實作（`ZstdRegister.o` 歸層級 1、`ZS_CPP_ZSTDREG_OBJS` 彙總、註解）已不同，故移除；差異見下方「G2 勘誤」「G3 勘誤與結果」。

#### 已實測的機制要點（G2／G3 注意）

1. `OBJS += …` 要放在 `include makefile.gcc` 之後；`OBJS` 是遞迴變數，`+=` 保持遞迴，`LFLAGS_ALL`、`DEL_OBJ_EXE`、`clean` 都看得到新物件。
2. 上游 `$(PROGPATH): $(OBJS)` 在讀到時就展開過，所以必須另外寫 `$(PROGPATH): $(ZS_OBJS)`，否則新物件被編了但不會觸發重新連結（只改新檔時 `make` 會說 nothing to be done）。
3. `$(ZS_OBJS): | $(O)` 補上輸出目錄的 order-only 依賴，否則 `-j` 下第一個新物件可能比 `mkdir` 早。
4. 靜態 pattern rule `$(LIST): $O/%.o: dir/%.c` 的 `$O` 必須已定義，所以規則只能放在 `include makefile.gcc` 之後。
5. `ZstdRegister.o` 不可再給規則（上游已有；重複會 `overriding recipe`）。其餘 119 個物件上游都沒有規則。
6. 二次執行不重編：建完後再跑 `make -n` → `Nothing to be done for 'all'`；`touch C/zstd/zstd_fast.c` 後 `make -n` 只剩 1 個編譯＋1 個連結（實測）。
7. `-DZSTD_MULTITHREAD` 與 Windows 一樣對**所有新物件**（C 與 C++）生效。`ZstdEncoder.cpp:257` 在沒有這個巨集時會**靜默**退成單執行緒（`nb = 0`），不會報錯，所以不能漏。
8. fast-lzma2 的 `-DNO_XXHASH -DFL2_7ZIP_BUILD` 只給 `C/fast-lzma2/*.c`（Windows 的 `7zip.mak` 也是只給該目錄的推論規則）；`FastLzma2Encoder.cpp` 不給。實測不加這兩個旗標 `fl2_compress.c` 也能編過，保留是為了和 Windows 的二進位行為一致。
9. zstdmt 的 `-I` 六個目錄是必要的（`#include "lz4frame.h"` 等裸檔名）：實測不加會 `fatal error: lz4frame.h: No such file or directory`。
10. 若日後要支援 `ST_MODE=1`（`-DZ7_ST`）：本設計沒有驗證，見風險。

### G2 勘誤（實測）

- **`ZstdRegister.o` 屬於層級 1，不是層級 2。** 只有 26 個物件時 `7zz a -t7z -m0=zstd` 回 `E_INVALIDARG`（coder 註冊表沒有 ZSTD 編碼器）。G2 已把它放進 `ZS_T1_CPP_ZSTDREG_OBJS`（仍不給規則）；層級 1 因此是 27 個物件、總計 349 個 `.o`，層級 2 是 93 個（上表第 21 列除外），G3 保持 `ZS_T2_CPP_ZSTDREG_OBJS` 為空。
- `7zstar_gcc.mak` 的 `ZS_T2_*` 清單在 G2 為空；G3 把上表各列貼進對應變數即可。

### G3 勘誤與結果（實測）

- 層級 2 實際填入 **93 個**物件（表 94 列減 `ZstdRegister.o`，它在層級 1）：`ZS_T2_CPP_COMPRESS_OBJS` 14、`ZS_T2_CPP_ARCHIVE_OBJS` 4、`ZS_T2_CPP_TARCHAIN_OBJS` 2、`ZS_T2_C_BROTLI_OBJS` 35、`ZS_T2_C_FL2_OBJS` 11、`ZS_T2_C_LIZARD_OBJS` 8、`ZS_T2_C_LZ4_OBJS` 3、`ZS_T2_C_LZ5_OBJS` 3、`ZS_T2_C_ZSTDMT_OBJS` 13。規則與旗標沿用 G2 的 `7zstar_gcc.mak`，G3 只改清單（沒有動規則）。
- 乾淨建置：exit 0、0 warning、**442 個 `.o`**（322＋27＋93）、`b/g/7zz` 4,910,392 bytes（與 G1 原型大小相同）。
- `7zz i` 另外列出 `tar.bz2`／`tar.gz`／`tar.xz`（上游本來就有的串聯格式）；fork 的串聯格式是 `tar.zst`、`tar.br`、`tar.lz4`、`tar.lz5`、`tar.liz`。
- **`-mmt` 行為（與原先預期不同）：** 獨立檔 `-tbrotli`／`-tlz4` 的寫入端**不會**轉發 `-mmt`（`Lz4Handler.cpp:456-475`、`BrotliHandler.cpp:245` 的註解與實測一致，Windows 同），所以 `a -tbrotli|-tlz4 -mmt=4` 的檔頭是 `AF FF DF 01`／`04 22 4D 18`，不是 `50 2A 4D 18`。skippable 容器出現在 `.7z` 編碼路徑（`-t7z -m0=brotli -mmt=4`、`-m0=lz4 -mmt=4`，封包流起點 offset 32 為 `50 2A 4D 18`）；`.lz5`／`.liz` 的容器則是無條件的預設輸出。

### G2／G3 具體工作

- **G2（層級 1）**：新增上述兩個檔（`ZS_T2_*` 全部留空）；修 `TempFileDecodedStream.cpp`（必須）與 `ZstdEncoder.cpp`（建議）；`.gitattributes` 加兩行（見下節）；`.gitignore` 加 `_o/`、`b/`；建置 → 預期 348 個物件、`7zz` 約 3.39 MB；跑 `7zz i`、`a -tzstd` + `zstd -t`、`x` 讀 Linux `zstd` 產的檔。
- **G3（層級 2）**：填入 `ZS_T2_*`（表中 94 列）；建置 → 預期 442 個物件、`7zz` 約 4.91 MB；`7zz i` 應列出 `br liz lz4 lz5 zst tar.br tar.liz tar.lz4 tar.lz5 tar.zst` 與 `ZSTD BROTLI FLZMA2 LIZARD LZ4 LZ5` codec。

## 官方檔改動清單

**無。**（官方建置檔：`7zip_gcc.mak`、`Arc_gcc.mak`、`LzmaDec_gcc.mak`、各 `makefile.gcc`、`var_gcc*.mak`、`warn_gcc*.mak`、`cmpl_*.mak` 皆不動；G1 結束時 `git status` 乾淨，`git diff <移植前的 commit> -- CPP/7zip/*.mak CPP/7zip/Bundles` 在這些檔上為空。）

### 非官方檔、但 G2 需要動的檔（fork 自有，不屬硬約束 (c)(f) 的範圍）

| 檔 | 為什麼 | 內容 |
|---|---|---|
| `CPP/7zip/Archive/Common/TempFileDecodedStream.cpp`（fork 新檔，M6b） | **必須。** 用了 Windows 版 `NWindows::NFile::NIO` 的 `COutFile::Write`、`CInFile::Read`、`CInFile::Seek`；POSIX 版（`CPP/Windows/FileIO.h:365-503`）的成員是 `COutFile::write_full`、`CInFile::read_part`、`CFileBase::seek`。編譯錯誤 3 處（`has no member named 'Write'／'Read'／'Seek'`）。 | 用 `#ifdef _WIN32` 保留原 Windows 程式碼、`#else` 放下方補丁的 POSIX 版（**不可以破壞 Windows 建置**）。語意：`ISequentialInStream::Read` 允許短讀，`read_part` 夠用；`seekOrigin` 0/1/2 與 `SEEK_SET/CUR/END` 數值相同。 |
| `CPP/7zip/Compress/ZstdEncoder.cpp`（fork 新檔，M2） | 建議。`#pragma warning(push/disable : 4061/pop)`（行 200、201、220）在 gcc 的 `-Werror` 下變成 `-Werror=unknown-pragmas`（3 個 error）。 | 用 `#ifdef _MSC_VER … #endif` 包起來（補丁如下）。不改原始碼的替代：`$O/ZstdEncoder.o: ZS_DEFS_ZSTD += -Wno-unknown-pragmas`（已實測可行）。 |
| `.gitattributes` | 建議。新 makefile 預設會被 `* text=auto eol=crlf` 轉成 CRLF（實測 make 4.3 不受影響，但上游把 `makefile.gcc` 指定為 LF，保持一致）。 | 在 `makefile.gcc text eol=lf` 那行旁邊加：`makefile.7zstar.gcc text eol=lf`、`7zstar_gcc.mak text eol=lf`。 |
| `.gitignore` | 建議。`_o/`（直接 `make -f makefile.gcc`）與 `b/`（`var_gcc.mak` 的 `O=b/g`）目前都**不在** `.gitignore`，建置後 `git status` 會出現大量物件檔。 | 加 `_o/`、`b/`。 |

**注意（CRLF）：** 這兩個 `.cpp` 在 Linux 工作樹也是 CRLF（`.gitattributes` 的 `eol=crlf`）。用編輯工具改時請保留行尾，或讓 git 以 `text=auto` 正規化；補丁用 `diff --strip-trailing-cr` 比對就沒有雜訊。

補丁（在 暫存目錄 樹上實測：`TempFileDecodedStream.cpp` 為 POSIX 分支內容；G2 要再加 `#ifdef _WIN32` 包住 Windows 分支）：

```diff
--- a/CPP/7zip/Compress/ZstdEncoder.cpp
+++ b/CPP/7zip/Compress/ZstdEncoder.cpp
@@ -197,8 +197,10 @@
 // deliberately non-exhaustive (many ZSTD_ErrorCode values have no better
 // HRESULT than the E_FAIL default; -Wall would otherwise flag every one of
 // them individually via C4061 even though a default: case is present).
+#ifdef _MSC_VER
 #pragma warning(push)
 #pragma warning(disable : 4061)
+#endif
 static HRESULT Zstd_GetErrorHRESULT(size_t zstdErrCode)
 {
   switch (ZSTD_getErrorCode(zstdErrCode))
@@ -217,7 +219,9 @@
       return E_FAIL;
   }
 }
+#ifdef _MSC_VER
 #pragma warning(pop)
+#endif
 
 static HRESULT Zstd_ApplyParam(ZSTD_CCtx *ctx, ZSTD_cParameter param, int value)
 {
--- a/CPP/7zip/Archive/Common/TempFileDecodedStream.cpp
+++ b/CPP/7zip/Archive/Common/TempFileDecodedStream.cpp
@@ -41,7 +41,10 @@
 Z7_COM7F_IMF(CLocalOutFileStream::Write(const void *data, UInt32 size, UInt32 *processedSize))
 {
   UInt32 processed = 0;
-  const bool ok = File.Write(data, size, processed);
+  size_t p2 = 0;
+  const ssize_t r = File.write_full(data, size, p2);
+  const bool ok = (r != -1);
+  processed = (UInt32)p2;
   if (processedSize)
     *processedSize = processed;
   return ok ? S_OK : GetLastError_noZero_HRESULT();
@@ -167,7 +170,9 @@
 {
   COM_TRY_BEGIN
   UInt32 processed = 0;
-  const bool ok = _file.Read(data, size, processed);
+  const ssize_t r = _file.read_part(data, size);
+  const bool ok = (r != -1);
+  if (ok) processed = (UInt32)r;
   if (processedSize)
     *processedSize = processed;
   return ok ? S_OK : GetLastError_noZero_HRESULT();
@@ -181,7 +186,9 @@
   if (seekOrigin >= 3)
     return STG_E_INVALIDFUNCTION;
   UInt64 realNewPosition = 0;
-  const bool ok = _file.Seek(offset, seekOrigin, realNewPosition);
+  const off_t r = _file.seek((off_t)offset, (int)seekOrigin);
+  const bool ok = (r != (off_t)-1);
+  if (ok) realNewPosition = (UInt64)r;
   if (newPosition)
     *newPosition = realNewPosition;
   return ok ? S_OK : GetLastError_noZero_HRESULT();
```

### vendored 函式庫 / vendored 改動

**vendored 改動：無**（G3 完成後 `git diff --stat <移植前的 commit> -- C` 為空）。**無改動**（`C/zstd`、`C/brotli`、`C/lz4`、`C/lz5`、`C/lizard`、`C/fast-lzma2`、`C/zstdmt`、`C/hashes` 全部不動；需要的只是 per-group 旗標）。

## vendored 函式庫的 Windows 相依與處理

指令：`grep -rnE "windows\.h|WIN32|_WIN32|_MSC_VER|process\.h|<io\.h>|Interlocked|CRITICAL_SECTION|_beginthread|__declspec|_mkdir|<intrin" C/<dir> --include=*.c --include=*.h`。結果與逐一檢查：

| 目錄 | 命中數 | Windows 相依 | 保護／POSIX 後備 | 實測 | 處理 |
|---|---|---|---|---|---|
| `C/fast-lzma2`（35 檔） | 63 | `util.h/.c`、`platform.h` 的 `windows.h`／`io.h`；`atomic.h` 的 `InterlockedIncrement/Add`；`fl2_threading.h/.c` 的 `CRITICAL_SECTION`、`_beginthreadex`、`<process.h>` | 全部在 `_WIN32`／`_MSC_VER`／`MSDOS\|OS2\|WIN32` 之內；後備：`atomic.h` 走 `__GNUC__` 的 `__sync_fetch_and_add`，`fl2_threading.h` 走 `MYTHREAD_POSIX`（pthread），`util.c` 走 POSIX 目錄走訪 | 11 檔全部編過 | 不改檔。加 `-DNO_XXHASH -DFL2_7ZIP_BUILD`（Windows 對齊）。**不要**嘗試補 `windows.h` 的 `_WIN32` 保護，已經有了。 |
| `C/zstdmt`（23 檔） | 15 | `threading.h` 的 `windows.h`／`CRITICAL_SECTION`；`zstd-mt_threading.c` 的 `<process.h>`／`_beginthreadex`；`memmt.h` 的 `<intrin.h>` | `threading.h` 是 `#ifdef _WIN32 … #else <pthread.h>`；`zstd-mt_threading.c` 整檔在 `#ifdef _WIN32` 內，Linux 上是空檔（`nm` 無符號）；`memmt.h` 的 intrin 在 `_MSC_VER` 內 | 13 檔編過；8 個 `*-mt_{compress,decompress}.c` 需 `-Wno-comment`（見警告策略）與 `-I` 六個目錄 | 不改檔，加旗標。 |
| `C/brotli`（47 檔） | 26 | `port.h`、`common/platform.h` 的 `__declspec(dllexport/import)`、`<intrin.h>`、`_MSC_VER` 分支 | 全部在 `_WIN32`／`_MSC_VER`／`BROTLI_MSVC_VERSION_CHECK(…)` 內 | 35 檔編過 | 不改檔。 |
| `C/lz5`（12 檔） | 15 | `lz5common.h` 的 `<intrin.h>`、`__declspec(deprecated)` | 全部在 `_MSC_VER` 內 | 3 檔（lz5、lz5frame、lz5hc）編過 | 不改檔。 |
| `C/lizard`（39 檔） | 20 | `__declspec(dllexport)`、`<intrin.h>` | 全部在 `_MSC_VER`／`_WIN32` 內 | 8 檔編過 | 不改檔。 |
| `C/lz4`（10 檔） | 25 | 同上 | 同上 | 3 檔編過 | 不改檔。 |
| `C/zstd`（82 檔；其中 `zstd_v01..v07`、解壓端不編） | 122 | `threading.h`／`threading.c`（`<process.h>`）、`mem.h`／`compiler.h` 的 `_MSC_VER` 與 `<intrin.h>` | 全部在 `_WIN32`／`_MSC_VER` 內；`ZSTD_MULTITHREAD` 且非 `_WIN32` → 直接用 `<pthread.h>` | 21 檔編過 | 不改檔。**必須** `-DZSTD_MULTITHREAD`。只編壓縮端；解壓端仍走官方 `C/ZstdDec.c`。 |
| `C/hashes`（3 檔） | 27 | `xxhash.h` 的 `__declspec`、`XXH_ALIGN`、`XXH_NO_INLINE` 等 MSVC 分支 | 同上 | `xxhash.c` 編過 | 不改檔。 |

結論：**所有 Windows 專屬 API 都已經在 `_WIN32`／`_MSC_VER` 內，不需要補保護**（原先預期要補保護的 `C/fast-lzma2` 的 `windows.h` 也已有 `#if defined(_WIN32)` 保護，`util.h:56`、`util.c:478`、`fl2_threading.h:19/55`、`atomic.h:20/36`）。判斷依據不只是 grep，而是 95 個檔在 gcc 13（兩種旗標組）與 clang 18 全部實際編過。

不是 Windows 專屬、但在 Linux 上需要注意的：

- `C/fast-lzma2` 的 POSIX 執行緒路徑在原註解裡寫「posix assumed」（`fl2_threading.h:22`），沒有偵測。實測 `-m0=flzma2 -mmt=4` 壓縮後 `7zz t` 通過，但這是小量冒煙，G4 要用大檔與多執行緒壓力再驗。
- `atomic.h` 在 gcc 下用 `long` 與 `__sync_fetch_and_add`，沒有對 32 位元或非 x86 特別處理（未測，見風險）。

## warning 處理策略

### 實測矩陣（全部是 gcc 13.3 / clang 18.1.3，`-O2`，新增 120 物件為對象）

| # | 設定 | 結果 |
|---|---|---|
| 1 | 單檔，旗標＝直接 `make -f makefile.gcc` 的旗標：`cc -O2 -c -Werror -Wall -Wextra -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC` ＋群組旗標，檔案 `C/zstd/zstd_compress.c`（`-DZSTD_MULTITHREAD`）、`C/brotli/br_encode.c`、`C/fast-lzma2/fl2_compress.c`（`-DNO_XXHASH -DFL2_7ZIP_BUILD`）、`C/lizard/lizard_compress.c`、`C/lz5/lz5hc.c` | 5 個全部 exit 0、0 警告 |
| 2 | 同 1，整批 120 物件（只加群組旗標） | 只有 3 個檔失敗：`ZstdEncoder.cpp`（`#pragma warning` ×3，`-Werror=unknown-pragmas`）、`TempFileDecodedStream.cpp`（3 處 Windows 成員，非警告）、`C/zstdmt/memmt.h:386`（`"/*" within comment`，`-Werror=comment`，影響 8 個 `{brotli,lizard,lz4,lz5}-mt_{compress,decompress}.c`） |
| 3 | 同 2，套用「單項處理」（下方）後 | exit 0、0 警告、442 個物件 |
| 4 | `DEBUG_BUILD=1`（`-g`、不帶 `-DNDEBUG`，assert 與 `DEBUGLOG` 啟用）；旗標同 3，**未帶** `warn_gcc.mak` | exit 0、0 警告（約 61 秒，`-j4`） |
| 5 | `CC=clang CXX=clang++`（clang 18.1.3）；旗標同 3，**未帶** `warn_gcc.mak` | exit 0、0 警告 |
| 6 | **官方入口旗標**（`var_gcc.mak`＋`warn_gcc.mak`，`CFLAGS_WARN` 含 `-Wconversion -Wunused-macros -Wcast-align -Wimplicit-fallthrough=5 …`），未放寬 | **95 個 vendored C 有 56 個失敗**；第一輪 773 筆診斷：`-Wsign-conversion` 680、`-Wimplicit-fallthrough=` 40、`-Wconversion` 30、`-Wcast-align` 23；壓掉這些後第二輪再浮出 46 筆 `-Wunused-macros`。fork 的 25 個 C++ 全部通過。 |
| 7 | 同 6，vendored C 加 `-Wno-conversion -Wno-sign-conversion -Wno-implicit-fallthrough -Wno-cast-align -Wno-unused-macros`（zstdmt 另加 `-Wno-comment`） | **exit 0、0 警告**；最終骨架在乾淨目錄從零建置：442 物件、約 44 秒、`7zz` 4,910,392 bytes |
| 8 | 單檔實測負向對照：`lz4-mt_compress.c` 不加 `-Wno-comment` → `memmt.h:386:21: error: "/*" within comment [-Werror=comment]`；不加 `-I` → `fatal error: lz4frame.h`；`ZstdEncoder.cpp` 原樣 → 4 行 error，加 `-Wno-unknown-pragmas` 或 `_MSC_VER` 保護 → exit 0 | 已記錄 |

### 策略

1. **不降低上游的基準：** 一律沿用 `-Werror -Wall -Wextra`，經 `var_gcc.mak`＋`warn_gcc.mak` 取得官方警告集。不使用 `-w`、不把 `-Werror` 拿掉。
2. **fork 自己寫的 C++（25 檔）：** 不放寬，必須在官方警告集下乾淨。已實測通過；唯一例外是 `ZstdEncoder.cpp` 的 MSVC pragma，修法是原始碼加 `#ifdef _MSC_VER`（建議），或旗標 `-Wno-unknown-pragmas`（備案）。
3. **vendored 第三方 C（95 檔）：** 只對這些物件的規則加 `ZS_WARN_VENDOR`（5 個 `-Wno-…`，只關掉 `warn_gcc.mak` 額外開的類別，**沒有關掉** `-Wall -Wextra` 內的任何一項）。依據：它們是第三方程式，上游本身就不在這個警告集下維護；不改 vendored 原始碼，保持 `UPSTREAM.txt` 的「與上游一致」。
4. **`ZS_WARN_ZSTDMT = -Wno-comment`** 只給 `C/zstdmt/*.c`。成因是 `memmt.h:386` 的 fork 自寫註解含 `Compress/*Encoder.cpp`；另一個等價修法是改該註解（一個字元），但那會動 vendored 檔，所以選旗標。
5. **各目錄實際觸發的類別**（第一輪）：zstd＝sign-conversion、conversion；lz4＝sign-conversion、implicit-fallthrough；lz5＝sign-conversion（187 筆）、conversion、implicit-fallthrough；lizard＝sign-conversion（270 筆）、conversion、implicit-fallthrough；brotli＝implicit-fallthrough（32）、cast-align（15）；zstdmt＝sign-conversion、conversion；fast-lzma2＝sign-conversion（101）、cast-align、conversion；所有目錄＝unused-macros。為了規則簡單，所有 vendored C 套同一組旗標。
6. Windows 側那串 `-wd4710 -wd4711 …` 是 MSVC 專用，不適用。

## 預估風險

| # | 風險 | 可能性／影響 | 說明與緩解 |
|---|---|---|---|
| 1 | `TempFileDecodedStream.cpp` 的 POSIX 修正語意有誤（短讀、`seek` 回傳值） | 低／中 | 實測 `7zz x c.tar.zst` 還原後 `cmp` 一致、`.7z`／`.tar.br` 讀取正常；G4 要補「大於暫存緩衝」「隨機 seek」的案例。 |
| 2 | 能編過但在 Linux 行為不同的 fork C++（路徑分隔符、暫存目錄、`wchar_t` 為 4 bytes、`GetLastError`） | 中／中 | 本次只驗了編譯與冒煙；G4 的向量測試是主要防線。 |
| 3 | fast-lzma2 的 POSIX 執行緒路徑（原作者註明「posix assumed」） | 中／中 | 小量冒煙過；G4 用大檔＋`-mmt` 多組合壓測，必要時用 `-fsanitize=thread` 另建一份（只在 G4 做）。 |
| 4 | 上游 gcc makefile 在下一個上游版本更名或重組 `OBJS`／`PROGPATH`／`CXXFLAGS`／`$O` | 低／中 | 方案 B 依賴這些變數名。緩解：合併上游時先跑一次 `make -f makefile.7zstar.gcc -n`；骨架很短，修起來快。 |
| 5 | 官方警告集隨 gcc 版本變多（`warn_gcc.mak` 針對新版 gcc 加旗標），fork C++ 可能新增警告 | 低／低 | 目前 gcc 13 通過；vendored 部分已全關。升級編譯器時再查。 |
| 6 | 其他架構（arm64、32 位元 x86）與 `USE_ASM=1`（需要 `asmc`／`jwasm`） | 未知／低 | 全部未驗證（附錄 B）。fork 新碼沒有組合語言；`atomic.h`、zstd 的 SIMD 選擇在非 x86_64 的行為未測。 |
| 7 | `ST_MODE=1`（單執行緒、`-DZ7_ST`）下 fork 的 MT 碼（`TarChainHandler`、各 `*Encoder.cpp` 呼叫 zstdmt）能否編過 | 未知／低 | 未驗證。TarChainHandler 內有 `#ifndef Z7_ST`，其他檔未檢查。 |
| 8 | 物件檔平面放在同一個 `$(O)`：未來新增 vendored 檔若與上游同名會互相覆蓋 | 低／高（會靜默錯鏈） | 目前 442 個無重名；G2 可加一行檢查（`sort | uniq -d`）。 |
| 9 | 驗證用 Linux 工具需要先 `apt-get update`（映像內的套件索引是空的） | 確定／低 | 實測 `apt-get install zstd brotli lz4` 在 `apt-get update` 之後成功；lz5／lizard 無套件（REPORT 已記）。 |
| 10 | 單次建置時間：+120 物件約 +20 秒（4 核）；官方警告集下全量約 44 秒 | 低／低 | 無需處理。 |

## 附錄 A：實證紀錄

環境：Ubuntu 24.04；`gcc 13.3.0`；`GNU Make 4.3`；`clang 18.1.3`。路徑以 `$S` 表示 暫存目錄。

**A.1 基線重現（移植前的樹，未改任何檔）**

```text
$ cd CPP/7zip/Bundles/Alone2 && make -j4 -k -f makefile.gcc O=$S/_o
...  322 個物件編過，連結失敗
make: *** [../../7zip_gcc.mak:267: .../_o/7zz] Error 1        # (行號為 CRLF 工作樹)
12 個 undefined reference（見「層級 1 證明」第 1 點）          real 0m26.7s
```

**A.2 原型（零改動官方檔）關鍵數字**

- 只靠 `include makefile.gcc` ＋ `OBJS +=` ＋ 靜態 pattern rule：`make -n` 顯示 120 個新物件編譯（既有 322 個不重編）；`make -n clean` 列出 442 個 `.o`。
- 失敗只有 A.3 列的 3 個檔，和 6 個 zstdmt 檔的 `-Wcomment`；套用處理後 `exit=0`，`$S/_o/7zz` 4,910,392 bytes。

**A.3 冒煙測試（依最終骨架從零建置的 `b/g/7zz`；暫存目錄 樹，已含兩個 fork 檔補丁）**

```text
$ 7zz i                      # 格式：br liz lz4 lz5 tar.br tar.liz tar.lz4 tar.lz5 tar.zst zst（另有 brotli/lizard/lz4/lz5/zstd 格式列）
                             # Codecs：ZSTD(4F71101) ZSTD-WZ(4015D，僅解) BROTLI(4F71102) FLZMA2(21) LIZARD(4F71106) LZ4(4F71104) LZ5(4F71105)
$ 7zz a -tzstd a.zst big.txt   &&  zstd -t a.zst              → a.zst : 4052632 bytes   （通過）
$ 7zz a -tbrotli a.br big.txt  &&  brotli -t a.br             → brotli-ok
$ 7zz a -tlz4 a.lz4 big.txt    &&  lz4 -t a.lz4               → decoded 4052632 bytes
$ 7zz a -ttar.zst c.tar.zst d  &&  zstd -dc c.tar.zst | tar tf -   → d/  d/big.txt
$ 7zz x -y -oo c.tar.zst       &&  cmp o/d/big.txt big.txt    → tar.zst-roundtrip-identical
$ 7zz a -t7z -m0={zstd,brotli,lz4,lz5,lizard,flzma2} -mmt=4 m.7z big.txt && 7zz t m.7z   → 六種全部 Everything is Ok
$ zstd -q big.txt -o lin.zst   &&  7zz t lin.zst              → Everything is Ok     （Linux zstd 產、7zz 讀）
$ tar cf - d | brotli > lin.tar.br && 7zz x lin.tar.br && cmp  → linux-tar.br-extract-identical
```

註：`7zz a c1.tar.zst d`（沒有 `-ttar.zst`）依副檔名選到單檔 `zstd` 格式，對目錄回 `E_INVALIDARG`；對**已存在**的 `.tar.zst` 再 `a` 也回 `E_INVALIDARG`（原因未查，未與 Windows 比對）。這兩點不是 Linux 問題，G4 寫測試時要避開或明確記錄。

**A.4 其他實測**

- 層級 1 單獨建置（骨架把 `ZS_T2_*` 清空）：348 個物件，exit 0，`7zz` 3,390,000 bytes。
- `ZstdRegister.o`：骨架中不給規則，沒有 `overriding recipe` 警告（`grep -cE "overriding|ignoring" = 0`）。
- CRLF 版骨架：`make -n` 與實際重編單一物件均正常。

## 附錄 B：未做／未驗證

- **未驗證：** arm64／32 位元 x86／`USE_ASM=1`（本環境沒有 `asmc`／`jwasm`：`which asmc jwasm` 無輸出；`var_gcc_x64.mak` 設 `IS_X64=1`、`USE_ASM=1`，實跑時 8 個 `*Opt.o` 回 `Error 127`）、`ST_MODE=1`、`-flto`、`COMPL_STATIC`（`7zzs` 靜態版）、`cmpl_clang*.mak`（`warn_clang.mak` 用 `-Weverything` 類旗標，只用預設 clang 旗標驗過）。
- **未驗證：** `.7z` 內 lz5／lizard 的**與其他實作**互通（沒有 Linux 工具；只驗了 7zz 自己壓自己解）。
- **未做：** 對 Windows 建置的影響檢查（G1 沒有動任何檔；G2 修 `TempFileDecodedStream.cpp` 時請用 `#ifdef _WIN32` 包住原路徑，Windows 側無法在此環境編譯驗證，建議在 Windows 端做一次 `Build.ps1`）。
- **未做：** `test/interop/` 向量的實際比對（屬 G4）。
- 實驗用的 暫存目錄 樹、原型 makefile、閉包腳本不入庫；可重現所需的指令與完整骨架都在本檔。
