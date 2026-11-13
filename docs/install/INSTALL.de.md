<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# 7-ZSTar installieren

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · **Deutsch** · [한국어](INSTALL.ko.md) · [Italiano](INSTALL.it.md) · [Polski](INSTALL.pl.md) · [Türkçe](INSTALL.tr.md) · [Nederlands](INSTALL.nl.md) · [Українська](INSTALL.uk.md) · [Bahasa Indonesia](INSTALL.id.md) · [ไทย](INSTALL.th.md) · [Čeština](INSTALL.cs.md) · [Magyar](INSTALL.hu.md) · [Română](INSTALL.ro.md) · [Svenska](INSTALL.sv.md) · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md)

*Bei Abweichungen vom englischen Text gilt die englische Fassung.*

Diese Seite führt die Kurzfassung im [README](../readme/README.de.md) näher aus: Systemvoraussetzungen, die SmartScreen-Warnung, Smart App Control und wie Sie einen Download prüfen, die drei Pakete, das Windows-11-Kontextmenü, Dateizuordnungen und die Deinstallation.

## Systemvoraussetzungen

**Windows 7 oder Windows Server 2008 R2, x64 oder x86. Unter arm64 Windows 10.**
Mehr ist nicht nötig: Die C-Laufzeit ist statisch eingebunden (`-MT`), die Programmdateien importieren also nur die eigenen DLLs von Windows – kein Redistributable, kein .NET.

Diese Untergrenze ist aus den Anforderungen der Pakete *abgeleitet*. Getestet wurde unter Windows 7 SP1 mit später erschienenen Updates (darunter PowerShell 5.1), unter Windows 10 22H2 und unter Windows 11, jeweils in der 64-Bit-Variante. Unter Windows 7 und 10 umfasste der Test die Installation und Deinstallation der x64-`.msi` für alle Benutzer und pro Benutzer, den Installationsassistenten, die x64-`.zip`, jeden ergänzten Codec und jedes Tar-Format in einem Schritt, das Kontextmenü, die Dateizuordnungen und die Hilfedatei sowie die x86-`.msi` und die x86-`.zip` unter 64-Bit-Windows. Nichts darüber hinaus wurde unter Windows getestet: weder Windows 8 oder 8.1 noch Windows Server, 32-Bit-Windows, arm64-Hardware oder Windows 7 ohne diese Updates. Die Untergrenze liegt außerdem höher als beim 7-Zip von Upstream, dessen Programmdateien noch unter Windows XP laden. Drei Dinge legen sie fest, und das zweite lässt sich durch keine Build-Einstellung rückgängig machen:

- Die `.msi` deklariert `InstallerVersion="500"`, und Windows Installer 5.0 wurde „with Windows Server 2008 R2 and later and Windows 7 and later“ (also mit Windows Server 2008 R2 und neuer sowie Windows 7 und neuer) ausgeliefert ([Microsoft][msi-versions]). Die portable `.zip` läuft nicht über Windows Installer, beachten Sie aber die nächsten beiden Punkte.
- **zstd und fast-lzma2 verwenden eine Synchronisierung, die es erst ab Vista gibt.** Beide erzwingen in ihren eigenen Headern `_WIN32_WINNT 0x0600` und rufen `InitializeConditionVariable` / `SleepConditionVariableCS` direkt auf. Deshalb importieren `7z.dll` und `7za.exe` – die beiden Programmdateien, in die die Codecs einkompiliert sind – vier Funktionen, die Windows XP und Server 2003 nicht haben. Die `7z.dll` von Upstream importiert keine davon.
- Die Toolchain: Gebaut wird mit Visual Studio 2022, dessen unterstützte Zielplattformen Windows 7 und neuer sind – Vista und Server 2008 stehen auf „No“ ([Microsoft][vs-targeting]). Die gelinkte Subsystemversion ist 6.0 unter x64 und x86 und 6.2 unter arm64, und Windows auf arm64 beginnt ohnehin erst mit Windows 10.

Windows Vista und Server 2008 liegen dazwischen: Die Programmdateien würden laden, aber die Toolchain unterstützt sie nicht, das Installationsprogramm läuft dort nicht, und 7-ZSTar ist darauf nicht getestet.

