<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# Instalado de 7-ZSTar

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · [한국어](INSTALL.ko.md) · [Italiano](INSTALL.it.md) · [Polski](INSTALL.pl.md) · [Türkçe](INSTALL.tr.md) · [Nederlands](INSTALL.nl.md) · [Українська](INSTALL.uk.md) · [Bahasa Indonesia](INSTALL.id.md) · [ไทย](INSTALL.th.md) · [Čeština](INSTALL.cs.md) · [Magyar](INSTALL.hu.md) · [Română](INSTALL.ro.md) · [Svenska](INSTALL.sv.md) · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md) · **Esperanto**

*Se ĉi tiu teksto malakordas kun la angla versio, validas la angla versio.*

Ĉi tiu paĝo donas la detalojn malantaŭ la mallonga versio en la [README](../readme/README.eo.md): sistemaj postuloj, la averto de SmartScreen, Smart App Control kaj kiel kontroli elŝuton, la tri pakaĵoj, la kunteksta menuo de Windows 11 (dekstra klako), dosierasocioj kaj malinstalo.

## Sistemaj postuloj

**Windows 7 aŭ Windows Server 2008 R2, x64 aŭ x86. Ĉe arm64, Windows 10.**
Nenio alia estas bezonata: la rultempa biblioteko de C estas ligita statike (`-MT`), do la duumaj dosieroj importas nenion krom la propraj DLL-oj de Windows - neniu redistribuebla pakaĵo, neniu .NET.

Tiu minimuma versio estas *dedukita* el tio, kion la pakaĵoj postulas, kaj ĝi estis testita sur Windows 7 SP1 kun postaj ĝisdatigoj instalitaj (inkluzive de PowerShell 5.1), sur Windows 10 22H2 kaj sur Windows 11, ĉiuj 64-bitaj. Sur Windows 7 kaj 10 tio kovris instaladon kaj malinstaladon de la `.msi` x64 por ĉiuj uzantoj kaj por unu uzanto, la instalan asistanton, la `.zip` x64, ĉiun aldonitan kodekon kaj ĉiun unupaŝan tar-formaton, la kuntekstan menuon, dosierasociojn kaj la helpan dosieron, same kiel la `.msi` kaj la `.zip` x86 funkciantajn en 64-bita Windows. Nenio alia estis testita en Windows: nek Windows 8 aŭ 8.1, nek Windows Server, nek 32-bita Windows, nek aparataro arm64, nek Windows 7 sen tiuj ĝisdatigoj. La minimuma versio estas ankaŭ pli alta ol tiu de la originala 7-Zip (upstream), kies duumaj dosieroj ankoraŭ ŝargiĝas en Windows XP. Tri aferoj metas ĝin tie, kaj la dua estas tiu, kiun neniu konstrua agordo povas malfari:

- La `.msi` deklaras `InstallerVersion="500"`, kaj Windows Installer 5.0 estis liverita "with Windows Server 2008 R2 and later and Windows 7 and later" (tio estas, kun Windows Server 2008 R2 kaj pli novaj kaj kun Windows 7 kaj pli novaj) ([Microsoft][msi-versions]). La portebla `.zip` ne trairas Windows Installer, sed vidu la sekvajn du punktojn.
- **zstd kaj fast-lzma2 uzas sinkronigon, kiu ekzistas nur ekde Vista.** Ambaŭ trudas `_WIN32_WINNT 0x0600` en siaj propraj kapdosieroj kaj rekte vokas `InitializeConditionVariable` / `SleepConditionVariableCS`, do `7z.dll` kaj `7za.exe` - la du duumaj dosieroj kun la kodekoj enkompilitaj - importas kvar funkciojn, kiujn Windows XP kaj Server 2003 ne havas. La `7z.dll` de la originalo importas neniun el ili.
- La ilaro: ĉi tiuj estas kompilitaj per Visual Studio 2022, kies listo de subtenataj celoj estas Windows 7 kaj pli novaj - Vista kaj Server 2008 estas "No" ([Microsoft][vs-targeting]). La ligita subsistema versio estas 6.0 ĉe x64 kaj x86 kaj 6.2 ĉe arm64, kaj Windows ĉe arm64 komenciĝas ĉe Windows 10 ĉiuokaze.

