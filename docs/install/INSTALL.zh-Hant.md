<!-- synced-with: docs/INSTALL.md @ e3fa827 -->
# 安裝 7-ZSTar

[English](../INSTALL.md) · **繁體中文** · [한국어](INSTALL.ko.md) · [العربية](INSTALL.ar.md)

這份文件是 [README](../readme/README.zh-Hant.md) 簡短說明背後的細節：系統需求、SmartScreen 警告、智慧型應用程式控制（Smart App Control）、如何核對下載的檔案、三種安裝包、Windows 11 右鍵選單、檔案關聯與解除安裝。

## 系統需求

**Windows 7 或 Windows Server 2008 R2，x64 或 x86。arm64 則需要 Windows 10。**
不需要其他東西：C 執行階段是靜態連結的（`-MT`），所以執行檔除了 Windows 本身的 DLL 之外什麼都不匯入，不用另外裝可轉散發套件，也不需要 .NET。

這個下限是依安裝包的需求*推算*出來的，另外也做過實測：Windows 7 SP1（已裝後續更新，其中包含 PowerShell 5.1）、Windows 10 22H2 和 Windows 11，皆為 64 位元。在 Windows 7 與 10 上，測試的項目有：全機與個別使用者 x64 `.msi` 的安裝與解除安裝、安裝精靈、x64 `.zip`、所有新增的編碼器與一步 tar 格式、右鍵選單、檔案關聯與說明檔，以及在 64 位元 Windows 上執行的 x86 `.msi` 與 `.zip`。除此之外，Windows 上沒有測過其他環境：Windows 8 與 8.1、Windows Server、32 位元 Windows、arm64 實機，以及沒裝上述更新的 Windows 7，都沒有測。這個下限也比上游 7-Zip 的高，上游的執行檔在 Windows XP 上仍然載得進去。有三個原因把門檻拉到這裡，其中第二個是任何建置設定都無法改變的：

- `.msi` 宣告了 `InstallerVersion="500"`，而 Windows Installer 5.0 是隨「Windows Server 2008 R2 及更新版本，以及 Windows 7 及更新版本」發行的（[Microsoft][msi-versions]）。免安裝的 `.zip` 不經過 Windows Installer，但請看接下來兩點。
- **zstd 與 fast-lzma2 使用只有 Vista 以上才有的同步機制。** 兩者都在自己的標頭檔裡強制定義 `_WIN32_WINNT 0x0600`，並直接呼叫 `InitializeConditionVariable` / `SleepConditionVariableCS`，所以內含這些編碼器的兩個執行檔 `7z.dll` 與 `7za.exe` 會匯入四個 Windows XP 與 Server 2003 沒有的函式。上游的 `7z.dll` 一個也不匯入。
- 工具鏈：這些檔案是用 Visual Studio 2022 建置的，它支援的目標平台是 Windows 7 以上，Vista 與 Server 2008 都是「No」（[Microsoft][vs-targeting]）。連結後的子系統版本在 x64 與 x86 是 6.0，在 arm64 是 6.2，而 Windows on arm64 本來就是從 Windows 10 才開始。

Windows Vista 與 Server 2008 落在中間：執行檔載得進去，但工具鏈不支援它們，安裝程式在那裡也跑不起來，7-ZSTar 也沒有在上面測試過。

**Linux 只支援命令列版本的自行建置；不支援 macOS。**
這個分支用 gcc 透過自己的 makefile 建出原生的 `7zz`（`Alone2` 主控台程式），該 makefile 會引用上游的 makefile，且不修改上游任何一個：`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`。
只在 Ubuntu 24.04、gcc 13.3（x86-64）上建置並測試過：以上游的編譯旗標建置沒有任何警告，77 項冒煙測試全過，25 個在 Windows 上製作與 37 個在 Linux 上製作的互通測試向量，得到的判定和在 Windows 上相同。這次移植動到的兩個本分支專屬檔案，在 Windows 上照樣能不改地建置（乾淨的 x64 建置、冒煙測試與互通回讀全部通過）。沒有圖形介面。上游其他的 Linux 目標（`7za`、`7zr`、`7z.so`）不受支援：它們的 gcc 物件清單缺少本分支對上游格式處理程式所做的修改需要的部分，預期會在連結時失敗。其他架構、發行版與編譯器都沒有驗證過，macOS 從來沒有建置過，因此無法標示 `MACOSX_DEPLOYMENT_TARGET`。建置步驟、測試與已知限制在 `build/linux/README.md`；與 Linux 工具的互通性見 `test/interop/REPORT.md`。

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## 未簽章的安裝包、SmartScreen 與智慧型應用程式控制

