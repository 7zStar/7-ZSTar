<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/logo/wordmark-dark@3x.png">
  <img src="docs/logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

**English** · [繁體中文](docs/readme/README.zh-Hant.md) · [简体中文](docs/readme/README.zh-Hans.md) · [Deutsch](docs/readme/README.de.md) · [Français](docs/readme/README.fr.md) · [Español](docs/readme/README.es.md) · [Português (Brasil)](docs/readme/README.pt-BR.md) · [日本語](docs/readme/README.ja.md) · [Tiếng Việt](docs/readme/README.vi.md) · [한국어](docs/readme/README.ko.md) · [العربية](docs/readme/README.ar.md) · [Esperanto](docs/readme/README.eo.md)

**A 7-Zip fork that's friendlier to modern Windows 11 users: a first-level right-click menu, zstd compression, and one-pass tar.zst.**

[Download](https://github.com/7zStar/7-ZSTar/releases/latest) · [Website](https://www.7zstar.com) · [Changelog](CHANGELOG.md)

## Why 7-ZSTar

- **Skip “Show more options”.** Install the all-users MSI and 7-ZSTar sits on the first level of the Windows 11 right-click menu.
- **One pass. No .tar on disk.** Compressing to tar.zst and extracting it are each a single step, with no .tar written either way. Official 7-Zip can't create a .tar.zst, and it extracts one in two steps, through a .tar.
- **10× faster than 7z.** On real project folders, tar.zst compressed 10 to 18 times faster than 7z.

## Speed

| Folder | Files | Raw size | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 s / 76.7 MB | 38.4 s / 51.8 MB | **3.8 s** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 s / 107.8 MB | 54.8 s / 65.7 MB | **3.6 s** / 83.4 MB |
| Python `.venv` (large binaries) | 11,654 | 671 MB | 25.5 s / 249.5 MB | 100.8 s / 167.2 MB | **5.6 s** / 210.9 MB |

tar.zst came out 15 to 23% smaller than zip, and no slower. It's 15 to 27% larger than 7z, though, so if the smallest file matters most, 7z is still the one to pick. These numbers are for compression; extraction took about the same time with all three.

zip, 7z and tar.zst all at default settings. 7-ZSTar 26.05.1 x64 (7z.exe), one machine (Intel Core Ultra 7 155H, NVMe SSD), three real project folders, median of 3 runs, 2026-11.

## Formats

- **One-step compression (8):** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **One-step extraction (10):** those 8, plus tar.lzma and tar.Z
- **Added codecs:** zstd, brotli, lz4, lz5 and lizard, each as a standalone format and as a method inside .7z, plus fast-lzma2 as an alternative LZMA2 encoder.
- Every format 7-Zip already supports is still here.

Extracting tar.br, tar.lz4, tar.lz5, tar.liz or tar.Z is still one step for you, but 7-ZSTar decodes to a temporary file first and deletes it afterwards.

## Command line

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

In PowerShell, put the format switch in quotes, as in `7z a "-ttar.zst" backup.tar.zst docs`. Without them PowerShell splits `-ttar.zst` in two and 7z creates a file named `.zst`. Command Prompt (cmd) needs no quotes.

## Download and install

| | All users `.msi` | Just you `-user.msi` | Portable `.zip` |
|---|---|---|---|
| Installs for | Every account on the PC | The current account | No install needed |
| Requires administrator rights | Yes | No | No |
| Right-click menu | Windows 11 first level | Under “Show more options” | None |
| Start menu entry | Yes | Yes | No |

Each comes in x64, x86 and arm64; pick the one that matches your Windows: on 64-bit Windows, the x86 packages may have no right-click menu. The arm64 builds haven't been run on real hardware yet. 7-ZSTar installs alongside official 7-Zip, and neither affects the other.

**Windows may warn about these downloads.** The installers and programs aren't code-signed by a certificate authority, so Microsoft Defender SmartScreen may stop them with a warning the first time you run one, and on a Windows 11 PC with Smart App Control turned on the `.msi` installers are blocked outright, with no option to continue. That doesn't mean the file is bad: every release comes with a `SHA256SUMS` file, and you can check that your download matches what was published. How to check it, what Smart App Control means for you, and how to carry on once it matches, is in [docs/INSTALL.md](https://github.com/7zStar/7-ZSTar/blob/main/docs/INSTALL.md#unsigned-packages-smartscreen-and-smart-app-control).

**About the first-level menu:** Windows 11 only lets programs with package identity onto the first level, so the all-users MSI installs a small MSIX package signed with a self-signed certificate, and trusts that certificate. Uninstalling removes both. If you'd rather not trust it, install with `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0` and the menu stays under “Show more options”. The package is registered only for the account that runs the installer; other accounts register it separately.

The full details, including file associations and uninstalling, are in [docs/INSTALL.md](https://github.com/7zStar/7-ZSTar/blob/main/docs/INSTALL.md).

## Known limitations

- **Unticking the shell-integration box removes the right-click registration.** In the file manager (`7zFM`), **Tools > Options > 7-ZSTar** has a box named "Integrate 7-ZSTar to shell context menu". As in official 7-Zip, unticking it deletes the shell extension's registration (its `CLSID` key) that the installer created, and the 7-ZSTar entry disappears from the right-click menu. With the all-users package you can tick the box again when the file manager runs as administrator. With the per-user package you cannot: ticking it again shows "Access is denied" and the entry stays gone. To get it back, run the original `.msi` again and choose *Repair*.
- **The first-level menu is only registered when the install runs in an interactive, signed-in session.** Installing the all-users `.msi` from a remote or non-interactive session (over SSH, or a silent deployment from a management tool) still reports success, but the Windows 11 package isn't registered, so only the classic menu under “Show more options” appears. Details are in [docs/INSTALL.md](https://github.com/7zStar/7-ZSTar/blob/main/docs/INSTALL.md#the-windows-11-right-click-menu).

## System requirements

Windows 7 or Windows Server 2008 R2 and later (x64, x86); Windows 10 and later on arm64. Nothing else to install. That floor comes from what the packages require; versions older than Windows 11 haven't been tested. On Linux there's a command-line build you compile yourself; macOS isn't supported.

## About this project

7-ZSTar is a 7-Zip fork that's friendlier to modern Windows 11 users. 7-Zip's core is excellent, but parts of it haven't kept up with how people work today: Windows 11 tucks it away under “Show more options”, and it can't compress to zstd. 7-ZSTar fills those gaps and leaves everything else the way you know it.

## Documentation

Every package includes `7-zip.chm`, official 7-Zip's help file, unmodified: **Help > Contents** and F1 open it. It says “7-Zip” throughout and doesn't cover what 7-ZSTar adds; for that, see this page and [CHANGELOG.md](CHANGELOG.md).

If the help file isn't next to the executable, those same entries open this section online instead.

## Building

See [build/README.md](build/README.md). Short version: VS2022 Build Tools (MSVC v143), then `pwsh build\Build.ps1`. Before merging a new upstream release, read [MAINTAINING.md](MAINTAINING.md).

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

LGPL v3, see [LICENSE](LICENSE). Some parts come with other terms: RAR decompression, for example, carries the unRAR restriction, so a build with RAR support isn't purely LGPL v3. The full list is in [LICENSE-EXCEPTIONS.md](LICENSE-EXCEPTIONS.md), and the copyright notices for every component are in [NOTICE](NOTICE).

## Thanks

7-ZSTar stands on the shoulders of many people. Thank you to everyone who has given their time to 7-Zip, to compression algorithms, and to open source at large. This software wouldn't exist without you.
