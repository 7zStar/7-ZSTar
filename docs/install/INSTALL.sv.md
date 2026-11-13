<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# Installera 7-ZSTar

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · [한국어](INSTALL.ko.md) · [Italiano](INSTALL.it.md) · [Polski](INSTALL.pl.md) · [Türkçe](INSTALL.tr.md) · [Nederlands](INSTALL.nl.md) · [Українська](INSTALL.uk.md) · [Bahasa Indonesia](INSTALL.id.md) · [ไทย](INSTALL.th.md) · [Čeština](INSTALL.cs.md) · [Magyar](INSTALL.hu.md) · [Română](INSTALL.ro.md) · **Svenska** · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md)

*Om innehållet här skiljer sig från den engelska versionen gäller den engelska versionen.*

Detaljerna bakom den korta versionen i [README](../readme/README.sv.md): systemkrav, SmartScreen-varningen, Smart appkontroll och hur du kontrollerar en nedladdning, de tre paketen, högerklicksmenyn i Windows 11, filassociationer och avinstallation.

## Systemkrav

**Windows 7 eller Windows Server 2008 R2, x64 eller x86. På arm64 krävs Windows 10.**
Inget annat behövs: C-körtiden är statiskt länkad (`-MT`), så binärfilerna importerar inget annat än Windows egna DLL-filer – inget omdistribuerbart paket och inget .NET.

Den miniminivån är *härledd* från vad paketen kräver, och den har testats på Windows 7 SP1 med senare uppdateringar installerade (bland annat PowerShell 5.1), Windows 10 22H2 och Windows 11, alla 64-bitars. På Windows 7 och 10 omfattade det installation och avinstallation av `.msi` för alla användare och per användare i x64, installationsguiden, x64-`.zip`, varje tillagd codec och varje tar-format i ett steg, högerklicksmenyn, filassociationer och hjälpfilen, samt x86-`.msi` och `.zip` körda på 64-bitars Windows. Inget annat har testats på Windows: inte Windows 8 eller 8.1, Windows Server, 32-bitars Windows, arm64-hårdvara eller Windows 7 utan de uppdateringarna. Miniminivån är också högre än uppströmsversionen av 7-Zip, vars binärfiler fortfarande går att läsa in på Windows XP. Tre saker sätter den där, och den andra är den som ingen bygginställning kan häva:

- `.msi` deklarerar `InstallerVersion="500"`, och Windows Installer 5.0 levererades "with Windows Server 2008 R2 and later and Windows 7 and later" ([Microsoft][msi-versions]). Den portabla `.zip` går inte via Windows Installer, men se de två följande punkterna.
- **zstd och fast-lzma2 använder synkronisering som bara finns från Vista.** Båda tvingar `_WIN32_WINNT 0x0600` i sina egna headerfiler och anropar `InitializeConditionVariable` / `SleepConditionVariableCS` direkt, så `7z.dll` och `7za.exe` – de två binärfilerna med codecarna inbyggda – importerar fyra funktioner som Windows XP och Server 2003 saknar. Uppströmsversionens `7z.dll` importerar ingen av dem.
- Verktygskedjan: de byggs med Visual Studio 2022, vars lista över stödda målplattformar är Windows 7 och senare – Vista och Server 2008 är "No" ([Microsoft][vs-targeting]). Den länkade delsystemversionen är 6.0 på x64 och x86 och 6.2 på arm64, och Windows på arm64 börjar ändå med Windows 10.

Windows Vista och Server 2008 hamnar mittemellan: binärfilerna skulle gå att läsa in, men verktygskedjan stöder dem inte, installationsprogrammet körs inte där och 7-ZSTar är inte testat på dem.

**Linux stöds bara som bygge för kommandoraden; macOS stöds inte.**
Forken bygger en nativ `7zz` (konsolprogrammet `Alone2`) med gcc via en egen makefile, som inkluderar uppströmsversionens och inte ändrar någon av dem:
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
Den har bara byggts och testats på Ubuntu 24.04 med gcc 13.3 (x86-64): bygget är varningsfritt med uppströmsversionens flaggor, röktestet med 77 kontroller går igenom, och de 25 Windows-gjorda och 37 Linux-gjorda interoperabilitetsvektorerna ger samma utfall som på Windows. De två filer som forken äger och som porteringen berörde bygger fortfarande oförändrade på Windows (rent x64-bygge, röktester och tillbakaläsning av interoperabilitet går alla igenom). Det finns inget grafiskt gränssnitt. Uppströmsversionens övriga Linux-mål (`7za`, `7zr`, `7z.so`) stöds inte: deras gcc-objektlistor saknar det som forkens ändringar av uppströmsversionens hanterare behöver, så de förväntas misslyckas vid länkningen. Andra arkitekturer, distributioner och kompilatorer har inte verifierats, och macOS har aldrig byggts, så inget `MACOSX_DEPLOYMENT_TARGET` kan anges. Byggsteg, tester och kända begränsningar finns i `build/linux/README.md`; interoperabilitet med Linux-verktyg finns i `test/interop/REPORT.md`.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## Osignerade paket, SmartScreen och Smart appkontroll

