# Linux 互通驗證報告（7-ZSTar × Linux 工具）

範圍：只測與記錄，不修任何原始碼或 makefile。
本檔由 Linux 端逐步填寫（A→E）；各段標題後的「狀態」註明該段是否已完成。

**摘要**

- **gcc 建置（B）**：失敗，發生在連結階段。322 個物件檔全部編過、0 警告。有 4 個原始檔沒列進 gcc 側的建置清單，連 6 個官方格式的 handler 都連不起來。
- **Windows 產物讀 Linux（C）**：25 個檔的位元組數、sha256、前 16 bytes 全部與 `MANIFEST.md` 一致。預期寫得明確的格子沒有任何一格相反。最大的意外：bsdtar 3.7.2 能解 `.7z` 內的 ZSTD。
- **Linux 向量（D）**：37 個，每個都用寫出它的工具解回來並比對 sha256，合計約 3.9 MiB。lz5 與 lizard 無套件，沒有產生。
- **尚未驗證**：7-ZSTar 讀這 37 個向量（需在 Windows 端進行），以及 gcc 版 `7zz` 的執行結果（沒有執行檔）。

## 1. 環境

狀態：完成（issue A）。記錄時間：2026-11-03T17:23Z（UTC）。

| 項目 | 版本／輸出 | 取得方式 |
|---|---|---|
| OS | Ubuntu 24.04.5 LTS (Noble Numbat)，`lsb_release -a`：Release 24.04 | 容器（以 root 執行，`apt-get` 不需 sudo） |
| 核心 | `Linux vm 6.18.44-fc-v230 #1 SMP PREEMPT_DYNAMIC @0 x86_64 x86_64 x86_64 GNU/Linux` | `uname -a` |
| CPU 執行緒數 | 4（`nproc`） | — |
| GNU tar | `tar (GNU tar) 1.35` | 系統內建 |
| bsdtar | `bsdtar 3.7.2 - libarchive 3.7.2 zlib/1.3 liblzma/5.4.5 bz2lib/1.0.8 liblz4/1.9.4 libzstd/1.5.5` | apt `libarchive-tools` 3.7.2-2ubuntu0.9 |
| zstd | `*** Zstandard CLI (64-bit) v1.5.5, by Yann Collet ***`（`--format=lz4` 出現在 `--help`） | apt `zstd` 1.5.5+dfsg2-2build1.1 |
| brotli | `brotli 1.1.0`（`--help` 有 `--large_window=NUM`，範圍 0、10-30） | apt `brotli` 1.1.0-2ubuntu0.1 |
| lz4 | `*** LZ4 command line interface 64-bits v1.9.4, by Yann Collet ***` | apt `lz4` 1.9.4-1build1.1 |
| xz | `xz (XZ Utils) 5.4.5` / `liblzma 5.4.5` | apt `xz-utils` |
| bzip2 | `bzip2 ... Version 1.0.8, 13-Jul-2019.` | apt `bzip2` |
| gzip | `gzip 1.12` | 系統內建 |
| xxd | `2:9.1.0016-1ubuntu7.20`（系統原本沒有，C 步驟需要，用 `apt-get install xxd` 補上） | apt |
| 官方 7-Zip | `7-Zip (z) 26.05 (x64) : Copyright (c) 1999-2026 Igor Pavlov : 2026-10-21`；`64-bit locale=C.UTF-8 Threads:4 OPEN_MAX:20000, ASM` | `https://github.com/ip7z/7zip/releases/download/26.05/7z2605-linux-x64.tar.xz`（GitHub 一次成功，HTTP 200，1579976 bytes），解到 `~/7zz/`，以 `~/7zz/7zz` 執行 |
| gcc | `gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0` | 系統內建 |
| make | `GNU Make 4.3`（`Built for x86_64-pc-linux-gnu`） | 系統內建 |
| lz5 / lizard 工具 | **無套件**：`apt-cache search -n lz5` 無結果；`apt-cache search -n lizard` 只有 `cl-agnostic-lizard`（Common Lisp 程式碼走訪器，與 Lizard 壓縮無關）。依規定不自行從原始碼編譯。 | — |

下載檔 `7z2605-linux-x64.tar.xz` 的 sha256：`22cf82fcc6eb7474f1d5bb4f02c0f8ebd573a718089d6833dc30f8350a3b232e`。

### 官方 7zz 26.05 的能力清單（`7zz i` 實跑，供後面矩陣對照）

- 有 `zstd` 格式處理器（副檔名 `zst tzst (.tar)`，旗標只有 K，即單檔串流），沒有 brotli／lz4／lz5／lizard 格式。
- Codec 清單只有 BCJ2／BCJ／PPC／IA64／ARM／ARMT／SPARC／ARM64／RISCV／Swap2／Swap4／BZip2／Copy／Deflate64／Deflate／Delta／LZMA2／LZMA／PPMD／Rar1-5／7zAES／AES256CBC。
  沒有 ZSTD／BROTLI／LZ4／LZ5／LIZARD codec，與事前對 `.7z` 內這些方法的預期一致（尚未用實檔驗證，留待 C）。
- 同一個 tarball 另含靜態版 `7zzs`；本報告一律使用 `7zz`。

## 2. gcc 建置

狀態：完成（issue B）。結果：**失敗，發生在連結階段**；編譯階段全部通過。完整 log 已存為 `test/interop/logs/alone2-build.log`（359 行，sha256 `be8f2486454f5ec704ade47c742e8f87e365d8cdd9aeb686904a65183a1c6dfc`；這個雜湊是 git 內存的 LF 換行內容，在 Windows 以 `eol=crlf` 檢出後會不同）。

### 指令與環境

```bash
cd CPP/7zip/Bundles/Alone2
make -j"$(nproc)" -f makefile.gcc > ~/alone2-build.log 2>&1; echo "make exit=$?" >> ~/alone2-build.log
```

- 與原定做法的差異：用重新導向取代 `| tee`，並把 exit code 附在 log 最後一行，內容等價。
- 執行時間 2026-11-03T22:02:57Z 到 22:03:24Z，實際耗時 26.7 秒，`nproc` = 4，**`make exit=2`**。
- 編譯器 gcc／g++ 13.3.0（Ubuntu 13.3.0-6ubuntu2~24.04.1），makefile 帶入的旗標：`-O2 -c -Werror -Wall -Wextra -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC`。
- 沒有修改任何 makefile 或原始碼，也沒有手動補 obj 清單。建置輸出目錄 `_o/` 已在取證後刪除，`git status` 中只剩 `test/interop/` 底下的新增檔。

### 結果

| 階段 | 結果 | 證據 |
|---|---|---|
| 編譯 | **通過**：322 個物件檔全部產出，0 個 warning，0 個編譯錯誤 | log 內 `-c` 編譯指令 322 行；`_o/*.o` 322 個；`grep -c -i warning` = 0；全 log 僅 1 行含 `error:`，且是連結器的 `collect2: error: ld returned 1 exit status` |
| 連結 | **失敗**：12 個不同的未定義符號，來自 6 個 handler 物件檔（Bz2Handler、GzHandler、LzmaHandler、XzHandler、ZHandler、ZstdHandler） | `make: *** [../../7zip_gcc.mak:267: _o/7zz] Error 1` |
| `7zz i` | **未測**：連結失敗，沒有執行檔 | `ls _o/7zz`：No such file or directory |
| `7zz t windows/chain/corpus.tar.zst` | **未測**：同上 | 同上 |

第一個（也是唯一一類）錯誤，log 第 325 到 326 行（原文，未改動）：

```text
/usr/bin/ld: _o/Bz2Handler.o: in function `NArchive::NBz2::CHandler::GetStream(unsigned int, ISequentialInStream**)':
Bz2Handler.cpp:(.text+0x656): undefined reference to `RewindableDecodedStream_GetPullInterfaces(IUnknown*, CMyComPtr<ISequentialInStream>&, CMyComPtr<ICompressSetInStream>&, CMyComPtr<ICompressSetOutStreamSize>&)'
```

### 未定義符號與歸屬（12 個）

下表的「定義位置」用 `grep` 在原始碼樹內確認，「參照者」取自 ld 的 `in function` 輸出。

| 未定義符號 | 定義位置（未列入 gcc 清單） | 參照的物件檔 |
|---|---|---|
| `RewindableDecodedStream_GetPullInterfaces`、`RewindableDecodedStream_SniffTar`、`CRewindableDecodedStream::Init`、`vtable for CRewindableDecodedStream` | `CPP/7zip/Archive/Common/RewindableDecodedStream.cpp` | Bz2Handler、GzHandler、LzmaHandler、XzHandler（只有 `SniffTar`）、ZstdHandler |
| `TempFileDecodedStream_SniffTar`、`CTempFileDecodedStream::Init`、`vtable for CTempFileDecodedStream` | `CPP/7zip/Archive/Common/TempFileDecodedStream.cpp` | ZHandler |
| `NCompress::NZstd::CEncoder::CEncoder()`、`NCompress::NZstd::CEncoderProps::SetFromMethodProps` | `CPP/7zip/Compress/ZstdEncoder.cpp` | ZstdHandler（`UpdateItems`） |
| `ZstdEncProps_Init`、`ZstdEncProps_NormalizeFull`、`ZstdEncProps_GetNumThreads_for_MemUsageLimit` | `CPP/7zip/Compress/ZstdEncoderProps.cpp` | ZstdHandler（`UpdateItems`） |

### 判定：缺在哪一層

