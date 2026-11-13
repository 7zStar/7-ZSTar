<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# 7-ZSTar installeren

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · [한국어](INSTALL.ko.md) · [Italiano](INSTALL.it.md) · [Polski](INSTALL.pl.md) · [Türkçe](INSTALL.tr.md) · **Nederlands** · [Українська](INSTALL.uk.md) · [Bahasa Indonesia](INSTALL.id.md) · [ไทย](INSTALL.th.md) · [Čeština](INSTALL.cs.md) · [Magyar](INSTALL.hu.md) · [Română](INSTALL.ro.md) · [Svenska](INSTALL.sv.md) · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md)

*Wijkt de inhoud af van de Engelse versie, dan geldt de Engelse versie.*

De details achter de korte versie in de [README](../readme/README.nl.md): systeemvereisten, de SmartScreen-waarschuwing, Smart App Control en hoe je een download controleert, de drie pakketten, het Windows 11-contextmenu, bestandskoppelingen en verwijderen.

## Systeemvereisten

**Windows 7 of Windows Server 2008 R2, x64 of x86. Op arm64 Windows 10.**
Meer is niet nodig: de C-runtime is statisch gelinkt (`-MT`), dus de uitvoerbare bestanden importeren alleen de eigen DLL's van Windows - geen redistributable, geen .NET.

Die ondergrens is *afgeleid* van wat de pakketten vereisen, en is getest op Windows 7 SP1 met latere updates (waaronder PowerShell 5.1), Windows 10 22H2 en Windows 11, allemaal 64-bits. Op Windows 7 en 10 omvatte dat het installeren en verwijderen van de x64-`.msi` voor alle gebruikers en per gebruiker, de installatiewizard, de x64-`.zip`, elke toegevoegde codec en elk tar-formaat in één stap, het contextmenu, bestandskoppelingen en het Help-bestand, en de x86-`.msi` en -`.zip` onder 64-bits Windows. Verder is op Windows niets getest: niet Windows 8 of 8.1, niet Windows Server, niet 32-bits Windows, niet arm64-hardware en niet Windows 7 zonder die updates. De ondergrens ligt ook hoger dan die van de 7-Zip van upstream, waarvan de binaire bestanden nog op Windows XP laden. Drie dingen zorgen daarvoor, en het tweede is het ding dat geen buildinstelling ongedaan kan maken:

- De `.msi` declareert `InstallerVersion="500"`, en Windows Installer 5.0 werd geleverd "with Windows Server 2008 R2 and later and Windows 7 and later" ([Microsoft][msi-versions]). De draagbare `.zip` gaat niet via Windows Installer, maar zie de volgende twee punten.
- **zstd en fast-lzma2 gebruiken synchronisatie die pas vanaf Vista bestaat.** Beide dwingen `_WIN32_WINNT 0x0600` af in hun eigen headers en roepen `InitializeConditionVariable` / `SleepConditionVariableCS` rechtstreeks aan, waardoor `7z.dll` en `7za.exe` - de twee binaire bestanden waarin de codecs zijn ingebouwd - vier functies importeren die Windows XP en Server 2003 niet hebben. De `7z.dll` van upstream importeert er geen enkele.
- De toolchain: deze bestanden worden gebouwd met Visual Studio 2022, waarvan de lijst met ondersteunde doelplatformen begint bij Windows 7 - Vista en Server 2008 staan op "No" ([Microsoft][vs-targeting]). De gelinkte subsysteemversie is 6.0 op x64 en x86 en 6.2 op arm64, en Windows op arm64 begint hoe dan ook bij Windows 10.

Windows Vista en Server 2008 vallen daartussenin: de binaire bestanden zouden laden, maar de toolchain ondersteunt ze niet, het installatieprogramma draait er niet en 7-ZSTar is er niet op getest.

