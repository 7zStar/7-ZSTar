# 7-ZSTar：Linux（gcc）建置與使用

在 Linux 上用 gcc 編出原生命令列 `7zz`，內含 7-ZSTar 的全部新 codec 與一步串聯格式。本檔是 Linux 移植的入口；設計、證據與限制的細節在文末「相關文件」。

本檔的每一條指令都在乾淨目錄實際跑過。

## 需求

- 實測環境：Ubuntu 24.04.5 LTS、x86-64、`gcc`／`g++` 13.3.0（`13.3.0-6ubuntu2~24.04.1`）、GNU Make 4.3、4 核。其他發行版、其他 gcc 版本、其他架構**沒有驗證**（見「已知限制」）。
- 建置需要的 apt 套件：`build-essential`（或只裝 `g++` 與 `make`）。不需要 `cmake`、`asmc`／`jwasm`、`perl`、`pkg-config`，也不需要任何第三方開發套件——所有函式庫（zstd、brotli、lz4、lz5、lizard、fast-lzma2）都已經 vendored 在 `C/`。
- 測試需要的 apt 套件：`zstd brotli lz4 libarchive-tools`（`libarchive-tools` 提供 `bsdtar`）。`tar` 與 `perl` 在標準 Ubuntu 映像裡已有；沒有 `perl` 時 `test-smoke.sh` 改用 `/dev/urandom` 產填充資料。
- 是否需要 root：**建置、測試、執行都不需要**。只有 `apt-get install` 本身需要 root（或 `sudo`），以及把 `7zz` 複製到 `/usr/local/bin` 這類系統目錄時。
- 全新容器的 apt 索引可能是空的，`apt-get install` 會報 `E: Unable to locate package`；先 `apt-get update`。

```bash
sudo apt-get update
sudo apt-get install -y build-essential                    # 建置
sudo apt-get install -y zstd brotli lz4 libarchive-tools   # 測試用（可選）
```

## 建置

```bash
cd CPP/7zip/Bundles/Alone2
make -j"$(nproc)" -f makefile.7zstar.gcc
```

- 入口是 fork 自己的 `makefile.7zstar.gcc`（`include` 上游的 `cmpl_gcc.mak`——它自己再 `include` `var_gcc.mak`、`warn_gcc.mak` 與 make 工作目錄裡的 `makefile.gcc`——然後 `include` `CPP/7zip/7zstar_gcc.mak`；第二輪 R1.4 改成這樣，取代原本手抄的三行 include）。**不要**直接用上游的 `makefile.gcc`：它不含 fork 的 codec 與 handler，會在連結階段失敗。
- 產物：`CPP/7zip/Bundles/Alone2/b/g/7zz`（物件檔也在 `b/g/`）。可用 `O=<目錄>` 改輸出位置。整個 `b/` 約 16 MB。
- 實測（2026-11-04，Ubuntu 24.04.5、gcc 13.3.0、`-j4`，從 `rm -rf b _o` 後的乾淨目錄）：

  | 項目 | 值 |
  |---|---|
  | exit code | 0 |
  | 警告／錯誤 | 0／0（`-Werror -Wall -Wextra` 加 `warn_gcc.mak`，官方警告集） |
  | 物件數 | 442 個 `.o` |
  | 時間 | 約 35～44 秒（`real`，4 核；本次兩次實測 37.3、34.9 秒，G4 實測 40.7 秒） |
  | `7zz` 大小 | 4,910,392 bytes |
  | sha256 | `db08c52aec453a3d0078b5fb158d3edcf5c9ed98a0db70448f3f4cfc46ab8766`（第二輪修正之後；第一輪是 `0469648c7fd362ffcad2ea60c05804533d63fac3772058ad44c9a3685140cf84`，差異只來自第二輪改的兩個 fork 自有 .cpp（`TempFileDecodedStream.cpp`、`TarChainHandler.cpp`；`ZstdEncoder.cpp` 只換了一行註解，不影響目的碼）） |

  大小與 sha256 只對**這個 commit 的原始碼、gcc 13.3.0-6ubuntu2~24.04.1、x86-64 這組環境**成立（同一環境下重建的結果相同，可重現）；換 gcc 版本、換 glibc 或換旗標，值就會不同，不能拿來當驗收條件。
