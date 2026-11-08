# Linux gcc 移植：G4 驗證報告

> 2026-11-04 移植時的驗證紀錄；指令與數字對應當時的原始碼。

日期：2026-11-04（UTC）。階段：G4（驗證）。
本檔所有結果都是實跑輸出；表格由 `build/linux/interop-check.sh`、`build/linux/test-smoke.sh` 直接產生再貼入，沒有手抄。重跑方式：

```bash
cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc   # 先建置
build/linux/test-smoke.sh                       # smoke，exit 0 才算過
build/linux/interop-check.sh all                # 25 + 37 + apt 互解，exit 0 才算過
INTEROP_LOG_DIR=<已存在的目錄> build/linux/interop-check.sh all   # 另存每個檔的 7zz l/t/x 原始輸出
```

## 環境

| 項目 | 值 |
|---|---|
| OS | `lsb_release -ds`：Ubuntu 24.04.5 LTS |
| 核心／架構 | `uname -a`：`Linux vm 6.18.44-fc-v233 #1 SMP PREEMPT_DYNAMIC @0 x86_64 x86_64 x86_64 GNU/Linux` |
| CPU 數 | `nproc` = 4 |
| 編譯器 | `gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0`；`g++` 同版；GNU ld 2.42；GNU Make 4.3 |
| locale | 測試時 `C.UTF-8`（`interop-check.sh` 自行設定；`7zz i` 顯示 `locale=C.UTF-8`） |
| perl | 5.38.2（`test-smoke.sh` 用來產生固定種子的 `random.bin`；沒有 perl 時退回 `/dev/urandom`） |
| apt 驗證工具 | zstd 1.5.5（`1.5.5+dfsg2-2build1.1`）、brotli 1.1.0（`1.1.0-2ubuntu0.1`）、lz4 1.9.4（`1.9.4-1build1.1`）、GNU tar 1.35、bsdtar 3.7.2（libarchive 3.7.2，zlib 1.3、liblzma 5.4.5、bz2lib 1.0.8、liblz4 1.9.4、libzstd 1.5.5） |
| 取得工具的方式 | `apt-get install -y zstd brotli lz4 libarchive-tools`（第一次因套件索引未更新而 `E: Unable to locate package`，先 `apt-get update` 再裝成功） |
| 原始碼 | 建置所用的原始碼樹等同 G3 驗收點，其後 G4 的改動只動 `build/linux/` 與 `.gitattributes` |

## 建置指令與產物

```bash
cd CPP/7zip/Bundles/Alone2 && rm -rf b _o && make -j"$(nproc)" -f makefile.7zstar.gcc > /tmp/g4-build.log 2>&1; echo exit=$?
```

| 項目 | 結果 |
|---|---|
| exit code | **0** |
| 時間 | `real 0m40.713s`（`user 2m15s`，4 核） |
| warning | `grep -ci warning` ＝ **0**；`grep -cE 'error:\|Error [0-9]'` ＝ 0（官方警告集 `-Werror -Wall -Wextra` ＋ `warn_gcc.mak`） |
| 物件數 | `b/g/*.o` ＝ **442**（編譯＋連結共 443 行 `g++`） |
| 再跑一次 `make` | `make: Nothing to be done for 'all'.` |
| 產物 | `CPP/7zip/Bundles/Alone2/b/g/7zz`，`-rwxr-xr-x`，**4,910,392 bytes** |
| sha256 | `0469648c7fd362ffcad2ea60c05804533d63fac3772058ad44c9a3685140cf84`（與 G3 階段的記錄**相同**，建置可重現） |
| 官方檔改動 | `git diff --stat <移植前的 commit> -- 'CPP/7zip/*.mak' 'CPP/7zip/Bundles/**/*.mak' 'CPP/7zip/Bundles/**/makefile.gcc' 'C/'` → 只有 fork 新檔 `CPP/7zip/7zstar_gcc.mak`（249 行新增）；`C/` 零改動。G4 沒有改任何 handler／codec 原始碼或 makefile。 |

`7zz i`：

```text
7-ZSTar (z) 26.05.1 (x64) : Copyright (c) 1999-2026 Igor Pavlov; 7-ZSTar contributors : 2026-10-21
 64-bit locale=C.UTF-8 Threads:4 OPEN_MAX:20000
```

Formats 區塊 73 項（含偽格式 `Hash`），其中 `brotli lizard lz4 lz5 zstd` 與 `tar.br tar.bz2 tar.gz tar.liz tar.lz4 tar.lz5 tar.xz tar.zst` 都在；Codecs 區塊含 `BROTLI`、`FLZMA2`、`LIZARD`、`LZ4`、`LZ5`、`ZSTD`、`ZSTD-WZ`。

## smoke 結果

`build/linux/test-smoke.sh`（對 `b/g/7zz`）：**`passed=77 failed=0`，exit 0**。連跑 3 次、改用相對路徑加環境變數 `SEVENZZ`、換工作目錄、不設 `TMPDIR`，結果相同；跑完 `mktemp -d` 的暫存目錄已清掉（`ls /tmp | grep -c 7zstar` ＝ 0）。從 `git clone` 出來的乾淨 checkout 再跑一次：`git ls-files --eol` 為 `i/lf w/lf attr/text eol=lf`，檔案模式 `100755`，第一行 `#!/usr/bin/env bash\n`（沒有 `\r`），`passed=77 failed=0`、`interop-check.sh all` 107 列 `unexpected=0`。

### 與 `Test-Smoke.ps1` 的對應

`Test-Smoke.ps1` 展開迴圈後共 61 個執行期檢查。移植 **58 個**，沒移植 **3 個**；另加 **19 個** Linux 專屬檢查，合計 77。

| 區塊 | ps1 檢查 | bash 對應 | 備註 |
|---|---|---|---|
| 身分 | banner 含 `7-ZSTar` | ✅ | |
| 授權文件（4） | NOTICE 引述、library-only、ported 檔數、LICENSE-7-Zip.txt | ✅ ✅ ✅ ✅ | 在本樹實跑通過，規則與 ps1 相同 |
| 格式登錄（3） | 五個 codec 格式已登錄、八個 `tar.*` 已登錄、格式數在上限 96 之下（下限 60） | ✅ ✅ ✅ | 實測 73 個 |
| 來回（10） | `-t7z/zip/zstd/brotli/lz4/lz5/lizard/xz/gzip/bzip2` | ✅ | 單檔格式用 `text.txt.<ext>` 命名 |
| 串聯（8） | `tar.zst/br/gz/bz2/xz/lz4/lz5/liz` 建立＋`l` 直接列出成員＋`x` 全檔相符 | ✅ | 另外要求 `l` 輸出有 `Type = tar` 這一層 |
| 互通（2） | bsdtar 讀我們的 `tar.gz`、我們 drill-down bsdtar 的 `tar.gz` | ✅ | 用 apt 的 bsdtar 取代 `System32\tar.exe`；沒裝就 `SKIP` |
| 非 tar 回歸 | `.zst` 不誤判成 tar | ✅ | |
| brotli 偵測（7） | mt 容器不加 `-mmt` 可解且 payload sha256 ＝ `0361E377…EAF`；`corrupt-hdr.br`、`fake-magic.br` 為 Data Error；`-mmt=0` 強制 raw（容器被拒）；其他 `-mmt` 寫法不影響偵測；`-mmt=0` 不影響 `.7z` 內 brotli；`-mmt=0/4` 不破壞 `.tar.br` drill-down | ✅ ×7 | |
| 截斷（5＋4） | `trunc.lz4/lz5/liz/br/trunc-mt.br` → `Unexpected end of data`；`trunc.tar.lz4/lz5/liz/br` → 同上且 `x` 的 fallback 寫出 ≥ 512 bytes `.tar` | ✅ ×9 | |
| 壞資料（5） | `corrupt-lz4/lz4mt/lz5/liz/br.7z` → `Data Error`，不含 `Unspecified`／`end of the file` | ✅ ×5 | |
| 超大標頭（8） | `oversize-*` → `Data Error`，峰值提交 < 256 MB | ✅ ×8（**方法不同**） | 見下 |
| **未移植（3）** | 「file manager resources name 7-ZSTar, not 7-Zip」「About dialog states the fork relationship and licence」「file manager uses 7-ZSTar's handler key names, not 7-Zip's」 | ❌ | 原因：這三個檢查在 `7zFM.exe`（Windows GUI）的 PE 資源裡找 UTF-16 字串；Linux 沒有 GUI／PE 檔（Linux 只做 CLI）。ps1 本身在找不到 `7zFM.exe` 時也是 `SKIP`。 |

