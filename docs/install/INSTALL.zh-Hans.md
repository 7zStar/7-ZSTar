<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# 安装 7-ZSTar

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · **简体中文** · [한국어](INSTALL.ko.md) · [Italiano](INSTALL.it.md) · [Polski](INSTALL.pl.md) · [Türkçe](INSTALL.tr.md) · [Nederlands](INSTALL.nl.md) · [Українська](INSTALL.uk.md) · [Bahasa Indonesia](INSTALL.id.md) · [ไทย](INSTALL.th.md) · [Čeština](INSTALL.cs.md) · [Magyar](INSTALL.hu.md) · [Română](INSTALL.ro.md) · [Svenska](INSTALL.sv.md) · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md)

这份文档是 [README](../readme/README.zh-Hans.md) 中简短说明背后的细节：系统要求、SmartScreen 警告、智能应用控制、如何核对下载的文件、三种安装包、Windows 11 右键菜单、文件关联与卸载。

## 系统要求

**Windows 7 或 Windows Server 2008 R2，x64 或 x86。arm64 则需要 Windows 10。**
不需要其他任何组件：C 运行时是静态链接的（`-MT`），所以这些二进制文件除了 Windows 自带的 DLL 之外不导入任何东西，既不用另装可再发行组件包，也不需要 .NET。

这个最低要求是根据安装包的需求*推算*出来的，也做过实测：在已安装后续更新（其中包括 PowerShell 5.1）的 Windows 7 SP1、Windows 10 22H2 和 Windows 11 上测试过，均为 64 位。在 Windows 7 和 10 上，测试的内容有：为所有用户安装和仅当前用户安装的 x64 `.msi` 的安装与卸载、安装向导、x64 `.zip`、所有新增的编解码器和一步完成的 tar 格式、右键菜单、文件关联和帮助文件，以及在 64 位 Windows 上运行的 x86 `.msi` 和 `.zip`。除此之外，Windows 上没有测试过其他环境：Windows 8 和 8.1、Windows Server、32 位 Windows、arm64 硬件，以及没有安装上述更新的 Windows 7，都没有测。这个最低要求也比上游 7-Zip 的高，上游的二进制文件在 Windows XP 上仍然能加载。有三个原因把门槛抬到了这里，其中第二个是任何构建设置都无法改变的：

- `.msi` 声明了 `InstallerVersion="500"`，而 Windows Installer 5.0 是随“with Windows Server 2008 R2 and later and Windows 7 and later”（即 Windows Server 2008 R2 及更高版本，以及 Windows 7 及更高版本）一起发布的（[Microsoft][msi-versions]）。免安装的 `.zip` 不经过 Windows Installer，但请看接下来的两点。
- **zstd 和 fast-lzma2 使用的同步机制只有 Vista 及以上才有。** 两者都在自己的头文件里强制定义 `_WIN32_WINNT 0x0600`，并直接调用 `InitializeConditionVariable` / `SleepConditionVariableCS`，所以内置了这些编解码器的两个二进制文件 `7z.dll` 和 `7za.exe`，会导入四个 Windows XP 和 Server 2003 没有的函数。上游的 `7z.dll` 一个也不导入。
- 工具链：这些文件是用 Visual Studio 2022 构建的，它支持的目标平台是 Windows 7 及更高版本，Vista 和 Server 2008 是“No”（[Microsoft][vs-targeting]）。链接后的子系统版本在 x64 和 x86 上是 6.0，在 arm64 上是 6.2，而 Windows on arm64 本来就是从 Windows 10 才开始的。

Windows Vista 和 Server 2008 处在两者之间：二进制文件能加载，但工具链不支持它们，安装程序在那里也运行不了，7-ZSTar 也没有在上面测试过。