**7-ZSTar 發行版中的安裝程式與程式檔，都沒有經過憑證授權單位的程式碼簽署**，本專案也沒有持有任何程式碼簽署憑證。因此 Windows 無法得知檔案是誰發布的，你第一次執行 `.msi`，或第一次執行 `.zip` 裡的程式時，Microsoft Defender SmartScreen 可能會擋下來並顯示警告。Microsoft 的開發人員文件把 “No signature”（沒有簽章）列為會顯示警告的情況之一，警告的標題是「Windows 已保護您的電腦」，使用者必須選擇「仍要執行」，應用程式才會執行（[Microsoft][smartscreen-rep]）。企業原則可以完全移除這個選項；遇到這種電腦，請詢問管理它的人。

發行版裡唯一*有*簽章的，是把 7-ZSTar 放進 Windows 11 右鍵選單第一層的那個小型套件，它在全機安裝的 `.msi` 裡面。它的憑證是自簽的，在建置這個套件時才產生，所以它不是憑證授權單位的簽章，也無法說明誰建置了這個套件；它做什麼，以及怎麼拒絕它，請見 [Windows 11 右鍵選單](#windows-11-右鍵選單)。

出現警告不代表檔案有問題，沒有警告也不代表檔案沒問題。你自己能核對的是：手上這份是否和發行頁面上發布的完全一樣。每個發行版都附有一個叫 `SHA256SUMS` 的檔案：每個安裝包一行，是 SHA-256 雜湊值，後面接檔名。

1. 把安裝包和 `SHA256SUMS` 從同一個發行頁面下載到同一個資料夾。
2. 在該資料夾開啟 PowerShell 進行比對。把名稱換成你下載的檔案：

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True` 表示兩個雜湊值完全相同。如果想自己看，可以改執行
   `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi`，再到 `SHA256SUMS` 裡找相同的檔名；比對時不分大小寫。
3. 如果得到 `False`，或是 `SHA256SUMS` 裡找不到該檔名，請不要執行：刪掉檔案，重新下載。如果還是對不上，請依 [SECURITY.md](../../SECURITY.md) 的說明回報。

`SHA256SUMS` 只涵蓋上傳到該發行版的檔案。自己建置同一個 tag 會得到不同的雜湊值（右鍵選單套件每次建置都用新的憑證簽署）；如果你寧可自己建置，每個發行版都會公開原始碼：見 [build/README.md](../../build/README.md)。

雜湊值核對無誤，而且你對檔案的來源也放心之後：

- **`.msi`**：照平常的方式啟動。如果 SmartScreen 擋下來，請選擇仍要執行的選項（英文版 Windows 上是 “Run anyway”）。警告視窗可能得先展開：在測試用的 Windows 10 上，要先點訊息下方的「其他資訊」連結，視窗才會出現「仍要執行」按鈕，在那之前只有不要執行檔案的按鈕。全機安裝的 `.msi` 接著會像其他安裝程式一樣，要求系統管理員核准。
- **`.zip`**：解壓縮後，從資料夾裡啟動 `7zFM.exe` 或 `7z.exe`。裡面的程式同樣沒有簽章，所以你第一次啟動每一個程式時，Windows 可能都會顯示同樣的警告。

SmartScreen 警告的依據是檔案的知名程度，不只是簽章；下載的人很少的檔案，即使有簽章也可能觸發警告。這裡的內容改變不了這一點，上面的步驟也沒有任何一步會關閉 SmartScreen。

### Windows 11 上的智慧型應用程式控制

有些 Windows 11 電腦開啟了更嚴格的保護，叫做**智慧型應用程式控制（Smart App Control）**。開啟時，Windows 會封鎖未簽章的檔案，除非 Microsoft 的雲端服務能為它背書，而新發行的版本通常沒有這樣的紀錄（[Microsoft][sac-faq]、[Microsoft][smartscreen-rep]）。和 SmartScreen 警告不同，這個封鎖沒有任何可以仍然執行該檔案的選項，Microsoft 的常見問題也說，無法為個別的應用程式略過智慧型應用程式控制。

在 Windows 11 Pro 25H2（組建 26200.8037）、已開啟智慧型應用程式控制的狀態下試用 7-ZSTar 26.05.1，結果如下：

- **`.msi` 安裝程式被封鎖了**，全機安裝版與個別使用者版都一樣。在繁體中文版 Windows 上，Windows Installer 顯示「系統禁用此安裝。請連絡系統管理員。」，同時 Windows 安全性通知說，智慧型應用程式控制封鎖了該檔案，因為 Windows 無法得知是誰發布的，而且它不是 Windows 認識的應用程式。沒有任何可以繼續的選項，`msiexec /i ... /qn` 回傳了 error 1625。英文版 Windows 上的訊息文字沒有查證過。
- **`.zip` 裡的程式可以執行。** 從免安裝 `.zip` 解壓縮出來的 `7zFM.exe`，在同一次測試中正常啟動。Windows 是否允許未簽章的程式執行，是它對該檔案的個別判斷，所以你的電腦上可能不一樣。
- 剛開啟智慧型應用程式控制之後，`.msi` 還能安裝幾分鐘，然後才開始被封鎖。原因沒有找到，所以剛開啟後安裝成功，並不代表安裝程式被允許。

所以在智慧型應用程式控制開啟的電腦上，**安裝程式無法安裝**，核對 `SHA256SUMS` 也改變不了這一點。能改變的，是到 Windows 安全性應用程式的智慧型應用程式控制設定裡把它關閉（以測試用的繁體中文版 Windows 來說：Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定）。測試中選擇關閉後立即生效，不用重新啟動，之後安裝程式就能安裝了。這是整台電腦的設定，這裡沒有任何地方要求你更改：由你自己決定，在受管理的電腦上則由你的系統管理員決定。

另外值得先知道的是，之後能不能再把它開回來。Microsoft 的常見問題說，較新的 Windows 更新讓智慧型應用程式控制可以在不重新全新安裝 Windows 的情況下再次開啟，所以在沒有這些更新的版本上，關閉可能就是永久的。在這裡測試的組建上，關閉之後仍然提供開啟的選項；那是測試結果，不是對你的版本所做的保證。

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## 安裝

共有三種安裝包，都由 `installer\Build-Package.ps1` 建置（個別使用者版要加 `-PerUser`）：

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| 安裝給 | 每個帳號 | 執行安裝的帳號 | - |
| 檔案總管右鍵選單 | 有 | 有，只有傳統選單（[見下](#個別使用者安裝包)） | 沒有 |
| [開始] 功能表項目 | 有 | 有 | 沒有 |
| 需要系統管理員 | 是 | 否 | 否 |
| 移除方式 | Apps & features（已安裝的應用程式） | Apps & features（已安裝的應用程式） | 刪除資料夾 |

請選擇和 Windows 本身相符的安裝包：32 位元 Windows 用 x86，64 位元 Windows 用 x64，Windows on Arm 用 arm64（arm64 安裝包有建置，但從來沒有實際執行過）。x86 的殼層擴充是 32 位元的，64 位元的檔案總管載入不了，所以在 64 位元 Windows 上，x86 的 `-user.msi` 完全沒有右鍵選單；x86 的 `.msi` 只有在 Windows 11 上才有，而且只限註冊過它的 Windows 11 套件的帳號（執行安裝的帳號，或是執行過 `-Register` 的帳號，見下文）。

MSI 一律安裝到 `Program Files\7-ZSTar`：和個別使用者版不同，它不讓你選資料夾，也會忽略命令列上的 `INSTALLFOLDER`，因為那個資料夾裡有安裝程式會以 SYSTEM 身分執行的指令碼，以及每位使用者的檔案總管都會載入的 DLL，而在別處（例如 `C:\` 底下）建立的資料夾，每位使用者都能寫入。它註冊的是自己的殼層擴充 CLSID 與自己的 `Software\7-ZSTar` 登錄機碼樹，所有右鍵選單機碼都命名為 `7-ZSTar`，所以既不會和官方 7-Zip 衝突，也不會移除官方 7-Zip 的項目。見 [installer/GUIDS.md](../../installer/GUIDS.md)。

它會執行一般的安裝精靈：welcome, licence, setup type, optional feature tree, finish（歡迎、授權、安裝類型、選用功能樹、完成）。安靜安裝照樣可以用，行為不變（`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`），因為 msiexec 在安靜模式下會跳過整個使用者介面流程。這個精靈只有英文，即使 Windows 設成其他語言也一樣（在繁體中文版 Windows 10 上看到的；`.msi` 沒有內建其他語言），結束頁面上的 *Launch 7-ZSTar File Manager* 預設是勾選的。

### Windows 11 右鍵選單

在 Windows 11 上，這個項目會出現在第一層選單，而不是像官方 7-Zip 和 WinRAR 那樣仍然埋在「顯示其他選項」底下。Windows 11 只有在殼層擴充帶有套件身分時，才會把它列在那裡，所以 MSI 會在程式旁邊附上一個只有身分的小型 MSIX 套件，並在安裝時註冊它。傳統的註冊方式也照樣保留：Windows 10 與 Windows 7 的右鍵選單只有一層，沒有「顯示其他選項」，這個項目就是靠它出現在選單裡；對還原了舊式右鍵選單的人，也靠它繼續運作。

那個套件是用**自簽憑證**簽署的，安裝程式會把這張憑證放進 `LocalMachine\TrustedPeople`：Windows 不會部署簽章無法串到任何受信任項目的套件。解除安裝時，會連同套件一起移除憑證。在 Windows 10 與 Windows 7 上，安裝程式兩者都不做：不加入憑證，也不註冊套件，選單完全由傳統的註冊方式提供。

如果你不想信任自簽憑證，可以只拒絕這一部分，其他都照常安裝：

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

這樣你只會得到傳統選單，所以在 Windows 11 上，7-ZSTar 會在右鍵選單裡，位於「顯示其他選項」底下。之後想啟用第一層項目，或是在一般安裝之後想復原：

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

信任那張憑證，表示 Windows 也會不加警告地接受**任何其他**用同一把金鑰簽署的套件。這把金鑰只用在這一個套件上，解除安裝時也會一併收回，但這就是你同意的內容：上面的 `SPARSE=0` 就是拒絕它的方法。

套件的註冊是以使用者為單位的，而且安裝程式只替執行安裝的人註冊。這會有兩個後果：

- 同一台電腦上的第二個帳號，只會有傳統選單，直到它用同一個指令碼加上 `-Register` 執行為止。
- 解除安裝時，只會替執行解除安裝的人取消註冊。如果是別人註冊的，他的註冊在解除安裝後依然存在，並指向一個已經不存在的資料夾；那個帳號用 `Get-AppxPackage 7-ZSTar | Remove-AppxPackage` 清除它。

**已知限制：只有在互動式、已登入的工作階段中安裝時，才會註冊第一層選單。** 從遠端或非互動的工作階段安裝全機 `.msi`（透過 SSH，或是管理工具的靜默部署），仍然會回報成功，但 Windows 11 套件沒有註冊，所以只會出現「顯示其他選項」底下的傳統選單。測試中，從 SSH 工作階段（工作階段 0）執行 `msiexec /i ... /qn` 的結束代碼是 0，但 `Setup-ShellIntegration.ps1` 回報了 `registration failed: 0x80070005`（拒絕存取）；同一個 `.msi` 從系統管理員的主控台工作階段安裝，就能正常註冊。

`-Status` 會印出哪些項目已就位、哪些沒有。

### 個別使用者安裝包

`7-ZSTar-<version>-<arch>-user.msi` 只為目前的帳號安裝，裝到 `%LOCALAPPDATA%\Programs\7-ZSTar`，不會跳出使用者帳戶控制（UAC）提示。它註冊的所有東西都放在 `HKCU` 底下；這個安裝包不會寫入任何東西到 `HKLM`（Windows Installer 自己的記錄除外）。以下是它沒有像全機安裝包那樣做的事：

- **沒有 Windows 11 第一層選單。** 在 Windows 11 上，7-ZSTar 在右鍵選單裡，位於「顯示其他選項」底下。第一層項目需要整台電腦都信任那張自簽憑證，而這需要系統管理員：在 Windows 11 上的實測顯示，只把憑證放在 `CurrentUser\TrustedPeople` 不足以讓 Windows 部署這個套件。所以個別使用者安裝包不包含它。
- **兩種安裝包，每台電腦只能裝其中一種。** 每個安裝包在另一個已安裝時都會拒絕安裝；要先解除安裝其中一個，才能安裝另一個。全機安裝包只看得到執行它的那個帳號的個別使用者副本，所以其他帳號的個別使用者安裝不會被偵測到。
- **Group policy（群組原則）可能隱藏它的選單。** 在設定了 `EnforceShellExtensionSecurity` 的地方，檔案總管只會載入列在全機的 *Approved* 機碼底下的殼層擴充，而個別使用者安裝無法寫入那個機碼，所以右鍵選單不會出現。在那種環境請使用全機安裝包。
- **在「工具 > 選項 > 系統」清除某個格式，也會移除 7-ZSTar 對它的提供。** 在那裡清除某個格式（點該儲存格直到它變空，然後按「確定」）時，檔案管理員會刪除整個 `HKCU\Software\Classes\.<ext>` 與 `7-ZSTar.<ext>` 機碼，而在個別使用者安裝中，這些機碼也存放著安裝包為「設定 > 應用程式 > 預設應用程式」與「開啟檔案」清單所註冊的內容。7-ZSTar 於是從該格式的「開啟檔案」清單中消失，「預設應用程式」也會對它顯示一個空白項目。修復安裝可以把它補回來（再次執行 `.msi`，選擇 *Repair*（修復））。更好的做法是在「預設應用程式」裡指派檔案類型，而不是在檔案管理員裡。全機安裝包在一個地方也有同樣的弱點，說明見下方的檔案關聯。

### 檔案關聯，以及解除安裝對它們的影響

**請在「設定 > 應用程式 > 預設應用程式」裡設定。** 在 Windows 11 上，在那裡輸入 7-ZSTar，它能開啟的每種格式都會列出來供你指派。在 Windows 10 上，7-ZSTar 列在該頁的 *Set defaults by app* 底下，按 *Manage* 可看到它的格式。Windows 7 沒有「設定」應用程式：7-ZSTar 列在控制台 > Default Programs > *Set your default programs* 裡，本文所說的「預設應用程式」在那裡就是指這一頁。從這兩個頁面指派格式，還沒有測試過。安裝程式會把 7-ZSTar 註冊成預設程式（Default Programs）的應用程式：每種格式有一個帶圖示與開啟命令的 ProgID、每個副檔名的「開啟檔案」清單裡有一個項目，還有 Windows 會讀取的 Capabilities 區塊；但它刻意不宣告擁有任何檔案類型：由哪個程式開啟你的壓縮檔是你的決定，這也讓 7-ZSTar 與官方 7-Zip 不會互相干擾。不過，當沒有其他程式提供開啟某種格式時，Windows 仍可能自行把它交給 7-ZSTar：在測試用的 Windows 10 與 Windows 7 上，沒有其他程式註冊過 `.7z`，結果 `.7z` 檔案顯示 7-ZSTar 的圖示，按兩下就用它開啟，Windows 並沒有詢問要用哪個程式。

**檔案管理員裡的「工具 > 選項 > 系統」在 Windows 11 上大多無效**，這是 Windows 的規則，不是這裡的錯誤。它會把一個 `7-ZSTar.<ext>` ProgID 寫到 `HKCU\Software\Classes`，而對於電腦已經認得的副檔名（每種壓縮格式都是），Windows 11 會忽略它：`AssocQueryString` 回答 `Unknown`，檔案總管畫出空白的通用圖示。Windows 認的是一個 `UserChoice` 機碼，上面蓋有只有它自己能算出的雜湊值，所以在 Windows 11 上，「設定」介面是唯一的路。沒有任何應用程式能寫出這樣的機碼：7-ZSTar 不行，7-Zip 不行，任何安裝程式都不行。Windows 10 與 Windows 7 在測試中的表現不同：在檔案管理員裡設定 `.7z` 和 `.zst`、且沒有為它們另選其他程式之後，`AssocQueryString` 兩者都回傳 `7zFM.exe`。

**在「所有使用者」欄清除某個格式，會移除全機安裝包自己對它的註冊。** 那一欄寫入的是 `HKLM\Software\Classes`，全機安裝包把它所提供的 ProgID 與「開啟檔案」項目都放在那裡，而在那裡清除某個格式（這需要以系統管理員身分執行檔案管理員）會把這些機碼整個刪掉，對每個帳號都一樣。修復安裝在個別使用者安裝包上把相同的機碼復原了；全機安裝包則沒有量測過。

**更改任何東西之後圖示仍然空白**，也可能是檔案總管的圖示快取造成的，它不會察覺已經快取過的 DLL 被換掉了；`ie4uinit.exe -show` 不能可靠地清掉它。請關閉檔案總管，刪除 `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db`，再重新啟動。

**解除安裝會移除它碰得到的關聯**：屬於執行解除安裝者的 `7-ZSTar.*` ProgID，而且只處理仍然指向它們的檔案類型，所以這段期間已經交給別的程式的格式不會被動到。解除安裝全機安裝包時，也不會動一個指向其他地方仍然存在的 7-ZSTar 副本的 ProgID，例如從 `.zip` 取得的免安裝版，並且是用該副本自己的**工具 > 選項 > 系統**設定的那個 ProgID。個別使用者安裝包做不到這一點：它的 ProgID 就是同樣那些 `HKCU` 機碼（見上文的*個別使用者安裝包*），解除安裝會把它們全部移除，不論是誰最後寫入的。如果把它們留下來，這些類型就會指向一個圖示與命令都是已刪除執行檔的 ProgID，結果是空白圖示，而且按兩下會出現錯誤。其他帳號的關聯碰不到；它們可以在程式移除之前，先用 `Setup-ShellIntegration.ps1 -RemoveAssociations` 清除自己的關聯。`msiexec /x ... KEEPASSOC=1` 會略過這項清理，升級則從來不會做這項清理。

**已知限制：其他帳號會保留它們自己設定的關聯。** 解除安裝全機安裝包時，只會清除執行解除安裝的帳號，在檔案管理員的**工具 > 選項 > 系統**裡、自己那一欄（欄標題是帳戶名稱）所設定的內容。其他任何在那裡設定過關聯的帳號會保留它們，這些關聯指向已被移除的程式，所以按兩下 `.7z` 檔案時，Windows 會詢問要用哪個程式。每個帳號都應該在解除安裝**之前**自行清除，用

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

它只會移除 7-ZSTar 的項目；或是在解除安裝之後，到「設定 > 應用程式 > 預設應用程式」重新指派這些類型。改在檔案管理員裡做的話，是在自己那一欄裡，逐一點擊顯示 7-ZSTar 的儲存格直到變空，然後按「確定」；請不要全選所有資料列再按「+」，因為它會把同一個狀態套用到所有選取的資料列，也會連帶清除屬於其他程式（例如官方 7-Zip）的格式。

在「所有使用者」欄裡設定的關聯，解除安裝的清理完全不會碰，會讓每個帳號都指向已移除的程式。設定過任何這類關聯的系統管理員，應該在解除安裝之前，從以系統管理員身分執行的檔案管理員裡清除那些儲存格，再按「確定」；`-RemoveAssociations` 碰不到這一欄。在解除安裝之前清除它並無妨，即使這會刪掉安裝包自己在那裡的註冊（見上文），因為解除安裝本來就會移除它。個別使用者安裝包沒有其他帳號的問題，官方 7-Zip 的行為也相同。

## 語言

每個安裝包都附有上游的翻譯，九十幾種語言。請在**工具 > 選項 > 語言**裡挑選；MSI 也讓你在 *Custom setup*（自訂安裝）中把它們排除。7-ZSTar 第一次執行時會嘗試跟隨系統語言，但當 Windows 的“language for non-Unicode programs”（非 Unicode 程式的語言）與 regional format（地區格式）設定不一致時，這項偵測會放棄並維持英文；自己手動選擇語言永遠有效。

7-ZSTar 自己新增的字串，包括 zstd 的壓縮等級與字典欄位、新的壓縮檔格式名稱，沒有上游的翻譯，會維持英文。例外是「關於」對話方塊的**贊助**與**網站**按鈕：92 種語言中有 67 種各有對應的字，其餘 25 種顯示英文（`Lang/UPSTREAM.md` 列出了它們）。
翻譯是直接引入的，不是在這裡撰寫的：見 [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md)。