1. **編譯層沒有問題。** gcc 13.3.0 在 `-Werror -Wall -Wextra` 下編過 322 個物件檔，其中包含被 fork 改過的 Bz2／Gz／Lzma／Xz／Z／Zstd 六個 handler。
2. **缺在連結層的 gcc 建置清單。** 有 4 個原始檔從未被編譯，因為沒有列進 gcc 側清單：`Archive/Common/RewindableDecodedStream.cpp`、`Archive/Common/TempFileDecodedStream.cpp`、`Compress/ZstdEncoder.cpp`、`Compress/ZstdEncoderProps.cpp`。Windows 側有列：`CPP/7zip/Bundles/Format7zF/Arc.mak` 第 162、163、295、296 行，`CPP/7zip/Bundles/Alone/makefile` 第 112、113、204、205 行。
3. **gcc 側三個建置檔從未被 fork 更新。** `git diff --stat b88c6bc HEAD -- CPP/7zip/7zip_gcc.mak CPP/7zip/Bundles/Format7zF/Arc_gcc.mak CPP/7zip/Bundles/Alone2/makefile.gcc` 輸出為空，也就是與上游 26.05 的 commit `b88c6bc` 完全相同。
4. **影響不限於新 codec。** 六個官方 handler 被 fork 改過（`git diff --stat b88c6bc HEAD` 為 539 行新增、30 行刪除），改動呼叫了上述 Archive/Common 兩個新檔，所以 gzip、bzip2、lzma、xz、Z 這些官方格式的 handler 在 gcc 下同樣連不起來。
5. **gcc 清單與 Windows 清單的差集很大。** Windows 的 `Arc.mak` 列 373 個物件檔，gcc 側（`Arc_gcc.mak` 加 `Alone2/makefile.gcc`）列 330 個。Windows 有、gcc 沒有的共 107 個，其中 25 個是 handler 或 coder 層級（Brotli、FastLzma2、Lizard、Lz4、Lz5 的 Decoder／Encoder／Handler／Register，TarChainHandler／TarChainRegister，ZstdRegister，ZstdEncoder／ZstdEncoderProps，RewindableDecodedStream，TempFileDecodedStream），其餘 82 個是第三方函式庫的物件檔（`br_*`、`zstd_*`、`lz4*`、`lz5*`、`lizard*`、`fl2_*` 等）。差集取法：從 `Arc.mak` 取出所有 `$O\xxx.obj`，從 `Arc_gcc.mak` 與 `Alone2/makefile.gcc` 取出所有 `$O/xxx.o`，去掉副檔名、排序去重後用 `comm -23` 取 Windows 獨有者。
6. **副觀察。** 上游 26.05 的 `7zip_gcc.mak` 第 828 行有 `ZstdRegister.o` 的規則，但上游 commit `b88c6bc` 的樹內沒有 `ZstdRegister.cpp`（`git ls-tree` 查無），`Arc_gcc.mak` 也沒列它。fork 新增了同名檔案，但它同樣不在 gcc 的連結清單內。

### 預期與實測不同之處

- 事前預期連結失敗，實測相符。
- 事前預期是 ZstdHandler、Bz2Handler、GzHandler 三個 handler 受影響，**實測是六個**（另有 LzmaHandler、XzHandler、ZHandler）。
- 事前預期產物在 `./b/g/7zz`，**此樹的 `makefile.gcc` 實際輸出到 `_o/`**（log 第 1 行 `mkdir -p _o`，連結指令 `-o _o/7zz`）。

### 未測項目（依規定不補清單，所以無法回答）

- 上述 4 個未列入的原始檔，以及 Brotli／Lz4／Lz5／Lizard／FastLzma2 等整組新檔，在 gcc 13.3 下能不能編譯，本次沒有編過，**未測**。
- 補上清單後能不能連結成功，**未測**。
- `7zz i` 與對 `corpus.tar.zst` 的 `7zz t`，因沒有執行檔，**未測**。

### Log 原文摘錄

前 30 行（log 第 1 到 30 行）：

```text
mkdir -p _o
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/7zBuf2.o ../../../../C/7zBuf2.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/7zCrc.o ../../../../C/7zCrc.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/7zCrcOpt.o ../../../../C/7zCrcOpt.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/7zStream.o ../../../../C/7zStream.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/Aes.o ../../../../C/Aes.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/AesOpt.o ../../../../C/AesOpt.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/Alloc.o ../../../../C/Alloc.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/Bcj2.o ../../../../C/Bcj2.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/Bcj2Enc.o ../../../../C/Bcj2Enc.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/Blake2s.o ../../../../C/Blake2s.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/Bra.o ../../../../C/Bra.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/Bra86.o ../../../../C/Bra86.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/BraIA64.o ../../../../C/BraIA64.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/BwtSort.o ../../../../C/BwtSort.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/CpuArch.o ../../../../C/CpuArch.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/Delta.o ../../../../C/Delta.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/HuffEnc.o ../../../../C/HuffEnc.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/LzFind.o ../../../../C/LzFind.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/Lzma2Dec.o ../../../../C/Lzma2Dec.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/Lzma2DecMt.o ../../../../C/Lzma2DecMt.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/Lzma2Enc.o ../../../../C/Lzma2Enc.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/LzmaDec.o ../../../../C/LzmaDec.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/LzmaEnc.o ../../../../C/LzmaEnc.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/Md5.o ../../../../C/Md5.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/MtCoder.o ../../../../C/MtCoder.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/MtDec.o ../../../../C/MtDec.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/Ppmd7.o ../../../../C/Ppmd7.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/Ppmd7Dec.o ../../../../C/Ppmd7Dec.c
cc      -O2 -c -Werror -Wall -Wextra  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC   -o _o/Ppmd7aDec.o ../../../../C/Ppmd7aDec.c
```

連結指令（log 第 324 行，過長，只留前 300 字元）與 ld 輸出（第 325 到 359 行）：

```text
g++ -o _o/7zz -s  -DNDEBUG     -z noexecstack   _o/7zBuf2.o _o/7zCrc.o _o/7zCrcOpt.o _o/7zStream.o _o/Aes.o _o/AesOpt.o _o/Alloc.o _o/Bcj2.o _o/Bcj2Enc.o _o/Blake2s.o _o/Bra.o _o/Bra86.o _o/BraIA64.o _o/BwtSort.o _o/CpuArch.o _o/Delta.o _o/HuffEnc.o _o/LzFind.o _o/Lzma2Dec.o _o/Lzma2DecMt.o _o/Lzma2
/usr/bin/ld: _o/Bz2Handler.o: in function `NArchive::NBz2::CHandler::GetStream(unsigned int, ISequentialInStream**)':
Bz2Handler.cpp:(.text+0x656): undefined reference to `RewindableDecodedStream_GetPullInterfaces(IUnknown*, CMyComPtr<ISequentialInStream>&, CMyComPtr<ICompressSetInStream>&, CMyComPtr<ICompressSetOutStreamSize>&)'
/usr/bin/ld: Bz2Handler.cpp:(.text+0x6b0): undefined reference to `vtable for CRewindableDecodedStream'
/usr/bin/ld: Bz2Handler.cpp:(.text+0x740): undefined reference to `CRewindableDecodedStream::Init(IInStream*, unsigned long, ISequentialInStream*, ICompressSetInStream*, ICompressSetOutStreamSize*, IRewindableMemberContinuation*)'
/usr/bin/ld: Bz2Handler.cpp:(.text+0x75a): undefined reference to `RewindableDecodedStream_SniffTar(IInStream*, bool&)'
/usr/bin/ld: _o/GzHandler.o: in function `NArchive::NGz::CHandler::GetStream(unsigned int, ISequentialInStream**)':
GzHandler.cpp:(.text+0x128d): undefined reference to `RewindableDecodedStream_GetPullInterfaces(IUnknown*, CMyComPtr<ISequentialInStream>&, CMyComPtr<ICompressSetInStream>&, CMyComPtr<ICompressSetOutStreamSize>&)'
/usr/bin/ld: GzHandler.cpp:(.text+0x12e8): undefined reference to `vtable for CRewindableDecodedStream'
/usr/bin/ld: GzHandler.cpp:(.text+0x139b): undefined reference to `CRewindableDecodedStream::Init(IInStream*, unsigned long, ISequentialInStream*, ICompressSetInStream*, ICompressSetOutStreamSize*, IRewindableMemberContinuation*)'
/usr/bin/ld: GzHandler.cpp:(.text+0x13b5): undefined reference to `RewindableDecodedStream_SniffTar(IInStream*, bool&)'
/usr/bin/ld: _o/LzmaHandler.o: in function `NArchive::NLzma::CHandler::GetStream(unsigned int, ISequentialInStream**)':
LzmaHandler.cpp:(.text+0xe53): undefined reference to `RewindableDecodedStream_GetPullInterfaces(IUnknown*, CMyComPtr<ISequentialInStream>&, CMyComPtr<ICompressSetInStream>&, CMyComPtr<ICompressSetOutStreamSize>&)'
/usr/bin/ld: LzmaHandler.cpp:(.text+0xeb0): undefined reference to `vtable for CRewindableDecodedStream'
/usr/bin/ld: LzmaHandler.cpp:(.text+0xf60): undefined reference to `CRewindableDecodedStream::Init(IInStream*, unsigned long, ISequentialInStream*, ICompressSetInStream*, ICompressSetOutStreamSize*, IRewindableMemberContinuation*)'
/usr/bin/ld: LzmaHandler.cpp:(.text+0xf7a): undefined reference to `RewindableDecodedStream_SniffTar(IInStream*, bool&)'
/usr/bin/ld: _o/XzHandler.o: in function `NArchive::NXz::CHandler::GetStream(unsigned int, ISequentialInStream**)':
XzHandler.cpp:(.text+0x3069): undefined reference to `RewindableDecodedStream_SniffTar(IInStream*, bool&)'
/usr/bin/ld: _o/ZHandler.o: in function `NArchive::NZ::CHandler::GetStream(unsigned int, ISequentialInStream**)':
ZHandler.cpp:(.text+0x434): undefined reference to `TempFileDecodedStream_SniffTar(ICompressCoder*, ISequentialInStream*, bool&)'
/usr/bin/ld: ZHandler.cpp:(.text+0x4bd): undefined reference to `vtable for CTempFileDecodedStream'
/usr/bin/ld: ZHandler.cpp:(.text+0x51a): undefined reference to `CTempFileDecodedStream::Init(ICompressCoder*, ISequentialInStream*)'
/usr/bin/ld: _o/ZstdHandler.o: in function `NArchive::NZstd::CHandler::GetStream(unsigned int, ISequentialInStream**)':
ZstdHandler.cpp:(.text+0x1384): undefined reference to `RewindableDecodedStream_GetPullInterfaces(IUnknown*, CMyComPtr<ISequentialInStream>&, CMyComPtr<ICompressSetInStream>&, CMyComPtr<ICompressSetOutStreamSize>&)'
/usr/bin/ld: ZstdHandler.cpp:(.text+0x13e0): undefined reference to `vtable for CRewindableDecodedStream'
/usr/bin/ld: ZstdHandler.cpp:(.text+0x1473): undefined reference to `CRewindableDecodedStream::Init(IInStream*, unsigned long, ISequentialInStream*, ICompressSetInStream*, ICompressSetOutStreamSize*, IRewindableMemberContinuation*)'
/usr/bin/ld: ZstdHandler.cpp:(.text+0x148d): undefined reference to `RewindableDecodedStream_SniffTar(IInStream*, bool&)'
/usr/bin/ld: _o/ZstdHandler.o: in function `NArchive::NZstd::CHandler::UpdateItems(ISequentialOutStream*, unsigned int, IArchiveUpdateCallback*)':
ZstdHandler.cpp:(.text+0x1ae0): undefined reference to `NCompress::NZstd::CEncoder::CEncoder()'
/usr/bin/ld: ZstdHandler.cpp:(.text+0x1e37): undefined reference to `ZstdEncProps_Init'
/usr/bin/ld: ZstdHandler.cpp:(.text+0x1e43): undefined reference to `NCompress::NZstd::CEncoderProps::SetFromMethodProps(CMethodProps const&)'
/usr/bin/ld: ZstdHandler.cpp:(.text+0x1e56): undefined reference to `ZstdEncProps_NormalizeFull'
/usr/bin/ld: ZstdHandler.cpp:(.text+0x1e69): undefined reference to `ZstdEncProps_GetNumThreads_for_MemUsageLimit'
collect2: error: ld returned 1 exit status
make: *** [../../7zip_gcc.mak:267: _o/7zz] Error 1
make exit=2
```

