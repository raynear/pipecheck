# 프로젝트 개요 (Project Overview)

> Flutter BoilerPlate - 4주 만에 앱스토어에 출시할 수 있는 Flutter 앱 템플릿

---

## 프로젝트 정보

| 항목 | 값 |
|------|-----|
| **프로젝트명** | Flutter BoilerPlate |
| **Repository 유형** | Monorepo |
| **주요 기술** | Flutter/Dart |
| **아키텍처** | Clean Architecture + MVVM |
| **상태 관리** | Riverpod 3.0 |
| **로컬 DB** | Drift (SQLite) |
| **원격 DB** | Supabase (선택) |
| **자동화** | Fastlane + GitHub Actions |

---

## 목적

이 프로젝트는 새로운 Flutter 앱을 빠르게 개발하기 위한 **보일러플레이트 템플릿**입니다.

### 핵심 가치

1. **빠른 시작**: Fork → Rename → 개발 시작
2. **모듈화**: 30+ 기능 플래그로 필요한 기능만 ON/OFF
3. **자동화**: 코드 생성, 빌드, 배포 자동화
4. **확장성**: Clean Architecture로 유지보수 용이
5. **완성도**: 프로덕션 레벨의 앱 템플릿

---

## 아키텍처 개요

```
┌─────────────────────────────────────┐
│         Presentation Layer          │
│    (Features: Views, ViewModels)    │
├─────────────────────────────────────┤
│          Domain Layer               │
│    (Business Logic: Actions)        │
├─────────────────────────────────────┤
│           Data Layer                │
│  (Repositories, Datasources, DB)    │
└─────────────────────────────────────┘
```

### 레이어별 책임

- **Presentation**: UI 렌더링, 사용자 입력 처리, 상태 표시
- **Domain**: 비즈니스 로직, 유스케이스, 검증 규칙
- **Data**: 데이터 저장, 외부 API 통신, 캐싱

---

## 포함된 기능

### 인증 & 보안

| 기능 | 플래그 | 설명 |
|------|--------|------|
| 생체인증/PIN | `isBiometricAuthEnabled` | 로컬 인증 |
| 이메일 인증 | `isEmailAuthEnabled` | Supabase 이메일 인증 |
| 소셜 로그인 | - | Firebase/Supabase 연동 |

### 백엔드 서비스

| 기능 | 플래그 | 설명 |
|------|--------|------|
| Firebase | `isFirebaseEnabled` | Analytics, Crashlytics, FCM |
| Supabase | `isSupabaseDatabaseEnabled` | DB, Auth, Storage |
| 원격 설정 | `isRemoteConfigEnabled` | Firebase Remote Config |

### 수익화

| 기능 | 플래그 | 설명 |
|------|--------|------|
| AdMob 광고 | `isAdsEnabled` | 배너, 전면, 보상형 광고 |
| 인앱 결제 | `isInAppPurchaseEnabled` | 일회성 구매 |
| 구독 | `isSubscriptionEnabled` | 정기 구독 |

### 알림 & 위젯

| 기능 | 플래그 | 설명 |
|------|--------|------|
| 로컬 알림 | `isNotificationEnabled` | 로컬 푸시 알림 |
| 푸시 알림 | - | FCM 푸시 알림 |
| 홈 위젯 | `isHomeWidgetEnabled` | iOS/Android 홈 위젯 |

### 미디어 & 위치

| 기능 | 플래그 | 설명 |
|------|--------|------|
| 카메라 | `isCameraEnabled` | 카메라 접근 |
| 위치 서비스 | `isLocationEnabled` | GPS, 지오펜싱 |
| 오디오 | - | 녹음, 재생 |

### 기타

| 기능 | 플래그 | 설명 |
|------|--------|------|
| 온보딩 | `isOnboardingEnabled` | 첫 실행 가이드 |
| 다크 모드 | `isDarkModeEnabled` | 테마 전환 |
| 다국어 | `isMultiLanguageEnabled` | i18n 지원 |
| A/B 테스팅 | `isABTestingEnabled` | 실험 기능 |
| 배지 시스템 | `isBadgeSystemEnabled` | 성취 배지 |
| iCloud 동기화 | `isICloudEnabled` | 데이터 동기화 |

---

## 프로젝트 구조

