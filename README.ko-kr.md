# Dev Drive 캐시 마이그레이션 스크립트

다른 언어:
| [English](README.en-us.md) | [简体中文](README.md) | [繁体中文](README.zh-tw.md) | [日本語](README.ja-jp.md) | [한국어](README.ko-kr.md) | [Français](README.fr-fr.md) | [Deutsch](README.de-de.md) | [Italiano](README.it-it.md) | [Español](README.es-es.md) | [Русский](README.ru-ru.md) | [Português (BR)](README.pt-br.md) | [Nederlands](README.nl-nl.md) | [Türkçe](README.tr-tr.md) | [العربية](README.ar-sa.md) | [हिंदी](README.hi-in.md) | [ไทย](README.th-th.md) |

## 소개

[Dev Drive 캐시 마이그레이션 스크립트](https://github.com/jqknono/migrate-to-win11-dev-drive)는 개발자가 다양한 개발 도구의 캐시 디렉터리를 Windows 11의 Dev Drive(ReFS 파일 시스템)로 마이그레이션하여 성능을 향상시키고, 하드 디스크 수명을 연장하며, 디스크 공간 사용량을 줄이는 것을 목표로 하는 대화형 PowerShell 도구입니다.

### 핵심 장점

- **하드 디스크 수명 연장**: 자주 읽고 쓰는 캐시 파일을 Dev Drive로 이동함으로써 시스템 디스크(일반적으로 SSD)에 대한 쓰기 횟수를 줄여 수명을 연장할 수 있습니다.
- **디스크 공간 절약**: 거대한 캐시 파일(Node.js의 `node_modules` 캐시, Python의 pip 캐시 등)을 시스템 디스크에서 이동시켜 귀중한 시스템 디스크 공간을 확보할 수 있습니다.
- **고성능**: Dev Drive의 ReFS 파일 시스템과 최적화 기능을 활용하여 캐시의 읽기/쓰기 속도를 향상시키고, 빌드 및 개발 도구의 응답 속도를 높일 수 있습니다.

### Copy-on-Write (COW) 기술

Dev Drive는 ReFS 파일 시스템을 기반으로 Copy-on-Write (COW) 기술을 활용합니다. COW는 리소스 관리 기술로, 여러 호출자가 동시에 동일한 리소스를 요청할 때 처음에는 동일한 리소스를 공유하는 것이 핵심 아이디어입니다. 특정 호출자가 리소스를 수정해야 할 때만 시스템이 해당 호출자를 위해 리소스의 복사본을 생성하고, 이 복사본을 수정하게 하며 다른 호출자가 사용하는 원본 리소스에는 영향을 주지 않습니다.

Dev Drive 시나리오에서 COW 기술은 다음과 같은 현저한 장점을 제공합니다:

1.  **효율적인 파일 복사**: 큰 파일을 복사해야 할 때 ReFS는 즉시 실제 데이터를 복사하는 대신 동일한 디스크 블록을 가리키는 새 파일 항목을 생성합니다. 소스 파일이나 대상 파일이 수정될 때만 실제로 수정된 데이터 블록을 복사합니다. 이로 인해 파일 복사 작업이 매우 빨라지며 추가 디스크 공간을 거의 사용하지 않습니다(수정이 발생할 때까지).
2.  **디스크 공간 절약**: 많은 유사 파일을 포함하는 캐시 디렉터리(예: 여러 프로젝트가 의존하는 동일한 버전의 패키지)의 경우 COW는 수정되지 않은 데이터 블록을 효과적으로 공유하여 전체 디스크 사용량을 줄일 수 있습니다.
3.  **성능 향상**: 불필요한 데이터 복사 작업을 줄여 파일 작업의 효율성을 높입니다.

### Dev Drive 및 ReFS 기능

Windows 11은 개발자를 위해 최적화된 스토리지 볼륨인 Dev Drive를 도입했습니다. Dev Drive는 파일 시스템으로 Resilient File System(ReFS)을 사용하며 전용 최적화 기능을 활성화합니다.

**ReFS(Resilient File System)**는 마이크로소프트가 개발한 차세대 파일 시스템으로, 기존 NTFS에 비해 다음과 같은 이점이 있습니다:

- **데이터 무결성**: 체크섬 및 자동 복구 기능을 통해 데이터 신뢰성을 향상시킵니다.
- **확장성**: 더 큰 볼륨 및 파일 크기를 지원합니다.
- **성능 최적화**: 가상화 및 빅 데이터 워크로드에 대해 최적화되었습니다.
- **통합 COW**: Copy-on-Write 의미 체계를 기본 지원하며, 이는 개발 시나리오의 파일 작업에 특히 유리합니다.

**Dev Drive 최적화**: ReFS를 기반으로 Dev Drive는 패키지 관리자 캐시, 빌드 출력 등과 같은 시나리오에 대한 성능 향상과 같이 개발자 워크로드를 추가로 최적화합니다.

## 스크립트 기능

이 스크립트는 다음과 같은 주요 기능을 제공합니다:

- **캐시 마이그레이션**: 다양한 개발 도구의 캐시 디렉터리를 Dev Drive로 마이그레이션하는 것을 지원합니다.
  - Node.js (npm, yarn, pnpm)
  - Python (pip)
  - .NET (NuGet)
  - Java (Maven, Gradle)
  - Go (Go modules)
  - Rust (Cargo)
  - VS Code 확장
  - Windows TEMP/TMP 디렉터리
    - JetBrains IDE (IntelliJ, PyCharm 등)
  - Android SDK
  - Chocolatey (Windows 패키지 관리자)
  - 사용자 숨김 폴더 (.xxx)
- **캐시 복원**: Dev Drive로 마이그레이션된 캐시 디렉터리를 원래 위치로 복원합니다.
- **링크 마이그레이션**: 심볼릭 링크/정션 포인트를 생성하여 캐시 디렉터리를 마이그레이션하며, 환경 변수는 수정하지 않습니다.
- **테스트 모드**: 실제 시스템을 수정하지 않고 Dev Drive 삭제와 같은 기능을 테스트하기 위한 안전한 시뮬레이션 작업을 제공합니다.

## 사용 방법

1.  **시스템 요구 사항**:
    - Windows 11 (빌드 22000 이상)
    - PowerShell 7+ (pwsh)
2.  **스크립트 실행**:
    - 관리자 권한으로 PowerShell 7(pwsh)을 엽니다.
    - 스크립트가 있는 디렉터리로 이동합니다.
    - `.\Setup-DevDriveCache.ps1`을 실행합니다.
3.  **대화형 작업**:
    - 스크립트가 시작되면 다양한 작업을 안내하는 대화형 메뉴가 표시됩니다.
    - 캐시 마이그레이션, Dev Drive 생성 또는 삭제 등을 위해 해당 옵션을 선택합니다.
    - 모든 중요 작업은 사용자 확인이 필요하며 안전을 보장합니다.

## 주의 사항

- **목적**: 이 스크립트의 목적은 캐시 폴더를 정리하는 것이 아니라 마이그레이션하는 것입니다. 마이그레이션 후 원본 캐시 데이터는 여전히 존재하며 저장 위치만 변경됩니다.
- **백업**: Dev Drive 삭제와 같은 중요 작업을 수행하기 전에 중요한 데이터를 백업하는 것이 좋습니다.
- **환경 변수**: 스크립트는 사용자 환경 변수를 읽거나 쓰지 않습니다. 마이그레이션은 심볼릭 링크를 통해 완료됩니다.

## 참고 자료

- [Microsoft Dev Drive 공식 문서](https://learn.microsoft.com/en-us/windows/dev-drive/)
- [Resilient File System (ReFS) 공식 문서](https://learn.microsoft.com/en-us/windows-server/storage/refs/refs-overview)

## 지원

- [宁屏去广告](https://www.nullprivate.com)