<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · **Deutsch** · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [Esperanto](README.eo.md)

**Ein 7-Zip-Fork, der besser zu Windows 11 passt: Rechtsklickmenü auf der ersten Ebene, zstd-Kompression und tar.zst in einem Durchgang.**

[Download](https://github.com/7zStar/7-ZSTar/releases/latest) · [Website](https://www.7zstar.com/de/) · [Changelog](../../CHANGELOG.md)

## Warum 7-ZSTar

- **Ohne „Weitere Optionen anzeigen“.** Mit dem MSI für alle Benutzer steht 7-ZSTar im Windows-11-Rechtsklickmenü gleich auf der ersten Ebene.
- **Ein Durchgang. Kein .tar auf der Platte.** Das Komprimieren nach tar.zst und das Entpacken von tar.zst sind jeweils ein einziger Schritt, und in keiner Richtung wird ein .tar geschrieben. Das offizielle 7-Zip kann kein .tar.zst erstellen und entpackt eines in zwei Schritten, über ein .tar.
- **10× schneller als 7z.** Bei echten Projektordnern komprimierte tar.zst 10- bis 18-mal schneller als 7z.

## Geschwindigkeit

| Ordner | Dateien | Rohgröße | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13.371 | 207 MB | 4,1 s / 76,7 MB | 38,4 s / 51,8 MB | **3,8 s** / 59,7 MB |
| Python `.venv` | 9.795 | 346 MB | 6,6 s / 107,8 MB | 54,8 s / 65,7 MB | **3,6 s** / 83,4 MB |
| Python `.venv` (große Binärdateien) | 11.654 | 671 MB | 25,5 s / 249,5 MB | 100,8 s / 167,2 MB | **5,6 s** / 210,9 MB |

tar.zst war 15 bis 23 % kleiner als zip und nicht langsamer. Gegenüber 7z ist es allerdings 15 bis 27 % größer; wer die kleinste Datei will, greift also weiterhin zu 7z. Die Werte gelten für das Komprimieren; beim Entpacken lagen alle drei etwa gleichauf.

zip, 7z und tar.zst jeweils mit Standardeinstellungen. 7-ZSTar 26.05.1 x64 (7z.exe), ein Rechner (Intel Core Ultra 7 155H, NVMe-SSD), drei echte Projektordner, Median aus 3 Durchläufen, 2026-11.

## Formate

- **Komprimieren in einem Schritt (8):** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Entpacken in einem Schritt (10):** diese 8 sowie tar.lzma und tar.Z
- **Hinzugefügte Codecs:** zstd, brotli, lz4, lz5 und lizard, jeweils als eigenständiges Format und als Methode innerhalb von .7z; dazu fast-lzma2 als alternativer LZMA2-Encoder.
- Alle Formate, die 7-Zip bereits unterstützt, sind weiterhin dabei.

Beim Entpacken von tar.br, tar.lz4, tar.lz5, tar.liz oder tar.Z bleibt es für Sie ein einziger Schritt, 7-ZSTar dekodiert aber zuerst in eine Zwischendatei und löscht sie danach wieder.

## Kommandozeile

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

In PowerShell setzen Sie den Format-Schalter in Anführungszeichen, etwa `7z a "-ttar.zst" backup.tar.zst docs`. Ohne sie zerlegt PowerShell `-ttar.zst` in zwei Teile, und 7z legt eine Datei mit dem Namen `.zst` an. Die Eingabeaufforderung (cmd) braucht keine Anführungszeichen.

## Download und Installation

| | MSI für alle Benutzer `.msi` | Nur für Sie `-user.msi` | Portable `.zip` |
|---|---|---|---|
| Installiert für | Jedes Konto auf dem PC | Das aktuelle Konto | Keine Installation nötig |
| Administratorrechte erforderlich | Ja | Nein | Nein |
| Rechtsklickmenü | Windows 11: erste Ebene | Unter „Weitere Optionen anzeigen“ | Keines |
| Startmenü-Eintrag | Ja | Ja | Nein |

Alle drei gibt es als x64, x86 und arm64. Wählen Sie die Variante, die zu Ihrem Windows passt: Unter 64-Bit-Windows haben die x86-Pakete möglicherweise kein Rechtsklickmenü. Die arm64-Builds sind noch nicht auf echter Hardware gelaufen. 7-ZSTar lässt sich neben dem offiziellen 7-Zip installieren; beide beeinflussen sich nicht.

**Windows kann bei diesen Downloads warnen.** Die Installationsprogramme und Programme sind nicht von einer Zertifizierungsstelle codesigniert, deshalb kann Microsoft Defender SmartScreen sie beim ersten Start mit einer Warnung stoppen, und auf einem Windows-11-PC mit aktivierter Smart App Control werden die `.msi`-Installer direkt blockiert, ohne Möglichkeit fortzufahren. Das heißt nicht, dass die Datei schlecht ist: Jedes Release enthält eine Datei `SHA256SUMS`, mit der Sie prüfen können, ob Ihr Download mit der veröffentlichten Datei übereinstimmt. Wie die Prüfung funktioniert, was Smart App Control für Sie bedeutet und wie Sie nach erfolgreichem Abgleich weitermachen, steht in [docs/INSTALL.md](../INSTALL.md#unsigned-packages-smartscreen-and-smart-app-control).

**Zum Menü auf der ersten Ebene:** Windows 11 lässt nur Programme mit Paketidentität auf die erste Ebene. Deshalb installiert das MSI für alle Benutzer ein kleines MSIX-Paket, das mit einem selbstsignierten Zertifikat signiert ist, und stuft dieses Zertifikat als vertrauenswürdig ein. Bei der Deinstallation wird beides entfernt. Wer dem Zertifikat nicht vertrauen möchte, installiert mit `msiexec /i 7-ZSTar-<Version>-<Architektur>.msi SPARSE=0`; dann bleibt das Menü unter „Weitere Optionen anzeigen“. Das Paket wird nur für das Konto registriert, das das Installationsprogramm ausführt; andere Konten registrieren es separat.

Alle Details, auch zu Dateizuordnungen und zur Deinstallation, stehen in [docs/INSTALL.md](../INSTALL.md) (bisher nur auf Englisch).

## Bekannte Einschränkungen

- **Wer das Kontrollkästchen für die Shell-Integration abwählt, entfernt die Rechtsklick-Registrierung.** Im Dateimanager (`7zFM`) gibt es unter **Extras > Optionen > 7-ZSTar** das Kontrollkästchen „7-ZSTar in Kontextmenü integrieren“. Wie beim offiziellen 7-Zip löscht das Abwählen die vom Installationsprogramm angelegte Registrierung der Shell-Erweiterung (den `CLSID`-Schlüssel), und der Eintrag von 7-ZSTar verschwindet aus dem Rechtsklickmenü. Beim Paket für alle Benutzer können Sie das Kontrollkästchen wieder aktivieren, wenn der Dateimanager als Administrator läuft. Beim Paket für den aktuellen Benutzer geht das nicht: Erneutes Aktivieren zeigt „Zugriff verweigert“, und der Eintrag bleibt verschwunden. Um ihn zurückzuholen, führen Sie die ursprüngliche `.msi` erneut aus und wählen *Reparieren*.
- **Das Menü auf der ersten Ebene wird nur registriert, wenn die Installation in einer interaktiven, angemeldeten Sitzung läuft.** Wer die `.msi` für alle Benutzer aus einer Remote- oder nicht interaktiven Sitzung installiert (über SSH oder als stille Verteilung per Verwaltungstool), bekommt trotzdem eine Erfolgsmeldung, aber das Windows-11-Paket wird nicht registriert; es erscheint nur das klassische Menü unter „Weitere Optionen anzeigen“. Einzelheiten stehen in [docs/INSTALL.md](../INSTALL.md#the-windows-11-right-click-menu).

## Systemanforderungen

Windows 7 oder Windows Server 2008 R2 und neuer (x64, x86); unter arm64 Windows 10 und neuer. Es muss nichts weiter installiert werden. Diese Untergrenze ergibt sich aus den Anforderungen der Pakete; Versionen vor Windows 11 wurden nicht getestet. Für Linux gibt es eine Kommandozeilenversion, die Sie selbst kompilieren; macOS wird nicht unterstützt.

## Über dieses Projekt

7-ZSTar ist ein 7-Zip-Fork, der besser zu Windows 11 passt. Der Kern von 7-Zip ist hervorragend, aber manches hat mit der heutigen Arbeitsweise nicht Schritt gehalten: Windows 11 versteckt 7-Zip unter „Weitere Optionen anzeigen“, und nach zstd komprimieren kann es ebenfalls nicht. 7-ZSTar schließt diese Lücken und lässt alles andere so, wie Sie es kennen.

## Dokumentation

Jedes Paket enthält `7-zip.chm`, die Hilfedatei des offiziellen 7-Zip, unverändert: **Hilfe > Hilfethemen** und F1 öffnen sie. Darin steht überall „7-Zip“, und was 7-ZSTar ergänzt, wird nicht behandelt; dazu siehe diese Seite und [CHANGELOG.md](../../CHANGELOG.md).

Liegt die Hilfedatei nicht neben der ausführbaren Datei, öffnen dieselben Einträge stattdessen diesen Abschnitt online (auf Englisch).

## Aus dem Quellcode bauen

Siehe [build/README.md](../../build/README.md). Kurzfassung: VS2022 Build Tools (MSVC v143), dann `pwsh build\Build.ps1`. Bevor Sie eine neue Upstream-Version einpflegen, lesen Sie [MAINTAINING.md](../../MAINTAINING.md).

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

LGPL v3, siehe [LICENSE](../../LICENSE). Einige Teile unterliegen anderen Bedingungen: Die RAR-Entpackung etwa trägt die unRAR-Einschränkung, ein Build mit RAR-Unterstützung ist also nicht rein LGPL v3. Die vollständige Liste steht in [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md), die Urheberrechtshinweise aller Komponenten in [NOTICE](../../NOTICE).

## Danksagung

7-ZSTar steht auf den Schultern vieler Menschen. Danke an alle, die ihre Zeit in 7-Zip, in Kompressionsalgorithmen und in quelloffene Software insgesamt gesteckt haben. Ohne Sie gäbe es diese Software nicht.
