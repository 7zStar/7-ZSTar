<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [Русский](README.ru.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · **Română** · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

*Dacă există diferențe față de versiunea în limba engleză, este valabilă versiunea în limba engleză.*

**Un fork al 7-Zip mai prietenos cu utilizatorii moderni de Windows 11: meniu contextual de prim nivel, comprimare zstd și tar.zst într-o singură trecere.**

[Descărcare](https://github.com/7zStar/7-ZSTar/releases/latest) · [Site web](https://www.7zstar.com) · [Jurnal de modificări](../../CHANGELOG.md)

## De ce 7-ZSTar

- **Fără „Afișați mai multe opțiuni”.** În Windows 11, 7-ZSTar se află chiar pe primul nivel al meniului contextual.
- **tar.zst dintr-un singur pas.** Comprimați un folder în .tar.zst sau extrageți unul dintr-un singur pas, fără ca vreun .tar să rămână pe disc. 7-Zip oficial nu poate crea .tar.zst și îl extrage în doi pași, printr-un .tar.
- **De aproximativ 10 ori mai rapid decât 7z.** Pe foldere reale de proiecte, tar.zst s-a comprimat de 10 până la 18 ori mai repede.

## Viteză

| Folder | Fișiere | Dimensiune inițială | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 s / 76.7 MB | 38.4 s / 51.8 MB | **3.8 s** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 s / 107.8 MB | 54.8 s / 65.7 MB | **3.6 s** / 83.4 MB |
| Python `.venv` (fișiere binare mari) | 11,654 | 671 MB | 25.5 s / 249.5 MB | 100.8 s / 167.2 MB | **5.6 s** / 210.9 MB |

Arhivele tar.zst au ieșit cu 15 până la 23% mai mici decât cele zip, fără să dureze mai mult. 7z face în continuare cele mai mici fișiere (tar.zst a fost cu 15 până la 27% mai mare), dar a durat mult mai mult. Extragerea a durat aproximativ la fel cu toate trei.

Setările implicite pentru toate trei; 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, NVMe SSD, mediana a 3 rulări, 2026-11.

## Formate

- **Comprimare într-o singură trecere:** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Extragere dintr-un singur pas:** toate cele de mai sus, plus tar.lzma și tar.Z
- **Codecuri adăugate:** zstd, brotli, lz4, lz5 și lizard (de sine stătătoare sau în interiorul unui .7z), plus fast-lzma2, un encoder LZMA2 alternativ
- Toate formatele pe care le gestionează 7-Zip oficial funcționează în continuare.

## Descărcare

Majoritatea utilizatorilor vor fișierul `.msi` x64 pentru toți utilizatorii, de pe pagina [Releases](https://github.com/7zStar/7-ZSTar/releases/latest).

| | `.msi` pentru toți utilizatorii | `-user.msi` doar pentru dvs. | `.zip` portabil |
|---|---|---|---|
| Necesită drepturi de Administrator | Da | Nu | Nu |
| Meniul contextual | Primul nivel în Windows 11 | Meniul clasic (în Windows 11, sub „Afișați mai multe opțiuni”) | Niciunul |
| Intrare în Meniul Start | Da | Da | Nu |

Fiecare există și pentru x86 și arm64; alegeți-l pe cel care corespunde versiunii dvs. de Windows. În Windows pe 64 de biți, este posibil ca pachetele x86 să nu aibă meniu contextual, iar variantele arm64 nu au fost încă încercate pe hardware real. 7-ZSTar se instalează alături de 7-Zip oficial, fără să îl afecteze.

**Este posibil ca Windows să vă avertizeze prima dată.** Fișierele nu sunt semnate digital, așa că SmartScreen le poate opri („Windows v-a protejat computerul”; poate fi nevoie să extindeți avertismentul ca să vedeți „Executați oricum”), iar în Windows 11 cu Controlul inteligent al aplicațiilor activat, `.msi`-ul este blocat complet. Fiecare versiune are un fișier `SHA256SUMS` cu care vă puteți verifica descărcarea. [Ghidul de instalare](../install/INSTALL.ro.md#pachete-nesemnate-smartscreen-și-controlul-inteligent-al-aplicațiilor) explică cum, și ce puteți face în legătură cu Controlul inteligent al aplicațiilor.

**Despre meniul de prim nivel:** în Windows 11, `.msi`-ul pentru toți utilizatorii adaugă un pachet mic, semnat cu un certificat autosemnat, și acordă încredere acelui certificat; asta cere Windows pentru primul nivel. Dezinstalarea le elimină pe amândouă. Dacă preferați să nu, instalați cu `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`. Pachetul este înregistrat pentru contul care rulează programul de instalare; celelalte conturi îl înregistrează separat.

Asocierile de fișiere, dezinstalarea și pachetul pe utilizator sunt descrise în [ghidul de instalare](../install/INSTALL.ro.md).

## Linia de comandă

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

În PowerShell, puneți opțiunea între ghilimele: `7z a "-ttar.zst" backup.tar.zst docs`. Fără ele, PowerShell o desparte în două și obțineți un fișier numit `.zst`. Aplicația Linie de comandă (cmd) nu are nevoie de ghilimele.

## Bine de știut

- **Dezactivarea opțiunii „Integrează 7-ZSTar în meniul contextual”** (în managerul de fișiere, **Unelte > Opţiuni... > 7-ZSTar**) elimină intrarea din meniul contextual, ca în 7-Zip oficial. Cu pachetul pentru toți utilizatorii, o reactivați pornind managerul de fișiere cu „Executare ca administrator”. Cu pachetul pe utilizator nu se poate („Access is denied.”); rulați din nou `.msi`-ul și alegeți *Repair* (reparare).
- **Instalările silențioase sau de la distanță în Windows 11** (prin SSH sau dintr-o unealtă de distribuire) reușesc, dar intrarea de prim nivel nu este înregistrată, așa că 7-ZSTar apare doar sub „Afișați mai multe opțiuni”. [Mai multe în ghidul de instalare](../install/INSTALL.ro.md#meniul-contextual-din-windows-11).
- **Extragerea unui fișier tar.br, tar.lz4, tar.lz5, tar.liz sau tar.Z** rămâne un singur pas pentru dvs., dar trece printr-un fișier temporar, care este șters după aceea.

## Cerințe de sistem

Windows 7 / Server 2008 R2 sau mai nou (x64, x86), ori Windows 10 sau mai nou pe arm64. Nu este nevoie să instalați nimic altceva. Testat pe Windows 7 SP1 pe 64 de biți (cu actualizările ulterioare instalate), pe Windows 10 și pe Windows 11; [ce s-a testat](../install/INSTALL.ro.md#cerințe-de-sistem). Pe Linux există o versiune pentru linia de comandă pe care o compilați singur; macOS nu este acceptat.

## Documentație

**Ajutor > Conţinut...** și F1 deschid `7-zip.chm`, fișierul de ajutor al 7-Zip oficial. Acesta spune „7-Zip” peste tot și nu acoperă ce adaugă 7-ZSTar; acestea le găsiți în această pagină și în [jurnalul de modificări](../../CHANGELOG.md). Dacă fișierul de ajutor lipsește, aceleași intrări deschid online această secțiune.

Pentru a compila singur 7-ZSTar, vedeți [build/README.md](../../build/README.md); înainte de a îmbina o versiune nouă din upstream, citiți [MAINTAINING.md](../../MAINTAINING.md).

<a id="donate"></a>

## Donații

7-ZSTar este gratuit, indiferent dacă donați sau nu. Dacă v-a economisit timp și doriți să mulțumiți, puteți trimite criptomonede la adresa de mai jos. Banii ajung la mine, DraftingDreamer, pentru propriile costuri de dezvoltare și nu cumpără funcții, asistență sau vreo promisiune privind ce urmează.

Este binevenit orice token de pe Ethereum sau Polygon: ETH, POL, USDT, USDC sau altceva. Adresa este aceeași pe ambele rețele.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="Codul QR al adresei de donații">

- Se acceptă doar transferuri pe Ethereum (ERC20) și Polygon. Dacă le puteți folosi pe amândouă, Polygon are de obicei comisioane mai mici.
- Aceasta este singura adresă oficială și nu vă voi cere niciodată să trimiteți la alta.
- Transferurile nu pot fi anulate, deci nu pot fi rambursate.

Mă ajută și dacă dați o stea 7-ZSTar pe GitHub sau îl recomandați unui prieten.

## Licență

LGPL v3, vedeți [LICENSE](../../LICENSE). Unele părți au alți termeni: decomprimarea RAR este supusă restricției unRAR, așa că o versiune cu suport RAR nu este strict LGPL v3. Lista completă se află în [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md), iar notificările privind drepturile de autor în [NOTICE](../../NOTICE).

Mulțumim tuturor celor care și-au dăruit timpul pentru 7-Zip, pentru algoritmii de comprimare și pentru open source în general. Fără voi, 7-ZSTar nu ar exista.
