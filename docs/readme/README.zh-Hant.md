<!-- synced-with: README.md @ 6da4c54 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · **繁體中文** · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [한국어](README.ko.md) · [العربية](README.ar.md) · [Esperanto](README.eo.md)

**對現代 Windows 11 使用者更友善的 7-Zip 分支版：右鍵選單第一層就有它，可以用 zstd 壓縮，一次做出 tar.zst。**

[下載](https://github.com/7zStar/7-ZSTar/releases/latest) · [官方網站](https://www.7zstar.com) · [更新紀錄](../../CHANGELOG.md)

## 為什麼用 7-ZSTar

- **不用再點「顯示其他選項」。** 在 Windows 11 上，7-ZSTar 就在右鍵選單的第一層。
- **一步做出 tar.zst。** 把資料夾壓成 .tar.zst，或把它解開，都只要一步，磁碟上不會留下 .tar。官方 7-Zip 做不出 .tar.zst，解開它也要兩步，中間會先產生一個 .tar。
- **比 7z 快 10 倍左右。** 拿實際的專案資料夾來壓，tar.zst 比 7z 快 10 到 18 倍。

## 速度實測

| 資料夾 | 檔案數 | 原始大小 | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 秒／76.7 MB | 38.4 秒／51.8 MB | **3.8 秒**／59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 秒／107.8 MB | 54.8 秒／65.7 MB | **3.6 秒**／83.4 MB |
| Python `.venv`（含大型二進位檔） | 11,654 | 671 MB | 25.5 秒／249.5 MB | 100.8 秒／167.2 MB | **5.6 秒**／210.9 MB |

tar.zst 比 zip 小 15% 到 23%，速度也不輸 zip。最小的檔案還是 7z 做得出來（tar.zst 比它大 15% 到 27%），但 7z 花的時間多很多。解壓縮時，三種格式花的時間差不多。

三種格式都用預設設定；7-ZSTar 26.05.1 x64、Intel Core Ultra 7 155H、NVMe SSD，每項跑 3 次取中位數，2026 年 11 月測。

## 支援的格式

- **一步壓縮：** tar.zst、tar.br、tar.lz4、tar.lz5、tar.liz、tar.gz、tar.bz2、tar.xz
- **一步解壓縮：** 上面全部，再加上 tar.lzma 和 tar.Z
- **新增的編碼器：** zstd、brotli、lz4、lz5、lizard（可以單獨使用，也可以用在 .7z 裡），以及 fast-lzma2（另一種 LZMA2 編碼器）
- 官方 7-Zip 能處理的格式，這裡全部都能用。

## 下載

大多數人下載全機安裝的 x64 `.msi` 就對了，在 [Releases](https://github.com/7zStar/7-ZSTar/releases/latest) 頁面。

| | 全機安裝 `.msi` | 只裝給自己 `-user.msi` | 免安裝 `.zip` |
|---|---|---|---|
| 需要系統管理員權限 | 要 | 不用 | 不用 |
| 右鍵選單 | Windows 11 上在第一層 | 傳統選單（Windows 11 上在「顯示其他選項」裡） | 沒有 |
| [開始] 功能表項目 | 有 | 有 | 沒有 |

每一種也都有 x86 和 arm64 版，請選和你的 Windows 相符的那個。在 64 位元 Windows 上，x86 版可能沒有右鍵選單；arm64 版還沒在實機上跑過。7-ZSTar 可以和官方 7-Zip 同時安裝，互不影響。

**第一次執行時，Windows 可能會跳出警告。** 這些檔案沒有程式碼簽章，所以 SmartScreen 可能會擋下來，顯示「Windows 已保護您的電腦」（可能要先點「其他資訊」才看得到「仍要執行」）；在開啟了智慧型應用程式控制（Smart App Control）的 Windows 11 上，`.msi` 會直接被封鎖。每個發行版都附有 `SHA256SUMS`，可以用來核對你下載的檔案。怎麼核對、遇到智慧型應用程式控制該怎麼辦，請看 [安裝說明](../install/INSTALL.zh-Hant.md#未簽章的安裝包smartscreen-與智慧型應用程式控制)。

**關於第一層選單：** 在 Windows 11 上，全機安裝的 `.msi` 會加裝一個用自簽憑證簽署的小套件，並信任這張憑證，這是 Windows 讓程式進入第一層的條件。解除安裝時兩者都會移除。如果不想這樣，用 `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0` 安裝即可。這個套件只替執行安裝的帳號註冊，其他帳號會各自註冊。

檔案關聯、解除安裝和「只裝給自己」版的細節，都寫在 [安裝說明](../install/INSTALL.zh-Hant.md)。

## 命令列

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

在 PowerShell 裡，格式參數要加引號：`7z a "-ttar.zst" backup.tar.zst docs`。不加的話，PowerShell 會把它拆成兩段，結果做出一個叫 `.zst` 的檔案。命令提示字元（cmd）不用加。

## 小提醒

- **關掉「將 7-ZSTar 整合到快顯功能表中」**（檔案管理員的「工具 > 選項 > 7-ZSTar」）會讓右鍵選單裡的 7-ZSTar 消失，這點和官方 7-Zip 一樣。全機安裝版只要用系統管理員身分執行檔案管理員，就能再打開。「只裝給自己」版沒辦法這樣打開（會顯示「存取被拒」）；請重新執行原本的 `.msi`，選 *Repair*（修復）。
- **在 Windows 11 上用靜默或遠端方式安裝**（例如透過 SSH，或用部署工具），安裝會成功，但第一層選單不會註冊，7-ZSTar 只會出現在「顯示其他選項」裡。[安裝說明裡有詳細說明](../install/INSTALL.zh-Hant.md#windows-11-右鍵選單)。
- **解壓縮 tar.br、tar.lz4、tar.lz5、tar.liz 或 tar.Z** 對你來說一樣是一步完成，只是過程中會先解到暫存檔，結束後自動刪除。

## 系統需求

Windows 7／Server 2008 R2 以上（x64、x86），arm64 需要 Windows 10 以上。不用另外安裝任何東西。已在 64 位元的 Windows 7 SP1（已裝後續更新）、Windows 10 和 Windows 11 上實測；[測了哪些項目](../install/INSTALL.zh-Hant.md#系統需求)。Linux 上有命令列版本，需要自行建置；不支援 macOS。

## 說明文件

「說明 > 內容」和 F1 會開啟官方 7-Zip 的說明檔 `7-zip.chm`。裡面寫的都是「7-Zip」，也沒有涵蓋 7-ZSTar 新增的功能；這些請看本頁和 [更新紀錄](../../CHANGELOG.md)。如果找不到說明檔，同樣的選項會改為在線上開啟這一段。

想自己建置 7-ZSTar，請看 [build/README.md](../../build/README.md)；要合併上游的新版本之前，請先讀 [MAINTAINING.md](../../MAINTAINING.md)。

<a id="donate"></a>

## 贊助

7-ZSTar 可以免費使用，贊不贊助都一樣。如果它幫你省了一些時間，想說聲謝謝，可以把加密貨幣轉到下面的地址。這筆錢給 DraftingDreamer（築夢天地）個人，用在我自己的開發開銷上，不換取功能、協助或任何後續承諾。

Ethereum 或 Polygon 鏈上的資產都收，ETH、POL、USDT、USDC 或其他代幣都歡迎。兩條鏈用同一個地址。

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="贊助地址的 QR Code">

- 只收 Ethereum（ERC20）和 Polygon 鏈上的轉帳。若兩者都有，建議用 Polygon，手續費通常比較低。
- 官方地址只有這一個，我不會要求任何人改轉到別的地址。
- 鏈上轉帳無法撤回，所以無法退款。

在 GitHub 幫 7-ZSTar 按星星，或介紹給朋友，也是幫忙。

## 授權

採用 LGPL v3，見 [LICENSE](../../LICENSE)。有些部分另有條款：RAR 解壓縮受 unRAR 限制約束，所以含 RAR 支援的版本並不完全是 LGPL v3。完整清單在 [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md)，各元件的著作權聲明在 [NOTICE](../../NOTICE)。

感謝每一位為 7-Zip、壓縮演算法和整個開源世界付出時間的人。沒有你們，就沒有 7-ZSTar。
