<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# A 7-ZSTar telepítése

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · [한국어](INSTALL.ko.md) · [Italiano](INSTALL.it.md) · [Polski](INSTALL.pl.md) · [Türkçe](INSTALL.tr.md) · [Nederlands](INSTALL.nl.md) · [Українська](INSTALL.uk.md) · [Bahasa Indonesia](INSTALL.id.md) · [ไทย](INSTALL.th.md) · [Čeština](INSTALL.cs.md) · **Magyar** · [Română](INSTALL.ro.md) · [Svenska](INSTALL.sv.md) · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md)

*Ha ez a dokumentum eltér az angol változattól, az angol változat az irányadó.*

A [README](../readme/README.hu.md) rövid ismertetője mögötti részletek: rendszerkövetelmények, a SmartScreen-figyelmeztetés, az Intelligens alkalmazáskezelés és a letöltött fájl ellenőrzése, a három csomag, a Windows 11 jobb gombos menüje, a fájltársítások és az eltávolítás.

## Rendszerkövetelmények

**Windows 7 vagy Windows Server 2008 R2, x64 vagy x86. arm64-en Windows 10.**
Semmi másra nincs szükség: a C futtatókörnyezet statikusan van beszerkesztve (`-MT`), így a binárisok csak magának a Windowsnak a DLL-jeit importálják – nincs szükség újraterjeszthető csomagra, és .NET-re sem.

Ez a minimum a csomagok követelményeiből *következik*, tesztelni pedig Windows 7 SP1-en (a későbbi frissítésekkel, köztük a PowerShell 5.1-gyel), Windows 10 22H2-n és Windows 11-en tesztelték, mindegyiken 64 biten. Windows 7-en és 10-en ez magában foglalta a minden felhasználónak szóló és a felhasználónkénti x64 `.msi` telepítését és eltávolítását, a telepítővarázslót, az x64 `.zip`-et, az összes hozzáadott kodeket és egylépéses tar-formátumot, a jobb gombos menüt, a fájltársításokat és a súgófájlt, valamint a 64 bites Windowson futó x86 `.msi`-t és `.zip`-et. Ezen kívül Windowson semmi mást nem teszteltek: sem a Windows 8-at és 8.1-et, sem a Windows Servert, a 32 bites Windowst, az arm64 hardvert, sem a Windows 7-et ezek a frissítések nélkül. A minimum a hivatalos (upstream) 7-Zipénél is magasabb, amelynek binárisai még Windows XP-n is betöltődnek. Három dolog szabja meg, és ezek közül a második az, amit semmilyen build-beállítás nem tud visszacsinálni:

- Az `.msi` az `InstallerVersion="500"` értéket deklarálja, a Windows Installer 5.0-t pedig a Microsoft szerint
  "with Windows Server 2008 R2 and later and Windows 7 and later" szállították (vagyis a Windows Server 2008 R2-vel és újabbakkal, valamint a Windows 7-tel és újabbakkal)
  ([Microsoft][msi-versions]). A hordozható `.zip` nem megy át a Windows Installeren,
  de lásd a következő két pontot.
- **A zstd és a fast-lzma2 csak Vistától elérhető szinkronizációt használ.** Mindkettő a saját fejléceiben
  kényszeríti a `_WIN32_WINNT 0x0600` értéket, és közvetlenül hívja az
  `InitializeConditionVariable` / `SleepConditionVariableCS` függvényeket, így a
  `7z.dll` és a `7za.exe` – az a két bináris, amelybe a kodekek bele vannak fordítva –
  négy olyan függvényt importál, amely a Windows XP-n és a Server 2003-on nincs meg.
  A hivatalos 7-Zip `7z.dll`-je egyiket sem importálja.
- Az eszközlánc: ezeket Visual Studio 2022-vel építik, amelynek támogatott
  célplatform-listája a Windows 7 és újabb – a Vista és a Server 2008 „No”
  ([Microsoft][vs-targeting]). A linkelt alrendszerverzió x64-en és
  x86-on 6.0, arm64-en 6.2, az arm64-es Windows pedig a Windows 10-zel kezdődik, bármi legyen is a beállítás.