**Linux 只支持命令行版本的自行构建；不支持 macOS。**
这个分支版用 gcc 通过自己的 makefile 构建出原生的 `7zz`（`Alone2` 控制台程序），该 makefile 会引用上游的 makefile，且不修改上游的任何一个：`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`。
只在 Ubuntu 24.04、gcc 13.3（x86-64）上构建并测试过：用上游的编译选项构建没有任何警告，包含 77 项检查的冒烟测试全部通过，25 个在 Windows 上生成的和 37 个在 Linux 上生成的互操作测试向量，得出的判定与在 Windows 上相同。这次移植改动的两个本分支专有文件，在 Windows 上照样可以不加修改地构建（干净的 x64 构建、冒烟测试和互操作回读全部通过）。没有图形界面。上游其他的 Linux 目标（`7za`、`7zr`、`7z.so`）不受支持：它们的 gcc 对象列表缺少本分支对上游处理程序所做的修改所需要的部分，预计会在链接时失败。其他架构、发行版和编译器都没有验证过，macOS 从未构建过，因此无法给出 `MACOSX_DEPLOYMENT_TARGET`。构建步骤、测试和已知限制见 `build/linux/README.md`；与 Linux 工具的互操作性见 `test/interop/REPORT.md`。

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## 未签名的安装包、SmartScreen 与智能应用控制

**7-ZSTar 发行版中的安装程序和程序文件，都没有经过证书颁发机构的代码签名**，本项目也没有持有任何代码签名证书。因此 Windows 无法得知文件是谁发布的，你第一次运行 `.msi`，或第一次运行 `.zip` 里的程序时，Microsoft Defender SmartScreen 可能会拦下来并显示警告。Microsoft 的开发者文档把“No signature”（没有签名）列为会显示警告的情形之一，警告的标题是“Windows 已保护你的电脑”，用户必须选择“仍要运行”，应用才会运行（[Microsoft][smartscreen-rep]）。企业策略可以完全去掉这个选项；遇到这种电脑，请询问管理它的人。

