<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · [Română](README.ro.md) · **Svenska** · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

*Om innehållet här skiljer sig från den engelska versionen gäller den engelska versionen.*

**En fork av 7-Zip som är vänligare mot dig som använder Windows 11 i dag: en högerklicksmeny med 7-ZSTar på första nivån, zstd-komprimering och tar.zst i ett svep.**

[Ladda ner](https://github.com/7zStar/7-ZSTar/releases/latest) · [Webbplats](https://www.7zstar.com) · [Ändringslogg](../../CHANGELOG.md)

## Därför 7-ZSTar

- **Slut på ”Visa fler alternativ”.** I Windows 11 ligger 7-ZSTar direkt på första nivån i högerklicksmenyn.
- **tar.zst i ett steg.** Komprimera en mapp till .tar.zst, eller packa upp en, i ett enda steg, utan att någon .tar blir kvar på disken. Den officiella versionen av 7-Zip kan inte skapa .tar.zst och packar upp en i två steg, via en .tar.
- **Ungefär 10× snabbare än 7z.** På riktiga projektmappar komprimerade tar.zst 10 till 18 gånger snabbare.

## Hastighet

| Mapp | Filer | Originalstorlek | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 s / 76.7 MB | 38.4 s / 51.8 MB | **3.8 s** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 s / 107.8 MB | 54.8 s / 65.7 MB | **3.6 s** / 83.4 MB |
| Python `.venv` (stora binärfiler) | 11,654 | 671 MB | 25.5 s / 249.5 MB | 100.8 s / 167.2 MB | **5.6 s** / 210.9 MB |

tar.zst blev 15 till 23 procent mindre än zip, utan att vara långsammare. 7z ger fortfarande de minsta filerna (tar.zst blev 15 till 27 procent större), men tog mycket längre tid. Uppackning tog ungefär lika lång tid med alla tre.

Standardinställningar för alla tre; 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, NVMe SSD, median av 3 körningar, 2026-11.

## Format

- **Komprimera i ett steg:** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Packa upp i ett steg:** alla dessa, plus tar.lzma och tar.Z
- **Tillagda codecs:** zstd, brotli, lz4, lz5 och lizard (fristående eller inuti .7z), plus fast-lzma2, en alternativ LZMA2-kodare
- Alla format som den officiella versionen av 7-Zip hanterar fungerar fortfarande.

## Ladda ner

De flesta vill ha `.msi` för alla användare, x64, från [Releaser](https://github.com/7zStar/7-ZSTar/releases/latest).

| | Alla användare `.msi` | Bara du `-user.msi` | Portabel `.zip` |
|---|---|---|---|
| Kräver administratörsbehörighet | Ja | Nej | Nej |
| Högerklicksmeny | Första nivån i Windows 11 | Klassiska menyn (under ”Visa fler alternativ” i Windows 11) | Ingen |
| Start menu (Startmenyn) | Ja | Ja | Nej |

Alla finns även för x86 och arm64; välj den som passar din Windows. I 64-bitars Windows kanske x86-paketen saknar högerklicksmeny, och arm64-byggena har ännu inte prövats på riktig hårdvara. 7-ZSTar installeras vid sidan av den officiella versionen av 7-Zip utan att påverka den.

**Windows kan varna dig första gången.** Filerna är inte kodsignerade, så SmartScreen kan stoppa dem (”Windows har skyddat datorn”; du kan behöva expandera varningen för att se *Kör ändå*), och i Windows 11 med Smart appkontroll påslagen blockeras `.msi` helt. Varje release har en `SHA256SUMS`-fil att kontrollera din nedladdning mot. [INSTALL.sv.md](../install/INSTALL.sv.md#osignerade-paket-smartscreen-och-smart-appkontroll) förklarar hur, och vad du kan göra åt Smart appkontroll.

**Om menyn på första nivån:** i Windows 11 lägger `.msi` för alla användare till ett litet paket signerat med ett självsignerat certifikat och litar på det certifikatet; det är vad Windows kräver för första nivån. Avinstallationen tar bort båda. Vill du inte det installerar du med `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`. Paketet registreras för det konto som kör installationsprogrammet; andra konton registrerar det separat.

Filassociationer, avinstallation och paketet per användare beskrivs i [INSTALL.sv.md](../install/INSTALL.sv.md).

## Kommandorad

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

I PowerShell ska du sätta växeln inom citattecken: `7z a "-ttar.zst" backup.tar.zst docs`. Utan citattecknen delar PowerShell upp den i två och du får en fil som heter `.zst`. Command Prompt (cmd), alltså kommandotolken, behöver inga citattecken.

## Bra att veta

- **Om du stänger av ”Lägg till i 7-ZSTar som alternativ i Utforskarens snabbmeny”** (i filhanteraren, **Verktyg > Alternativ... > 7-ZSTar**) försvinner posten i högerklicksmenyn, precis som i den officiella versionen av 7-Zip. Med paketet för alla användare slår du på den igen genom att köra filhanteraren som administratör. Med paketet per användare går det inte (”Åtkomst nekad.”); kör `.msi` igen och välj *Repair* (reparera).
- **Tysta eller fjärrinstallationer i Windows 11** (över SSH, eller från ett distributionsverktyg) lyckas, men posten på första nivån registreras inte, så 7-ZSTar syns bara under ”Visa fler alternativ”. [Mer i INSTALL.sv.md](../install/INSTALL.sv.md#högerklicksmenyn-i-windows-11).
- **Uppackning av tar.br, tar.lz4, tar.lz5, tar.liz eller tar.Z** är fortfarande ett enda steg för dig, men går via en temporär fil som tas bort efteråt.

## Systemkrav

Windows 7 / Server 2008 R2 eller senare (x64, x86), eller Windows 10 eller senare på arm64. Inget annat behöver installeras. Testat på 64-bitars Windows 7 SP1 (med senare uppdateringar installerade), Windows 10 och Windows 11; [vad som testades](../install/INSTALL.sv.md#systemkrav). För Linux finns ett bygge för kommandoraden som du kompilerar själv; macOS stöds inte.

## Dokumentation

**Hjälp > Hjälp...** och F1 öppnar `7-zip.chm`, hjälpfilen i den officiella versionen av 7-Zip. Där står ”7-Zip” genomgående, och den beskriver inte det som 7-ZSTar lagt till; det gör den här sidan och [ändringsloggen](../../CHANGELOG.md). Saknas hjälpfilen öppnar samma poster det här avsnittet online.

Vill du bygga 7-ZSTar själv, se [build/README.md](../../build/README.md); läs [MAINTAINING.md](../../MAINTAINING.md) innan du slår ihop en ny uppströmsrelease.

<a id="donate"></a>

## Donera

7-ZSTar är gratis att använda, oavsett om du bidrar eller inte. Om det har sparat dig tid och du vill säga tack kan du skicka krypto till adressen nedan. Pengarna går till mig, DraftingDreamer, för mina egna utvecklingskostnader. Det ger ingen rätt till funktioner, hjälp eller några löften om vad som kommer härnäst.

Alla token på Ethereum eller Polygon är välkomna: ETH, POL, USDT, USDC eller något annat. Det är samma adress på båda nätverken.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="QR-kod för donationsadressen">

- Endast överföringar på Ethereum (ERC20) och Polygon accepteras. Kan du använda båda har Polygon oftast lägre avgifter.
- Det här är den enda officiella adressen, och jag ber dig aldrig skicka till en annan.
- Överföringar kan inte ångras, så de kan inte återbetalas.

Att ge 7-ZSTar en stjärna på GitHub eller tipsa en vän hjälper också.

## Licens

LGPL v3, se [LICENSE](../../LICENSE). Vissa delar har andra villkor: RAR-uppackning omfattas av unRAR-begränsningen, så ett bygge med RAR-stöd är inte rent LGPL v3. Hela listan finns i [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md), och upphovsrättsmeddelandena finns i [NOTICE](../../NOTICE).

Tack till alla som har lagt sin tid på 7-Zip, på komprimeringsalgoritmer och på öppen källkod i stort. 7-ZSTar hade inte funnits utan er.
