<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · **Esperanto**

*Se la enhavo malkonsentas kun la angla versio, validas la angla versio.*

**7-Zip-disbranĉo pli amika al modernaj uzantoj de Windows 11: la kunteksta menuo en la unua nivelo, zstd-densigo kaj tar.zst en unu paŝo.**

[Elŝuti](https://github.com/7zStar/7-ZSTar/releases/latest) · [Retejo](https://www.7zstar.com) · [Ŝanĝoprotokolo](../../CHANGELOG.md)

## Kial 7-ZSTar

- **Ne plu «Show more options» (Montri pliajn opciojn).** En Windows 11, 7-ZSTar estas rekte en la unua nivelo de la dekstraklaka menuo.
- **tar.zst en unu paŝo.** Densigu dosierujon al .tar.zst, aŭ elarĥivigu tian, en unu paŝo, sen ke restu .tar sur la disko. La oficiala 7-Zip ne povas krei .tar.zst kaj elarĥivigas tian en du paŝoj, tra .tar.
- **Ĉirkaŭ 10× pli rapide ol 7z.** Ĉe realaj projektaj dosierujoj tar.zst densigis 10 ĝis 18 foje pli rapide.

## Rapido

| Dosierujo | Dosieroj | Origina grando | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 s / 76.7 MB | 38.4 s / 51.8 MB | **3.8 s** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 s / 107.8 MB | 54.8 s / 65.7 MB | **3.6 s** / 83.4 MB |
| Python `.venv` (grandaj duumaj dosieroj) | 11,654 | 671 MB | 25.5 s / 249.5 MB | 100.8 s / 167.2 MB | **5.6 s** / 210.9 MB |

tar.zst estis 15 ĝis 23 % pli malgranda ol zip, kaj ne pli malrapida. 7z ankoraŭ kreas la plej malgrandajn dosierojn (tar.zst estis 15 ĝis 27 % pli granda), sed bezonis multe pli da tempo. Elarĥivigo daŭris proksimume same ĉe ĉiuj tri.

Implicitaj agordoj por ĉiuj tri; 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, NVMe SSD, mediano de 3 mezuroj, 2026-11.

## Formatoj

- **Densigo en unu paŝo:** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Elarĥivigo en unu paŝo:** ĉiuj tiuj, plus tar.lzma kaj tar.Z
- **Aldonitaj kodekoj:** zstd, brotli, lz4, lz5 kaj lizard (memstare aŭ ene de .7z), plus fast-lzma2, alternativa kodilo de LZMA2
- Ĉiu formato, kiun la oficiala 7-Zip traktas, daŭre funkcias.

## Elŝuto

Plej multaj homoj volas la `.msi` x64 por ĉiuj uzantoj el [Eldonoj](https://github.com/7zStar/7-ZSTar/releases/latest).

| | Por ĉiuj uzantoj `.msi` | Nur por vi `-user.msi` | Portebla `.zip` |
|---|---|---|---|
| Bezonas administrator rights (administrantajn rajtojn) | Jes | Ne | Ne |
| Kunteksta menuo | Unua nivelo en Windows 11 | Klasika menuo (en Windows 11 sub «Show more options») | Neniu |
| Ero en Start menu (la starta menuo) | Jes | Jes | Ne |

Ĉiu estas ankaŭ por x86 kaj arm64; elektu tiun, kiu kongruas kun via Windows. En 64-bita Windows la pakaĵoj x86 eble ne havas dekstraklakan menuon, kaj la kompilaĵoj arm64 ankoraŭ ne estis provitaj sur reala aparataro. 7-ZSTar instaliĝas apud la oficiala 7-Zip sen influi ĝin.

**Windows povas averti vin la unuan fojon.** La dosieroj ne estas kodsubskribitaj, do SmartScreen povas haltigi ilin («Windows protected your PC» (Windows protektis vian komputilon); eble necesas malfermi la averton por vidi *Run anyway* (rulu tamen)), kaj en Windows 11 kun ŝaltita Smart App Control (inteligenta kontrolo de aplikaĵoj) la `.msi` estas tute blokita. Ĉiu eldono havas dosieron `SHA256SUMS`, kun kiu vi povas kontroli vian elŝuton. [La instalaj klarigoj](../install/INSTALL.eo.md#nesubskribitaj-pakaĵoj-smartscreen-kaj-smart-app-control) klarigas kiel, kaj kion fari pri Smart App Control.

**Pri la menuo en la unua nivelo:** en Windows 11 la `.msi` por ĉiuj uzantoj aldonas malgrandan pakaĵon subskribitan per memsubskribita atestilo kaj fidas tiun atestilon; tion Windows postulas por la unua nivelo. Malinstalo forigas ambaŭ. Se vi preferas ne fari tion, instalu per `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`. La pakaĵo estas registrita por la konto, kiu rulas la instalilon; aliaj kontoj registras ĝin aparte.

Dosierasocioj, malinstalo kaj la pakaĵo por unu uzanto estas priskribitaj en [la instalaj klarigoj](../install/INSTALL.eo.md).

## Komandlinio

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

En PowerShell metu la opcion inter citilojn: `7z a "-ttar.zst" backup.tar.zst docs`. Sen citiloj PowerShell dividas ĝin en du kaj vi ricevas dosieron nomatan `.zst`. Command Prompt (cmd) (la komandlinia fenestro) ne bezonas citilojn.

## Bone scii

- **Malŝalti «Metu 7-ZSTar'on en kuntekstan menuon de ŝelo»** (dosiermastrumilo, **Agordoj > Agordoj... > 7-ZSTar**) forigas la dekstraklakan eron, same kiel en la oficiala 7-Zip. Ĉe la pakaĵo por ĉiuj uzantoj vi povas reŝalti ĝin per rulado de la dosiermastrumilo per «run as administrator» (kiel administranto). Ĉe la pakaĵo por unu uzanto tio ne eblas («Access is denied» (Aliro rifuzita)); rulu la `.msi` denove kaj elektu *Repair* (ripari).
- **Silentaj aŭ foraj instaloj en Windows 11** (per SSH, aŭ el disponiga ilo) sukcesas, sed la ero en la unua nivelo ne estas registrita, do 7-ZSTar aperas nur sub «Show more options». [Pli en la instalaj klarigoj](../install/INSTALL.eo.md#la-kunteksta-menuo-de-windows-11).
- **Elarĥivigo de tar.br, tar.lz4, tar.lz5, tar.liz aŭ tar.Z** restas unu paŝo por vi, sed pasas tra provizora dosiero, kiu poste estas forigita.

## Sistemaj postuloj

Windows 7 / Server 2008 R2 aŭ pli nova (x64, x86), aŭ Windows 10 aŭ pli nova ĉe arm64. Nenio alia estas instalenda. Provita en 64-bita Windows 7 SP1 (kun poste eldonitaj ĝisdatigoj instalitaj), Windows 10 kaj Windows 11; [kio estis provita](../install/INSTALL.eo.md#sistemaj-postuloj). Por Linux ekzistas komandlinia kompilaĵo, kiun vi mem kompilas; macOS ne estas subtenata.

## Dokumentaro

**Helpo > Enhavo...** kaj F1 malfermas `7-zip.chm`, la helpan dosieron de la oficiala 7-Zip. Ĝi diras «7-Zip» ĉie kaj ne priskribas tion, kion aldonas 7-ZSTar; tion faras ĉi tiu paĝo kaj la [ŝanĝoprotokolo](../../CHANGELOG.md). Se la helpa dosiero mankas, samaj eroj malfermas ĉi tiun sekcion rete.

Por kompili 7-ZSTar mem, vidu [build/README.md](../../build/README.md); antaŭ ol kunfandi novan eldonon de la originalo (upstream), legu [MAINTAINING.md](../../MAINTAINING.md).

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

LGPL v3, vidu [LICENSE](../../LICENSE). Iuj partoj havas aliajn kondiĉojn: RAR-maldensigo portas la limigon unRAR, do kompilaĵo kun RAR-subteno ne estas pure LGPL v3. La kompleta listo troviĝas en [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md), kaj la kopirajtaj avizoj estas en [NOTICE](../../NOTICE).

Dankon al ĉiuj, kiuj donis sian tempon al 7-Zip, al densigaj algoritmoj kaj al la malfermitkoda mondo ĝenerale. Sen vi 7-ZSTar ne ekzistus.
