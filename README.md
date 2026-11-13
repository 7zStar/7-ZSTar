<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/logo/wordmark-dark@3x.png">
  <img src="docs/logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

**English** · [繁體中文](docs/readme/README.zh-Hant.md) · [简体中文](docs/readme/README.zh-Hans.md) · [Deutsch](docs/readme/README.de.md) · [Français](docs/readme/README.fr.md) · [Español](docs/readme/README.es.md) · [Português (Brasil)](docs/readme/README.pt-BR.md) · [日本語](docs/readme/README.ja.md) · [Tiếng Việt](docs/readme/README.vi.md) · [Русский](docs/readme/README.ru.md) · [한국어](docs/readme/README.ko.md) · [Italiano](docs/readme/README.it.md) · [Polski](docs/readme/README.pl.md) · [Türkçe](docs/readme/README.tr.md) · [Nederlands](docs/readme/README.nl.md) · [Українська](docs/readme/README.uk.md) · [Bahasa Indonesia](docs/readme/README.id.md) · [ไทย](docs/readme/README.th.md) · [Čeština](docs/readme/README.cs.md) · [Magyar](docs/readme/README.hu.md) · [Română](docs/readme/README.ro.md) · [Svenska](docs/readme/README.sv.md) · [Ελληνικά](docs/readme/README.el.md) · [हिन्दी](docs/readme/README.hi.md) · [العربية](docs/readme/README.ar.md) · [فارسی](docs/readme/README.fa.md) · [עברית](docs/readme/README.he.md) · [Esperanto](docs/readme/README.eo.md)

**A 7-Zip fork that's friendlier to modern Windows 11 users: a first-level right-click menu, zstd compression, and one-pass tar.zst.**