- 再跑一次同樣的 `make` 應印 `make: Nothing to be done for 'all'.`。
- 上游的 gcc makefile 不追蹤標頭相依（沒有 `-MMD`）：改了 `.h` 之後先 `make -f makefile.7zstar.gcc clean` 再建，否則會拿到舊物件。
- 清掉重建：上游 `7zip_gcc.mak` 有 `clean` 目標，經 `makefile.7zstar.gcc` 可用（實測 exit 0）：

  ```bash
  make -f makefile.7zstar.gcc clean    # 刪掉 b/g/ 下的 7zz 與全部 442 個 .o，留下空的 b/g/
  rm -rf b _o                          # 連目錄一起清掉（_o 在本線不會產生，寫上只是相容舊習慣）
  ```
- 偵錯版：`make -j"$(nproc)" -f makefile.7zstar.gcc DEBUG_BUILD=1 O=b/gd`（`-g`、不帶 `-DNDEBUG`、assert 啟用；實測 exit 0、0 警告、約 44 秒，`7zz` 37,460,704 bytes）。建議像這樣用 `O=` 指到另一個目錄，不要和一般版混在 `b/g/`。

## 安裝與使用

`7zz` 是單一可執行檔（`ldd` 實測只連 `libstdc++`、`libm`、`libgcc_s`、`libc`，沒有其他外部檔案），複製到 `PATH` 上的任何目錄即可：

```bash
sudo install -m 0755 CPP/7zip/Bundles/Alone2/b/g/7zz /usr/local/bin/7zz     # 系統層
install -m 0755 CPP/7zip/Bundles/Alone2/b/g/7zz ~/.local/bin/7zz            # 只給自己（~/.local/bin 要在 PATH 裡）
```

用法與上游 7-Zip 的 `7zz` 相同。以下例子都實跑過（`proj/` 是含 1.3 MB 文字檔與 300 KB 亂數檔的測試目錄）：

```bash
7zz i                                      # 看註冊的格式與 codec；banner 第一行含 7-ZSTar
7zz i | grep -E 'zstd|brotli|lz4|lz5|lizard' # 單檔格式
7zz a -tzstd a.txt.zst proj/a.txt          # 單檔 .zst
7zz a -ttar.zst proj.tar.zst proj          # 一步 tar+zstd
7zz a -t7z -m0=brotli -mx=9 proj.7z proj   # .7z 內使用 brotli
7zz l proj.tar.zst                         # 直接列出 tar 內成員（不必先解壓外層）
7zz t proj.tar.zst                         # 測試
7zz x -y -oout proj.tar.zst                # 解到 out/
```

實跑結果：`a -tzstd` 後 `t`／`x` 解回與原檔 `cmp` 一致；`a -ttar.zst` 後 `l` 直接列出 `proj/a.txt`、`proj/sub/r.bin` 等成員；`a -t7z -m0=brotli` 後 `l -slt` 顯示 `Method = BROTLI`，`x` 解回的 `sha256sum -c` 全部 OK。

可用的新格式與 codec 見「支援範圍」。其他 `-m0=` 名稱：`zstd`、`brotli`、`lz4`、`lz5`、`lizard`、`flzma2`（在 `.7z` 清單上顯示為 `LZMA2`）。

## 測試

先建置（上一節），再從 repo 根目錄跑。兩支腳本都是 bash，都不需要 root；`b/g/7zz` 是預設路徑，也可以傳別的。

```bash
build/linux/test-smoke.sh CPP/7zip/Bundles/Alone2/b/g/7zz
build/linux/interop-check.sh all --7zz CPP/7zip/Bundles/Alone2/b/g/7zz
```

