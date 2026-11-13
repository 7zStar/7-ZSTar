<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · **Polski** · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

*W razie jakichkolwiek rozbieżności obowiązuje wersja angielska.*

**Fork 7-Zip przyjaźniejszy dla użytkowników nowoczesnego Windows 11: polecenia na pierwszym poziomie menu kontekstowego, kompresja zstd i tar.zst w jednym przebiegu.**

[Pobierz](https://github.com/7zStar/7-ZSTar/releases/latest) · [Strona WWW](https://www.7zstar.com) · [Lista zmian](../../CHANGELOG.md)

## Dlaczego 7-ZSTar

- **Koniec z „Pokaż więcej opcji”.** W Windows 11 7-ZSTar jest od razu na pierwszym poziomie menu kontekstowego.
- **tar.zst w jednym kroku.** Skompresowanie folderu do .tar.zst albo rozpakowanie takiego pliku to jeden krok, bez pliku .tar zostającego na dysku. Oficjalny 7-Zip nie potrafi utworzyć .tar.zst, a rozpakowuje go w dwóch krokach, przez .tar.
- **Około 10× szybciej niż 7z.** Na prawdziwych folderach projektów tar.zst kompresował się od 10 do 18 razy szybciej.

## Szybkość

| Folder | Pliki | Rozmiar oryginalny | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 s / 76.7 MB | 38.4 s / 51.8 MB | **3.8 s** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 s / 107.8 MB | 54.8 s / 65.7 MB | **3.6 s** / 83.4 MB |
| Python `.venv` (duże pliki binarne) | 11,654 | 671 MB | 25.5 s / 249.5 MB | 100.8 s / 167.2 MB | **5.6 s** / 210.9 MB |

tar.zst wyszedł o 15–23% mniejszy niż zip i nie był wolniejszy. 7z nadal tworzy najmniejsze pliki (tar.zst był o 15–27% większy), ale trwało to znacznie dłużej. Rozpakowywanie trwało mniej więcej tyle samo we wszystkich trzech formatach.

Ustawienia domyślne we wszystkich trzech; 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, dysk NVMe SSD, mediana z 3 uruchomień, 2026-11.

## Formaty

- **Kompresja w jednym kroku:** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Rozpakowywanie w jednym kroku:** wszystkie powyższe oraz tar.lzma i tar.Z
- **Dodane kodeki:** zstd, brotli, lz4, lz5 i lizard (osobno albo wewnątrz .7z) oraz fast-lzma2, alternatywny koder LZMA2
- Każdy format obsługiwany przez oficjalny 7-Zip nadal działa.

## Pobieranie

Większość osób potrzebuje pliku `.msi` x64 dla wszystkich użytkowników z [Wydania](https://github.com/7zStar/7-ZSTar/releases/latest).

| | Dla wszystkich użytkowników `.msi` | Tylko dla Ciebie `-user.msi` | Przenośny `.zip` |
|---|---|---|---|
| Wymaga uprawnień administratora | Tak | Nie | Nie |
| Menu kontekstowe | Pierwszy poziom w Windows 11 | Menu klasyczne (w Windows 11 pod „Pokaż więcej opcji”) | Brak |
| Wpis w Start menu (menu Start) | Tak | Tak | Nie |

Każdy z nich jest dostępny także dla x86 i arm64; wybierz ten, który pasuje do Twojego Windows. W 64-bitowym Windows pakiety x86 mogą nie mieć menu kontekstowego, a wersji arm64 nie wypróbowano jeszcze na prawdziwym sprzęcie. 7-ZSTar instaluje się obok oficjalnego 7-Zip i nie wpływa na jego działanie.

**Windows może ostrzec Cię przy pierwszym uruchomieniu.** Pliki nie mają podpisu cyfrowego, więc SmartScreen może je zatrzymać („System Windows ochronił ten komputer”; aby zobaczyć *Uruchom mimo to*, może być trzeba rozwinąć ostrzeżenie), a w Windows 11 z włączoną funkcją Inteligentna kontrola aplikacji plik `.msi` jest blokowany całkowicie. Każde wydanie zawiera plik `SHA256SUMS`, z którym możesz porównać pobrany plik. [Instrukcja instalacji](../install/INSTALL.pl.md#niepodpisane-pakiety-smartscreen-i-inteligentna-kontrola-aplikacji) wyjaśnia, jak to zrobić i co zrobić w sprawie Inteligentnej kontroli aplikacji.

**O menu na pierwszym poziomie:** w Windows 11 `.msi` dla wszystkich użytkowników dodaje mały pakiet podpisany certyfikatem z podpisem własnym i uznaje ten certyfikat za zaufany; tego właśnie wymaga Windows dla pierwszego poziomu. Odinstalowanie usuwa oba. Jeśli wolisz tego uniknąć, zainstaluj za pomocą `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`. Pakiet jest rejestrowany dla konta, które uruchamia instalator; pozostałe konta rejestrują go osobno.

Skojarzenia plików, odinstalowywanie i pakiet dla bieżącego użytkownika opisuje [instrukcja instalacji](../install/INSTALL.pl.md).

## Wiersz poleceń

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

W PowerShellu ujmij przełącznik w cudzysłów: `7z a "-ttar.zst" backup.tar.zst docs`. Bez nich PowerShell dzieli go na dwie części i powstaje plik o nazwie `.zst`. Command Prompt (cmd) (wiersz polecenia) nie wymaga cudzysłowu.

## Warto wiedzieć

- **Wyłączenie opcji „Zintegruj program 7-ZSTar z menu kontekstowym powłoki”** (menedżer plików, **Narzędzia > Opcje > 7-ZSTar**) usuwa wpis z menu kontekstowego, tak jak w oficjalnym 7-Zip. W pakiecie dla wszystkich użytkowników włączysz ją z powrotem, uruchamiając menedżer plików w trybie *run as administrator* (jako administrator). W pakiecie dla bieżącego użytkownika nie da się tego zrobić („Odmowa dostępu.”); uruchom `.msi` jeszcze raz i wybierz *Repair* (napraw).
- **Ciche lub zdalne instalacje w Windows 11** (przez SSH albo z narzędzia do wdrażania) kończą się powodzeniem, ale wpis na pierwszym poziomie nie jest rejestrowany, więc 7-ZSTar pojawia się tylko pod „Pokaż więcej opcji”. [Więcej w instrukcji instalacji](../install/INSTALL.pl.md#menu-kontekstowe-windows-11).
- **Rozpakowywanie tar.br, tar.lz4, tar.lz5, tar.liz lub tar.Z** dla Ciebie nadal jest jednym krokiem, ale przechodzi przez plik tymczasowy, który potem jest usuwany.

## Wymagania systemowe

Windows 7 / Server 2008 R2 lub nowszy (x64, x86) albo Windows 10 lub nowszy na arm64. Nic więcej nie trzeba instalować. Przetestowano w 64-bitowych Windows 7 SP1 (z zainstalowanymi późniejszymi aktualizacjami), Windows 10 i Windows 11; [co przetestowano](../install/INSTALL.pl.md#wymagania-systemowe). W Linuksie jest wersja wiersza poleceń, którą trzeba skompilować samodzielnie; macOS nie jest obsługiwany.

## Dokumentacja

**Pomoc > Zawartość** i F1 otwierają `7-zip.chm`, plik pomocy oficjalnego 7-Zip. Wszędzie jest w nim mowa o „7-Zip” i nie obejmuje on tego, co dodaje 7-ZSTar; opisują to ta strona i [lista zmian](../../CHANGELOG.md). Jeśli pliku pomocy brakuje, te same pozycje otwierają ten fragment online.

Aby samodzielnie zbudować 7-ZSTar, zobacz [build/README.md](../../build/README.md); przed scaleniem nowego wydania upstream przeczytaj [MAINTAINING.md](../../MAINTAINING.md).

<a id="donate"></a>

## Wesprzyj

Z 7-ZSTar można korzystać za darmo, niezależnie od tego, czy coś wpłacisz. Jeśli oszczędził Ci trochę czasu i chcesz podziękować, możesz wysłać kryptowaluty na poniższy adres. Trafią do mnie, DraftingDreamer, na moje własne koszty tworzenia programu i nie kupują funkcji, pomocy ani obietnic dotyczących tego, co dalej.

Przyjmuję dowolny token w sieci Ethereum lub Polygon: ETH, POL, USDT, USDC albo inny. Adres jest taki sam w obu sieciach.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="Kod QR adresu do wpłat">

- Przyjmowane są tylko przelewy w sieciach Ethereum (ERC20) i Polygon. Jeśli możesz użyć obu, w Polygon opłaty są zwykle niższe.
- To jedyny oficjalny adres i nigdy nie poproszę o wysłanie środków na inny.
- Transakcji w sieci nie można cofnąć, więc nie da się ich zwrócić.

Gwiazdka dla 7-ZSTar na GitHubie albo polecenie go znajomemu też pomaga.

## Licencja

LGPL v3, zob. [LICENSE](../../LICENSE). Niektóre części mają inne warunki: rozpakowywanie RAR podlega ograniczeniu unRAR, więc kompilacja z obsługą RAR nie jest wyłącznie na licencji LGPL v3. Pełna lista znajduje się w [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md), a informacje o prawach autorskich w [NOTICE](../../NOTICE).

Dziękuję wszystkim, którzy poświęcili swój czas 7-Zip, algorytmom kompresji i otwartemu oprogramowaniu w ogóle. Bez Was 7-ZSTar by nie powstał.
