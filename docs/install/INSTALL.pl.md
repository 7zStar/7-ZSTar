<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# Instalacja 7-ZSTar

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · [한국어](INSTALL.ko.md) · [Italiano](INSTALL.it.md) · **Polski** · [Türkçe](INSTALL.tr.md) · [Nederlands](INSTALL.nl.md) · [Українська](INSTALL.uk.md) · [Bahasa Indonesia](INSTALL.id.md) · [ไทย](INSTALL.th.md) · [Čeština](INSTALL.cs.md) · [Magyar](INSTALL.hu.md) · [Română](INSTALL.ro.md) · [Svenska](INSTALL.sv.md) · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md)

*W razie jakichkolwiek rozbieżności obowiązuje wersja angielska.*

Szczegóły stojące za krótką wersją w [README](../readme/README.pl.md): wymagania systemowe, ostrzeżenie SmartScreen, Inteligentna kontrola aplikacji i sposób sprawdzenia pobranego pliku, trzy pakiety, menu kontekstowe Windows 11, skojarzenia plików i odinstalowywanie.

## Wymagania systemowe

**Windows 7 lub Windows Server 2008 R2, x64 lub x86. Na arm64 – Windows 10.**
Nic więcej nie jest potrzebne: środowisko uruchomieniowe C jest dołączone statycznie (`-MT`), więc pliki binarne importują wyłącznie własne biblioteki DLL systemu Windows – bez pakietów redystrybucyjnych i bez .NET.

Ta dolna granica jest *wyliczona* z tego, czego wymagają pakiety, i została przetestowana na Windows 7 SP1 z zainstalowanymi późniejszymi aktualizacjami (między innymi PowerShell 5.1), na Windows 10 22H2 i na Windows 11, wszystkie w wersji 64-bitowej. W Windows 7 i 10 obejmowało to instalowanie i odinstalowywanie pakietów `.msi` x64 (dla wszystkich użytkowników i dla bieżącego użytkownika), kreator instalacji, plik `.zip` x64, każdy dodany kodek i każdy format tar zapisywany w jednym kroku, menu kontekstowe, skojarzenia plików i plik pomocy, a także działanie `.msi` i `.zip` w wersji x86 w 64-bitowym Windows. Niczego więcej w Windows nie testowano: ani Windows 8 czy 8.1, ani Windows Server, ani 32-bitowego Windows, ani sprzętu arm64, ani Windows 7 bez tych aktualizacji. Ta granica jest też wyższa niż w oryginalnym (upstream) 7-Zip, którego pliki binarne nadal się ładują w Windows XP. Wpływają na nią trzy rzeczy, z których druga jest tą, jakiej nie cofnie żadne ustawienie kompilacji:

- Plik `.msi` deklaruje `InstallerVersion="500"`, a Instalator Windows 5.0 był dostarczany „with Windows Server 2008 R2 and later and Windows 7 and later” ([Microsoft][msi-versions]). Przenośny `.zip` nie korzysta z Instalatora Windows, ale zobacz dwa następne punkty.
- **zstd i fast-lzma2 używają synchronizacji dostępnej dopiero od Windows Vista.** Oba wymuszają `_WIN32_WINNT 0x0600` we własnych nagłówkach i wywołują bezpośrednio `InitializeConditionVariable` / `SleepConditionVariableCS`, więc `7z.dll` i `7za.exe` – dwa pliki binarne z wkompilowanymi kodekami – importują cztery funkcje, których nie ma w Windows XP ani Server 2003. `7z.dll` z upstream nie importuje żadnej z nich.
- Zestaw narzędzi: całość jest budowana w Visual Studio 2022, którego lista obsługiwanych systemów docelowych zaczyna się od Windows 7 – dla Windows Vista i Server 2008 stoi tam „No” ([Microsoft][vs-targeting]). Wersja podsystemu w pliku wynikowym to 6.0 na x64 i x86 oraz 6.2 na arm64, a Windows na arm64 zaczyna się od Windows 10 niezależnie od tego.