**Linux wird nur als Kommandozeilen-Build unterstützt; macOS wird nicht unterstützt.**
Der Fork baut mit gcc ein natives `7zz` (das Konsolenprogramm `Alone2`) über ein eigenes Makefile, das die Makefiles von Upstream einbindet und keines davon ändert:
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
Es wurde nur unter Ubuntu 24.04 mit gcc 13.3 (x86-64) gebaut und getestet: Der Build ist mit den Flags von Upstream warnungsfrei, der Smoke-Test mit 77 Prüfungen läuft durch, und die 25 unter Windows erzeugten und 37 unter Linux erzeugten Interop-Vektoren führen zu denselben Ergebnissen wie unter Windows. Die beiden fork-eigenen Dateien, die der Port berührt hat, lassen sich unter Windows weiterhin unverändert bauen (sauberer x64-Build, Smoke-Tests und Interop-Rücklesung laufen alle durch). Es gibt keine grafische Oberfläche. Die übrigen Linux-Ziele von Upstream (`7za`, `7zr`, `7z.so`) werden nicht unterstützt: In ihren gcc-Objektlisten fehlt, was die Änderungen des Forks an den Handlern von Upstream brauchen, sodass sie voraussichtlich beim Linken scheitern. Andere Architekturen, Distributionen und Compiler wurden nicht geprüft, und macOS wurde nie gebaut, weshalb sich kein `MACOSX_DEPLOYMENT_TARGET` angeben lässt. Build-Schritte, Tests und bekannte Grenzen stehen in `build/linux/README.md`; die Interoperabilität mit Linux-Werkzeugen steht in `test/interop/REPORT.md`.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## Nicht signierte Pakete, SmartScreen und Smart App Control

**Die Installationsprogramme und Programme einer 7-ZSTar-Version sind nicht von einer Zertifizierungsstelle codesigniert**, und dieses Projekt besitzt kein Codesignatur-Zertifikat. Windows kann deshalb nicht erkennen, wer die Datei veröffentlicht hat, und wenn Sie die `.msi` oder ein Programm aus der `.zip` zum ersten Mal ausführen, kann Microsoft Defender SmartScreen es mit einer Warnung stoppen. Die Entwicklerdokumentation von Microsoft nennt „No signature“ (keine Signatur) unter den Fällen, die eine Warnung mit dem Titel „Windows protected your PC“ (auf einem deutschsprachigen Windows: „Der Computer wurde durch Windows geschützt“) anzeigen und in denen der Benutzer „Run anyway“ („Trotzdem ausführen“) wählen muss, bevor die App startet ([Microsoft][smartscreen-rep]). Unternehmensrichtlinien können diese Wahl ganz entfernen; fragen Sie auf einem solchen PC die Person, die ihn verwaltet.

