<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/logo/wordmark-dark@3x.png">
  <img src="docs/logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](README.md) · **繁體中文** · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [Esperanto](README.eo.md)

**對現代 Windows 11 使用者更友善的 7-Zip 分支版：右鍵選單第一層就有它，可以用 zstd 壓縮，一次做出 tar.zst。**

[下載](https://github.com/7zStar/7-ZSTar/releases/latest) · [官方網站](https://www.7zstar.com) · [更新紀錄](CHANGELOG.md)

## 為什麼用 7-ZSTar

- **不用再點「顯示其他選項」。** 用全機安裝的 MSI 裝好，7-ZSTar 直接出現在 Windows 11 右鍵選單第一層。
- **一次到位，磁碟上沒有 .tar。** 壓縮成 tar.zst、解開 tar.zst 都是一步完成，兩個方向都不會寫出 .tar。官方 7-Zip 不能壓縮成 .tar.zst，解壓縮也要先解出 .tar、再解一次。
- **比 7z 快 10 倍。** 壓縮實際的專案資料夾，tar.zst 比 7z 快 10 到 18 倍。

## 速度實測

| 資料夾 | 檔案數 | 原始大小 | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 秒／76.7 MB | 38.4 秒／51.8 MB | **3.8 秒**／59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 秒／107.8 MB | 54.8 秒／65.7 MB | **3.6 秒**／83.4 MB |
| Python `.venv`（含大型二進位檔） | 11,654 | 671 MB | 25.5 秒／249.5 MB | 100.8 秒／167.2 MB | **5.6 秒**／210.9 MB |

tar.zst 比 zip 小 15 到 23%，速度也不輸 zip。不過它比 7z 大 15 到 27%，最在乎檔案大小的話，還是選 7z。這裡比的是壓縮；解壓縮三者差不多，沒有速度優勢。

zip、7z、tar.zst 都用預設值壓縮。7-ZSTar 26.05.1 x64（7z.exe）、單機（Intel Core Ultra 7 155H、NVMe SSD）、三個實際專案資料夾、3 輪中位數、2026-11。

## 支援的格式

- **一步壓縮（8 種）**：tar.zst、tar.br、tar.lz4、tar.lz5、tar.liz、tar.gz、tar.bz2、tar.xz
- **一步解開（10 種）**：以上 8 種，加上 tar.lzma、tar.Z
- **新增的壓縮方式**：zstd、brotli、lz4、lz5、lizard，可以當獨立格式，也可以用在 .7z 裡；另有 fast-lzma2 可替代 LZMA2。
- 7-Zip 原本支援的格式都還在。

解開 tar.br、tar.lz4、tar.lz5、tar.liz、tar.Z 時，操作上一樣是一步，但程式會先解到暫存檔，用完刪除。

## 命令列

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

在 PowerShell 裡，格式參數要加引號，例如 `7z a "-ttar.zst" backup.tar.zst docs`。不加的話，PowerShell 會把 `-ttar.zst` 拆成兩個參數，7z 就會建出一個名叫 `.zst` 的檔案。命令提示字元（cmd）不用加引號。

## 下載與安裝

| | 全機安裝 `.msi` | 個別使用者 `-user.msi` | 免安裝 `.zip` |
|---|---|---|---|
| 安裝給 | 這台電腦所有帳號 | 目前帳號 | 不用安裝 |
| 需要系統管理員權限 | 是 | 否 | 否 |
| 右鍵選單 | Windows 11 第一層 | 在「顯示其他選項」裡 | 沒有 |
| 開始功能表 | 有 | 有 | 沒有 |

三種都有 x64、x86、arm64 版，請選和 Windows 相同的架構：在 64 位元 Windows 上裝 x86 版，可能沒有右鍵選單。arm64 版還沒在實機上跑過。可以和官方 7-Zip 同時安裝，互不影響。

**Windows 可能會對這些下載顯示警告。** 安裝程式和程式檔都沒有經過憑證授權單位簽發的程式碼簽署，所以第一次執行時，Microsoft Defender SmartScreen 可能會擋下來並顯示警告；在已開啟 Smart App Control 的 Windows 11 電腦上，`.msi` 安裝檔則會直接被封鎖，而且沒有任何可以繼續的選項。這不代表檔案有問題：每個 Release 都附有 `SHA256SUMS`，可以用來核對你下載的檔案是否和發布的一致。核對方法、Smart App Control 對你的影響，以及核對無誤後如何繼續安裝，見 [docs/INSTALL.md](docs/INSTALL.md#unsigned-packages-smartscreen-and-smart-app-control)（目前只有英文）。

**關於第一層選單**：Windows 11 只讓帶有套件身分的程式進第一層，所以全機 MSI 會安裝一個自簽憑證簽署的小型 MSIX 套件，並信任這張憑證；解除安裝時一併移除。不想信任的話，用 `msiexec /i 7-ZSTar-<版本>-<架構>.msi SPARSE=0` 安裝，選單就會留在「顯示其他選項」裡。套件只替執行安裝的帳號註冊，其他帳號要另外註冊。

完整說明（含檔案關聯與解除安裝）在 [docs/INSTALL.md](docs/INSTALL.md)，目前只有英文。

## 已知限制

- **取消勾選「整合到右鍵選單」會移除右鍵選單的註冊。** 在檔案管理員（`7zFM`）的「工具 ▸ 選項 ▸ 7-ZSTar」分頁，有一個「將 7-ZSTar 整合到快顯功能表中」核取方塊。和官方 7-Zip 一樣，取消勾選會刪掉安裝程式建立的殼層擴充註冊（`CLSID` 鍵），7-ZSTar 就從右鍵選單消失。全機安裝版以系統管理員身分執行檔案管理員，可以再勾回來；個別使用者版勾不回來：再勾選會跳出「存取被拒」，選單也不會回來。要補回，請重新執行當初的 `.msi` 安裝檔，選「修復」。
- **第一層選單只有在互動式登入的工作階段安裝時才會註冊。** 從遠端或非互動的工作階段安裝全機 `.msi`（例如透過 SSH，或管理工具的靜默部署），安裝仍會回報成功，但 Windows 11 套件沒有註冊，只會出現「顯示其他選項」裡的傳統選單。詳情見 [docs/INSTALL.md](docs/INSTALL.md#the-windows-11-right-click-menu)。

## 系統需求

Windows 7 或 Windows Server 2008 R2 以上（x64、x86）；arm64 需要 Windows 10 以上。不用另外安裝執行環境。這個下限是依套件需求推得，比 Windows 11 舊的版本還沒有實測過。Linux 只提供自行建置的命令列版本，不支援 macOS。

## 專案定位

7-ZSTar 是對現代 Windows 11 使用者更友善的 7-Zip 分支版。7-Zip 的核心很出色，但有些地方沒跟上現在的使用方式：Windows 11 把它收在「顯示其他選項」裡，也不能壓縮成 zstd。7-ZSTar 補上這些缺口，其他操作都和 7-Zip 一樣，原本的使用習慣不用改。

## 說明文件

每個套件都附官方 7-Zip 的說明檔，從「說明」選單或按 F1 開啟，內容原封不動，所以寫的是「7-Zip」，也不含 7-ZSTar 新增的功能；新增的內容請看本頁與 [CHANGELOG.md](CHANGELOG.md)。

如果執行檔旁沒有說明檔，這些選項會改開本專案 GitHub 頁面的這一段（英文版）。

## 從原始碼建置

見 [build/README.md](build/README.md)。簡單說：裝好 VS2022 Build Tools（MSVC v143），再執行 `pwsh build\Build.ps1`。要合併上游新版前，先讀 [MAINTAINING.md](MAINTAINING.md)。

<a id="donate"></a>

## 贊助

7-ZSTar 可以免費使用，贊不贊助都一樣。如果它幫你省了一些時間，想說聲謝謝，可以把加密貨幣轉到下面的地址。這筆錢給 DraftingDreamer（築夢天地）個人，用在我自己的開發開銷上，不換取功能、協助或任何後續承諾。

Ethereum 或 Polygon 鏈上的資產都收，ETH、POL、USDT、USDC 或其他代幣都歡迎。兩條鏈用同一個地址。

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="docs/donate-qr.png" width="200" alt="贊助地址的 QR Code">

- 只收 Ethereum（ERC20）和 Polygon 鏈上的轉帳。若兩者都有，建議用 Polygon，手續費通常比較低。
- 官方地址只有這一個，我不會要求任何人改轉到別的地址。
- 鏈上轉帳無法撤回，所以無法退款。

在 GitHub 幫 7-ZSTar 按星星，或介紹給朋友，也是幫忙。

## 授權

LGPL v3，見 [LICENSE](LICENSE)。部分內容另有條款，例如 RAR 解壓縮受 unRAR 限制，因此含 RAR 支援的版本不是純 LGPL v3。完整清單見 [LICENSE-EXCEPTIONS.md](LICENSE-EXCEPTIONS.md)，各元件的版權聲明見 [NOTICE](NOTICE)。

## 致謝

7-ZSTar 站在許多人的肩膀上。謝謝每一位為 7-Zip、各種壓縮演算法和開放原始碼世界付出過的人，沒有你們，就沒有這個軟體。