A Windows Vista és a Server 2008 a kettő között áll: a binárisok betöltődnének, de az eszközlánc nem támogatja őket, a telepítő nem fut rajtuk, és a 7-ZSTar-t nem tesztelték rajtuk.

**A Linux csak parancssori buildként támogatott; a macOS nem támogatott.**
A fork egy natív `7zz`-t (az `Alone2` konzolprogramot) épít gcc-vel a saját makefile-ján keresztül, amely beemeli az upstream makefile-jait, és egyiket sem módosítja:
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
Csak Ubuntu 24.04-en, gcc 13.3-mal (x86-64) építették és tesztelték: a build az upstream kapcsolóival figyelmeztetésmentes, a 77 ellenőrzésből álló füsttesz lefut, és a 25 Windowson készült és 37 Linuxon készült interoperabilitási vektor ugyanazt az eredményt adja, mint Windowson. A két forkhoz tartozó fájl, amelyhez a portolás hozzányúlt, Windowson változatlanul lefordul (tiszta x64 build, a füsttesztek és az interop visszaolvasás mind sikeres). Grafikus felület nincs. Az upstream többi Linux célja (`7za`, `7zr`, `7z.so`) nem támogatott: a gcc-s objektumlistáikból hiányzik az, amire a fork upstream kezelőket érintő módosításainak szüksége van, ezért várhatóan nem linkelhetők. Más architektúrákat, disztribúciókat és fordítókat nem ellenőriztek, a macOS-t pedig soha nem építették le, ezért `MACOSX_DEPLOYMENT_TARGET` nem adható meg. Az építési lépések, a tesztek és az ismert korlátok a `build/linux/README.md` fájlban vannak; a Linuxos eszközökkel való együttműködésről a `test/interop/REPORT.md` szól.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## Aláíratlan csomagok, SmartScreen és Intelligens alkalmazáskezelés

**A 7-ZSTar kiadásaiban a telepítők és a programok nincsenek tanúsítványkiadó által kódaláírva**, és ennek a projektnek nincs kódaláíró tanúsítványa. A Windows ezért nem tudja megállapítani, ki adta ki a fájlt, és amikor először futtatod az `.msi`-t, vagy egy programot a `.zip`-ből, a Microsoft Defender SmartScreen figyelmeztetéssel megállíthatja. A Microsoft fejlesztői dokumentációja a "No signature" esetet sorolja azok közé, amelyekben "Windows protected your PC" (magyarul: „A Windows megvédte a számítógépét”) címmel figyelmeztetés jelenik meg, és a felhasználónak a „Futtatás mindenképpen” gombot kell választania (angol nyelvű Windowson „Run anyway”), mielőtt az alkalmazás elindul ([Microsoft][smartscreen-rep]). A vállalati szabályzat ezt a lehetőséget teljesen el is veheti; egy ilyen gépen kérdezd azt, aki kezeli.

