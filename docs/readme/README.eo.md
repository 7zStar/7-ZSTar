<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [한국어](README.ko.md) · [العربية](README.ar.md) · **Esperanto**

**7-Zip-disbranĉo pli amika al modernaj uzantoj de Windows 11: komandoj en la unua nivelo de la kunteksta menuo, zstd-densigo kaj tar.zst en unu trairo.**

[Elŝuti](https://github.com/7zStar/7-ZSTar/releases/latest) · [Retejo](https://www.7zstar.com/eo/) · [Ŝanĝoprotokolo](../../CHANGELOG.md)

## Kial 7-ZSTar

- **Preterpasu «Show more options» (Montri pliajn opciojn).** Instalu la MSI por ĉiuj uzantoj, kaj 7-ZSTar staros en la unua nivelo de la kunteksta menuo de Windows 11 (dekstra klako).
- **Unu trairo. Neniu .tar sur la disko.** Densigi al tar.zst kaj elarĥivigi ĝin estas po unu paŝo, kaj en neniu direkto estas skribata .tar. La oficiala 7-Zip ne povas krei arĥivon .tar.zst kaj elarĥivigas tian en du paŝoj, tra .tar.
- **10× pli rapide ol 7z.** Ĉe realaj projektaj dosierujoj tar.zst densigis 10 ĝis 18 foje pli rapide ol 7z.

## Rapido

| Dosierujo | Dosieroj | Origina grando | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13 371 | 207 MB | 4,1 s / 76,7 MB | 38,4 s / 51,8 MB | **3,8 s** / 59,7 MB |
| Python `.venv` | 9 795 | 346 MB | 6,6 s / 107,8 MB | 54,8 s / 65,7 MB | **3,6 s** / 83,4 MB |
| Python `.venv` (grandaj duumaj dosieroj) | 11 654 | 671 MB | 25,5 s / 249,5 MB | 100,8 s / 167,2 MB | **5,6 s** / 210,9 MB |

tar.zst donis arĥivojn 15 ĝis 23 % pli malgrandajn ol zip, kaj ne pli malrapide. Ĝi estas tamen 15 ĝis 27 % pli granda ol 7z, do se plej gravas la plej malgranda dosiero, 7z restas la pli bona elekto. Tiuj nombroj rilatas al densigo; ĉe elarĥivigo ĉiuj tri bezonis proksimume same da tempo.

zip, 7z kaj tar.zst ĉiuj kun la implicitaj agordoj. 7-ZSTar 26.05.1 x64 (7z.exe), unu komputilo (Intel Core Ultra 7 155H, NVMe SSD), tri realaj projektaj dosierujoj, mediano de 3 mezuroj, 2026-11.

## Formatoj

- **Densigo en unu paŝo (8):** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Elarĥivigo en unu paŝo (10):** tiuj 8, plus tar.lzma kaj tar.Z
- **Aldonitaj kodekoj:** zstd, brotli, lz4, lz5 kaj lizard, ĉiu kiel memstara formato kaj kiel metodo en .7z, plus fast-lzma2 kiel alternativa kodilo de LZMA2.
- Ĉiu formato, kiun 7-Zip jam subtenas, restas ĉi tie.

Elarĥivigo de tar.br, tar.lz4, tar.lz5, tar.liz aŭ tar.Z restas unu paŝo por vi, sed 7-ZSTar unue maldensigas al meza dosiero kaj poste forigas ĝin.

## Komandlinio

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

En PowerShell metu la formatan opcion inter citilojn, ekzemple `7z a "-ttar.zst" backup.tar.zst docs`. Sen ili PowerShell dividas `-ttar.zst` en du kaj 7z kreas dosieron nomatan `.zst`. Command Prompt (cmd) ne bezonas citilojn.

## Elŝuto kaj instalo

| | Por ĉiuj uzantoj `.msi` | Nur por vi `-user.msi` | Portebla `.zip` |
|---|---|---|---|
| Instalas por | Ĉiu konto en la komputilo | La nuna konto | Neniu instalo necesas |
| Bezonas administrantajn rajtojn | Jes | Ne | Ne |
| Kunteksta menuo | Unua nivelo de Windows 11 | Sub «Show more options» | Neniu |
| Ero en la Starta menuo | Jes | Jes | Ne |

Ĉiu venas en x64, x86 kaj arm64; elektu tiun, kiu kongruas kun via Windows: en 64-bita Windows la pakaĵoj x86 eble ne havas kuntekstan menuon. La kompilaĵoj arm64 ankoraŭ ne funkciis sur reala aparataro. 7-ZSTar instaliĝas apud la oficiala 7-Zip, kaj neniu influas la alian.

**Windows povas averti pri ĉi tiuj elŝutoj.** La instaliloj kaj programoj ne estas kodsubskribitaj de atestila aŭtoritato, do Microsoft Defender SmartScreen povas haltigi ilin per averto la unuan fojon, kiam vi rulas iun, kaj en komputilo kun Windows 11 kaj ŝaltita Smart App Control la instalilojn `.msi` oni tute blokas, sen ebleco daŭrigi. Tio ne signifas, ke la dosiero estas malbona: ĉiu eldono havas dosieron `SHA256SUMS`, kaj vi povas kontroli, ĉu via elŝuto kongruas kun tio, kio estis publikigita. Kiel kontroli, kion Smart App Control signifas por vi, kaj kiel daŭrigi post kiam la dosiero kongruas, troviĝas en [docs/INSTALL.md](https://github.com/7zStar/7-ZSTar/blob/main/docs/INSTALL.md#unsigned-packages-smartscreen-and-smart-app-control).

**Pri la menuo en la unua nivelo:** Windows 11 enlasas en la unuan nivelon nur programojn kun pakaĵa identeco, do la MSI por ĉiuj uzantoj instalas malgrandan MSIX-pakaĵon subskribitan per memsubskribita atestilo kaj aldonas tiun atestilon al la fidataj atestiloj. Malinstalo forigas ambaŭ. Se vi preferas ne fidi ĝin, instalu per `msiexec /i 7-ZSTar-<versio>-<arkitekturo>.msi SPARSE=0`, kaj la menuo restas sub «Show more options». La pakaĵo estas registrita nur por la konto, kiu rulas la instalilon; aliaj kontoj registras ĝin aparte.

La kompletaj detaloj, inkluzive de dosierasocioj kaj malinstalo, troviĝas en [docs/INSTALL.md](https://github.com/7zStar/7-ZSTar/blob/main/docs/INSTALL.md) (nur en la angla).

## Konataj limigoj

- **Malmarki la markobutonon pri integriĝo en la ŝelon forigas la registradon de la dekstraklaka menuo.** En la dosieradministrilo (`7zFM`), sub **Agordoj > Agordoj... > 7-ZSTar**, estas markobutono nomata «Metu 7-ZSTar'on en kuntekstan menuon de ŝelo». Same kiel en la oficiala 7-Zip, malmarki ĝin forigas la registradon de la ŝela etendaĵo (ĝian ŝlosilon `CLSID`), kiun kreis la instalilo, kaj la ero de 7-ZSTar malaperas el la kunteksta menuo. Ĉe la pakaĵo por ĉiuj uzantoj vi povas marki la butonon denove, se la dosieradministrilo funkcias kiel administranto. Ĉe la pakaĵo nur por vi ne eblas: nova marko montras «Access is denied» (Aliro rifuzita), kaj la ero restas for. Por restarigi ĝin, rulu denove la originalan `.msi` kaj elektu *Repair* (Ripari).
- **La menuo en la unua nivelo estas registrita nur se la instalo okazas en interaga, ensalutinta seanco.** Instali la `.msi` por ĉiuj uzantoj el fora aŭ neinteraga seanco (per SSH, aŭ silenta disponigo el administra ilo) ankoraŭ raportas sukceson, sed la pakaĵo por Windows 11 ne estas registrita, do aperas nur la klasika menuo sub «Show more options». Detaloj estas en [docs/INSTALL.md](https://github.com/7zStar/7-ZSTar/blob/main/docs/INSTALL.md#the-windows-11-right-click-menu).

## Sistemaj postuloj

Windows 7 aŭ Windows Server 2008 R2 kaj pli novaj (x64, x86); ĉe arm64 Windows 10 kaj pli novaj. Nenio alia estas instalenda. Tiu limo venas el la postuloj de la pakaĵoj; versioj pli malnovaj ol Windows 11 ne estis testitaj. Por Linux ekzistas komandlinia versio, kiun vi mem kompilas; macOS ne estas subtenata.

## Pri ĉi tiu projekto

7-ZSTar estas 7-Zip-disbranĉo pli amika al modernaj uzantoj de Windows 11. La kerno de 7-Zip estas bonega, sed kelkaj aferoj ne sekvis la hodiaŭan manieron de laboro: Windows 11 kaŝas ĝin sub «Show more options», kaj ĝi ne povas densigi al zstd. 7-ZSTar plenigas tiujn mankojn kaj lasas ĉion alian tia, kian vi konas.

## Dokumentaro

Ĉiu pakaĵo enhavas `7-zip.chm`, la helpan dosieron de la oficiala 7-Zip, senŝanĝan: **Helpo > Enhavo...** kaj F1 malfermas ĝin. Ĝi diras "7-Zip" ĉie kaj ne priskribas tion, kion aldonas 7-ZSTar; pri tio vidu ĉi tiun paĝon kaj [CHANGELOG.md](../../CHANGELOG.md).

Se la helpa dosiero ne troviĝas apud la plenumebla dosiero, samaj eroj malfermas ĉi tiun sekcion rete anstataŭe (en la angla).

## Konstruo el la fontkodo

Vidu [build/README.md](../../build/README.md). Mallonge: VS2022 Build Tools (MSVC v143), poste `pwsh build\Build.ps1`. Antaŭ ol kunfandi novan eldonon de la originalo (upstream), legu [MAINTAINING.md](../../MAINTAINING.md).

<a id="donate"></a>

## Donaci

7-ZSTar estas senpage uzebla, ĉu vi kontribuas, ĉu ne. Se ĝi ŝparis al vi iom da tempo kaj vi volas diri dankon, vi povas sendi kriptomonon al la suba adreso. La mono iras al mi, DraftingDreamer, por miaj propraj kostoj de programado, kaj ne aĉetas funkciojn, helpon aŭ ajnan promeson pri tio, kio venos poste.

Ĉiu ĵetono sur Ethereum aŭ Polygon bonvenas: ETH, POL, USDT, USDC aŭ io alia. La adreso estas la sama en ambaŭ retoj.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="QR-kodo de la donaca adreso">

- Oni akceptas nur transakciojn sur Ethereum (ERC20) kaj Polygon. Se vi povas uzi ambaŭ, Polygon kutime havas pli malaltajn transakciokostojn.
- Ĉi tiu estas la sola oficiala adreso, kaj mi neniam petos vin sendi al iu alia adreso.
- Transakcioj ne povas esti malfaritaj, do ne eblas repago.

Se vi donas stelon al 7-ZSTar ĉe GitHub aŭ rekomendas ĝin al amiko, ankaŭ tio helpas.

## Permesilo

LGPL v3, vidu [LICENSE](../../LICENSE). Iuj partoj havas aliajn kondiĉojn: ekzemple RAR-maldensigo portas la limigon unRAR, do kompilaĵo kun RAR-subteno ne estas pure LGPL v3. La kompleta listo troviĝas en [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md), kaj la kopirajtaj avizoj de ĉiuj komponantoj en [NOTICE](../../NOTICE).

## Dankoj

7-ZSTar staras sur la ŝultroj de multaj homoj. Dankon al ĉiuj, kiuj donis sian tempon al 7-Zip, al densigaj algoritmoj kaj al la malfermitkoda mondo ĝenerale. Sen vi ĉi tiu programo ne ekzistus.