| 腳本 | 內容 | 預期輸出（實跑，2026-11-04） |
|---|---|---|
| `test-smoke.sh` | 79 個檢查：banner、格式數、每種 codec 來回、一步串聯建立與 drill-down、mt-brotli 容器、`-mmt=0` 強制 raw、截斷檔回 `Unexpected end of data`、壞檔回 `Data Error`、oversize 上限等 | 79 行 `PASS`、0 行 `FAIL`，最後一行 `passed=79 failed=0`，exit 0（約 2～3 秒）。2026-11-04 實跑是 77 個；`trunc-prefix.br` 的 2 個檢查 2026-11-06 移植，尚未在 Linux 執行過 |
| `interop-check.sh all` | `test/interop/windows/` 的 25 個 Windows 產物、`test/interop/linux/` 的 37 個向量、與 apt 的 `zstd`／`brotli`／`lz4`／`tar`／`bsdtar` 互相解壓 | `windows summary: 25/25 PASS`；`linux summary: 37 vectors; UPSTREAM-LIMIT=4 PASS=32 REJECTED-CLEAN=1; same-as-Windows 37/37`；最後 `rows=107 unexpected=0`，exit 0（約 10～11 秒） |

- 需要的 apt 工具：`zstd`、`brotli`、`lz4`、`bsdtar`（`libarchive-tools`）、GNU `tar`；`perl` 可選。缺工具時 `test-smoke.sh` 對該檢查印 `SKIP`（不算過也不算失敗，所以 `passed` 會小於 79），`interop-check.sh` 的 apt 互解列則無法完整執行。要得到上面的預期數字，四個 apt 套件都要裝。
- `UPSTREAM-LIMIT=4`、`REJECTED-CLEAN=1` 是**預期**結果，不是失敗：見「已知限制」。
- 帶 sanitizer 的 7zz 不要跑 `test-smoke.sh`：其中 9 個 `ulimit -v` 檢查會因為 sanitizer 要映射大塊位址空間而必然失敗（`REPORT.md`「額外驗證」）。要看得到符號化的堆疊，sanitizer 建置另加 `LFLAGS_STRIP=`（上游預設 `-s` 會剝掉符號；命令列覆寫，不改 makefile）。
- 逐檔結果表與環境細節在 `REPORT.md`。
- CI：`.github/workflows/build.yml` 的 `linux` job（`ubuntu-24.04`）跑同樣的建置（斷言 log 內 0 行 warning）、`test-smoke.sh` 與 `interop-check.sh all`，並把 `7zz` 上傳為 artifact `7-ZSTar-linux-x64`。

## 支援範圍

- **只有 CLI：`CPP/7zip/Bundles/Alone2` 的 `7zz`。** 這是本線唯一建置、唯一驗證的目標。沒有 GUI（上游也沒有 Linux GUI）。
- 上游其他 Linux 目標——`7za`、`7zr`、`7z.so`（`Format7zF`）——**不支援**：它們的上游 gcc 清單沒有 fork 改過的上游 handler 所需的物件（`RewindableDecodedStream.o` 等），預期連結失敗（推論，未實測）。靜態 `7zzs`（`COMPL_STATIC=1`）第二輪起可建置（`7zzs i` 與 `7zz` 相同），未跑 smoke，見已知限制第 6 點。
- fork 新增、在 `7zz` 裡可用的東西（`7zz i` 實測列出）：

  | 類別 | 名稱 |
  |---|---|
  | 單檔格式 | `zstd`（`.zst`、`.tzst`）、`brotli`（`.br`、`.tbr`）、`lz4`（`.lz4`、`.tlz4`）、`lz5`（`.lz5`、`.tlz5`）、`lizard`（`.liz`、`.tliz`） |
  | 一步串聯格式 | `tar.zst`、`tar.br`、`tar.lz4`、`tar.lz5`、`tar.liz`（上游本來就有 `tar.gz`、`tar.bz2`、`tar.xz`） |
  | `.7z` 內的 codec | `ZSTD`、`BROTLI`、`LZ4`、`LZ5`、`LIZARD`、`FLZMA2`（fast-lzma2；另有解碼用的 `ZSTD-WZ`） |
  | 多執行緒 | zstd 走 libzstd 自己的 MT；brotli／lz4／lz5／lizard 走 `C/zstdmt` 的 skippable 容器；fast-lzma2 自帶執行緒池 |

