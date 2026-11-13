<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# 7-ZSTar 설치하기

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · **한국어** · [Italiano](INSTALL.it.md) · [Polski](INSTALL.pl.md) · [Türkçe](INSTALL.tr.md) · [Nederlands](INSTALL.nl.md) · [Українська](INSTALL.uk.md) · [Bahasa Indonesia](INSTALL.id.md) · [ไทย](INSTALL.th.md) · [Čeština](INSTALL.cs.md) · [Magyar](INSTALL.hu.md) · [Română](INSTALL.ro.md) · [Svenska](INSTALL.sv.md) · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md)

*영어판과 내용이 다를 경우 영어판을 따릅니다.*

[README](../readme/README.ko.md)의 간단한 안내 뒤에 있는 자세한 내용입니다. 시스템 요구 사항, SmartScreen 경고, 스마트 앱 컨트롤과 내려받은 파일을 확인하는 방법, 세 가지 패키지, Windows 11 오른쪽 클릭 메뉴, 파일 연결, 제거 방법을 다룹니다.

## 시스템 요구 사항

**Windows 7 또는 Windows Server 2008 R2, x64 또는 x86. arm64에서는 Windows 10.**
그 밖에 필요한 것은 없습니다. C 런타임을 정적으로 링크(`-MT`)했기 때문에
바이너리는 Windows 자체의 DLL만 가져다 쓰며, 재배포 가능 패키지도 .NET도 필요하지 않습니다.

이 최소 사양은 패키지가 요구하는 조건에서 *도출*한 것이며, 테스트는 Windows 7 SP1(이후 업데이트 설치, PowerShell 5.1 포함),
Windows 10 22H2, Windows 11에서 모두 64비트로 했습니다. Windows 7과 10에서는 모든 사용자용과 사용자별 x64 `.msi`의 설치와 제거,
설치 마법사, x64 `.zip`, 추가된 모든 코덱과 한 번에 끝나는 tar 형식, 오른쪽 클릭 메뉴, 파일 연결, 도움말 파일,
그리고 64비트 Windows에서 실행되는 x86 `.msi`와 `.zip`을 확인했습니다. 그 밖에는 Windows에서 테스트한 것이 없습니다.
Windows 8과 8.1, Windows Server, 32비트 Windows, arm64 하드웨어, 그 업데이트가 없는 Windows 7도 마찬가지입니다.
또한 이 최소 사양은 upstream 7-Zip의 최소 사양보다 높습니다. upstream 바이너리는 지금도 Windows XP에서 로드됩니다.
이 기준을 정하는 요인은 세 가지이며, 그중 두 번째는 어떤 빌드 설정으로도 되돌릴 수 없습니다.

- `.msi`는 `InstallerVersion="500"`을 선언하며, Windows Installer 5.0은
  "with Windows Server 2008 R2 and later and Windows 7 and later"(Windows Server 2008 R2 이후 및 Windows 7 이후와 함께) 제공되었습니다
  ([Microsoft][msi-versions]). 포터블 `.zip`은 Windows Installer를 거치지 않지만
  다음 두 항목을 보십시오.
- **zstd와 fast-lzma2는 Vista 이후에만 있는 동기화 기능을 사용합니다.** 두 라이브러리 모두
  자체 헤더에서 `_WIN32_WINNT 0x0600`을 강제하고
  `InitializeConditionVariable` / `SleepConditionVariableCS`를 직접 호출합니다. 따라서
  코덱이 포함된 두 바이너리인 `7z.dll`과 `7za.exe`는 Windows XP와 Server 2003에 없는
  함수 네 개를 가져옵니다. upstream의 `7z.dll`은 그중 어느 것도 가져오지 않습니다.
- 툴체인: 이 바이너리는 Visual Studio 2022로 빌드하며, 이 버전이 지원하는
  대상 목록은 Windows 7 이후입니다. Vista와 Server 2008은 "No"입니다
  ([Microsoft][vs-targeting]). 링크된 서브시스템 버전은 x64와
  x86에서 6.0, arm64에서 6.2이며, arm64용 Windows는 어차피 Windows 10부터 시작합니다.

Windows Vista와 Server 2008은 그 중간에 있습니다. 바이너리는 로드되겠지만
툴체인이 지원하지 않고, 설치 관리자는 그곳에서 실행되지 않으며,
7-ZSTar는 해당 버전에서 테스트하지 않았습니다.