**方法差異（oversize）**：ps1 用 `7z t -bt` 印出的 `Virtual Memory`（Windows 峰值提交）判定。Linux 的 `7zz t -bt` 只印 `Kernel/User/Process/Global Time`，沒有記憶體統計（實測：`7zz t -bt build/testdata/oversize-packed.lz5` 的統計區只有四行時間），系統也沒有 `/usr/bin/time`。所以改成在 `ulimit -v 262144`（256 MB 位址空間上限）之下跑 `7zz t`：若解碼器真去配 1 GiB，會死在 `Can't allocate required memory!`，而不是 `Data Error`；腳本拒絕輸出含 `allocate` 的結果。兩個佐證：(1) 控制組「同一上限下有效的 `mt-brotli.br` 仍可解」通過（所以不是上限本身讓一切失敗）；(2) 上限確實有牙齒：400 MB 全零檔以 `-m0=lzma2:d=400m` 壓縮後，同樣的 `ulimit -v 262144` 下 `7zz t` 回 `ERROR: Can't allocate required memory!`、rc=2。這是「不會配 1 GiB」的行為證明，不是峰值數字；沒有 ps1 那種 MB 讀數。

**Linux 專屬新增（19）**：格式數等於實測值 73（常數 `FORMAT_COUNT_LINUX`，改 handler 時需同步更新）、Codecs 表含六個 codec、`.7z` 內 `-m0=zstd|brotli|lz4|lz5|lizard|flzma2` 各一個（要求 `l -slt` 的 `Method =` 行出現對應名稱，避免靜默退回 LZMA2；flzma2 在清單上顯示為 `LZMA2`）、四個檔頭檢查（`.zst` ＝ `28b52ffd`、`.lz4` ＝ `04224d18`、`.lz5`／`.liz` ＝ `502a4d18`，釘住 fork 的線上格式）、六個 apt CLI 互讀（zstd／brotli／lz4 讀我們寫的、我們讀它們寫的）、上述 256 MB 位址空間控制組。

**變異測試（證明檢查有牙齒）**：用包裝腳本改寫 `7zz` 的行為再跑 `test-smoke.sh`，每種都應變紅：

| 變異 | 結果 |
|---|---|
| 輸出的 `Data Error` 換成 `Unspecified error`（保留 exit code） | 25 個檢查 FAIL（`regressed to Unspecified error`），`passed=52 failed=25` |
| 輸出的 `Unexpected end of data` 換成 `Data Error` | 9 個截斷檢查 FAIL，`passed=68 failed=9` |
| 吃掉 `-mmt=0` 參數（模擬「沒有強制 raw」） | 只有 `-mmt=0 forces raw decoding` FAIL（`-mmt=0 still decoded the mt container`），`passed=76 failed=1` |
| banner 的 `7-ZSTar` 換成 `7-Zip` | 只有 banner 檢查 FAIL |
| `l` 的輸出隱藏成員名（模擬沒有 drill-down） | 8 個 `one-step create + drill-down` ＋ 1 個 bsdtar drill-down FAIL |
| 不存在的 7zz 路徑 | exit 2，印出建置提示 |

`interop-check.sh` 同樣做了變異測試：`x` 後在每個解出檔尾端多寫一個位元組 → 25 個 Windows 檔中全部 FAIL（`sha256 mismatch …`）、apt 區 21 列 FAIL；`l` 隱藏成員名 → 8 個 chain 檔 FAIL（`no drill-down`）。

### 額外驗證：多執行緒壓力與 sanitizer（G3 交辦給 G4 的項目）

不改任何 makefile：在乾淨 clone 裡用命令列覆寫編譯器即可，例如 `make -j2 -f makefile.7zstar.gcc CC='gcc -fsanitize=thread -g -fno-omit-frame-pointer' CXX='g++ -fsanitize=thread -g -fno-omit-frame-pointer'`（ASan 版把 `thread` 換成 `address,undefined`）。兩個 sanitizer 建置都 **exit 0、0 warning、442 個物件**（官方警告集 `-Werror` 照常生效）。測試腳本與一次性的壓力腳本都在 scratchpad，壓力腳本不入庫（下表即其規格）。

| 測試 | 結果 |
|---|---|
| **一般建置的壓力**：60,035,092 bytes 的混合檔（base64 亂數文字＋原始亂數，設計成多個 block／chunk）；`-tzstd/brotli/lz4/lz5/lizard` 各 `-mmt=1/2/4/8`、`.7z` 內 `-m0=zstd/brotli/lz4/lz5/lizard/flzma2` 各 `-mmt=1/2/4/8`、八種 `tar.*` 一步串聯（目錄含大檔＋小檔，`l` 要列出成員），全部 `a`→`t`→`x` 後 sha256 必須相符；整組重複 3 輪 | **156/156 相符，0 失敗**（約 10 分鐘） |
| **ASan＋UBSan＋LSan**：`interop-check.sh all`（107 列）跑在 sanitizer 版 7zz 上 | exit 0、`unexpected=0`，25/25＋37/37＋apt 互解結果與一般建置完全相同；**沒有任何 AddressSanitizer／LeakSanitizer 報告** |
| ASan 版跑 `test-smoke.sh` | 68/77；失敗的 9 個全是 `ulimit -v` 檢查（控制組＋8 個 `oversize-*`）：ASan 啟動時要映射大塊 shadow 記憶體，`ulimit -v 262144` 下直接 `AddressSanitizer failed to allocate 268435456 bytes … (errno: 12)`——是 sanitizer 與位址空間上限不相容，不是記憶體錯誤。其餘 68 個無報告 |
| UBSan 診斷 | 唯一的種類是 **`misaligned address`**（`runtime error: load/store of misaligned address … requires N byte alignment`），沒有溢位、移位、空指標等其他種類（非 misaligned 的診斷數 ＝ 0）。位置：上游 `C/ZstdDec.c`（最多）、`C/LzmaEnc.c:3077`、`Archive/Zip/ZipIn.cpp:113`、`Archive/Tar/TarIn.cpp:103`，以及 fork 的 `Archive/ZstdHandler.cpp:102`。這是上游 7-Zip 在小端機器上刻意的未對齊存取寫法（`MY_CPU_LE_UNALIGN`），x86-64／arm64 上無害；與移植無關。 |
| **TSan**：`test-smoke.sh` | 61/77；`ulimit -v` 那 9 個同樣因 TSan 不相容而失敗（`ThreadSanitizer: CHECK failed: sanitizer_allocator…`），另 7 個被下列競爭觸發 |
| TSan：壓力（8 MB 混合檔，同上矩陣 1 輪，52 項） | 45 項乾淨、7 項有報告（rc=66）：`-tlizard`（mmt=1、4）、`.7z` `-m0=flzma2`（mmt=1/2/4/8）、`tar.gz`。**`zstd`、`brotli`、`lz4`、`lz5`（獨立檔）、`.7z` 內 zstd／brotli／lz4／lz5／lizard、`tar.zst/br/lz4/lz5/liz/xz/bz2` 全部乾淨**；另對 60 MB 檔 `-mmt=4` 的獨立 zstd／lz4／lz5／brotli 各跑 6 次，0 報告 |