## 3. Windows → Linux 矩陣

狀態：完成（issue C）。執行時間約 2026-11-03T22:20Z。

### 方法

- 先核對 25 個檔的大小、sha256、前 16 bytes：**25 個檔全部與 `MANIFEST.md` 一致**（腳本 `scripts/check_headers.sh`，結果見第 4 節）。
- 每一格都在全新的空目錄執行，記 exit code、驗證結果與錯誤第一行。腳本是 `scripts/run_matrix.sh`，原始資料是 `logs/windows-to-linux-matrix.tsv`（每格一列，含完整指令與輸出目錄的頂層內容）。
- 單檔格式：比對解出的 `text512k.txt` 與 `corpus/SHA256SUMS` 的該行。tar 與 7z：把解出的樹用 `sha256sum -c corpus/SHA256SUMS` 比對，滿分是 `9/9`。
- `empty.txt` 是空檔，它的 sha256 恆等於空字串的雜湊，所以「1/9」只代表空檔「相符」，等於沒解出任何內容。
- 錯誤訊息中的路徑前綴 `/home/user/7-ZSTar/test/interop/` 已省略。指令中的 `OUT` 是該格專屬的空目錄。
- 結果分類：
  - **通過**：exit 0，且解出內容的 sha256 全數相符。
  - **不支援**：工具明確表示認不得這個格式或方法（`Unrecognized archive format`、`Cannot open the file as archive`、`Unsupported Method`、`Unknown codec ID`、`does not look like a tar archive`、`unsupported format`）。
  - **失敗**：工具試著解碼但出錯，或沒有訊息就失敗。
  - **不適用**：把 GNU tar 或 bsdtar 用在單檔格式，payload 本來就不是 tar。
  - **僅解出 .tar**：7zz 一步解 tar 鏈，exit 0 但只輸出 `corpus.tar`。
  - **通過（僅列出或測試）**：`7zz t`、`bsdtar -tf`、`lz4 -t` 這類不解出內容的指令，exit 0。這類格不代表資料能解出。
  - **無工具**：lz5、lizard 在 Ubuntu 24.04 沒有套件。
- 標示「(附加)」的列不在原定清單內，是為了釐清 lz5／lizard 容器被其他 CLI 如何看待而多做的探測，不計入下面的統計。

### 統計

矩陣共 114 格，其中 10 格是附加探測，其餘 104 格是正式格。兩個 mt4 的 `.7z` 只做 `7zz t`，已含在正式格內。

| 結果 | 正式格數（不含附加） | 附加探測格數 |
|---|---|---|
| 通過 | 40 | 0 |
| 不支援 | 29 | 6 |
| 失敗 | 2 | 4 |
| 不適用 | 16 | 0 |
| 僅解出 .tar | 4 | 0 |
| 通過（僅列出或測試） | 9 | 0 |
| 無工具 | 4 | 0 |
| 合計 | 104 | 10 |

### 矩陣

#### 單檔格式（`single/`，payload 是 `text512k.txt`）

| 檔案 | 工具與版本 | 指令 | exit | 驗證 | 結果 | 錯誤第一行或備註 |
|---|---|---|---|---|---|---|
| `single/text512k.txt.zst` | zstd 1.5.5 | `zstd -d -q -o "OUT/text512k.txt" windows/single/text512k.txt.zst` | 0 | sha256 OK | 通過 |  |
| `single/text512k.txt.zst` | GNU tar 1.35 (自動偵測) | `tar -xf windows/single/text512k.txt.zst -C OUT` | 2 | no output file | 不適用 | tar: This does not look like a tar archive（payload 不是 tar） |
| `single/text512k.txt.zst` | bsdtar 3.7.2 | `bsdtar -xf windows/single/text512k.txt.zst -C OUT` | 1 | no output file | 不適用 | bsdtar: Error opening archive: Unrecognized archive format（payload 不是 tar） |
| `single/text512k.txt.zst` | 7zz 26.05 | `7zz x -y -oOUT windows/single/text512k.txt.zst` | 0 | sha256 OK | 通過 |  |
| `single/text512k.txt.br` | brotli 1.1.0 | `brotli -d -o "OUT/text512k.txt" windows/single/text512k.txt.br` | 0 | sha256 OK | 通過 |  |
| `single/text512k.txt.br` | GNU tar 1.35 (自動偵測) | `tar -xf windows/single/text512k.txt.br -C OUT` | 2 | no output file | 不適用 | tar: This does not look like a tar archive（payload 不是 tar） |
| `single/text512k.txt.br` | bsdtar 3.7.2 | `bsdtar -xf windows/single/text512k.txt.br -C OUT` | 1 | no output file | 不適用 | bsdtar: Error opening archive: Unrecognized archive format（payload 不是 tar） |
| `single/text512k.txt.br` | 7zz 26.05 | `7zz x -y -oOUT windows/single/text512k.txt.br` | 2 | no output file | 不支援 | ERROR: windows/single/text512k.txt.br -- Cannot open the file as archive |
| `single/text512k.txt.lz4` | lz4 1.9.4 | `lz4 -d -q windows/single/text512k.txt.lz4 "OUT/text512k.txt"` | 0 | sha256 OK | 通過 |  |
| `single/text512k.txt.lz4` | GNU tar 1.35 (自動偵測) | `tar -xf windows/single/text512k.txt.lz4 -C OUT` | 2 | no output file | 不適用 | tar: This does not look like a tar archive（payload 不是 tar） |
| `single/text512k.txt.lz4` | bsdtar 3.7.2 | `bsdtar -xf windows/single/text512k.txt.lz4 -C OUT` | 1 | no output file | 不適用 | bsdtar: Error opening archive: Unrecognized archive format（payload 不是 tar） |
| `single/text512k.txt.lz4` | 7zz 26.05 | `7zz x -y -oOUT windows/single/text512k.txt.lz4` | 2 | no output file | 不支援 | ERROR: windows/single/text512k.txt.lz4 -- Cannot open the file as archive |
| `single/text512k.txt.lz5` | 專用 CLI | `-` | - | 無工具 | 無工具 | 無 apt 套件，依規定不自編 |
| `single/text512k.txt.lz5` | (附加) zstd 1.5.5 | `zstd -dc windows/single/text512k.txt.lz5 > "OUT/text512k.txt"` | 1 | sha256 MISMATCH | 不支援 | zstd: windows/single/text512k.txt.lz5: unsupported format |
| `single/text512k.txt.lz5` | (附加) lz4 1.9.4 | `lz4 -dc windows/single/text512k.txt.lz5 > "OUT/text512k.txt"` | 1 | sha256 MISMATCH | 失敗 | 無錯誤訊息（exit 1，輸出 0 bytes） |
| `single/text512k.txt.lz5` | (附加) lz4 1.9.4 (-t) | `lz4 -t windows/single/text512k.txt.lz5` | 1 | - | 失敗 | Stream followed by undecodable data at position 16 |
| `single/text512k.txt.lz5` | GNU tar 1.35 (自動偵測) | `tar -xf windows/single/text512k.txt.lz5 -C OUT` | 2 | no output file | 不適用 | tar: This does not look like a tar archive（payload 不是 tar） |
| `single/text512k.txt.lz5` | bsdtar 3.7.2 | `bsdtar -xf windows/single/text512k.txt.lz5 -C OUT` | 1 | no output file | 不適用 | bsdtar: Error opening archive: Zstd decompression failed: Unknown frame descriptor（payload 不是 tar） |
| `single/text512k.txt.lz5` | 7zz 26.05 | `7zz x -y -oOUT windows/single/text512k.txt.lz5` | 2 | no output file | 不支援 | ERROR: windows/single/text512k.txt.lz5 -- Cannot open the file as archive |
| `single/text512k.txt.liz` | 專用 CLI | `-` | - | 無工具 | 無工具 | 無 apt 套件，依規定不自編 |
| `single/text512k.txt.liz` | (附加) zstd 1.5.5 | `zstd -dc windows/single/text512k.txt.liz > "OUT/text512k.txt"` | 1 | sha256 MISMATCH | 不支援 | zstd: windows/single/text512k.txt.liz: unsupported format |
| `single/text512k.txt.liz` | (附加) lz4 1.9.4 | `lz4 -dc windows/single/text512k.txt.liz > "OUT/text512k.txt"` | 1 | sha256 MISMATCH | 失敗 | 無錯誤訊息（exit 1，輸出 0 bytes） |
| `single/text512k.txt.liz` | (附加) lz4 1.9.4 (-t) | `lz4 -t windows/single/text512k.txt.liz` | 1 | - | 失敗 | Stream followed by undecodable data at position 16 |
| `single/text512k.txt.liz` | GNU tar 1.35 (自動偵測) | `tar -xf windows/single/text512k.txt.liz -C OUT` | 2 | no output file | 不適用 | tar: This does not look like a tar archive（payload 不是 tar） |
| `single/text512k.txt.liz` | bsdtar 3.7.2 | `bsdtar -xf windows/single/text512k.txt.liz -C OUT` | 1 | no output file | 不適用 | bsdtar: Error opening archive: Zstd decompression failed: Unknown frame descriptor（payload 不是 tar） |
| `single/text512k.txt.liz` | 7zz 26.05 | `7zz x -y -oOUT windows/single/text512k.txt.liz` | 2 | no output file | 不支援 | ERROR: windows/single/text512k.txt.liz -- Cannot open the file as archive |
| `single/text512k.txt.xz` | xz 5.4.5 | `xz -dc windows/single/text512k.txt.xz > "OUT/text512k.txt"` | 0 | sha256 OK | 通過 |  |
| `single/text512k.txt.xz` | GNU tar 1.35 (自動偵測) | `tar -xf windows/single/text512k.txt.xz -C OUT` | 2 | no output file | 不適用 | tar: This does not look like a tar archive（payload 不是 tar） |
| `single/text512k.txt.xz` | bsdtar 3.7.2 | `bsdtar -xf windows/single/text512k.txt.xz -C OUT` | 1 | no output file | 不適用 | bsdtar: Error opening archive: Unrecognized archive format（payload 不是 tar） |
| `single/text512k.txt.xz` | 7zz 26.05 | `7zz x -y -oOUT windows/single/text512k.txt.xz` | 0 | sha256 OK | 通過 |  |
| `single/text512k.txt.gz` | gzip 1.12 | `gzip -dc windows/single/text512k.txt.gz > "OUT/text512k.txt"` | 0 | sha256 OK | 通過 |  |
| `single/text512k.txt.gz` | GNU tar 1.35 (自動偵測) | `tar -xf windows/single/text512k.txt.gz -C OUT` | 2 | no output file | 不適用 | tar: This does not look like a tar archive（payload 不是 tar） |
| `single/text512k.txt.gz` | bsdtar 3.7.2 | `bsdtar -xf windows/single/text512k.txt.gz -C OUT` | 1 | no output file | 不適用 | bsdtar: Error opening archive: Unrecognized archive format（payload 不是 tar） |
| `single/text512k.txt.gz` | 7zz 26.05 | `7zz x -y -oOUT windows/single/text512k.txt.gz` | 0 | sha256 OK | 通過 |  |
| `single/text512k.txt.bz2` | bzip2 1.0.8 | `bzip2 -dc windows/single/text512k.txt.bz2 > "OUT/text512k.txt"` | 0 | sha256 OK | 通過 |  |
| `single/text512k.txt.bz2` | GNU tar 1.35 (自動偵測) | `tar -xf windows/single/text512k.txt.bz2 -C OUT` | 2 | no output file | 不適用 | tar: This does not look like a tar archive（payload 不是 tar） |
| `single/text512k.txt.bz2` | bsdtar 3.7.2 | `bsdtar -xf windows/single/text512k.txt.bz2 -C OUT` | 1 | no output file | 不適用 | bsdtar: Error opening archive: Unrecognized archive format（payload 不是 tar） |
| `single/text512k.txt.bz2` | 7zz 26.05 | `7zz x -y -oOUT windows/single/text512k.txt.bz2` | 0 | sha256 OK | 通過 |  |

