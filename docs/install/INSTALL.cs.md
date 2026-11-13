<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# Instalace 7-ZSTar

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · [한국어](INSTALL.ko.md) · [Italiano](INSTALL.it.md) · [Polski](INSTALL.pl.md) · [Türkçe](INSTALL.tr.md) · [Nederlands](INSTALL.nl.md) · [Українська](INSTALL.uk.md) · [Bahasa Indonesia](INSTALL.id.md) · [ไทย](INSTALL.th.md) · **Čeština** · [Magyar](INSTALL.hu.md) · [Română](INSTALL.ro.md) · [Svenska](INSTALL.sv.md) · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md)

*Pokud se obsah liší od anglické verze, platí anglická verze.*

Podrobnosti ke stručnému návodu v souboru [README](../readme/README.cs.md): systémové požadavky, varování SmartScreen, Inteligentní řízení aplikací a ověření staženého souboru, tři balíčky, kontextová nabídka Windows 11, přidružení souborů a odinstalace.

## Systémové požadavky

**Windows 7 nebo Windows Server 2008 R2, x64 nebo x86. Na arm64 Windows 10.**
Nic dalšího není potřeba: běhová knihovna jazyka C je připojena staticky (`-MT`), takže binární soubory importují jen vlastní knihovny DLL systému Windows – žádný redistribuovatelný balíček ani .NET.

Tato spodní hranice je *odvozena* z toho, co balíčky vyžadují, a byla otestována na Windows 7 SP1 s nainstalovanými pozdějšími aktualizacemi (mimo jiné s PowerShellem 5.1), na Windows 10 22H2 a Windows 11, vše 64bitové. Na Windows 7 a 10 test zahrnoval instalaci a odinstalaci x64 `.msi` pro všechny uživatele i pro jednoho uživatele, instalační průvodce, x64 `.zip`, všechny přidané kodeky a formáty tar na jeden krok, kontextovou nabídku, přidružení souborů a soubor nápovědy a také x86 `.msi` a `.zip` spuštěné na 64bitovém Windows. Nic jiného ve Windows testováno nebylo: ani Windows 8 a 8.1, ani Windows Server, 32bitové Windows, hardware s arm64 nebo Windows 7 bez uvedených aktualizací. Tato hranice je také vyšší než u původního 7-Zip, jehož binární soubory se stále načtou ve Windows XP. Za tím stojí tři věci a ta druhá je ta, kterou žádné nastavení sestavení nezvrátí:

- `.msi` deklaruje `InstallerVersion="500"` a Instalační služba systému Windows 5.0 byla dodávána „with Windows Server 2008 R2 and later and Windows 7 and later“ ([Microsoft][msi-versions]). Přenosný `.zip` instalační službou systému Windows neprochází, ale viz následující dva body.
- **zstd a fast-lzma2 používají synchronizaci, která existuje až od Windows Vista.** Obě si ve vlastních hlavičkových souborech vynucují `_WIN32_WINNT 0x0600` a přímo volají `InitializeConditionVariable` / `SleepConditionVariableCS`, takže `7z.dll` a `7za.exe` – dva binární soubory s přeloženými kodeky – importují čtyři funkce, které Windows XP a Server 2003 nemají. `7z.dll` z původního 7-Zip žádnou z nich neimportuje.
- Sada nástrojů: soubory se sestavují ve Visual Studiu 2022, jehož seznam podporovaných cílů začíná Windows 7 a novějšími – u Windows Vista a Server 2008 je uvedeno „No“ ([Microsoft][vs-targeting]). Verze propojeného subsystému je 6.0 na x64 a x86 a 6.2 na arm64 a Windows na arm64 začíná Windows 10 tak jako tak.

Windows Vista a Server 2008 leží mezi tím: binární soubory by se načetly, ale sada nástrojů je nepodporuje, instalační program tam nepoběží a 7-ZSTar na nich není testován.

