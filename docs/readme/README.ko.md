<!-- translated-from: README.md @ e3fa827 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · **한국어** · [العربية](README.ar.md) · [Esperanto](README.eo.md)

*이 문서는 영어 원문을 번역한 것이며, 내용이 다를 경우 영어 원문을 따릅니다.*

**최신 Windows 11 사용자에게 더 친절한 7-Zip 포크: 오른쪽 클릭 메뉴 첫 번째 단계, zstd 압축, 한 번에 끝나는 tar.zst.**

[다운로드](https://github.com/7zStar/7-ZSTar/releases/latest) · [웹사이트](https://www.7zstar.com) · [변경 내역](../../CHANGELOG.md)

## 7-ZSTar를 쓰는 이유

- **“추가 옵션 표시”는 건너뛰세요.** 모든 사용자용 MSI로 설치하면 7-ZSTar가 Windows 11 오른쪽 클릭 메뉴의 첫 번째 단계에 나타납니다.
- **한 번에, 디스크에 .tar 없이.** tar.zst로 압축하는 것도, 푸는 것도 각각 한 단계로 끝나며 어느 쪽에서도 .tar가 만들어지지 않습니다. 공식 7-Zip은 .tar.zst를 만들 수 없고, 풀 때는 .tar를 거치는 두 단계가 필요합니다.
- **7z보다 10배 빠릅니다.** 실제 프로젝트 폴더에서 tar.zst는 7z보다 10~18배 빠르게 압축되었습니다.

## 속도

| 폴더 | 파일 수 | 원본 크기 | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1초 / 76.7 MB | 38.4초 / 51.8 MB | **3.8초** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6초 / 107.8 MB | 54.8초 / 65.7 MB | **3.6초** / 83.4 MB |
| Python `.venv`(큰 바이너리 포함) | 11,654 | 671 MB | 25.5초 / 249.5 MB | 100.8초 / 167.2 MB | **5.6초** / 210.9 MB |

tar.zst는 zip보다 15~23% 작았고 속도도 뒤지지 않았습니다. 다만 7z보다는 15~27% 크므로, 파일 크기가 가장 중요하다면 7z가 여전히 낫습니다. 이 수치는 압축 기준이며, 압축 해제는 세 가지 모두 걸린 시간이 비슷했습니다.

zip, 7z, tar.zst 모두 기본 설정입니다. 7-ZSTar 26.05.1 x64(7z.exe), PC 한 대(Intel Core Ultra 7 155H, NVMe SSD), 실제 프로젝트 폴더 3개, 3회 측정의 중앙값, 2026-11.

## 지원 형식

- **한 번에 압축(8가지):** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **한 번에 압축 해제(10가지):** 위 8가지에 tar.lzma와 tar.Z를 더한 것
- **추가된 코덱:** zstd, brotli, lz4, lz5, lizard는 각각 독립 형식으로도, .7z 안의 방식으로도 쓸 수 있으며, fast-lzma2는 LZMA2 인코더의 대안으로 들어 있습니다.
- 7-Zip이 이미 지원하던 형식은 모두 그대로 있습니다.

tar.br, tar.lz4, tar.lz5, tar.liz, tar.Z를 풀 때도 사용자에게는 여전히 한 단계이지만, 7-ZSTar가 먼저 임시 파일로 디코딩한 뒤 작업이 끝나면 그 파일을 삭제합니다.

## 명령줄

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

PowerShell에서는 형식 스위치를 `7z a "-ttar.zst" backup.tar.zst docs`처럼 따옴표로 묶으십시오. 따옴표가 없으면 PowerShell이 `-ttar.zst`를 둘로 나눠서 7z가 `.zst`라는 이름의 파일을 만듭니다. 명령 프롬프트(cmd)에서는 따옴표가 필요 없습니다.

## 다운로드와 설치

| | 모든 사용자용 `.msi` | 현재 사용자용 `-user.msi` | 설치 없이 쓰는 `.zip` |
|---|---|---|---|
| 설치 대상 | PC의 모든 계정 | 현재 계정 | 설치 필요 없음 |
| 관리자 권한 필요 | 예 | 아니요 | 아니요 |
| 오른쪽 클릭 메뉴 | Windows 11 첫 번째 단계 | 클래식 메뉴(Windows 11에서는 “추가 옵션 표시” 안) | 없음 |
| 시작 메뉴 항목 | 있음 | 있음 | 없음 |

패키지마다 x64, x86, arm64가 있으니 사용 중인 Windows에 맞는 것을 고르십시오. 64비트 Windows에서 x86 패키지를 설치하면 오른쪽 클릭 메뉴가 없을 수 있습니다. arm64 빌드는 아직 실제 기기에서 실행해 보지 않았습니다. 7-ZSTar는 공식 7-Zip과 나란히 설치되며 서로 영향을 주지 않습니다.

**Windows가 이 다운로드에 대해 경고할 수 있습니다.** 설치 관리자와 프로그램은 인증 기관의 코드 서명을 받지 않았으므로, 처음 실행할 때 Microsoft Defender SmartScreen이 경고와 함께 막을 수 있습니다. 스마트 앱 컨트롤(Smart App Control)이 켜진 Windows 11 PC에서는 `.msi` 설치 관리자가 계속할 방법 없이 아예 차단됩니다. 그렇다고 파일에 문제가 있다는 뜻은 아닙니다. 모든 릴리스에는 `SHA256SUMS` 파일이 함께 있으며, 이를 이용해 내려받은 파일이 게시된 파일과 일치하는지 확인할 수 있습니다. 확인 방법, 스마트 앱 컨트롤이 사용자에게 미치는 영향, 일치하는 것을 확인한 뒤 계속 진행하는 방법은 [docs/install/INSTALL.ko.md](../install/INSTALL.ko.md#서명되지-않은-패키지-smartscreen-및-스마트-앱-컨트롤)에 있습니다.

**첫 번째 단계 메뉴에 대해:** Windows 11은 패키지 ID가 있는 프로그램만 첫 번째 단계에 올려 주므로, Windows 11에서 모든 사용자용 MSI는 자체 서명 인증서로 서명한 작은 MSIX 패키지를 설치하고 그 인증서를 신뢰하도록 등록합니다. 제거하면 둘 다 삭제됩니다. 신뢰하고 싶지 않다면 `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`으로 설치하십시오. 그러면 메뉴는 “추가 옵션 표시” 안에 남습니다. 이 패키지는 설치 관리자를 실행한 계정에만 등록되며, 다른 계정은 따로 등록해야 합니다.

파일 연결과 제거 방법을 포함한 자세한 내용은 [docs/install/INSTALL.ko.md](../install/INSTALL.ko.md)에 있습니다.

## 알려진 제한 사항

- **셸 통합 확인란의 선택을 해제하면 오른쪽 클릭 등록이 삭제됩니다.** 파일 관리자(`7zFM`)의 **도구 > 옵션 > 7-ZSTar**에는 "7-ZSTar 탐색기 메뉴 사용"이라는 확인란이 있습니다. 공식 7-Zip과 마찬가지로 선택을 해제하면 설치 관리자가 만든 셸 확장의 등록(`CLSID` 키)이 삭제되어 7-ZSTar 항목이 오른쪽 클릭 메뉴에서 사라집니다. 모든 사용자용 패키지는 파일 관리자를 관리자 권한으로 실행하면 확인란을 다시 선택할 수 있습니다. 현재 사용자용 패키지는 그럴 수 없습니다. 다시 선택하면 "액세스가 거부되었습니다."가 표시되고 항목은 돌아오지 않습니다. 되돌리려면 처음에 쓴 `.msi`를 다시 실행하고 *Repair*(복구)를 선택하십시오.
- **첫 번째 단계 메뉴는 대화형으로 로그인한 세션에서 설치할 때만 등록됩니다.** 모든 사용자용 `.msi`를 원격 세션이나 비대화형 세션(SSH, 또는 관리 도구를 통한 자동 배포)에서 설치하면 성공했다고 표시되지만 Windows 11 패키지는 등록되지 않으므로, “추가 옵션 표시” 안의 기존 메뉴만 나타납니다. 자세한 내용은 [docs/install/INSTALL.ko.md](../install/INSTALL.ko.md#windows-11-오른쪽-클릭-메뉴)에 있습니다.

## 시스템 요구 사항

Windows 7 또는 Windows Server 2008 R2 이후 버전(x64, x86), arm64에서는 Windows 10 이후 버전. 따로 설치할 것은 없습니다. 이 하한선은 패키지가 요구하는 조건에서 나온 것입니다. 테스트는 모두 64비트인 Windows 7 SP1(이후 업데이트 적용), Windows 10 22H2, Windows 11에서 했으며, Windows 8과 8.1, 32비트 Windows, Windows Server, arm64 하드웨어에서는 하지 않았습니다. Linux에서는 직접 컴파일하는 명령줄 빌드가 있으며, macOS는 지원하지 않습니다.

## 이 프로젝트에 대해

7-ZSTar는 최신 Windows 11 사용자에게 더 친절한 7-Zip 포크입니다. 7-Zip의 핵심은 훌륭하지만, 요즘 사람들이 일하는 방식을 따라가지 못한 부분이 있습니다. Windows 11은 7-Zip을 “추가 옵션 표시” 뒤에 숨기고, 7-Zip은 zstd로 압축하지 못합니다. 7-ZSTar는 그 빈틈을 채우고 나머지는 익숙한 그대로 둡니다.

## 문서

모든 패키지에는 공식 7-Zip의 도움말 파일 `7-zip.chm`이 수정 없이 들어 있으며, **도움말 > 도움말 항목**이나 F1 키로 열 수 있습니다. 내용은 처음부터 끝까지 “7-Zip”으로 쓰여 있고 7-ZSTar가 추가한 기능은 다루지 않습니다. 그 부분은 이 페이지와 [CHANGELOG.md](../../CHANGELOG.md)를 보십시오.

도움말 파일이 실행 파일 옆에 없으면, 같은 메뉴 항목이 대신 이 섹션을 온라인으로 엽니다.

## 빌드

[build/README.md](../../build/README.md)를 보십시오. 요약하면 VS2022 Build Tools(MSVC v143)를 설치한 뒤 `pwsh build\Build.ps1`을 실행합니다. 새 업스트림 릴리스를 병합하기 전에는 [MAINTAINING.md](../../MAINTAINING.md)를 읽으십시오.

<a id="donate"></a>

## 후원

7-ZSTar는 후원하지 않아도 무료로 쓸 수 있습니다. 시간을 아껴 주었고 고마움을 전하고 싶다면 아래 주소로 암호화폐를 보내 주세요. 후원금은 저, DraftingDreamer에게 전달되어 제 개인 개발 비용에 쓰이며, 기능이나 지원, 앞으로의 계획에 대한 약속을 사 주는 돈은 아닙니다.

Ethereum이나 Polygon 네트워크의 토큰이면 무엇이든 받습니다. ETH, POL, USDT, USDC 등 어느 것이든 좋습니다. 두 네트워크의 주소는 같습니다.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="후원 주소 QR 코드">

- Ethereum(ERC20)과 Polygon 네트워크의 전송만 받습니다. 둘 다 쓸 수 있다면 보통 Polygon이 수수료가 더 낮습니다.
- 공식 주소는 이것 하나뿐이며, 다른 주소로 보내 달라고 요청하는 일은 절대 없습니다.
- 전송은 되돌릴 수 없으므로 환불도 할 수 없습니다.

GitHub에서 7-ZSTar에 별을 눌러 주시거나 친구에게 소개해 주시는 것도 도움이 됩니다.

## 라이선스

LGPL v3이며 [LICENSE](../../LICENSE)를 보십시오. 일부는 다른 조건이 적용됩니다. 예를 들어 RAR 압축 해제에는 unRAR 제한이 있으므로, RAR 지원이 포함된 빌드는 순수한 LGPL v3가 아닙니다. 전체 목록은 [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md)에, 모든 구성 요소의 저작권 고지는 [NOTICE](../../NOTICE)에 있습니다.

## 감사의 말

7-ZSTar는 많은 분들의 어깨 위에 서 있습니다. 7-Zip과 압축 알고리즘, 그리고 오픈 소스 전반에 시간을 쏟아 주신 모든 분께 감사드립니다. 여러분이 없었다면 이 소프트웨어는 존재하지 않았을 것입니다.