TSan 的三類發現（全部已用 unstripped 版本符號化、重現；**G4 不改原始碼，都沒修**）：

1. **fork 程式碼：進度計數器的資料競爭（良性，間歇出現）。** `LizardWrite`（寫入緒）呼叫 `CLocalProgress::SetRatioInfo` 讀 `*processedIn/*processedOut`，同時 `LizardRead`（讀取緒）在 `*x->processedIn += size` 寫同一個計數器（`CPP/7zip/Compress/LizardDecoder.cpp:28` 與 `:67`，原碼註解「we need no lock here, cause only one thread can write」只顧到寫入端）。`Lz4Decoder.cpp`、`Lz5Decoder.cpp`、`BrotliDecoder.cpp` 的第 67 行有逐字相同的 `x->progress->SetRatioInfo(x->processedIn, x->processedOut)`，所以是同一個潛在競爭，只是本次只有 lizard 被抓到。內容是 64 位元進度計數，只影響進度條，不影響資料；承襲 mcmilk，與平臺無關。
2. **fork 程式碼：`tar.gz` 路徑的解構順序問題（每次可重現）。** `CPP/7zip/Archive/TarChain/TarChainHandler.cpp`：`gzipCrcStream`（第 234 行，內含 `pipeIn`）宣告在 `CStreamBinder binder`（第 365 行）**之前**，函式 `return`（第 459 行）時 `binder` 先被解構，之後 `gzipCrcStream` 釋放 `pipeIn`，`~CBinderInStream` 才呼叫已被解構的 `binder.CloseRead_CallOnce()` → 對已銷毀的 `CSemaphore` 做 `Semaphore_ReleaseN`。TSan 報 `use of an invalid mutex (e.g. uninitialized or destroyed)`，堆疊 `Semaphore_ReleaseN ← CStreamBinder::CloseRead_CallOnce ← CBinderInStream::~CBinderInStream ← CSequentialInStreamWithCRC::~… ← TarChainHandler::UpdateItems:459`。實際上那塊 stack 記憶體還在所以沒有當掉，輸出也正確（壓力測試相符），但這是未定義行為；只有 gzip 路徑受影響：`pipeIn` 本身宣告在內層區塊，區塊結束就釋放，gzip 路徑多一份由函式層級的 `gzipCrcStream` 持有的參考（第 380 行 `SetStream(pipeIn)`），才拖到函式結束（壓力測試裡其他七種 `tar.*` 都沒有被報告）。建議：在 `return` 前加 `gzipCrcStream.Release();`，或把 `gzipCrcStream` 的宣告移到 `binder` 之後。解構順序與平臺無關，Windows 上的實際後果沒有在 Linux 端驗證（需在 Windows 上跑）。**第二輪已修正（宣告移到 `binder` 之後），前後對照見本檔「第二輪」段。**
3. **vendored 函式庫：不是移植造成。** `C/fast-lzma2`（`radix_engine.h:903/953`、`lzma2_enc.c:2092-2093`、`fl2_pool.c:177`、`fl2_compress.c:1084-1089`）：作者用「原子寫入／一般讀取」與進度欄位的無鎖讀取，TSan 無法判定；`-m0=flzma2` 連 `-mmt=1` 也會觸發（fast-lzma2 自帶執行緒池）。上游 `C/LzFindMt.c:176`（`MtSync_StopWriting`，LZMA2／xz 多執行緒）是官方 7-Zip 自己的程式碼，`-txz` 與 `.7z` `-m0=lzma2` 偶爾也會觸發（不是每次）。兩者都在 `C/`，G4 不動 vendored 程式碼。

### 完整 smoke 輸出

```text
7-ZSTar Linux smoke tests
  binary: /home/user/7-ZSTar/CPP/7zip/Bundles/Alone2/b/g/7zz

PASS banner identifies 7-ZSTar (not another archiver)
PASS NOTICE quotes every vendored licence file accurately
PASS vendored libraries are library-only (no GPL programs/tests trees)
PASS NOTICE's count of ported files matches the files themselves
PASS upstream's own licence statement ships with the package
PASS codecs 7-ZSTar adds are all registered as formats
PASS chained tar.* out-formats are registered
PASS codec table lists ZSTD BROTLI LZ4 LZ5 LIZARD FLZMA2
        (73 formats registered)
PASS format count is under the compiled-in ceiling (96)
PASS format count equals the measured Linux value (73)
PASS round trip: -t7z
PASS round trip: -tzip
PASS round trip: -tzstd
PASS round trip: -tbrotli
PASS round trip: -tlz4
PASS round trip: -tlz5
PASS round trip: -tlizard
PASS round trip: -txz
PASS round trip: -tgzip
PASS round trip: -tbzip2
PASS 7z round trip: -m0=zstd
PASS 7z round trip: -m0=brotli
PASS 7z round trip: -m0=lz4
PASS 7z round trip: -m0=lz5
PASS 7z round trip: -m0=lizard
PASS 7z round trip: -m0=flzma2
PASS stream header: .zst is a plain zstd frame (28b52ffd)
PASS stream header: .lz4 is a plain LZ4 frame (04224d18)
PASS stream header: .lz5 is the skippable container (502a4d18)
PASS stream header: .liz is the skippable container (502a4d18)
PASS one-step create + drill-down: tar.zst
PASS one-step create + drill-down: tar.br
PASS one-step create + drill-down: tar.gz
PASS one-step create + drill-down: tar.bz2
PASS one-step create + drill-down: tar.xz
PASS one-step create + drill-down: tar.lz4
PASS one-step create + drill-down: tar.lz5
PASS one-step create + drill-down: tar.liz
PASS interop: bsdtar reads our tar.gz
PASS interop: we drill into bsdtar's tar.gz
PASS interop: zstd -dc reads our .zst
PASS interop: we read zstd's .zst
PASS interop: brotli -dc reads our .br
PASS interop: we read brotli's .br
PASS interop: lz4 -dc reads our .lz4
PASS interop: we read lz4's .lz4
PASS non-tar .zst still lists as a single item (drill-down does not misfire)
PASS mt-brotli container (mcmilk wire format) extracts without -mmt
PASS corrupted mt-brotli header fails as Data Error, not Unspecified
PASS raw .br faking the container magic fails as Data Error, not Unspecified
PASS -mmt=0 forces raw decoding: bytes unchanged, container refused
PASS every other -mmt spelling leaves detection alone
PASS -mmt=0 does not reach brotli inside a .7z
PASS -mmt=0 does not break .tar.br drill-down
PASS truncated trunc.lz4 fails as Unexpected end of data
PASS truncated trunc.lz5 fails as Unexpected end of data
PASS truncated trunc.liz fails as Unexpected end of data
PASS truncated trunc.br fails as Unexpected end of data
PASS truncated trunc-mt.br fails as Unexpected end of data
PASS truncated trunc.tar.lz4 falls back to a partial .tar, Unexpected end of data
PASS truncated trunc.tar.lz5 falls back to a partial .tar, Unexpected end of data
PASS truncated trunc.tar.liz falls back to a partial .tar, Unexpected end of data
PASS truncated trunc.tar.br falls back to a partial .tar, Unexpected end of data
PASS corrupt-lz4.7z (one byte flipped) fails as Data Error
PASS corrupt-lz4mt.7z (one byte flipped) fails as Data Error
PASS corrupt-lz5.7z (one byte flipped) fails as Data Error
PASS corrupt-liz.7z (one byte flipped) fails as Data Error
PASS corrupt-br.7z (one byte flipped) fails as Data Error
PASS address-space cap of 256 MB leaves a valid container decodable
PASS oversize-packed-lz4mt.7z fails as Data Error under 256 MB
PASS oversize-content-lz4mt.7z fails as Data Error under 256 MB
PASS oversize-packed.lz5 fails as Data Error under 256 MB
PASS oversize-content.lz5 fails as Data Error under 256 MB
PASS oversize-packed.liz fails as Data Error under 256 MB
PASS oversize-content.liz fails as Data Error under 256 MB
PASS oversize-packed-mt.br fails as Data Error under 256 MB
PASS oversize-hint-mt.br fails as Data Error under 256 MB

passed=77 failed=0
```