Windows Vista kaj Server 2008 troviĝas inter tiuj limoj: la duumaj dosieroj ŝargiĝus, sed la ilaro ne subtenas ilin, la instalilo ne funkcios tie, kaj 7-ZSTar ne estas testita sur ili.

**Linux estas subtenata nur kiel komandlinia kompilaĵo; macOS ne estas subtenata.**
La disbranĉo kompilas denaskan `7zz` (la konzolan programon `Alone2`) per gcc, tra sia propra makefile, kiu inkluzivas tiujn de la originalo kaj modifas neniun el ili:
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
Ĝi estis kompilita kaj testita nur sur Ubuntu 24.04 kun gcc 13.3 (x86-64): la kompilo estas sen avertoj sub la flagoj de la originalo, la fumtesto kun 77 kontroloj trapasas, kaj la 25 interoperaj vektoroj faritaj en Windows kaj la 37 faritaj en Linux donas la samajn verdiktojn kiel en Windows. La du dosieroj posedataj de la disbranĉo, kiujn la adapto tuŝis, ankoraŭ kompiliĝas senŝanĝe en Windows (pura kompilo x64, fumtestoj kaj interopa relegado ĉiuj trapasas). Ne ekzistas GUI. La aliaj Linux-celoj de la originalo (`7za`, `7zr`, `7z.so`) ne estas subtenataj: en iliaj listoj de gcc-objektoj mankas tio, kion la ŝanĝoj de la disbranĉo en la traktiloj de la originalo bezonas, do oni atendas, ke ili malsukcesos ĉe la ligado. Aliaj arkitekturoj, distribuoj kaj kompililoj ne estis kontrolitaj, kaj macOS neniam estis kompilita, do neniu `MACOSX_DEPLOYMENT_TARGET` povas esti donita. Paŝoj de kompilo, testoj kaj konataj limoj estas en `build/linux/README.md`; interoperado kun Linux-iloj estas en `test/interop/REPORT.md`.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## Nesubskribitaj pakaĵoj, SmartScreen kaj Smart App Control

**La instaliloj kaj programoj en eldono de 7-ZSTar ne estas kodsubskribitaj de atestila aŭtoritato**, kaj ĉi tiu projekto posedas neniun atestilon por kodsubskribo. Windows tial ne povas scii, kiu publikigis la dosieron, kaj kiam vi rulas la `.msi`, aŭ programon el la `.zip`, la unuan fojon, Microsoft Defender SmartScreen povas haltigi ĝin per averto. La disvolva dokumentaro de Microsoft listigas "No signature" (neniu subskribo) inter la kazoj, kiuj montras averton kun la titolo "Windows protected your PC" (Windows protektis vian komputilon), kie la uzanto devas elekti "Run anyway" (ruli tamen) antaŭ ol la aplikaĵo ruliĝas ([Microsoft][smartscreen-rep]). Entreprena politiko povas tute forigi tiun elekton; en tia komputilo, demandu tiun, kiu ĝin administras.

