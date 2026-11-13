<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# Instalarea 7-ZSTar

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · [简体中文](INSTALL.zh-Hans.md) · [Deutsch](INSTALL.de.md) · [Français](INSTALL.fr.md) · [Español](INSTALL.es.md) · [Português (Brasil)](INSTALL.pt-BR.md) · [日本語](INSTALL.ja.md) · [Tiếng Việt](INSTALL.vi.md) · [Русский](INSTALL.ru.md) · [한국어](INSTALL.ko.md) · [Italiano](INSTALL.it.md) · [Polski](INSTALL.pl.md) · [Türkçe](INSTALL.tr.md) · [Nederlands](INSTALL.nl.md) · [Українська](INSTALL.uk.md) · [Bahasa Indonesia](INSTALL.id.md) · [ไทย](INSTALL.th.md) · [Čeština](INSTALL.cs.md) · [Magyar](INSTALL.hu.md) · **Română** · [Svenska](INSTALL.sv.md) · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md) · [Esperanto](INSTALL.eo.md)

*Dacă există diferențe față de versiunea în limba engleză, este valabilă versiunea în limba engleză.*

Aici găsiți detaliile din spatele variantei scurte din [README](../readme/README.ro.md): cerințele de sistem, avertismentul SmartScreen, Controlul inteligent al aplicațiilor (Smart App Control) și verificarea unei descărcări, cele trei pachete, meniul contextual din Windows 11, asocierile de fișiere și dezinstalarea.

## Cerințe de sistem

**Windows 7 sau Windows Server 2008 R2, x64 sau x86. Pe arm64, Windows 10.**
Nu este nevoie de nimic altceva: runtime-ul C este legat static (`-MT`), așa că fișierele binare nu importă decât DLL-urile din Windows însuși - fără pachete redistribuibile, fără .NET.

Această cerință minimă este *dedusă* din ce necesită pachetele și a fost testată pe Windows 7 SP1 cu actualizări ulterioare instalate (printre ele PowerShell 5.1), pe Windows 10 22H2 și pe Windows 11, toate pe 64 de biți. Pe Windows 7 și 10, testul a acoperit instalarea și dezinstalarea fișierelor `.msi` x64 pentru toți utilizatorii și pe utilizator, expertul de instalare, `.zip`-ul x64, fiecare codec adăugat și fiecare format tar dintr-un singur pas, meniul contextual, asocierile de fișiere și fișierul de ajutor, precum și `.msi`-ul și `.zip`-ul x86 rulând pe Windows pe 64 de biți. Nimic altceva nu a fost testat pe Windows: nici Windows 8 sau 8.1, nici Windows Server, nici Windows pe 32 de biți, nici hardware arm64, nici Windows 7 fără acele actualizări. Cerința minimă este, de asemenea, mai ridicată decât cea a 7-Zip original, ale cărui fișiere binare se încarcă încă pe Windows XP. Trei lucruri o stabilesc la acest nivel, iar al doilea este cel pe care nicio setare de compilare nu îl poate anula:

- Fișierul `.msi` declară `InstallerVersion="500"`, iar Windows Installer 5.0 a fost livrat „with Windows Server 2008 R2 and later and Windows 7 and later” ([Microsoft][msi-versions]). Arhiva `.zip` portabilă nu trece prin Windows Installer, dar vedeți următoarele două puncte.
- **zstd și fast-lzma2 folosesc sincronizare disponibilă doar începând cu Vista.** Ambele forțează `_WIN32_WINNT 0x0600` în propriile antete și apelează direct `InitializeConditionVariable` / `SleepConditionVariableCS`, astfel încât `7z.dll` și `7za.exe` - cele două fișiere binare în care sunt compilate codecurile - importă patru funcții pe care Windows XP și Server 2003 nu le au. `7z.dll` din 7-Zip original nu importă niciuna dintre ele.
- Lanțul de compilare: acestea sunt compilate cu Visual Studio 2022, a cărui listă de ținte acceptate este Windows 7 și versiunile ulterioare - Vista și Server 2008 sunt „No” ([Microsoft][vs-targeting]). Versiunea subsistemului din fișierele legate este 6.0 pe x64 și x86 și 6.2 pe arm64, iar Windows pe arm64 începe oricum cu Windows 10.