## Windows 產物 25 個逐檔結果

來源 `test/interop/windows/`（`MANIFEST.md`：8 個單檔、8 個 tar 串聯、9 個 `.7z`），全是 Windows 建置的 `7z.exe` 寫的。每個檔跑 `7zz l`、`7zz t`、`7zz x -y -o<新目錄>`，解出內容與 `test/interop/corpus/SHA256SUMS` 比對：單檔對 `text512k.txt`（`3b270f4f…`），串聯與 `.7z` 對 corpus 的 9 個檔加 `SHA256SUMS` 本身（共 10 個檔，檔案集合必須恰好相符，不可多）。`.7z` 的 `Method` 取自 `7zz l -slt`。

**結果：25/25 PASS**，`t`、`x` 全是 exit 0；含 `.lz5`／`.liz`／`.7z` 內 LZ5／LIZARD／ZSTD／BROTLI／LZ4（這些官方 7zz 與 Linux CLI 都讀不了，見 `test/interop/REPORT.md` 第 3 節）。所有串聯格式 `7zz l` 直接列出 tar 成員（`Type = <壓縮>+tar`，即 drill-down），沒有出現只解出 `.tar` 的兩段式。「與預期相同」欄的預期是「全部通過」；repo 內沒有 Windows `7z.exe` 自讀這 25 個檔的記錄可供逐格比對（`test/interop/REPORT.md` 第 3 節是 Linux 工具讀它們），所以這張表的比較基準是預期，不是 Windows 實測。

| 檔案 | 類型（7zz l） | t | x | sha256 | 判定 | 與預期（全部 PASS）相同？ | 備註 |
|---|---|---|---|---|---|---|---|
| `7z/corpus-brotli-mt4.7z` | 7z | 0 | 0 | 相符 (10/10) | PASS | 同 | Method=BROTLI  |
| `7z/corpus-brotli.7z` | 7z | 0 | 0 | 相符 (10/10) | PASS | 同 | Method=BROTLI  |
| `7z/corpus-flzma2.7z` | 7z | 0 | 0 | 相符 (10/10) | PASS | 同 | Method=LZMA2:21  |
| `7z/corpus-lizard.7z` | 7z | 0 | 0 | 相符 (10/10) | PASS | 同 | Method=LIZARD  |
| `7z/corpus-lz4.7z` | 7z | 0 | 0 | 相符 (10/10) | PASS | 同 | Method=LZ4  |
| `7z/corpus-lz5.7z` | 7z | 0 | 0 | 相符 (10/10) | PASS | 同 | Method=LZ5  |
| `7z/corpus-lzma2.7z` | 7z | 0 | 0 | 相符 (10/10) | PASS | 同 | Method=LZMA2:21  |
| `7z/corpus-zstd-mt4.7z` | 7z | 0 | 0 | 相符 (10/10) | PASS | 同 | Method=ZSTD  |
| `7z/corpus-zstd.7z` | 7z | 0 | 0 | 相符 (10/10) | PASS | 同 | Method=ZSTD  |
| `chain/corpus.tar.br` | brotli+tar | 0 | 0 | 相符 (10/10) | PASS | 同 | drill-down: members listed  |
| `chain/corpus.tar.bz2` | bzip2+tar | 0 | 0 | 相符 (10/10) | PASS | 同 | drill-down: members listed  |
| `chain/corpus.tar.gz` | gzip+tar | 0 | 0 | 相符 (10/10) | PASS | 同 | drill-down: members listed  |
| `chain/corpus.tar.liz` | lizard+tar | 0 | 0 | 相符 (10/10) | PASS | 同 | drill-down: members listed  |
| `chain/corpus.tar.lz4` | lz4+tar | 0 | 0 | 相符 (10/10) | PASS | 同 | drill-down: members listed  |
| `chain/corpus.tar.lz5` | lz5+tar | 0 | 0 | 相符 (10/10) | PASS | 同 | drill-down: members listed  |
| `chain/corpus.tar.xz` | xz+tar | 0 | 0 | 相符 (10/10) | PASS | 同 | drill-down: members listed  |
| `chain/corpus.tar.zst` | zstd+tar | 0 | 0 | 相符 (10/10) | PASS | 同 | drill-down: members listed  |
| `single/text512k.txt.br` | brotli | 0 | 0 | 相符 (1/1) | PASS | 同 |   |
| `single/text512k.txt.bz2` | bzip2 | 0 | 0 | 相符 (1/1) | PASS | 同 |   |
| `single/text512k.txt.gz` | gzip | 0 | 0 | 相符 (1/1) | PASS | 同 |   |
| `single/text512k.txt.liz` | lizard | 0 | 0 | 相符 (1/1) | PASS | 同 |   |
| `single/text512k.txt.lz4` | lz4 | 0 | 0 | 相符 (1/1) | PASS | 同 |   |
| `single/text512k.txt.lz5` | lz5 | 0 | 0 | 相符 (1/1) | PASS | 同 |   |
| `single/text512k.txt.xz` | xz | 0 | 0 | 相符 (1/1) | PASS | 同 |   |
| `single/text512k.txt.zst` | zstd | 0 | 0 | 相符 (1/1) | PASS | 同 |   |

windows summary: 25/25 PASS

## Linux 向量逐檔結果

來源 `test/interop/linux/`：目錄內實際 39 個檔 ＝ **37 個向量** ＋ `MANIFEST.md` ＋ `SHA256SUMS`（附屬檔不算向量）。向量集合以 `MANIFEST.md` 的表格列為準（腳本逐列解析），並先跑 `sha256sum -c linux/SHA256SUMS`：37 個 OK、0 個非 OK（傳輸／checkout 沒有損壞；腳本若有列在 MANIFEST 卻不存在的檔會當場記 `MISSING`）。

判定規則沿用 `build/Test-Interop.ps1`（Windows 版）：`PASS`、`REJECTED-CLEAN`（預期被拒、exit 在 {1,2,7,8,255}、輸出沒有 `Unspecified`／`exception`）、`UPSTREAM-LIMIT`（pax 格式 GNU sparse 1.0 條目未展開，且其餘成員全對）、其餘為 FAIL。「Windows 預期」欄取自 `test/interop/REPORT.md` 第 8 節：32 PASS、`lz4-legacy` REJECTED-CLEAN、四個 UPSTREAM-LIMIT（`tar/corpus.bsdtar-default.tar.zst`、`tar/corpus.bsdtar-default.tar.lz4`、`tar/sparse.gnutar-sparse-pax.tar.zst`、`tar/sparse.bsdtar-default.tar.zst`，寫在腳本的 `WIN_EXPECT`）。

**結果：37 個向量 ＝ 32 PASS ＋ 1 REJECTED-CLEAN ＋ 4 UPSTREAM-LIMIT；37/37 與 Windows 結果相同。**

