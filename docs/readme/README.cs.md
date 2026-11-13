<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · **Čeština** · [Magyar](README.hu.md) · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

*Pokud se obsah liší od anglické verze, platí anglická verze.*

**Fork programu 7-Zip, který je přívětivější pro uživatele moderního Windows 11: příkazy na první úrovni kontextové nabídky, komprese zstd a tar.zst na jeden průchod.**

[Stáhnout](https://github.com/7zStar/7-ZSTar/releases/latest) · [Web](https://www.7zstar.com) · [Seznam změn](../../CHANGELOG.md)

## Proč 7-ZSTar

- **Už žádné „Zobrazit další možnosti“.** Ve Windows 11 je 7-ZSTar přímo na první úrovni kontextové nabídky.
- **tar.zst na jeden krok.** Složku zkomprimujete do .tar.zst, nebo takový archiv rozbalíte, jedním krokem a na disku po tom nezůstane žádný .tar. Oficiální 7-Zip archiv .tar.zst vytvořit neumí a rozbaluje ho ve dvou krocích, přes .tar.
- **Zhruba 10× rychleji než 7z.** Na skutečných složkách s projekty byl tar.zst při kompresi 10 až 18krát rychlejší.

## Rychlost

| Složka | Soubory | Původní velikost | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 s / 76.7 MB | 38.4 s / 51.8 MB | **3.8 s** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 s / 107.8 MB | 54.8 s / 65.7 MB | **3.6 s** / 83.4 MB |
| Python `.venv` (velké binární soubory) | 11,654 | 671 MB | 25.5 s / 249.5 MB | 100.8 s / 167.2 MB | **5.6 s** / 210.9 MB |

Archivy tar.zst vyšly o 15 až 23 % menší než zip a nebyly pomalejší. Nejmenší soubory dělá pořád 7z (tar.zst byl o 15 až 27 % větší), ale trvalo mu to mnohem déle. Rozbalení trvalo u všech tří formátů zhruba stejně dlouho.

Všechny tři ve výchozím nastavení; 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, NVMe SSD, medián ze 3 běhů, 2026-11.

## Formáty

- **Komprese na jeden krok:** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Rozbalení na jeden krok:** všechny výše uvedené a navíc tar.lzma a tar.Z
- **Přidané kodeky:** zstd, brotli, lz4, lz5 a lizard (samostatně i uvnitř .7z) a fast-lzma2, alternativní kodér LZMA2
- Všechny formáty, které zvládá oficiální 7-Zip, fungují dál.

## Stažení

Většina lidí chce `.msi` pro všechny uživatele, x64, ze stránky [Vydání](https://github.com/7zStar/7-ZSTar/releases/latest).

| | `.msi` pro všechny uživatele | `-user.msi` jen pro vás | Přenosný `.zip` |
|---|---|---|---|
| Vyžaduje oprávnění správce | Ano | Ne | Ne |
| Kontextová nabídka | První úroveň ve Windows 11 | Klasická nabídka (ve Windows 11 pod „Zobrazit další možnosti“) | Žádná |
| Nabídka Start | Položka je | Položka je | Položka není |

Každý je i pro x86 a arm64; vyberte ten, který odpovídá vašemu Windows. V 64bitovém Windows nemusí mít balíčky x86 kontextovou nabídku a sestavení pro arm64 zatím nebyla vyzkoušena na skutečném hardwaru. 7-ZSTar se instaluje vedle oficiálního 7-Zip a nijak ho neovlivňuje.

**Windows vás při prvním spuštění může varovat.** Soubory nejsou podepsané kódem, takže je Filtr SmartScreen v programu Microsoft Defender může zastavit („Systém Windows ochránil váš počítač“; možná bude nutné varování rozbalit, aby se zobrazilo *Přesto spustit*) a ve Windows 11 se zapnutou funkcí Inteligentní řízení aplikací se `.msi` zablokuje úplně. Každé vydání obsahuje soubor `SHA256SUMS`, proti kterému si můžete stažený soubor ověřit. [Instalace](../install/INSTALL.cs.md#nepodepsané-balíčky-smartscreen-a-inteligentní-řízení-aplikací) vysvětluje jak a také co dělat, když je zapnutá funkce Inteligentní řízení aplikací.

**K nabídce na první úrovni:** ve Windows 11 přidává `.msi` pro všechny uživatele malý balíček podepsaný sám sebou vystaveným certifikátem a tomuto certifikátu důvěřuje; právě to Windows pro první úroveň vyžadují. Odinstalace odstraní obojí. Pokud to nechcete, nainstalujte pomocí `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`. Balíček se registruje pro účet, který spouští instalační program; ostatní účty si ho registrují zvlášť.

Přidružení souborů, odinstalace a balíček jen pro vás jsou popsány v [Instalaci](../install/INSTALL.cs.md).

## Příkazový řádek

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

V PowerShellu dejte přepínač do uvozovek: `7z a "-ttar.zst" backup.tar.zst docs`. Bez nich ho PowerShell rozdělí na dvě části a vznikne soubor s názvem `.zst`. Command Prompt (cmd), tedy příkazový řádek, uvozovky nepotřebuje.

## Dobré vědět

- **Vypnutí volby „Integrovat 7-ZSTar do kontextového menu“** (správce souborů, **Nástroje > Možnosti > 7-ZSTar**) odebere položku z nabídky po kliknutí pravým tlačítkem, stejně jako v oficiálním 7-Zip. U balíčku pro všechny uživatele ji znovu zapnete spuštěním správce souborů jako správce. U balíčku jen pro vás to nejde („Přístup byl odepřen.“); spusťte `.msi` znovu a zvolte *Repair*.
- **Tichá nebo vzdálená instalace ve Windows 11** (přes SSH nebo z nástroje pro nasazení) proběhne úspěšně, ale položka na první úrovni se nezaregistruje, takže se 7-ZSTar zobrazí jen pod „Zobrazit další možnosti“. [Více v Instalaci](../install/INSTALL.cs.md#kontextová-nabídka-windows-11).
- **Rozbalení tar.br, tar.lz4, tar.lz5, tar.liz nebo tar.Z** je pro vás pořád jeden krok, jen prochází dočasným souborem, který se potom smaže.

## Systémové požadavky

Windows 7 / Server 2008 R2 nebo novější (x64, x86), nebo Windows 10 či novější na arm64. Není třeba nic dalšího instalovat. Vyzkoušeno na 64bitovém Windows 7 SP1 (s nainstalovanými pozdějšími aktualizacemi), Windows 10 a Windows 11; [co bylo vyzkoušeno](../install/INSTALL.cs.md#systémové-požadavky). Pro Linux existuje sestavení pro příkazový řádek, které si musíte přeložit sami; macOS podporován není.

## Dokumentace

**Nápověda > Obsah** a F1 otevřou `7-zip.chm`, soubor nápovědy oficiálního 7-Zip. Všude v něm stojí „7-Zip“ a nepokrývá, co přidává 7-ZSTar; to najdete na této stránce a v [seznamu změn](../../CHANGELOG.md). Pokud soubor nápovědy chybí, stejné položky otevřou tuto část online.

Chcete-li si 7-ZSTar sestavit sami, viz [build/README.md](../../build/README.md); před sloučením nového vydání původního projektu si přečtěte [MAINTAINING.md](../../MAINTAINING.md).

<a id="donate"></a>

## Podpořit

7-ZSTar můžete používat zdarma, ať ho podpoříte, nebo ne. Pokud vám ušetřil čas a chcete poděkovat, můžete poslat kryptoměnu na níže uvedenou adresu. Dostanu ji já, DraftingDreamer, na pokrytí nákladů na vývoj; za peníze nezískáte žádné funkce, pomoc ani příslib, jak se bude projekt vyvíjet dál.

Vítán je jakýkoli token na sítích Ethereum nebo Polygon: ETH, POL, USDT, USDC i cokoli jiného. Na obou sítích je stejná adresa.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="QR kód adresy pro dar">

- Přijímají se pouze převody v sítích Ethereum (ERC20) a Polygon. Pokud můžete použít obě, Polygon má obvykle nižší poplatky.
- Toto je jediná oficiální adresa a nikdy vás nepožádám, abyste peníze poslali na jinou.
- Převody nelze zrušit, takže se peníze nedají vrátit.

Pomůže i dát 7-ZSTar hvězdičku na GitHubu nebo ho doporučit známému.

## Licence

LGPL v3, viz [LICENSE](../../LICENSE). Některé části mají jiné podmínky: dekomprese RAR podléhá omezení unRAR, takže sestavení s podporou RAR není čistě LGPL v3. Úplný seznam je v [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md) a oznámení o autorských právech v [NOTICE](../../NOTICE).

Děkujeme všem, kdo věnovali svůj čas programu 7-Zip, kompresním algoritmům i open source jako celku. Bez vás by 7-ZSTar neexistoval.
