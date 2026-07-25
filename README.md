# Flutter BoilerPlate

Clean Architecture 기반 Flutter 앱 템플릿

## 특징

- **Clean Architecture** + MVVM 패턴
- **Riverpod 3.0** 상태 관리 (코드 생성 방식)
- **Drift** 로컬 데이터베이스 (자동 코드 생성)
- **Dart CLI 도구** 프로젝트 설정, 코드 생성, 테스트 자동화
- **Feature CLI** 기능 관리 및 스캐폴딩
- **Fastlane** 빌드/배포 자동화
- **30+ 기능 플래그** 원터치 ON/OFF

---

## 빠른 시작

```bash
# 1. Template 사용 또는 Clone
git clone https://github.com/[your-username]/boiler_plate.git my_app
cd my_app

# 2. 설정 편집
vi project.yaml      # 프로젝트별 설정 (앱 이름, Bundle ID, 스토어 정보, IAP)
vi app_config.yaml   # 인프라 설정 (플랫폼, 서비스, 서명)

# 3. 프로젝트 초기화
./run init

# 4. 앱 실행
cd app && flutter run
```

> **참고**: `./run init`은 `project.yaml` + `app_config.yaml`을 기반으로 패키지명, 번들 ID 등을 자동 변경합니다.
> Dart SDK >=3.8.0 (Flutter stable 최신 권장)을 요구합니다.
>
> **배포까지의 최단 경로는 [docs/quick-start.md](docs/quick-start.md)가 기준입니다.**

---

## 프로젝트 구조

```
boiler_plate/
├── app/                    # Flutter 앱
│   ├── lib/
│   │   ├── config/         # 앱 설정, 기능 플래그
│   │   ├── core/           # 공통 (서비스, 라우터, 디자인)
│   │   ├── data/           # 데이터 레이어 (DB, Repository)
│   │   └── features/       # 기능별 모듈
│
├── tools/
│   ├── cli/                # Dart CLI 도구 (init, setup, rename, build, deploy 등)
│   └── feature_cli/        # Feature CLI (기능 관리, 스캐폴딩)
│
├── fastlane/               # 빌드/배포 자동화
├── docs/                   # 문서
├── project.yaml            # 프로젝트별 고유 설정 (SSOT)
├── app_config.yaml         # 보일러플레이트 공통 설정
└── run                     # 통합 CLI 실행기
```

---

## 핵심 명령어

### CLI 도구 (./run)
```bash
./run init                    # 프로젝트 초기화 (project.yaml + app_config.yaml 기반)
./run build                   # Freezed, Drift, Riverpod 코드 생성
./run test                    # 테스트 실행 및 커버리지 리포트
./run deploy                  # 원버튼 배포 (preflight → build → upload)
./run feature status          # 기능 상태 확인
./run feature enable ads      # 광고 활성화
./run feature generate -n profile --full  # 새 Feature 생성
./run --help                  # 전체 명령어 확인
```

### Fastlane (선택 — 개별 레인 실행)
```bash
cd fastlane
bundle exec fastlane codegen        # 코드 생성
bundle exec fastlane test           # 테스트
```

> 통합 배포는 fastlane 레인이 아니라 `./run deploy`(= `./deploy`)를 사용합니다.

> 모든 CLI 명령은 `./run <명령어> --help`로 사용법을 확인할 수 있습니다.

---

## 포함된 기능

| 카테고리 | 기능 | 플래그 |
|---------|------|--------|
| 인증 | 생체인증/PIN | `isBiometricAuthEnabled` |
| 인증 | 이메일/소셜 | `isEmailAuthEnabled` |
| 백엔드 | Firebase | `isFirebaseEnabled` |
| 수익화 | 광고 | `isAdsEnabled` |
| 수익화 | 구독/IAP | `isSubscriptionEnabled` |
| 기능 | 알림 | `isNotificationEnabled` |
| 기능 | 온보딩 | `isOnboardingEnabled` |

---

## 기술 스택

| 분류 | 기술 |
|------|------|
| **Framework** | Flutter 3.x |
| **상태 관리** | Riverpod 3.0 |
| **라우팅** | GoRouter |
| **로컬 DB** | Drift (SQLite) |
| **코드 생성** | Freezed, JSON Serializable |
| **자동화** | Fastlane |

---

## 문서

| 문서 | 설명 |
|------|------|
| [quick-start](docs/quick-start.md) | **골든 패스: clone → deploy 최단 경로** |
| [PREREQUISITES](docs/00-PREREQUISITES.md) | 설치 요구사항 |
| [GETTING_STARTED](docs/01-GETTING_STARTED.md) | 시작 가이드 |
| [SPRINT-CHECKLIST](docs/02-SPRINT-CHECKLIST.md) | 개발 체크리스트 |
| [TEMPLATE-GUIDE](docs/guides/TEMPLATE-GUIDE.md) | 아키텍처, 코드 패턴 |
| [CLI_TOOLS](docs/guides/CLI_TOOLS.md) | CLI 도구 사용법 |
| [FEATURE_MANAGEMENT](docs/guides/FEATURE_MANAGEMENT.md) | 기능 관리 |
| [FASTLANE_SETUP](docs/guides/FASTLANE_SETUP.md) | 배포 자동화 |
| [EXTERNAL_SETUP](docs/guides/EXTERNAL_SETUP.md) | 외부 서비스 설정 |

---

## 라이선스

MIT License