linux/SHA256SUMS 核對：37 個 OK、0 個非 OK

| 檔案 | 類型（7zz l） | t | x | sha256 | Windows 預期 | 本次判定 | 與 Windows 相同？ | 備註 |
|---|---|---|---|---|---|---|---|---|
| `tar/corpus.gnutar-gnu.tar.zst` | zstd+tar | 0 | 0 | 相符 | PASS | PASS | 同 | drill-down: members listed  |
| `tar/corpus.gnutar-pax.tar.zst` | zstd+tar | 0 | 0 | 相符 | PASS | PASS | 同 | drill-down: members listed  |
| `tar/corpus.bsdtar-default.tar.zst` | zstd+tar | 0 | 0 | 相符（sparse 條目未展開） | UPSTREAM-LIMIT | UPSTREAM-LIMIT | 同 | drill-down: members listed [pax GNU.sparse 1.0 entry left compacted as GNUSparseFile.0/zeros.bin] |
| `tar/corpus.bsdtar-gnutar.tar.zst` | zstd+tar | 0 | 0 | 相符 | PASS | PASS | 同 | drill-down: members listed  |
| `tar/corpus.bsdtar-default.tar.lz4` | lz4+tar | 0 | 0 | 相符（sparse 條目未展開） | UPSTREAM-LIMIT | UPSTREAM-LIMIT | 同 | drill-down: members listed [pax GNU.sparse 1.0 entry left compacted as GNUSparseFile.0/zeros.bin] |
| `tar/sparse.gnutar-sparse-gnu.tar.zst` | zstd+tar | 0 | 0 | 相符 | PASS | PASS | 同 | drill-down: members listed  |
| `tar/sparse.gnutar-sparse-pax.tar.zst` | zstd+tar | 0 | 0 | 相符（sparse 條目未展開） | UPSTREAM-LIMIT | UPSTREAM-LIMIT | 同 | drill-down: members listed [pax GNU.sparse 1.0 entry left compacted as GNUSparseFile.16794/sparse.bin] |
| `tar/sparse.bsdtar-default.tar.zst` | zstd+tar | 0 | 0 | 相符（sparse 條目未展開） | UPSTREAM-LIMIT | UPSTREAM-LIMIT | 同 | drill-down: members listed [pax GNU.sparse 1.0 entry left compacted as GNUSparseFile.0/sparse.bin] |
| `zstd/zstd-19.text512k.txt.zst` | zstd | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `zstd/zstd-T0-long31.text512k.txt.zst` | zstd | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `zstd/zstd-T0-long31-stdin.text512k.txt.zst` | zstd | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `zstd/zstd-no-check.text512k.txt.zst` | zstd | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `zstd/zstd-no-content-size.text512k.txt.zst` | zstd | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `zstd/zstd-stdin.text512k.txt.zst` | zstd | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `zstd-frames/concat.a-then-b.zst` | zstd | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `zstd-frames/skippable-before.a.zst` | zstd | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `zstd-frames/skippable-between.a-b.zst` | zstd | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `brotli/brotli-q0-w10.text512k.txt.br` | brotli | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `brotli/brotli-q0-w24.text512k.txt.br` | brotli | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `brotli/brotli-q5-w16.text512k.txt.br` | brotli | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `brotli/brotli-q5-w22.text512k.txt.br` | brotli | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `brotli/brotli-q11-w10.text512k.txt.br` | brotli | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `brotli/brotli-q11-w16.text512k.txt.br` | brotli | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `brotli/brotli-q11-w22.text512k.txt.br` | brotli | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `brotli/brotli-q11-w24.text512k.txt.br` | brotli | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `brotli/corpus.gnutar.tar.br` | brotli+tar | 0 | 0 | 相符 | PASS | PASS | 同 | drill-down: members listed  |
| `brotli/brotli-q5-large-window30.text512k.txt.br` | brotli | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `lz4/zstd-format-lz4.text512k.txt.lz4` | lz4 | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `lz4/lz4-B4.text512k.txt.lz4` | lz4 | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `lz4/lz4-B7.text512k.txt.lz4` | lz4 | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `lz4/lz4-BD.text512k.txt.lz4` | lz4 | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `lz4/lz4-BX.text512k.txt.lz4` | lz4 | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `lz4/lz4-no-frame-crc.text512k.txt.lz4` | lz4 | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `lz4/lz4-content-size.text512k.txt.lz4` | lz4 | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `lz4/lz4-legacy.text512k.txt.lz4` |  | 2 | 2 | n/a（拒絕） | REJECTED-CLEAN | REJECTED-CLEAN | 同 |  [Open ERROR: Cannot open the file as [lz4] archive] |
| `lz4/lz4-B4-BD.text512k.txt.lz4` | lz4 | 0 | 0 | 相符 | PASS | PASS | 同 |   |
| `lz4/concat.a-then-b.lz4` | lz4 | 0 | 0 | 相符 | PASS | PASS | 同 |   |

linux summary: 37 vectors; UPSTREAM-LIMIT=4 PASS=32 REJECTED-CLEAN=1; same-as-Windows 37/37

## 與 Windows 結果的差異

**逐格比較（37 個向量 × 判定）：沒有任何不同的格子。** 以下是「相同」的具體證據，不是「沒查」：

1. **lz4 legacy 乾淨拒絕**：`lz4/lz4-legacy.text512k.txt.lz4`，檔頭 `02 21 4c 18 3e e8 02 00 61 6c 69 6e 65 20 30 01`（legacy frame magic）。`7zz l`／`t`／`x` 皆 exit 2，訊息與 Windows `REPORT.md` 第 8 節逐字相同：

   ```text
   Open ERROR: Cannot open the file as [lz4] archive
   Errors: 1
   ```

   輸出沒有 `Unspecified`、沒有 crash。
2. **pax GNU sparse 1.0 不展開**（與官方 7-Zip 26.05 相同的上游限制）：Linux 上解出的壓實檔與 Windows 記錄的大小逐位元組相同——

   | 向量 | Linux 解出 | Windows `REPORT.md` 第 8 節 |
   |---|---|---|
   | `tar/corpus.bsdtar-default.tar.zst`、`…tar.lz4` | `GNUSparseFile.0/zeros.bin` 4608 bytes（應為 1 MiB） | `GNUSparseFile.0\zeros.bin` 4608 |
   | `tar/sparse.gnutar-sparse-pax.tar.zst` | `GNUSparseFile.16794/sparse.bin` 12800 bytes（應為 4 MiB） | `GNUSparseFile.16794\sparse.bin` 12800 |
   | `tar/sparse.bsdtar-default.tar.zst` | `GNUSparseFile.0/sparse.bin` 12800 bytes | 同 12800 |
   | `tar/sparse.gnutar-sparse-gnu.tar.zst`（舊式 type `S`） | `sparse.bin` 4194304 bytes，sha256 相符 | 兩邊都正確展開 |

   連目錄編號（`.0`、`.16794`）都一致，因為這是 tar handler 的邏輯，與平臺無關。其他成員在這四個向量裡全數 sha256 相符（判定 `UPSTREAM-LIMIT` 的條件就是「只有 sparse 條目出問題」）。
3. **其他 32 個 PASS**：zstd 6（含 2 GiB 視窗 `--long=31`、無 content size、無 check）、zstd-frames 3（串接、開頭與中間的 skippable frame）、brotli 10（含 `--large_window=30`，7zz 與 Windows 一樣讀得開）、lz4 9、tar 4（GNU／pax 兩種方言的長檔名與繁中檔名、bsdtar gnutar、GNU 舊式 sparse）。所有 `.tar.*` 都是一步 drill-down。
4. **Windows 25 個產物**：沒有 Windows 自讀記錄可比（見上節），以預期「全過」為準，實測 25/25 PASS。

