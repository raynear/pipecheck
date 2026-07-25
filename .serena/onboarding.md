# Flutter BoilerPlate - Onboarding Guide

## Project Overview

Clean Architecture 기반 Flutter 앱 템플릿으로, 새로운 앱 개발을 빠르게 시작할 수 있습니다.

## Quick Start (필수 순서!)

```bash
# 1. 초기 설정
./setup

# 2. 프로젝트 이름 변경 (필수!) ⚠️
./rename my_app_name

# 3. 앱 실행
cd app && flutter run
```

> **중요**: `./rename`은 반드시 기능 개발 전에 실행해야 합니다!

## Architecture

```
Clean Architecture + MVVM
├── Presentation Layer (features/)
│   ├── Views (UI)
│   ├── ViewModels (Riverpod Notifier)
│   └── Widgets
├── Domain Layer (domain/)
│   └── Entities
└── Data Layer (data/)
    ├── Models (Freezed)
    ├── Repositories
    └── Database (Drift)
```

## Tech Stack

| 분류 | 기술 |
|------|------|
| Framework | Flutter 3.x |
| State | Riverpod 3.0 (Generator) |
| Routing | GoRouter |
| Local DB | Drift (SQLite) |
| Code Gen | Freezed, JSON Serializable |
| Build | Fastlane |

## Key Commands

| Command | Description |
|---------|-------------|
| `./setup` | 초기 설정 (SDK 검증 → 의존성 → 코드 생성) |
| `./rename <name>` | 프로젝트 이름 변경 **(필수!)** |
| `./build` | 코드 생성 (Freezed, Drift, Riverpod) |
| `./feature status` | 기능 플래그 상태 확인 |
| `./feature enable <name>` | 기능 활성화 |

## Feature Flags

30+ 기능 플래그로 기능 ON/OFF:

```dart
// lib/config/app_feature_config.dart
static const bool isAuthenticationEnabled = true;
static const bool isAdsEnabled = false;
static const bool isSupabaseDatabaseEnabled = false;
```

## Directory Structure

```
boiler_plate/
├── app/                    # Flutter 앱
│   ├── lib/
│   │   ├── config/         # 앱 설정, 기능 플래그
│   │   ├── core/           # 공통 (서비스, 라우터, 디자인)
│   │   ├── data/           # 데이터 레이어 (DB, Repository)
│   │   └── features/       # 기능별 모듈
│   └── build.sh            # 코드 생성 스크립트
├── tools/
│   ├── cli/                # Dart CLI 도구
│   └── feature_cli/        # Feature 관리 CLI
├── fastlane/               # 빌드/배포 자동화
└── docs/                   # 문서
```

## Adding New Features

```bash
# Feature CLI로 새 기능 생성
./feature generate -n my_feature --full

# 생성되는 구조:
# lib/features/my_feature/
# ├── models/my_feature_model.dart
# ├── views/my_feature_view.dart
# ├── view_models/my_feature_view_model.dart
# └── index.dart
```

## Code Generation

코드 변경 후 반드시 실행:

```bash
cd app && ./build.sh
```

생성되는 파일:
- `*.freezed.dart` - Freezed 모델
- `*.g.dart` - JSON Serializable, Riverpod
- `database.g.dart` - Drift 테이블

## Vibe Coding Workflow

`/vibe` 명령으로 AI와 함께 앱 개발:

```
Phase 1: Ideation     → 아이디어 구체화
Phase 2: Planning     → PRD, 아키텍처
Phase 3: Scaffolding  → 코드 자동 생성 (rename 필수!)
Phase 4: Development  → AI 페어 프로그래밍
Phase 5: Launch       → 앱스토어 출시
```

## Important Notes

1. **프로젝트 이름 변경 필수**: 기능 개발 전 `./rename` 실행
2. **코드 생성**: 모델, ViewModel 변경 후 `./build.sh` 실행
3. **import 경로**: 패키지명으로 import (예: `package:my_app/...`)
4. **Riverpod**: `ref.watch`는 build에서, `ref.read`는 콜백에서
5. **Freezed**: `copyWith` 사용 (immutable)

## Documentation

- [GETTING_STARTED](docs/01-GETTING_STARTED.md)
- [FEATURE_MANAGEMENT](docs/guides/FEATURE_MANAGEMENT.md)
- [CLI_TOOLS](docs/guides/CLI_TOOLS.md)
- [EXTERNAL_SETUP](docs/guides/EXTERNAL_SETUP.md)