#### tar 串接格式（`chain/`，payload 是 `corpus/` 整個目錄）

| 檔案 | 工具與版本 | 指令 | exit | 驗證 | 結果 | 錯誤第一行或備註 |
|---|---|---|---|---|---|---|
| `chain/corpus.tar.zst` | zstd 1.5.5 \| GNU tar 1.35 | `zstd -dc windows/chain/corpus.tar.zst \| tar -xf - -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.zst` | GNU tar 1.35 (--zstd) | `tar --zstd -xf windows/chain/corpus.tar.zst -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.zst` | GNU tar 1.35 (自動偵測) | `tar -xf windows/chain/corpus.tar.zst -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.zst` | bsdtar 3.7.2 | `bsdtar -xf windows/chain/corpus.tar.zst -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.zst` | 7zz 26.05 (一步) | `7zz x -y -oOUT windows/chain/corpus.tar.zst` | 0 | 0/9 sha256 OK | 僅解出 .tar | 輸出只有 corpus.tar（1625600 bytes），內容 0/9；另見「兩步」列 |
| `chain/corpus.tar.zst` | 7zz 26.05 (兩步) | `7zz x -y -o"OUT/s1" windows/chain/corpus.tar.zst > /dev/null && 7zz x -y -oOUT OUT/s1/*.tar` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.br` | brotli 1.1.0 \| GNU tar 1.35 | `brotli -dc windows/chain/corpus.tar.br \| tar -xf - -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.br` | GNU tar 1.35 (-I brotli) | `tar -I brotli -xf windows/chain/corpus.tar.br -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.br` | GNU tar 1.35 (自動偵測) | `tar -xf windows/chain/corpus.tar.br -C OUT` | 2 | 0/9 sha256 OK | 不支援 | tar: This does not look like a tar archive |
| `chain/corpus.tar.br` | bsdtar 3.7.2 | `bsdtar -xf windows/chain/corpus.tar.br -C OUT` | 1 | 0/9 sha256 OK | 不支援 | bsdtar: Error opening archive: Unrecognized archive format |
| `chain/corpus.tar.br` | 7zz 26.05 (一步) | `7zz x -y -oOUT windows/chain/corpus.tar.br` | 2 | 0/9 sha256 OK | 不支援 | ERROR: windows/chain/corpus.tar.br -- Cannot open the file as archive |
| `chain/corpus.tar.lz4` | lz4 1.9.4 \| GNU tar 1.35 | `lz4 -dc windows/chain/corpus.tar.lz4 \| tar -xf - -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.lz4` | GNU tar 1.35 (-I lz4) | `tar -I lz4 -xf windows/chain/corpus.tar.lz4 -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.lz4` | GNU tar 1.35 (自動偵測) | `tar -xf windows/chain/corpus.tar.lz4 -C OUT` | 2 | 0/9 sha256 OK | 不支援 | tar: This does not look like a tar archive |
| `chain/corpus.tar.lz4` | bsdtar 3.7.2 | `bsdtar -xf windows/chain/corpus.tar.lz4 -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.lz4` | 7zz 26.05 (一步) | `7zz x -y -oOUT windows/chain/corpus.tar.lz4` | 2 | 0/9 sha256 OK | 不支援 | ERROR: windows/chain/corpus.tar.lz4 -- Cannot open the file as archive |
| `chain/corpus.tar.lz5` | 專用 CLI | `-` | - | 無工具 | 無工具 | 無 apt 套件，依規定不自編 |
| `chain/corpus.tar.lz5` | (附加) zstd 1.5.5 \| GNU tar 1.35 | `zstd -dc windows/chain/corpus.tar.lz5 \| tar -xf - -C OUT` | 2 | 0/9 sha256 OK | 不支援 | zstd: windows/chain/corpus.tar.lz5: unsupported format |
| `chain/corpus.tar.lz5` | (附加) lz4 1.9.4 \| GNU tar 1.35 | `lz4 -dc windows/chain/corpus.tar.lz5 \| tar -xf - -C OUT` | 2 | 0/9 sha256 OK | 不支援 | tar: This does not look like a tar archive |
| `chain/corpus.tar.lz5` | GNU tar 1.35 (自動偵測) | `tar -xf windows/chain/corpus.tar.lz5 -C OUT` | 2 | 0/9 sha256 OK | 不支援 | tar: This does not look like a tar archive |
| `chain/corpus.tar.lz5` | bsdtar 3.7.2 | `bsdtar -xf windows/chain/corpus.tar.lz5 -C OUT` | 1 | 0/9 sha256 OK | 失敗 | bsdtar: Error opening archive: Zstd decompression failed: Unknown frame descriptor |
| `chain/corpus.tar.lz5` | 7zz 26.05 (一步) | `7zz x -y -oOUT windows/chain/corpus.tar.lz5` | 2 | 0/9 sha256 OK | 不支援 | ERROR: windows/chain/corpus.tar.lz5 -- Cannot open the file as archive |
| `chain/corpus.tar.liz` | 專用 CLI | `-` | - | 無工具 | 無工具 | 無 apt 套件，依規定不自編 |
| `chain/corpus.tar.liz` | (附加) zstd 1.5.5 \| GNU tar 1.35 | `zstd -dc windows/chain/corpus.tar.liz \| tar -xf - -C OUT` | 2 | 0/9 sha256 OK | 不支援 | zstd: windows/chain/corpus.tar.liz: unsupported format |
| `chain/corpus.tar.liz` | (附加) lz4 1.9.4 \| GNU tar 1.35 | `lz4 -dc windows/chain/corpus.tar.liz \| tar -xf - -C OUT` | 2 | 0/9 sha256 OK | 不支援 | tar: This does not look like a tar archive |
| `chain/corpus.tar.liz` | GNU tar 1.35 (自動偵測) | `tar -xf windows/chain/corpus.tar.liz -C OUT` | 2 | 0/9 sha256 OK | 不支援 | tar: This does not look like a tar archive |
| `chain/corpus.tar.liz` | bsdtar 3.7.2 | `bsdtar -xf windows/chain/corpus.tar.liz -C OUT` | 1 | 0/9 sha256 OK | 失敗 | bsdtar: Error opening archive: Zstd decompression failed: Unknown frame descriptor |
| `chain/corpus.tar.liz` | 7zz 26.05 (一步) | `7zz x -y -oOUT windows/chain/corpus.tar.liz` | 2 | 0/9 sha256 OK | 不支援 | ERROR: windows/chain/corpus.tar.liz -- Cannot open the file as archive |
| `chain/corpus.tar.gz` | gzip 1.12 \| GNU tar 1.35 | `gzip -dc windows/chain/corpus.tar.gz \| tar -xf - -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.gz` | GNU tar 1.35 (--gzip) | `tar --gzip -xf windows/chain/corpus.tar.gz -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.gz` | GNU tar 1.35 (自動偵測) | `tar -xf windows/chain/corpus.tar.gz -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.gz` | bsdtar 3.7.2 | `bsdtar -xf windows/chain/corpus.tar.gz -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.gz` | 7zz 26.05 (一步) | `7zz x -y -oOUT windows/chain/corpus.tar.gz` | 0 | 0/9 sha256 OK | 僅解出 .tar | 輸出只有 corpus.tar（1625600 bytes），內容 0/9；另見「兩步」列 |
| `chain/corpus.tar.gz` | 7zz 26.05 (兩步) | `7zz x -y -o"OUT/s1" windows/chain/corpus.tar.gz > /dev/null && 7zz x -y -oOUT OUT/s1/*.tar` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.xz` | xz 5.4.5 \| GNU tar 1.35 | `xz -dc windows/chain/corpus.tar.xz \| tar -xf - -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.xz` | GNU tar 1.35 (--xz) | `tar --xz -xf windows/chain/corpus.tar.xz -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.xz` | GNU tar 1.35 (自動偵測) | `tar -xf windows/chain/corpus.tar.xz -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.xz` | bsdtar 3.7.2 | `bsdtar -xf windows/chain/corpus.tar.xz -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.xz` | 7zz 26.05 (一步) | `7zz x -y -oOUT windows/chain/corpus.tar.xz` | 0 | 0/9 sha256 OK | 僅解出 .tar | 輸出只有 corpus.tar（1625600 bytes），內容 0/9；另見「兩步」列 |
| `chain/corpus.tar.xz` | 7zz 26.05 (兩步) | `7zz x -y -o"OUT/s1" windows/chain/corpus.tar.xz > /dev/null && 7zz x -y -oOUT OUT/s1/*.tar` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.bz2` | bzip2 1.0.8 \| GNU tar 1.35 | `bzip2 -dc windows/chain/corpus.tar.bz2 \| tar -xf - -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.bz2` | GNU tar 1.35 (--bzip2) | `tar --bzip2 -xf windows/chain/corpus.tar.bz2 -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.bz2` | GNU tar 1.35 (自動偵測) | `tar -xf windows/chain/corpus.tar.bz2 -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.bz2` | bsdtar 3.7.2 | `bsdtar -xf windows/chain/corpus.tar.bz2 -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `chain/corpus.tar.bz2` | 7zz 26.05 (一步) | `7zz x -y -oOUT windows/chain/corpus.tar.bz2` | 0 | 0/9 sha256 OK | 僅解出 .tar | 輸出只有 corpus.tar（1625600 bytes），內容 0/9；另見「兩步」列 |
| `chain/corpus.tar.bz2` | 7zz 26.05 (兩步) | `7zz x -y -o"OUT/s1" windows/chain/corpus.tar.bz2 > /dev/null && 7zz x -y -oOUT OUT/s1/*.tar` | 0 | 9/9 sha256 OK | 通過 |  |

#### 7z 容器（`7z/`，payload 是 `corpus/` 整個目錄）

| 檔案 | 工具與版本 | 指令 | exit | 驗證 | 結果 | 錯誤第一行或備註 |
|---|---|---|---|---|---|---|
| `7z/corpus-zstd.7z` | 7zz 26.05 (t) | `7zz t windows/7z/corpus-zstd.7z` | 2 | - | 不支援 | ERROR: Unsupported Method : a.txt -- ERROR: Unsupported Method : b-crlf.txt |
| `7z/corpus-zstd.7z` | 7zz 26.05 (x) | `7zz x -y -oOUT windows/7z/corpus-zstd.7z` | 2 | 1/9 sha256 OK | 不支援 | ERROR: Unsupported Method : a.txt -- ERROR: Unsupported Method : b-crlf.txt；只有空檔 empty.txt 的 sha256 相符，等於沒解出內容 |
| `7z/corpus-zstd.7z` | bsdtar 3.7.2 (-tf) | `bsdtar -tf windows/7z/corpus-zstd.7z` | 0 | - | 通過（僅列出或測試） |  |
| `7z/corpus-zstd.7z` | bsdtar 3.7.2 (-xf) | `bsdtar -xf windows/7z/corpus-zstd.7z -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `7z/corpus-brotli.7z` | 7zz 26.05 (t) | `7zz t windows/7z/corpus-brotli.7z` | 2 | - | 不支援 | ERROR: Unsupported Method : a.txt -- ERROR: Unsupported Method : b-crlf.txt |
| `7z/corpus-brotli.7z` | 7zz 26.05 (x) | `7zz x -y -oOUT windows/7z/corpus-brotli.7z` | 2 | 1/9 sha256 OK | 不支援 | ERROR: Unsupported Method : a.txt -- ERROR: Unsupported Method : b-crlf.txt；只有空檔 empty.txt 的 sha256 相符，等於沒解出內容 |
| `7z/corpus-brotli.7z` | bsdtar 3.7.2 (-tf) | `bsdtar -tf windows/7z/corpus-brotli.7z` | 0 | - | 通過（僅列出或測試） |  |
| `7z/corpus-brotli.7z` | bsdtar 3.7.2 (-xf) | `bsdtar -xf windows/7z/corpus-brotli.7z -C OUT` | 1 | 1/9 sha256 OK | 不支援 | a.txt: Unknown codec ID: 4f71102: Unknown error -1；只有空檔 empty.txt 的 sha256 相符，等於沒解出內容 |
| `7z/corpus-lz4.7z` | 7zz 26.05 (t) | `7zz t windows/7z/corpus-lz4.7z` | 2 | - | 不支援 | ERROR: Unsupported Method : a.txt -- ERROR: Unsupported Method : b-crlf.txt |
| `7z/corpus-lz4.7z` | 7zz 26.05 (x) | `7zz x -y -oOUT windows/7z/corpus-lz4.7z` | 2 | 1/9 sha256 OK | 不支援 | ERROR: Unsupported Method : a.txt -- ERROR: Unsupported Method : b-crlf.txt；只有空檔 empty.txt 的 sha256 相符，等於沒解出內容 |
| `7z/corpus-lz4.7z` | bsdtar 3.7.2 (-tf) | `bsdtar -tf windows/7z/corpus-lz4.7z` | 0 | - | 通過（僅列出或測試） |  |
| `7z/corpus-lz4.7z` | bsdtar 3.7.2 (-xf) | `bsdtar -xf windows/7z/corpus-lz4.7z -C OUT` | 1 | 1/9 sha256 OK | 不支援 | a.txt: Unknown codec ID: 4f71104: Unknown error -1；只有空檔 empty.txt 的 sha256 相符，等於沒解出內容 |
| `7z/corpus-lz5.7z` | 7zz 26.05 (t) | `7zz t windows/7z/corpus-lz5.7z` | 2 | - | 不支援 | ERROR: Unsupported Method : a.txt -- ERROR: Unsupported Method : b-crlf.txt |
| `7z/corpus-lz5.7z` | 7zz 26.05 (x) | `7zz x -y -oOUT windows/7z/corpus-lz5.7z` | 2 | 1/9 sha256 OK | 不支援 | ERROR: Unsupported Method : a.txt -- ERROR: Unsupported Method : b-crlf.txt；只有空檔 empty.txt 的 sha256 相符，等於沒解出內容 |
| `7z/corpus-lz5.7z` | bsdtar 3.7.2 (-tf) | `bsdtar -tf windows/7z/corpus-lz5.7z` | 0 | - | 通過（僅列出或測試） |  |
| `7z/corpus-lz5.7z` | bsdtar 3.7.2 (-xf) | `bsdtar -xf windows/7z/corpus-lz5.7z -C OUT` | 1 | 1/9 sha256 OK | 不支援 | a.txt: Unknown codec ID: 4f71105: Unknown error -1；只有空檔 empty.txt 的 sha256 相符，等於沒解出內容 |
| `7z/corpus-lizard.7z` | 7zz 26.05 (t) | `7zz t windows/7z/corpus-lizard.7z` | 2 | - | 不支援 | ERROR: Unsupported Method : a.txt -- ERROR: Unsupported Method : b-crlf.txt |
| `7z/corpus-lizard.7z` | 7zz 26.05 (x) | `7zz x -y -oOUT windows/7z/corpus-lizard.7z` | 2 | 1/9 sha256 OK | 不支援 | ERROR: Unsupported Method : a.txt -- ERROR: Unsupported Method : b-crlf.txt；只有空檔 empty.txt 的 sha256 相符，等於沒解出內容 |
| `7z/corpus-lizard.7z` | bsdtar 3.7.2 (-tf) | `bsdtar -tf windows/7z/corpus-lizard.7z` | 0 | - | 通過（僅列出或測試） |  |
| `7z/corpus-lizard.7z` | bsdtar 3.7.2 (-xf) | `bsdtar -xf windows/7z/corpus-lizard.7z -C OUT` | 1 | 1/9 sha256 OK | 不支援 | a.txt: Unknown codec ID: 4f71106: Unknown error -1；只有空檔 empty.txt 的 sha256 相符，等於沒解出內容 |
| `7z/corpus-flzma2.7z` | 7zz 26.05 (t) | `7zz t windows/7z/corpus-flzma2.7z` | 0 | - | 通過（僅列出或測試） |  |
| `7z/corpus-flzma2.7z` | 7zz 26.05 (x) | `7zz x -y -oOUT windows/7z/corpus-flzma2.7z` | 0 | 9/9 sha256 OK | 通過 |  |
| `7z/corpus-flzma2.7z` | bsdtar 3.7.2 (-tf) | `bsdtar -tf windows/7z/corpus-flzma2.7z` | 0 | - | 通過（僅列出或測試） |  |
| `7z/corpus-flzma2.7z` | bsdtar 3.7.2 (-xf) | `bsdtar -xf windows/7z/corpus-flzma2.7z -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `7z/corpus-lzma2.7z` | 7zz 26.05 (t) | `7zz t windows/7z/corpus-lzma2.7z` | 0 | - | 通過（僅列出或測試） |  |
| `7z/corpus-lzma2.7z` | 7zz 26.05 (x) | `7zz x -y -oOUT windows/7z/corpus-lzma2.7z` | 0 | 9/9 sha256 OK | 通過 |  |
| `7z/corpus-lzma2.7z` | bsdtar 3.7.2 (-tf) | `bsdtar -tf windows/7z/corpus-lzma2.7z` | 0 | - | 通過（僅列出或測試） |  |
| `7z/corpus-lzma2.7z` | bsdtar 3.7.2 (-xf) | `bsdtar -xf windows/7z/corpus-lzma2.7z -C OUT` | 0 | 9/9 sha256 OK | 通過 |  |
| `7z/corpus-zstd-mt4.7z` | 7zz 26.05 (t) | `7zz t windows/7z/corpus-zstd-mt4.7z` | 2 | - | 不支援 | ERROR: Unsupported Method : a.txt -- ERROR: Unsupported Method : b-crlf.txt |
| `7z/corpus-brotli-mt4.7z` | 7zz 26.05 (t) | `7zz t windows/7z/corpus-brotli-mt4.7z` | 2 | - | 不支援 | ERROR: Unsupported Method : a.txt -- ERROR: Unsupported Method : b-crlf.txt |

`corpus-zstd-mt4.7z` 與 `corpus-brotli-mt4.7z` 各只跑一次 `7zz t`（上表末兩列）：兩個檔與對應的非 mt4 檔**位元組相同**（sha256 分別為 `303c66b96314792c4eb834c72e571f78cfc12dce5ec7fb7b53cd003bf9c6e8a8` 與 `db267bc35be50f2e8f92b051355104c18732e48812d814ba33987aa57de5dc0a`，核對結果見第 4 節的檔頭核對表），結果與非 mt4 檔相同，不再另跑其他工具。

`7zz l -slt` 看到的 Method 欄位（每個檔 10 個資料項）：zstd 為 `04F71101`、brotli 為 `04F71102`、lz4 為 `04F71104`、lz5 為 `04F71105`、lizard 為 `04F71106`，flzma2 與 lzma2 兩個檔都是 `LZMA2:21`。

### 對照附錄的預期矩陣

下表把事前的預期矩陣逐格對上實測。「相符」表示預期寫「可讀」或「預期失敗」而實測一致；「已確認」表示預期是「未確認」，現在有實測結果。**預期寫得明確的格子，實測沒有任何一格與預期相反。**

| 產物 | GNU tar 1.35 | bsdtar 3.7.2 | 7zz 26.05 | 專用 CLI |
|---|---|---|---|---|
| `.zst` 標準 frame | 不適用 | 不適用 | 通過（相符） | zstd 通過（相符） |
| `.tar.zst` | `--zstd` 與自動偵測都通過（相符） | 通過（相符） | 兩步通過（相符）；一步只解出 `.tar`（已確認） | zstd 通過（相符） |
| `.br`、`.tar.br`（標準串流） | `-I brotli` 通過（已確認）；自動偵測失敗 | 不支援（相符） | 不支援（相符） | brotli 通過（相符） |
| `.lz4`、`.tar.lz4` 裸 frame | `-I lz4` 通過（已確認）；自動偵測失敗 | 通過（相符，僅 `.tar.lz4` 可測） | 不支援（相符） | lz4 通過（相符） |
| lz4 的 skippable 容器（`-mmt>1`） | 未測 | 未測 | 未測 | 未測。Windows 端 `.lz4` 全是裸 frame（開頭 `04 22 4D 18`），沒有這種向量 |
| `.lz5`、`.liz`、`.tar.lz5`、`.tar.liz` | 不支援（相符） | 失敗，訊息誤導（見第 4 節） | 不支援（相符） | 無工具 |
| `.7z` 內 ZSTD | 不適用 | **通過**（已確認） | 不支援（相符） | 不適用 |
| `.7z` 內 BROTLI、LZ4、LZ5、LIZARD | 不適用 | `-tf` 能列檔，`-xf` 不支援（已確認） | 不支援（相符） | 不適用 |
| `.7z` 內 FLZMA2 | 不適用 | 通過（已確認） | 通過（已確認） | 不適用 |
| `.gz`、`.xz`、`.bz2`、`.tar.*` 基準 | 通過（相符） | 通過（相符） | 單檔通過；tar 鏈兩步通過（相符） | 通過（相符） |


## 4. 發現

狀態：完成（issue C、D、E）。C 的差異與觀察在本節；D 的產生過程中的觀察在第 5 節；彙整時沒有再發現新項目。

### 檔頭核對：25 個檔全部與 MANIFEST 一致

腳本 `scripts/check_headers.sh` 逐檔比對 `MANIFEST.md` 的位元組數、sha256 與前 16 bytes，**25 筆全部相符，沒有不一致**。

| 檔案 | 位元組數 | sha256 | 前 16 bytes | 實際前 16 bytes |
|---|---|---|---|---|
| `single/text512k.txt.zst` | OK | OK | OK | `28 B5 2F FD A0 05 00 08 00 54 E2 02 CA D2 5C 1C` |
| `single/text512k.txt.br` | OK | OK | OK | `AF FF DF 00 00 20 52 CD FE CB 7F 12 29 08 79 34` |
| `single/text512k.txt.lz4` | OK | OK | OK | `04 22 4D 18 4C 40 05 00 08 00 00 00 00 00 2F A0` |
| `single/text512k.txt.lz5` | OK | OK | OK | `50 2A 4D 18 04 00 00 00 72 8A 02 00 05 22 4D 18` |
| `single/text512k.txt.liz` | OK | OK | OK | `50 2A 4D 18 04 00 00 00 B2 E7 02 00 06 22 4D 18` |
| `single/text512k.txt.xz` | OK | OK | OK | `FD 37 7A 58 5A 00 00 01 69 22 DE 36 02 00 21 01` |
| `single/text512k.txt.gz` | OK | OK | OK | `1F 8B 08 08 A9 13 EA 6A 04 00 74 65 78 74 35 31` |
| `single/text512k.txt.bz2` | OK | OK | OK | `42 5A 68 39 31 41 59 26 53 59 3D DB 7B B0 02 7D` |
| `chain/corpus.tar.zst` | OK | OK | OK | `28 B5 2F FD 00 60 BC 91 04 7E EB C4 4B 13 2E 10` |
| `chain/corpus.tar.br` | OK | OK | OK | `8F FF 5F 00 60 80 EC 36 92 B1 92 B1 A2 EC 8C F0` |
| `chain/corpus.tar.lz4` | OK | OK | OK | `04 22 4D 18 4C 40 00 CE 18 00 00 00 00 00 0B F7` |
| `chain/corpus.tar.lz5` | OK | OK | OK | `50 2A 4D 18 04 00 00 00 27 FE 02 00 05 22 4D 18` |
| `chain/corpus.tar.liz` | OK | OK | OK | `50 2A 4D 18 04 00 00 00 9E 60 03 00 06 22 4D 18` |
| `chain/corpus.tar.gz` | OK | OK | OK | `1F 8B 08 00 00 00 00 00 00 FF EC 5C 07 38 95 FF` |
| `chain/corpus.tar.xz` | OK | OK | OK | `FD 37 7A 58 5A 00 00 01 69 22 DE 36 02 00 21 01` |
| `chain/corpus.tar.bz2` | OK | OK | OK | `42 5A 68 39 31 41 59 26 53 59 9B F2 43 25 01 33` |
| `7z/corpus-zstd.7z` | OK | OK | OK | `37 7A BC AF 27 1C 00 04 AC 98 B9 9E EF C3 01 00` |
| `7z/corpus-brotli.7z` | OK | OK | OK | `37 7A BC AF 27 1C 00 04 5D 3C FF BD CE 13 02 00` |
| `7z/corpus-lz4.7z` | OK | OK | OK | `37 7A BC AF 27 1C 00 04 8A BD 8D BB 35 5F 02 00` |
| `7z/corpus-lz5.7z` | OK | OK | OK | `37 7A BC AF 27 1C 00 04 F0 D7 A5 43 98 FC 02 00` |
| `7z/corpus-lizard.7z` | OK | OK | OK | `37 7A BC AF 27 1C 00 04 25 F0 0B B1 87 4D 03 00` |
| `7z/corpus-flzma2.7z` | OK | OK | OK | `37 7A BC AF 27 1C 00 04 AD 77 57 D6 A9 83 01 00` |
| `7z/corpus-lzma2.7z` | OK | OK | OK | `37 7A BC AF 27 1C 00 04 03 07 5A 55 B4 78 01 00` |
| `7z/corpus-zstd-mt4.7z` | OK | OK | OK | `37 7A BC AF 27 1C 00 04 AC 98 B9 9E EF C3 01 00` |
| `7z/corpus-brotli-mt4.7z` | OK | OK | OK | `37 7A BC AF 27 1C 00 04 5D 3C FF BD CE 13 02 00` |

### 預期與實測的差異

附錄矩陣裡預期寫得明確的格子（「可讀」或「預期失敗」），**實測沒有任何一格與預期相反**。差異都在預期寫「未確認」的格子，現在有了實測結果：

1. **bsdtar 能解 `.7z` 內的 ZSTD。** `bsdtar -xf windows/7z/corpus-zstd.7z` exit 0，解出內容 9/9 sha256 相符。7zz 對同一個檔回 `ERROR: Unsupported Method : a.txt`，`7zz l -slt` 顯示 Method 為 `04F71101`。
2. **bsdtar 對 BROTLI、LZ4、LZ5、LIZARD 的 `.7z`：能列檔，不能解出。** `bsdtar -tf` exit 0，列出 13 個項目。`bsdtar -xf` exit 1，訊息分別是 `a.txt: Unknown codec ID: 4f71102`（brotli）、`4f71104`（lz4）、`4f71105`（lz5）、`4f71106`（lizard），後面都接 `Unknown error -1`。
3. **FLZMA2 的 `.7z` 能被 7zz 與 bsdtar 讀。** 兩者都 9/9 通過。`7zz l -slt` 顯示的 Method 是 `LZMA2:21`，與 `corpus-lzma2.7z` 完全相同，7z 檔內沒有任何欄位區分這兩者。
4. **7zz 不會一步解出 `.tar.zst` 的內容。** 一步只輸出 `corpus.tar`（1625600 bytes），內容 0/9。再對 `corpus.tar` 解第二步後 9/9 通過。`.tar.gz`、`.tar.xz`、`.tar.bz2` 的行為完全相同，所以這是官方 7zz 一貫的行為，不是 zstd 專屬的缺陷。
5. **GNU tar 的 `-I brotli` 與 `-I lz4` 都能解。** `.tar.br` 與 `.tar.lz4` 各 9/9 通過。但自動偵測的 `tar -xf` 兩者都失敗（exit 2，`tar: This does not look like a tar archive`），因為 GNU tar 不認這兩種格式。
6. **bsdtar 讀 `.tar.lz4` 通過，讀 `.tar.br` 不支援。** 後者訊息是 `Unrecognized archive format`，與附錄相符。

### 其他觀察

7. **bsdtar 把 LZ5 與 Lizard 容器當成 zstd。** `bsdtar -xf` 對 `.lz5`、`.liz`、`.tar.lz5`、`.tar.liz` 全部 exit 1，訊息是 `Zstd decompression failed: Unknown frame descriptor`，不是「格式不明」。這與附錄記載的 libarchive 行為一致：zstd 偵測接受開頭的 skippable frame（這兩種容器都以 `50 2A 4D 18` 開頭）。同一批檔，zstd CLI 回 `unsupported format`，7zz 回 `Cannot open the file as archive`，GNU tar 回 `This does not look like a tar archive`。結論仍是「讀不了」，與預期相符，只是 bsdtar 的訊息會誤導。
8. **`lz4` CLI 對 LZ5 與 Lizard 容器的行為不一致。** `lz4 -t` exit 1，訊息是 `Stream followed by undecodable data at position 16`。`lz4 -dc 檔 > 輸出` 同樣 exit 1，但**沒有任何錯誤訊息**，輸出是 0 bytes。以 `-dc` 驗證時必須看 exit code，不能只看有沒有訊息。
9. **Windows 端 zstd 幀的屬性**（`7zz x` 印出的 Method 行）。`text512k.txt.zst`：single-segment，帶 content size 524293，沒有 xxh64 checksum（`NO-XXH64`）。`corpus.tar.zst`：串流式，`unknown-content-size`，window 最大 4 MiB（log 22），同樣沒有 xxh64 checksum。這些幀 zstd 1.5.5、GNU tar、bsdtar、7zz 都能解。
10. **單檔格式用 GNU tar 或 bsdtar 讀一律失敗，屬於不適用。** payload 是純文字不是 tar：GNU tar 回 `This does not look like a tar archive`（exit 2），bsdtar 回 `Unrecognized archive format`（exit 1，LZ5 與 Lizard 例外，見第 7 點）。共 16 格，不是缺陷。
11. **7zz 讀單檔：** `.zst`、`.xz`、`.gz`、`.bz2` 通過。`.br`、`.lz4`、`.lz5`、`.liz` 回 `Cannot open the file as archive`（exit 2）。
12. **lz4 的 skippable 容器沒有向量可測。** Windows 端所有 `.lz4` 都是裸 frame（開頭 `04 22 4D 18`），附錄矩陣「同上但 skippable 容器（`-mmt>1`）」那一列沒有檔可測，記「未測（無向量）」。
13. **`-mt4` 的 7z 與非 mt4 的位元組相同。** 兩組 sha256 相同（見上表），所以只各跑一次 `7zz t`，結果與非 mt4 檔相同。
14. **gcc 建置（B）的差異**見第 2 節：受影響的 handler 是 6 個而不是 3 個，產物目錄是 `_o/` 而不是 `b/g/`。
15. **Windows 端 `.lz4` 的標頭。** `single/text512k.txt.lz4` 與 `chain/corpus.tar.lz4` 的 FLG 都是 `0x4C`、BD 都是 `0x40`：區塊相依（linked）、帶 content size、帶 content checksum、區塊 64 KiB。這種 frame lz4 1.9.4 與 bsdtar 都解得開（見第 3 節矩陣）。反方向（Linux 產的區塊獨立、區塊 checksum、legacy）見第 5 節與 `linux/MANIFEST.md`。

## 5. Linux 向量

狀態：完成（issue D）。

完整清單在 `linux/MANIFEST.md`，每個檔一列：產生指令、位元組數、sha256、前 16 bytes、解回驗證指令與結果。傳輸核對用 `linux/SHA256SUMS`（37 行，`sha256sum -c` 全部 OK）。產生腳本是 `scripts/make_linux_vectors.sh`。

- 共 37 個向量，合計 4076124 bytes（約 3.9 MiB），低於 10 MB 上限。
- 每個向量都用**寫出它的同一個工具**解回來，sha256 全數相符才列入。沒有任何一個因驗證失敗被排除。

| 目錄 | 個數 | 內容 |
|---|---|---|
| `tar/` | 8 | GNU tar 與 bsdtar 的 `.tar.zst`（GNU 與 pax 兩種方言各有）、bsdtar 的 `.tar.lz4`、3 個 sparse 檔 |
| `zstd/` | 6 | `-19`、`-T0 --long=31`（檔案輸入與 stdin 輸入各一）、`--no-check`、`--no-content-size`、stdin 輸入 |
| `zstd-frames/` | 3 | 兩個 frame 串接、skippable frame 在最前面、skippable frame 夾在中間 |
| `brotli/` | 10 | `-q` 與 `-w` 的 8 種組合、`tar` 串流的 `.tar.br`、`--large_window=30` |
| `lz4/` | 10 | `-B4`、`-B7`、`-BD`、`-BX`、`--no-frame-crc`、`--content-size`、`-l`、`-B4 -BD`、兩檔串接、`zstd --format=lz4` |

### 未產生的項目

| 項目 | 原因 |
|---|---|
| lz5 向量 | Ubuntu 24.04 沒有 lz5 套件，依規定不從原始碼編譯 |
| lizard 向量 | Ubuntu 24.04 沒有 lizard 套件，依規定不從原始碼編譯 |

原定清單中其餘項目都已產生：`zstd --format=lz4` 該 build 支援，`--large_window=30` 該 brotli 有此選項。

### 與原定清單不同，或值得注意的事實

1. **多產了幾個清單外的向量。** `zstd-T0-long31-stdin`、`lz4-B4-BD`、`tar/corpus.gnutar-pax`、`tar/corpus.bsdtar-gnutar`、`tar/sparse.gnutar-sparse-pax`、`tar/sparse.bsdtar-default`。理由在後面各點。
2. **`--long=31` 對檔案輸入沒有效果。** `zstd -T0 --long=31` 讀檔案時，frame 的視窗被收斂成 512 KiB（`zstd -lv`：`Window Size: 512 KiB`）。只有 stdin 輸入才真的寫入 2 GiB 視窗，所以另外多做了 stdin 版。這一個 stdin 版用預設設定的 `zstd -d` 解不開：exit 1，`Window size larger than maximum : 2147483648 > 134217728`，必須加 `--long=31`。
3. **`lz4 -BD` 與 `-B7` 的產出位元組完全相同。** 輸入是 524293 bytes，小於 1 MiB，所以只有一個區塊。標頭顯示最大區塊是 1 MiB（`-B7` 要求的是 4 MiB），而且 FLG 的區塊獨立位元仍為 1（`-BD` 要求的是區塊相依）。為了有一個真正的「區塊相依」向量，多做了 `-B4 -BD`（64 KiB 區塊，FLG 的獨立位元為 0）。
4. **brotli 在 `-q 0` 時不理會 `-w 10`。** `brotli -q 0 -w 10` 的檔頭解出 WBITS=18。其餘組合的 WBITS 都與 `-w` 相同（`-q 5 -w 16` 與 `-q 11 -w 16` 為 16，`-w 22` 為 22，`-w 24` 為 24，`-q 11 -w 10` 為 10）。
5. **`--large_window=30` 的產物，不加旗標的 `brotli -d` 也解得開。** 檔頭首位元組是 `0x11`（大視窗位元流），WBITS=30，但 brotli 1.1.0 的 CLI 在沒有 `--large_window` 時照樣解碼成功，exit 0，sha256 相符。所以事前預期的「一般解碼器失敗」，對這個 Linux CLI 不成立。7-ZSTar 讀不讀得了仍需在 Windows 端驗證。
6. **bsdtar 預設就會寫 sparse 條目。** 對同一個稀疏檔，bsdtar 寫的第一個標頭 type 是 `x`（pax extended header），含 4 個 `GNU.sparse` 鍵；GNU tar 的 `--format=gnu` 寫 type `S`；GNU tar 的 `--format=pax` 寫 4 個 `GNU.sparse` 鍵。三種編碼都解得回來，所以三個都收。
7. **`zstd --format=lz4` 可用。** 它寫出的 frame 前 16 bytes 與 Windows 端 `single/text512k.txt.lz4` 完全相同（FLG=0x4C、BD=0x40）。

## 6. 未完成與原因

狀態：完成（issue E）。下表列出所有沒做或沒做完的項目，每項寫明試過什麼。

| 項目 | 結果 | 試過什麼與原因 |
|---|---|---|
| lz5、lizard 的 Linux 工具 | 無套件 | 試過 `apt-cache search -n lz5`、`apt-cache search -n lizard`、`apt-cache policy lz5 liblz5-1 liblz5-dev lizard liblizard-dev`。只找到 `cl-agnostic-lizard`（Common Lisp 程式碼走訪器，與壓縮無關）。依規定不從原始碼編譯。影響：第 3 節矩陣的 lz5、liz 專用 CLI 共 4 格記「無工具」；第 5 節沒有 lz5、lizard 向量 |
| gcc 版 `7zz` 的執行結果 | 未測 | 連結失敗，沒有執行檔，所以 `7zz i` 與 `7zz t windows/chain/corpus.tar.zst` 無從執行 |
| gcc 下 4 個未列入檔案能否編譯、補清單後能否連結 | 未測 | 依規定不修 makefile、不手動補 obj 清單，所以沒有嘗試 |
| lz4 的 skippable 容器（`-mmt>1`） | 未測 | Windows 端沒有產出這種向量，所有 `.lz4` 都是裸 frame |
| 7-ZSTar 讀 Linux 向量 | 未驗證 | 7-ZSTar 只能在 Windows 執行，這需在 Windows 端驗證，見第 7 節 |

其他需要交代的事：

- **網路與權限沒有擋任何項目。** `apt-get` 與 GitHub 下載（`7z2605-linux-x64.tar.xz`）都一次成功，備援網址沒用到。沒有逾時，每個步驟都遠少於 60 分鐘。
- **多裝了 `xxd`。** 系統沒有 `xxd`，用 `apt-get install xxd` 補上，版本記在第 1 節。

## 7. 給 Windows 端的提醒

狀態：完成（issue E）。7-ZSTar 無法在 Linux 執行，所以下面關於 7-ZSTar 的部分都是「請在 Windows 端驗證」，不是結論。「依據」欄標明來源：**實測**是本報告的 Linux 輸出，**預期**是事前寫下的預期。

### 7.1 值得先看的 Linux 向量

| 向量（在 `linux/` 底下） | 為什麼值得盯 | 依據 |
|---|---|---|
| `brotli/brotli-q5-large-window30.text512k.txt.br` | 大視窗位元流（首位元組 `0x11`，WBITS=30），不是 RFC 7932 標準格式。事前預期 7-ZSTar 讀不了，要看的是失敗時錯誤是否乾淨、有沒有留下半成品 | 預期；實測：Linux 的 brotli 1.1.0 不加旗標也解得開，exit 0 |
| `lz4/lz4-legacy.text512k.txt.lz4` | 開頭 `02 21 4C 18`（legacy frame）。事前預期被拒，要看錯誤是否乾淨 | 預期；實測：`lz4 -t` exit 0 |
| `zstd/zstd-T0-long31-stdin.text512k.txt.zst` | frame 宣告 2 GiB 視窗且沒有 content size。7-ZSTar 解碼端有沒有視窗上限，事前標為未確認，請記錄通過、拒絕或記憶體不足 | 實測：zstd 1.5.5 預設上限 128 MiB，不加 `--long=31` 會拒絕並 exit 1 |
| `zstd-frames/skippable-before.a.zst` | 檔頭就是 `50 2A 4D 18`，與 Windows 端 `.lz5`、`.liz` 的 mcmilk 容器是同一個魔數，但這個 skippable frame 的內容長度是 16，容器的長度欄是 4。請記錄 7-ZSTar 把它當 zstd 還是當容器 | 實測（魔數與長度）；對應 skippable frame 的 header 處理 |
| `zstd-frames/skippable-between.a-b.zst` | skippable frame 夾在兩個 frame 中間。解碼後必須是 `a.txt` 接 `b-crlf.txt` | 實測：`zstd -d` 解出該結果 |
| `zstd-frames/concat.a-then-b.zst`、`lz4/concat.a-then-b.lz4` | 多 frame 串接。單檔 handler 是不是解完全部 frame，而不是只解第一個，請核對輸出長度 | 實測：兩者解碼後都是 `a.txt` 接 `b-crlf.txt` |
| `lz4/lz4-BX.*`、`lz4/lz4-no-frame-crc.*`、`lz4/lz4-B4-BD.*`、`lz4/lz4-content-size.*`、`lz4/lz4-B4.*` | 標頭選項變因。Windows 端兩個 `.lz4` 的 FLG 都是 `0x4C`（區塊相依、有 content size、有 content checksum、64 KiB），沒有出現過「區塊 checksum」與「無 content checksum」這兩種組合 | 實測：FLG 與 BD 值見 `linux/MANIFEST.md` 備註欄 |
| `tar/sparse.gnutar-sparse-gnu.tar.zst`、`tar/sparse.gnutar-sparse-pax.tar.zst`、`tar/sparse.bsdtar-default.tar.zst` | 三種 sparse 編碼：GNU 舊式 type `S`、兩種 pax `GNU.sparse` 鍵。解出的 `sparse.bin` 必須是 4194304 bytes，sha256 見 `linux/MANIFEST.md` | 實測；7-ZSTar 的 tar 層是否展開 sparse 未驗證 |
| `tar/corpus.gnutar-gnu.tar.zst`、`tar/corpus.bsdtar-gnutar.tar.zst`（GNU `@LongLink`）；`tar/corpus.gnutar-pax.tar.zst`、`tar/corpus.bsdtar-default.tar.zst`（pax 標頭） | 長檔名（超過 100 字元）與繁中檔名的兩種存法。這是 tar 層的變因，與壓縮層無關。失敗時請先把 `.tar` 解出來，分清是哪一層 | 實測：標頭種類見備註欄 |

其餘向量（`zstd/` 其他檔、`brotli/` 的 `-q` 與 `-w` 組合與 `corpus.gnutar.tar.br`、`tar/corpus.bsdtar-default.tar.lz4`、`lz4/zstd-format-lz4.*`）沒有已知風險。`zstd-format-lz4` 的前 16 bytes 與 Windows 端 `single/text512k.txt.lz4` 完全相同。這幾個若失敗，就是互通缺陷，請原樣回報。

lz5 與 lizard 沒有 Linux 向量（無套件），所以 Linux 到 Windows 方向這兩種格式沒有覆蓋。

### 7.2 Windows 產物在 Linux 上的可讀性（第 3 節的結論）

- **`.zst`、`.tar.zst`**：zstd、GNU tar（`--zstd` 與自動偵測）、bsdtar 都能讀。官方 7zz 能解 `.zst`，但 `.tar.zst` 要分兩步（一步只解出 `.tar`）。
- **`.br`、`.tar.br`**：brotli CLI 能讀。`.tar.br` 要用 `tar -I brotli` 或 `brotli -dc | tar -x`。GNU tar 自動偵測、bsdtar、官方 7zz 都不能。
- **`.lz4`、`.tar.lz4`**：lz4 CLI、`tar -I lz4`、bsdtar 能讀。GNU tar 自動偵測與官方 7zz 不能。
- **`.lz5`、`.liz`、`.tar.lz5`、`.tar.liz`**：Linux 上沒有已知工具能讀。bsdtar 的錯誤訊息會誤導成 `Zstd decompression failed`。
- **`.7z`**：內含 ZSTD 的，bsdtar 3.7.2 能解，官方 7zz 不能（`Unsupported Method`，Method `04F71101`）。內含 BROTLI、LZ4、LZ5、LIZARD 的，兩者都不能（bsdtar 能列檔但解不出）。內含 FLZMA2 的，兩者都能解；7zz 看到的 Method 是 `LZMA2:21`，與 lzma2 對照檔相同。
- **gcc 建置**：fork 在 Linux 連結失敗（第 2 節）。這是需要決策的事，不是在 Windows 端補測就能解決的事。

### 7.3 回報方式

請照 `linux/MANIFEST.md` 的備註欄逐檔核對：單檔比對解碼後的 sha256，tar 類比對 `corpus/SHA256SUMS`（9 行全 OK），sparse 比對 4194304 bytes 與 sha256。失敗或預期失敗的向量，請記 7-ZSTar 的指令、exit code 與錯誤第一行，預期失敗者特別記錄錯誤是否乾淨。

## 8. Linux → Windows（Windows 端補寫，2026-11-04）

狀態：完成（issue F）。工具：`build/Test-Interop.ps1`（新檔）對 `linux/MANIFEST.md` 的 37 個向量各跑 `7z l`／`7z t`／`7z x`，解出內容對 `corpus/SHA256SUMS`（含 `SHA256SUMS` 本身，因為 Linux 的 tar 是用 `*` 打包）或 MANIFEST 備註的 payload sha256。執行檔：本樹 x64 建置的 `7z.exe`（`CPP/7zip/UI/Console/x64`）。

### 統計

| 結果 | 數 | 向量 |
|---|---|---|
| PASS | 32 | zstd 6、zstd-frames 3、brotli 10（含 `--large_window=30`，見發現 2）、lz4 9、tar 4（GNU tar gnu／pax、bsdtar gnutar、GNU 舊式 sparse） |
| REJECTED-CLEAN（預期被拒，錯誤乾淨） | 1 | `lz4/lz4-legacy.text512k.txt.lz4`：`7z l`／`t`／`x` 皆 exit 2，`Open ERROR: Cannot open the file as [lz4] archive`，無 Unspecified |
| UPSTREAM-LIMIT（上游同樣行為） | 4 | `tar/corpus.bsdtar-default.tar.zst`、`tar/corpus.bsdtar-default.tar.lz4`、`tar/sparse.gnutar-sparse-pax.tar.zst`、`tar/sparse.bsdtar-default.tar.zst` |
| FAIL | 0 | — |

### 發現

1. **pax 格式的 GNU sparse 1.0 條目不展開。** bsdtar 預設（pax）與 GNU tar `--format=pax --sparse` 寫出的稀疏檔，7-ZSTar 解成 `GNUSparseFile.<n>/<name>`、內容是壓實後的資料（`zeros.bin` 4608 bytes、`sparse.bin` 12800 bytes），不是展開後的 1 MiB／4 MiB。**官方 7-Zip 26.05 的 `7z.exe`對同一個內層 `.tar` 的輸出完全相同**（`GNUSparseFile.0\zeros.bin` 4608、`GNUSparseFile.16794\sparse.bin` 12800），GNU 舊式 sparse（type `S`）兩邊都正確展開 4194304 bytes。判定：上游 tar handler 的限制，fork 未改變；`Test-Interop.ps1` 歸為 `UPSTREAM-LIMIT`。附帶：Linux VM 上 bsdtar 把全零的 `zeros.bin` 當稀疏檔寫（pax header 3 個其中之一），所以連一般語料也受影響。
2. **brotli 大視窗（`--large_window=30`）可解。** 事前預期一般解碼器讀不了，7-ZSTar 的 brotli 解碼端實際接受 WBITS=30，sha256 相符；與 Linux 端觀察「不加旗標的 `brotli -d` 也解得開」一致。第一次跑時它被列為「預期拒絕」而得到 UNEXPECTED-OK；既然實測能解，`Test-Interop.ps1` 改以實測為基準——這個向量**必須**解得開，日後拒絕就是退化（FAIL）。
3. **zstd 2 GiB 視窗（stdin `--long=31`）可解**，`7z t`／`x` exit 0，sha256 相符；Linux 端 `zstd -d` 不加 `--long=31` 反而拒絕。多 frame 串接、開頭與中間的手工 skippable frame 都正確。
4. **lz4**：`-B4`～`-B7`、`-BD`、`-BX`、`--no-frame-crc`、`--content-size`、串接、`zstd --format=lz4` 全通過；legacy frame（magic `02 21 4C 18`）被乾淨拒絕（`Cannot open the file as archive`），與預期一致。
5. **tar 層**：長檔名（GNU `@LongLink` 與 pax `path`）、繁中檔名、空檔、`SHA256SUMS` 在 GNU／pax／bsdtar 三種方言下都正確解出。
6. 一步串聯：所有 `.tar.zst`／`.tar.lz4`／`.tar.br` 都是 `7z x` 一步解出成員，沒有出現先解出 `.tar` 的兩段式。

### 給 README／決策的結論

- Windows → Linux：7-ZSTar 的 `.zst`／`.tar.zst`、`.lz4`／`.tar.lz4`（裸 frame）、`.br`／`.tar.br` 能被對應的 Linux CLI 讀；GNU tar 要 `-I lz4`／`-I brotli`；bsdtar 讀 zstd／lz4 不讀 brotli；官方 7zz 讀 `.zst` 與 `.7z` 內 FLZMA2，不讀 `.7z` 內 ZSTD／BROTLI／LZ4／LZ5／LIZARD；`.lz5`／`.liz` 與多執行緒容器只有 7-ZSTar 自己讀得了。
- Linux → Windows：Linux 工具產的 zstd／brotli／lz4／tar 向量 7-ZSTar 全部讀得了（lz4 legacy 除外，乾淨拒絕）；唯一限制是 pax GNU sparse 1.0 不展開，且與官方 7-Zip 相同。

### 腳本已知限制（code review 列出，刻意不改——它們是已執行過的證據腳本，Windows 端無 Linux 無法重跑驗證）

- `scripts/run_matrix.sh`：`<work-dir>` 非空時不會拒絕，舊的 `cellN/` 殘留可能讓驗證誤報通過；`<interop-dir>` 傳相對路徑時 `sha256sum -c` 讀不到 `SHA256SUMS`（誤報失敗，不會誤報通過）。重跑時用空目錄與絕對路徑。
- `scripts/check_headers.sh`：發現不符時 exit code 仍為 0，以 TSV 內容為準。
- `scripts/make_linux_vectors.sh`、`run_matrix.sh`：`mktemp -d` 的暫存目錄不清理。