**Linux는 명령줄 빌드로만 지원하며, macOS는 지원하지 않습니다.**
이 포크는 자체 makefile로 gcc를 사용해 네이티브 `7zz`(`Alone2` 콘솔 프로그램)를 빌드합니다.
이 makefile은 upstream의 makefile을 포함할 뿐 upstream 파일은 하나도 수정하지 않습니다.
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
Ubuntu 24.04, gcc 13.3(x86-64)에서만 빌드와 테스트를 마쳤습니다.
upstream의 플래그로 빌드해도 경고가 없고, 77개 항목의 스모크 테스트를 통과하며,
Windows에서 만든 상호 운용 벡터 25개와 Linux에서 만든 벡터 37개가 Windows에서와 같은
판정을 내립니다. 이 포트가 건드린 포크 소유 파일 두 개는 Windows에서도
그대로 빌드됩니다(x64 클린 빌드, 스모크 테스트, 상호 운용 read-back 모두 통과). GUI는 없습니다.
upstream의 다른 Linux 대상(`7za`, `7zr`, `7z.so`)은
지원하지 않습니다. 이들의 gcc 오브젝트 목록에는 upstream 핸들러에 대한 포크의 변경이 필요로 하는 항목이 없어서
링크에 실패할 것으로 예상합니다. 다른
아키텍처, 배포판, 컴파일러는 검증하지 않았고, macOS는
한 번도 빌드한 적이 없으므로 `MACOSX_DEPLOYMENT_TARGET`도 제시할 수 없습니다. 빌드
절차, 테스트, 알려진 제한은 `build/linux/README.md`에,
Linux 도구와의 상호 운용성은 `test/interop/REPORT.md`에 있습니다.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## 서명되지 않은 패키지, SmartScreen 및 스마트 앱 컨트롤

**7-ZSTar 릴리스의 설치 관리자와 프로그램은 인증 기관(CA)의 코드 서명을 받지 않았으며**, 이 프로젝트는 코드 서명 인증서를 보유하고 있지 않습니다.
그래서 Windows는 파일을 누가 게시했는지 알 수 없고,
`.msi` 또는 `.zip`에 든 프로그램을 처음 실행할 때 Microsoft Defender SmartScreen이 경고와 함께 실행을 막을 수 있습니다. Microsoft 개발자 문서는
"No signature"(서명 없음)를 "Windows의 PC 보호"라는 제목의 경고가 표시되는 경우 중 하나로 꼽으며,
이때 사용자가 "실행"을 선택해야 앱이 실행됩니다
([Microsoft][smartscreen-rep]). 기업 정책으로 이 선택지가 아예 없어질 수도 있습니다.
그런 PC라면 관리하는 사람에게 문의하십시오.