Windows Vista și Server 2008 se află undeva la mijloc: fișierele binare s-ar încărca, dar lanțul de compilare nu le acceptă, programul de instalare nu va rula acolo, iar 7-ZSTar nu este testat pe ele.

**Linux este acceptat doar ca versiune compilată pentru linia de comandă; macOS nu este acceptat.**
Fork-ul compilează un `7zz` nativ (programul de consolă `Alone2`) cu gcc, printr-un makefile propriu, care îl include pe cel din 7-Zip original și nu modifică niciunul dintre ele:
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
A fost compilat și testat doar pe Ubuntu 24.04 cu gcc 13.3 (x86-64): compilarea nu dă avertismente cu opțiunile din 7-Zip original, testul rapid de 77 de verificări trece, iar cei 25 de vectori de interoperabilitate creați pe Windows și cei 37 creați pe Linux dau aceleași verdicte ca pe Windows. Cele două fișiere ale fork-ului pe care portarea le-a atins se compilează în continuare nemodificate pe Windows (compilare x64 curată, testele rapide și recitirea de interoperabilitate trec toate). Nu există interfață grafică. Celelalte ținte Linux din 7-Zip original (`7za`, `7zr`, `7z.so`) nu sunt acceptate: listele lor de obiecte gcc nu conțin ce au nevoie modificările fork-ului pentru handlerele din 7-Zip original, așa că este de așteptat ca linkeditarea să eșueze. Alte arhitecturi, distribuții și compilatoare nu au fost verificate, iar macOS nu a fost compilat niciodată, deci nu se poate indica nicio valoare pentru `MACOSX_DEPLOYMENT_TARGET`. Pașii de compilare, testele și limitele cunoscute se află în `build/linux/README.md`; interoperabilitatea cu uneltele Linux se află în `test/interop/REPORT.md`.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## Pachete nesemnate, SmartScreen și Controlul inteligent al aplicațiilor

**Programele de instalare și programele dintr-o versiune 7-ZSTar nu sunt semnate digital de o autoritate de certificare**, iar acest proiect nu deține niciun certificat de semnare a codului. Prin urmare, Windows nu poate ști cine a publicat fișierul, iar când rulați pentru prima dată fișierul `.msi` sau un program din `.zip`, Microsoft Defender SmartScreen îl poate opri cu un avertisment. Documentația Microsoft pentru dezvoltatori enumeră „No signature” printre cazurile care afișează un avertisment cu titlul „Windows v-a protejat computerul”, în care utilizatorul trebuie să aleagă „Executați oricum” înainte ca aplicația să ruleze ([Microsoft][smartscreen-rep]). Politicile unei întreprinderi pot elimina complet această opțiune; pe un astfel de PC, întrebați persoana care îl administrează.