```
boiler_plate/
├── app/                    # Flutter 앱
│   ├── lib/
│   │   ├── config/         # 앱 설정, 기능 플래그
│   │   ├── core/           # 서비스, 라우터, 디자인, 위젯
│   │   ├── data/           # 데이터 레이어
│   │   ├── domain/         # 도메인 레이어
│   │   └── features/       # 기능 모듈
│   └── packages/           # 내부 패키지
│
├── fastlane/               # 빌드/배포 자동화
├── tools/
│   ├── cli/                # Dart CLI (init, setup, deploy 등)
│   └── feature_cli/        # Feature CLI (기능 관리)
├── scripts/                # Shell 래퍼 스크립트
└── docs/                   # 문서
```

---

## 내부 패키지

| 패키지 | 설명 |
|--------|------|
| `authentication` | 인증 공통 로직 |
| `utils` | 유틸리티 함수 |
| `ab_testing` | A/B 테스팅 |
| `geofence_foreground_service` | 지오펜싱 서비스 |
| `flutter_heatmap_calendar` | 히트맵 캘린더 위젯 |

---

## 개발 워크플로우

### 1. 초기 설정

```bash
# Fork & Clone
git clone https://github.com/[username]/my_app.git
cd my_app

# 프로젝트 초기화 (app_config.yaml 기반 이름 변경 + 설정 + 코드 생성)
./init
```

### 2. 기능 관리

```bash
# 기능 상태 확인
./feature status

# 기능 활성화/비활성화
./feature enable ads
./feature disable supabase
```

### 3. 개발

```bash
# 앱 실행
flutter run

# 코드 생성 (모델, DB 변경 시)
./build.sh
```

### 4. 배포

```bash
cd fastlane

# 버전 증가
bundle exec fastlane bump_version type:patch

# 테스트
bundle exec fastlane test

# 배포
bundle exec fastlane deploy
```

---

## 문서 구조

| 문서 | 설명 |
|------|------|
| [README](./README.md) | 문서 진입점 |
| [Prerequisites](./00-PREREQUISITES.md) | 사전 요구사항 |
| [Getting Started](./01-GETTING_STARTED.md) | 빠른 시작 |
| [Sprint Checklist](./02-SPRINT-CHECKLIST.md) | 4주 스프린트 |
| [Technology Stack](./technology-stack.md) | 기술 스택 상세 |
| [Data Models](./data-models.md) | 데이터 모델 |
| [Component Inventory](./component-inventory.md) | 컴포넌트 목록 |
| [Source Tree](./reference/archive/source-tree-analysis.md) | 소스 구조 (아카이브) |

### 가이드

| 문서 | 설명 |
|------|------|
| [Template Guide](./guides/TEMPLATE-GUIDE.md) | 템플릿 구조 |
| [Feature Management](./guides/FEATURE_MANAGEMENT.md) | 기능 관리 |
| [Fastlane Setup](./guides/FASTLANE_SETUP.md) | Fastlane 설정 |
| [External Setup](./guides/EXTERNAL_SETUP.md) | 외부 서비스 |

---

## 빠른 참조

### 핵심 명령어

```bash
# 코드 생성
cd app && ./build.sh

# Feature CLI
./feature status
./feature enable [feature]
./feature disable [feature]
./feature generate -n [name] --full

# Fastlane
cd fastlane
bundle exec fastlane codegen
bundle exec fastlane test
bundle exec fastlane deploy
```

### 주요 설정 파일

| 파일 | 용도 |
|------|------|
| `app/lib/config/app_feature_config.dart` | 기능 플래그 |
| `project.yaml` / `app_config.yaml` / `.env` (루트) | 사용자 편집 설정 (앱 정체성 / 인프라 / 시크릿) |
| `app/config/env/.env.debug` | 자동 생성 산출물 (`project.yaml`/`app_config.yaml`에서 `./build`가 생성 — 손 편집 금지) |
| `app/pubspec.yaml` | 의존성 |
| `fastlane/Appfile` | 앱 정보 |
| `.github/workflows/ci.yml` | CI/CD |

---

## 다음 단계

1. **Fork**: 이 레포지토리를 Fork
2. **Setup**: [Getting Started](./01-GETTING_STARTED.md) 따라 설정
3. **Sprint**: [Sprint Checklist](./02-SPRINT-CHECKLIST.md) 따라 개발
4. **Deploy**: Fastlane으로 배포

---

*생성일: 2026-01-03*
