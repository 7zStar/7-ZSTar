<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · **Deutsch** · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [Русский](README.ru.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

*Bei Unterschieden zur englischen Fassung gilt die englische Fassung.*

**Ein 7-Zip-Fork, der für heutige Windows-11-Nutzer angenehmer ist: Rechtsklickmenü auf der ersten Ebene, zstd-Komprimierung und tar.zst in einem Durchgang.**

[Download](https://github.com/7zStar/7-ZSTar/releases/latest) · [Website](https://www.7zstar.com) · [Changelog](../../CHANGELOG.md)

## Warum 7-ZSTar

- **Schluss mit „Weitere Optionen anzeigen“.** Unter Windows 11 steht 7-ZSTar gleich auf der ersten Ebene des Rechtsklickmenüs.
- **tar.zst in einem Schritt.** Einen Ordner nach .tar.zst komprimieren oder eine .tar.zst-Datei entpacken ist jeweils ein einziger Schritt, und es bleibt keine .tar-Datei auf der Platte zurück. Das offizielle 7-Zip kann keine .tar.zst-Dateien erstellen und entpackt sie in zwei Schritten, über eine .tar-Datei.
- **Etwa 10× schneller als 7z.** Bei echten Projektordnern komprimierte tar.zst 10- bis 18-mal schneller.

## Geschwindigkeit

| Ordner | Dateien | Originalgröße | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 s / 76.7 MB | 38.4 s / 51.8 MB | **3.8 s** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 s / 107.8 MB | 54.8 s / 65.7 MB | **3.6 s** / 83.4 MB |
| Python `.venv` (große Binärdateien) | 11,654 | 671 MB | 25.5 s / 249.5 MB | 100.8 s / 167.2 MB | **5.6 s** / 210.9 MB |

tar.zst war 15 bis 23 % kleiner als zip und nicht langsamer. 7z erzeugt weiterhin die kleinsten Dateien (tar.zst war 15 bis 27 % größer), brauchte dafür aber viel länger. Beim Entpacken dauerten alle drei etwa gleich lang.

Standardeinstellungen bei allen dreien; 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, NVMe SSD, Median aus 3 Durchläufen, 2026-11.

## Formate

- **In einem Schritt komprimieren:** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **In einem Schritt entpacken:** alle diese sowie tar.lzma und tar.Z
- **Hinzugefügte Codecs:** zstd, brotli, lz4, lz5 und lizard (einzeln oder innerhalb von .7z), dazu fast-lzma2, ein alternativer LZMA2-Encoder
- Alle Formate, die das offizielle 7-Zip beherrscht, funktionieren weiterhin.

## Download

Die meisten wollen die `.msi` für alle Benutzer in x64 von [Releases](https://github.com/7zStar/7-ZSTar/releases/latest).

| | `.msi` für alle Benutzer | Nur für Sie `-user.msi` | Portable `.zip` |
|---|---|---|---|
| Administratorrechte erforderlich | Ja | Nein | Nein |
| Rechtsklickmenü | Erste Ebene unter Windows 11 | Klassisches Kontextmenü (unter Windows 11 unter „Weitere Optionen anzeigen“) | Keines |
| Eintrag im Startmenü | Ja | Ja | Nein |

Jede Variante gibt es auch für x86 und arm64; wählen Sie die, die zu Ihrem Windows passt. Unter 64-Bit-Windows haben die x86-Pakete möglicherweise kein Rechtsklickmenü, und die arm64-Builds wurden noch nicht auf echter Hardware ausprobiert. 7-ZSTar lässt sich neben dem offiziellen 7-Zip installieren, ohne es zu beeinflussen.

**Windows warnt beim ersten Mal möglicherweise.** Die Dateien sind nicht codesigniert, daher kann SmartScreen sie stoppen („Der Computer wurde durch Windows geschützt“; unter Umständen müssen Sie die Warnung erweitern, um *Trotzdem ausführen* zu sehen), und unter Windows 11 mit aktivierter Smart App Control wird die `.msi` direkt blockiert. Jedes Release enthält eine Datei `SHA256SUMS`, mit der Sie Ihren Download abgleichen können. Die [Installationsanleitung](../install/INSTALL.de.md#nicht-signierte-pakete-smartscreen-und-smart-app-control) erklärt, wie das geht und was bei Smart App Control zu tun ist.

**Zum Menü auf der ersten Ebene:** Unter Windows 11 fügt die `.msi` für alle Benutzer ein kleines Paket hinzu, das mit einem selbstsignierten Zertifikat signiert ist, und stuft dieses Zertifikat als vertrauenswürdig ein; das verlangt Windows für die erste Ebene. Beim Deinstallieren wird beides entfernt. Wer das nicht möchte, installiert mit `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`. Das Paket wird für das Konto registriert, das das Installationsprogramm ausführt; andere Konten registrieren es separat.

Dateizuordnungen, das Deinstallieren und das Paket pro Benutzer werden in der [Installationsanleitung](../install/INSTALL.de.md) behandelt.

## Kommandozeile

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

In PowerShell setzen Sie den Schalter in Anführungszeichen: `7z a "-ttar.zst" backup.tar.zst docs`. Ohne sie teilt PowerShell ihn in zwei Teile, und Sie erhalten eine Datei namens `.zst`. Die Eingabeaufforderung (cmd) braucht keine Anführungszeichen.

## Gut zu wissen

- **Wer „7-ZSTar in Kontextmenü integrieren“ abschaltet** (Dateimanager, **Extras > Optionen > 7-ZSTar**), entfernt den Rechtsklick-Eintrag, genau wie beim offiziellen 7-Zip. Beim Paket für alle Benutzer schalten Sie ihn wieder ein, indem Sie den Dateimanager als Administrator ausführen. Beim Paket pro Benutzer geht das nicht („Zugriff verweigert“); führen Sie die `.msi` erneut aus und wählen Sie *Repair* (Reparieren).
- **Stille oder Remote-Installationen unter Windows 11** (über SSH oder ein Verteilungswerkzeug) gelingen, aber der Eintrag auf der ersten Ebene wird nicht registriert, sodass 7-ZSTar nur unter „Weitere Optionen anzeigen“ erscheint. [Mehr dazu in der Installationsanleitung](../install/INSTALL.de.md#das-windows-11-kontextmenü).
- **Das Entpacken von tar.br, tar.lz4, tar.lz5, tar.liz oder tar.Z** bleibt für Sie ein einziger Schritt, läuft aber über eine temporäre Datei, die danach gelöscht wird.

## Systemvoraussetzungen

Windows 7 / Server 2008 R2 oder neuer (x64, x86), bzw. Windows 10 oder neuer unter arm64. Es muss nichts weiter installiert werden. Getestet unter 64-Bit-Windows 7 SP1 (mit nachträglich installierten Updates), Windows 10 und Windows 11; [was getestet wurde](../install/INSTALL.de.md#systemvoraussetzungen). Für Linux gibt es eine Kommandozeilenversion, die Sie selbst kompilieren; macOS wird nicht unterstützt.

## Dokumentation

**Hilfe > Hilfethemen** und F1 öffnen `7-zip.chm`, die Hilfedatei des offiziellen 7-Zip. Darin steht überall „7-Zip“, und was 7-ZSTar ergänzt, wird nicht behandelt; das steht auf dieser Seite und im [Changelog](../../CHANGELOG.md). Fehlt die Hilfedatei, öffnen dieselben Einträge diesen Abschnitt online.

Wer 7-ZSTar selbst bauen möchte, findet alles in [build/README.md](../../build/README.md); bevor Sie eine neue Upstream-Version einpflegen, lesen Sie [MAINTAINING.md](../../MAINTAINING.md).

<a id="donate"></a>

## Spenden

7-ZSTar ist kostenlos nutzbar, ob Sie etwas beisteuern oder nicht. Wenn es Ihnen Zeit gespart hat und Sie Danke sagen möchten, können Sie Kryptowährung an die Adresse unten senden. Das Geld geht an mich, DraftingDreamer, für meine eigenen Entwicklungskosten. Dafür gibt es weder Funktionen noch Hilfe noch irgendein Versprechen, wie es weitergeht.

Jeder Token auf Ethereum oder Polygon ist willkommen: ETH, POL, USDT, USDC oder etwas anderes. In beiden Netzwerken gilt dieselbe Adresse.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="QR-Code der Spendenadresse">

- Es werden nur Transfers über Ethereum (ERC20) und Polygon akzeptiert. Wenn Sie die Wahl haben, empfiehlt sich Polygon: Dort sind die Gebühren meist niedriger.
- Das ist die einzige offizielle Adresse; ich bitte Sie nie, an eine andere zu senden.
- Blockchain-Transaktionen sind unumkehrbar, daher gibt es keine Rückerstattung.

Ein Stern auf GitHub oder eine Empfehlung an Freunde hilft auch.

## Lizenz

LGPL v3, siehe [LICENSE](../../LICENSE). Einige Teile unterliegen anderen Bedingungen: Die RAR-Entpackung trägt die unRAR-Einschränkung, ein Build mit RAR-Unterstützung ist also nicht rein LGPL v3. Die vollständige Liste steht in [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md), die Urheberrechtshinweise in [NOTICE](../../NOTICE).

Danke an alle, die ihre Zeit in 7-Zip, in Kompressionsalgorithmen und in Open Source insgesamt gesteckt haben. Ohne Sie gäbe es 7-ZSTar nicht.
