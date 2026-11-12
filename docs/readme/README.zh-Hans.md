<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · **简体中文** · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [한국어](README.ko.md) · [العربية](README.ar.md) · [Esperanto](README.eo.md)

**对现代 Windows 11 用户更友好的 7-Zip 分支版：右键菜单第一级就有它，支持 zstd 压缩，tar.zst 一次生成。**

[下载](https://github.com/7zStar/7-ZSTar/releases/latest) · [官方网站](https://www.7zstar.com) · [更新日志](../../CHANGELOG.md)

## 为什么用 7-ZSTar

- **告别“显示更多选项”。** 用“为所有用户安装”的 MSI 装好后，7-ZSTar 直接出现在 Windows 11 右键菜单第一级。
- **一步到位，磁盘上不留 .tar。** 压缩成 tar.zst、解开 tar.zst 都只要一步，两个方向都不生成 .tar。官方 7-Zip 不能压缩成 .tar.zst，解压也要先解出 .tar，再解一次。
- **比 7z 快 10 倍。** 压缩真实项目文件夹时，tar.zst 比 7z 快 10 到 18 倍。

## 速度实测

| 文件夹 | 文件数 | 原始大小 | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 秒／76.7 MB | 38.4 秒／51.8 MB | **3.8 秒**／59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 秒／107.8 MB | 54.8 秒／65.7 MB | **3.6 秒**／83.4 MB |
| Python `.venv`（含大型二进制文件） | 11,654 | 671 MB | 25.5 秒／249.5 MB | 100.8 秒／167.2 MB | **5.6 秒**／210.9 MB |

tar.zst 的体积比 zip 小 15% 到 23%，速度也不输 zip。当然，它比 7z 大 15% 到 27%，如果最看重体积，还是选 7z。这里比的是压缩；解压时三者耗时相近，没有速度优势。

zip、7z、tar.zst 均使用默认设置。7-ZSTar 26.05.1 x64（7z.exe），单机（Intel Core Ultra 7 155H，NVMe SSD），三个真实项目文件夹，取 3 次的中位数，2026-11。

## 支持的格式

- **一步压缩（8 种）**：tar.zst、tar.br、tar.lz4、tar.lz5、tar.liz、tar.gz、tar.bz2、tar.xz
- **一步解开（10 种）**：以上 8 种，再加 tar.lzma、tar.Z
- **新增的压缩算法**：zstd、brotli、lz4、lz5、lizard，既可以作为独立格式，也可以在 .7z 里使用；另有 fast-lzma2 可替代 LZMA2。
- 7-Zip 原有的格式全部保留。

解开 tar.br、tar.lz4、tar.lz5、tar.liz、tar.Z 时，操作上同样只要一步，但程序会先解到临时文件，用完即删。

## 命令行

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

在 PowerShell 里，格式参数要加引号，例如 `7z a "-ttar.zst" backup.tar.zst docs`。不加的话，PowerShell 会把 `-ttar.zst` 拆成两个参数，7z 就会创建出一个名为 `.zst` 的文件。命令提示符（cmd）不用加引号。

## 下载与安装

| | 为所有用户安装 `.msi` | 仅当前用户 `-user.msi` | 免安装 `.zip` |
|---|---|---|---|
| 安装范围 | 这台电脑的所有账户 | 当前账户 | 无需安装 |
| 需要管理员权限 | 是 | 否 | 否 |
| 右键菜单 | Windows 11 第一级 | 在“显示更多选项”里 | 无 |
| 开始菜单 | 有 | 有 | 无 |

三种都提供 x64、x86、arm64 版本，请选择与 Windows 相同的架构：在 64 位 Windows 上安装 x86 版本，可能没有右键菜单。arm64 版本尚未在真机上运行过。可以和官方 7-Zip 同时安装，互不影响。

**Windows 可能会对这些下载显示警告。** 安装程序和程序文件都没有经过证书颁发机构签发的代码签名，所以第一次运行时，Microsoft Defender SmartScreen 可能会拦截并显示警告；在已开启 Smart App Control 的 Windows 11 电脑上，`.msi` 安装文件则会被直接拦截，而且没有任何可以继续的选项。这并不代表文件有问题：每个 Release 都附有 `SHA256SUMS`，可以用来核对你下载的文件是否与发布的一致。核对方法、Smart App Control 对你的影响，以及核对无误后如何继续安装，见 [docs/INSTALL.md](../INSTALL.md#unsigned-packages-smartscreen-and-smart-app-control)（目前只有英文版）。

**关于第一级菜单**：Windows 11 只允许带有包标识的程序进入第一级，所以“为所有用户安装”的 MSI 会安装一个用自签名证书签署的小型 MSIX 包，并信任这张证书；卸载时一并移除。如果不想信任它，用 `msiexec /i 7-ZSTar-<版本>-<架构>.msi SPARSE=0` 安装，菜单就会留在“显示更多选项”里。这个包只为运行安装程序的账户注册，其他账户需要另行注册。

完整说明（包括文件关联和卸载）见 [docs/INSTALL.md](../INSTALL.md)，目前只有英文版。

## 已知限制

- **取消勾选“添加到右键菜单”会移除右键菜单的注册。** 在文件管理器（`7zFM`）的“工具 ▸ 选项 ▸ 7-ZSTar”页，有一个“添加 7-ZSTar 到右键菜单”复选框。和官方 7-Zip 一样，取消勾选会删掉安装程序创建的外壳扩展注册（`CLSID` 键），7-ZSTar 就从右键菜单消失。“为所有用户安装”的版本以管理员身份运行文件管理器，可以再勾回来；仅当前用户版勾不回来：再勾选会弹出“拒绝访问”，菜单也不会回来。要恢复，请重新运行当初的 `.msi` 安装文件，选择“修复”。
- **只有在交互式登录的会话中安装，第一级菜单才会注册。** 从远程或非交互式会话安装“为所有用户安装”的 `.msi`（例如通过 SSH，或管理工具的静默部署），安装仍会报告成功，但 Windows 11 包没有注册，只会出现“显示更多选项”里的传统菜单。详情见 [docs/INSTALL.md](../INSTALL.md#the-windows-11-right-click-menu)。

## 系统要求

Windows 7 或 Windows Server 2008 R2 及以上（x64、x86）；arm64 需要 Windows 10 及以上。无需额外安装运行环境。这个下限是根据安装包的要求推算的，比 Windows 11 更早的版本尚未实测。Linux 只提供需要自行构建的命令行版本，不支持 macOS。

## 项目定位

7-ZSTar 是对现代 Windows 11 用户更友好的 7-Zip 分支版。7-Zip 的内核很出色，但有些地方没跟上现在的使用习惯：Windows 11 把它收在“显示更多选项”里，也不能压缩成 zstd。7-ZSTar 补上这些短板，其余操作都和 7-Zip 一样，不用改变使用习惯。

## 说明文档

每个安装包都附带官方 7-Zip 的帮助文件，从“帮助”菜单或按 F1 打开，内容未做改动，所以写的是“7-Zip”，也不包含 7-ZSTar 新增的功能；新增内容请看本页和 [CHANGELOG.md](../../CHANGELOG.md)。

如果可执行文件旁边没有帮助文件，这些入口会改为打开本项目 GitHub 页面的这一段（英文版）。

## 从源代码构建

见 [build/README.md](../../build/README.md)。简单来说：装好 VS2022 Build Tools（MSVC v143），再运行 `pwsh build\Build.ps1`。合并上游新版本之前，请先读 [MAINTAINING.md](../../MAINTAINING.md)。

<a id="donate"></a>

## 赞助

7-ZSTar 可以免费使用，赞助与否都没关系。如果它帮你省了些时间，想表达一下谢意，可以把加密货币转到下面的地址。这笔钱是给我个人（DraftingDreamer，筑梦天地）的，用来补贴我自己的开发开销，不用于交换功能或帮助，也不构成任何后续承诺。

Ethereum 和 Polygon 链上的资产都收，ETH、POL、USDT、USDC 或其他代币都欢迎。两条链用的是同一个地址。

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="赞助地址的二维码">

- 只接收 Ethereum（ERC20）和 Polygon 链上的转账。如果两条链都能用，建议用 Polygon，手续费通常更低。
- 官方地址只有这一个，我不会要求任何人改转到别的地址。
- 链上转账无法撤销，所以不能退款。

在 GitHub 上给 7-ZSTar 点个星标，或者推荐给朋友，同样是帮忙。

## 许可证

LGPL v3，见 [LICENSE](../../LICENSE)。部分内容另有条款，例如 RAR 解压受 unRAR 限制，因此带 RAR 支持的版本不是纯 LGPL v3。完整清单见 [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md)，各组件的版权声明见 [NOTICE](../../NOTICE)。

## 致谢

7-ZSTar 站在许多人的肩膀上。感谢每一位为 7-Zip、各种压缩算法和开源世界付出过的人，没有你们，就没有这个软件。