A kiadásban az egyetlen *aláírt* dolog az a kis csomag, amely a 7-ZSTar-t a Windows 11 jobb gombos menüjének első szintjére teszi, a minden felhasználónak szóló `.msi`-n belül. A tanúsítványa önaláírt, és annak az egy csomagnak az építésekor jön létre, így nem tanúsítványkiadó aláírása, és semmit sem mond arról, ki építette a csomagot; hogy mit csinál, és hogyan utasítható vissza, azt lásd itt: [a Windows 11 jobb gombos menüje](#a-windows-11-jobb-gombos-menüje).

A figyelmeztetés nem bizonyítja, hogy a fájl rossz, hiánya pedig nem bizonyítaná, hogy jó. Azt viszont magad is ellenőrizheted, hogy a példányod pontosan az-e, amelyet a kiadási oldalon közzétettek. Minden kiadás tartalmaz egy `SHA256SUMS` nevű fájlt: csomagonként egy sor, egy SHA-256 hash, utána a fájlnév.

1. Töltsd le a csomagot és a `SHA256SUMS` fájlt ugyanarról a kiadási oldalról, ugyanabba a mappába.
2. Nyiss egy PowerShellt abban a mappában, és hasonlítsd össze őket. Cseréld ki a nevet a letöltött fájléra:

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   A `True` azt jelenti, hogy a hashek azonosak. Ha inkább magad szeretnéd megnézni őket, futtasd a
   `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi` parancsot, és keresd meg ugyanazt
   a fájlnevet a `SHA256SUMS`-ben; az összehasonlítás nem tesz különbséget kis- és nagybetű között.
3. Ha `False`-t kapsz, vagy a fájlnév nincs benne a `SHA256SUMS`-ben, ne futtasd: töröld a fájlt,
   és töltsd le újra. Ha még mindig nem egyezik, jelentsd, kérjük, a
   [SECURITY.md](../../SECURITY.md) leírása szerint.

A `SHA256SUMS` csak az adott kiadásra feltöltött fájlokat fedi le. Ugyanannak a címkének (tag) a saját építése más hasheket ad (a jobb gombos menü csomagját minden buildnél új tanúsítvánnyal írják alá), a forráskód pedig minden kiadással együtt közzé van téve, ha inkább te építenéd meg: lásd [build/README.md](../../build/README.md).

Ha a hashek egyeznek, és megnyugtat a fájl eredete:

- **`.msi`** – indítsd el a szokásos módon. Ha a SmartScreen megállítja, válaszd azt a lehetőséget, amellyel mindenképpen
  futtatható („Futtatás mindenképpen”; angol nyelvű Windowson „Run anyway”). Előfordulhat, hogy a figyelmeztető ablakot előbb ki kell bontani: a tesztelt Windows 10-es gépen
  csak egy olyan gombot kínált, amely a fájl futtatását mellőzi, amíg az üzenete alatti hivatkozásra
  nem kattintottak. A minden felhasználónak szóló `.msi` ezután rendszergazdai jóváhagyást kér, mint
  bármely más telepítő.
- **`.zip`** – csomagold ki, és indítsd el a `7zFM.exe`-t vagy a `7z.exe`-t a mappából. A benne lévő
  programok is aláíratlanok, ezért a Windows ugyanazt a figyelmeztetést mutathatja,
  amikor először elindítod mindegyiket.

A SmartScreen azt is figyelembe veszi, mennyire ismert egy fájl, nem csak az aláírást; olyan fájl is kiválthatja, amelyet kevesen töltöttek le, még ha alá is van írva. Ezen itt semmi nem változtat, és a fenti lépések közül semmi nem kapcsolja ki a SmartScreent.

### Az Intelligens alkalmazáskezelés Windows 11-en

Egyes Windows 11-es gépeken egy szigorúbb védelem, az **Intelligens alkalmazáskezelés** van bekapcsolva. Amikor be van kapcsolva, a Windows blokkolja az aláíratlan fájlokat, hacsak a Microsoft felhőszolgáltatása nem tud kezeskedni értük, egy új kiadásról pedig általában nincs ilyen feljegyzés ([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). A SmartScreen-figyelmeztetéssel ellentétben a blokkoláshoz nincs „mégis futtatom” lehetőség, és a Microsoft GYIK-ja szerint egyedi alkalmazásra nem lehet megkerülni az Intelligens alkalmazáskezelést.

Ez történt, amikor a 7-ZSTar 26.05.1-et Windows 11 Pro 25H2-n (build 26200.8037), bekapcsolt Intelligens alkalmazáskezeléssel kipróbálták:

- **Az `.msi` telepítők blokkolva lettek**, a minden felhasználónak szóló és a felhasználónkénti egyaránt. Hagyományos kínai nyelvű Windowson a Windows Installer ezt írta:
  「系統禁用此安裝。請連絡系統管理員。」 (nagyjából: a rendszer letiltotta ezt a telepítést, forduljon a rendszergazdához), a Windows biztonság értesítése pedig azt közölte,
  hogy az Intelligens alkalmazáskezelés blokkolta a fájlt, mert a Windows nem tudta megállapítani, ki adta ki, és nem olyan alkalmazás, amelyet a Windows ismer. Folytatási lehetőség nem volt,
  és az `msiexec /i ... /qn` 1625-ös hibával (error 1625) tért vissza. Ez az üzenet a Windows Installer 1625-ös sztringje (string 1625); angol nyelvű Windowson ugyanez a
  sztring így szól: "The system administrator has set policies to prevent this
  installation." (a Windows Installer angol erőforrásaiból kiolvasva, a képernyőn nem látva).
- **A `.zip`-ből egy program lefutott.** A hordozható `.zip`-ből kicsomagolt `7zFM.exe`
  ugyanabban a tesztben normálisan elindult. Az, hogy a Windows engedi-e egy aláíratlan program futását,
  a fájlról alkotott saját megítélése, ezért a te gépeden ez más lehet.
- Közvetlenül az Intelligens alkalmazáskezelés bekapcsolása után az `.msi` néhány percig települt, mielőtt blokkolni kezdték volna. Az okot nem találták meg, ezért a bekapcsolás utáni azonnali siker nem jelenti azt, hogy a telepítő engedélyezett.

Tehát olyan gépen, ahol az Intelligens alkalmazáskezelés be van kapcsolva, **a telepítők nem telepíthetők**, és a `SHA256SUMS` ellenőrzése ezen nem változtat. Ezen az segít, ha a Windows biztonság alkalmazás Az Intelligens alkalmazáskezelés beállításai részében kikapcsolod az Intelligens alkalmazáskezelést (a tesztelt hagyományos kínai Windowson: Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定).
A tesztben a **Ki** lehetőség választása azonnal, újraindítás nélkül érvénybe lépett, és a telepítők utána települtek. Ez az egész gépre vonatkozó beállítás, és az itt leírtak nem kérik, hogy megváltoztasd: ez a te döntésed, vagy felügyelt gépen a rendszergazdádé.

Azt is érdemes előre tudni, visszakapcsolható-e. A Microsoft GYIK-ja szerint a friss Windows-frissítések lehetővé teszik az Intelligens alkalmazáskezelés újbóli bekapcsolását a Windows tiszta telepítése nélkül, így az ezeket nélkülöző verzión a kikapcsolás végleges lehet. Az itt tesztelt buildben a bekapcsolás lehetősége a kikapcsolás után is felkínálódott; ez tesztelési eredmény, nem ígéret a te verziódra.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## Telepítés

Három csomag, mindegyiket az `installer\Build-Package.ps1` építi (a felhasználónkénti a `-PerUser` kapcsolóval):

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| Telepítés ennek | minden fiók | a telepítő fiók | - |
| Explorer jobb gombos menü | igen | igen, csak a klasszikus menü ([lent](#a-felhasználónkénti-csomag)) | nem |
| Start menu (Start-menü) bejegyzés | igen | igen | nem |
| Rendszergazda szükséges | igen | nem | nem |
| Eltávolítás | *Telepített alkalmazások* a Gépházban | *Telepített alkalmazások* a Gépházban | a mappa törlése |

A *Telepített alkalmazások* a Windows 11-es elnevezés. A Windows 10 ugyanazt az oldalt *Alkalmazások és szolgáltatások* néven hívja, Windows 7-en pedig a Control Panel (Vezérlőpult) *Programs and Features* (programok és szolgáltatások) oldala.

A magával a Windowsszal egyező csomagokat használd: x86-ot 32 bites Windowson, x64-et 64 bites Windowson, arm64-et Windows on Arm-on (az arm64-es csomagok el vannak készítve, de soha nem futtatták őket). Az x86-os shell-bővítmény 32 bites, a 64 bites Explorer pedig nem tudja betölteni, ezért 64 bites Windowson az x86 `-user.msi`-nek egyáltalán nincs jobb gombos menüje, az x86 `.msi`-é pedig csak Windows 11-en van, és csak azoknál a fiókoknál, amelyek regisztrálták a Windows 11-es csomagját (a telepítő fiók, vagy az, amelyik lefuttatta a `-Register`-t, lásd alább).

Az MSI mindig a `Program Files\7-ZSTar` mappába telepít: a felhasználónkénti csomaggal ellentétben nem enged mappát választani, és a parancssori `INSTALLFOLDER`-t figyelmen kívül hagyja, mert abban a mappában van egy szkript, amelyet a telepítő SYSTEM-ként futtat, és egy DLL, amelyet minden felhasználó Explorere betölt, egy máshol (például a `C:\` alatt) létrehozott mappába pedig minden felhasználó írhat. Saját shell-bővítmény CLSID-t és saját `Software\7-ZSTar` beállításjegyzék-ágat regisztrál, és minden helyimenü-kulcsot `7-ZSTar` néven nevez el – így sem nem ütközik a hivatalos 7-Zipével, sem nem távolítja el azt. Lásd: [installer/GUIDS.md](../../installer/GUIDS.md).

Normál telepítővarázslót futtat – welcome, licence, setup type, optional feature tree, finish (üdvözlés, licenc, telepítési típus, választható funkciók fája, befejezés) –, és a csendes telepítés is változatlanul működik (`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`), mert az msiexec csendes módban kihagyja a teljes felületi sorozatot. A varázsló csak angol nyelvű, más nyelvre állított Windowson is (hagyományos kínai Windows 10-en látták; az `.msi` más nyelv nélkül készül), és a befejező oldalán alapértelmezés szerint be van pipálva a *Launch 7-ZSTar File Manager* (a 7-ZSTar Fájlkezelő indítása).

### A Windows 11 jobb gombos menüje

Windows 11-en a bejegyzés az első szintű menüben van, nem a *További lehetőségek megjelenítése* alá temetve, ahol a hivatalos 7-Zip és a WinRAR még mindig áll. A Windows 11 csak akkor listáz ott shell-bővítményt, ha az csomagidentitással érkezik, ezért az MSI a program mellé szállít egy kis, csak identitást hordozó MSIX-csomagot, és telepítés közben regisztrálja. A klasszikus regisztráció is megmarad. Ez teszi a bejegyzést a jobb gombos menübe Windows 10-en és Windows 7-en, amelyek menüje egyszintű, és nincs benne *További lehetőségek megjelenítése*, és ez tartja működőképesen azoknak is, akik visszaállították a régi helyi menüt.

Ezt a csomagot **önaláírt tanúsítvánnyal** írták alá, és a telepítő a `LocalMachine\TrustedPeople` tárolóba teszi – a Windows nem telepít olyan csomagot, amelynek aláírását nem tudja valami megbízhatóra visszavezetni. Az eltávolítás a tanúsítványt a csomaggal együtt eltávolítja. Windows 10-en és Windows 7-en a telepítő egyiket sem teszi: nem ad hozzá tanúsítványt, és nem regisztrál csomagot, a menüt egyedül a klasszikus regisztráció adja.

Ha nem szeretnél önaláírt tanúsítványban megbízni, csak ezt a részt utasítsd vissza, a többit tartsd meg:

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

Ekkor csak a klasszikus menüt kapod, így Windows 11-en a 7-ZSTar bejegyzés a jobb gombos menüben a *További lehetőségek megjelenítése* alatt van. Az első szintű bejegyzés későbbi bekapcsolásához, vagy normál telepítés utáni visszavonásához:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

Ha megbízol ebben a tanúsítványban, a Windows **bármely más**, ugyanazzal a kulccsal aláírt csomagot is figyelmeztetés nélkül elfogad. Csak erre az egy csomagra használják, és az eltávolítás kiveszi, de ebbe egyezel bele – a fenti `SPARSE=0` az elutasításának módja.

A csomagregisztráció felhasználónkénti, és a telepítő csak annak futtatja le, aki telepít. Két következmény:

- Ugyanazon a gépen egy második fiók csak a klasszikus menüt kapja, amíg ugyanazt a szkriptet le nem futtatja `-Register`-rel.
- Az eltávolítás csak annak vonja vissza a regisztrációt, aki az eltávolítást végzi. Ha valaki más regisztrálta, az ő regisztrációja túléli az eltávolítást, és egy már nem létező mappára mutat; az a fiók a
  `Get-AppxPackage 7-ZSTar | Remove-AppxPackage` paranccsal törli.

**Ismert korlátozás: az első szintű menü csak akkor regisztrálódik, ha a telepítés interaktív, bejelentkezett munkamenetben fut.** A minden felhasználónak szóló `.msi` telepítése távoli vagy nem interaktív munkamenetből – SSH-n keresztül, vagy felügyeleti eszközből végzett csendes telepítéssel – továbbra is sikert jelez, de a Windows 11-es csomag nem regisztrálódik, ezért csak a klasszikus menü jelenik meg a *További lehetőségek megjelenítése* alatt. A tesztben az `msiexec /i ... /qn` SSH-munkamenetből (0. munkamenet) 0-val lépett ki, miközben a `Setup-ShellIntegration.ps1` `registration failed: 0x80070005` üzenetet jelentett (hozzáférés megtagadva); ugyanez az `.msi` egy rendszergazda konzolmunkamenetéből telepítve normálisan regisztrált.

A `-Status` kiírja, mi van a helyén és mi nincs.

### A felhasználónkénti csomag

A `7-ZSTar-<version>-<arch>-user.msi` csak az aktuális fióknak telepít, a `%LOCALAPPDATA%\Programs\7-ZSTar` mappába, UAC-kérés nélkül. Mindent a `HKCU` alatt regisztrál; a csomag semmit nem ír a `HKLM`-be (a Windows Installer saját nyilvántartását leszámítva). Amit nem úgy tesz, mint a gépenkénti csomag:

- **Nincs Windows 11 első szintű menü.** Windows 11-en a 7-ZSTar a jobb gombos menüben a *További lehetőségek megjelenítése* alatt van. Az első szintű bejegyzéshez az önaláírt tanúsítványnak az egész gépen megbízhatónak kell lennie, ehhez rendszergazda kell: Windows 11-en mérve a `CurrentUser\TrustedPeople` alatti tanúsítvány nem elég ahhoz, hogy a Windows telepítse a csomagot. Ezért a felhasználónkénti csomag kihagyja.
- **A kettő közül gépenként csak az egyik.** Mindkét csomag megtagadja a telepítést, amíg a másik telepítve van; az egyiket távolítsd el, mielőtt a másikat telepíted. A gépenkénti csomag csak a futtató fiók felhasználónkénti példányát látja, így egy másik fiók felhasználónkénti telepítését nem észleli.
- **A Csoportházirend elrejtheti a menüjét.** Ahol az `EnforceShellExtensionSecurity` be van állítva, az Explorer csak a gépszintű *Approved* kulcs alatt felsorolt shell-bővítményeket tölti be, ebbe pedig a felhasználónkénti telepítés nem tud írni, ezért a jobb gombos menü nem jelenik meg. Ott a gépenkénti csomagot használd.
- **Egy formátum törlése az Eszközök > Beállítások... > Rendszer alatt a 7-ZSTar felkínálását is eltávolítja ahhoz a formátumhoz.** Amikor ott törölsz egy formátumot (kattints a cellájára, amíg üres nem lesz, majd OK), a fájlkezelő törli a teljes
  `HKCU\Software\Classes\.<ext>` és `7-ZSTar.<ext>` kulcsot – felhasználónkénti telepítésnél pedig ezek a kulcsok tartalmazzák azt is, amit a csomag a Gépház > Alkalmazások > Alapértelmezett alkalmazások és a *Társítás* lista számára regisztrált. A 7-ZSTar ezután kiesik az adott formátum *Társítás* listájából, az Alapértelmezett alkalmazások pedig üres bejegyzést mutat hozzá. A telepítés javítása visszarakja (futtasd újra az `.msi`-t, és válaszd a
  *Repair* (javítás) lehetőséget). Jobb, ha a fájltípusokat az Alapértelmezett alkalmazásokban rendeled hozzá, nem a fájlkezelőben. A gépenkénti csomagnak ugyanez a gyenge pontja egy helyen megvan, az alábbi, fájltársításokról szóló részben leírva.

### Fájltársítások, és mit tesz velük az eltávolítás

**Állítsd be őket a Gépház > Alkalmazások > Alapértelmezett alkalmazások alatt.** Windows 11-en írd be oda, hogy 7-ZSTar, és minden formátum, amelyet meg tud nyitni, listázva lesz a hozzárendeléshez. Windows 10-en a 7-ZSTar az oldalon a *Set defaults by app* (alkalmazásonkénti alapértelmezések megadása) alatt szerepel, ahol a *Manage* (kezelés) mutatja a formátumait. Windows 7-nek nincs Gépház alkalmazása: a 7-ZSTar a Control Panel (Vezérlőpult) > Alapértelmezett programok > *Alapértelmezett programok beállítása* alatt szerepel, és ezt jelenti itt az *Alapértelmezett alkalmazások* ott. A formátumok hozzárendelését erről a két oldalról nem tesztelték. A telepítő a 7-ZSTar-t Alapértelmezett programok alkalmazásként regisztrálja – formátumonként egy ProgID-t az ikonjával és a megnyitási paranccsal, egy bejegyzést minden kiterjesztés *Társítás* listájában, és a Capabilities blokkot, amelyet a Windows olvas –, de szándékosan nem foglal le egyetlen fájltípust sem: hogy mely program nyitja meg az archívumaidat, az a te döntésed, és ez az, ami miatt a 7-ZSTar és a hivatalos 7-Zip nem keresztezik egymást. A Windows így is magától küldhet egy formátumot a 7-ZSTar-hoz, ha más program nem ajánlkozik a megnyitására: a tesztelt Windows 10-es és Windows 7-es gépeken, ahol semmi más nem regisztrálta a `.7z`-t, egy `.7z` fájl a 7-ZSTar ikonját mutatta, és dupla kattintásra abban nyílt meg, anélkül hogy a Windows megkérdezte volna, melyik programot használja.

**Az Eszközök > Beállítások... > Rendszer a fájlkezelőben Windows 11-en többnyire nem működik**, és ez Windows-szabály, nem itteni hiba. A `HKCU\Software\Classes` alá ír egy `7-ZSTar.<ext>` ProgID-t, a Windows 11 pedig minden olyan kiterjesztésnél figyelmen kívül hagyja, amelyet a gép már ismer – minden archívumformátum ilyen: az `AssocQueryString` `Unknown`-t válaszol, és az Explorer az üres általános ikont rajzolja. Helyette egy olyan `UserChoice` kulcsot tart tiszteletben, amelyet egy csak a Windows által kiszámítható hash-sel pecsételnek meg, ezért ott a Gépház felülete az egyetlen út. Egyetlen alkalmazás sem tud ilyet írni: sem a 7-ZSTar, sem a 7-Zip, sem semmilyen telepítő. A Windows 10 és a Windows 7 a tesztben másképp viselkedett: miután a `.7z` és a `.zst` be lett állítva a fájlkezelőben, más program kijelölése nélkül, az `AssocQueryString` mindkettőre `7zFM.exe`-t adott vissza.

**Egy formátum törlése a *Minden felhasználónak* oszlopában eltávolítja a gépenkénti csomag saját regisztrációját ahhoz a formátumhoz.** Az az oszlop a `HKLM\Software\Classes`-ba ír, ahol a gépenkénti csomag a hirdetett ProgID-kat és *Társítás* bejegyzéseket tartja, és egy formátum ott törlése (amihez a fájlkezelőt rendszergazdaként (run as administrator) kell futtatni) ezeket a kulcsokat egészében törli – minden fiók számára. A javítás a felhasználónkénti csomagnál ugyanezeket a kulcsokat visszaállította; ennél a csomagnál nem mérték.

**Egy ikon, amely bármilyen változtatás után üres marad,** az Explorer ikon-gyorsítótára is lehet, amely nem veszi észre, hogy egy már gyorsítótárazott DLL-t lecseréltek; az `ie4uinit.exe -show` nem megbízhatóan törli. Zárd be az Explorert, töröld a `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db` fájlokat, és indítsd újra.

**Az eltávolítás eltávolítja az elérhető társításokat** – az eltávolítást végző fiókhoz tartozó `7-ZSTar.*` ProgID-kat, és csak azokat a fájltípusokat, amelyek még rájuk mutatnak, így az időközben másik programnak átadott formátumot békén hagyja. A gépenkénti csomag eltávolítása békén hagyja azt a ProgID-t is, amely a 7-ZSTar valahol máshol még létező másolatát nyitja meg – például egy hordozható, `.zip`-ből származót, amelyet annak a másolatnak a saját **Eszközök > Beállítások... > Rendszer** felületén állítottak be. A felhasználónkénti csomag erre nem képes: a ProgID-i ugyanazok a `HKCU` kulcsok (lásd fent *A felhasználónkénti csomag*), és az eltávolítása törli őket, bárki írta is utoljára. Ha otthagynánk őket, a típusok egy olyan ProgID-ra mutatnának, amelynek ikonja és parancsa egy törölt végrehajtható fájl, ami üres ikont és hibát jelent dupla kattintásra. Más fiókok társításai elérhetetlenek; a sajátjukat törölhetik a `Setup-ShellIntegration.ps1 -RemoveAssociations` paranccsal, mielőtt a program eltűnik. Az `msiexec /x ... KEEPASSOC=1` ezt kihagyja, a frissítés pedig sosem csinálja.

**Ismert korlátozás: a többi fiók megtartja a saját maga beállított társításokat.** A gépenkénti csomag eltávolítása csak azt törli, amit az eltávolítást futtató fiók a saját oszlopában (a fiók nevével jelölve) állított be az **Eszközök > Beállítások... > Rendszer** alatt a fájlkezelőben. Bármely más fiók, amely ott állított be társításokat, megtartja őket, az eltávolított programra mutatva, így egy `.7z` fájlra duplán kattintva a Windows megkérdezi, melyik programmal nyissa meg. Minden fiók törölje a sajátját az eltávolítás **előtt** ezzel:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

amely csak a 7-ZSTar bejegyzéseit távolítja el, vagy utólag rendelje hozzá újra a típusokat a Gépház > Alkalmazások > Alapértelmezett alkalmazások alatt. Ha ezt inkább a fájlkezelőben teszi, a saját oszlopában minden olyan cellára rá kell kattintani, amely a 7-ZSTar-t mutatja, amíg üres nem lesz, majd OK; ne jelöld ki az összes sort, és ne nyomd meg a „+” gombot, mert az minden kijelölt sorra egy állapotot alkalmaz, így azokat a formátumokat is törli, amelyek másik programhoz tartoznak, például a hivatalos 7-Zip-hez.

A **Minden felhasználónak** oszlopban beállított társításokat az eltávolítási takarítás egyáltalán nem érinti, és minden fiókot az eltávolított programra mutatva hagy. Egy rendszergazda, aki ilyet állított be, az eltávolítás előtt törölje ezeket a cellákat egy rendszergazdaként futtatott fájlkezelőből, majd OK; a `-RemoveAssociations` ezt az oszlopot nem éri el. Az eltávolítás előtti törlés ártalmatlan, bár a csomag saját regisztrációját is törli ott (lásd fent), mivel az eltávolítás azt úgyis eltávolítja. A felhasználónkénti csomagnak nincs meg a más fiókokkal kapcsolatos problémája, és a hivatalos 7-Zip ugyanígy viselkedik.

## Nyelvek

Minden csomag az upstream fordításait hordozza, kilencvenvalahány nyelven. Válassz egyet az **Eszközök > Beállítások... > Nyelv** alatt; az MSI a *Custom* (egyéni) telepítésnél lehetővé teszi, hogy kihagyd őket. A 7-ZSTar az első indításkor megpróbálja követni a rendszernyelvet, de ez az észlelés feladja, és angol marad, ha a Windows „language for non-Unicode programs” (a nem Unicode-os programokhoz beállított nyelv) és a Területi formátum beállítása nem egyezik – a nyelv kézi kiválasztása mindig működik.

Azok a szövegek, amelyeket a 7-ZSTar maga adott hozzá – a zstd szint- és szótármezői, az új archívumformátumok nevei –, nem rendelkeznek upstream fordítással, és angolok maradnak. A kivétel a **7-ZSTar névjegye...** párbeszédablak **Adomány** és **Weboldal** gombja: a 92 nyelvből 67-nél mindkettőhöz van szó, a másik 25-nél angol felirat látszik
(a `Lang/UPSTREAM.md` felsorolja őket).
A fordításokat átvették, nem itt írták: lásd [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md).