发行版里唯一*有*签名的，是把 7-ZSTar 放进 Windows 11 右键菜单第一级的那个小型包，它位于为所有用户安装的 `.msi` 里面。它的证书是自签名的，在构建这个包时才生成，所以它不是证书颁发机构的签名，也说明不了是谁构建了这个包；它做什么、怎样拒绝它，请见 [Windows 11 右键菜单](#windows-11-右键菜单)。

出现警告并不代表文件有问题，没有警告也不代表文件没问题。你自己能核对的是：手上这份是不是和发行页面上发布的完全一样。每个发行版都附带一个名为 `SHA256SUMS` 的文件：每个安装包一行，是 SHA-256 哈希值，后面跟文件名。

1. 把安装包和 `SHA256SUMS` 从同一个发行页面下载到同一个文件夹。
2. 在该文件夹中打开 PowerShell 进行比对。把名称换成你下载的文件：

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True` 表示两个哈希值完全相同。如果想自己查看，可以改为运行
   `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi`，再到 `SHA256SUMS` 里找相同的文件名；比对时不区分大小写。
3. 如果得到 `False`，或者 `SHA256SUMS` 里找不到该文件名，请不要运行：删除该文件，重新下载。如果仍然对不上，请按 [SECURITY.md](../../SECURITY.md) 中的说明报告。

`SHA256SUMS` 只涵盖上传到该发行版的文件。自己构建同一个 tag 会得到不同的哈希值（右键菜单包每次构建都用新的证书签名）；如果你更愿意自己构建，每个发行版都会公开源代码：见 [build/README.md](../../build/README.md)。

哈希值核对无误，而且你对文件的来源也放心之后：

- **`.msi`**：照常启动。如果 SmartScreen 拦下来，请选择“仍要运行”（英文版 Windows 上是 “Run anyway”）。警告窗口可能需要先展开：在测试用的 Windows 10 上，要先点击消息下方的“更多信息”链接，才会出现“仍要运行”按钮，在那之前只有一个“不运行”按钮。为所有用户安装的 `.msi` 接着会像其他安装程序一样，要求管理员批准。
- **`.zip`**：解压后，从文件夹里启动 `7zFM.exe` 或 `7z.exe`。里面的程序同样没有签名，所以你第一次启动每一个程序时，Windows 都可能显示同样的警告。

SmartScreen 警告的依据是文件的知名度，不仅仅是签名；下载的人很少的文件，即使有签名也可能触发警告。这里的内容改变不了这一点，上面的步骤也没有任何一步会关闭 SmartScreen。

### Windows 11 上的智能应用控制

有些 Windows 11 电脑打开了更严格的保护，叫作**智能应用控制**。打开时，Windows 会拦截未签名的文件，除非 Microsoft 的云服务能为它担保，而新发布的版本通常没有这样的记录（[Microsoft][sac-faq]、[Microsoft][smartscreen-rep]）。和 SmartScreen 警告不同，这种拦截没有任何可以仍然运行该文件的选项，Microsoft 的常见问题解答也说，无法为单个应用绕过智能应用控制。

在 Windows 11 Pro 25H2（内部版本 26200.8037）、已打开智能应用控制的情况下试用 7-ZSTar 26.05.1，结果如下：

- **`.msi` 安装程序被拦截了**，为所有用户安装的和仅当前用户的都一样。在繁体中文版 Windows 上，Windows Installer 显示了「系統禁用此安裝。請連絡系統管理員。」，同时 Windows 安全中心的通知说，智能应用控制拦截了该文件，因为 Windows 无法得知是谁发布的，而且它不是 Windows 认识的应用。没有任何可以继续的选项，`msiexec /i ... /qn` 返回了 error 1625。这条消息是 Windows Installer 的字符串 1625；在英文版 Windows 上，同一条字符串是 “The system administrator has set policies to prevent this installation.”（是从 Windows Installer 的英文资源中读出的，没有在屏幕上见到过）。
- **`.zip` 里的程序可以运行。** 从免安装 `.zip` 解压出来的 `7zFM.exe`，在同一次测试中正常启动了。Windows 是否允许未签名的程序运行，是它对该文件的单独判断，所以在你的电脑上可能不一样。
- 刚打开智能应用控制之后，`.msi` 还能安装几分钟，然后才开始被拦截。原因没有找到，所以刚打开后安装成功，并不代表安装程序被允许。

所以在智能应用控制处于打开状态的电脑上，**安装程序无法安装**，核对 `SHA256SUMS` 也改变不了这一点。能改变的，是到 Windows 安全中心应用的智能应用控制设置里把它关闭（以测试用的繁体中文版 Windows 来说：Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定）。测试中选择“关闭”后立即生效，不用重启，之后安装程序就能安装了。这是整台电脑的设置，这里没有任何地方要求你更改：由你自己决定，在受管理的电脑上则由你的管理员决定。

另外值得先了解的是，之后还能不能再把它打开。Microsoft 的常见问题解答说，较新的 Windows 更新允许在不全新安装 Windows 的情况下再次打开智能应用控制，所以在没有这些更新的版本上，关闭可能就是永久的。在这里测试的版本上，关闭之后仍然提供打开的选项；那是测试结果，不是对你的版本做出的保证。

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## 安装

共有三种安装包，都由 `installer\Build-Package.ps1` 构建（仅当前用户的那个要加 `-PerUser`）：

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| 安装给 | 每个账户 | 执行安装的账户 | - |
| 文件资源管理器右键菜单 | 有 | 有，只有传统右键菜单（[见下](#仅当前用户安装包)） | 没有 |
| 「开始」菜单项 | 有 | 有 | 没有 |
| 需要管理员 | 是 | 否 | 否 |
| 移除方式 | “设置”中的“安装的应用” | “设置”中的“安装的应用” | 删除文件夹 |

“安装的应用”是 Windows 11 中的名称。Windows 10 把同一个页面叫作“应用和功能”，在 Windows 7 上则是 Control Panel（控制面板）里的 *Programs and Features*（程序和功能）。

请选择与 Windows 本身相符的安装包：32 位 Windows 用 x86，64 位 Windows 用 x64，Windows on Arm 用 arm64（arm64 安装包已经构建出来，但从未运行过）。x86 的外壳扩展是 32 位的，64 位的文件资源管理器无法加载它，所以在 64 位 Windows 上，x86 的 `-user.msi` 完全没有右键菜单；x86 的 `.msi` 只在 Windows 11 上才有，而且只限注册过它的 Windows 11 包的账户（执行安装的账户，或运行过 `-Register` 的账户，见下文）。

MSI 一律安装到 `Program Files\7-ZSTar`：和仅当前用户安装包不同，它不让你选择文件夹，也会忽略命令行里的 `INSTALLFOLDER`，因为那个文件夹里有安装程序会以 SYSTEM 身份运行的脚本，以及每位用户的文件资源管理器都会加载的 DLL，而在别处（例如 `C:\` 下）创建的文件夹，每位用户都能写入。它注册的是自己的外壳扩展 CLSID 和自己的 `Software\7-ZSTar` 注册表分支，所有右键菜单注册表项都命名为 `7-ZSTar`，所以既不会和官方 7-Zip 冲突，也不会移除官方 7-Zip 的项目。见 [installer/GUIDS.md](../../installer/GUIDS.md)。

它会运行一个普通的安装向导：welcome, licence, setup type, optional feature tree, finish（欢迎、许可协议、安装类型、可选功能树、完成）。静默安装照样可用，行为不变（`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`），因为 msiexec 在静默模式下会跳过整个用户界面流程。这个向导只有英文，即使 Windows 设成了其他语言也一样（在繁体中文版 Windows 10 上看到的；`.msi` 没有内置其他语言），结束页面上的 *Launch 7-ZSTar File Manager*（启动 7-ZSTar 文件管理器）默认是勾选的。

### Windows 11 右键菜单

在 Windows 11 上，这个项目会出现在第一级菜单里，而不是像官方 7-Zip 和 WinRAR 那样仍然埋在“显示更多选项”下面。Windows 11 只有在外壳扩展带有包标识时，才会把它列在那里，所以 MSI 会在程序旁边附带一个只含标识的小型 MSIX 包，并在安装时注册它。传统的注册方式也保留着：Windows 10 和 Windows 7 的右键菜单只有一级，没有“显示更多选项”，这个项目就是靠它出现在菜单里的；对恢复了旧版右键菜单的用户，也靠它继续工作。

那个包是用**自签名证书**签名的，安装程序会把这张证书放进 `LocalMachine\TrustedPeople`：Windows 不会部署签名无法链到任何受信任项的包。卸载时，会连同包一起移除证书。在 Windows 10 和 Windows 7 上，安装程序两样都不做：不添加证书，也不注册包，菜单完全由传统的注册方式提供。

如果你不想信任自签名证书，可以只拒绝这一部分，其余照常安装：

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

这样你只会得到传统右键菜单，所以在 Windows 11 上，7-ZSTar 在右键菜单里，位于“显示更多选项”下面。之后想启用第一级项目，或者在正常安装之后想撤销：

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

信任那张证书，意味着 Windows 也会不加警告地接受用同一把密钥签名的**任何其他**包。这把密钥只用于这一个包，卸载时也会一并收回，但这正是你同意的内容：上面的 `SPARSE=0` 就是拒绝它的办法。

包的注册是按用户进行的，而且安装程序只替执行安装的人注册。这有两个后果：

- 同一台电脑上的第二个账户，只有传统右键菜单，直到它用同一个脚本加上 `-Register` 运行为止。
- 卸载时，只会替执行卸载的人取消注册。如果是别人注册的，他的注册在卸载后依然存在，并指向一个已经不存在的文件夹；那个账户用 `Get-AppxPackage 7-ZSTar | Remove-AppxPackage` 清除它。

**已知限制：只有在交互式、已登录的会话中安装时，才会注册第一级菜单。** 通过远程或非交互式会话安装为所有用户安装的 `.msi`（经由 SSH，或管理工具的静默部署），仍然会报告成功，但 Windows 11 包没有注册，所以只会出现“显示更多选项”下面的传统右键菜单。测试中，从 SSH 会话（会话 0）运行 `msiexec /i ... /qn`，退出码是 0，而 `Setup-ShellIntegration.ps1` 报告了 `registration failed: 0x80070005`（拒绝访问）；同一个 `.msi` 从管理员的控制台会话安装，就能正常注册。

`-Status` 会打印出哪些项目已就位、哪些没有。

### 仅当前用户安装包

`7-ZSTar-<version>-<arch>-user.msi` 只为当前账户安装，装到 `%LOCALAPPDATA%\Programs\7-ZSTar`，不会出现用户账户控制(UAC)提示。它注册的所有内容都放在 `HKCU` 下；这个安装包不会向 `HKLM` 写入任何东西（Windows Installer 自己的记录除外）。以下是它没有像为所有用户安装的安装包那样做的事：

- **没有 Windows 11 第一级菜单。** 在 Windows 11 上，7-ZSTar 在右键菜单里，位于“显示更多选项”下面。第一级项目需要整台电脑都信任那张自签名证书，而这需要管理员：在 Windows 11 上的实测表明，只把证书放在 `CurrentUser\TrustedPeople` 不足以让 Windows 部署这个包。所以仅当前用户安装包不包含它。
- **两种安装包，每台电脑只能装其中一种。** 每个安装包在另一个已安装时都会拒绝安装；要先卸载其中一个，才能安装另一个。为所有用户安装的安装包只看得到运行它的那个账户的仅当前用户副本，所以其他账户的仅当前用户安装不会被检测到。
- **组策略可能隐藏它的菜单。** 在设置了 `EnforceShellExtensionSecurity` 的地方，文件资源管理器只会加载列在整机范围 *Approved* 项下的外壳扩展，而仅当前用户安装无法写入那个项，所以右键菜单不会出现。在那种环境请使用为所有用户安装的安装包。
- **在“工具 > 选项 > 系统”中清除某个格式，也会移除 7-ZSTar 对它的提供。** 在那里清除某个格式（点击它的单元格直到变空，然后点“确定”）时，文件管理器会删除整个 `HKCU\Software\Classes\.<ext>` 和 `7-ZSTar.<ext>` 注册表项，而在仅当前用户安装中，这些项里还存放着安装包为“设置 > 应用 > 默认应用”和“打开方式”列表所注册的内容。7-ZSTar 于是从该格式的“打开方式”列表中消失，“默认应用”里也会为它显示一个空白条目。修复安装可以把它补回来（再次运行 `.msi`，选择 *Repair*）。更好的做法是在“默认应用”里分配文件类型，而不是在文件管理器里。为所有用户安装的安装包在一个地方也有同样的弱点，说明见下文的文件关联。

### 文件关联，以及卸载对它们的影响

**请在“设置 > 应用 > 默认应用”中设置。** 在 Windows 11 上，在那里输入 7-ZSTar，它能打开的每种格式都会列出来供你分配。在 Windows 10 上，7-ZSTar 列在该页的 *Set defaults by app*（按应用设置默认值）下面，点 *Manage*（管理）可以看到它的格式。Windows 7 没有“设置”应用：7-ZSTar 列在 Control Panel（控制面板）> 默认程序 > “设置默认程序”里，本文所说的“默认应用”在那里就是指这一页。从这两个页面分配格式，还没有测试过。安装程序会把 7-ZSTar 注册为默认程序应用：每种格式一个带图标和打开命令的 ProgID、每个扩展名的“打开方式”列表里一个条目，以及 Windows 会读取的 Capabilities 块；但它刻意不声明拥有任何文件类型：由哪个程序打开你的压缩文件由你决定，这也让 7-ZSTar 和官方 7-Zip 不会互相干扰。不过，在没有其他程序提供打开某种格式时，Windows 仍可能自行把它交给 7-ZSTar：在测试用的 Windows 10 和 Windows 7 上，没有其他程序注册过 `.7z`，结果 `.7z` 文件显示着 7-ZSTar 的图标，双击就用它打开，Windows 并没有询问用哪个程序。

**文件管理器里的“工具 > 选项 > 系统”在 Windows 11 上大多不起作用**，这是 Windows 的规则，不是这里的错误。它会往 `HKCU\Software\Classes` 里写一个 `7-ZSTar.<ext>` ProgID，而对于电脑已经认识的扩展名（每种压缩格式都是），Windows 11 会忽略它：`AssocQueryString` 返回 `Unknown`，文件资源管理器画出空白的通用图标。Windows 认的是一个 `UserChoice` 项，上面盖有只有它自己能算出的哈希值，所以在 Windows 11 上，“设置”界面是唯一的路。没有任何应用能写出这样的项：7-ZSTar 不行，7-Zip 不行，任何安装程序都不行。Windows 10 和 Windows 7 在测试中的表现不同：在文件管理器里设置了 `.7z` 和 `.zst`、且没有为它们另选其他程序之后，`AssocQueryString` 对两者都返回了 `7zFM.exe`。

**在“所有用户”列中清除某个格式，会移除为所有用户安装的安装包自己对它的注册。** 该列写入的是 `HKLM\Software\Classes`，为所有用户安装的安装包把它所提供的 ProgID 和“打开方式”条目都放在那里，而在那里清除某个格式（这需要以管理员身份运行文件管理器）会把这些项整个删掉，对每个账户都一样。修复安装在仅当前用户安装包上把相同的项恢复了；为所有用户安装的安装包则没有测量过。

**更改任何东西之后图标仍然空白**，也可能是文件资源管理器的图标缓存造成的，它不会察觉已经缓存过的 DLL 被替换了；`ie4uinit.exe -show` 不能可靠地清掉它。请关闭文件资源管理器，删除 `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db`，再重新启动。

**卸载会移除它能够到的关联**：属于执行卸载者的 `7-ZSTar.*` ProgID，而且只处理仍然指向它们的文件类型，所以这期间已经交给别的程序的格式不会被动到。卸载为所有用户安装的安装包时，也不会动一个指向别处仍然存在的 7-ZSTar 副本的 ProgID，例如从 `.zip` 得到的免安装版，并且是用该副本自己的**工具 > 选项 > 系统**设置的那个 ProgID。仅当前用户安装包做不到这一点：它的 ProgID 就是那些同样的 `HKCU` 项（见上文的“仅当前用户安装包”），卸载会把它们全部移除，不论是谁最后写入的。如果把它们留下，这些类型就会指向一个图标和命令都是已删除可执行文件的 ProgID，结果是空白图标，而且双击会出现错误。其他账户的关联够不着；它们可以在程序被移除之前，先用 `Setup-ShellIntegration.ps1 -RemoveAssociations` 清除自己的关联。`msiexec /x ... KEEPASSOC=1` 会跳过这项清理，升级则从来不会做这项清理。

**已知限制：其他账户会保留它们自己设置的关联。** 卸载为所有用户安装的安装包时，只会清除执行卸载的账户在文件管理器的**工具 > 选项 > 系统**里、自己那一列（列标题为账户名称）中所设置的内容。其他在那里设置过关联的账户会保留它们，这些关联指向已被移除的程序，所以双击 `.7z` 文件时，Windows 会询问用哪个程序打开。每个账户都应该在卸载**之前**自行清除，用

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

它只会移除 7-ZSTar 的条目；或者在卸载之后，到“设置 > 应用 > 默认应用”里重新分配这些类型。改在文件管理器里做的话，是在自己那一列里，逐一点击显示 7-ZSTar 的单元格直到变空，然后点“确定”；请不要全选所有行再点“+”，因为它会把同一个状态应用到所有选中的行，也会连带清除属于其他程序（例如官方 7-Zip）的格式。

在**所有用户**列里设置的关联，卸载清理完全不会碰，会让每个账户都指向已被移除的程序。设置过任何这类关联的管理员，应该在卸载之前，在以管理员身份运行的文件管理器里清除那些单元格，再点“确定”；`-RemoveAssociations` 够不着这一列。在卸载之前清除它并无妨，即使这会删掉安装包自己在那里的注册（见上文），因为卸载本来就会移除它。仅当前用户安装包没有其他账户的问题，官方 7-Zip 的行为也相同。

## 语言

每个安装包都带有上游的翻译，九十多种语言。请在**工具 > 选项 > 语言**里选择；MSI 也允许你在 *Custom*（自定义）安装中把它们排除。7-ZSTar 第一次运行时会尝试跟随系统语言，但当 Windows 的“language for non-Unicode programs”（非 Unicode 程序的语言）与区域格式设置不一致时，这项检测会放弃并保持英文；自己手动选择语言永远有效。

7-ZSTar 自己新增的字符串，包括 zstd 的压缩级别和字典字段、新的压缩格式名称，没有上游的翻译，会保持英文。例外是“关于 7-ZSTar”对话框的**赞助**和**网站**按钮：92 种语言中有 67 种各有对应的字词，其余 25 种显示英文（`Lang/UPSTREAM.md` 列出了它们）。
翻译是直接引入的，不是在这里撰写的：见 [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md)。
