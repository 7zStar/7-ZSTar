<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · **简体中文** · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

**对现代 Windows 11 用户更友好的 7-Zip 分支版：右键菜单第一级就有它，支持 zstd 压缩，tar.zst 一步生成。**

[下载](https://github.com/7zStar/7-ZSTar/releases/latest) · [官方网站](https://www.7zstar.com) · [更新日志](../../CHANGELOG.md)

## 为什么用 7-ZSTar

- **告别“显示更多选项”。** 在 Windows 11 上，7-ZSTar 直接出现在右键菜单的第一级。
- **一步生成 tar.zst。** 把文件夹压缩成 .tar.zst，或者把它解开，都只要一步，磁盘上不会留下 .tar。官方 7-Zip 不能创建 .tar.zst，解开它也要分两步，中间会先解出一个 .tar。
- **比 7z 快 10 倍左右。** 在真实的项目文件夹上，tar.zst 的压缩速度比 7z 快 10 到 18 倍。

## 速度实测

| 文件夹 | 文件数 | 原始大小 | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 秒／76.7 MB | 38.4 秒／51.8 MB | **3.8 秒**／59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 秒／107.8 MB | 54.8 秒／65.7 MB | **3.6 秒**／83.4 MB |
| Python `.venv`（含大型二进制文件） | 11,654 | 671 MB | 25.5 秒／249.5 MB | 100.8 秒／167.2 MB | **5.6 秒**／210.9 MB |

tar.zst 的体积比 zip 小 15% 到 23%，速度也不比 zip 慢。7z 生成的文件仍然最小（tar.zst 比它大 15% 到 27%），但耗时长得多。解压时，三种格式耗时差不多。

三种格式均使用默认设置；7-ZSTar 26.05.1 x64，Intel Core Ultra 7 155H，NVMe SSD，每项取 3 次运行的中位数，2026-11。

## 支持的格式

- **一步压缩：** tar.zst、tar.br、tar.lz4、tar.lz5、tar.liz、tar.gz、tar.bz2、tar.xz
- **一步解压：** 以上全部，再加上 tar.lzma 和 tar.Z
- **新增的压缩算法：** zstd、brotli、lz4、lz5 和 lizard（可单独使用，也可在 .7z 里使用），以及 fast-lzma2（LZMA2 的另一种编码器）
- 官方 7-Zip 能处理的格式，这里全部照常可用。

## 下载

大多数人需要的是“为所有用户安装”的 x64 `.msi`，在 [Releases](https://github.com/7zStar/7-ZSTar/releases/latest) 页面下载。

| | 为所有用户安装 `.msi` | 仅当前用户 `-user.msi` | 免安装 `.zip` |
|---|---|---|---|
| 需要管理员权限 | 是 | 否 | 否 |
| 右键菜单 | Windows 11 上在第一级 | 传统右键菜单（Windows 11 上在“显示更多选项”下） | 无 |
| 「开始」菜单项 | 有 | 有 | 无 |

每种也都有 x86 和 arm64 版本，请选择与你的 Windows 相符的那个。在 64 位 Windows 上，x86 版本可能没有右键菜单；arm64 版本尚未在真机上运行过。7-ZSTar 可以与官方 7-Zip 同时安装，不会影响官方 7-Zip。

**第一次运行时，Windows 可能会弹出警告。** 这些文件没有代码签名，所以 SmartScreen 可能会拦截（显示“Windows 已保护你的电脑”，可能需要展开警告才能看到“仍要运行”）；在已打开智能应用控制的 Windows 11 上，`.msi` 会被直接阻止。每个发行版都附有 `SHA256SUMS` 文件，可用来核对你下载的文件。核对方法，以及智能应用控制的应对办法，见[安装说明](../install/INSTALL.zh-Hans.md#未签名的安装包smartscreen-与智能应用控制)。

**关于第一级菜单：** 在 Windows 11 上，“为所有用户安装”的 `.msi` 会额外安装一个用自签名证书签署的小型软件包，并信任这张证书；这是 Windows 对进入第一级菜单的要求。卸载时两者都会移除。如果不想这样，用 `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0` 安装即可。这个软件包只为运行安装程序的账户注册，其他账户需要各自注册。

文件关联、卸载以及“仅当前用户”安装包的细节，见[安装说明](../install/INSTALL.zh-Hans.md)。

## 命令行

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

在 PowerShell 里，格式参数要加引号：`7z a "-ttar.zst" backup.tar.zst docs`。不加的话，PowerShell 会把它拆成两段，结果生成一个名为 `.zst` 的文件。Command Prompt (cmd)（命令提示符）不用加引号。

## 小提醒

- **取消勾选“添加 7-ZSTar 到右键菜单”**（文件管理器里的 **工具 > 选项 > 7-ZSTar**）会移除右键菜单项，这一点和官方 7-Zip 一样。“为所有用户安装”版以管理员身份运行文件管理器，就能重新勾上。“仅当前用户”版做不到（会提示“拒绝访问。”）；请重新运行 `.msi`，选择 *Repair*（修复）。
- **在 Windows 11 上静默安装或远程安装**（通过 SSH，或用部署工具）会成功，但不会注册第一级菜单，7-ZSTar 只会出现在“显示更多选项”下。[安装说明里有更多细节](../install/INSTALL.zh-Hans.md#windows-11-右键菜单)。
- **解压 tar.br、tar.lz4、tar.lz5、tar.liz 或 tar.Z** 对你来说仍是一步，只是过程中会先解到一个临时文件，结束后自动删除。

## 系统要求

Windows 7 / Server 2008 R2 及以上（x64、x86），或 arm64 上的 Windows 10 及以上。无需另外安装任何东西。已在 64 位 Windows 7 SP1（已装后续更新）、Windows 10 和 Windows 11 上实测；[测试了哪些项目](../install/INSTALL.zh-Hans.md#系统要求)。Linux 上有需要自行编译的命令行版本；不支持 macOS。

## 说明文档

**帮助 > 帮助** 和 F1 会打开 `7-zip.chm`，也就是官方 7-Zip 的帮助文件。其中通篇写的是“7-Zip”，也没有涵盖 7-ZSTar 新增的功能；这些内容请看本页和[更新日志](../../CHANGELOG.md)。如果找不到帮助文件，同样的入口会改为在线打开这一部分。

想自己构建 7-ZSTar，请看 [build/README.md](../../build/README.md)；合并上游新版本之前，请先读 [MAINTAINING.md](../../MAINTAINING.md)。

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

采用 LGPL v3，见 [LICENSE](../../LICENSE)。部分内容另有条款：RAR 解压受 unRAR 限制，因此带 RAR 支持的版本并不是纯粹的 LGPL v3。完整清单见 [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md)，各组件的版权声明见 [NOTICE](../../NOTICE)。

感谢每一位为 7-Zip、压缩算法以及整个开源世界付出过时间的人。没有你们，就没有 7-ZSTar。