## 已知限制

每一條都有對應的實測證據，括號內是出處：

1. **pax GNU sparse 1.0 不展開**（上游 7-Zip 相同的限制）。bsdtar 預設格式會把全零的檔寫成 GNU sparse 1.0，`7zz` 解成 `GNUSparseFile.0/zeros.bin` 這類壓實檔（大小 4608，應為 1 MiB）；`test/interop/linux/` 有 4 個這樣的向量，判定為 `UPSTREAM-LIMIT`，與 Windows 結果逐位元組相同。舊式 GNU sparse（type `S`）可正確展開。（`REPORT.md`「與 Windows 結果的差異」第 2 點；`test/interop/REPORT.md` 第 8 節）
2. **lz4 legacy frame 乾淨拒絕。** `7zz` 讀 legacy magic（`02 21 4C 18`）的 `.lz4` 回 `Open ERROR: Cannot open the file as [lz4] archive`、exit 2，不會 crash 也不會是 `Unspecified`。（`REPORT.md`「與 Windows 結果的差異」第 1 點）
3. **獨立 `.br`／`.lz4` 加 `-mmt` 不產生 skippable 容器。** 這是 fork 既定設計（Windows 同）：`a -tbrotli|-tlz4 -mmt=4` 的檔頭仍是裸格式（`AF FF …`／`04 22 4D 18`），讀取端才把 `-mmt` 當格式選擇器；容器出現在 `.7z` 路徑（`-t7z -m0=brotli|lz4 -mmt=4`，封包流為 `50 2A 4D 18`），`.lz5`／`.liz` 與其 `tar.*` 則無條件寫容器。因此「獨立檔 `-mmt=4` 產生容器」這個預期並不成立。（`DESIGN.md`「G3 勘誤與結果」；`REPORT.md`「未完成與原因」）
4. **lz5／lizard 沒有外部獨立實作可互通。** Ubuntu 沒有這兩個格式的套件，也不從原始碼編其他工具；只驗證了「7-ZSTar（Windows 產）→ 7-ZSTar（Linux）」與 Linux 自己來回。（`REPORT.md`「未完成與原因」；`DESIGN.md` 附錄 B）
5. **TSan 發現的 `tar.gz` 解構順序問題已在第二輪修正。** `CPP/7zip/Archive/TarChain/TarChainHandler.cpp` 的 `gzipCrcStream` 原本宣告在 `CStreamBinder binder` 之前，函式返回時 `binder` 先解構、`~CBinderInStream` 才回呼它，TSan 每次重現 `use of an invalid mutex`；現在宣告移到 `binder` 之後（反向解構，先釋放 `gzipCrcStream`），同一腳本改前 exit 66、改後 0 報告（`REPORT.md`「第二輪」段）。**仍未修**：lz4／lz5／lizard／brotli 解碼器進度計數器的良性資料競爭（`*Decoder.cpp:28/67`，承襲 mcmilk，只影響進度顯示）。ASan＋UBSan＋LSan 無報告。（`REPORT.md`「額外驗證」第 1、2 點與「第二輪」段）
6. **未驗證的組合**：其他架構（arm64、32 位元 x86）、`USE_ASM=1`（本環境沒有 `asmc`／`jwasm`）、`ST_MODE=1`（單執行緒）、`-flto`、clang 下的官方警告集（clang 18.1.3 只用預設旗標驗過）、Ubuntu 24.04 以外的發行版與 gcc 版本。靜態 `7zzs`（`make -f makefile.7zstar.gcc COMPL_STATIC=1`）第二輪已建置通過（exit 0，`7zzs i` 與 `7zz` 相同；只有 ld 對上游 `getpwuid`／`getgrgid` 的靜態連結警告），但沒有拿 `7zzs` 跑 smoke。（`DESIGN.md`「預估風險」與附錄 B；`REPORT.md`「未完成與原因」、「第二輪」段）
7. **Windows 側重建已在 Windows 端驗證（2026-11-04，第一輪）。** 第一輪改了兩個 fork 檔（`TempFileDecodedStream.cpp` 的 `#ifdef _WIN32`、`ZstdEncoder.cpp` 的 `#ifdef _MSC_VER`）；Windows 端 `Build.ps1 -Clean` x64 17/17 零警告、`Test-Smoke.ps1` 61/61、`Test-Interop.ps1` 對 37 個 Linux 向量 32 PASS／1 REJECTED-CLEAN／4 UPSTREAM-LIMIT，與移植前相同。**第二輪又改了三個 fork 自有 .cpp，Windows 重建尚待驗證**：`TempFileDecodedStream.cpp`（`#ifndef _WIN32` 內把解碼明文暫存檔的建立模式設為 `0600`，Windows 分支不動）、`TarChainHandler.cpp`（上述宣告順序，純 C++、跨平臺）、`ZstdEncoder.cpp`（只改一行註解）。

