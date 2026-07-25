# CLI 도구 사용법

> 통합 CLI(`./run`)를 사용한 프로젝트 관리 가이드

---

## 목차

1. [개요](#개요)
2. [명령어 레퍼런스](#명령어-레퍼런스)
   - [init](#init)
   - [build](#build)
   - [test](#test)
   - [deploy](#deploy)
   - [feature](#feature)
3. [기타 명령어](#기타-명령어)
4. [공통 옵션](#공통-옵션)
5. [문제 해결](#문제-해결)

---

## 개요

Flutter BoilerPlate 프로젝트는 `./run` 통합 CLI를 제공합니다.
모든 명령어는 `./run <명령어> [옵션]` 형식으로 실행합니다.

### CLI 구조

```
./run                     # 통합 CLI 실행기
├── init                  # 프로젝트 초기화
├── build                 # 코드 생성
├── gen-env               # 런타임 env 산출물 생성
├── test                  # 테스트
├── deploy                # 배포
├── deploy-legal          # 법적 문서 호스팅 (--target firebase|github)
├── feature               # 기능 관리
├── preflight             # 배포 전 검증
├── rename                # 이름 변경
├── setup                 # 프로젝트 설정
├── screenshot            # 스크린샷 캡처
├── generate-icon         # 앱 아이콘 생성
├── generate-legal        # 법적 문서 생성
├── generate-privacy      # Apple Privacy Manifest 생성
├── generate-data-safety  # Data Safety 답안지 생성
├── generate-desc         # 스토어 설명 생성
└── iap-register          # IAP 상품 등록

tools/
├── cli/                  # 핵심 CLI 도구 (Dart)
│   ├── bin/              # 실행 가능한 스크립트
│   └── lib/              # 명령어 구현 + 공통 모듈
└── feature_cli/          # Feature CLI (기능 관리, 스캐폴딩)
```

### 도움말 확인

```bash
./run --help              # 전체 명령어 목록
./run init --help         # 개별 명령어 도움말
./run feature --help      # Feature CLI 도움말
```

---

## 명령어 레퍼런스

### init

프로젝트 초기화를 수행합니다. `project.yaml` + `app_config.yaml`을 기반으로 이름 변경, SDK 검증, 의존성 설치, 코드 생성을 한 번에 실행합니다.

#### 사용법

```bash
./run init [옵션]
```

#### 실행 단계

```
1. project.yaml + app_config.yaml 로드
2. 프로젝트 이름/Bundle ID 변경
3. SDK 버전 검증
4. 의존성 설치
5. 코드 생성
6. 환경 파일 생성
```

> **참고**: 프로젝트를 처음 Fork한 후 **가장 먼저** 실행해야 하는 명령입니다.

---

### build

코드 생성을 수행합니다.

#### 사용법

```bash
./run build [옵션]
```

#### 옵션

| 옵션 | 단축 | 설명 |
|------|------|------|
| `--watch` | `-w` | 파일 변경 감지 모드 |
| `--clean` | `-c` | 이전 생성 파일 삭제 |
| `--help` | `-h` | 도움말을 표시합니다 |

#### 생성되는 파일

- `*.freezed.dart` - Freezed 모델
- `*.g.dart` - JSON Serializable, Riverpod
- `database.g.dart` - Drift 데이터베이스

---

### test

테스트를 실행합니다.

#### 사용법

```bash
./run test [옵션]
```

#### 옵션

| 옵션 | 단축 | 설명 |
|------|------|------|
| `--coverage` | `-c` | 커버리지 리포트 생성 |
| `--unit` | | 단위 테스트만 실행 |
| `--integration` | | 통합 테스트만 실행 |
| `--help` | `-h` | 도움말을 표시합니다 |

---

### deploy

원버튼 배포를 수행합니다. Preflight 검증 → Fastlane 빌드 → 업로드까지 자동 실행합니다.

#### 사용법

```bash
./run deploy [옵션]
```

#### 실행 단계

```
1. Preflight 검증
   ├── config ↔ .env 동기화 확인
   ├── SDK 버전 검증
   └── 환경 변수 검증

2. Fastlane 빌드 & 업로드
   ├── 인증서 설정
   ├── 버전 관리
   ├── 빌드 실행 (실시간 진행 상태 표시)
   └── 스토어 업로드
```

---

### feature

기능 플래그 관리 및 Feature 모듈 생성을 수행합니다.

#### 사용법

```bash
./run feature <명령어> [인자] [옵션]
```

#### 명령어

| 명령어 | 별칭 | 설명 |
|--------|------|------|
| `status` | `st` | 현재 기능 상태 표시 |
| `list` | `ls` | 사용 가능한 기능 목록 |
| `enable` | `on` | 기능 활성화 |
| `disable` | `off` | 기능 비활성화 |
| `generate` | `gen` | 새 Feature 모듈 생성 |

#### 예시

```bash
./run feature status                        # 기능 상태 확인
./run feature enable ads                    # 광고 활성화
./run feature disable notification          # 알림 비활성화
./run feature generate -n profile --full    # 전체 구조 생성
```

자세한 내용: [FEATURE_MANAGEMENT.md](./FEATURE_MANAGEMENT.md)

---

## 기타 명령어

| 명령어 | 설명 |
|--------|------|
| `./run setup` | 프로젝트 설정 (이름 변경 없이) |
| `./run rename <이름>` | 프로젝트 이름 일괄 변경 |
| `./run preflight` | 배포 전 환경 검증 (deploy에 포함) |
| `./run gen-env` | 런타임 env 산출물 재생성 (`app/config/env/.env.{debug,profile,release}`) |
| `./run screenshot` | 스크린샷 자동 캡처 (요청 시뮬 없으면 hard-fail, opt-out `--allow-missing-devices`; 캡처 후 PNG 크기 검증) |
| `./run generate-legal` | 개인정보 처리방침, 이용약관 생성 |
| `./run deploy-legal` | 법적 문서 호스팅 — `--target firebase`(기본, `<id>.web.app`) 또는 `--target github`(GitHub Pages, `<owner>.github.io/<repo>`; `legal_hosting: github` 필요). `--dry-run` 지원 |
| `./run generate-icon` | 앱 아이콘 생성 |
| `./run generate-privacy` | Apple Privacy Manifest 생성 (`PrivacyInfo.xcprivacy`, init에 포함) |
| `./run generate-data-safety` | Data Safety 답안지 + 업로드 파일 생성 (Play 답안지 `metadata/data_safety/data_safety.md`, **Play 자동 업로드용 CSV `metadata/data_safety/data_safety.csv`**, iOS `metadata/app_privacy_details.json`). CSV는 `./deploy`(Android)가 `upload_data_safety` 레인으로 androidpublisher dataSafety API에 자동 업로드 — Play Console Data safety 폼 수동 입력 불필요 |
| `./run generate-desc` | 스토어 설명 생성 |
| `./run iap-register` | IAP 상품 등록 (project.yaml 기반) |

---

## 공통 옵션

모든 CLI 명령어에서 사용 가능한 공통 옵션입니다.

| 옵션 | 단축 | 설명 |
|------|------|------|
| `--help` | `-h` | 도움말을 표시합니다 |
| `--verbose` | `-v` | 자세한 로그를 출력합니다 |

---

## 문제 해결

### 명령어가 실행되지 않음

```bash
# 실행 권한 확인
chmod +x run

# 또는 dart로 직접 실행
dart run tools/cli/bin/init.dart
```

### SDK 버전 오류

```bash
flutter upgrade
flutter channel stable && flutter upgrade
```

### 의존성 설치 실패

```bash
flutter clean
flutter pub get
```

### 코드 생성 오류

```bash
cd app
dart run build_runner build --delete-conflicting-outputs
```

### config 변경 후 .env 오래됨

`./run deploy` 실행 시 경고가 표시됩니다. `./run init`을 다시 실행하여 동기화하세요.

---

## 참고 문서

| 문서 | 설명 |
|------|------|
| [01-GETTING_STARTED.md](../01-GETTING_STARTED.md) | 빠른 시작 가이드 |
| [FEATURE_MANAGEMENT.md](./FEATURE_MANAGEMENT.md) | 기능 관리 상세 |
| [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) | 문제 해결 가이드 |
