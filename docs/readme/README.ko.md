<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · **한국어** · [Italiano](README.it.md) · [Polski](README.pl.md) · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

*영어판과 내용이 다를 경우 영어판을 따릅니다.*

**최신 Windows 11 사용자에게 더 친절한 7-Zip 포크: 오른쪽 클릭 메뉴 첫 화면, zstd 압축, 한 번에 끝나는 tar.zst.**

[다운로드](https://github.com/7zStar/7-ZSTar/releases/latest) · [웹사이트](https://www.7zstar.com) · [변경 내역](../../CHANGELOG.md)

## 7-ZSTar를 쓰는 이유

- **“추가 옵션 표시”는 이제 건너뛰세요.** Windows 11에서 7-ZSTar는 오른쪽 클릭 메뉴 첫 화면에 바로 있습니다.
- **tar.zst를 한 번에.** 폴더를 .tar.zst로 압축하거나 .tar.zst를 푸는 일이 모두 한 번에 끝나며, 디스크에 .tar가 남지 않습니다. 공식 7-Zip은 .tar.zst를 만들 수 없고, 풀 때도 .tar를 거치는 두 단계가 필요합니다.
- **7z보다 약 10배 빠릅니다.** 실제 프로젝트 폴더에서 tar.zst 압축이 10~18배 빨랐습니다.

## 속도

| 폴더 | 파일 수 | 원본 크기 | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1초 / 76.7 MB | 38.4초 / 51.8 MB | **3.8초** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6초 / 107.8 MB | 54.8초 / 65.7 MB | **3.6초** / 83.4 MB |
| Python `.venv`(큰 바이너리 포함) | 11,654 | 671 MB | 25.5초 / 249.5 MB | 100.8초 / 167.2 MB | **5.6초** / 210.9 MB |

tar.zst 파일은 zip보다 15~23% 작았고 속도도 뒤지지 않았습니다. 가장 작은 파일은 여전히 7z가 만들지만(tar.zst가 15~27% 더 큼) 시간은 훨씬 오래 걸렸습니다. 압축을 푸는 데 걸린 시간은 세 형식이 비슷했습니다.

세 형식 모두 기본 설정입니다. 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, NVMe SSD, 3회 측정의 중앙값, 2026-11.

## 지원 형식

- **한 번에 압축:** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **한 번에 풀기:** 위의 모든 형식과 tar.lzma, tar.Z
- **추가된 코덱:** zstd, brotli, lz4, lz5, lizard(단독으로도, .7z 안에서도 사용 가능), 그리고 LZMA2의 다른 인코더인 fast-lzma2
- 공식 7-Zip이 다루는 형식은 모두 그대로 쓸 수 있습니다.

## 다운로드

대부분의 사용자는 [릴리스](https://github.com/7zStar/7-ZSTar/releases/latest) 페이지에서 모든 사용자용 x64 `.msi`를 받으면 됩니다.

| | 모든 사용자용 `.msi` | 현재 사용자용 `-user.msi` | 설치 없이 쓰는 `.zip` |
|---|---|---|---|
| 관리자 권한 필요 | 예 | 아니요 | 아니요 |
| 오른쪽 클릭 메뉴 | Windows 11에서는 첫 화면 | 기존 메뉴(Windows 11에서는 “추가 옵션 표시” 아래) | 없음 |
| Start menu(시작 메뉴) 항목 | 예 | 예 | 아니요 |

각각 x86과 arm64용도 있으니 사용 중인 Windows에 맞는 것을 고르세요. 64비트 Windows에서는 x86 패키지에 오른쪽 클릭 메뉴가 없을 수 있고, arm64 빌드는 아직 실제 하드웨어에서 시험하지 못했습니다. 7-ZSTar는 공식 7-Zip과 나란히 설치되며 서로 영향을 주지 않습니다.

**처음 실행할 때 Windows가 경고를 표시할 수 있습니다.** 파일에 코드 서명이 없어서 SmartScreen이 막을 수 있으며(“Windows의 PC 보호”, 경고를 펼쳐야 “실행”(영어 Windows에서는 “Run anyway”)이 보일 수 있습니다), 스마트 앱 컨트롤을 켠 Windows 11에서는 `.msi`가 아예 차단됩니다. 모든 릴리스에는 내려받은 파일과 대조해 볼 수 있는 `SHA256SUMS` 파일이 있습니다. 확인하는 방법과 스마트 앱 컨트롤에 대한 대처법은 [설치 안내](../install/INSTALL.ko.md#서명되지-않은-패키지-smartscreen-및-스마트-앱-컨트롤)에 있습니다.

**첫 화면 메뉴에 대해:** Windows 11에서 모든 사용자용 `.msi`는 자체 서명 인증서로 서명한 작은 패키지를 함께 추가하고 그 인증서를 신뢰하도록 등록합니다. 첫 화면에 들어가려면 Windows가 이렇게 하도록 요구합니다. 제거하면 둘 다 삭제됩니다. 원하지 않으면 `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`으로 설치하세요. 이 패키지는 설치 프로그램을 실행한 계정에만 등록되며, 다른 계정은 각자 따로 등록합니다.

파일 연결, 제거, 현재 사용자용 패키지에 대해서는 [설치 안내](../install/INSTALL.ko.md)에서 다룹니다.

## 명령줄

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

PowerShell에서는 스위치를 따옴표로 감싸세요: `7z a "-ttar.zst" backup.tar.zst docs`. 따옴표가 없으면 PowerShell이 스위치를 둘로 쪼개서 `.zst`라는 이름의 파일이 만들어집니다. Command Prompt (cmd)(명령 프롬프트)에서는 따옴표가 필요 없습니다.

## 알아 두면 좋은 점

- **“7-ZSTar 탐색기 메뉴 사용”을 끄면**(파일 관리자의 **도구 > 옵션 > 7-ZSTar**) 공식 7-Zip과 마찬가지로 오른쪽 클릭 메뉴 항목이 사라집니다. 모든 사용자용 패키지에서는 파일 관리자를 관리자 권한으로 실행해 다시 켤 수 있습니다. 현재 사용자용 패키지에서는 켤 수 없으며(“액세스가 거부되었습니다.”), `.msi`를 다시 실행해 *Repair*(복구)를 선택하세요.
- **Windows 11에서 자동(silent) 설치나 원격 설치**(SSH를 통하거나 배포 도구로)는 성공하지만 첫 화면 항목은 등록되지 않으므로, 7-ZSTar는 “추가 옵션 표시” 아래에만 나타납니다. [설치 안내에 더 자세한 내용이 있습니다](../install/INSTALL.ko.md#windows-11-오른쪽-클릭-메뉴).
- **tar.br, tar.lz4, tar.lz5, tar.liz, tar.Z를 풀 때**도 사용자에게는 여전히 한 번에 끝나지만, 임시 파일을 거치며 그 파일은 나중에 삭제됩니다.

## 시스템 요구 사항

Windows 7 / Server 2008 R2 이상(x64, x86), arm64에서는 Windows 10 이상. 따로 설치할 것은 없습니다. 64비트 Windows 7 SP1(이후 업데이트 설치), Windows 10, Windows 11에서 테스트했습니다. [테스트한 항목](../install/INSTALL.ko.md#시스템-요구-사항). Linux에서는 직접 컴파일하는 명령줄 빌드가 있으며, macOS는 지원하지 않습니다.

## 문서

**도움말 > 도움말 항목**과 F1은 공식 7-Zip의 도움말 파일인 `7-zip.chm`을 엽니다. 이 파일은 처음부터 끝까지 “7-Zip”이라고만 쓰여 있고 7-ZSTar가 추가한 내용은 다루지 않습니다. 그 내용은 이 페이지와 [변경 내역](../../CHANGELOG.md)에 있습니다. 도움말 파일이 없으면 같은 항목이 이 부분을 온라인으로 엽니다.

7-ZSTar를 직접 빌드하려면 [build/README.md](../../build/README.md)를, 새 upstream 릴리스를 병합하기 전에는 [MAINTAINING.md](../../MAINTAINING.md)를 읽어 보세요.

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
- 블록체인 전송은 되돌릴 수 없으므로 환불도 할 수 없습니다.

GitHub에서 7-ZSTar에 별을 눌러 주시거나 친구에게 소개해 주시는 것도 도움이 됩니다.

## 라이선스

LGPL v3이며, [LICENSE](../../LICENSE)를 보세요. 일부는 다른 조건이 적용됩니다. RAR 압축 해제에는 unRAR 제한이 따르므로 RAR을 지원하는 빌드는 순수한 LGPL v3가 아닙니다. 전체 목록은 [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md)에, 저작권 고지는 [NOTICE](../../NOTICE)에 있습니다.

7-Zip, 압축 알고리즘, 그리고 오픈 소스 전반에 시간을 들여 주신 모든 분께 감사드립니다. 여러분이 없었다면 7-ZSTar도 없었을 것입니다.