與 Windows 側**方法**上的差異（結果不受影響，但請知道）：

- `oversize-*`：Windows 用 `-bt` 的 `Virtual Memory`，Linux 用 `ulimit -v 262144`（見「smoke 結果」）。
- 檔案系統：Linux 解出的檔名是 UTF-8 原樣（`中文檔名.txt` 與 corpus 同名同 hash）；不存在 Windows 的路徑長度或保留字限制，這方面 Linux 只會比 Windows 寬鬆，所以「Windows 通過、Linux 失敗」的檔名類問題不會出現，反向（Linux 通過、Windows 失敗）本次沒有向量覆蓋。
- 沒有發現任何「Linux 通過但 Windows 失敗」或相反的向量。

## apt 互解

工具與 payload 見表上方一行。方向：`7zz → CLI` ＝ 7zz 寫、apt 工具讀；`CLI → 7zz` ＝ apt 工具寫、7zz 讀（`t`＋`x`，串聯另加 `l` 確認 drill-down）。共 45 列，**全部 PASS 或 UPSTREAM-LIMIT**，沒有 FAIL。

- `7zz → CLI`：`-tzstd|brotli|lz4` 的輸出用 `zstd -dc`／`brotli -dc`／`lz4 -dc` 解回 sha256 相符，並通過 `zstd -t`／`brotli -t`／`lz4 -t`；`-ttar.{zst,br,lz4,gz,xz,bz2}` 的輸出用 `zstd|tar`、`tar --zstd`、`tar` 自動偵測、`bsdtar`、`tar -I brotli`、`tar -I lz4` 等解回，10 個檔全相符；`.7z` 內 `-m0=zstd|flzma2|lzma2` 用 `bsdtar -xf` 解回 10/10 相符（`test/interop/REPORT.md` 第 3 節：bsdtar 讀得了 `.7z` 內的 ZSTD）。
- `CLI → 7zz`：`zstd -3/-19/--long=27/stdin -T0`、`brotli -q 1/5/11 -w 24`、`lz4 -1/-9/--content-size/-B7 -BD` 產的單檔全部 `t`＋`x` 相符；`tar|zstd`、`tar --zstd`、`bsdtar --zstd`、`tar|brotli`、`tar|lz4`、`bsdtar --lz4`、`tar -czf/-cJf/-cjf`、`bsdtar -czf` 產的串聯全部 drill-down 並 `x` 後內容正確。三個 bsdtar 產物判為 `UPSTREAM-LIMIT`：bsdtar 預設（pax）把全零的 `zeros.bin` 寫成 GNU sparse 1.0，7zz 解成 `GNUSparseFile.0/zeros.bin`（4608 bytes）——與上節同一個上游限制，其餘 9 個檔全相符。
- lz5／lizard：沒有 apt 套件，**未做**外部實作互通（依規定不從原始碼編；見「未完成與原因」）。

工具：zstd v1.5.5；brotli 1.1.0；lz4 v1.9.4；tar (GNU tar) 1.35；bsdtar 3.7.2
單檔 payload `big.dat`（4243496 bytes，sha256 0d00ce5739cbb8f4…）；tar 類 payload 為 corpus/（10 個檔）。

| 方向 | 內容 | 結果 | 備註 |
|---|---|---|---|
| 7zz → CLI | `7zz a -tzstd` → `zstd -dc` | PASS | sha256 相符，head=28b52ffd |
| 7zz → CLI | `7zz a -tbrotli` → `brotli -dc` | PASS | sha256 相符，head=afffdf00 |
| 7zz → CLI | `7zz a -tlz4` → `lz4 -dc` | PASS | sha256 相符，head=04224d18 |
| 7zz → CLI | `7zz a -tzstd` → `zstd -t` | PASS |  |
| 7zz → CLI | `7zz a -tbrotli` → `brotli -t` | PASS |  |
| 7zz → CLI | `7zz a -tlz4` → `lz4 -t` | PASS |  |
| 7zz → CLI | `7zz a -ttar.zst` → `zstd -dc FILE \| tar -xf - -C DIR` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -ttar.zst` → `tar --zstd -xf FILE -C DIR` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -ttar.zst` → `tar -xf FILE -C DIR` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -ttar.zst` → `bsdtar -xf FILE -C DIR` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -ttar.br` → `brotli -dc FILE \| tar -xf - -C DIR` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -ttar.br` → `tar -I brotli -xf FILE -C DIR` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -ttar.lz4` → `lz4 -dc FILE \| tar -xf - -C DIR` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -ttar.lz4` → `tar -I lz4 -xf FILE -C DIR` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -ttar.lz4` → `bsdtar -xf FILE -C DIR` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -ttar.gz` → `tar -xf FILE -C DIR` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -ttar.gz` → `bsdtar -xf FILE -C DIR` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -ttar.xz` → `tar -xf FILE -C DIR` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -ttar.xz` → `bsdtar -xf FILE -C DIR` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -ttar.bz2` → `tar -xf FILE -C DIR` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -ttar.bz2` → `bsdtar -xf FILE -C DIR` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -t7z -m0=zstd` → `bsdtar -xf` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -t7z -m0=flzma2` → `bsdtar -xf` | PASS | 10/10 相符 |
| 7zz → CLI | `7zz a -t7z -m0=lzma2` → `bsdtar -xf` | PASS | 10/10 相符 |
| CLI → 7zz | `zstd -3` → `7zz t`+`x` | PASS | t=0 x=0 sha256 相符 |
| CLI → 7zz | `zstd -19` → `7zz t`+`x` | PASS | t=0 x=0 sha256 相符 |
| CLI → 7zz | `zstd --long=27` → `7zz t`+`x` | PASS | t=0 x=0 sha256 相符 |
| CLI → 7zz | `zstd -T0 (stdin)` → `7zz t`+`x` | PASS | t=0 x=0 sha256 相符 |
| CLI → 7zz | `brotli -q 1` → `7zz t`+`x` | PASS | t=0 x=0 sha256 相符 |
| CLI → 7zz | `brotli -q 5` → `7zz t`+`x` | PASS | t=0 x=0 sha256 相符 |
| CLI → 7zz | `brotli -q 11 -w 24` → `7zz t`+`x` | PASS | t=0 x=0 sha256 相符 |
| CLI → 7zz | `lz4 -1` → `7zz t`+`x` | PASS | t=0 x=0 sha256 相符 |
| CLI → 7zz | `lz4 -9` → `7zz t`+`x` | PASS | t=0 x=0 sha256 相符 |
| CLI → 7zz | `lz4 --content-size` → `7zz t`+`x` | PASS | t=0 x=0 sha256 相符 |
| CLI → 7zz | `lz4 -B7 -BD` → `7zz t`+`x` | PASS | t=0 x=0 sha256 相符 |
| CLI → 7zz | `tar cf - \| zstd` → `7zz l`+`t`+`x` | PASS | types=zstd+tar t=0 x=0; drill-down: members listed  |
| CLI → 7zz | `tar --zstd -cf` → `7zz l`+`t`+`x` | PASS | types=zstd+tar t=0 x=0; drill-down: members listed  |
| CLI → 7zz | `bsdtar --zstd -cf` → `7zz l`+`t`+`x` | UPSTREAM-LIMIT | types=zstd+tar t=0 x=0; drill-down: members listed [pax GNU.sparse 1.0 entry left compacted as GNUSparseFile.0/zeros.bin] |
| CLI → 7zz | `tar cf - \| brotli` → `7zz l`+`t`+`x` | PASS | types=brotli+tar t=0 x=0; drill-down: members listed  |
| CLI → 7zz | `tar cf - \| lz4` → `7zz l`+`t`+`x` | PASS | types=lz4+tar t=0 x=0; drill-down: members listed  |
| CLI → 7zz | `bsdtar --lz4 -cf` → `7zz l`+`t`+`x` | UPSTREAM-LIMIT | types=lz4+tar t=0 x=0; drill-down: members listed [pax GNU.sparse 1.0 entry left compacted as GNUSparseFile.0/zeros.bin] |
| CLI → 7zz | `tar -czf` → `7zz l`+`t`+`x` | PASS | types=gzip+tar t=0 x=0; drill-down: members listed  |
| CLI → 7zz | `tar -cJf` → `7zz l`+`t`+`x` | PASS | types=xz+tar t=0 x=0; drill-down: members listed  |
| CLI → 7zz | `tar -cjf` → `7zz l`+`t`+`x` | PASS | types=bzip2+tar t=0 x=0; drill-down: members listed  |
| CLI → 7zz | `bsdtar -czf` → `7zz l`+`t`+`x` | UPSTREAM-LIMIT | types=gzip+tar t=0 x=0; drill-down: members listed [pax GNU.sparse 1.0 entry left compacted as GNUSparseFile.0/zeros.bin] |

