<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Türkçe](README.tr.md) · **Nederlands** · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

*Wijkt de inhoud af van de Engelse versie, dan geldt de Engelse versie.*

**Een fork van 7-Zip die prettiger is voor moderne Windows 11-gebruikers: een rechtsklikmenu op het eerste niveau, zstd-compressie en tar.zst in één keer.**

[Downloaden](https://github.com/7zStar/7-ZSTar/releases/latest) · [Website](https://www.7zstar.com) · [Wijzigingslogboek](../../CHANGELOG.md)

## Waarom 7-ZSTar

- **Nooit meer “Meer opties weergeven”.** Op Windows 11 staat 7-ZSTar gewoon op het eerste niveau van het rechtsklikmenu.
- **tar.zst in één keer.** Comprimeer een map naar .tar.zst, of pak er een uit, in één stap, zonder dat er een .tar op schijf achterblijft. Het officiële 7-Zip kan geen .tar.zst maken en pakt er een in twee stappen uit, via een .tar.
- **Ongeveer 10× sneller dan 7z.** Op echte projectmappen werd tar.zst 10 tot 18 keer sneller gecomprimeerd.

## Snelheid

| Map | Bestanden | Oorspronkelijke grootte | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 s / 76.7 MB | 38.4 s / 51.8 MB | **3.8 s** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 s / 107.8 MB | 54.8 s / 65.7 MB | **3.6 s** / 83.4 MB |
| Python `.venv` (grote binaire bestanden) | 11,654 | 671 MB | 25.5 s / 249.5 MB | 100.8 s / 167.2 MB | **5.6 s** / 210.9 MB |

tar.zst werd 15 tot 23% kleiner dan zip, en niet trager. 7z maakt nog steeds de kleinste bestanden (tar.zst was 15 tot 27% groter), maar had veel meer tijd nodig. Uitpakken duurde bij alle drie ongeveer even lang.

Bij alle drie de standaardinstellingen; 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, NVMe SSD, mediaan van 3 runs, 2026-11.

## Formaten

- **In één keer comprimeren:** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **In één keer uitpakken:** al die formaten, plus tar.lzma en tar.Z
- **Toegevoegde codecs:** zstd, brotli, lz4, lz5 en lizard (op zichzelf of in een .7z), plus fast-lzma2, een alternatieve LZMA2-encoder
- Alle formaten die het officiële 7-Zip aankan, werken nog steeds.

## Downloaden

De meeste mensen willen de x64 `.msi` voor alle gebruikers van [Releases](https://github.com/7zStar/7-ZSTar/releases/latest).

| | Alle gebruikers `.msi` | Alleen jij `-user.msi` | Draagbare `.zip` |
|---|---|---|---|
| Beheerdersrechten nodig | Ja | Nee | Nee |
| Rechtsklikmenu | Eerste niveau op Windows 11 | Klassiek menu (op Windows 11 onder “Meer opties weergeven”) | Geen |
| Start menu-item (item in het Startmenu) | Ja | Ja | Nee |

Elk is er ook voor x86 en arm64; kies het pakket dat bij je Windows past. Op 64-bits Windows hebben de x86-pakketten mogelijk geen rechtsklikmenu, en de arm64-builds zijn nog niet op echte hardware geprobeerd. 7-ZSTar wordt naast het officiële 7-Zip geïnstalleerd, zonder dat te beïnvloeden.

**Windows kan je de eerste keer waarschuwen.** De bestanden zijn niet ondertekend met een code-handtekening, dus SmartScreen kan ze tegenhouden (“Uw pc wordt beschermd”; mogelijk moet je de waarschuwing eerst uitvouwen om *Toch uitvoeren* te zien), en op Windows 11 met Smart App Control ingeschakeld wordt de `.msi` helemaal geblokkeerd. Elke release heeft een `SHA256SUMS`-bestand waarmee je je download kunt controleren. In de [installatiegids](../install/INSTALL.nl.md#niet-ondertekende-pakketten-smartscreen-en-smart-app-control) staat hoe, en wat je kunt doen met Smart App Control.

**Over het menu op het eerste niveau:** op Windows 11 voegt de `.msi` voor alle gebruikers een klein pakket toe dat is ondertekend met een zelfondertekend certificaat en vertrouwt dat certificaat; dat is wat Windows voor het eerste niveau vereist. Bij het verwijderen verdwijnen beide. Wil je dat liever niet, installeer dan met `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`. Het pakket wordt geregistreerd voor het account dat het installatieprogramma uitvoert; andere accounts registreren het apart.

Bestandskoppelingen, verwijderen en het pakket per gebruiker worden behandeld in de [installatiegids](../install/INSTALL.nl.md).

## Opdrachtregel

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

Zet in PowerShell de schakelaar tussen aanhalingstekens: `7z a "-ttar.zst" backup.tar.zst docs`. Zonder aanhalingstekens splitst PowerShell hem in tweeën en krijg je een bestand met de naam `.zst`. In Command Prompt (cmd), oftewel de opdrachtprompt, zijn geen aanhalingstekens nodig.

## Goed om te weten

- **“7-ZSTar integreren in het contextmenu” uitzetten** (bestandsbeheer, **Extra > Opties... > 7-ZSTar**) haalt het rechtsklikitem weg, net als in het officiële 7-Zip. Bij het pakket voor alle gebruikers zet je het weer aan door het bestandsbeheer als administrator uit te voeren. Bij het pakket per gebruiker kan dat niet (“Toegang geweigerd.”); voer de `.msi` opnieuw uit en kies *Repair* (herstellen).
- **Stille of externe installaties op Windows 11** (via SSH, of vanuit een uitrolprogramma) slagen, maar het item op het eerste niveau wordt niet geregistreerd, dus 7-ZSTar verschijnt alleen onder “Meer opties weergeven”. [Meer in de installatiegids](../install/INSTALL.nl.md#het-windows-11-contextmenu).
- **Tar.br, tar.lz4, tar.lz5, tar.liz of tar.Z uitpakken** is voor jou nog steeds één stap, maar gaat via een tijdelijk bestand dat daarna wordt verwijderd.

## Systeemvereisten

Windows 7 / Server 2008 R2 of nieuwer (x64, x86), of Windows 10 of nieuwer op arm64. Er hoeft verder niets te worden geïnstalleerd. Getest op 64-bits Windows 7 SP1 (met latere updates geïnstalleerd), Windows 10 en Windows 11; [wat er is getest](../install/INSTALL.nl.md#systeemvereisten). Voor Linux is er een opdrachtregelversie die je zelf compileert; macOS wordt niet ondersteund.

## Documentatie

**Help > Inhoud...** en F1 openen `7-zip.chm`, het helpbestand van het officiële 7-Zip. Daarin staat overal “7-Zip” en wat 7-ZSTar toevoegt komt er niet in voor; deze pagina en het [wijzigingslogboek](../../CHANGELOG.md) wel. Ontbreekt het helpbestand, dan openen dezelfde items dit onderdeel online.

Wil je 7-ZSTar zelf bouwen, zie dan [build/README.md](../../build/README.md); lees [MAINTAINING.md](../../MAINTAINING.md) voordat je een nieuwe upstream-release samenvoegt.

<a id="donate"></a>

## Doneren

7-ZSTar is gratis te gebruiken, of je nu bijdraagt of niet. Heeft het je wat tijd bespaard en wil je bedanken, dan kun je crypto sturen naar het adres hieronder. Het gaat naar mij, DraftingDreamer, voor mijn eigen ontwikkelkosten, en koopt geen functies, hulp of beloftes over wat er daarna komt.

Elk token op Ethereum of Polygon is welkom: ETH, POL, USDT, USDC of iets anders. Het adres is op beide netwerken hetzelfde.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="QR-code van het donatieadres">

- Alleen overboekingen op Ethereum (ERC20) en Polygon worden geaccepteerd. Kun je beide gebruiken, dan zijn de kosten op Polygon meestal lager.
- Dit is het enige officiële adres en ik vraag je nooit om naar een ander adres te sturen.
- Overboekingen zijn onomkeerbaar en kunnen dus niet worden terugbetaald.

7-ZSTar een ster geven op GitHub of het aan een vriend vertellen helpt ook.

## Licentie

LGPL v3, zie [LICENSE](../../LICENSE). Sommige onderdelen hebben andere voorwaarden: voor het uitpakken van RAR geldt de unRAR-beperking, dus een build met RAR-ondersteuning is niet puur LGPL v3. De volledige lijst staat in [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md) en de copyrightvermeldingen in [NOTICE](../../NOTICE).

Dank aan iedereen die tijd heeft gestoken in 7-Zip, in compressiealgoritmen en in open source in het algemeen. Zonder jullie zou 7-ZSTar niet bestaan.
