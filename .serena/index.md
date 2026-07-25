# Flutter BoilerPlate - Project Index

## Project Structure

```
boiler_plate/
├── app/                          # Flutter 앱 (메인)
├── tools/                        # CLI 도구
├── fastlane/                     # 빌드/배포 자동화
├── docs/                         # 문서
├── webapp/                       # 웹앱 (Landing, Privacy Policy)
└── _bmad/                        # BMAD 워크플로우
```

---

## App Structure (`app/lib/`)

### config/
앱 설정 및 기능 플래그

| File | Description |
|------|-------------|
| `app_config.dart` | 앱 기본 설정 (이름, 버전) |
| `app_feature_config.dart` | 30+ 기능 플래그 ON/OFF |
| `firebase_options.dart` | Firebase 설정 |

### core/
공통 모듈 (서비스, 라우터, 디자인 시스템, 위젯)

#### core/services/
| Service | Description |
|---------|-------------|
| `ad_service.dart` | AdMob 광고 (Banner, Interstitial) |
| `authentication_service.dart` | 생체인증, PIN |
| `firebase_service.dart` | Analytics, Crashlytics |
| `supabase_service.dart` | Supabase 연동 |
| `notification_service.dart` | 로컬/푸시 알림 |
| `in_app_purchase_service.dart` | 구독, IAP |
| `feature_flag_service.dart` | 런타임 기능 플래그 |
| `remote_config_service.dart` | Firebase Remote Config |
| `ab_testing_provider.dart` | A/B 테스트 |

#### core/design/
| Module | Description |
|--------|-------------|
| `design_system.dart` | 디자인 시스템 인터페이스 |
| `design_system_provider.dart` | 디자인 시스템 Provider |
| `material3/` | Material 3 테마 |
| `bold_minimalism/` | Bold Minimalism 테마 |

#### core/widgets/
| Category | Widgets |
|----------|---------|
| `buttons/` | ActionButton, AdaptiveButton, IconButtons |
| `inputs/` | AdaptiveTextField, FormFields, SelectionControls |
| `navigation/` | AdaptiveAppBar, BottomNavBar, DateNavigation |
| `cards/` | CustomCards |
| `lists/` | AdaptiveListTile, InteractiveLists |
| `dialogs/` | AdaptiveDialogs |
| `sheets/` | AdaptiveSheets |
| `loading/` | LoadingIndicator |
| `feedback/` | EmptyState |
| `ads/` | AdContainer |

#### core/state/
| File | Description |
|------|-------------|
| `auth_state.dart` | 인증 상태 (Riverpod) |
| `settings.dart` | 앱 설정 상태 |
| `global_variable.dart` | 전역 변수 |

#### core/
| File | Description |
|------|-------------|
| `router.dart` | GoRouter 라우팅 설정 |
| `error_handler.dart` | 에러 핸들링 |
| `utils.dart` | 유틸리티 함수 |

### data/
데이터 레이어 (DB, Repository)

#### data/core/
| File | Description |
|------|-------------|
| `models/base_model.dart` | 기본 모델 인터페이스 |
| `repositories/base_repository.dart` | 기본 Repository 인터페이스 |
| `repositories/repository_providers.dart` | Repository Providers |

#### data/definitions/
Drift 테이블 정의 (*.dart)

#### data/database/
| File | Description |
|------|-------------|
| `database.dart` | Drift 데이터베이스 설정 |
| `migrations.dart` | DB 마이그레이션 |

#### data/generated/
자동 생성된 모델/리포지토리

### features/
기능별 모듈 (MVVM)

| Feature | Description |
|---------|-------------|
| `auth/` | 인증 (로그인, 생체인증) |
| `home/` | 홈 화면 |
| `settings/` | 설정 화면 |
| `splash/` | 스플래시 화면 |
| `onboarding/` | 온보딩 |
| `subscription/` | 구독 관리 |
| `permission/` | 권한 요청 |

#### Feature 구조
```
features/[name]/
├── models/           # Freezed 모델
├── views/            # UI (ConsumerWidget)
├── view_models/      # Riverpod Notifier
├── widgets/          # Feature 전용 위젯
└── index.dart        # 배럴 파일
```

### domain/
도메인 레이어

| Path | Description |
|------|-------------|
| `actions/` | 비즈니스 액션 (auth, post) |
| `models/` | 도메인 모델 |
| `providers/` | 도메인 Providers |

---

## Tools (`tools/`)

### tools/cli/
Dart CLI 도구

| Command | File | Description |
|---------|------|-------------|
| `./setup` | `setup_command.dart` | 프로젝트 초기 설정 |
| `./rename` | `rename_command.dart` | 프로젝트 이름 변경 **(필수!)** |
| `./build` | `build_command.dart` | 코드 생성 |
| `./test` | `test_command.dart` | 테스트 실행 |

### tools/feature_cli/
Feature 관리 CLI

| Command | Description |
|---------|-------------|
| `./feature status` | 기능 상태 확인 |
| `./feature enable <name>` | 기능 활성화 |
| `./feature disable <name>` | 기능 비활성화 |
| `./feature generate -n <name>` | Feature 스캐폴딩 |

---

## Documentation (`docs/`)

| File | Description |
|------|-------------|
| `00-PREREQUISITES.md` | 설치 요구사항 |
| `01-GETTING_STARTED.md` | 시작 가이드 |
| `02-SPRINT-CHECKLIST.md` | 개발 체크리스트 |
| `guides/TEMPLATE-GUIDE.md` | 템플릿 구조 |
| `guides/FEATURE_MANAGEMENT.md` | 기능 관리 |
| `guides/CLI_TOOLS.md` | CLI 도구 가이드 |
| `guides/FASTLANE_SETUP.md` | Fastlane 설정 |
| `guides/EXTERNAL_SETUP.md` | 외부 서비스 설정 |

---

## Workflows (`_bmad/`)

### Vibe Coding (`_bmad/bmm/workflows/0-vibe-coding/`)
AI와 함께하는 앱 개발 워크플로우

| Phase | Description |
|-------|-------------|
| Phase 1 | Ideation - 아이디어 구체화 |
| Phase 2 | Planning - PRD, 아키텍처 |
| Phase 3 | Scaffolding - 코드 생성 **(rename 필수!)** |
| Phase 4 | Development - AI 페어 프로그래밍 |
| Phase 5 | Launch - 앱스토어 출시 |

---

## Key Files Quick Reference

### Entry Points
- `app/lib/main.dart` - 앱 진입점
- `app/lib/core/router.dart` - 라우팅 설정

### Configuration
- `app/lib/config/app_feature_config.dart` - 기능 플래그
- `app/config/env/.env.debug` - 환경 변수

### Database
- `app/lib/data/database/database.dart` - DB 설정
- `app/lib/data/definitions/` - 테이블 정의

### State Management
- `app/lib/core/state/` - 전역 상태
- `app/lib/features/*/view_models/` - Feature 상태

---

## Generated Files (Do Not Edit!)

| Pattern | Generator |
|---------|-----------|
| `*.freezed.dart` | Freezed |
| `*.g.dart` | JSON Serializable, Riverpod |
| `database.g.dart` | Drift |