rows=107 unexpected=0

## 未完成與原因

| 項目 | 狀態 | 原因 |
|---|---|---|
| lz5／lizard 與外部獨立實作互通 | 未做 | Ubuntu 24.04 沒有 lz5／lizard 套件，規則禁止從原始碼編其他工具。這兩種格式只驗證了「7-ZSTar（Windows 產）→ 7-ZSTar（Linux）」與 Linux 自己來回，等於同一份程式碼的兩個平臺，**不是**獨立實作驗證。 |
| `Test-Smoke.ps1` 的 3 個 GUI 檢查 | 不適用 | `7zFM.exe` 的 PE 資源字串；Linux 沒有 GUI（見「smoke 結果」）。 |
| oversize 的峰值記憶體「MB 讀數」 | 以行為證明替代 | `7zz -bt` 在 Linux 不印記憶體；見「smoke 結果」的方法差異。 |
| 獨立 `a -tlz4/-tbrotli -mmt=4` 產生 skippable 容器 | 不測（設計如此） | G3 差異註記：`.lz4`／`.br` 獨立檔不論 `-mmt` 都寫 plain frame，`.lz5`／`.liz` 永遠是容器（`Lz4Handler.cpp`、`BrotliHandler.cpp` 註解）。smoke 把這個行為釘成檢查（檔頭 `04224d18`／`502a4d18`），容器的**讀取**由 `mt-brotli.br` 與 `.7z` `-mmt` 路徑覆蓋。若日後想讓獨立檔也寫容器，那是行為變更，不是 Linux 缺陷。 |
| Linux → Windows 的檔名／長路徑類回讀 | 未測 | 本次向量沒有涵蓋「Linux 通過、Windows 失敗」這個方向（需要在 Windows 側跑）。 |
| 其他架構／選項 | 未測 | arm64、32 位元、`USE_ASM=1`（沒有 `asmc`／`jwasm`）、`ST_MODE=1`、clang 官方警告集——G3 已記為未做，G4 範圍不含。靜態 `7zzs` 第二輪 R1.2 已建置通過（見「第二輪」段），未跑 smoke。 |
| Windows 建置 | 已在 Windows 端驗證（2026-11-04） | `Build.ps1 -Clean` x64 17/17 零警告、`Test-Smoke.ps1` 61/61、`Test-Interop.ps1` 對 37 個 Linux 向量 32 PASS／1 REJECTED-CLEAN／4 UPSTREAM-LIMIT，與移植前相同；兩個 fork 檔的 `_WIN32`／`_MSC_VER` 分支在 MSVC 下行為不變。 |
| TarChain `tar.gz` 的解構順序（TSan：use of an invalid mutex） | **第二輪已修** | 見「額外驗證」第 2 點與「第二輪」段；`gzipCrcStream` 的宣告移到 `CStreamBinder binder` 之後，同一腳本改前 exit 66／改後 0 報告。Windows 重建尚待驗證。 |
| lz4／lz5／lizard／brotli 解碼器進度計數器的資料競爭 | 發現，未修 | 見「額外驗證」第 1 點；`Compress/{Lizard,Lz5,Lz4,Brotli}Decoder.cpp:28/67`，只影響進度，承襲 mcmilk。 |
| fast-lzma2、`LzFindMt.c` 的 TSan 報告 | 記錄，不處理 | vendored／上游程式碼，與移植無關（見「額外驗證」第 3 點）。 |
| TSan／ASan 與 `ulimit -v` 的 oversize 檢查不相容 | 已知限制 | 在 sanitizer 版上這 9 個檢查必然失敗；一般建置全過。 |

## 第二輪（2026-11-04，review follow-ups 與 TarChain 解構順序）

環境同上（Ubuntu 24.04、gcc 13.3.0、4 核）。R1／R2 每步修改完成後，都**重新實跑**下列全部指令；本段的數字除標「另一次實測」者外，都是這次重跑得到的。

### R1 makefile 與腳本修正

| 條 | 改動 | 驗證（實跑） |
|---|---|---|
| 1 | `7zstar_gcc.mak`：`OBJS +=` 之前加 `ZS_UPSTREAM_DUP := $(filter $(ZS_OBJS),$(OBJS))` 護欄 | 正常建置不觸發。測試時把 `$O/7zHandler.o` 加進 `ZS_CPP_TARCHAIN_OBJS` 後 `make -n -f makefile.7zstar.gcc` → `../../7zstar_gcc.mak:245: *** 7zstar_gcc.mak: upstream now builds b/g/7zHandler.o -- drop them from the ZS_* lists.  Stop.`，exit 2（前面是 GNU make 自己的 `overriding recipe`／`ignoring old recipe` 兩行）；`git checkout --` 還原後 `git diff --quiet` 乾淨。 |
| 2 | `$(PROGPATH_STATIC): $(ZS_OBJS)` | `make -j4 -f makefile.7zstar.gcc COMPL_STATIC=1` exit 0；`b/g/7zzs` 為 `ELF 64-bit LSB executable … statically linked`；`7zzs i` 與第一輪基準 `7zz i` 逐行相同。唯二輸出是 ld 對上游 `FileStreams.o` 的 `getgrgid`／`getpwuid` 靜態連結警告（非編譯 warning）。 |
| 3 | 每個目錄一份清單（`ZS_CPP_*_OBJS`／`ZS_C_*_OBJS`）、刪未定義彙總變數與施工註解、行號引用改規則名、`-DZSTD_MULTITHREAD` 註解改成實際範圍 | 乾淨重建後 `7zz i` 與第一輪基準（另行建置的 `7zz`）`diff` 無差異（125 行）；物件數 442。 |
| 4 | `makefile.7zstar.gcc` 改為 `include ../../cmpl_gcc.mak` ＋ `include ../../7zstar_gcc.mak` | 乾淨重建 exit 0、0 warning、442 物件。第 1–4 條單獨重建時 sha256 與第一輪相同（另一次實測）；含第 7、8 條後為 `ec45e99b…`，差異只來自兩個 .cpp。 |
| 5 | `interop-check.sh`：`sha256sum -c` 失敗計入 `BAD_RUNS`、`linux/` 檔案集合對 `MANIFEST.md`、`ERROR-EXIT` 進判定清單、刪 `types_of()`、25／37／4194304 改由 manifest／`find` 推得、`mktemp` 相對路徑不殘留、`.tar.` 向量要求 `Type` 含 `+tar` | `interop-check.sh all`：`windows summary: 25/25 PASS`、`linux/ 檔案集合與 MANIFEST.md 一致：37 個`、`linux summary: 37 vectors; UPSTREAM-LIMIT=4 PASS=32 REJECTED-CLEAN=1; same-as-Windows 37/37`、`rows=107 unexpected=0`，exit 0。負向測試（改 1 byte／多一檔／少一檔／偽造 `.tar.zst`／相對 `TMPDIR`）在暫存副本上做，各 exit 1 或 2。另有一次唯讀審查逐項核對 diff：全部 DONE、`bash -n` 通過。 |
| 6 | `test-smoke.sh`：`ulimit -v` 兩處加 `-mmt=1`、`mktemp` 相對路徑不殘留、刪空標題、改正種子與 flzma2 註解 | `test-smoke.sh`：`passed=77 failed=0`，exit 0。 |
| 7 | `TempFileDecodedStream.cpp`：`#ifndef _WIN32` 內 `outStream->File.mode_for_Create = 0600` | `strace -f -e trace=openat 7zz x -y -oout test/interop/linux/brotli/corpus.gnutar.tar.br`（umask 022）→ `openat(AT_FDCWD, "/tmp/7zsD.CC5EC35A.tmp", O_WRONLY\|O_CREAT\|O_EXCL, 0600)`；`tar/corpus.bsdtar-default.tar.lz4` 同為 `0600`；兩次 `Everything is Ok`，`/tmp` 無殘留。（`.tar.zst` 不經過這個暫存檔，所以用 brotli／lz4 的串聯向量驗。） |
| 8 | `ZstdEncoder.cpp:262` 註解補 `7zstar_gcc.mak` | `git diff` 只有該行。 |