Das Einzige in einer Version, das signiert *ist*, ist das kleine Paket, das 7-ZSTar in die erste Ebene des Windows-11-Kontextmenüs bringt, enthalten in der `.msi` für alle Benutzer. Sein Zertifikat ist selbstsigniert und wird erzeugt, während nur dieses eine Paket gebaut wird. Es ist also keine Signatur einer Zertifizierungsstelle und sagt nichts darüber aus, wer das Paket gebaut hat; was es bewirkt und wie Sie es ablehnen, steht unter [Das Windows-11-Kontextmenü](#das-windows-11-kontextmenü).

Die Warnung ist kein Beweis dafür, dass eine Datei schlecht ist, und ihr Ausbleiben wäre kein Beweis dafür, dass eine Datei gut ist. Was Sie selbst prüfen können, ist, dass Ihre Kopie genau die ist, die auf der Release-Seite veröffentlicht wurde. Jede Version enthält eine Datei namens `SHA256SUMS`: eine Zeile pro Paket, ein SHA-256-Hash gefolgt vom Dateinamen.

1. Laden Sie das Paket und `SHA256SUMS` von derselben Release-Seite in denselben Ordner herunter.
2. Öffnen Sie PowerShell in diesem Ordner und vergleichen Sie. Ersetzen Sie den Namen durch die Datei, die Sie heruntergeladen haben:

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True` bedeutet, dass die Hashes identisch sind. Wenn Sie sie lieber selbst ansehen möchten, führen Sie stattdessen
   `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi` aus und suchen Sie denselben
   Dateinamen in `SHA256SUMS`; beim Vergleich wird die Groß- und Kleinschreibung ignoriert.
3. Wenn Sie `False` erhalten oder der Dateiname nicht in `SHA256SUMS` steht, führen Sie die Datei nicht aus: Löschen Sie sie und laden Sie sie erneut herunter. Stimmt sie dann immer noch nicht überein, melden Sie das bitte wie in [SECURITY.md](../../SECURITY.md) beschrieben.

`SHA256SUMS` deckt nur die Dateien ab, die zu dieser Version hochgeladen wurden. Wenn Sie denselben Tag selbst bauen, erhalten Sie andere Hashes (das Kontextmenü-Paket wird bei jedem Build mit einem neuen Zertifikat signiert), und der Quellcode wird mit jeder Version veröffentlicht, falls Sie lieber selbst bauen möchten: siehe [build/README.md](../../build/README.md).

Sobald die Hashes übereinstimmen und Sie mit der Herkunft der Datei zufrieden sind:

- **`.msi`** – starten Sie sie wie gewohnt. Hält SmartScreen sie an, wählen Sie die Option, sie trotzdem auszuführen („Trotzdem ausführen“ auf einem deutschsprachigen Windows, „Run anyway“ auf einem englischsprachigen Windows). Möglicherweise muss das Warnfenster zuerst erweitert werden: Auf dem getesteten Windows-10-Rechner bot es nur eine Schaltfläche an, die Datei nicht auszuführen, bis der Link unter der Meldung angeklickt wurde. Die `.msi` für alle Benutzer verlangt danach wie jedes andere Installationsprogramm die Genehmigung eines Administrators.
- **`.zip`** – entpacken Sie sie und starten Sie `7zFM.exe` oder `7z.exe` aus dem Ordner. Auch die darin enthaltenen Programme sind nicht signiert, sodass Windows beim ersten Start jedes einzelnen dieselbe Warnung zeigen kann.

SmartScreen warnt danach, wie bekannt eine Datei ist, nicht nur anhand von Signaturen; eine Datei, die nur wenige Personen heruntergeladen haben, kann die Warnung auch dann auslösen, wenn sie signiert ist. Nichts hier ändert das, und nichts in den obigen Schritten schaltet SmartScreen aus.

### Smart App Control unter Windows 11

Auf manchen Windows-11-PCs ist ein strengerer Schutz namens **Smart App Control** eingeschaltet. Ist er eingeschaltet, blockiert Windows nicht signierte Dateien, es sei denn, der Cloud-Dienst von Microsoft kann für sie bürgen, und eine neue Version hat in der Regel keinen solchen Eintrag ([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). Anders als bei der SmartScreen-Warnung gibt es bei der Sperre keine Option, die Datei trotzdem auszuführen, und laut den FAQ von Microsoft gibt es keine Möglichkeit, Smart App Control für eine einzelne App zu umgehen.

Was passierte, als 7-ZSTar 26.05.1 unter Windows 11 Pro 25H2 (Build 26200.8037) mit eingeschaltetem Smart App Control ausprobiert wurde:

- **Die `.msi`-Installationsprogramme wurden blockiert**, das für alle Benutzer ebenso wie das pro Benutzer. Auf einem Windows in traditionellem Chinesisch meldete Windows Installer „系統禁用此安裝。請連絡系統管理員。“, und eine Benachrichtigung der Windows-Sicherheit besagte, dass Smart App Control die Datei blockiert hatte, weil Windows nicht erkennen konnte, wer sie veröffentlicht hat, und es keine App ist, die Windows kennt. Es gab keine Option zum Fortfahren, und `msiexec /i ... /qn` gab den Fehler 1625 zurück. Diese Meldung ist die Zeichenfolge 1625 von Windows Installer; auf einem englischsprachigen Windows lautet dieselbe Zeichenfolge „The system administrator has set policies to prevent this installation.“ (aus den englischen Ressourcen von Windows Installer gelesen, nicht auf dem Bildschirm gesehen).
- **Ein Programm aus der `.zip` lief.** `7zFM.exe`, aus der portablen `.zip` entpackt, startete im selben Test normal. Ob Windows ein nicht signiertes Programm ausführen lässt, ist eine eigene Beurteilung dieser Datei, daher kann es auf Ihrem PC anders sein.
- Kurz nachdem Smart App Control eingeschaltet worden war, ließ sich die `.msi` noch einige Minuten lang installieren, bevor sie blockiert wurde. Die Ursache wurde nicht gefunden, ein Erfolg direkt nach dem Einschalten bedeutet also nicht, dass das Installationsprogramm zugelassen ist.

Auf einem PC mit eingeschaltetem Smart App Control **lassen sich die Installationsprogramme also nicht installieren**, und die Prüfung von `SHA256SUMS` ändert daran nichts. Etwas ändern kann das Ausschalten von Smart App Control in den Einstellungen für Smart App Control der App Windows-Sicherheit (auf dem getesteten Windows in traditionellem Chinesisch: Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定). Im Test wirkte die Wahl der Option „Deaktiviert“ sofort und ohne Neustart, und die Installationsprogramme ließen sich danach installieren. Das ist eine Einstellung für den ganzen PC, und nichts hier fordert Sie auf, sie zu ändern: Das entscheiden Sie selbst, auf einem verwalteten PC Ihr Administrator.

Es lohnt sich auch, vorher zu wissen, ob man es wieder einschalten kann. Laut den FAQ von Microsoft erlauben aktuelle Windows-Updates, Smart App Control ohne Neuinstallation von Windows wieder einzuschalten; auf einer Version ohne sie kann das Ausschalten also dauerhaft sein. Im hier getesteten Build wurde die Option zum Einschalten nach dem Ausschalten weiterhin angeboten; das ist ein Testergebnis, kein Versprechen für Ihre Version.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## Installation

Drei Pakete, alle gebaut von `installer\Build-Package.ps1` (das Paket pro Benutzer mit `-PerUser`):

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| Installiert für | alle Konten | das installierende Konto | - |
| Kontextmenü im Datei-Explorer | ja | ja, nur klassisches Menü ([unten](#das-paket-pro-benutzer)) | nein |
| Eintrag im Startmenü | ja | ja | nein |
| Benötigt Administrator | ja | nein | nein |
| Entfernen | *Installierte Apps* in den Einstellungen | *Installierte Apps* in den Einstellungen | Ordner löschen |

*Installierte Apps* ist der Name unter Windows 11. Windows 10 nennt dieselbe Seite *Apps und Features*, und unter Windows 7 ist es *Programs and Features* (Programme und Funktionen) im Control Panel (Systemsteuerung).

Verwenden Sie die Pakete, die zu Windows selbst passen: x86 unter 32-Bit-Windows, x64 unter 64-Bit-Windows, arm64 unter Windows on Arm (die arm64-Pakete werden gebaut, wurden aber noch nie ausgeführt). Die x86-Shell-Erweiterung ist 32-Bit, und der 64-Bit-Explorer kann sie nicht laden. Unter 64-Bit-Windows hat die x86-`-user.msi` deshalb gar kein Kontextmenü, und die x86-`.msi` hat nur unter Windows 11 eines, und nur für Konten, die ihr Windows-11-Paket registriert haben (das installierende oder eines, das `-Register` ausgeführt hat, siehe unten).

Die MSI installiert nach `Program Files\7-ZSTar` – immer: Anders als das Paket pro Benutzer bietet sie keine Ordnerauswahl und ignoriert `INSTALLFOLDER` auf der Kommandozeile, weil dieser Ordner ein Skript enthält, das das Installationsprogramm als SYSTEM ausführt, und eine DLL, die der Explorer jedes Benutzers lädt, und ein anderswo angelegter Ordner (etwa unter `C:\`) für jeden Benutzer beschreibbar ist. Sie registriert ihre eigene CLSID der Shell-Erweiterung und ihren eigenen Registry-Hive `Software\7-ZSTar` und nennt jeden Kontextmenü-Schlüssel `7-ZSTar` – sie kollidiert also weder mit denen des offiziellen 7-Zip noch entfernt sie diese. Siehe [installer/GUIDS.md](../../installer/GUIDS.md).

Sie führt einen normalen Installationsassistenten aus (welcome, licence, setup type, optional feature tree, finish: Willkommen, Lizenz, Setup-Typ, Baum der optionalen Funktionen, Abschluss), und die stille Installation funktioniert weiterhin unverändert (`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`), weil msiexec im stillen Modus die gesamte Oberflächensequenz überspringt. Der Assistent ist nur auf Englisch, auch unter einem Windows, das auf eine andere Sprache eingestellt ist (gesehen unter Windows 10 in traditionellem Chinesisch; die `.msi` wird ohne weitere Sprache gebaut), und auf seiner Abschlussseite ist *Launch 7-ZSTar File Manager* (7-ZSTar-Dateimanager starten) standardmäßig angehakt.

### Das Windows-11-Kontextmenü

Unter Windows 11 steht der Eintrag im Menü der ersten Ebene und nicht versteckt unter *Weitere Optionen anzeigen*, wo das offizielle 7-Zip und WinRAR noch immer stehen. Windows 11 listet dort eine Shell-Erweiterung nur auf, wenn sie mit Paketidentität kommt. Deshalb liefert die MSI neben dem Programm ein kleines MSIX-Paket nur mit Identität mit und registriert es bei der Installation. Die klassische Registrierung bleibt zusätzlich erhalten. Sie bringt den Eintrag unter Windows 10 und Windows 7 ins Kontextmenü, dessen Menü nur eine Ebene hat und kein *Weitere Optionen anzeigen* kennt, und sie sorgt dafür, dass er für alle funktioniert, die das alte Kontextmenü wiederhergestellt haben.

Dieses Paket ist mit einem **selbstsignierten Zertifikat** signiert, und das Installationsprogramm legt es in `LocalMachine\TrustedPeople` ab – Windows stellt kein Paket bereit, dessen Signatur sich nicht auf etwas Vertrauenswürdiges zurückführen lässt. Die Deinstallation entfernt das Zertifikat zusammen mit dem Paket. Unter Windows 10 und Windows 7 tut das Installationsprogramm beides nicht: Es fügt kein Zertifikat hinzu und registriert kein Paket, und das Menü kommt allein aus der klassischen Registrierung.

Wenn Sie einem selbstsignierten Zertifikat lieber nicht vertrauen möchten, lehnen Sie nur diesen Teil ab und behalten Sie alles andere:

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

Dann erhalten Sie nur das klassische Menü, sodass der 7-ZSTar-Eintrag unter Windows 11 im Kontextmenü unter *Weitere Optionen anzeigen* steht. Um den Eintrag der ersten Ebene später einzuschalten oder nach einer normalen Installation rückgängig zu machen:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

Dieses Zertifikat als vertrauenswürdig zu behandeln heißt, dass Windows auch **jedes andere** mit demselben Schlüssel signierte Paket ohne Warnung akzeptiert. Es wird nur für dieses eine Paket verwendet, und die Deinstallation nimmt es wieder heraus, aber dem stimmen Sie damit zu – `SPARSE=0` oben ist der Weg, es abzulehnen.

Die Paketregistrierung gilt pro Benutzer, und das Installationsprogramm führt sie nur für den aus, der installiert hat. Daraus folgen zwei Dinge:

- Ein zweites Konto auf demselben Rechner erhält nur das klassische Menü, bis es dasselbe Skript mit `-Register` ausführt.
- Die Deinstallation hebt die Registrierung nur für den auf, der deinstalliert. Hat jemand anderes sie registriert, überdauert seine Registrierung die Deinstallation und zeigt auf einen Ordner, den es nicht mehr gibt; dieses Konto entfernt sie mit `Get-AppxPackage 7-ZSTar | Remove-AppxPackage`.

**Bekannte Einschränkung: Das Menü der ersten Ebene wird nur registriert, wenn die Installation in einer interaktiven, angemeldeten Sitzung läuft.** Wird die `.msi` für alle Benutzer aus einer Remote- oder nicht interaktiven Sitzung installiert – über SSH oder bei einer stillen Verteilung durch ein Verwaltungswerkzeug –, wird weiterhin Erfolg gemeldet, aber das Windows-11-Paket wird nicht registriert, sodass nur das klassische Menü unter *Weitere Optionen anzeigen* erscheint. Im Test beendete sich `msiexec /i ... /qn` aus einer SSH-Sitzung (Sitzung 0) mit 0, während `Setup-ShellIntegration.ps1` `registration failed: 0x80070005` meldete (Zugriff verweigert); dieselbe `.msi`, aus der Konsolensitzung eines Administrators installiert, registrierte sich normal.

`-Status` gibt aus, was vorhanden ist und was nicht.

### Das Paket pro Benutzer

`7-ZSTar-<version>-<arch>-user.msi` installiert nur für das aktuelle Konto nach `%LOCALAPPDATA%\Programs\7-ZSTar`, ohne Abfrage der Benutzerkontensteuerung (UAC). Alles, was es registriert, liegt unter `HKCU`; das Paket schreibt nichts nach `HKLM` (von der eigenen Buchführung von Windows Installer abgesehen). Was es nicht so macht wie das Paket pro Computer:

- **Kein Menü der ersten Ebene unter Windows 11.** Unter Windows 11 steht 7-ZSTar im Kontextmenü unter *Weitere Optionen anzeigen*. Der Eintrag der ersten Ebene braucht das selbstsignierte Zertifikat als computerweit vertrauenswürdig, wofür ein Administrator nötig ist: Unter Windows 11 gemessen reicht ein Zertifikat in `CurrentUser\TrustedPeople` nicht, damit Windows das Paket bereitstellt. Deshalb lässt das Paket pro Benutzer ihn weg.
- **Nur eines der beiden pro Computer.** Jedes Paket weigert sich zu installieren, solange das andere installiert ist; deinstallieren Sie eines, bevor Sie das andere installieren. Das Paket pro Computer sieht nur die Kopie pro Benutzer des Kontos, das es ausführt, sodass die Installation pro Benutzer eines anderen Kontos nicht erkannt wird.
- **Eine Gruppenrichtlinie kann sein Menü ausblenden.** Wo `EnforceShellExtensionSecurity` gesetzt ist, lädt der Explorer nur Shell-Erweiterungen, die unter dem computerweiten Schlüssel *Approved* aufgeführt sind, den eine Installation pro Benutzer nicht beschreiben kann, sodass das Kontextmenü nicht erscheint. Verwenden Sie dort das Paket pro Computer.
- **Das Löschen eines Formats unter Extras > Optionen > System entfernt auch das Angebot von 7-ZSTar dafür.** Wenn Sie dort ein Format löschen (klicken Sie auf seine Zelle, bis sie leer ist, dann OK), löscht der Dateimanager die gesamten Schlüssel `HKCU\Software\Classes\.<ext>` und `7-ZSTar.<ext>` – und bei einer Installation pro Benutzer enthalten diese Schlüssel auch das, was das Paket für Einstellungen > Apps > Standard-Apps und die Liste *Öffnen mit* registriert hat. 7-ZSTar verschwindet dann für dieses Format aus *Öffnen mit*, und Standard-Apps zeigt dafür einen leeren Eintrag. Die Reparatur der Installation bringt es zurück (führen Sie die `.msi` erneut aus und wählen Sie *Repair* (Reparieren)). Besser ist es, Dateitypen in Standard-Apps zuzuweisen statt im Dateimanager. Das Paket pro Computer hat dieselbe Schwachstelle an einer Stelle, die unten bei den Dateizuordnungen beschrieben ist.

### Dateizuordnungen und was die Deinstallation damit macht

**Legen Sie sie unter Einstellungen > Apps > Standard-Apps fest.** Unter Windows 11 geben Sie dort 7-ZSTar ein, und jedes Format, das es öffnen kann, wird zur Zuweisung aufgelistet. Unter Windows 10 ist 7-ZSTar auf dieser Seite unter *Set defaults by app* (Standardwerte nach App festlegen) aufgeführt, wo *Manage* (Verwalten) seine Formate zeigt. Windows 7 hat keine Einstellungen-App: 7-ZSTar ist unter Control Panel (Systemsteuerung) > Standardprogramme > *Standardprogramme festlegen* aufgeführt, und das ist es, was *Standard-Apps* in dieser Anleitung dort meint. Die Zuweisung von Formaten über diese beiden Seiten wurde nicht getestet. Das Installationsprogramm registriert 7-ZSTar als Anwendung für Standardprogramme – eine ProgID pro Format mit Symbol und Öffnen-Befehl, einen Eintrag in der Liste *Öffnen mit* jeder Erweiterung und den Capabilities-Block, den Windows liest –, beansprucht aber bewusst keinen Dateityp: Welches Programm Ihre Archive öffnet, entscheiden Sie, und genau das hält 7-ZSTar und das offizielle 7-Zip voneinander fern. Windows kann ein Format trotzdem von sich aus an 7-ZSTar schicken, wenn kein anderes Programm anbietet, es zu öffnen: Auf den getesteten Windows-10- und Windows-7-Rechnern, auf denen nichts anderes `.7z` registriert hatte, zeigte eine `.7z`-Datei das Symbol von 7-ZSTar und öffnete sich per Doppelklick damit, ohne dass Windows fragte, welches Programm verwendet werden soll.

**Extras > Optionen > System im Dateimanager funktioniert unter Windows 11 größtenteils nicht**, und das ist eine Windows-Regel und kein Fehler hier. Es schreibt eine ProgID `7-ZSTar.<ext>` nach `HKCU\Software\Classes`, und für jede Erweiterung, die der Rechner bereits kennt – jedes Archivformat gehört dazu –, ignoriert Windows 11 sie: `AssocQueryString` antwortet `Unknown`, und der Explorer zeichnet das leere generische Symbol. Berücksichtigt wird stattdessen ein Schlüssel `UserChoice`, der mit einem Hash versehen ist, den nur Windows berechnen kann; deshalb ist die Einstellungen-Oberfläche dort der einzige Weg. Keine Anwendung kann einen solchen schreiben: nicht 7-ZSTar, nicht 7-Zip, kein Installationsprogramm. Windows 10 und Windows 7 verhielten sich im Test anders: Nachdem `.7z` und `.zst` im Dateimanager festgelegt worden waren, ohne dass ein anderes Programm dafür gewählt war, gab `AssocQueryString` für beide `7zFM.exe` zurück.

**Das Löschen eines Formats in seiner Spalte *alle Benutzer* entfernt die eigene Registrierung des Pakets pro Computer dafür.** Diese Spalte schreibt nach `HKLM\Software\Classes`, wo das Paket pro Computer die ProgIDs und die *Öffnen mit*-Einträge hält, die es anbietet, und das Löschen eines Formats dort (was einen Dateimanager voraussetzt, der mit *Als Administrator ausführen* gestartet wurde) löscht diese Schlüssel vollständig – für jedes Konto. Die Reparatur stellte beim Paket pro Benutzer dieselben Schlüssel wieder her; bei diesem wurde es nicht gemessen.

**Ein Symbol, das nach einer Änderung leer bleibt**, kann auch am Symbol-Cache des Explorers liegen, der nicht bemerkt, dass eine bereits zwischengespeicherte DLL ersetzt wurde; `ie4uinit.exe -show` leert ihn nicht zuverlässig. Schließen Sie den Explorer, löschen Sie `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db` und starten Sie ihn neu.

**Die Deinstallation entfernt die Zuordnungen, die sie erreichen kann** – die `7-ZSTar.*`-ProgIDs dessen, der deinstalliert, und nur die Dateitypen, die noch darauf zeigen, sodass ein Format, das inzwischen einem anderen Programm übergeben wurde, in Ruhe gelassen wird. Die Deinstallation des Pakets pro Computer lässt außerdem eine ProgID in Ruhe, die eine anderswo noch vorhandene Kopie von 7-ZSTar öffnet – eine portable aus der `.zip`, eingerichtet über die eigenen **Extras > Optionen > System** dieser Kopie. Das Paket pro Benutzer kann das nicht: Seine ProgIDs sind genau diese `HKCU`-Schlüssel (siehe *Das Paket pro Benutzer* oben), und seine Deinstallation entfernt sie, wer auch immer sie zuletzt geschrieben hat. Sie zurückzulassen würde diese Typen auf eine ProgID zeigen lassen, deren Symbol und Befehl eine gelöschte ausführbare Datei sind – also ein leeres Symbol und eine Fehlermeldung beim Doppelklick. Die Zuordnungen anderer Konten sind außer Reichweite; sie können ihre eigenen mit `Setup-ShellIntegration.ps1 -RemoveAssociations` entfernen, bevor das Programm verschwindet. `msiexec /x ... KEEPASSOC=1` überspringt das, und ein Upgrade tut es nie.

**Bekannte Einschränkung: Andere Konten behalten die Zuordnungen, die sie selbst festgelegt haben.** Die Deinstallation des Pakets pro Computer löscht nur das, was das Konto, das die Deinstallation ausführt, in seiner eigenen Spalte (deren Spaltenüberschrift der Kontoname ist) unter **Extras > Optionen > System** im Dateimanager festgelegt hat. Jedes andere Konto, das dort Zuordnungen festgelegt hat, behält sie, auf das entfernte Programm zeigend, sodass Windows beim Doppelklick auf eine `.7z`-Datei fragt, welches Programm verwendet werden soll. Jedes Konto sollte seine eigenen **vor** der Deinstallation löschen, mit

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

was nur die Einträge von 7-ZSTar entfernt, oder die Typen danach unter Einstellungen > Apps > Standard-Apps neu zuweisen. Im Dateimanager bedeutet es stattdessen, jede Zelle in der eigenen Spalte, die 7-ZSTar zeigt, anzuklicken, bis sie leer ist, dann OK; markieren Sie nicht alle Zeilen und drücken Sie nicht „+“, was einen Zustand auf jede markierte Zeile anwendet und damit auch Formate löscht, die einem anderen Programm gehören, etwa dem offiziellen 7-Zip.

Zuordnungen, die in der Spalte **alle Benutzer** festgelegt wurden, werden von der Aufräumaktion der Deinstallation überhaupt nicht angetastet und lassen jedes Konto auf das entfernte Programm zeigen. Ein Administrator, der welche festgelegt hat, sollte diese Zellen löschen, aus einem Dateimanager, der mit *Als Administrator ausführen* gestartet wurde, dann OK, bevor er deinstalliert; `-RemoveAssociations` erreicht diese Spalte nicht. Sie direkt vor einer Deinstallation zu leeren ist unschädlich, auch wenn es dort die eigene Registrierung des Pakets löscht (siehe oben), denn die Deinstallation entfernt sie ohnehin. Das Paket pro Benutzer hat das Problem mit anderen Konten nicht, und das offizielle 7-Zip verhält sich genauso.

## Sprachen

Jedes Paket enthält die Übersetzungen von Upstream, gut 90 Sprachen. Wählen Sie eine unter **Extras > Optionen > Sprache**; die MSI erlaubt es außerdem, sie bei der Installation *Custom* (benutzerdefiniert) wegzulassen. 7-ZSTar versucht, beim ersten Start der Systemsprache zu folgen, aber diese Erkennung gibt auf und bleibt bei Englisch, wenn die Windows-Einstellungen „language for non-Unicode programs“ (Sprache für Programme, die kein Unicode unterstützen) und „Regionales Format“ nicht übereinstimmen – eine Sprache von Hand zu wählen funktioniert immer.

Zeichenfolgen, die 7-ZSTar selbst hinzugefügt hat – die Felder für Zstd-Stufe und Wörterbuch, die Namen der neuen Archivformate –, haben keine Übersetzung von Upstream und bleiben Englisch. Die Ausnahme sind die Schaltflächen **Spenden** und **Website** im Dialog „Über 7-ZSTar“: 67 der 92 Sprachen haben jeweils ein eigenes Wort dafür, die übrigen 25 zeigen Englisch (`Lang/UPSTREAM.md` listet sie auf).
Die Übersetzungen sind übernommen und nicht hier geschrieben: siehe [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md).
