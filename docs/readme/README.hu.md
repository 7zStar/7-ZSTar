<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · **Magyar** · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

*Ha ez a dokumentum eltér az angol változattól, az angol változat az irányadó.*

**A 7-Zip egy olyan forkja, amely barátságosabb a modern Windows 11-felhasználókkal: első szintű jobb gombos menü, zstd tömörítés és egy menetben készülő tar.zst.**

[Letöltés](https://github.com/7zStar/7-ZSTar/releases/latest) · [Weboldal](https://www.7zstar.com) · [Változásnapló](../../CHANGELOG.md)

## Miért a 7-ZSTar

- **Nincs több „További lehetőségek megjelenítése”.** Windows 11-en a 7-ZSTar közvetlenül a jobb gombos menü első szintjén van.
- **A tar.zst egy lépésben.** Egyetlen lépésben tömöríthetsz egy mappát .tar.zst fájlba, vagy csomagolhatsz ki egyet, anélkül hogy .tar fájl maradna a lemezen. A hivatalos 7-Zip nem tud .tar.zst fájlt készíteni, a kicsomagolását pedig két lépésben végzi, egy .tar fájlon keresztül.
- **Nagyjából 10× gyorsabb, mint a 7z.** Valódi projektmappákon a tar.zst tömörítése 10–18-szor gyorsabb volt.

## Sebesség

| Mappa | Fájlok | Eredeti méret | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 s / 76.7 MB | 38.4 s / 51.8 MB | **3.8 s** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 s / 107.8 MB | 54.8 s / 65.7 MB | **3.6 s** / 83.4 MB |
| Python `.venv` (nagy bináris fájlokkal) | 11,654 | 671 MB | 25.5 s / 249.5 MB | 100.8 s / 167.2 MB | **5.6 s** / 210.9 MB |

A tar.zst 15–23%-kal kisebb lett, mint a zip, és nem volt lassabb. A 7z továbbra is a legkisebb fájlokat készíti (a tar.zst 15–27%-kal nagyobb volt), de sokkal tovább tartott. A kicsomagolás mindhárom formátumnál nagyjából ugyanannyi ideig tartott.

Mindhárom formátum alapbeállításokkal; 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, NVMe SSD, 3 futtatás mediánja, 2026. november.

## Formátumok

- **Tömörítés egy lépésben:** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Kicsomagolás egy lépésben:** mindezek, valamint a tar.lzma és a tar.Z
- **Hozzáadott kodekek:** zstd, brotli, lz4, lz5 és lizard (önállóan vagy .7z fájlon belül), valamint a fast-lzma2, egy alternatív LZMA2-kódoló
- A hivatalos 7-Zip által kezelt minden formátum továbbra is működik.

## Letöltés

A legtöbben a minden felhasználónak szóló x64 `.msi` fájlt keresik, amely a [Kiadások](https://github.com/7zStar/7-ZSTar/releases/latest) oldalon található.

| | Minden felhasználónak `.msi` | Csak neked `-user.msi` | Hordozható `.zip` |
|---|---|---|---|
| Rendszergazdai jogosultság szükséges | Igen | Nem | Nem |
| Jobb gombos menü | Első szint Windows 11-en | Klasszikus menü (Windows 11-en a „További lehetőségek megjelenítése” alatt) | Nincs |
| Start menu (Start-menü) bejegyzés | Igen | Igen | Nem |

Mindegyik x86 és arm64 változatban is elérhető; válaszd azt, amelyik megfelel a Windowsodnak. 64 bites Windowson az x86 csomagoknak előfordulhat, hogy nincs jobb gombos menüjük, az arm64 buildeket pedig még nem próbálták ki valódi hardveren. A 7-ZSTar a hivatalos 7-Zip mellett települ, anélkül hogy az működésére hatással lenne.

**A Windows az első alkalommal figyelmeztethet.** A fájlok nincsenek kódaláírással ellátva, ezért a SmartScreen megállíthatja őket („A Windows megvédte a számítógépét”; a *Futtatás mindenképpen* megjelenítéséhez előfordulhat, hogy ki kell bontanod a figyelmeztetést), a bekapcsolt Intelligens alkalmazáskezeléssel rendelkező Windows 11-en pedig az `.msi` egyenesen le van tiltva. Minden kiadáshoz tartozik egy `SHA256SUMS` fájl, amellyel ellenőrizheted a letöltést. Hogy hogyan, és mit tehetsz az Intelligens alkalmazáskezelés ellen, azt az [INSTALL.md](../install/INSTALL.hu.md#aláíratlan-csomagok-smartscreen-és-intelligens-alkalmazáskezelés) magyarázza el.

**Az első szintű menüről:** Windows 11-en a minden felhasználónak szóló `.msi` hozzáad egy önaláírt tanúsítvánnyal aláírt kis csomagot, és megbízhatónak jelöli ezt a tanúsítványt; a Windows ezt követeli meg az első szinthez. Az eltávolítás mindkettőt eltávolítja. Ha ezt nem szeretnéd, telepíts a következővel: `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`. A csomag arra a fiókra regisztrálódik, amelyik a telepítőt futtatja; a többi fiók külön regisztrálja.

A fájltársításokat, az eltávolítást és a felhasználónkénti csomagot az [INSTALL.md](../install/INSTALL.hu.md) tárgyalja.

## Parancssor

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

PowerShellben tedd idézőjelbe a kapcsolót: `7z a "-ttar.zst" backup.tar.zst docs`. Idézőjelek nélkül a PowerShell kettévágja, és egy `.zst` nevű fájlt kapsz. A Command Prompt (cmd) (parancssor) használatához nem kellenek idézőjelek.

## Jó tudni

- **A „7-ZSTar hozzáadása a parancsértelmező helyi menüjéhez” kikapcsolása** (fájlkezelő, **Eszközök > Beállítások... > 7-ZSTar**) eltávolítja a jobb gombos bejegyzést, ahogy a hivatalos 7-Zipben is. A minden felhasználónak szóló csomagnál a fájlkezelő rendszergazdaként való futtatásával kapcsolhatod vissza. A felhasználónkénti csomagnál ez nem megy („A hozzáférés megtagadva.”); futtasd újra az `.msi` fájlt, és válaszd a *Repair* (javítás) lehetőséget.
- **A csendes vagy távoli telepítés Windows 11-en** (SSH-n keresztül, vagy telepítőeszközből) sikeres, de az első szintű bejegyzés nem regisztrálódik, így a 7-ZSTar csak a „További lehetőségek megjelenítése” alatt jelenik meg. [Részletek az INSTALL.md-ben](../install/INSTALL.hu.md#a-windows-11-jobb-gombos-menüje).
- **A tar.br, tar.lz4, tar.lz5, tar.liz vagy tar.Z kicsomagolása** számodra továbbra is egy lépés, de egy ideiglenes fájlon keresztül megy, amelyet utána törlünk.

## Rendszerkövetelmények

Windows 7 / Server 2008 R2 vagy újabb (x64, x86), arm64-en Windows 10 vagy újabb. Semmi mást nem kell telepíteni. Tesztelve 64 bites Windows 7 SP1-en (a későbbi frissítésekkel), Windows 10-en és Windows 11-en; [mit teszteltek](../install/INSTALL.hu.md#rendszerkövetelmények). Linuxra van egy parancssori build, amelyet magadnak kell lefordítanod; a macOS nem támogatott.

## Dokumentáció

A **Súgó > Tartalomjegyzék...** és az F1 a `7-zip.chm` fájlt nyitja meg, a hivatalos 7-Zip súgófájlját. Ez végig „7-Zip”-et ír, és nem tér ki arra, amit a 7-ZSTar hozzáad; ezt ez az oldal és a [változásnapló](../../CHANGELOG.md) tárgyalja. Ha a súgófájl hiányzik, ugyanezek a bejegyzések ezt a részt nyitják meg online.

A 7-ZSTar saját építéséhez lásd a [build/README.md](../../build/README.md) fájlt; egy új upstream kiadás beolvasztása előtt olvasd el a [MAINTAINING.md](../../MAINTAINING.md) fájlt.

<a id="donate"></a>

## Adomány

A 7-ZSTar ingyen használható, akár adományozol, akár nem. Ha időt spóroltál vele, és szeretnél köszönetet mondani, küldhetsz kriptovalutát az alábbi címre. Az összeg személyesen hozzám kerül (DraftingDreamer), a saját fejlesztési költségeimre megy, és nem vesz meg se funkciót, se segítséget, se ígéretet a folytatásról.

Az Ethereum és a Polygon hálózatán bármilyen token jöhet: ETH, POL, USDT, USDC vagy bármi más. A két hálózaton ugyanaz a cím.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="Az adománycím QR-kódja">

- Csak az Ethereum (ERC20) és a Polygon hálózatán érkező átutalások fogadhatók el. Ha mindkettő használható, a Polygon hálózaton általában alacsonyabb a díj.
- Ez az egyetlen hivatalos cím, és soha nem kérlek meg, hogy másikra utalj.
- Az átutalások nem vonhatók vissza, ezért visszatérítés sem lehetséges.

Az is segít, ha csillagozod a 7-ZSTar projektet a GitHubon, vagy ajánlod egy ismerősödnek.

## Licenc

LGPL v3, lásd a [LICENSE](../../LICENSE) fájlt. Egyes részekre más feltételek vonatkoznak: a RAR-kicsomagolásra az unRAR korlátozása érvényes, ezért a RAR-támogatással készült build nem tisztán LGPL v3. A teljes lista a [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md) fájlban van, a szerzői jogi közlemények pedig a [NOTICE](../../NOTICE) fájlban.

Köszönet mindenkinek, aki időt szánt a 7-Zipre, a tömörítési algoritmusokra és a nyílt forráskódú világra. Nélkületek a 7-ZSTar nem létezne.