Windows Vista i Server 2008 są gdzieś pośrodku: pliki binarne by się załadowały, ale zestaw narzędzi ich nie obsługuje, instalator się tam nie uruchomi, a 7-ZSTar nie jest na nich testowany.

**Linux jest obsługiwany wyłącznie jako kompilacja z wiersza poleceń; macOS nie jest obsługiwany.**
Ten fork buduje natywny `7zz` (program konsolowy `Alone2`) za pomocą gcc, według własnego pliku makefile, który dołącza makefile z upstream i żadnego z nich nie modyfikuje:
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
Został zbudowany i przetestowany wyłącznie na Ubuntu 24.04 z gcc 13.3 (x86-64): kompilacja przebiega bez ostrzeżeń przy flagach z upstream, test dymny z 77 sprawdzeniami przechodzi, a 25 wektorów interoperacyjności utworzonych w Windows i 37 utworzonych w Linuksie daje te same werdykty co w Windows. Dwa pliki należące do forka, których dotknął port, nadal budują się w Windows bez zmian (czysta kompilacja x64, testy dymne i odczyt interoperacyjny przechodzą). Nie ma graficznego interfejsu. Pozostałe cele Linuksa z upstream (`7za`, `7zr`, `7z.so`) nie są obsługiwane: ich listy plików obiektowych dla gcc nie zawierają tego, czego potrzebują zmiany forka w obsługujących formaty modułach z upstream, więc oczekuje się, że nie dadzą się zlinkować. Inne architektury, dystrybucje i kompilatory nie zostały sprawdzone, a macOS nigdy nie był budowany, więc nie można podać żadnego `MACOSX_DEPLOYMENT_TARGET`. Kroki budowania, testy i znane ograniczenia opisano w `build/linux/README.md`; interoperacyjność z narzędziami linuksowymi – w `test/interop/REPORT.md`.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## Niepodpisane pakiety, SmartScreen i Inteligentna kontrola aplikacji

**Instalatory i programy w wydaniu 7-ZSTar nie są podpisane cyfrowo przez urząd certyfikacji**, a ten projekt nie ma certyfikatu do podpisywania kodu. Windows nie może więc ustalić, kto opublikował plik, i przy pierwszym uruchomieniu `.msi` albo programu z `.zip` Microsoft Defender SmartScreen może go zatrzymać z ostrzeżeniem. Dokumentacja Microsoft dla deweloperów wymienia „No signature” jako jeden z przypadków, w których pojawia się ostrzeżenie zatytułowane „System Windows ochronił ten komputer” i użytkownik musi wybrać „Run anyway” (w polskim Windows: „Uruchom mimo to”), zanim aplikacja się uruchomi ([Microsoft][smartscreen-rep]). Zasady przedsiębiorstwa mogą całkowicie usunąć tę możliwość wyboru; na takim komputerze zapytaj osobę, która nim zarządza.