**Linux je podporován pouze jako sestavení pro příkazový řádek; macOS podporován není.**
Fork sestavuje nativní `7zz` (konzolový program `Alone2`) pomocí gcc a vlastního makefilu, který zahrnuje ty původní a žádný z nich neupravuje:
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
Bylo sestaveno a testováno jen na Ubuntu 24.04 s gcc 13.3 (x86-64): sestavení je s příznaky původního projektu bez varování, smoke test o 77 kontrolách projde a 25 interoperabilitních vektorů vytvořených ve Windows a 37 vytvořených v Linuxu dává stejné výsledky jako ve Windows. Dva soubory vlastněné forkem, kterých se port dotkl, se ve Windows nadále sestaví beze změny (čisté sestavení x64, smoke testy i zpětné čtení interoperability vše projdou). Grafické rozhraní není. Ostatní linuxové cíle původního projektu (`7za`, `7zr`, `7z.so`) podporovány nejsou: v jejich seznamech objektů pro gcc chybí to, co změny forku v obslužných modulech původního projektu potřebují, takže se očekává, že se nepodaří slinkovat. Jiné architektury, distribuce a překladače ověřeny nebyly a macOS nebyl nikdy sestaven, takže nelze uvést žádné `MACOSX_DEPLOYMENT_TARGET`. Postup sestavení, testy a známá omezení jsou v `build/linux/README.md`; interoperabilita s nástroji pro Linux je v `test/interop/REPORT.md`.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## Nepodepsané balíčky, SmartScreen a Inteligentní řízení aplikací

**Instalační balíčky a programy ve vydání 7-ZSTar nejsou podepsány kódem od certifikační autority** a tento projekt nevlastní žádný certifikát pro podepisování kódu. Windows proto nedokáže poznat, kdo soubor vydal, a když poprvé spustíte `.msi` nebo program z `.zip`, může je Filtr SmartScreen v programu Microsoft Defender zastavit varováním. Vývojářská dokumentace Microsoftu uvádí „No signature“ jako jeden z případů, kdy se zobrazí varování s názvem „Systém Windows ochránil váš počítač“, kde musí uživatel před spuštěním aplikace zvolit „Přesto spustit“ ([Microsoft][smartscreen-rep]). Podnikové zásady mohou tuto možnost úplně odebrat; na takovém počítači se obraťte na toho, kdo ho spravuje.