**Linux wordt alleen ondersteund als opdrachtregelbuild; macOS wordt niet ondersteund.**
De fork bouwt met gcc een native `7zz` (het consoleprogramma `Alone2`) via een eigen makefile, die die van upstream insluit en er geen enkele wijzigt:
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
Dit is alleen gebouwd en getest op Ubuntu 24.04 met gcc 13.3 (x86-64): de build is vrij van waarschuwingen met de vlaggen van upstream, de smoke-test met 77 controles slaagt, en de 25 op Windows gemaakte en 37 op Linux gemaakte interoperabiliteitsvectoren geven dezelfde uitkomsten als op Windows. De twee bestanden van de fork die de overzetting heeft aangeraakt, bouwen op Windows nog ongewijzigd (schone x64-build, smoke-tests en interop-terugleescontrole slagen allemaal). Er is geen GUI. De andere Linux-doelen van upstream (`7za`, `7zr`, `7z.so`) worden niet ondersteund: hun gcc-objectlijsten missen wat de wijzigingen van de fork aan de handlers van upstream nodig hebben, dus naar verwachting mislukt het linken. Andere architecturen, distributies en compilers zijn niet geverifieerd, en macOS is nooit gebouwd, dus er kan geen `MACOSX_DEPLOYMENT_TARGET` worden opgegeven. Bouwstappen, tests en bekende beperkingen staan in `build/linux/README.md`; interoperabiliteit met Linux-hulpprogramma's staat in `test/interop/REPORT.md`.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## Niet-ondertekende pakketten, SmartScreen en Smart App Control

**De installatieprogramma's en programma's in een 7-ZSTar-release zijn niet door een certificeringsinstantie ondertekend**, en dit project heeft geen certificaat voor code-ondertekening. Windows kan daarom niet zien wie het bestand heeft gepubliceerd, en wanneer je de `.msi`, of een programma uit de `.zip`, voor het eerst uitvoert, kan Microsoft Defender SmartScreen het met een waarschuwing tegenhouden. De ontwikkelaarsdocumentatie van Microsoft noemt "No signature" als een van de gevallen waarin een waarschuwing met de titel "Windows protected your PC" (in een Nederlandstalige Windows: Uw pc wordt beschermd) verschijnt, waarbij de gebruiker "Run anyway" (Toch uitvoeren) moet kiezen voordat de app start ([Microsoft][smartscreen-rep]). Bedrijfsbeleid kan die keuze helemaal wegnemen; vraag het op zo'n pc aan degene die de pc beheert.