Jedyną rzeczą w wydaniu, która *jest* podpisana, jest mały pakiet umieszczający 7-ZSTar na pierwszym poziomie menu kontekstowego Windows 11, zawarty w `.msi` dla wszystkich użytkowników. Jego certyfikat jest samopodpisany i generowany podczas budowania tego jednego pakietu, więc nie jest podpisem urzędu certyfikacji i nic nie mówi o tym, kto pakiet zbudował; zobacz [menu kontekstowe Windows 11](#menu-kontekstowe-windows-11), aby dowiedzieć się, co robi i jak z niego zrezygnować.

Ostrzeżenie nie jest dowodem, że plik jest zły, a jego brak nie byłby dowodem, że plik jest dobry. To, co możesz sprawdzić samodzielnie, to czy Twoja kopia jest dokładnie tą, która została opublikowana na stronie wydania. Każde wydanie zawiera plik o nazwie `SHA256SUMS`: po jednej linii na pakiet, czyli skrót SHA-256 i nazwa pliku.

1. Pobierz pakiet i `SHA256SUMS` z tej samej strony wydania, do tego samego folderu.
2. Otwórz PowerShell w tym folderze i porównaj. Zastąp nazwę nazwą pobranego pliku:

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True` oznacza, że skróty są identyczne. Aby obejrzeć je samodzielnie, uruchom
   `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi` i znajdź tę samą
   nazwę pliku w `SHA256SUMS`; porównanie nie rozróżnia wielkich i małych liter.
3. Jeśli otrzymasz `False` albo nazwy pliku nie ma w `SHA256SUMS`, nie uruchamiaj go:
   usuń plik i pobierz go ponownie. Jeśli nadal się nie zgadza, zgłoś to, jak opisano w [SECURITY.md](../../SECURITY.md).

`SHA256SUMS` obejmuje tylko pliki wysłane do tego wydania. Samodzielne zbudowanie tego samego tagu daje inne skróty (pakiet menu kontekstowego jest podpisywany nowym certyfikatem przy każdej kompilacji), a kod źródłowy jest publikowany z każdym wydaniem, jeśli wolisz zbudować go samemu: zobacz [build/README.md](../../build/README.md).

Gdy skróty się zgadzają i jesteś zadowolony z pochodzenia pliku:

- **`.msi`** – uruchom go jak zwykle. Jeśli SmartScreen go zatrzyma, wybierz opcję uruchomienia go mimo ostrzeżenia („Uruchom mimo to”; „Run anyway” w angielskojęzycznym Windows). Okno ostrzeżenia może wymagać najpierw rozwinięcia: na testowanym komputerze z Windows 10 oferowało ono tylko przycisk rezygnujący z uruchomienia pliku, dopóki nie kliknięto linku pod komunikatem. `.msi` dla wszystkich użytkowników prosi następnie o zgodę administratora, jak każdy inny instalator.
- **`.zip`** – rozpakuj go i uruchom `7zFM.exe` lub `7z.exe` z folderu. Znajdujące się w nim programy też są niepodpisane, więc Windows może pokazać to samo ostrzeżenie przy pierwszym uruchomieniu każdego z nich.

SmartScreen ostrzega w zależności od tego, jak dobrze znany jest plik, a nie tylko od podpisów; plik pobrany przez niewielu ludzi może wywołać ostrzeżenie nawet wtedy, gdy jest podpisany. Nic tutaj tego nie zmienia i nic w powyższych krokach nie wyłącza SmartScreen.

### Inteligentna kontrola aplikacji w Windows 11

Na niektórych komputerach z Windows 11 jest włączona ostrzejsza ochrona o nazwie **Inteligentna kontrola aplikacji**. Gdy jest włączona, Windows blokuje niepodpisane pliki, chyba że usługa w chmurze Microsoft może za nie poręczyć, a nowe wydanie zwykle nie ma takiego wpisu ([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). W przeciwieństwie do ostrzeżenia SmartScreen blokada nie ma opcji uruchomienia pliku mimo wszystko, a FAQ Microsoft mówi, że nie ma sposobu na obejście Inteligentnej kontroli aplikacji dla pojedynczej aplikacji.

Co się stało, gdy 7-ZSTar 26.05.1 wypróbowano w Windows 11 Pro 25H2 (kompilacja 26200.8037) z włączoną Inteligentną kontrolą aplikacji:

- **Instalatory `.msi` zostały zablokowane**, zarówno ten dla wszystkich użytkowników, jak i ten dla bieżącego użytkownika. W tradycyjnym chińskim Windows Instalator Windows wyświetlił 「系統禁用此安裝。請連絡系統管理員。」, a powiadomienie z aplikacji Zabezpieczenia Windows informowało, że Inteligentna kontrola aplikacji zablokowała plik, ponieważ Windows nie może ustalić, kto go opublikował, i nie jest to aplikacja znana Windows. Nie było opcji kontynuowania, a `msiexec /i ... /qn` zwrócił błąd 1625. Ten komunikat to ciąg 1625 z Instalatora Windows; w angielskojęzycznym Windows ten sam ciąg brzmi „The system administrator has set policies to prevent this installation.” (odczytany z angielskich zasobów Instalatora Windows, a nie widziany na ekranie).
- **Program z `.zip` się uruchomił.** `7zFM.exe`, wypakowany z przenośnego `.zip`, uruchomił się normalnie w tym samym teście. To, czy Windows pozwala uruchomić niepodpisany program, jest jego własną oceną tego pliku, więc na Twoim komputerze może być inaczej.
- Tuż po włączeniu Inteligentnej kontroli aplikacji `.msi` instalował się jeszcze przez kilka minut, zanim zaczął być blokowany. Przyczyny nie ustalono, więc sukces zaraz po jej włączeniu nie oznacza, że instalator jest dozwolony.

Zatem na komputerze, na którym Inteligentna kontrola aplikacji jest włączona, **instalatorów nie da się zainstalować**, a sprawdzenie `SHA256SUMS` tego nie zmienia. Zmienia to wyłączenie Inteligentnej kontroli aplikacji w ustawieniach „Ustawienia funkcji Inteligentna kontrola aplikacji” aplikacji Zabezpieczenia Windows (w testowanym tradycyjnym chińskim Windows: Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定). W teście wybranie opcji wyłączenia zadziałało od razu, bez ponownego uruchamiania, a instalatory się wtedy zainstalowały. To ustawienie dotyczy całego komputera i nic tutaj nie prosi Cię o jego zmianę: decyzja należy do Ciebie, a na komputerze zarządzanym – do administratora.

Warto też wcześniej wiedzieć, czy da się ją z powrotem włączyć. FAQ Microsoft mówi, że ostatnie aktualizacje Windows pozwalają ponownie włączyć Inteligentną kontrolę aplikacji bez czystej instalacji Windows, więc w wersji bez nich jej wyłączenie może być trwałe. W testowanej tutaj kompilacji opcja jej włączenia nadal była oferowana po wyłączeniu; to wynik testu, a nie obietnica dotycząca Twojej wersji.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## Instalowanie

Trzy pakiety, wszystkie budowane przez `installer\Build-Package.ps1` (pakiet dla bieżącego użytkownika z `-PerUser`):

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| Instaluje dla | każdego konta | konta, które instaluje | - |
| Menu kontekstowe Eksploratora plików | tak | tak, tylko menu klasyczne ([poniżej](#pakiet-dla-bieżącego-użytkownika)) | nie |
| Wpis w Menu Start | tak | tak | nie |
| Wymaga administratora | tak | nie | nie |
| Usuwanie | *Zainstalowane aplikacje* w Ustawieniach | *Zainstalowane aplikacje* w Ustawieniach | usunięcie folderu |

*Zainstalowane aplikacje* to nazwa z Windows 11. Windows 10 nazywa tę samą stronę *Aplikacje i funkcje*, a w Windows 7 jest to *Programs and Features* (Programy i funkcje) w Control Panel (Panel sterowania).

Używaj pakietów zgodnych z samym Windows: x86 w 32-bitowym Windows, x64 w 64-bitowym Windows, arm64 w Windows na Arm (pakiety arm64 są budowane, ale nigdy ich nie uruchomiono). Rozszerzenie powłoki x86 jest 32-bitowe, a 64-bitowy Eksplorator plików nie może go załadować, więc w 64-bitowym Windows pakiet x86 `-user.msi` w ogóle nie ma menu kontekstowego, a x86 `.msi` ma je tylko w Windows 11 i tylko dla kont, które zarejestrowały jego pakiet Windows 11 (to, które instalowało, albo takie, które uruchomiło `-Register`, poniżej).

MSI instaluje się w `Program Files\7-ZSTar` – zawsze: w odróżnieniu od pakietu dla bieżącego użytkownika nie oferuje wyboru folderu i ignoruje `INSTALLFOLDER` w wierszu poleceń, ponieważ ten folder zawiera skrypt uruchamiany przez instalator jako SYSTEM oraz bibliotekę DLL ładowaną przez Eksplorator plików każdego użytkownika, a folder utworzony gdzie indziej (na przykład w `C:\`) jest zapisywalny dla każdego użytkownika. Rejestruje własny CLSID rozszerzenia powłoki i własną gałąź rejestru `Software\7-ZSTar`, a każdy klucz menu kontekstowego nazywa `7-ZSTar` – dzięki temu ani nie koliduje z oficjalnym 7-Zip, ani niczego mu nie usuwa. Zobacz [installer/GUIDS.md](../../installer/GUIDS.md).

Uruchamia zwykły kreator instalacji – welcome, licence, setup type, optional feature tree, finish (czyli powitanie, licencja, typ instalacji, drzewo funkcji opcjonalnych, zakończenie) – a cicha instalacja nadal działa bez zmian (`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`), ponieważ msiexec w trybie cichym pomija całą sekwencję interfejsu. Kreator jest wyłącznie po angielsku, także w Windows ustawionym na inny język (widziane w tradycyjnym chińskim Windows 10; `.msi` jest budowany bez innego języka), a na jego stronie końcowej domyślnie zaznaczona jest opcja *Launch 7-ZSTar File Manager* (uruchom menedżer plików 7-ZSTar).

### Menu kontekstowe Windows 11

W Windows 11 wpis znajduje się w menu na pierwszym poziomie, a nie schowany pod *Pokaż więcej opcji*, gdzie nadal są oficjalny 7-Zip i WinRAR. Windows 11 wymienia tam rozszerzenie powłoki tylko wtedy, gdy ma ono tożsamość pakietu, więc MSI dostarcza obok programu mały pakiet MSIX zawierający wyłącznie tożsamość i rejestruje go podczas instalacji. Klasyczna rejestracja jest zachowana również. To ona umieszcza wpis w menu kontekstowym w Windows 10 i Windows 7, których menu ma jeden poziom i nie ma *Pokaż więcej opcji*, i to ona sprawia, że wpis działa u każdego, kto przywrócił stare menu kontekstowe.

Ten pakiet jest podpisany **certyfikatem samopodpisanym**, a instalator umieszcza go w `LocalMachine\TrustedPeople` – Windows nie wdroży pakietu, którego podpisu nie może powiązać z czymś zaufanym. Odinstalowanie usuwa certyfikat razem z pakietem. W Windows 10 i Windows 7 instalator nie robi żadnej z tych rzeczy: nie dodaje certyfikatu i nie rejestruje pakietu, a menu zapewnia sama klasyczna rejestracja.

Jeśli wolisz nie ufać certyfikatowi samopodpisanemu, odrzuć tylko tę część i zachowaj całą resztę:

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

Dostajesz wtedy tylko menu klasyczne, więc w Windows 11 wpis 7-ZSTar jest w menu kontekstowym pod *Pokaż więcej opcji*. Aby włączyć wpis na pierwszym poziomie później albo cofnąć go po zwykłej instalacji:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

Zaufanie temu certyfikatowi oznacza, że Windows przyjmie bez ostrzeżenia także **każdy inny** pakiet podpisany tym samym kluczem. Jest on używany wyłącznie dla tego jednego pakietu, a odinstalowanie wycofuje zaufanie, ale na to się godzisz – a `SPARSE=0` powyżej to sposób, by tego odmówić.

Rejestracja pakietu odbywa się dla każdego użytkownika osobno, a instalator uruchamia ją tylko dla osoby, która instalowała. Z tego wynikają dwie rzeczy:

- Drugie konto na tym samym komputerze dostaje tylko menu klasyczne, dopóki nie uruchomi tego samego skryptu z `-Register`.
- Odinstalowanie wyrejestrowuje pakiet tylko dla osoby, która odinstalowuje. Jeśli ktoś inny go zarejestrował, jego rejestracja przetrwa odinstalowanie i wskazuje na folder, którego już nie ma; to konto usuwa ją poleceniem `Get-AppxPackage 7-ZSTar | Remove-AppxPackage`.

**Znane ograniczenie: menu na pierwszym poziomie jest rejestrowane tylko wtedy, gdy instalacja działa w interaktywnej, zalogowanej sesji.** Zainstalowanie `.msi` dla wszystkich użytkowników z sesji zdalnej lub nieinteraktywnej – przez SSH albo w cichym wdrożeniu z narzędzia do zarządzania – nadal zgłasza sukces, ale pakiet Windows 11 nie jest rejestrowany, więc pojawia się tylko menu klasyczne pod *Pokaż więcej opcji*. W teście `msiexec /i ... /qn` z sesji SSH (sesja 0) zakończył się kodem 0, podczas gdy `Setup-ShellIntegration.ps1` zgłosił `registration failed: 0x80070005` (odmowa dostępu); ten sam `.msi` zainstalowany z sesji konsoli administratora zarejestrował się normalnie.

`-Status` wypisuje, co jest, a czego nie ma na miejscu.

### Pakiet dla bieżącego użytkownika

`7-ZSTar-<version>-<arch>-user.msi` instaluje tylko dla bieżącego konta, w `%LOCALAPPDATA%\Programs\7-ZSTar`, bez monitu UAC. Wszystko, co rejestruje, trafia do `HKCU`; pakiet nie zapisuje niczego w `HKLM` (pomijając własną ewidencję Instalatora Windows). Czego nie robi tak jak pakiet dla całego komputera:

- **Brak menu Windows 11 na pierwszym poziomie.** W Windows 11 7-ZSTar jest w menu kontekstowym pod *Pokaż więcej opcji*. Wpis na pierwszym poziomie wymaga, by samopodpisany certyfikat był zaufany w całym komputerze, a to wymaga administratora: zmierzono w Windows 11, że certyfikat w `CurrentUser\TrustedPeople` nie wystarcza, by Windows wdrożył pakiet. Dlatego pakiet dla bieżącego użytkownika to pomija.
- **Tylko jeden z dwóch na komputer.** Każdy pakiet odmawia instalacji, gdy zainstalowany jest drugi; odinstaluj jeden, zanim zainstalujesz drugi. Pakiet dla całego komputera widzi tylko kopię dla bieżącego użytkownika konta, które go uruchamia, więc instalacja dla bieżącego użytkownika na innym koncie nie jest wykrywana.
- **Zasady grupy mogą ukryć jego menu.** Tam, gdzie ustawiono `EnforceShellExtensionSecurity`, Eksplorator plików ładuje tylko rozszerzenia powłoki wymienione w ogólnokomputerowym kluczu *Approved*, do którego instalacja dla bieżącego użytkownika nie może pisać, więc menu kontekstowe się nie pojawia. Użyj tam pakietu dla całego komputera.
- **Wyczyszczenie formatu w Narzędzia > Opcje > System usuwa także ofertę 7-ZSTar dla niego.** Gdy wyczyścisz tam format (klikaj jego komórkę, aż będzie pusta, potem OK), menedżer plików usuwa w całości klucze `HKCU\Software\Classes\.<ext>` i `7-ZSTar.<ext>` – a w instalacji dla bieżącego użytkownika te klucze zawierają też to, co pakiet zarejestrował dla Ustawienia > Aplikacje > Aplikacje domyślne i dla listy *Otwórz za pomocą*. 7-ZSTar wypada wtedy z *Otwórz za pomocą* dla tego formatu, a Aplikacje domyślne pokazują dla niego pusty wpis. Naprawa instalacji go przywraca (uruchom `.msi` ponownie i wybierz *Repair* – naprawa). Lepiej przypisywać typy plików w Aplikacjach domyślnych niż w menedżerze plików. Pakiet dla całego komputera ma ten sam słaby punkt w jednym miejscu, opisanym niżej w części o skojarzeniach plików.

### Skojarzenia plików i co się z nimi dzieje po odinstalowaniu

**Ustawiaj je w Ustawienia > Aplikacje > Aplikacje domyślne.** W Windows 11 wpisz tam 7-ZSTar, a zobaczysz listę wszystkich formatów, które może otworzyć, do przypisania. W Windows 10 7-ZSTar jest wymieniony pod *Set defaults by app* (ustaw wartości domyślne według aplikacji) na tej stronie, gdzie *Manage* (zarządzaj) pokazuje jego formaty. Windows 7 nie ma aplikacji Ustawienia: 7-ZSTar jest tam wymieniony w Control Panel > Default Programs > *Set your default programs* (Panel sterowania > Programy domyślne > ustawienie programów domyślnych), co w tym przewodniku oznacza tam *Aplikacje domyślne*. Przypisywanie formatów z tych dwóch stron nie było testowane. Instalator rejestruje 7-ZSTar jako aplikację z listy Programy domyślne (Default Programs) – ProgID na każdy format z jego ikoną i poleceniem otwarcia, wpis na liście *Otwórz za pomocą* każdego rozszerzenia oraz blok Capabilities, który czyta Windows – ale celowo nie przejmuje żadnego typu pliku: to, który program otwiera Twoje archiwa, jest Twoją decyzją i dzięki temu 7-ZSTar i oficjalny 7-Zip nie wchodzą sobie w drogę. Windows może mimo to sam skierować format do 7-ZSTar, gdy żaden inny program nie oferuje jego otwarcia: na testowanych komputerach z Windows 10 i Windows 7, gdzie nic innego nie zarejestrowało `.7z`, plik `.7z` pokazywał ikonę 7-ZSTar i otwierał się w nim po dwukrotnym kliknięciu, bez pytania Windows, którego programu użyć.

**Narzędzia > Opcje > System w menedżerze plików w większości nie działa w Windows 11**, a to reguła Windows, a nie tutejszy błąd. Zapisuje ono ProgID `7-ZSTar.<ext>` w `HKCU\Software\Classes`, a dla każdego rozszerzenia, które komputer już zna – a zna każdy format archiwum – Windows 11 to ignoruje: `AssocQueryString` odpowiada `Unknown`, a Eksplorator plików rysuje pustą ikonę ogólną. Honoruje natomiast klucz `UserChoice` opatrzony skrótem, który potrafi obliczyć tylko Windows, dlatego jedyną drogą jest tam interfejs aplikacji Ustawienia. Żadna aplikacja nie może go zapisać: ani 7-ZSTar, ani 7-Zip, ani żaden instalator. W Windows 10 i Windows 7 w testach było inaczej: gdy `.7z` i `.zst` ustawiono w menedżerze plików, a żaden inny program nie był dla nich wybrany, `AssocQueryString` zwrócił dla obu `7zFM.exe`.

**Wyczyszczenie formatu w jego kolumnie *Wszyscy użytkownicy* usuwa własną rejestrację pakietu dla całego komputera dla tego formatu.** Ta kolumna zapisuje w `HKLM\Software\Classes`, gdzie pakiet dla całego komputera trzyma ProgID-y i wpisy *Otwórz za pomocą*, które reklamuje, a wyczyszczenie tam formatu (wymaga to menedżera plików uruchomionego za pomocą polecenia *Uruchom jako administrator*) usuwa te klucze w całości – dla każdego konta. Naprawa przywróciła te same klucze w pakiecie dla bieżącego użytkownika; w tym pakiecie nie zmierzono tego.

**Ikona, która pozostaje pusta po zmianie czegokolwiek**, może też pochodzić z pamięci podręcznej ikon Eksploratora plików, która nie zauważa, że DLL, który już zapamiętała, został zastąpiony; `ie4uinit.exe -show` nie czyści jej niezawodnie. Zamknij Eksplorator plików, usuń `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db` i uruchom go ponownie.

**Odinstalowanie usuwa skojarzenia, do których ma dostęp** – ProgID-y `7-ZSTar.*` należące do osoby odinstalowującej i tylko te typy plików, które nadal na nie wskazują, więc format przekazany w międzyczasie innemu programowi zostaje nietknięty. Odinstalowanie pakietu dla całego komputera pomija też ProgID, który otwiera inną, nadal istniejącą kopię 7-ZSTar – przenośną z `.zip`, skonfigurowaną własnym **Narzędzia > Opcje > System** tej kopii. Pakiet dla bieżącego użytkownika tego nie potrafi: jego ProgID-y to te same klucze `HKCU` (zobacz *Pakiet dla bieżącego użytkownika* powyżej), a odinstalowanie usuwa je niezależnie od tego, kto zapisał je ostatni. Zostawienie ich oznaczałoby, że te typy wskazują na ProgID, którego ikoną i poleceniem jest usunięty plik wykonywalny, czyli pustą ikonę i błąd po dwukrotnym kliknięciu. Skojarzenia innych kont są poza zasięgiem; mogą one wyczyścić własne poleceniem `Setup-ShellIntegration.ps1 -RemoveAssociations`, zanim program zniknie. `msiexec /x ... KEEPASSOC=1` to pomija, a aktualizacja nigdy tego nie robi.

**Znane ograniczenie: inne konta zachowują skojarzenia, które same ustawiły.**
Odinstalowanie pakietu dla całego komputera czyści tylko to, co konto uruchamiające odinstalowanie ustawiło we własnej kolumnie (z nagłówkiem w postaci nazwy konta) w **Narzędzia > Opcje > System** w menedżerze plików. Każde inne konto, które tam ustawiło skojarzenia, zachowuje je, wskazujące na usunięty program, więc dwukrotne kliknięcie pliku `.7z` pyta Windows, którego programu użyć. Każde konto powinno wyczyścić własne **przed** odinstalowaniem, poleceniem

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

które usuwa tylko wpisy 7-ZSTar, albo po nim przypisać typy ponownie w Ustawienia > Aplikacje > Aplikacje domyślne. Zrobienie tego w menedżerze plików oznacza kliknięcie każdej komórki we własnej kolumnie, która pokazuje 7-ZSTar, aż będzie pusta, a potem OK; nie zaznaczaj wszystkich wierszy i nie naciskaj „+”, bo to stosuje jeden stan do każdego zaznaczonego wiersza, a więc czyści także formaty należące do innego programu, takiego jak oficjalny 7-Zip.

Skojarzenia ustawione w kolumnie **Wszyscy użytkownicy** nie są w ogóle ruszane przez porządki po odinstalowaniu i pozostają wskazujące każde konto na usunięty program. Administrator, który jakieś ustawił, powinien wyczyścić te komórki, w menedżerze plików uruchomionym za pomocą polecenia *Uruchom jako administrator*, potem OK, przed odinstalowaniem; `-RemoveAssociations` nie sięga tej kolumny. Wyczyszczenie jej tuż przed odinstalowaniem jest nieszkodliwe, choć usuwa tam własną rejestrację pakietu (powyżej), bo odinstalowanie i tak ją usuwa. Pakiet dla bieżącego użytkownika nie ma problemu z innymi kontami, a oficjalny 7-Zip zachowuje się tak samo.

## Języki

Każdy pakiet zawiera tłumaczenia z upstream, ponad 90 języków. Wybierz jeden w **Narzędzia > Opcje > Język**; MSI pozwala też je pominąć w instalacji *Custom*. 7-ZSTar próbuje przy pierwszym uruchomieniu podążać za językiem systemu, ale to wykrywanie poddaje się i zostaje przy angielskim, gdy ustawienia Windows „language for non-Unicode programs” (język programów nieobsługujących standardu Unicode) i „Format regionalny” się różnią – ręczny wybór języka zawsze działa.

Ciągi, które 7-ZSTar dodał sam – pola poziomu i słownika zstd, nazwy nowych formatów archiwów – nie mają tłumaczenia z upstream i pozostają po angielsku. Wyjątkiem są przyciski **Wesprzyj** i **Strona WWW** w oknie „7-ZSTar - informacje”: 67 z 92 języków ma własne tłumaczenie każdego z nich, pozostałe 25 pokazuje angielski (`Lang/UPSTREAM.md` je wymienia).
Tłumaczenia są przejęte z upstream, a nie pisane tutaj: zobacz [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md).