Jediná věc ve vydání, která *je* podepsána, je malý balíček, který umísťuje 7-ZSTar na první úroveň kontextové nabídky Windows 11, uvnitř `.msi` pro všechny uživatele. Jeho certifikát je podepsaný sám sebou a vzniká při sestavování právě tohoto jednoho balíčku, takže to není podpis certifikační autority a nic nevypovídá o tom, kdo balíček sestavil; co dělá a jak ho odmítnout, viz [kontextová nabídka Windows 11](#kontextová-nabídka-windows-11).

Varování není důkazem, že je soubor špatný, a jeho absence by nebyla důkazem, že je soubor dobrý. Co si můžete ověřit sami, je to, že vaše kopie je přesně ta, která je zveřejněna na stránce vydání. Každé vydání obsahuje soubor `SHA256SUMS`: jeden řádek na balíček, hash SHA-256 následovaný názvem souboru.

1. Stáhněte balíček a `SHA256SUMS` ze stejné stránky vydání do stejné složky.
2. V této složce otevřete PowerShell a porovnejte. Název nahraďte souborem, který jste stáhli:

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True` znamená, že hashe jsou shodné. Chcete-li je porovnat sami, spusťte `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi` a najděte stejný název souboru v `SHA256SUMS`; porovnání nerozlišuje velká a malá písmena.
3. Pokud dostanete `False` nebo název souboru v `SHA256SUMS` není, soubor nespouštějte: smažte ho a stáhněte znovu. Pokud stále nesouhlasí, nahlaste to prosím způsobem popsaným v [SECURITY.md](../../SECURITY.md).

`SHA256SUMS` pokrývá jen soubory nahrané k danému vydání. Sestavení stejného tagu vlastními silami dá jiné hashe (balíček kontextové nabídky Windows 11 se při každém sestavení podepisuje novým certifikátem) a zdrojový kód se zveřejňuje s každým vydáním, pokud byste raději sestavili program sami: viz [build/README.md](../../build/README.md).

Jakmile hashe sedí a jste spokojeni s tím, odkud soubor pochází:

- **`.msi`** – spusťte ho jako obvykle. Pokud ho SmartScreen zastaví, zvolte možnost spustit ho přesto („Přesto spustit“; „Run anyway“ v anglickém Windows). Okno s varováním možná bude nutné nejprve rozbalit: na testovaném počítači s Windows 10 nabízelo jen tlačítko pro nespuštění souboru, dokud se neklikl odkaz pod jeho zprávou. `.msi` pro všechny uživatele pak vyžádá schválení správcem jako každý jiný instalační program.
- **`.zip`** – rozbalte ho a spusťte `7zFM.exe` nebo `7z.exe` ze složky. Programy uvnitř jsou také nepodepsané, takže Windows může při prvním spuštění každého z nich zobrazit stejné varování.

SmartScreen varuje podle toho, jak dobře je soubor znám, nejen podle podpisů; soubor, který si stáhlo málo lidí, ho může vyvolat, i když je podepsaný. Nic z toho na tom nic nemění a žádný z výše uvedených kroků SmartScreen nevypíná.

### Inteligentní řízení aplikací ve Windows 11

Na některých počítačích s Windows 11 je zapnutá přísnější ochrana zvaná **Inteligentní řízení aplikací**. Když je zapnutá, Windows blokuje nepodepsané soubory, pokud za ně neručí cloudová služba Microsoftu, a nové vydání takový záznam obvykle nemá ([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). Na rozdíl od varování SmartScreen nemá tato blokace možnost soubor přesto spustit a FAQ Microsoftu uvádí, že neexistuje způsob, jak Inteligentní řízení aplikací pro jednotlivou aplikaci obejít.

Co se stalo, když byl 7-ZSTar 26.05.1 vyzkoušen na Windows 11 Pro 25H2 (build 26200.8037) se zapnutým Inteligentním řízením aplikací:

- **Instalační balíčky `.msi` byly zablokovány**, ten pro všechny uživatele i ten pro jednoho uživatele. V tradiční čínštině Windows hlásila Instalační služba systému Windows 「系統禁用此安裝。請連絡系統管理員。」 a oznámení Zabezpečení Windows uvedlo, že Inteligentní řízení aplikací soubor zablokovalo, protože Windows nemohl zjistit, kdo ho vydal, a není to aplikace, kterou Windows zná. Nebyla žádná možnost pokračovat a `msiexec /i ... /qn` vrátil chybu 1625. Ta zpráva je řetězec 1625 Instalační služby systému Windows; v anglickém Windows tentýž řetězec zní „The system administrator has set policies to prevent this installation.“ (přečteno z anglických zdrojů Instalační služby systému Windows, ne viděno na obrazovce).
- **Program z `.zip` fungoval.** `7zFM.exe` rozbalený z přenosného `.zip` se ve stejném testu spustil normálně. Zda Windows nepodepsanému programu dovolí běžet, je jeho vlastní posouzení daného souboru, takže na vašem počítači to může být jinak.
- Krátce po zapnutí Inteligentního řízení aplikací se `.msi` několik minut instalovalo, než se začalo blokovat. Příčina nebyla nalezena, takže úspěch hned po zapnutí neznamená, že je instalační program povolen.

Takže na počítači, kde je Inteligentní řízení aplikací zapnuté, **instalační balíčky nelze nainstalovat** a kontrola `SHA256SUMS` na tom nic nemění. Změní to vypnutí Inteligentního řízení aplikací v aplikaci Zabezpečení Windows, v části Nastavení Inteligentního řízení aplikací (na testovaném tradičním čínském Windows: Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定). V testu volba vypnutí zabrala okamžitě bez restartu a instalační balíčky se pak nainstalovaly. Je to nastavení pro celý počítač a nic zde po vás nechce, abyste ho změnili: je to vaše rozhodnutí, nebo rozhodnutí vašeho správce na spravovaném počítači.

Dobré je také nejprve vědět, zda lze funkci znovu zapnout. FAQ Microsoftu uvádí, že nedávné aktualizace Windows umožňují Inteligentní řízení aplikací znovu zapnout bez čisté instalace Windows, takže ve verzi bez nich může být vypnutí trvalé. Na zde testovaném sestavení byla možnost zapnout ho po vypnutí stále nabízena; to je výsledek testu, ne příslib pro vaši verzi.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## Instalace

Tři balíčky, všechny sestavené skriptem `installer\Build-Package.ps1` (balíček pro jednoho uživatele s `-PerUser`):

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| Instaluje pro | všechny účty | instalující účet | - |
| Kontextová nabídka Průzkumníka souborů | ano | ano, jen klasická nabídka ([níže](#balíček-pro-jednoho-uživatele)) | ne |
| Nabídka Start (položka) | ano | ano | ne |
| Vyžaduje správce | ano | ne | ne |
| Odebrání | *Nainstalované aplikace* v Nastavení | *Nainstalované aplikace* v Nastavení | smazat složku |

*Nainstalované aplikace* je název ve Windows 11. Windows 10 nazývá stejnou stránku *Aplikace a funkce* a ve Windows 7 je to *Programs and Features* (Programy a funkce) v Control Panel (Ovládací panely).

Použijte balíčky, které odpovídají samotnému Windows: x86 na 32bitovém Windows, x64 na 64bitovém Windows, arm64 na Windows na zařízeních Arm (balíčky arm64 jsou sestaveny, ale nikdy nebyly spuštěny). Rozšíření shellu x86 je 32bitové a 64bitový Průzkumník souborů ho načíst nemůže, takže na 64bitovém Windows nemá x86 `-user.msi` kontextovou nabídku vůbec a x86 `.msi` ji má jen ve Windows 11 a jen pro účty, které zaregistrovaly jeho balíček pro Windows 11 (ten, který instaloval, nebo ten, který spustil `-Register`, viz níže).

MSI se instaluje do `Program Files\7-ZSTar` – vždy: na rozdíl od balíčku pro jednoho uživatele nenabízí volbu složky a ignoruje `INSTALLFOLDER` na příkazovém řádku, protože tato složka obsahuje skript, který instalační program spouští jako SYSTEM, a knihovnu DLL, kterou načítá Průzkumník souborů každého uživatele, a složka vytvořená jinde (například pod `C:\`) je zapisovatelná pro každého uživatele. Registruje vlastní CLSID rozšíření shellu a vlastní registrový hive `Software\7-ZSTar` a každý klíč kontextové nabídky pojmenovává `7-ZSTar`, takže se s oficiálním 7-Zip nekříží ani ho neodebírá. Viz [installer/GUIDS.md](../../installer/GUIDS.md).

Spouští běžného instalačního průvodce (welcome, licence, setup type, optional feature tree, finish – tedy uvítání, licence, typ instalace, strom volitelných funkcí, dokončení) a tichá instalace stále funguje beze změny (`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`), protože msiexec v tichém režimu celou posloupnost uživatelského rozhraní přeskočí. Průvodce je jen v angličtině, i na Windows nastaveném na jiný jazyk (viděno na tradičním čínském Windows 10; `.msi` je sestaveno bez dalšího jazyka) a na jeho poslední stránce je ve výchozím stavu zaškrtnuto *Launch 7-ZSTar File Manager*.

### Kontextová nabídka Windows 11

Ve Windows 11 je položka v nabídce první úrovně, ne ukrytá pod *Zobrazit další možnosti*, kde oficiální 7-Zip a WinRAR stále sedí. Windows 11 uvádí rozšíření shellu v nabídce první úrovně jen tehdy, když přichází s identitou balíčku, proto MSI vedle programu dodává malý balíček MSIX pouze s identitou a při instalaci ho registruje. Klasická registrace je zachována také. Právě ta zajišťuje položku v kontextové nabídce ve Windows 10 a Windows 7, jejichž nabídka má jedinou úroveň bez *Zobrazit další možnosti*, a právě ta zachovává funkčnost pro každého, kdo obnovil starou kontextovou nabídku.

Tento balíček je podepsán **certifikátem podepsaným sám sebou** a instalační program ho vkládá do `LocalMachine\TrustedPeople` – Windows nenasadí balíček, jehož podpis nedokáže navázat na nic důvěryhodného. Odinstalace odebere certifikát spolu s balíčkem. Ve Windows 10 a Windows 7 instalační program neudělá ani jedno: nepřidá žádný certifikát a neregistruje žádný balíček a nabídku zajišťuje samotná klasická registrace.

Pokud nechcete důvěřovat certifikátu podepsanému sám sebou, odmítněte jen tuto část a vše ostatní ponechte:

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

Pak dostanete jen klasickou nabídku, takže ve Windows 11 je položka 7-ZSTar v kontextové nabídce pod *Zobrazit další možnosti*. Chcete-li položku první úrovně zapnout později, nebo ji po běžné instalaci vrátit zpět:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

Důvěra v tento certifikát znamená, že Windows bez varování přijme i **jakýkoli jiný** balíček podepsaný stejným klíčem. Používá se vždy jen pro tento jeden balíček a odinstalace ho zase odebere, ale s tím souhlasíte – `SPARSE=0` výše je způsob, jak to odmítnout.

Registrace balíčku je pro každého uživatele zvlášť a instalační program ji spouští jen pro toho, kdo instaloval. Dva důsledky:

- Druhý účet na stejném počítači dostane jen klasickou nabídku, dokud nespustí tentýž skript s `-Register`.
- Odinstalace ji zruší jen tomu, kdo odinstalovává. Pokud ji zaregistroval někdo jiný, jeho registrace odinstalaci přežije a ukazuje na složku, která už neexistuje; tento účet ji vyčistí příkazem `Get-AppxPackage 7-ZSTar | Remove-AppxPackage`.

**Známé omezení: položka první úrovně se zaregistruje jen tehdy, když instalace běží v interaktivní, přihlášené relaci.** Instalace `.msi` pro všechny uživatele ze vzdálené nebo neinteraktivní relace – přes SSH nebo tichým nasazením z nástroje pro správu – sice hlásí úspěch, ale balíček pro Windows 11 se neregistruje, takže se objeví jen klasická nabídka pod *Zobrazit další možnosti*. V testu skončil `msiexec /i ... /qn` z relace SSH (relace 0) s kódem 0, zatímco `Setup-ShellIntegration.ps1` ohlásil `registration failed: 0x80070005` (Přístup byl odepřen.); stejné `.msi` nainstalované z konzolové relace správce se zaregistrovalo normálně.

`-Status` vypíše, co je a co není na místě.

### Balíček pro jednoho uživatele

`7-ZSTar-<version>-<arch>-user.msi` se instaluje jen pro aktuální účet do `%LOCALAPPDATA%\Programs\7-ZSTar`, bez výzvy Řízení uživatelských účtů (UAC). Vše, co registruje, jde pod `HKCU`; balíček nezapisuje nic do `HKLM` (kromě vlastní evidence Instalační služby systému Windows). Co nedělá tak, jak to dělá balíček pro celý počítač:

- **Žádná nabídka první úrovně ve Windows 11.** Ve Windows 11 je 7-ZSTar v kontextové nabídce pod *Zobrazit další možnosti*. Položka první úrovně vyžaduje, aby byl certifikát podepsaný sám sebou důvěryhodný v rámci celého počítače, k čemuž je potřeba správce: změřeno na Windows 11, certifikát v `CurrentUser\TrustedPeople` nestačí k tomu, aby Windows balíček nasadil. Balíček pro jednoho uživatele ji proto vynechává.
- **Vždy jen jeden ze dvou na počítač.** Každý balíček odmítne instalaci, dokud je nainstalován ten druhý; jeden odinstalujte, než nainstalujete druhý. Balíček pro celý počítač vidí jen kopii pro jednoho uživatele u účtu, který ho spouští, takže instalace pro jednoho uživatele u jiného účtu se nezjistí.
- **Zásady skupiny mohou jeho nabídku skrýt.** Kde je nastaveno `EnforceShellExtensionSecurity`, Průzkumník souborů načítá jen rozšíření shellu uvedená pod klíčem *Approved* platným pro celý počítač, do kterého instalace pro jednoho uživatele zapisovat nemůže, takže se kontextová nabídka neobjeví. Tam použijte balíček pro celý počítač.
- **Vymazání formátu v Nástroje > Možnosti > Systém také odebere nabídku 7-ZSTar pro tento formát.** Když tam formát vymažete (klikejte na jeho buňku, dokud není prázdná, pak OK), správce souborů smaže celé klíče `HKCU\Software\Classes\.<ext>` a `7-ZSTar.<ext>` – a u instalace pro jednoho uživatele tyto klíče obsahují i to, co balíček zaregistroval pro Nastavení > Aplikace > Výchozí aplikace a seznam *Otevřít v programu*. 7-ZSTar pak pro daný formát ze seznamu *Otevřít v programu* zmizí a Výchozí aplikace pro něj ukazují prázdnou položku. Oprava instalace ho vrátí (spusťte `.msi` znovu a zvolte *Repair*). Lepší je přiřazovat typy souborů ve Výchozích aplikacích, ne ve správci souborů. Balíček pro celý počítač má stejné slabé místo na jednom místě, popsaném níže u přidružení souborů.

### Přidružení souborů a co s nimi dělá odinstalace

**Nastavte je v Nastavení > Aplikace > Výchozí aplikace.** Ve Windows 11 tam zadejte 7-ZSTar a zobrazí se všechny formáty, které umí otevřít, k přiřazení. Ve Windows 10 je 7-ZSTar na té stránce uveden v části *Set defaults by app* (Nastavit výchozí aplikace podle aplikace), kde *Manage* (Spravovat) zobrazí jeho formáty. Windows 7 aplikaci Nastavení nemá: 7-ZSTar je tam uveden v Control Panel > Default Programs > *Set your default programs* (Ovládací panely > Výchozí programy > Nastavit výchozí programy), což je to, co v této příručce za tamní *Výchozí aplikace* stojí. Přiřazování formátů z těchto dvou stránek nebylo testováno. Instalační program registruje 7-ZSTar jako aplikaci pro funkci Výchozí programy – ProgID pro každý formát s jeho ikonou a příkazem otevření, položku v seznamu *Otevřít v programu* u každé přípony a blok Capabilities, který Windows čte – ale záměrně si nenárokuje žádný typ souboru: který program otevírá vaše archivy, je vaše rozhodnutí, a právě to udržuje 7-ZSTar a oficiální 7-Zip navzájem z cesty. Windows může formát poslat do 7-ZSTar i samo, když žádný jiný program nenabízí jeho otevření: na testovaných počítačích s Windows 10 a Windows 7, kde `.7z` nikdo jiný neregistroval, ukázal soubor `.7z` ikonu 7-ZSTar a po dvojitém kliknutí se v něm otevřel, aniž by se Windows ptal, který program použít.

**Nástroje > Možnosti > Systém ve správci souborů většinou ve Windows 11 nefunguje**, a to je pravidlo Windows, ne zdejší chyba. Zapisuje ProgID `7-ZSTar.<ext>` do `HKCU\Software\Classes` a pro každou příponu, kterou počítač už zná – a každý formát archivu ano – ho Windows 11 ignoruje: `AssocQueryString` odpoví `Unknown` a Průzkumník souborů vykreslí prázdnou obecnou ikonu. Respektuje místo toho klíč `UserChoice` opatřený hashem, který dokáže spočítat jen Windows, a proto je tam jedinou cestou rozhraní Nastavení. Žádná aplikace takový klíč zapsat nemůže: ani 7-ZSTar, ani 7-Zip, ani žádný instalační program. Windows 10 a Windows 7 se při testování chovaly jinak: jakmile byly `.7z` a `.zst` nastaveny ve správci souborů a nebyl pro ně vybrán žádný jiný program, `AssocQueryString` vrátil pro oba `7zFM.exe`.

**Vymazání formátu ve sloupci *Všichni uživatelé* odebere vlastní registraci balíčku pro celý počítač pro tento formát.** Tento sloupec zapisuje do `HKLM\Software\Classes`, kde balíček pro celý počítač uchovává ProgID a položky *Otevřít v programu*, které nabízí, a vymazání tamního formátu (což vyžaduje správce souborů spuštěný příkazem „Spustit jako správce“) smaže tyto klíče celé – pro každý účet. Oprava instalace obnovila stejné klíče u balíčku pro jednoho uživatele; u tohoto balíčku to měřeno nebylo.

**Ikona, která zůstává prázdná po jakékoli změně,** může být také mezipaměť ikon Průzkumníka souborů, která si nevšimne, že byla nahrazena knihovna DLL, kterou už uložila; `ie4uinit.exe -show` ji spolehlivě nevyčistí. Zavřete Průzkumníka souborů, smažte `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db` a spusťte ho znovu.

**Odinstalace odebere přidružení, na která dosáhne** – ProgID `7-ZSTar.*` patřící tomu, kdo odinstalovává, a jen typy souborů, které na ně stále ukazují, takže formát mezitím předaný jinému programu zůstane nedotčen. Odinstalace balíčku pro celý počítač také ponechá ProgID, který otevírá kopii 7-ZSTar jinde, jež stále existuje – přenosnou z `.zip`, nastavenou vlastním **Nástroje > Možnosti > Systém** té kopie. Balíček pro jednoho uživatele to nedokáže: jeho ProgID jsou tytéž klíče `HKCU` (viz *Balíček pro jednoho uživatele* výše) a odinstalace je odebere, ať je naposledy zapsal kdokoli. Jejich ponechání by nasměrovalo tyto typy na ProgID, jehož ikona a příkaz jsou smazaný spustitelný soubor, což znamená prázdnou ikonu a chybu při dvojitém kliknutí. Přidružení jiných účtů jsou mimo dosah; ty si mohou vyčistit sama příkazem `Setup-ShellIntegration.ps1 -RemoveAssociations`, než program zmizí. `msiexec /x ... KEEPASSOC=1` to přeskočí a upgrade to nedělá nikdy.

**Známé omezení: ostatní účty si ponechají přidružení, která si samy nastavily.** Odinstalace balíčku pro celý počítač vyčistí jen to, co účet provádějící odinstalaci nastavil ve svém vlastním sloupci (jehož záhlaví tvoří název účtu) pod **Nástroje > Možnosti > Systém** ve správci souborů. Každý jiný účet, který tam přidružení nastavil, si je ponechá a ta budou ukazovat na odebraný program, takže dvojité kliknutí na soubor `.7z` se Windows zeptá, který program použít. Každý účet by si měl svá vyčistit **před** odinstalací příkazem

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

který odebere jen položky 7-ZSTar, nebo po odinstalaci typy znovu přiřadit v Nastavení > Aplikace > Výchozí aplikace. Ve správci souborů to znamená kliknout na každou buňku ve vlastním sloupci, která ukazuje 7-ZSTar, dokud není prázdná, pak OK; nevybírejte všechny řádky a nemačkejte „+“, které použije jeden stav na všechny vybrané řádky, a tak vymaže i formáty, které patří jinému programu, například oficiálnímu 7-Zip.

Přidružení nastavená ve sloupci **Všichni uživatelé** se čištění při odinstalaci vůbec nedotkne a zůstanou ukazovat všechny účty na odebraný program. Správce, který nějaká nastavil, by měl tyto buňky vymazat ze správce souborů spuštěného jako správce, pak OK, před odinstalací; `-RemoveAssociations` tento sloupec nezasáhne. Vymazání těsně před odinstalací je neškodné, i když tam smaže vlastní registraci balíčku (viz výše), protože ji odinstalace stejně odebere. Balíček pro jednoho uživatele problém s ostatními účty nemá a oficiální 7-Zip se chová stejně.

## Jazyky

Každý balíček obsahuje překlady původního projektu, přes 90 jazyků. Vyberte jeden v **Nástroje > Možnosti > Jazyk**; MSI také umožňuje je při nastavení *Custom* vynechat. 7-ZSTar se při prvním spuštění pokusí řídit jazykem systému, ale toto zjišťování to vzdá a zůstane u angličtiny, když se nastavení "language for non-Unicode programs" (jazyk pro programy, které nepodporují Unicode) a „Místní formát“ ve Windows rozcházejí – ruční výběr jazyka funguje vždy.

Řetězce, které 7-ZSTar přidal sám – pole pro úroveň zstd a slovník, názvy nových formátů archivů – nemají překlad původního projektu a zůstávají anglicky. Výjimkou jsou tlačítka **Podpořit** a **Web** v dialogu O programu 7-ZSTar: 67 z 92 jazyků má pro každou položku překlad, ostatních 25 zobrazuje angličtinu (`Lang/UPSTREAM.md` je vyjmenovává). Překlady jsou převzaté, nevznikají zde: viz [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md).