## 官方檔改動清單

**無。** 上游的建置檔（`7zip_gcc.mak`、`Arc_gcc.mak`、各 `makefile.gcc`、`var_gcc*.mak`、`warn_gcc*.mak`、`cmpl_*.mak`）與 vendored 的 `C/` 都沒有改動。清單與理由見 `build/linux/DESIGN.md` 的「官方檔改動清單」。

驗證指令與實跑結果（2026-11-04）：

```text
$ git diff --stat <移植前的 commit> -- 'CPP/7zip/*.mak' 'CPP/7zip/Bundles/**/*.mak' 'CPP/7zip/Bundles/**/makefile.gcc' 'C/'
 CPP/7zip/7zstar_gcc.mak | 249 ++++++++++++++++++++++++++++++++++++++++++++++++
 1 file changed, 249 insertions(+)
```

唯一出現的 `CPP/7zip/7zstar_gcc.mak` 是 fork 新增的檔，不是上游檔；`C/` 沒有任何輸出，代表零改動。

本線動到的 fork 自有檔（都不屬於官方建置檔）：

| 檔 | 內容 |
|---|---|
| `CPP/7zip/7zstar_gcc.mak`（新） | 物件清單、per-group 旗標、靜態 pattern rule、接上連結目標 |
| `CPP/7zip/Bundles/Alone2/makefile.7zstar.gcc`（新） | bundle 入口，9 行 |
| `CPP/7zip/Archive/Common/TempFileDecodedStream.cpp` | 3 處 `#ifdef _WIN32`：Windows 分支逐字保留原行，`#else` 為 POSIX 版（`write_full`／`read_part`／`seek`）；只新增行 |
| `CPP/7zip/Compress/ZstdEncoder.cpp` | `#pragma warning` 包進 `#ifdef _MSC_VER`；只新增行 |
| `.gitignore` | 加 `_o/`、`b/` |
| `.gitattributes` | 新 makefile 與 `*.sh` 用 `eol=lf` |
| `build/linux/*` | 本目錄的文件與兩支測試腳本 |

## 相關文件

- [`DESIGN.md`](DESIGN.md)：物件清單差集、makefile 方案、官方檔改動清單、vendored 相依、warning 策略、風險。
- [`REPORT.md`](REPORT.md)：驗證報告——環境、建置、smoke、25＋37 向量逐檔結果、與 Windows 的差異、未完成項。
- [`../../test/interop/REPORT.md`](../../test/interop/REPORT.md)：Windows 側的互通報告（含 Linux 工具互讀與第 8 節 Windows 結果）。