**Installationsprogrammen och programmen i en 7-ZSTar-release är inte kodsignerade av någon certifikatutfärdare**, och projektet har inget kodsigneringscertifikat. Windows kan därför inte se vem som har publicerat filen, och när du kör `.msi`, eller ett program från `.zip`, för första gången kan Microsoft Defender SmartScreen stoppa den med en varning. Microsofts utvecklardokumentation listar "No signature" som ett av fallen som visar en varning med rubriken "Windows har skyddat datorn" ("Windows protected your PC"), där användaren måste välja "Kör ändå" ("Run anyway") innan appen körs ([Microsoft][smartscreen-rep]). Företagspolicyer kan ta bort det alternativet helt; på en sådan dator får du fråga den som hanterar den.

Det enda i en release som *är* signerat är det lilla paketet som lägger 7-ZSTar på första nivån i högerklicksmenyn i Windows 11, inuti `.msi` för alla användare. Dess certifikat är självsignerat och skapas medan just det paketet byggs, så det är ingen certifikatutfärdares signatur och säger ingenting om vem som byggde paketet; se [högerklicksmenyn i Windows 11](#högerklicksmenyn-i-windows-11) för vad det gör och hur du tackar nej till det.

Varningen är inget bevis på att en fil är dålig, och att den uteblir vore inget bevis på att en fil är bra. Det du själv kan kontrollera är att din kopia är exakt den som publicerats på release-sidan. Varje release har en fil som heter `SHA256SUMS`: en rad per paket, en SHA-256-hash följd av filnamnet.

1. Ladda ner paketet och `SHA256SUMS` från samma release-sida, till samma mapp.
2. Öppna PowerShell i den mappen och jämför. Byt ut namnet mot filen du laddade ner:

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True` betyder att hasharna är identiska. Vill du hellre titta på dem själv kör du
   `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi` och letar upp samma
   filnamn i `SHA256SUMS`; jämförelsen skiljer inte på stora och små bokstäver.
3. Får du `False`, eller finns filnamnet inte i `SHA256SUMS`, ska du inte köra den: ta bort filen och ladda ner den igen. Stämmer den fortfarande inte, rapportera det enligt beskrivningen i [SECURITY.md](../../SECURITY.md).

`SHA256SUMS` täcker bara filerna som laddats upp till den releasen. Bygger du samma tagg själv får du andra hashar (paketet för högerklicksmenyn signeras med ett nytt certifikat vid varje bygge), och källkoden publiceras med varje release om du hellre vill bygga själv: se [build/README.md](../../build/README.md).

När hasharna stämmer och du är nöjd med varifrån filen kommer:

- **`.msi`** – starta den som vanligt. Om SmartScreen stoppar den, välj alternativet för att köra den ändå ("Kör ändå"; "Run anyway" i ett engelskspråkigt Windows). Varningsfönstret kan behöva expanderas först: på den Windows 10-dator som testades erbjöd det bara en knapp för att inte köra filen tills länken under meddelandet klickades. `.msi` för alla användare ber sedan om administratörsgodkännande som vilket installationsprogram som helst.
- **`.zip`** – packa upp den och starta `7zFM.exe` eller `7z.exe` från mappen. Programmen i den är också osignerade, så Windows kan visa samma varning första gången du startar vart och ett.

SmartScreen varnar utifrån hur välkänd en fil är, inte bara utifrån signaturer; en fil som har laddats ner av få personer kan utlösa varningen även om den är signerad. Inget här ändrar på det, och inget i stegen ovan stänger av SmartScreen.

### Smart appkontroll i Windows 11

Vissa Windows 11-datorer har ett strängare skydd som heter **Smart appkontroll** påslaget. När det är på blockerar Windows osignerade filer om inte Microsofts molntjänst kan gå i god för dem, och en ny release har oftast ingen sådan post ([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). Till skillnad från SmartScreen-varningen finns det inget alternativ att köra filen ändå vid blockeringen, och Microsofts FAQ säger att det inte går att kringgå Smart appkontroll för en enskild app.

Det som hände när 7-ZSTar 26.05.1 provades på Windows 11 Pro 25H2 (build 26200.8037) med Smart appkontroll påslaget:

- **`.msi`-installationsprogrammen blockerades**, både det för alla användare och det per användare. I ett Windows på traditionell kinesiska sa Windows Installer 「系統禁用此安裝。請連絡系統管理員。」, och en avisering från Windows-säkerhet sa att Smart appkontroll hade blockerat filen eftersom Windows inte kunde se vem som publicerat den och den inte är en app som Windows känner till. Det fanns inget alternativ att fortsätta, och `msiexec /i ... /qn` returnerade fel 1625. Det meddelandet är Windows Installers sträng 1625; i ett engelskspråkigt Windows lyder samma sträng "The system administrator has set policies to prevent this installation." (läst från Windows Installers engelska resurser, inte sett på skärmen).
- **Ett program från `.zip` kördes.** `7zFM.exe`, uppackad från den portabla `.zip`, startade normalt i samma test. Om Windows låter ett osignerat program köra är Windows egen bedömning av just den filen, så det kan vara annorlunda på din dator.
- Strax efter att Smart appkontroll slagits på installerades `.msi` i några minuter innan den började blockeras. Orsaken hittades inte, så en lyckad installation direkt efter påslagningen betyder inte att installationsprogrammet är tillåtet.

Så på en dator där Smart appkontroll är på **kan installationsprogrammen inte installeras**, och att kontrollera `SHA256SUMS` ändrar inte det. Det som ändrar det är att stänga av Smart appkontroll i Inställningar för smart appkontroll i appen Windows-säkerhet (på det testade Windows på traditionell kinesiska: Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定). I testet trädde valet av alternativet *Av* i kraft direkt utan omstart, och installationsprogrammen kunde sedan installeras. Det är en inställning för hela datorn och inget här ber dig ändra den: det är ditt beslut, eller din administratörs på en hanterad dator.

Det är också värt att veta i förväg om den går att slå på igen. Microsofts FAQ säger att de senaste Windows-uppdateringarna gör det möjligt att slå på Smart appkontroll igen utan en ren installation av Windows, så på en version utan dem kan avstängningen vara permanent. På den version som testades här erbjöds alternativet att slå på den fortfarande efter att den stängts av; det är ett testresultat, inte ett löfte om din version.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## Installation

Tre paket, alla byggda av `installer\Build-Package.ps1` (paketet per användare med `-PerUser`):

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| Installerar för | alla konton | det installerande kontot | - |
| Utforskarens högerklicksmeny | ja | ja, bara den klassiska menyn ([nedan](#paketet-per-användare)) | nej |
| Post i Start menu (Startmenyn) | ja | ja | nej |
| Kräver administratör | ja | nej | nej |
| Borttagning | *Installerade appar* i Inställningar | *Installerade appar* i Inställningar | ta bort mappen |

*Installerade appar* är namnet i Windows 11. Windows 10 kallar samma sida *Appar och funktioner*, och i Windows 7 heter den *Programs and Features* (Program och funktioner) i Control Panel (Kontrollpanelen).

Använd de paket som matchar själva Windows: x86 på 32-bitars Windows, x64 på 64-bitars Windows, arm64 på Windows on Arm (arm64-paketen byggs men har aldrig körts). Shell-tillägget för x86 är 32-bitars och 64-bitars Utforskaren kan inte läsa in det, så på 64-bitars Windows har x86 `-user.msi` ingen högerklicksmeny alls, och x86 `.msi` har en bara i Windows 11 och bara för konton som har registrerat dess Windows 11-paket (det som installerade, eller ett som körde `-Register`, nedan).

MSI installerar i `Program Files\7-ZSTar` – alltid: till skillnad från paketet per användare erbjuder det inget val av mapp, och ignorerar `INSTALLFOLDER` på kommandoraden, eftersom den mappen innehåller ett skript som installationsprogrammet kör som SYSTEM och en DLL som varje användares Utforskaren läser in, och en mapp som skapats någon annanstans (under `C:\`, till exempel) är skrivbar för alla användare. Det registrerar sin egen CLSID för shell-tillägget och sin egen registergren `Software\7-ZSTar`, och namnger varje snabbmenynyckel `7-ZSTar` – så det varken kolliderar med eller tar bort den officiella 7-Zips. Se [installer/GUIDS.md](../../installer/GUIDS.md).

Det kör en vanlig installationsguide – welcome, licence, setup type, optional feature tree, finish (välkomstsida, licens, installationstyp, träd med valfria funktioner, slutsida) – och tyst installation fungerar fortfarande oförändrat (`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`), eftersom msiexec hoppar över hela användargränssnittssekvensen i tyst läge. Guiden är bara på engelska, även i ett Windows inställt på ett annat språk (sett i Windows 10 på traditionell kinesiska; `.msi` byggs utan något annat språk), och på dess sista sida är *Launch 7-ZSTar File Manager* ikryssat som standard.

### Högerklicksmenyn i Windows 11

I Windows 11 finns posten i menyn på första nivån, inte undanstoppad under *Visa fler alternativ* där den officiella 7-Zip och WinRAR fortfarande sitter. Windows 11 listar ett shell-tillägg där bara när det kommer med paketidentitet, så MSI levererar ett litet MSIX-paket med enbart identitet bredvid programmet och registrerar det under installationen. Den klassiska registreringen behålls också. Det är den som lägger posten i högerklicksmenyn i Windows 10 och Windows 7, vars meny bara har en nivå utan *Visa fler alternativ*, och som håller den igång för den som har återställt den gamla snabbmenyn.

Det paketet är signerat med ett **självsignerat certifikat**, och installationsprogrammet lägger det i `LocalMachine\TrustedPeople` – Windows distribuerar inte ett paket vars signatur det inte kan koppla till något betrott. Avinstallation tar bort certifikatet tillsammans med paketet. I Windows 10 och Windows 7 gör installationsprogrammet ingetdera: det lägger inte till något certifikat och registrerar inget paket, och den klassiska registreringen ensam ger menyn.

Vill du hellre inte lita på ett självsignerat certifikat kan du tacka nej till just den delen och behålla allt annat:

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

Du får då bara den klassiska menyn, så i Windows 11 finns 7-ZSTar-posten i högerklicksmenyn under *Visa fler alternativ*. För att slå på posten på första nivån senare, eller för att ångra den efter en vanlig installation:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

Att lita på det certifikatet innebär att Windows också godtar **vilket annat** paket som helst som signerats med samma nyckel utan varning. Det används bara till just det här paketet, och avinstallation tar bort det igen, men det är vad du går med på – `SPARSE=0` ovan är sättet att tacka nej till det.

Paketregistreringen sker per användare, och installationsprogrammet kör den bara för den som installerade. Två konsekvenser:

- Ett andra konto på samma dator får bara den klassiska menyn, tills det kör samma skript med `-Register`.
- Avinstallation avregistrerar det bara för den som avinstallerar. Om någon annan registrerade det överlever den registreringen avinstallationen och pekar på en mapp som inte längre finns; det kontot rensar den med `Get-AppxPackage 7-ZSTar | Remove-AppxPackage`.

**Känd begränsning: menyn på första nivån registreras bara när installationen körs i en interaktiv, inloggad session.** Installeras `.msi` för alla användare från en fjärrsession eller icke-interaktiv session – över SSH, eller en tyst driftsättning från ett hanteringsverktyg – rapporteras ändå att det lyckades, men Windows 11-paketet registreras inte, så bara den klassiska menyn under *Visa fler alternativ* visas. I testet avslutades `msiexec /i ... /qn` från en SSH-session (session 0) med 0 medan `Setup-ShellIntegration.ps1` rapporterade `registration failed: 0x80070005` (åtkomst nekad); samma `.msi` installerad från en administratörs konsolsession registrerades normalt.

`-Status` skriver ut vad som finns på plats och vad som inte gör det.

### Paketet per användare

`7-ZSTar-<version>-<arch>-user.msi` installerar bara för det aktuella kontot, i `%LOCALAPPDATA%\Programs\7-ZSTar`, utan UAC-fråga. Allt det registrerar hamnar under `HKCU`; paketet skriver ingenting till `HKLM` (bortsett från Windows Installers egen bokföring). Det den inte gör på samma sätt som paketet per dator:

- **Ingen meny på första nivån i Windows 11.** I Windows 11 finns 7-ZSTar i högerklicksmenyn under *Visa fler alternativ*. Posten på första nivån kräver att det självsignerade certifikatet är betrott på hela datorn, vilket kräver en administratör: uppmätt i Windows 11 räcker inte ett certifikat i `CurrentUser\TrustedPeople` för att Windows ska distribuera paketet. Därför utelämnar paketet per användare den.
- **Ett av de två per dator.** Varje paket vägrar installeras medan det andra är installerat; avinstallera det ena innan du installerar det andra. Paketet per dator kan bara se kopian per användare för det konto som kör det, så en annan användares installation per användare upptäcks inte.
- **Grupprincip kan dölja dess meny.** Där `EnforceShellExtensionSecurity` är satt läser Utforskaren bara in shell-tillägg som anges under den datorövergripande nyckeln *Approved*, som en installation per användare inte kan skriva till, så högerklicksmenyn visas inte. Använd paketet per dator där.
- **Att rensa ett format i Verktyg > Alternativ... > System tar också bort 7-ZSTars erbjudande för det.** När du rensar ett format där (klicka på dess cell tills den är tom, sedan OK) tar filhanteraren bort hela nycklarna `HKCU\Software\Classes\.<ext>` och `7-ZSTar.<ext>` – och för en installation per användare innehåller de nycklarna också det som paketet registrerade för Inställningar > Appar > Standardappar och listan *Öppna med*. 7-ZSTar försvinner då från *Öppna med* för det formatet, och Standardappar visar en tom post för det. Reparation av installationen återställer det (kör `.msi` igen och välj *Repair*). Bättre är att tilldela filtyper i Standardappar än i filhanteraren. Paketet per dator har samma svaga punkt på ett ställe, beskrivet under filassociationer nedan.

### Filassociationer och vad avinstallationen gör med dem

**Ställ in dem i Inställningar > Appar > Standardappar.** I Windows 11 skriver du 7-ZSTar där och varje format det kan öppna listas för tilldelning. I Windows 10 listas 7-ZSTar under *Set defaults by app* (ange standardvärden per app) på den sidan, där *Manage* (Hantera) visar dess format. Windows 7 har ingen Inställningar-app: 7-ZSTar listas under Control Panel (Kontrollpanelen) > Standardprogram > *Ange dina standardprogram*, vilket är vad *Standardappar* i den här guiden står för där. Att tilldela format från de två sidorna har inte testats. Installationsprogrammet registrerar 7-ZSTar som ett program i Standardprogram – ett ProgID per format med dess ikon och öppningskommando, en post i varje filändelses lista *Öppna med* och det Capabilities-block som Windows läser – men gör medvetet anspråk på ingen filtyp: vilket program som öppnar dina arkiv är ditt beslut, och det är vad som håller 7-ZSTar och den officiella 7-Zip ur varandras väg. Windows kan ändå skicka ett format till 7-ZSTar på egen hand när inget annat program erbjuder sig att öppna det: på de Windows 10- och Windows 7-datorer som testades, där inget annat hade registrerat `.7z`, visade en `.7z`-fil 7-ZSTars ikon och öppnades i det vid dubbelklick, utan att Windows frågade vilket program som skulle användas.

**Verktyg > Alternativ... > System i filhanteraren fungerar för det mesta inte i Windows 11**, och det är en Windows-regel snarare än ett fel här. Det skriver ett `7-ZSTar.<ext>`-ProgID i `HKCU\Software\Classes`, och för varje filändelse som datorn redan känner till – varje arkivformat gör det – ignorerar Windows 11 det: `AssocQueryString` svarar `Unknown` och Utforskaren ritar den tomma generiska ikonen. Det Windows i stället respekterar är en `UserChoice`-nyckel stämplad med en hash som bara Windows kan beräkna, vilket är varför gränssnittet i Inställningar är den enda vägen där. Inget program kan skriva en: inte 7-ZSTar, inte 7-Zip, inget installationsprogram. Windows 10 och Windows 7 betedde sig annorlunda vid testning: när `.7z` och `.zst` väl hade ställts in i filhanteraren, utan att något annat program valts för dem, returnerade `AssocQueryString` `7zFM.exe` för båda.

**Att rensa ett format i dess kolumn *Alla användare* tar bort paketet per dators egen registrering för det.** Den kolumnen skriver till `HKLM\Software\Classes`, där paketet per dator håller de ProgID:n och *Öppna med*-poster det erbjuder, och att rensa ett format där (vilket kräver att filhanteraren körs som administratör, run as administrator) tar bort de nycklarna helt – för varje konto. Reparation återställde samma nycklar för paketet per användare; för det här paketet mättes det inte.

**En ikon som förblir tom efter att något ändrats** kan också bero på Utforskarens ikoncache, som inte märker att en DLL som redan cachats har ersatts; `ie4uinit.exe -show` rensar den inte på ett pålitligt sätt. Stäng Utforskaren, ta bort `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db`, starta den igen.

**Avinstallation tar bort de associationer den kommer åt** – de `7-ZSTar.*`-ProgID:n som tillhör den som avinstallerar, och bara de filtyper som fortfarande pekar på dem, så ett format som under tiden har överlämnats till ett annat program lämnas ifred. Avinstallation av paketet per dator lämnar också ifred ett ProgID som öppnar en kopia av 7-ZSTar någon annanstans som fortfarande finns – en portabel från `.zip`, uppsatt med den kopians egen **Verktyg > Alternativ... > System**. Paketet per användare kan inte det: dess ProgID:n är just de `HKCU`-nycklarna (se *Paketet per användare* ovan), och avinstallationen tar bort dem vem som än skrev dem sist. Att lämna dem kvar skulle peka de filtyperna på ett ProgID vars ikon och kommando är en borttagen körbar fil, vilket ger en tom ikon och ett fel vid dubbelklick. Andra kontons associationer är utom räckhåll; de kan rensa sina egna med `Setup-ShellIntegration.ps1 -RemoveAssociations` innan programmet försvinner. `msiexec /x ... KEEPASSOC=1` hoppar över detta, och en uppgradering gör det aldrig.

**Känd begränsning: andra konton behåller de associationer de själva har ställt in.**
Avinstallation av paketet per dator rensar bara det som kontot som kör avinstallationen har ställt in i sin egen kolumn (med kontonamnet som rubrik) under
**Verktyg > Alternativ... > System** i filhanteraren. Alla andra konton som har ställt in associationer där behåller dem, pekande på det borttagna programmet, så ett dubbelklick på en `.7z`-fil frågar Windows vilket program som ska användas. Varje konto bör rensa sina egna **innan** avinstallationen, med

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

som bara tar bort 7-ZSTars poster, eller efteråt tilldela typerna igen under Inställningar > Appar > Standardappar. Att göra det i filhanteraren i stället innebär att klicka på varje cell i sin egen kolumn som visar 7-ZSTar tills den är tom, sedan OK; markera inte alla rader och tryck på "+", som tillämpar ett tillstånd på varje markerad rad och därför också rensar format som tillhör ett annat program, till exempel den officiella 7-Zip.

Associationer som ställts in i kolumnen **Alla användare** berörs inte alls av avinstallationens upprensning, och lämnas kvar så att de pekar varje konto mot det borttagna programmet. En administratör som har ställt in några bör rensa de cellerna, från en filhanterare körd som administratör (run as administrator), sedan OK, före avinstallationen; `-RemoveAssociations` når inte den kolumnen. Att rensa den precis före en avinstallation är ofarligt, även om det tar bort paketets egen registrering där (ovan), eftersom avinstallationen tar bort den ändå. Paketet per användare har inte problemet med andra konton, och den officiella 7-Zip beter sig på samma sätt.

## Språk

Varje paket innehåller uppströmsversionens översättningar, ett 90-tal språk. Välj ett under **Verktyg > Alternativ... > Språk**; MSI låter dig också utesluta dem under installationstypen *Custom*. 7-ZSTar försöker följa systemspråket vid första körningen, men den identifieringen ger upp och stannar på engelska när Windows "language for non-Unicode programs" (språk för program som inte stöder Unicode) och inställningen Regionsformat inte stämmer överens – att välja språk för hand fungerar alltid.

Strängar som 7-ZSTar har lagt till själv – fälten för zstd-nivå och ordbok, de nya arkivformatens namn – har ingen översättning från uppströmsversionen och förblir på engelska. Undantaget är knapparna **Donera** och **Webbplats** i dialogrutan Om 7-ZSTar...: 67 av de 92 språken har ett ord för varje, och de övriga 25 visar engelska (`Lang/UPSTREAM.md` listar dem).
Översättningarna är övertagna från uppströmsversionen, inte skrivna här: se [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md).