Het enige onderdeel van een release dat *wel* is ondertekend, is het kleine pakket dat 7-ZSTar op het eerste niveau van het Windows 11-contextmenu zet, in de `.msi` voor alle gebruikers. Het certificaat is zelfondertekend en wordt gegenereerd terwijl alleen dat pakket wordt gebouwd; het is dus geen handtekening van een certificeringsinstantie en zegt niets over wie het pakket heeft gebouwd; zie [het Windows 11-contextmenu](#het-windows-11-contextmenu) voor wat het doet en hoe je het kunt weigeren.

De waarschuwing is geen bewijs dat een bestand slecht is, en het ontbreken ervan zou geen bewijs zijn dat een bestand goed is. Wat je zelf kunt controleren, is dat jouw exemplaar precies dat is wat op de releasepagina is gepubliceerd. Elke release bevat een bestand met de naam `SHA256SUMS`: één regel per pakket, een SHA-256-hash gevolgd door de bestandsnaam.

1. Download het pakket en `SHA256SUMS` van dezelfde releasepagina, naar dezelfde map.
2. Open PowerShell in die map en vergelijk. Vervang de naam door het bestand dat je hebt gedownload:

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True` betekent dat de hashes identiek zijn. Wil je ze liever zelf bekijken, voer dan
   `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi` uit en zoek dezelfde
   bestandsnaam op in `SHA256SUMS`; de vergelijking negeert hoofdletters en kleine letters.
3. Krijg je `False`, of staat de bestandsnaam niet in `SHA256SUMS`, voer het bestand dan niet uit:
   verwijder het en download het opnieuw. Komt het nog steeds niet overeen, meld dit dan zoals
   beschreven in [SECURITY.md](../../SECURITY.md).

`SHA256SUMS` dekt alleen de bestanden die bij die release zijn geüpload. Als je dezelfde tag zelf bouwt, krijg je andere hashes (het pakket voor het contextmenu wordt bij elke build met een nieuw certificaat ondertekend), en de broncode wordt bij elke release gepubliceerd als je liever zelf bouwt: zie [build/README.md](../../build/README.md).

Zodra de hashes overeenkomen en je tevreden bent over waar het bestand vandaan komt:

- **`.msi`** - start het zoals gewoonlijk. Als SmartScreen het tegenhoudt, kies dan de optie om het toch uit te voeren (Toch uitvoeren; "Run anyway" in een Engelstalige Windows). Het waarschuwingsvenster moet misschien eerst worden uitgevouwen: op de geteste Windows 10-computer bood het alleen een knop om het bestand niet uit te voeren (Niet uitvoeren) totdat op de koppeling onder het bericht (Meer informatie) werd geklikt. De `.msi` voor alle gebruikers vraagt daarna, net als elk ander installatieprogramma, om goedkeuring van een Administrator.
- **`.zip`** - pak het uit en start `7zFM.exe` of `7z.exe` vanuit de map. De programma's erin zijn ook niet ondertekend, dus Windows kan dezelfde waarschuwing tonen de eerste keer dat je elk ervan start.

SmartScreen waarschuwt op basis van hoe bekend een bestand is, niet alleen op handtekeningen; een bestand dat door weinig mensen is gedownload, kan de waarschuwing oproepen, zelfs als het is ondertekend. Niets hier verandert dat, en niets in de bovenstaande stappen schakelt SmartScreen uit.

### Smart App Control op Windows 11

Op sommige Windows 11-pc's is een strengere beveiliging met de naam **Smart App Control** ingeschakeld (Aan). Als die aan staat, blokkeert Windows niet-ondertekende bestanden, tenzij de clouddienst van Microsoft ervoor kan instaan, en een nieuwe release heeft meestal zo'n vermelding niet ([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). Anders dan bij de SmartScreen-waarschuwing is er bij de blokkade geen optie om het bestand toch uit te voeren, en volgens de FAQ van Microsoft is er geen manier om Smart App Control voor één afzonderlijke app te omzeilen.

Wat er gebeurde toen 7-ZSTar 26.05.1 werd geprobeerd op Windows 11 Pro 25H2 (build 26200.8037) met Smart App Control ingeschakeld (Aan):

- **De `.msi`-installatieprogramma's werden geblokkeerd**, zowel dat voor alle gebruikers als dat per gebruiker. In een Windows in het traditioneel Chinees meldde Windows Installer 「系統禁用此安裝。請連絡系統管理員。」, en een melding van Windows-beveiliging zei dat Smart App Control het bestand had geblokkeerd omdat Windows niet kon vaststellen wie het had gepubliceerd en het geen app is die Windows kent. Er was geen optie om door te gaan, en `msiexec /i ... /qn` gaf error 1625 terug. Dat bericht is string 1625 van Windows Installer; in een Engelstalige Windows luidt dezelfde string "The system administrator has set policies to prevent this installation." (gelezen uit de Engelse resources van Windows Installer, niet op het scherm gezien).
- **Een programma uit de `.zip` werd uitgevoerd.** `7zFM.exe`, uitgepakt uit de draagbare `.zip`, startte in dezelfde test normaal. Of Windows een niet-ondertekend programma laat draaien, is zijn eigen oordeel over dat bestand, dus op jouw pc kan dit anders zijn.
- Vlak nadat Smart App Control was ingeschakeld, kon de `.msi` een paar minuten worden geïnstalleerd voordat die werd geblokkeerd. De oorzaak is niet gevonden, dus een geslaagde installatie vlak na het inschakelen betekent niet dat het installatieprogramma is toegestaan.

Op een pc waarop Smart App Control aan staat, **kunnen de installatieprogramma's dus niet worden geïnstalleerd**, en het controleren van `SHA256SUMS` verandert daar niets aan. Wat wel helpt, is Smart App Control uitschakelen in de app Windows-beveiliging, onder Instellingen voor Smart App Control (in de geteste Windows in het traditioneel Chinees: Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定). In de test werkte het kiezen van de optie Uit meteen, zonder herstart, en daarna konden de installatieprogramma's worden geïnstalleerd. Dit is een instelling voor de hele pc en niets hier vraagt je die te wijzigen: dat is aan jou, of aan je Administrator op een beheerde pc.

Het is ook goed om vooraf te weten of het weer kan worden ingeschakeld. Volgens de FAQ van Microsoft maken recente Windows-updates het mogelijk Smart App Control opnieuw in te schakelen zonder Windows schoon opnieuw te installeren; op een versie zonder die updates kan uitschakelen dus definitief zijn. Op de hier geteste build werd de optie om het in te schakelen na het uitschakelen nog steeds aangeboden; dat is een testresultaat, geen belofte voor jouw versie.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## Installeren

Drie pakketten, allemaal gebouwd met `installer\Build-Package.ps1` (dat per gebruiker met `-PerUser`):

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| Installeert voor | elk account | het installerende account | - |
| Contextmenu van Verkenner | ja | ja, alleen klassiek menu ([hieronder](#het-pakket-per-gebruiker)) | nee |
| Item in het Startmenu | ja | ja | nee |
| Administrator vereist | ja | nee | nee |
| Verwijderen | *Geïnstalleerde apps* in Instellingen | *Geïnstalleerde apps* in Instellingen | de map verwijderen |

*Geïnstalleerde apps* is de naam in Windows 11. Windows 10 noemt dezelfde pagina *Apps en onderdelen*, en op Windows 7 is het *Programs and Features* (Programma's en onderdelen) in *Control Panel* (Configuratiescherm).

Gebruik de pakketten die bij Windows zelf passen: x86 op 32-bits Windows, x64 op 64-bits Windows, arm64 op Windows on Arm (de arm64-pakketten worden gebouwd maar zijn nog nooit uitgevoerd). De x86-shell-extensie is 32-bits en de 64-bits Verkenner kan die niet laden, dus op 64-bits Windows heeft de x86 `-user.msi` helemaal geen contextmenu, en de x86 `.msi` heeft er alleen een op Windows 11 en alleen voor accounts die het Windows 11-pakket ervan hebben geregistreerd (het installerende account, of een account dat `-Register` heeft uitgevoerd, zie hieronder).

De MSI installeert in `Program Files\7-ZSTar` - altijd: anders dan het pakket per gebruiker biedt het geen keuze van map en negeert het `INSTALLFOLDER` op de opdrachtregel, omdat die map een script bevat dat het installatieprogramma als SYSTEM uitvoert en een DLL die de Verkenner van elke gebruiker laadt, en een elders aangemaakte map (bijvoorbeeld onder `C:\`) voor elke gebruiker beschrijfbaar is. Het registreert zijn eigen shell-extensie-CLSID en zijn eigen registerstructuur `Software\7-ZSTar`, en noemt elke contextmenusleutel `7-ZSTar` - zodat het niet botst met die van de officiële 7-Zip en die ook niet verwijdert. Zie [installer/GUIDS.md](../../installer/GUIDS.md).

Het draait een gewone installatiewizard - welcome, licence, setup type, optional feature tree, finish (welkom, licentie, installatietype, boomstructuur met optionele onderdelen, voltooien) - en stil installeren werkt nog steeds ongewijzigd (`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`), omdat msiexec in de stille modus de hele UI-reeks overslaat. De wizard is alleen in het Engels, ook op een Windows die op een andere taal staat (gezien op Windows 10 in het traditioneel Chinees; de `.msi` wordt zonder andere talen gebouwd), en op de laatste pagina staat *Launch 7-ZSTar File Manager* (7-ZSTar File Manager starten) standaard aangevinkt.

### Het Windows 11-contextmenu

Op Windows 11 staat het item in het menu op het eerste niveau, en niet verstopt onder *Meer opties weergeven*, waar de officiële 7-Zip en WinRAR nog steeds zitten. Windows 11 toont daar alleen een shell-extensie als die met pakketidentiteit wordt geleverd, dus de MSI levert naast het programma een klein MSIX-pakket dat alleen uit identiteit bestaat en registreert dat tijdens de installatie. De klassieke registratie blijft ook behouden. Die zorgt ervoor dat het item in het contextmenu staat op Windows 10 en Windows 7, waarvan het menu één niveau heeft zonder *Meer opties weergeven*, en houdt het werkend voor iedereen die het oude contextmenu heeft hersteld.

Dat pakket is ondertekend met een **zelfondertekend certificaat**, en het installatieprogramma zet dat in `LocalMachine\TrustedPeople` - Windows implementeert geen pakket waarvan de handtekening niet naar iets vertrouwds is te herleiden. Bij het verwijderen gaat het certificaat samen met het pakket weg. Op Windows 10 en Windows 7 doet het installatieprogramma geen van beide: het voegt geen certificaat toe en registreert geen pakket, en alleen de klassieke registratie levert het menu.

Wil je een zelfondertekend certificaat liever niet vertrouwen, weiger dan alleen dat onderdeel en behoud al het andere:

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

Je krijgt dan alleen het klassieke menu, dus op Windows 11 staat het 7-ZSTar-item in het contextmenu onder *Meer opties weergeven*. Om het item op het eerste niveau later alsnog in te schakelen, of om het na een normale installatie ongedaan te maken:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

Dat certificaat vertrouwen betekent dat Windows ook **elk ander** pakket dat met dezelfde sleutel is ondertekend zonder waarschuwing accepteert. Het wordt uitsluitend voor dit ene pakket gebruikt en bij het verwijderen weer ingetrokken, maar daar ga je wel mee akkoord - `SPARSE=0` hierboven is de manier om het te weigeren.

Pakketregistratie gebeurt per gebruiker, en het installatieprogramma voert die alleen uit voor degene die heeft geïnstalleerd. Twee gevolgen:

- Een tweede account op dezelfde computer krijgt alleen het klassieke menu, totdat het hetzelfde script met `-Register` uitvoert.
- Bij het verwijderen wordt de registratie alleen ongedaan gemaakt voor degene die verwijdert. Als iemand anders het heeft geregistreerd, blijft diens registratie na het verwijderen bestaan en wijst die naar een map die er niet meer is; dat account wist die met `Get-AppxPackage 7-ZSTar | Remove-AppxPackage`.

**Bekende beperking: het menu op het eerste niveau wordt alleen geregistreerd als de installatie in een interactieve, aangemelde sessie draait.** Het installeren van de `.msi` voor alle gebruikers vanuit een externe of niet-interactieve sessie - via SSH, of een stille uitrol vanuit een beheerprogramma - meldt nog steeds succes, maar het Windows 11-pakket wordt niet geregistreerd, dus alleen het klassieke menu onder *Meer opties weergeven* verschijnt. In de test sloot `msiexec /i ... /qn` vanuit een SSH-sessie (sessie 0) af met 0, terwijl `Setup-ShellIntegration.ps1` `registration failed: 0x80070005` meldde (toegang geweigerd); dezelfde `.msi`, geïnstalleerd vanuit de consolesessie van een Administrator, registreerde normaal.

`-Status` toont wat wel en niet aanwezig is.

### Het pakket per gebruiker

`7-ZSTar-<version>-<arch>-user.msi` installeert alleen voor het huidige account, in `%LOCALAPPDATA%\Programs\7-ZSTar`, zonder melding van Gebruikersaccountbeheer. Alles wat het registreert komt onder `HKCU`; het pakket schrijft niets naar `HKLM` (de eigen administratie van Windows Installer daargelaten). Wat het niet doet zoals het pakket per computer:

- **Geen Windows 11-menu op eerste niveau.** Op Windows 11 staat 7-ZSTar in het contextmenu onder *Meer opties weergeven*. Voor het item op het eerste niveau moet het zelfondertekende certificaat computerbreed worden vertrouwd, wat een Administrator vereist: gemeten op Windows 11 is een certificaat in `CurrentUser\TrustedPeople` niet genoeg om het pakket door Windows te laten implementeren. Het pakket per gebruiker laat het dus weg.
- **Eén van de twee per computer.** Elk pakket weigert te installeren zolang het andere is geïnstalleerd; verwijder het ene voordat je het andere installeert. Het pakket per computer kan alleen de installatie per gebruiker zien van het account dat het uitvoert, dus de installatie per gebruiker van een ander account wordt niet gedetecteerd.
- **Groepsbeleid kan het menu verbergen.** Waar `EnforceShellExtensionSecurity` is ingesteld, laadt Verkenner alleen shell-extensies die onder de computerbrede sleutel *Approved* staan, waarnaar een installatie per gebruiker niet kan schrijven, dus het contextmenu verschijnt niet. Gebruik daar het pakket per computer.
- **Een formaat wissen onder Extra > Opties... > Systeem verwijdert ook het aanbod van 7-ZSTar ervoor.** Wanneer je daar een formaat wist (klik op de cel totdat die leeg is, en dan op OK), verwijdert het bestandsbeheer (7zFM) de volledige sleutels `HKCU\Software\Classes\.<ext>` en `7-ZSTar.<ext>` - en bij een installatie per gebruiker bevatten die sleutels ook wat het pakket heeft geregistreerd voor Instellingen > Apps > Standaard-apps en de lijst *Openen met*. 7-ZSTar verdwijnt dan uit *Openen met* voor dat formaat, en Standaard-apps toont er een lege vermelding voor. Het herstellen van de installatie zet het terug (voer de `.msi` opnieuw uit en kies *Repair*). Beter is het bestandstypen toe te wijzen in Standaard-apps in plaats van in het bestandsbeheer. Het pakket per computer heeft op één plek hetzelfde zwakke punt, beschreven hieronder bij bestandskoppelingen.

### Bestandskoppelingen en wat verwijderen ermee doet

**Stel ze in via Instellingen > Apps > Standaard-apps.** Typ op Windows 11 daar 7-ZSTar, en elk formaat dat het kan openen wordt weergegeven om toe te wijzen. Op Windows 10 staat 7-ZSTar op die pagina onder *Set defaults by app* (standaardwaarden per app instellen), waar *Manage* (beheren) de formaten toont. Windows 7 heeft geen app Instellingen: 7-ZSTar staat daar onder *Control Panel* (Configuratiescherm) > Standaardprogramma's > *Uw standaardprogramma's instellen*, en dat is wat *Standaard-apps* in deze gids daar betekent. Het toewijzen van formaten vanaf die twee pagina's is niet getest. Het installatieprogramma registreert 7-ZSTar als Standaardprogramma's-toepassing - een ProgID per formaat met het pictogram en de openopdracht, een vermelding in de lijst *Openen met* van elke extensie, en het Capabilities-blok dat Windows leest - maar het claimt bewust geen enkel bestandstype: welk programma je archieven opent, is jouw beslissing, en daardoor lopen 7-ZSTar en de officiële 7-Zip elkaar niet in de weg. Windows kan een formaat nog steeds uit zichzelf naar 7-ZSTar sturen wanneer geen ander programma aanbiedt het te openen: op de geteste Windows 10- en Windows 7-computers, waar niets anders `.7z` had geregistreerd, toonde een `.7z`-bestand het pictogram van 7-ZSTar en werd het er met een dubbelklik in geopend, zonder dat Windows vroeg welk programma moest worden gebruikt.

**Extra > Opties... > Systeem in het bestandsbeheer werkt op Windows 11 grotendeels niet**, en dat is een regel van Windows en geen bug hier. Het schrijft een ProgID `7-ZSTar.<ext>` naar `HKCU\Software\Classes`, en voor elke extensie die de computer al kent - elk archiefformaat doet dat - negeert Windows 11 die: `AssocQueryString` antwoordt `Unknown` en Verkenner tekent het lege standaardpictogram. Wat het in plaats daarvan respecteert, is een sleutel `UserChoice` die is voorzien van een hash die alleen Windows kan berekenen, en daarom is de interface van Instellingen daar de enige route. Geen enkele toepassing kan er een schrijven: niet 7-ZSTar, niet 7-Zip, geen enkel installatieprogramma. Windows 10 en Windows 7 gedroegen zich in de test anders: nadat `.7z` en `.zst` in het bestandsbeheer waren ingesteld, zonder dat een ander programma ervoor was gekozen, gaf `AssocQueryString` voor beide `7zFM.exe` terug.

**Een formaat wissen in de kolom *Alle gebruikers* verwijdert de eigen registratie van het pakket per computer ervoor.** Die kolom schrijft naar `HKLM\Software\Classes`, waar het pakket per computer de ProgID's en vermeldingen in *Openen met* bewaart die het aanbiedt, en een formaat daar wissen (wat vereist dat het bestandsbeheer is gestart via *Als administrator uitvoeren*) verwijdert die sleutels volledig - voor elk account. Herstellen zette dezelfde sleutels terug voor het pakket per gebruiker; voor dit pakket is dat niet gemeten.

**Een pictogram dat leeg blijft na een wijziging** kan ook de pictogramcache van Verkenner zijn, die niet merkt dat een DLL die al in de cache staat is vervangen; `ie4uinit.exe -show` wist die niet betrouwbaar. Sluit Verkenner, verwijder `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db` en start het opnieuw.

**Bij het verwijderen worden de koppelingen verwijderd die het kan bereiken** - de `7-ZSTar.*`-ProgID's van degene die verwijdert, en alleen de bestandstypen die er nog naar verwijzen, zodat een formaat dat intussen aan een ander programma is gegeven, met rust wordt gelaten. Bij het verwijderen van het pakket per computer wordt ook een ProgID met rust gelaten die een kopie van 7-ZSTar elders opent die nog bestaat - een draagbare kopie uit de `.zip`, ingesteld met **Extra > Opties... > Systeem** van die kopie zelf. Het pakket per gebruiker kan dat niet: de ProgID's daarvan zijn diezelfde `HKCU`-sleutels (zie *Het pakket per gebruiker* hierboven), en bij het verwijderen worden ze verwijderd, wie ze ook het laatst heeft geschreven. Ze laten staan zou die types laten verwijzen naar een ProgID waarvan het pictogram en de opdracht een verwijderd uitvoerbaar bestand zijn, wat een leeg pictogram en een fout bij dubbelklikken oplevert. De koppelingen van andere accounts zijn onbereikbaar; die kunnen hun eigen koppelingen wissen met `Setup-ShellIntegration.ps1 -RemoveAssociations` voordat het programma verdwijnt. `msiexec /x ... KEEPASSOC=1` slaat dit over, en een upgrade doet het nooit.

**Bekende beperking: andere accounts behouden de koppelingen die ze zelf hebben ingesteld.** Bij het verwijderen van het pakket per computer wordt alleen gewist wat het account dat de verwijdering uitvoert in zijn eigen kolom (met de accountnaam als kolomkop) onder **Extra > Opties... > Systeem** in het bestandsbeheer heeft ingesteld. Elk ander account dat daar koppelingen heeft ingesteld, behoudt die, verwijzend naar het verwijderde programma, zodat dubbelklikken op een `.7z`-bestand aan Windows vraagt welk programma moet worden gebruikt. Elk account moet zijn eigen koppelingen wissen **vóór** het verwijderen, met

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

waarmee alleen de vermeldingen van 7-ZSTar worden verwijderd, of achteraf de types opnieuw toewijzen onder Instellingen > Apps > Standaard-apps. Het in het bestandsbeheer doen betekent: klik in de eigen kolom op elke cel waarin 7-ZSTar staat totdat die leeg is, en dan op OK; selecteer niet alle rijen en druk niet op "+", want dat past één status toe op elke geselecteerde rij en wist dus ook formaten die bij een ander programma horen, zoals de officiële 7-Zip.

Koppelingen die in de kolom **Alle gebruikers** zijn ingesteld, worden door het opruimen bij het verwijderen helemaal niet aangeraakt, en blijven voor elk account naar het verwijderde programma verwijzen. Een Administrator die er een heeft ingesteld, moet die cellen wissen, vanuit een bestandsbeheer dat is gestart via *Als administrator uitvoeren*, en dan op OK klikken, vóór het verwijderen; `-RemoveAssociations` bereikt deze kolom niet. Het wissen vlak voor het verwijderen is onschadelijk, ook al verwijdert het daar de eigen registratie van het pakket (zie boven), omdat het verwijderen die toch wist. Het pakket per gebruiker heeft het probleem met andere accounts niet, en de officiële 7-Zip gedraagt zich hetzelfde.

## Talen

Elk pakket bevat de vertalingen van upstream, ruim 90 talen. Kies er een onder **Extra > Opties... > Taal**; de MSI laat je ze onder de installatie *Custom* ook weglaten. 7-ZSTar probeert bij de eerste keer starten de systeemtaal te volgen, maar die detectie geeft het op en blijft Engels wanneer de Windows-instellingen "language for non-Unicode programs" (taal voor niet-Unicode-programma's) en "Regionale instellingen" het niet eens zijn - een taal handmatig kiezen werkt altijd.

Teksten die 7-ZSTar zelf heeft toegevoegd - de velden voor het zstd-niveau en het woordenboek, de namen van de nieuwe archiefformaten - hebben geen vertaling van upstream en blijven Engels. De uitzondering zijn de knoppen **Doneer** en **Website** in het dialoogvenster **Over 7-ZSTar...**: bij 67 van de 92 talen is voor beide een woord beschikbaar, bij de andere 25 staat Engels (`Lang/UPSTREAM.md` somt ze op).
Vertalingen worden overgenomen, niet hier geschreven: zie [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md).