[Download](https://github.com/7zStar/7-ZSTar/releases/latest) · [Website](https://www.7zstar.com) · [Changelog](CHANGELOG.md)

## Why 7-ZSTar

- **No more “Show more options”.** On Windows 11, 7-ZSTar is right on the first level of the right-click menu.
- **tar.zst in one step.** Compress a folder to .tar.zst, or extract one, in a single step, with no .tar left on disk. Official 7-Zip can't create .tar.zst, and extracts one in two steps, through a .tar.
- **About 10× faster than 7z.** On real project folders, tar.zst compressed 10 to 18 times faster.

## Speed

| Folder | Files | Raw size | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 s / 76.7 MB | 38.4 s / 51.8 MB | **3.8 s** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 s / 107.8 MB | 54.8 s / 65.7 MB | **3.6 s** / 83.4 MB |
| Python `.venv` (large binaries) | 11,654 | 671 MB | 25.5 s / 249.5 MB | 100.8 s / 167.2 MB | **5.6 s** / 210.9 MB |

tar.zst came out 15 to 23% smaller than zip, and no slower. 7z still makes the smallest files (tar.zst was 15 to 27% larger), but it took far longer. Extracting took about the same time with all three.

Default settings for all three; 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, NVMe SSD, median of 3 runs, 2026-11.

## Formats

- **Compress in one step:** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Extract in one step:** all of those, plus tar.lzma and tar.Z
- **Added codecs:** zstd, brotli, lz4, lz5 and lizard (on their own or inside .7z), plus fast-lzma2, an alternative LZMA2 encoder
- Every format official 7-Zip handles still works.

## Download

Most people want the all-users x64 `.msi` from [Releases](https://github.com/7zStar/7-ZSTar/releases/latest).

| | All users `.msi` | Just you `-user.msi` | Portable `.zip` |
|---|---|---|---|
| Needs administrator rights | Yes | No | No |
| Right-click menu | First level on Windows 11 | Classic menu (under “Show more options” on Windows 11) | None |
| Start menu entry | Yes | Yes | No |

Each also comes for x86 and arm64; pick the one that matches your Windows. On 64-bit Windows the x86 packages may have no right-click menu, and the arm64 builds haven't been tried on real hardware yet. 7-ZSTar installs alongside official 7-Zip without affecting it.

**Windows may warn you the first time.** The files aren't code-signed, so SmartScreen may stop them ("Windows protected your PC"; you may need to expand the warning to see *Run anyway*), and on Windows 11 with Smart App Control turned on, the `.msi` is blocked outright. Every release has a `SHA256SUMS` file to check your download against. [INSTALL.md](docs/INSTALL.md#unsigned-packages-smartscreen-and-smart-app-control) explains how, and what to do about Smart App Control.

**About the first-level menu:** on Windows 11, the all-users `.msi` adds a small package signed with a self-signed certificate and trusts that certificate; that is what Windows requires for the first level. Uninstalling removes both. If you'd rather not, install with `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`. The package is registered for the account that runs the installer; other accounts register it separately.

File associations, uninstalling and the per-user package are covered in [INSTALL.md](docs/INSTALL.md).

## Command line

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

In PowerShell, put the switch in quotes: `7z a "-ttar.zst" backup.tar.zst docs`. Without them PowerShell splits it in two and you get a file named `.zst`. Command Prompt (cmd) needs no quotes.

## Good to know

- **Turning off “Integrate 7-ZSTar to shell context menu”** (file manager, **Tools > Options > 7-ZSTar**) removes the right-click entry, as in official 7-Zip. With the all-users package, turn it back on by running the file manager as administrator. With the per-user package you can't ("Access is denied"); run the `.msi` again and choose *Repair*.
- **Silent or remote installs on Windows 11** (over SSH, or from a deployment tool) succeed, but the first-level entry isn't registered, so 7-ZSTar shows up only under “Show more options”. [More in INSTALL.md](docs/INSTALL.md#the-windows-11-right-click-menu).
- **Extracting tar.br, tar.lz4, tar.lz5, tar.liz or tar.Z** is still one step for you, but goes through a temporary file that is deleted afterwards.

## System requirements

Windows 7 / Server 2008 R2 or later (x64, x86), or Windows 10 or later on arm64. Nothing else to install. Tested on 64-bit Windows 7 SP1 (with later updates installed), Windows 10 and Windows 11; [what was tested](docs/INSTALL.md#system-requirements). On Linux there's a command-line build you compile yourself; macOS isn't supported.

## Documentation

**Help > Contents** and F1 open `7-zip.chm`, official 7-Zip's help file. It says “7-Zip” throughout and doesn't cover what 7-ZSTar adds; this page and the [changelog](CHANGELOG.md) do. If the help file is missing, the same entries open this section online.

To build 7-ZSTar yourself, see [build/README.md](build/README.md); before merging a new upstream release, read [MAINTAINING.md](MAINTAINING.md).

<a id="donate"></a>

## Donate

7-ZSTar is free to use, whether you chip in or not. If it has saved you some time and you'd like to say thanks, you can send crypto to the address below. It goes to me, DraftingDreamer, for my own development costs, and doesn't buy features, help, or any promise about what comes next.

Any token on Ethereum or Polygon is welcome: ETH, POL, USDT, USDC or anything else. It's the same address on both networks.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="docs/donate-qr.png" width="200" alt="QR code of the donation address">

- Only transfers on Ethereum (ERC20) and Polygon are accepted. If you can use either, Polygon usually has lower fees.
- This is the only official address, and I'll never ask you to send to a different one.
- Transfers can't be reversed, so they can't be refunded.

Starring 7-ZSTar on GitHub or telling a friend helps too.

## License

LGPL v3, see [LICENSE](LICENSE). Some parts come with other terms: RAR decompression carries the unRAR restriction, so a build with RAR support isn't purely LGPL v3. The full list is in [LICENSE-EXCEPTIONS.md](LICENSE-EXCEPTIONS.md), and the copyright notices are in [NOTICE](NOTICE).

Thank you to everyone who has given their time to 7-Zip, to compression algorithms, and to open source at large. 7-ZSTar wouldn't exist without you.