릴리스에서 서명된 것은 딱 하나, 모든 사용자용 `.msi` 안에 들어 있고 7-ZSTar를 Windows 11 오른쪽 클릭 메뉴의 첫 화면에 올려 주는 작은 패키지뿐입니다.
이 패키지의 인증서는 자체 서명이며 해당 패키지를 빌드하는 동안 생성됩니다.
따라서 인증 기관의 서명이 아니고 패키지를 누가 빌드했는지는 전혀 증명하지 않습니다. 이 패키지의 역할과 사용하지 않는 방법은
[Windows 11 오른쪽 클릭 메뉴](#windows-11-오른쪽-클릭-메뉴)를 보십시오.

경고가 떴다고 해서 파일이 나쁘다는 증거는 아니고, 경고가 없다고 해서 파일이 안전하다는 증거도 아닙니다. 직접 확인할 수 있는 것은 내가 받은 파일이 릴리스 페이지에 게시된 파일과 정확히 같은지입니다. 모든 릴리스에는 `SHA256SUMS`라는 파일이 있습니다. 패키지마다 한 줄씩, SHA-256 해시 뒤에 파일 이름이 적혀 있습니다.

1. 같은 릴리스 페이지에서 패키지와 `SHA256SUMS`를 같은 폴더에 내려받습니다.
2. 그 폴더에서 PowerShell을 열고 비교합니다. 이름은 내려받은 파일 이름으로 바꾸십시오.

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True`가 나오면 해시가 동일합니다. 직접 눈으로 비교하려면
   `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi`를 실행해서
   `SHA256SUMS`에서 같은 파일 이름을 찾으십시오. 비교할 때 대소문자는 구분하지 않습니다.
3. `False`가 나오거나 `SHA256SUMS`에 파일 이름이 없으면 실행하지 마십시오.
   파일을 삭제하고 다시 내려받으십시오. 그래도 일치하지 않으면
   [SECURITY.md](../../SECURITY.md)에 설명된 대로 신고해 주십시오.

`SHA256SUMS`는 해당 릴리스에 올라온 파일만 다룹니다. 같은
태그를 직접 빌드하면 해시가 다르게 나오며(오른쪽 클릭 메뉴 패키지는 빌드할 때마다 새 인증서로 서명됩니다),
직접 빌드하고 싶은 분을 위해 모든 릴리스에 소스 코드를 함께 공개합니다. [build/README.md](../../build/README.md)를 보십시오.

해시가 일치하고 파일의 출처에 만족한다면:

- **`.msi`** - 평소처럼 실행합니다. SmartScreen이 막으면 그래도 실행하는 옵션("실행")을 선택합니다
  (영어 Windows에서는 "Run anyway"입니다). 경고 창을 먼저 펼쳐야 할 수도 있습니다.
  시험한 Windows 10 PC에서는 경고 창의 메시지 아래에 있는 "추가 정보" 링크를 누르기 전까지
  파일을 실행하지 않는 "실행 안 함" 단추만 표시되었습니다.
  그러면 모든 사용자용 `.msi`는 다른 설치 관리자와 마찬가지로 관리자 승인을 요청합니다.
- **`.zip`** - 압축을 풀고 폴더에서 `7zFM.exe` 또는 `7z.exe`를 실행합니다. 안에 든
  프로그램도 서명되어 있지 않으므로, 각 프로그램을 처음 실행할 때 Windows가 같은 경고를 표시할 수 있습니다.

SmartScreen은 서명 여부만이 아니라 파일이 얼마나 널리 알려졌는지를 보고 경고합니다. 내려받은 사람이 적은 파일은 서명이 되어 있어도 경고가 뜰 수 있습니다. 여기 있는 어떤 것도 이를 바꾸지 못하며, 위의 단계 중 어느 것도 SmartScreen을 끄지 않습니다.

### Windows 11의 스마트 앱 컨트롤

일부 Windows 11 PC에는 **스마트 앱 컨트롤**이라는 더 엄격한 보호 기능이
켜져 있습니다. 이 기능이 켜져 있으면 Windows는 Microsoft 클라우드 서비스가 보증할 수 있는 경우가 아니면 서명되지 않은 파일을 차단하는데,
새 릴리스에는 보통 그런 기록이 없습니다
([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). SmartScreen 경고와 달리
이 차단에는 그래도 파일을 실행하는 옵션이 없으며, Microsoft FAQ에 따르면
개별 앱에 대해 스마트 앱 컨트롤을 우회할 방법은 없습니다.

스마트 앱 컨트롤을 "켬"으로 둔 Windows 11 Pro 25H2(build 26200.8037)에서 7-ZSTar 26.05.1을 시험했을 때의 결과는 다음과 같습니다.

- **`.msi` 설치 관리자가 차단되었습니다.** 모든 사용자용과 사용자별 설치 관리자 모두 같았습니다. 중국어 번체 Windows에서 Windows Installer는
  「系統禁用此安裝。請連絡系統管理員。」(뜻: 이 설치는 시스템에서 금지되어 있으니 시스템 관리자에게 문의하라는 내용)라고 표시했고, Windows 보안 알림은
  Windows가 게시자를 알 수 없고 Windows가 아는 앱도 아니어서
  스마트 앱 컨트롤이 파일을 차단했다고 알렸습니다. 계속 진행할 옵션은 없었고,
  `msiexec /i ... /qn`은 error 1625를 반환했습니다. 이 메시지는
  Windows Installer의 string 1625이며, 영어 Windows에서는 같은 문자열이
  "The system administrator has set policies to prevent this installation."로 표시됩니다
  (Windows Installer의 영어 리소스에서 읽은 것이며 화면에서 확인한 것은 아닙니다).
- **`.zip`의 프로그램은 실행되었습니다.** 같은 시험에서 포터블 `.zip`에서 풀어낸 `7zFM.exe`가
  정상적으로 시작되었습니다. 서명되지 않은 프로그램의 실행을 허용할지는
  Windows가 그 파일에 대해 내리는 개별 판단이므로, 사용 중인 PC에서는 다를 수 있습니다.
- 스마트 앱 컨트롤을 "켬"으로 바꾼 직후에는 `.msi`가 몇 분 동안
  설치되다가 그 뒤에 차단되기 시작했습니다. 원인은 찾지 못했으므로,
  켠 직후의 설치 성공이 설치 관리자가 허용된다는 뜻은 아닙니다.

따라서 스마트 앱 컨트롤이 켜져 있는 PC에서는 **설치 관리자를 설치할 수 없으며**,
`SHA256SUMS`를 확인해도 이는 달라지지 않습니다. 달라지는 것은 Windows 보안 앱의 스마트 앱 컨트롤 설정에서
스마트 앱 컨트롤을 끄는 것입니다(시험한 중국어 번체 Windows에서의 경로: Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定).
시험에서는 "끄기"를 선택하자 다시 시작하지 않아도 즉시 적용되었고,
그 뒤 설치 관리자가 설치되었습니다. 이는 PC 전체에 적용되는 설정이며
여기서 변경을 요구하는 것은 아닙니다. 그것은 본인이, 관리되는 PC라면 관리자가 결정할 일입니다.

다시 켤 수 있는지도 먼저 알아 둘 만합니다. Microsoft FAQ에 따르면
최근 Windows 업데이트에서는 Windows를 새로 설치하지 않고도 스마트 앱 컨트롤을 다시 켤 수 있으므로,
그렇지 않은 버전에서는 한 번 끄면 영구적일 수 있습니다. 여기서 시험한 빌드에서는 "끄기" 후에도 다시
"켬" 옵션이 계속 제공되었습니다. 이는 시험 결과일 뿐 사용 중인 버전에 대한 보장이 아닙니다.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## 설치

패키지는 세 가지이며 모두 `installer\Build-Package.ps1`로 빌드합니다(사용자별
패키지는 `-PerUser`를 붙입니다).

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| 설치 대상 | 모든 계정 | 설치하는 계정 | - |
| 파일 탐색기 오른쪽 클릭 메뉴 | 예 | 예, 기존 메뉴만([아래](#사용자별-패키지)) | 아니요 |
| 시작 메뉴 항목 | 예 | 예 | 아니요 |
| 관리자 권한 필요 | 예 | 아니요 | 아니요 |
| 제거 | 설정의 *설치된 앱* | 설정의 *설치된 앱* | 폴더 삭제 |

*설치된 앱*은 Windows 11에서 쓰는 이름입니다. Windows 10에서는 같은 페이지를 *앱 및 기능*이라고 하며,
Windows 7에서는 Control Panel(제어판)의 *Programs and Features*(프로그램 및 기능)입니다.

Windows 자체와 맞는 패키지를 사용하십시오. 32비트 Windows에는 x86, 64비트 Windows에는 x64, Arm용 Windows에는 arm64입니다(arm64 패키지는 빌드되지만
실행해 본 적은 없습니다). x86 셸 확장은 32비트이고 64비트 파일 탐색기는
이를 로드할 수 없습니다. 그래서 64비트 Windows에서 x86 `-user.msi`는 오른쪽 클릭 메뉴가
전혀 없고, x86 `.msi`는 Windows 11에서만, 그리고 Windows 11 패키지를 등록한 계정(설치한 계정 또는
아래의 `-Register`를 실행한 계정)에서만 메뉴가 나타납니다.

MSI는 항상 `Program Files\7-ZSTar`에 설치됩니다. 사용자별
패키지와 달리 폴더를 고를 수 없고, 명령줄의 `INSTALLFOLDER`도 무시합니다.
그 폴더에는 설치 관리자가 SYSTEM 권한으로 실행하는 스크립트와
모든 사용자의 파일 탐색기가 로드하는 DLL이 들어 있는데, 다른 곳(예를 들어 `C:\` 아래)에 만든 폴더는 모든 사용자가 쓸 수 있기 때문입니다.
MSI는 자체 셸 확장 CLSID와 자체 `Software\7-ZSTar` 레지스트리 하이브를 등록하고,
모든 컨텍스트 메뉴 키 이름을 `7-ZSTar`로 지으므로
공식 7-Zip과 충돌하지도, 공식 7-Zip을 제거하지도 않습니다. [installer/GUIDS.md](../../installer/GUIDS.md)를 보십시오.

MSI는 일반적인 설치 마법사(welcome, licence, setup type, optional feature tree, finish - 시작, 사용권, 설치 유형, 선택 기능 트리, 마침)를 실행합니다. 조용한 설치도 그대로 동작합니다
(`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`). 자동(quiet) 모드에서는 msiexec가
UI 시퀀스 전체를 건너뛰기 때문입니다. 마법사는 다른 언어로 설정된 Windows에서도
영어로만 표시되며(중국어 번체 Windows 10에서 확인했고, `.msi`에는 다른 언어가 들어 있지 않습니다),
마침 페이지에는 *Launch 7-ZSTar File Manager*가 기본으로 선택되어 있습니다.

### Windows 11 오른쪽 클릭 메뉴

Windows 11에서 7-ZSTar 항목은 공식 7-Zip과 WinRAR가 여전히 머물러 있는 *추가 옵션 표시* 아래가 아니라 첫 화면 메뉴에 나타납니다. Windows 11은 패키지 ID(package identity)가 있는 셸 확장만 그곳에 나열하므로,
MSI는 프로그램 옆에 ID만 담은 작은 MSIX 패키지를 넣어 두고 설치 중에 등록합니다.
기존 등록도 함께 유지합니다. 메뉴가 한 단계뿐이고
*추가 옵션 표시*가 없는 Windows 10과 Windows 7의 오른쪽 클릭 메뉴에 항목을 넣어 주는 것이 바로 이 등록이며,
예전 컨텍스트 메뉴로 되돌린 사용자에게도 항목이 계속 동작하게 해 줍니다.

이 패키지는 **자체 서명 인증서**로 서명되며, 설치 관리자는 이 인증서를
`LocalMachine\TrustedPeople`에 넣습니다. Windows는 서명을 신뢰할 수 있는 무언가로 연결할 수 없는
패키지를 배포하지 않기 때문입니다. 제거하면 패키지와 함께 인증서도 삭제됩니다. Windows 10과 Windows 7에서는 설치 관리자가
둘 다 하지 않습니다. 인증서를 추가하지도, 패키지를 등록하지도 않으며
기존 등록만으로 메뉴가 나타납니다.

자체 서명 인증서를 신뢰하고 싶지 않다면 그 부분만 거부하고
나머지는 그대로 사용할 수 있습니다.

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

그러면 기존 메뉴만 생기므로, Windows 11에서 7-ZSTar 항목은 오른쪽 클릭
메뉴의 *추가 옵션 표시* 아래에 나타납니다. 첫 화면 항목을 나중에 켜거나, 일반 설치 후에 되돌리려면 다음을 사용합니다.

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

이 인증서를 신뢰하면 같은 키로 서명된 **다른** 패키지도 Windows가 경고 없이
받아들이게 됩니다. 이 인증서는 이 패키지 하나에만 사용되고 제거하면 함께 삭제되지만,
동의하는 내용은 그런 것입니다. 위의 `SPARSE=0`이 이를 거부하는 방법입니다.

패키지 등록은 사용자별로 이루어지며, 설치 관리자는 설치한 사용자에 대해서만 이를 실행합니다.
그 결과는 두 가지입니다.

- 같은 컴퓨터의 두 번째 계정은 같은 스크립트를 `-Register`로 실행하기 전까지는
  기존 메뉴만 보입니다.
- 제거하면 제거하는 사용자의 등록만 해제됩니다. 다른 사람이 등록했다면 그 사람의 등록은
  제거 후에도 남아서 더 이상 없는 폴더를 가리킵니다. 그 계정은
  `Get-AppxPackage 7-ZSTar | Remove-AppxPackage`로 정리합니다.

**알려진 제한: 첫 화면 메뉴는 설치가 대화형 로그인 세션에서 실행될 때만 등록됩니다.**
원격이나 비대화형 세션에서 모든 사용자용 `.msi`를 설치하면(SSH를 통하거나 관리 도구의 조용한 배포 등)
성공으로 보고되지만 Windows 11 패키지는
등록되지 않으므로 *추가 옵션 표시* 아래의 기존 메뉴만 나타납니다.
시험에서 SSH 세션(세션 0)의 `msiexec /i ... /qn`은 0으로 종료했지만
`Setup-ShellIntegration.ps1`은 `registration failed: 0x80070005`
(액세스가 거부되었습니다.)를 보고했습니다. 같은 `.msi`를 관리자의 콘솔
세션에서 설치했을 때는 정상적으로 등록되었습니다.

`-Status`는 무엇이 갖춰져 있고 무엇이 없는지 출력합니다.

### 사용자별 패키지

`7-ZSTar-<version>-<arch>-user.msi`는 현재 계정에만 설치되며, 설치 위치는
`%LOCALAPPDATA%\Programs\7-ZSTar`이고 사용자 계정 컨트롤 창이 뜨지 않습니다. 등록하는 모든 것은
`HKCU` 아래로 들어가며, 이 패키지는 `HKLM`에 아무것도 쓰지 않습니다(Windows Installer 자체의 관리 정보는 제외).
컴퓨터 단위 패키지처럼 하지 못하는 점은 다음과 같습니다.

- **Windows 11 첫 화면 메뉴 없음.** Windows 11에서 7-ZSTar는 오른쪽 클릭 메뉴의
  *추가 옵션 표시* 아래에 있습니다. 첫 화면 항목에는 자체 서명 인증서를
  컴퓨터 전체에서 신뢰해야 하고 이는 관리자 권한이 필요합니다. Windows 11에서 측정한 결과,
  `CurrentUser\TrustedPeople`의 인증서로는 Windows가 패키지를
  배포하기에 충분하지 않았습니다. 그래서 사용자별 패키지에서는 이를 뺐습니다.
- **컴퓨터당 둘 중 하나만.** 각 패키지는 다른 패키지가 설치되어 있으면 설치를 거부하므로
  하나를 제거한 뒤 다른 것을 설치하십시오.
  컴퓨터 단위 패키지는 자신을 실행하는 계정의 사용자별 설치만 볼 수 있으므로
  다른 계정의 사용자별 설치는 감지되지 않습니다.
- **그룹 정책이 메뉴를 숨길 수 있습니다.** `EnforceShellExtensionSecurity`가
  설정된 곳에서는 파일 탐색기가 컴퓨터 전체의 *Approved* 키에 나열된 셸 확장만 로드하는데,
  사용자별 설치는 이 키에 쓸 수 없으므로 오른쪽 클릭
  메뉴가 나타나지 않습니다. 그런 곳에서는 컴퓨터 단위 패키지를 사용하십시오.
- **도구 > 옵션 > 시스템에서 형식을 지우면 7-ZSTar가 그 형식에 대해 제공하던 항목도 함께 사라집니다.**
  그곳에서 형식을 지우면(셀이 빌 때까지 클릭한 다음 확인),
  파일 관리자(`7zFM`)는 `HKCU\Software\Classes\.<ext>`와 `7-ZSTar.<ext>` 키 전체를 삭제합니다.
  사용자별 설치에서는 이 키들에 설정 > 앱 > 기본 앱 및 *연결 프로그램* 목록용으로 패키지가 등록한 내용도 들어 있습니다.
  그러면 7-ZSTar가 해당 형식의 *연결 프로그램*에서 빠지고, 기본 앱에는 그 형식에 대해 빈 항목이 나타납니다.
  설치를 복구하면 되돌아옵니다(`.msi`를 다시 실행하고 *Repair*(복구)를 선택).
  더 좋은 방법은 파일 관리자가 아니라 기본 앱에서 파일 형식을 지정하는 것입니다.
  컴퓨터 단위 패키지도 한 곳에서는 같은 약점이 있으며,
  아래의 파일 연결에서 설명합니다.

### 파일 연결과 제거 시 연결에 일어나는 일

**설정 > 앱 > 기본 앱에서 지정하십시오.** Windows 11에서는 그곳에 7-ZSTar를 입력하면
7-ZSTar가 열 수 있는 모든 형식이 나열되어 지정할 수 있습니다. Windows 10에서는 그 페이지의
*Set defaults by app*(앱별 기본값 설정) 아래에 7-ZSTar가 나열되며, *Manage*(관리)를 누르면 형식이 표시됩니다.
Windows 7에는 설정 앱이 없습니다. 7-ZSTar는 Control Panel > Default Programs > *Set your default programs*
(제어판의 기본 프로그램, 그 안의 기본 프로그램 설정)에
나열되며, 이 문서에서 말하는 기본 앱이 그곳에서는 이것을 가리킵니다.
그 두 페이지에서 형식을 지정하는 것은 테스트하지 않았습니다. 설치 관리자는 7-ZSTar를 기본 프로그램 응용 프로그램으로 등록합니다. 형식마다 아이콘과 열기 명령이 있는 ProgID,
각 확장명의 *연결 프로그램* 목록 항목, Windows가 읽는 Capabilities 블록입니다.
그러나 어떤 파일 형식도 의도적으로 차지하지 않습니다. 어떤 프로그램으로 압축 파일을 열지는
사용자가 결정할 일이며, 그래서 7-ZSTar와 공식
7-Zip이 서로 방해하지 않습니다. 그래도 다른 프로그램이 열겠다고 나서지 않는 형식은 Windows가 알아서 7-ZSTar로 보낼 수 있습니다.
테스트한 Windows 10과 Windows 7 PC에서는 다른 프로그램이 `.7z`를 등록하지 않은 상태였는데,
`.7z` 파일에 7-ZSTar의 아이콘이 표시되었고 Windows가 사용할 프로그램을 묻지 않고 더블클릭하면 7-ZSTar에서 열렸습니다.

**파일 관리자의 도구 > 옵션 > 시스템은 Windows 11에서 대부분 동작하지 않으며**,
이는 여기의 버그가 아니라 Windows의 규칙입니다. 이 설정은
`HKCU\Software\Classes`에 `7-ZSTar.<ext>` ProgID를 쓰는데, 컴퓨터가 이미 알고 있는 확장명(모든 압축 형식이 그렇습니다)에 대해서는 Windows 11이 이를 무시합니다.
`AssocQueryString`은 `Unknown`을 반환하고 파일 탐색기는 빈 일반 아이콘을 그립니다.
Windows 11이 대신 따르는 것은 Windows만 계산할 수 있는 해시가 찍힌 `UserChoice` 키이며,
그래서 그곳에서는 설정 UI가 유일한 경로입니다. 어떤 응용 프로그램도 이 키를 쓸 수 없습니다.
7-ZSTar도, 7-Zip도, 어떤 설치 관리자도 마찬가지입니다. Windows 10과 Windows 7은 시험에서 다르게 동작했습니다.
파일 관리자에서 `.7z`와 `.zst`를 다른 프로그램을 고르지 않은 채 지정하자
`AssocQueryString`이 둘 모두에 대해 `7zFM.exe`를 반환했습니다.

**모든 사용자 열에서 형식을 지우면 컴퓨터 단위 패키지가 그 형식에 대해 등록한 자체 항목이 제거됩니다.**
그 열은 `HKLM\Software\Classes`에 쓰며, 컴퓨터 단위 패키지는 이곳에 자신이 알리는 ProgID와
*연결 프로그램* 항목을 보관합니다. 그곳에서 형식을 지우면(파일 관리자를 관리자 권한으로 실행해야 합니다)
이 키들이 통째로 삭제되고, 모든 계정에 영향을 줍니다. 사용자별 패키지에서는 복구하면 같은 키가 복원되었으며,
컴퓨터 단위 패키지에서는 측정하지 않았습니다.

**무엇을 바꾼 뒤에도 아이콘이 계속 비어 있다면** 파일 탐색기의
아이콘 캐시 때문일 수도 있습니다. 이 캐시는 이미 캐시한 DLL이 교체된 것을 알아차리지 못하며,
`ie4uinit.exe -show`로는 안정적으로 비워지지 않습니다. 파일 탐색기를 닫고
`%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db`를 삭제한 다음 다시 시작하십시오.

**제거하면 닿을 수 있는 연결이 제거됩니다.** 제거하는 사용자 소유의 `7-ZSTar.*`
ProgID와, 여전히 그것을 가리키는 파일 형식만 대상이므로, 그 사이에 다른 프로그램에 넘긴 형식은
그대로 둡니다. 컴퓨터 단위 패키지를 제거할 때는 다른 곳에 아직 있는 7-ZSTar 사본을 여는 ProgID도
건드리지 않습니다. 예를 들어 `.zip`의 포터블 사본에서 그 사본 자체의
**도구 > 옵션 > 시스템**으로 설정한 경우입니다. 사용자별
패키지는 그렇게 하지 못합니다. 이 패키지의 ProgID가 바로 그 `HKCU` 키들이므로(위의 *사용자별 패키지*를 보십시오),
제거하면 마지막에 누가 썼든 이를 삭제합니다. 그대로 두면 아이콘과
명령이 삭제된 실행 파일인 ProgID를 그 형식들이 가리키게 되어, 아이콘은 빈 상태가 되고 더블클릭하면 오류가 납니다.
다른 계정의 연결은 닿지 않습니다. 해당 계정은 프로그램이 사라지기 전에
`Setup-ShellIntegration.ps1 -RemoveAssociations`로 자기 연결을 정리할 수 있습니다.
`msiexec /x ... KEEPASSOC=1`은 이 정리를 건너뛰며, 업그레이드는 이를 절대 실행하지 않습니다.

**알려진 제한: 다른 계정은 자신이 설정한 연결을 그대로 유지합니다.**
컴퓨터 단위 패키지를 제거하면 제거를 실행하는 계정이 파일 관리자의
**도구 > 옵션 > 시스템**에서 자기 열(계정 이름이 머리글인 열)에 설정한 것만 정리됩니다.
그곳에 연결을 설정한 다른 계정은 삭제된 프로그램을 가리키는 채로 그대로 두게 되며,
따라서 `.7z` 파일을 더블클릭하면 Windows가 사용할 프로그램을 묻습니다. 각 계정은
제거하기 **전에** 다음으로 자기 연결을 정리해야 합니다.

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

이 명령은 7-ZSTar의 항목만 제거합니다. 아니면 제거 후에 설정 > 앱 > 기본 앱에서
형식을 다시 지정하십시오. 파일 관리자에서 하려면
7-ZSTar가 표시된 자기 열의 각 셀이 빌 때까지 클릭한 다음 확인을 누릅니다. 모두 선택하고 "+"를 누르지 마십시오.
이 동작은 선택한 모든 행에 하나의 상태를 적용하므로 공식 7-Zip 같은 다른 프로그램에 속한 형식까지
지우게 됩니다.

모든 사용자 열에 설정된 연결은 제거 정리 작업이 전혀 건드리지 않으며,
모든 계정이 삭제된 프로그램을 가리키는 채로 남습니다.
설정한 관리자가 있다면 제거하기 전에 파일 관리자를 관리자 권한으로 실행해서 그 셀을 비우고 확인을 눌러야 합니다.
`-RemoveAssociations`는 이 열에 닿지 않습니다. 제거 직전에 비우는 것은
패키지 자체의 등록(위 참조)도 함께 삭제하더라도 문제가 없습니다. 어차피
제거하면 그것도 삭제되기 때문입니다. 사용자별 패키지에는
다른 계정 문제가 없으며, 공식 7-Zip도 똑같이 동작합니다.

## 언어

모든 패키지에는 upstream의 번역 90여 개 언어가 들어 있습니다. **도구 > 옵션 > 언어**에서
고르십시오. MSI에서는 *Custom* 설치(사용자 지정 설치)에서 언어를 제외할 수도 있습니다. 7-ZSTar는 처음 실행할 때 시스템 언어를 따르려고 하지만,
Windows의 "language for non-Unicode programs"(유니코드를 지원하지 않는 프로그램용 언어)와 "사용지역 언어" 설정이 서로 다르면
이 감지는 포기하고 영어로 남습니다. 언어를 직접 고르면 항상 동작합니다.

7-ZSTar가 직접 추가한 문자열, 즉 zstd 수준과 사전 필드, 새 압축 형식 이름에는
upstream 번역이 없어서 영어로 남습니다.
예외는 7-ZSTar 정보 대화 상자의 **후원**과 **웹사이트** 단추입니다. 92개 언어 중 67개 언어에는 각각 해당하는 단어가 있고,
나머지 25개 언어는 영어를 표시합니다
(`Lang/UPSTREAM.md`에 목록이 있습니다).
번역은 이곳에서 작성하지 않고 가져온 것입니다. [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md)를 보십시오.