R1 之後的乾淨重建：exit 0、0 warning、442 物件、`7zz` sha256 `ec45e99bf53463bb13545bfd71e7902a8d691d2d0ba9dca8601b8ae2537f9419`。

### R2 TarChain `tar.gz` 路徑的解構順序

改動：`CPP/7zip/Archive/TarChain/TarChainHandler.cpp` +11／−1——`gzipCrcStream` 的宣告從原 `:234` 移到 `CStreamBinder binder; RINOK(binder.Create_ReInit())` 之後（現 `:376`），加 `// 7-ZSTar:` 註解。局部變數反向解構，所以 `gzipCrcStream` 現在先於 `binder` 解構，`~CBinderInStream` 回呼 `binder.CloseRead_CallOnce()` 時 `binder` 還活著；gzip trailer（`:462-463` 讀 `GetCRC()`／`GetSize()`）仍在作用域內、`return` 之前。無行為變更。

TSan 前後對照（兩個 TSan 版各用 `git worktree` 另建，`make -f makefile.7zstar.gcc CC='gcc -fsanitize=thread -g -fno-omit-frame-pointer' CXX='g++ -fsanitize=thread -g -fno-omit-frame-pointer'`，各 exit 0、0 warning、442 物件；同一支腳本、`TSAN_OPTIONS="exitcode=66 log_path=…"`，來源目錄 4 個檔含子目錄，步驟 `7zz a -ttar.gz out.tar.gz in` → `7zz l`（drill-down 列出成員）→ `7zz x` → 逐檔 sha256）：

| 二進位 | `a` | `l` | `x` | round trip | TSan 報告 |
|---|---|---|---|---|---|
| 改前（第 1 次） | exit 66 | 0（5 列成員） | 0 | 相符 | 1 份：`WARNING: ThreadSanitizer: use of an invalid mutex (e.g. uninitialized or destroyed)`，`Location is stack of main thread` |
| 改前（第 2 次） | exit 66 | 0 | 0 | 相符 | 同上 |
| 改後（第 1 次） | exit 0 | 0（5 列成員） | 0 | 相符 | **0** |
| 改後（第 2 次） | exit 0 | 0 | 0 | 相符 | **0** |

用 `LFLAGS_STRIP=` 建的符號化版本（改前）堆疊：`Semaphore_ReleaseN C/Threads.c:694 ← CSemaphore::Release Windows/Synchronization.h:161 ← CStreamBinder::CloseRead_CallOnce Common/StreamBinder.h:67 ← CBinderInStream::~CBinderInStream StreamBinder.cpp:15 ← CMyComPtr<ISequentialInStream>::~CMyComPtr ← CSequentialInStreamWithCRC::~… ← CMyComPtr2_Create<…>::~CMyComPtr2_Create MyCom.h:161 ← UpdateItems 返回`，與第一輪 REPORT 所述一致；改後連跑 5 次 0 報告。

改後 TSan 版對其他七種串聯各跑 `a`＋`l`＋`x`＋sha256：`tar.zst`／`tar.br`／`tar.lz4`／`tar.lz5`／`tar.liz`／`tar.xz`／`tar.bz2` 全部 `a=0 l=0 x=0 roundtrip=match reports=0`。另一輪 `tar.xz` 曾出現上游 `C/LzFindMt.c` 的資料競爭（改前同樣有，偶發、上游、不在範圍）。

一般建置（非 TSan）：`rm -rf b _o && make -j2 -f makefile.7zstar.gcc` exit 0、0 warning、442 物件；`test-smoke.sh` `passed=77 failed=0`；`interop-check.sh all` 25/25、37/37 same-as-Windows、`rows=107 unexpected=0`；`7zz i` 與第一輪基準逐行相同。

**不在本輪範圍、未動**：「額外驗證」第 1 點的解碼器進度計數器資料競爭（`Compress/{Lizard,Lz5,Lz4,Brotli}Decoder.cpp:28/67`）；第 3 點的 vendored／上游報告。

### 最終產物與官方檔

| 項目 | 值 |
|---|---|
| `7zz` sha256 | `db08c52aec453a3d0078b5fb158d3edcf5c9ed98a0db70448f3f4cfc46ab8766`（4,910,392 bytes，442 物件；同環境可重現） |
| 官方檔改動 | **無。** `git diff --stat <移植前的 commit> -- 'CPP/7zip/*.mak' 'CPP/7zip/Bundles/**/*.mak' 'CPP/7zip/Bundles/**/makefile.gcc' 'C/'` 只列 fork 新檔 `CPP/7zip/7zstar_gcc.mak`；`C/` 零改動。本輪動到的 fork 自有檔：`7zstar_gcc.mak`、`Bundles/Alone2/makefile.7zstar.gcc`、`Archive/Common/TempFileDecodedStream.cpp`（+5，POSIX 分支）、`Archive/TarChain/TarChainHandler.cpp`（+11／−1）、`Compress/ZstdEncoder.cpp`（一行註解）、`build/linux/*`。 |
| 待 Windows 端 | Windows 重建＋`Test-Smoke.ps1`（`TempFileDecodedStream.cpp` 的 `#ifndef _WIN32` 段、`TarChainHandler.cpp` 的宣告順序）。 |

### R4 審查後保留的小項（不改，留給下一次動這兩支腳本時）

- `interop-check.sh`：manifest 在三處各解析一次（向量數、集合比對、逐列迴圈），改其中一處會不一致；`SPARSE_SIZE` 在全域從 manifest 的中文句子解析，只有 linux 段用得到；`SHA256SUMS` 的涵蓋範圍沒有和 manifest 比對（新增向量忘了更新 `SHA256SUMS` 時，傳輸核對不會計入失敗）；`sums_bad` 數的是「非 OK 行」而非檔數（`sha256sum` 另印 WARNING 行），判定正確但數字會偏多。
- `test-smoke.sh` 的 `ulimit -v` 對照只在 4 核機器實測過，`-mmt=1` 後是否在更多核心的機器上穩定，待 CI 或下一輪驗。