La sola afero en eldono, kiu *estas* subskribita, estas la malgranda pakaĵo, kiu metas 7-ZSTar en la unuan nivelon de la kunteksta menuo de Windows 11, ene de la `.msi` por ĉiuj uzantoj. Ĝia atestilo estas memsubskribita kaj generita dum la kompilo de tiu sola pakaĵo, do ĝi ne estas subskribo de atestila aŭtoritato kaj diras nenion pri tio, kiu kompilis la pakaĵon; vidu [la kuntekstan menuon de Windows 11](#la-kunteksta-menuo-de-windows-11) pri tio, kion ĝi faras kaj kiel rifuzi ĝin.

La averto ne pruvas, ke dosiero estas malbona, kaj ĝia foresto ne pruvus, ke dosiero estas bona. Kion vi mem povas kontroli, estas ke via kopio estas ĝuste tiu publikigita en la paĝo de la eldono. Ĉiu eldono portas dosieron nomatan `SHA256SUMS`: unu linio por ĉiu pakaĵo, haŝo SHA-256 sekvata de la dosiernomo.

1. Elŝutu la pakaĵon kaj `SHA256SUMS` el la sama paĝo de la eldono, en la saman dosierujon.
2. Malfermu PowerShell en tiu dosierujo kaj komparu. Anstataŭigu la nomon per la dosiero, kiun vi elŝutis:

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True` signifas, ke la haŝoj estas identaj. Por rigardi ilin mem anstataŭe, rulu `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi` kaj trovu la saman dosiernomon en `SHA256SUMS`; la komparo ignoras majusklojn kaj minusklojn.
3. Se vi ricevas `False`, aŭ la dosiernomo ne estas en `SHA256SUMS`, ne rulu ĝin: forigu la dosieron kaj elŝutu ĝin denove. Se ĝi ankoraŭ ne kongruas, bonvolu raporti tion kiel priskribite en [SECURITY.md](../../SECURITY.md).

`SHA256SUMS` kovras nur la dosierojn alŝutitajn al tiu eldono. Kompili la saman etikedon (tag) mem donas aliajn haŝojn (la pakaĵo de la kunteksta menuo estas subskribita per nova atestilo ĉe ĉiu kompilo), kaj la fontkodo estas publikigita kun ĉiu eldono, se vi preferas kompili ĝin: vidu [build/README.md](../../build/README.md).

Kiam la haŝoj kongruas kaj vi estas kontenta pri la origino de la dosiero:

- **`.msi`** - startu ĝin kiel kutime. Se SmartScreen haltigas ĝin, elektu la opcion ruli ĝin tamen ("Run anyway" en angla Windows). Eble necesas unue etendi la averton: en la testita komputilo kun Windows 10, ĝi proponis nur butonon por ne ruli la dosieron, ĝis oni klakis la ligilon sub ĝia mesaĝo. La `.msi` por ĉiuj uzantoj poste petas aprobon de administrator (administranto) kiel iu ajn alia instalilo.
- **`.zip`** - eltiru ĝin kaj startu `7zFM.exe` aŭ `7z.exe` el la dosierujo. La programoj en ĝi ankaŭ estas nesubskribitaj, do Windows povas montri la saman averton la unuan fojon, kiam vi startas ĉiun el ili.

SmartScreen avertas laŭ tio, kiom bone konata estas dosiero, ne nur laŭ subskriboj; dosiero elŝutita de malmultaj homoj povas ekigi ĝin eĉ kiam ĝi estas subskribita. Nenio ĉi tie ŝanĝas tion, kaj nenio en la suprataj paŝoj malŝaltas SmartScreen.

### Smart App Control en Windows 11

En kelkaj komputiloj kun Windows 11 pli strikta protekto nomata **Smart App Control** estas ŝaltita (*On*). Kiam ĝi estas ŝaltita, Windows blokas nesubskribitajn dosierojn, krom se la nuba servo de Microsoft povas garantii pri ili, kaj nova eldono kutime ne havas tian registron ([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). Male al la averto de SmartScreen, la bloko ne havas opcion ruli la dosieron tamen, kaj la FAQ de Microsoft diras, ke ne ekzistas maniero preterpasi Smart App Control por unuopa aplikaĵo.

Kio okazis, kiam 7-ZSTar 26.05.1 estis provita sur Windows 11 Pro 25H2 (build 26200.8037) kun Smart App Control ŝaltita:

- **La instaliloj `.msi` estis blokitaj**, tiu por ĉiuj uzantoj kaj tiu por unu uzanto same. En tradicia ĉina Windows, Windows Installer diris 「系統禁用此安裝。請連絡系統管理員。」, kaj sciigo de Windows Security diris, ke Smart App Control blokis la dosieron, ĉar Windows ne povis scii, kiu ĝin publikigis, kaj ĝi ne estas aplikaĵo konata de Windows. Ne estis opcio daŭrigi, kaj `msiexec /i ... /qn` redonis eraron 1625. Tiu mesaĝo estas la ĉeno 1625 de Windows Installer; en angla Windows la sama ĉeno legiĝas "The system administrator has set policies to prevent this installation." (legita el la anglaj rimedoj de Windows Installer, ne vidita sur ekrano).
- **Programo el la `.zip` ruliĝis.** `7zFM.exe`, eltirita el la portebla `.zip`, startiĝis normale en la sama testo. Ĉu Windows lasas nesubskribitan programon ruli, estas ĝia propra juĝo pri tiu dosiero, do tio povas esti malsama en via komputilo.
- Tuj post kiam Smart App Control estis ŝaltita, la `.msi` instaliĝis dum kelkaj minutoj, antaŭ ol ĝi komencis esti blokata. La kaŭzo ne estis trovita, do sukceso tuj post la ŝaltado ne signifas, ke la instalilo estas permesata.

Do en komputilo, kie Smart App Control estas ŝaltita, **la instaliloj ne povas esti instalitaj**, kaj kontrolo de `SHA256SUMS` tion ne ŝanĝas. Kio ja ŝanĝas, estas malŝalti Smart App Control en la agordoj de Smart App Control (Smart App Control settings) de la apo Windows Security (en la testita tradicia ĉina Windows: Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定). En la testo, elekti la opcion *Off* (malŝaltita) efikis tuj, sen restartigo, kaj la instaliloj poste instaliĝis. Tio estas agordo por la tuta komputilo kaj nenio ĉi tie petas vin ŝanĝi ĝin: la decido estas via, aŭ tiu de via administrator (administranto) en administrata komputilo.

Ankaŭ valoras scii antaŭe, ĉu ĝi povas esti denove ŝaltita. La FAQ de Microsoft diras, ke lastatempaj ĝisdatigoj de Windows permesas denove ŝalti Smart App Control sen pura instalo de Windows, do en versio sen ili malŝalti ĝin povas esti definitiva. En la ĉi tie testita eldono de Windows (build) la opcio por ŝalti ĝin ankoraŭ estis proponata post la malŝalto; tio estas testrezulto, ne promeso pri via versio.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## Instalado

Tri pakaĵoj, ĉiuj konstruitaj de `installer\Build-Package.ps1` (tiu por unu uzanto per `-PerUser`):

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| Instalas por | ĉiu konto | la instalanta konto | - |
| Kunteksta menuo de Explorer (dosiera esplorilo de Windows) | jes | jes, nur klasika menuo ([sube](#la-pakaĵo-por-unu-uzanto)) | ne |
| Ero en *Start menu* (starta menuo) | jes | jes | ne |
| Bezonas administrator rights (administrantajn rajtojn) | jes | ne | ne |
| Forigo | *Installed apps* (instalitaj aplikaĵoj) en Settings (agordoj) | *Installed apps* en Settings | forigi la dosierujon |

*Installed apps* estas la nomo en Windows 11. Windows 10 nomas la saman paĝon *Apps & features* (aplikaĵoj kaj funkcioj), kaj en Windows 7 ĝi estas *Programs and Features* (programoj kaj funkcioj) en Control Panel (kontrolpanelo).

Uzu la pakaĵojn, kiuj kongruas kun Windows mem: x86 en 32-bita Windows, x64 en 64-bita Windows, arm64 en Windows on Arm (la pakaĵoj arm64 estas konstruitaj, sed neniam rulitaj). La ŝela etendaĵo x86 estas 32-bita kaj 64-bita Explorer ne povas ŝargi ĝin, do en 64-bita Windows la x86 `-user.msi` tute ne havas kuntekstan menuon, kaj la x86 `.msi` havas ĝin nur en Windows 11 kaj nur por kontoj, kiuj registris ĝian pakaĵon por Windows 11 (la instalinta konto, aŭ konto, kiu rulis `-Register`, vidu sube).

La MSI instalas al `Program Files\7-ZSTar` - ĉiam: male al la pakaĵo por unu uzanto ĝi ne proponas elekton de dosierujo kaj ignoras `INSTALLFOLDER` en la komandlinio, ĉar tiu dosierujo enhavas skripton, kiun la instalilo rulas kiel SYSTEM, kaj DLL-on, kiun la Explorer de ĉiu uzanto ŝargas, kaj dosierujo farita aliloke (ekzemple sub `C:\`) estas skribebla por ĉiu uzanto. Ĝi registras sian propran CLSID de ŝela etendaĵo kaj sian propran registran branĉon (hive) `Software\7-ZSTar`, kaj nomas ĉiun ŝlosilon de kunteksta menuo `7-ZSTar` - do ĝi nek koliziiĝas kun tiuj de la oficiala 7-Zip, nek forigas ilin. Vidu [installer/GUIDS.md](../../installer/GUIDS.md).

Ĝi rulas normalan instalan asistanton - welcome, licence, setup type, optional feature tree, finish (bonvenigo, permesilo, tipo de instalo, arbo de nedevigaj funkcioj, fino) - kaj silenta instalado ankoraŭ funkcias senŝanĝe (`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`), ĉar msiexec preterlasas la tutan sekvencon de la fasado en silenta reĝimo. La asistanto estas nur en la angla, ankaŭ en Windows agordita al alia lingvo (vidite en tradicia ĉina Windows 10; la `.msi` estas konstruita sen alia lingvo), kaj ĝia fina paĝo havas *Launch 7-ZSTar File Manager* (ruli la dosiermastrumilon de 7-ZSTar) markita implicite.

### La kunteksta menuo de Windows 11

En Windows 11 la ero estas en la menuo de la unua nivelo, ne enterigita sub *Show more options* (montri pliajn opciojn), kie la oficiala 7-Zip kaj WinRAR ankoraŭ troviĝas. Windows 11 listigas tie ŝelan etendaĵon nur se ĝi venas kun pakaĵa identeco, do la MSI liveras apud la programo malgrandan MSIX-pakaĵon nur kun identeco kaj registras ĝin dum la instalado. La klasika registrado estas konservata ankaŭ. Ĝi estas tio, kio metas la eron en la kuntekstan menuon en Windows 10 kaj Windows 7, kies menuo havas unu solan nivelon sen *Show more options*, kaj tio, kio daŭrigas ĝian funkciadon por ĉiu, kiu restarigis la malnovan kuntekstan menuon.

Tiu pakaĵo estas subskribita per **memsubskribita atestilo**, kaj la instalilo metas ĝin en `LocalMachine\TrustedPeople` - Windows ne disponigos pakaĵon, kies subskribo ne ĉenas al io fidata. Malinstalado forigas la atestilon kune kun la pakaĵo. En Windows 10 kaj Windows 7 la instalilo faras nenion el ambaŭ: ĝi aldonas neniun atestilon kaj registras neniun pakaĵon, kaj la klasika registrado sola donas la menuon.

Se vi preferas ne fidi memsubskribitan atestilon, rifuzu nur tiun parton kaj konservu ĉion alian:

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

Tiam vi ricevas nur la klasikan menuon, do en Windows 11 la ero de 7-ZSTar estas en la kunteksta menuo sub *Show more options*. Por ŝalti la eron de la unua nivelo poste, aŭ por malfari ĝin post normala instalado:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

Fidi tiun atestilon signifas, ke Windows akceptos sen averto ankaŭ **ajnan alian** pakaĵon subskribitan per la sama ŝlosilo. Ĝi estas uzata nur por ĉi tiu unu pakaĵo, kaj malinstalado forprenas ĝin denove, sed tion vi konsentas - `SPARSE=0` supre estas la maniero rifuzi ĝin.

La registrado de la pakaĵo estas por unu uzanto, kaj la instalilo faras ĝin nur por tiu, kiu instalis. Du sekvoj:

- Dua konto en la sama komputilo ricevas nur la klasikan menuon, ĝis ĝi rulas tiun saman skripton kun `-Register`.
- Malinstalado malregistras ĝin nur por tiu, kiu malinstalas. Se iu alia registris ĝin, ilia registrado postvivas la malinstaladon kaj montras al dosierujo, kiu jam ne ekzistas; tiu konto forigas ĝin per `Get-AppxPackage 7-ZSTar | Remove-AppxPackage`.

**Konata limigo: la menuo de la unua nivelo estas registrita nur kiam la instalado okazas en interaga, ensalutinta seanco.** Instali la `.msi` por ĉiuj uzantoj el fora aŭ neinteraga seanco - per SSH, aŭ silenta disponigo el administra ilo - ankoraŭ raportas sukceson, sed la pakaĵo por Windows 11 ne estas registrita, do aperas nur la klasika menuo sub *Show more options*. En la testo, `msiexec /i ... /qn` el SSH-seanco (seanco 0) finiĝis per 0, dum `Setup-ShellIntegration.ps1` raportis `registration failed: 0x80070005` (aliro rifuzita); la sama `.msi` instalita el konzola seanco de administranto registriĝis normale.

`-Status` montras, kio estas kaj kio ne estas surloke.

### La pakaĵo por unu uzanto

`7-ZSTar-<version>-<arch>-user.msi` instalas nur por la nuna konto, en `%LOCALAPPDATA%\Programs\7-ZSTar`, sen peto de User Account Control (UAC). Ĉio, kion ĝi registras, iras sub `HKCU`; la pakaĵo skribas nenion al `HKLM` (krom la propra librotenado de Windows Installer). Kion ĝi ne faras tiel, kiel la pakaĵo por la tuta komputilo:

- **Neniu menuo de la unua nivelo de Windows 11.** En Windows 11 7-ZSTar estas en la kunteksta menuo sub *Show more options*. La ero de la unua nivelo postulas, ke la memsubskribita atestilo estu fidata en la tuta komputilo, kio bezonas administrator (administranton): mezurite en Windows 11, atestilo en `CurrentUser\TrustedPeople` ne sufiĉas, por ke Windows disponigu la pakaĵon. Tial la pakaĵo por unu uzanto ellasas ĝin.
- **Unu el la du por komputilo.** Ĉiu pakaĵo rifuzas instaliĝi dum la alia estas instalita; malinstalu unu antaŭ ol instali la alian. La pakaĵo por la tuta komputilo povas vidi nur la kopion por unu uzanto de la konto, kiu ĝin rulas, do instalo por unu uzanto de alia konto ne estas detektata.
- **Group policy (grupa politiko) povas kaŝi ĝian menuon.** Kie `EnforceShellExtensionSecurity` estas agordita, Explorer ŝargas nur ŝelajn etendaĵojn listigitajn sub la ŝlosilo *Approved* de la tuta komputilo, kiun instalo por unu uzanto ne povas skribi, do la kunteksta menuo ne aperas. Uzu tie la pakaĵon por la tuta komputilo.
- **Malplenigi formaton en Agordoj > Agordoj... > Sistemo ankaŭ forigas la proponon de 7-ZSTar por ĝi.** Kiam vi malplenigas tie formaton (klaku ĝian ĉelon ĝis ĝi malplenas, poste Bone), la dosiermastrumilo forigas la tutajn ŝlosilojn `HKCU\Software\Classes\.<ext>` kaj `7-ZSTar.<ext>` - kaj ĉe instalo por unu uzanto tiuj ŝlosiloj enhavas ankaŭ tion, kion la pakaĵo registris por Settings > Apps > Default apps (agordoj, aplikaĵoj, implicitaj aplikaĵoj) kaj la liston *Open with* (malfermi per). 7-ZSTar tiam malaperas el *Open with* por tiu formato, kaj Default apps montras malplenan eron por ĝi. Ripari la instaladon revenigas ĝin (rulu la `.msi` denove kaj elektu *Repair*, tio estas ripari). Pli bone, atribuu dosiertipojn en Default apps anstataŭ en la dosiermastrumilo. La pakaĵo por la tuta komputilo havas la saman malfortan punkton en unu loko, priskribita sube sub dosierasocioj.

### Dosierasocioj kaj kio okazas ĉe malinstalado

**Agordu ilin en Settings > Apps > Default apps.** En Windows 11 tajpu tie 7-ZSTar, kaj ĉiu formato, kiun ĝi povas malfermi, estas listigita por atribuo. En Windows 10 7-ZSTar estas listigita sub *Set defaults by app* (agordi implicitojn laŭ aplikaĵo) en tiu paĝo, kie *Manage* (administri) montras ĝiajn formatojn. Windows 7 ne havas la apon Settings: 7-ZSTar estas listigita en Control Panel > Default Programs > *Set your default programs* (agordi viajn implicitajn programojn), kio estas tio, kion *Default apps* signifas en ĉi tiu gvidilo tie. Atribui formatojn el tiuj du paĝoj ne estis testita. La instalilo registras 7-ZSTar kiel aplikaĵon de Default Programs - ProgID por ĉiu formato kun ĝia ikono kaj malfermkomando, eron en la listo *Open with* de ĉiu etendo, kaj la blokon Capabilities, kiun Windows legas - sed ĝi intence postulas neniun dosiertipon: kiu programo malfermas viajn arĥivojn, estas via decido, kaj tio tenas 7-ZSTar kaj la oficialan 7-Zip for de la vojo unu de la alia. Windows tamen povas mem sendi formaton al 7-ZSTar, kiam neniu alia programo proponas malfermi ĝin: en la testitaj komputiloj kun Windows 10 kaj Windows 7, kie nenio alia registris `.7z`, dosiero `.7z` montris la ikonon de 7-ZSTar kaj malfermiĝis en ĝi per duobla klako, sen ke Windows demandis, kiun programon uzi.

**Agordoj > Agordoj... > Sistemo en la dosiermastrumilo plejparte ne funkcias en Windows 11**, kaj tio estas regulo de Windows, ne cimo ĉi tie. Ĝi skribas ProgID `7-ZSTar.<ext>` en `HKCU\Software\Classes`, kaj por ĉiu etendo, kiun la komputilo jam konas - ĉiu arĥiva formato estas tia - Windows 11 ignoras ĝin: `AssocQueryString` respondas `Unknown` kaj Explorer desegnas la malplenan ĝeneralan ikonon. Kion ĝi respektas anstataŭe, estas ŝlosilo `UserChoice` stampita per haŝo, kiun nur Windows povas kalkuli, kaj tial la interfaco de Settings estas la sola vojo tie. Neniu aplikaĵo povas skribi tian: nek 7-ZSTar, nek 7-Zip, nek ajna instalilo. Windows 10 kaj Windows 7 kondutis alie en testoj: post kiam `.7z` kaj `.zst` estis agorditaj en la dosiermastrumilo, sen elekto de alia programo por ili, `AssocQueryString` redonis `7zFM.exe` por ambaŭ.

**Malplenigi formaton en ĝia kolumno *All users* forigas la propran registradon de la pakaĵo por la tuta komputilo por ĝi.** Tiu kolumno skribas al `HKLM\Software\Classes`, kie la pakaĵo por la tuta komputilo tenas la ProgID-ojn kaj la erojn *Open with*, kiujn ĝi proponas, kaj malplenigi tie formaton, kio postulas la dosiermastrumilon rulatan per *Run as administrator* (kiel administranto), forigas tiujn ŝlosilojn tute - por ĉiu konto. Ripari restarigis la samajn ŝlosilojn por la pakaĵo por unu uzanto; por ĉi tiu ĝi ne estis mezurita.

**Ikono, kiu restas malplena post ŝanĝo de io,** povas esti ankaŭ la ikona kaŝmemoro de Explorer, kiu ne rimarkas, ke DLL, kiun ĝi jam kaŝmemoris, estis anstataŭigita; `ie4uinit.exe -show` ne fidinde malplenigas ĝin. Fermu Explorer, forigu `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db`, startu ĝin denove.

**Malinstalado forigas la asociojn, kiujn ĝi povas atingi** - la ProgID-ojn `7-ZSTar.*` apartenantajn al tiu, kiu malinstalas, kaj nur la dosiertipojn, kiuj ankoraŭ montras al ili, do formato transdonita intertempe al alia programo restas netuŝita. Malinstalado de la pakaĵo por la tuta komputilo lasas netuŝita ankaŭ ProgID-on, kiu malfermas kopion de 7-ZSTar aliloke, kiu ankoraŭ ekzistas - portebla el la `.zip`, agordita per la propra **Agordoj > Agordoj... > Sistemo** de tiu kopio. La pakaĵo por unu uzanto ne povas: ĝiaj ProgID-oj estas tiuj samaj ŝlosiloj `HKCU` (vidu *La pakaĵo por unu uzanto* supre), kaj malinstali ĝin forigas ilin, ĉiu ajn skribis ilin laste. Lasi ilin malantaŭe direktus tiujn tipojn al ProgID, kies ikono kaj komando estas forigita plenumebla dosiero, tio estas malplena ikono kaj eraro ĉe duobla klako. Asocioj de aliaj kontoj estas ekster atingo; ili povas forigi la proprajn per `Setup-ShellIntegration.ps1 -RemoveAssociations` antaŭ ol la programo foriĝas. `msiexec /x ... KEEPASSOC=1` preterlasas tion, kaj ĝisdatigo neniam faras ĝin.

**Konata limigo: aliaj kontoj konservas la asociojn, kiujn ili mem agordis.** Malinstalado de la pakaĵo por la tuta komputilo forigas nur tion, kion la konto, kiu rulas la malinstaladon, agordis en sia propra kolumno (kun la kontonomo kiel kaplinio) sub **Agordoj > Agordoj... > Sistemo** en la dosiermastrumilo. Ĉiu alia konto, kiu agordis tie asociojn, konservas ilin, montrantajn al la forigita programo, do duobla klako sur dosiero `.7z` igas Windows demandi, kiun programon uzi. Ĉiu konto devus forigi la proprajn **antaŭ** la malinstalado, per

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

kio forigas nur la erojn de 7-ZSTar, aŭ poste denove atribui la tipojn sub Settings > Apps > Default apps. Fari tion anstataŭe en la dosiermastrumilo signifas klaki ĉiun ĉelon en sia propra kolumno, kiu montras 7-ZSTar, ĝis ĝi malplenas, poste Bone; ne elektu ĉiujn vicojn kaj premu "+", kio aplikas unu staton al ĉiu elektita vico kaj tiel malplenigas ankaŭ formatojn, kiuj apartenas al alia programo, ekzemple la oficiala 7-Zip.

Asocioj agorditaj en la kolumno **All users** tute ne estas tuŝataj de la purigado ĉe malinstalado, kaj restas montrantaj ĉiun konton al la forigita programo. Administrator (administranto), kiu agordis iun, devus malplenigi tiujn ĉelojn, el dosiermastrumilo rulata per *Run as administrator*, poste Bone, antaŭ ol malinstali; `-RemoveAssociations` ne atingas ĉi tiun kolumnon. Malplenigi ĝin tuj antaŭ malinstalado estas sendanĝera, kvankam ĝi forigas tie la propran registradon de la pakaĵo (supre), ĉar la malinstalado forigas tion ĉiuokaze. La pakaĵo por unu uzanto ne havas la problemon de aliaj kontoj, kaj la oficiala 7-Zip kondutas same.

## Lingvoj

Ĉiu pakaĵo portas la tradukojn de la originalo (upstream), pli ol 90 lingvojn. Elektu unu sub **Agordoj > Agordoj... > Lingvo**; la MSI ankaŭ lasas vin preterlasi ilin sub la instalado *Custom*. 7-ZSTar provas sekvi la sisteman lingvon ĉe la unua starto, sed tiu detekto rezignas kaj restas angla, kiam la agordoj de Windows "language for non-Unicode programs" (lingvo por ne-Unicode-programoj) kaj "regional format" (regiona formato) malakordas - elekti lingvon permane ĉiam funkcias.

Ĉenoj, kiujn 7-ZSTar mem aldonis - la kampoj de zstd-nivelo kaj vortaro, la nomoj de la novaj arĥivaj formatoj - ne havas tradukon de la originalo kaj restas anglaj. La escepto estas la butonoj **Donaci** kaj **Retejo** de la dialogo «Pri 7-ZSTar...»: 67 el la 92 lingvoj havas vorton por ĉiu, kaj la aliaj 25 montras la anglan (`Lang/UPSTREAM.md` listigas ilin).
La tradukoj estas importitaj (vendored) kiel ili estas, ne verkitaj ĉi tie: vidu [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md).