Singurul lucru dintr-o versiune care *este* semnat este pachetul mic ce pune 7-ZSTar pe primul nivel al meniului contextual din Windows 11, aflat în `.msi`-ul pentru toți utilizatorii. Certificatul său este autosemnat și generat în timpul compilării acelui pachet, deci nu este semnătura unei autorități de certificare și nu spune nimic despre cine a compilat pachetul; vedeți [meniul contextual din Windows 11](#meniul-contextual-din-windows-11) pentru ce face și cum îl puteți refuza.

Avertismentul nu este o dovadă că un fișier este dăunător, iar absența lui nu ar fi o dovadă că un fișier este bun. Ce puteți verifica singur este că exemplarul dumneavoastră este exact cel publicat pe pagina versiunii. Fiecare versiune conține un fișier numit `SHA256SUMS`: câte o linie pentru fiecare pachet, un hash SHA-256 urmat de numele fișierului.

1. Descărcați pachetul și `SHA256SUMS` de pe aceeași pagină a versiunii, în același folder.
2. Deschideți PowerShell în acel folder și comparați. Înlocuiți numele cu cel al fișierului descărcat:

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True` înseamnă că hash-urile sunt identice. Dacă vreți să le priviți chiar dumneavoastră, rulați
   `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi` și găsiți același
   nume de fișier în `SHA256SUMS`; comparația ignoră diferența dintre majuscule și minuscule.
3. Dacă obțineți `False` sau numele fișierului nu se află în `SHA256SUMS`, nu îl rulați:
   ștergeți fișierul și descărcați-l din nou. Dacă tot nu se potrivește, vă rugăm să
   raportați așa cum este descris în [SECURITY.md](../../SECURITY.md).

`SHA256SUMS` acoperă doar fișierele încărcate la acea versiune. Dacă compilați singur același
tag, veți obține alte hash-uri (pachetul meniului contextual este semnat
cu un certificat nou la fiecare compilare), iar codul sursă este publicat
cu fiecare versiune, dacă preferați să compilați: vedeți [build/README.md](../../build/README.md).

După ce hash-urile se potrivesc și sunteți mulțumit de proveniența fișierului:

- **`.msi`** - porniți-l ca de obicei. Dacă SmartScreen îl oprește, alegeți opțiunea de a-l rula
  oricum („Executați oricum”; „Run anyway” într-un Windows în limba engleză). Poate fi nevoie să extindeți mai întâi
  fereastra de avertizare: pe mașina cu Windows 10 testată, aceasta oferea doar un buton
  pentru a nu rula fișierul, până când se făcea clic pe linkul de sub mesajul ei. `.msi`-ul pentru toți utilizatorii
  cere apoi aprobarea Administratorului, ca oricare alt program de instalare.
- **`.zip`** - extrageți-l și porniți `7zFM.exe` sau `7z.exe` din folder. Programele
  din interior sunt și ele nesemnate, așa că Windows poate afișa același avertisment
  prima dată când porniți fiecare dintre ele.

SmartScreen avertizează în funcție de cât de cunoscut este un fișier, nu doar de semnături; un fișier
descărcat de puțini oameni poate declanșa avertismentul chiar dacă este semnat. Nimic
din cele de aici nu schimbă acest lucru, iar pașii de mai sus nu dezactivează SmartScreen.

### Controlul inteligent al aplicațiilor în Windows 11

Unele PC-uri cu Windows 11 au activată o protecție mai strictă, numită **Controlul inteligent al aplicațiilor** (Smart App Control).
Când este activată, Windows blochează fișierele nesemnate, cu excepția cazului în care serviciul cloud al Microsoft
poate garanta pentru ele, iar o versiune nouă de obicei nu are o astfel de înregistrare
([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). Spre deosebire de avertismentul SmartScreen, blocarea nu are opțiunea de a rula oricum fișierul, iar întrebările frecvente Microsoft spun că nu există
nicio modalitate de a ocoli Controlul inteligent al aplicațiilor pentru o aplicație individuală.

Ce s-a întâmplat când 7-ZSTar 26.05.1 a fost încercat pe Windows 11 Pro 25H2 (build
26200.8037) cu Controlul inteligent al aplicațiilor activat:

- **Programele de instalare `.msi` au fost blocate**, atât cel pentru toți utilizatorii, cât și cel pe utilizator.
  Pe un Windows în chineză tradițională, Windows Installer a afișat
  「系統禁用此安裝。請連絡系統管理員。」, iar o notificare Securitate Windows a spus
  că Controlul inteligent al aplicațiilor a blocat fișierul, deoarece Windows nu a putut stabili cine
  l-a publicat și nu este o aplicație cunoscută de Windows. Nu exista nicio opțiune de
  a continua, iar `msiexec /i ... /qn` a returnat eroarea 1625. Acel mesaj este șirul 1625
  din Windows Installer; pe un Windows în limba engleză, același șir este „The system administrator has set policies to prevent this
  installation.” (citit din resursele în limba engleză ale Windows Installer, nu văzut pe
  ecran).
- **Un program din `.zip` a rulat.** `7zFM.exe`, extras din `.zip`-ul portabil,
  a pornit normal în același test. Dacă Windows lasă un program nesemnat să ruleze
  este propria lui apreciere asupra fișierului respectiv, așa că pe PC-ul dumneavoastră rezultatul poate fi diferit.
- Imediat după ce Controlul inteligent al aplicațiilor a fost activat, `.msi`-ul s-a instalat câteva
  minute înainte de a începe să fie blocat. Cauza nu a fost găsită, așa că un succes
  imediat după activare nu înseamnă că programul de instalare este permis.

Așadar, pe un PC cu Controlul inteligent al aplicațiilor activat, **programele de instalare nu pot fi instalate**,
iar verificarea `SHA256SUMS` nu schimbă acest lucru. Ce schimbă lucrurile este dezactivarea Controlului inteligent al
aplicațiilor în aplicația Securitate Windows, la „Setări Controlul inteligent al aplicațiilor” (pe Windows în chineză tradițională testat: Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定).
În test, alegerea opțiunii de dezactivare a avut efect imediat, fără repornire, iar
programele de instalare s-au instalat apoi. Aceasta este o setare pentru întregul PC și nimic
din cele de aici nu vă cere să o schimbați: decizia vă aparține dumneavoastră sau Administratorului dumneavoastră, pe un PC gestionat.

Este bine de știut mai întâi și dacă poate fi reactivat. Întrebările frecvente Microsoft
spun că actualizările recente ale Windows permit reactivarea Controlului inteligent al aplicațiilor
fără o instalare curată a Windows, deci pe o versiune fără ele, dezactivarea
poate fi permanentă. Pe versiunea testată aici, opțiunea de
activare era în continuare oferită după dezactivare; acesta este un rezultat de test, nu o
promisiune despre versiunea dumneavoastră.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## Instalare

Trei pachete, toate create de `installer\Build-Package.ps1` (cel pe utilizator
cu `-PerUser`):

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| Se instalează pentru | toate conturile | contul care instalează | - |
| Meniul contextual din Explorer | da | da, doar meniul clasic ([mai jos](#pachetul-pe-utilizator)) | nu |
| Intrare în Meniul Start | da | da | nu |
| Necesită Administrator | da | nu | nu |
| Eliminare | *Aplicații instalate* din Setări | *Aplicații instalate* din Setări | ștergeți folderul |

*Aplicații instalate* este denumirea din Windows 11. Windows 10 numește aceeași pagină *Aplicații și
caracteristici*, iar în Windows 7 este *Programe și caracteristici* în Panou de control.

Folosiți pachetele care corespund versiunii Windows: x86 pe Windows pe 32 de biți, x64 pe
Windows pe 64 de biți, arm64 pe Windows pe Arm (pachetele arm64 sunt compilate, dar
nu au fost niciodată rulate). Extensia shell x86 este pe 32 de biți, iar Explorer pe 64 de biți nu o poate
încărca, deci pe Windows pe 64 de biți `-user.msi` x86 nu are deloc meniu contextual,
iar `.msi`-ul x86 are unul doar pe Windows 11 și doar pentru conturile care au
înregistrat pachetul lui pentru Windows 11 (cel care a instalat sau unul care a rulat
`-Register`, mai jos).

Pachetul MSI se instalează în `Program Files\7-ZSTar` - întotdeauna: spre deosebire de pachetul
pe utilizator, nu oferă alegerea folderului și ignoră `INSTALLFOLDER` din linia de comandă,
deoarece acel folder conține un script pe care programul de instalare îl rulează ca SYSTEM și
un DLL pe care Explorer al fiecărui utilizator îl încarcă, iar un folder creat în altă parte (de exemplu sub
`C:\`) poate fi scris de orice utilizator. Își înregistrează propriul CLSID de extensie
shell și propria ramură de registry `Software\7-ZSTar` și denumește fiecare cheie
de meniu contextual `7-ZSTar` - astfel încât nici nu intră în conflict cu 7-Zip oficial, nici nu îl elimină pe al acestuia.
Vedeți [installer/GUIDS.md](../../installer/GUIDS.md).

Rulează un expert de instalare obișnuit - welcome, licence, setup type, optional feature tree, finish (bun venit, licență, tipul de instalare, arborele de funcții opționale, final) - iar instalarea silențioasă funcționează în continuare neschimbat
(`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`), deoarece msiexec omite întreaga
secvență de interfață în modul silențios. Expertul este doar în limba engleză, chiar și pe un
Windows setat pe altă limbă (observat pe Windows 10 în chineză tradițională; `.msi`-ul
este compilat fără nicio altă limbă), iar pagina lui finală are bifat implicit *Launch
7-ZSTar File Manager*.

### Meniul contextual din Windows 11

În Windows 11, intrarea se află în meniul de prim nivel, nu ascunsă sub *Afișați mai multe opțiuni*,
unde se află încă 7-Zip oficial și WinRAR. Windows 11 listează acolo o extensie shell doar când
aceasta vine cu identitate de pachet, așa că MSI-ul livrează lângă program un mic pachet MSIX doar cu identitate
și îl înregistrează în timpul instalării. Este păstrată și înregistrarea clasică. Ea este cea care pune intrarea
în meniul contextual pe Windows 10 și Windows 7, al căror meniu are un singur
nivel, fără *Afișați mai multe opțiuni*, și cea care îl menține funcțional pentru oricine
a restabilit vechiul meniu contextual.

Acel pachet este semnat cu un **certificat autosemnat**, iar programul de instalare
îl pune în `LocalMachine\TrustedPeople` - Windows nu va implementa un pachet
a cărui semnătură nu poate fi legată de ceva de încredere. Dezinstalarea elimină
certificatul împreună cu pachetul. Pe Windows 10 și Windows 7, programul de instalare
nu face niciuna dintre aceste două lucruri: nu adaugă niciun certificat și nu înregistrează niciun pachet, iar
înregistrarea clasică singură oferă meniul.

Dacă preferați să nu acordați încredere unui certificat autosemnat, refuzați doar
acea parte și păstrați tot restul:

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

Veți avea atunci doar meniul clasic, deci în Windows 11 intrarea 7-ZSTar se află în
meniul contextual sub *Afișați mai multe opțiuni*. Pentru a activa mai târziu intrarea de prim nivel sau pentru a o anula după o instalare obișnuită:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

Acordarea de încredere acelui certificat înseamnă că Windows va accepta fără avertisment și **orice alt** pachet
semnat cu aceeași cheie. Ea este folosită întotdeauna doar pentru acest pachet,
iar dezinstalarea o elimină, dar la aceasta vă dați acordul -
`SPARSE=0` de mai sus este modalitatea de a o refuza.

Înregistrarea pachetului se face pe utilizator, iar programul de instalare o execută doar pentru cine
a instalat. Două consecințe:

- Un al doilea cont de pe același calculator are doar meniul clasic, până când
  rulează același script cu `-Register`.
- Dezinstalarea anulează înregistrarea doar pentru cine dezinstalează. Dacă altcineva
  a înregistrat-o, înregistrarea lui supraviețuiește dezinstalării și indică un
  folder care nu mai există; acel cont o șterge cu
  `Get-AppxPackage 7-ZSTar | Remove-AppxPackage`.

**Limitare cunoscută: meniul de prim nivel este înregistrat doar dacă instalarea
rulează într-o sesiune interactivă, cu utilizator conectat.** Instalarea `.msi`-ului pentru toți utilizatorii
dintr-o sesiune la distanță sau neinteractivă - prin SSH sau o implementare silențioasă dintr-un
instrument de administrare - raportează totuși succes, dar pachetul pentru Windows 11 nu
este înregistrat, așa că apare doar meniul clasic de sub *Afișați mai multe opțiuni*. În
test, `msiexec /i ... /qn` dintr-o sesiune SSH (sesiunea 0) s-a încheiat cu 0, în timp ce
`Setup-ShellIntegration.ps1` a raportat `registration failed: 0x80070005`
(Access is denied.); același `.msi` instalat din sesiunea de consolă a unui Administrator
s-a înregistrat normal.

`-Status` afișează ce este și ce nu este configurat.

### Pachetul pe utilizator

`7-ZSTar-<version>-<arch>-user.msi` se instalează doar pentru contul curent, în
`%LOCALAPPDATA%\Programs\7-ZSTar`, fără solicitarea Control cont utilizator. Tot ce înregistrează
se află sub `HKCU`; pachetul nu scrie nimic în `HKLM` (în afară de evidența proprie a Windows Installer). Ce nu face
așa cum face pachetul pe mașină:

- **Fără meniul de prim nivel din Windows 11.** În Windows 11, 7-ZSTar se află în
  meniul contextual sub *Afișați mai multe opțiuni*. Intrarea de prim nivel are nevoie ca
  certificatul autosemnat să fie de încredere la nivel de mașină, ceea ce cere un Administrator:
  măsurat pe Windows 11, un certificat din `CurrentUser\TrustedPeople` nu
  este suficient pentru ca Windows să implementeze pachetul. De aceea pachetul pe utilizator
  o lasă deoparte.
- **Doar unul dintre cele două pe o mașină.** Fiecare pachet refuză să se instaleze cât timp
  celălalt este instalat; dezinstalați-l pe unul înainte de a-l instala pe celălalt. Pachetul
  pe mașină poate vedea doar copia pe utilizator a contului care îl rulează,
  deci instalarea pe utilizator a altui cont nu este detectată.
- **Politică de grup: meniul poate fi ascuns.** Acolo unde `EnforceShellExtensionSecurity` este
  setat, Explorer încarcă doar extensiile shell listate sub cheia
  *Approved* de la nivel de mașină, în care o instalare pe utilizator nu poate scrie, așa că meniul contextual
  nu apare. Folosiți acolo pachetul pe mașină.
- **Ștergerea unui format din Unelte > Opţiuni... > Sistem elimină și oferta 7-ZSTar
  pentru el.** Când ștergeți acolo un format (faceți clic pe celula lui până devine goală,
  apoi Bine), managerul de fișiere șterge integral cheile
  `HKCU\Software\Classes\.<ext>` și `7-ZSTar.<ext>` - iar pentru o instalare pe utilizator acele chei conțin și ce a înregistrat pachetul pentru Setări >
  Aplicații > Aplicații implicite și pentru lista *Deschidere cu*. 7-ZSTar dispare atunci din
  *Deschidere cu* pentru acel format, iar Aplicații implicite arată pentru el o intrare goală.
  Repararea instalării o aduce înapoi (rulați din nou `.msi`-ul și alegeți
  *Repair*). Mai bine, atribuiți tipurile de fișiere în Aplicații implicite, nu în managerul
  de fișiere. Pachetul pe mașină are același punct slab într-un singur loc,
  descris mai jos la asocierile de fișiere.

### Asocieri de fișiere și efectul dezinstalării asupra lor

**Setați-le în Setări > Aplicații > Aplicații implicite.** În Windows 11, tastați 7-ZSTar
acolo și sunt listate toate formatele pe care le poate deschide, pentru a le atribui. În Windows 10,
7-ZSTar este listat pe acea pagină la *Set defaults by app* (setare valori implicite după aplicație), unde *Manage* (gestionare) arată formatele lui.
Windows 7 nu are aplicația Setări: 7-ZSTar este listat în
Panou de control > Programe implicite > *Setare programe implicite*, ceea ce înseamnă
*Aplicații implicite* din acest ghid acolo. Atribuirea formatelor din acele
două pagini nu a fost testată. Programul de instalare înregistrează 7-ZSTar ca aplicație
Programe implicite - un ProgID pentru fiecare format, cu pictograma și comanda de deschidere, o
intrare în lista *Deschidere cu* a fiecărei extensii și blocul Capabilities pe care Windows îl
citește - dar nu revendică în mod deliberat niciun tip de fișier: care program vă deschide
arhivele este decizia dumneavoastră și tocmai asta face ca 7-ZSTar și 7-Zip oficial să nu se încurce
unul pe altul. Windows poate totuși trimite singur un format către 7-ZSTar
când niciun alt program nu se oferă să îl deschidă: pe mașinile cu Windows 10 și Windows 7
testate, unde nimic altceva nu înregistrase `.7z`, un fișier `.7z` afișa pictograma 7-ZSTar
și se deschidea în el la dublu clic, fără ca Windows să întrebe ce
program să folosească.

**Unelte > Opţiuni... > Sistem din managerul de fișiere nu funcționează în mare parte pe
Windows 11**, iar aceasta este o regulă Windows, nu o eroare de aici. Scrie
un ProgID `7-ZSTar.<ext>` în `HKCU\Software\Classes`, iar pentru orice extensie pe care
mașina o cunoaște deja - fiecare format de arhivă o are - Windows 11 îl ignoră:
`AssocQueryString` răspunde `Unknown`, iar Explorer desenează pictograma generică goală.
Ce respectă în schimb este o cheie `UserChoice` ștampilată cu un hash pe care doar Windows
îl poate calcula, motiv pentru care interfața Setări este singura cale acolo. Nicio
aplicație nu o poate scrie: nici 7-ZSTar, nici 7-Zip, nici vreun program de instalare. Windows
10 și Windows 7 s-au comportat diferit la testare: după ce `.7z` și `.zst` au fost setate
în managerul de fișiere, fără alt program ales pentru ele, `AssocQueryString`
a returnat `7zFM.exe` pentru ambele.

**Ștergerea unui format din coloana *Toți utilizatorii* elimină înregistrarea proprie
a pachetului pe mașină pentru acel format.** Coloana aceea scrie
`HKLM\Software\Classes`, unde pachetul pe mașină își ține ProgID-urile și
intrările *Deschidere cu* pe care le anunță, iar ștergerea unui format de acolo (ceea ce necesită
managerul de fișiere pornit cu „Executare ca administrator”) șterge integral acele chei - pentru fiecare
cont. Repararea a restabilit aceleași chei pentru pachetul pe utilizator; pentru acesta
nu a fost măsurat.

**O pictogramă care rămâne goală după orice modificare** poate fi și cache-ul de pictograme al
Explorer, care nu observă că un DLL pe care l-a pus deja în cache a fost
înlocuit; `ie4uinit.exe -show` nu îl golește în mod sigur. Închideți Explorer,
ștergeți `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db` și porniți-l
din nou.

**Dezinstalarea elimină asocierile pe care le poate atinge** - ProgID-urile `7-ZSTar.*`
ale celui care dezinstalează și doar tipurile de fișiere care încă
indică spre ele, astfel încât un format predat între timp altui program rămâne neatins.
Dezinstalarea pachetului pe mașină lasă neatins și un ProgID care
deschide o copie a 7-ZSTar aflată în altă parte și care încă există - una portabilă din
`.zip`, configurată din **Unelte > Opţiuni... > Sistem** al acelei copii. Pachetul
pe utilizator nu poate face asta: ProgID-urile lui sunt aceleași chei `HKCU` (vedeți *Pachetul pe
utilizator* mai sus), iar dezinstalarea le elimină indiferent cine le-a scris
ultimul. Lăsarea lor ar îndrepta acele tipuri către un ProgID a cărui pictogramă și
comandă sunt un executabil șters, adică o pictogramă goală și o eroare la
dublu clic. Asocierile altor conturi sunt în afara razei de acțiune; ele le pot șterge
pe ale lor cu `Setup-ShellIntegration.ps1 -RemoveAssociations` înainte ca
programul să dispară. `msiexec /x ... KEEPASSOC=1` omite această curățare, iar o actualizare nu o face niciodată.

**Limitare cunoscută: celelalte conturi își păstrează asocierile pe care și le-au setat singure.**
Dezinstalarea pachetului pe mașină șterge doar ce a setat contul care rulează dezinstalarea
în propria coloană (având ca antet numele contului) din
**Unelte > Opţiuni... > Sistem** al managerului de fișiere. Orice alt cont care a setat
acolo asocieri le păstrează, indicând spre programul eliminat, astfel încât
dublu clic pe un fișier `.7z` întreabă Windows ce program să folosească. Fiecare cont
ar trebui să își șteargă asocierile **înainte** de dezinstalare, cu

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

care elimină doar intrările 7-ZSTar, sau după aceea să atribuie din nou tipurile
în Setări > Aplicații > Aplicații implicite. Dacă o faceți în managerul de fișiere, înseamnă
să faceți clic pe fiecare celulă din propria coloană care arată 7-ZSTar până devine
goală, apoi Bine; nu selectați toate rândurile și nu apăsați „+”, care aplică o singură stare
tuturor rândurilor selectate și șterge astfel și formatele care aparțin altui program, cum ar fi
7-Zip oficial.

Asocierile setate în coloana **Toți utilizatorii** nu sunt atinse deloc de curățarea
de la dezinstalare și rămân îndreptând fiecare cont către programul eliminat.
Un Administrator care a setat vreuna ar trebui să șteargă acele celule, dintr-un manager de fișiere pornit
cu „Executare ca administrator”, apoi Bine, înainte de dezinstalare; `-RemoveAssociations` nu
ajunge la această coloană. Ștergerea ei chiar înainte de o dezinstalare este inofensivă, chiar dacă
șterge și înregistrarea proprie a pachetului de acolo (mai sus), deoarece
dezinstalarea o elimină oricum. Pachetul pe utilizator nu are problema
celorlalte conturi, iar 7-Zip oficial se comportă la fel.

## Limbi

Fiecare pachet include traducerile din 7-Zip original, peste 90 de limbi. Alegeți una la
**Unelte > Opţiuni... > Limbaj**; MSI-ul vă permite, de asemenea, să le omiteți la instalarea *Custom*.
7-ZSTar încearcă să urmeze limba sistemului la prima pornire, dar această detectare renunță și rămâne
pe engleză atunci când setarea „Limbă pentru programele non-Unicode” din Windows și setarea
„Format regional” nu coincid - alegerea manuală a unei limbi funcționează întotdeauna.

Șirurile adăugate de 7-ZSTar însuși - câmpurile pentru nivelul zstd și dicționar, numele noilor
formate de arhivă - nu au traducere din 7-Zip original și rămân în engleză. Excepția
sunt butoanele **Donează** și **Site web** din caseta „Despre 7-ZSTar...”: 67 din cele 92 de limbi au câte un cuvânt pentru fiecare, iar celelalte 25 afișează engleza
(`Lang/UPSTREAM.md` le listează).
Traducerile sunt preluate ca atare (vendored), nu scrise aici: vedeți [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md).
