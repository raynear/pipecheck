# 기술 스택 (Technology Stack)

> Flutter BoilerPlate 프로젝트의 상세 기술 스택 분석

---

## 개요

| 분류 | 기술 | 버전 | 용도 |
|------|------|------|------|
| **Framework** | Flutter | SDK >=3.8.0 | 크로스플랫폼 모바일 개발 |
| **Language** | Dart | 3.x | 프로그래밍 언어 |
| **Architecture** | Clean Architecture + MVVM | - | 코드 구조화 패턴 |
| **State Management** | Riverpod | 3.0.3 | 반응형 상태 관리 |
| **Navigation** | GoRouter | 17.0.1 | 선언적 라우팅 |
| **Local DB** | Drift | 2.21.0 | SQLite ORM |
| **Remote DB** | Supabase | 2.5.9 | 서버리스 백엔드 |
| **Automation** | Fastlane | - | 빌드/배포 자동화 |
| **CI/CD** | GitHub Actions | - | 지속적 통합/배포 |

---

## 핵심 의존성

### 상태 관리 & 코드 생성

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `flutter_riverpod` | ^3.0.3 | 반응형 상태 관리 |
| `riverpod_generator` | ^3.0.3 | Riverpod 코드 생성 |
| `freezed` | ^3.2.3 | Immutable 데이터 클래스 |
| `freezed_annotation` | ^3.1.0 | Freezed 어노테이션 |
| `json_serializable` | ^6.8.0 | JSON 직렬화 |
| `json_annotation` | ^4.9.0 | JSON 어노테이션 |
| `build_runner` | ^2.4.15 | 코드 생성 실행기 |

### 데이터베이스

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `drift` | ^2.21.0 | SQLite ORM (로컬 DB) |
| `drift_sqflite` | ^2.0.1 | Drift SQLite 드라이버 |
| `drift_dev` | ^2.21.0 | Drift 코드 생성 (dev) |
| `supabase_flutter` | ^2.5.9 | Supabase 클라이언트 |
| `shared_preferences` | ^2.5.3 | 간단한 키-값 저장 |
| `flutter_secure_storage` | ^10.0.0 | 보안 저장소 |
| `icloud_storage` | ^2.2.0 | iCloud 동기화 |

### 네비게이션

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `go_router` | ^17.0.1 | 선언적 라우팅 |

---

## Firebase 통합

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `firebase_core` | ^4.3.0 | Firebase 코어 |
| `firebase_analytics` | ^12.1.0 | 앱 분석 |
| `firebase_crashlytics` | ^5.0.6 | 크래시 리포팅 |
| `firebase_messaging` | ^16.1.0 | 푸시 알림 |
| `firebase_remote_config` | ^6.1.3 | 원격 설정 |
| `firebase_in_app_messaging` | ^0.9.0+5 | 인앱 메시징 |

---

## 수익화

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `google_mobile_ads` | ^7.0.0 | AdMob 광고 |
| `in_app_purchase` | ^3.2.0 | 인앱 결제/구독 |
| `in_app_review` | ^2.0.9 | 앱 리뷰 요청 |

---

## 알림

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `awesome_notifications` | ^0.10.1 | 고급 로컬 알림 |
| `flutter_local_notifications` | ^19.0.1 | 로컬 알림 |
| `workmanager` | ^0.9.0+3 | 백그라운드 작업 |
| `home_widget` | ^0.8.0 | 홈 위젯 |

---

## 미디어 & 카메라

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `camera` | ^0.11.0+2 | 카메라 접근 |
| `image_picker` | ^1.1.2 | 이미지 선택 |
| `image` | ^4.5.4 | 이미지 처리 |
| `image_gallery_saver` | ^2.0.3 | 갤러리 저장 |
| `gallery_saver_plus` | ^3.2.8 | 갤러리 저장 (확장) |
| `audioplayers` | ^6.1.0 | 오디오 재생 |
| `flutter_sound` | ^9.28.0 | 오디오 녹음/재생 |
| `audio_waveforms` | ^2.0.1 | 오디오 파형 시각화 |
| `audio_session` | ^0.2.1 | 오디오 세션 관리 |
| `record` | ^6.0.0 | 오디오 녹음 |
| `flutter_soloud` | ^3.1.3 | 고성능 오디오 |
| `simple_audio_trimmer` | ^0.1.4 | 오디오 트리밍 |

---

## 위치 서비스

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `geolocator` | ^14.0.1 | 위치 추적 |
| `google_maps_flutter` | ^2.12.1 | Google 지도 |
| `geofence_foreground_service` | path | 지오펜싱 (내부 패키지) |

---

## UI & 디자인

### 테마 & 스타일

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `flex_color_scheme` | ^8.2.0 | 동적 테마 |
| `google_fonts` | ^6.2.1 | Google Fonts |
| `flutter_vector_icons` | ^2.0.0 | 벡터 아이콘 |
| `cupertino_icons` | ^1.0.8 | iOS 스타일 아이콘 |

### 애니메이션 & 효과

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `flutter_animate` | ^4.5.2 | 선언적 애니메이션 |
| `lottie` | ^3.3.1 | Lottie 애니메이션 |
| `confetti` | ^0.8.0 | 컨페티 효과 |
| `auto_animated` | ^3.2.0 | 자동 애니메이션 |
| `morphing_text` | ^1.0.1 | 텍스트 모핑 |

### 위젯 & 컴포넌트

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `introduction_screen` | ^4.0.0 | 온보딩 화면 |
| `showcaseview` | ^5.0.1 | 튜토리얼 오버레이 |
| `stylish_bottom_bar` | ^1.1.0 | 커스텀 하단 바 |
| `modal_bottom_sheet` | ^3.0.0 | 모달 바텀 시트 |
| `sheet` | ^1.0.0 | 시트 위젯 |
| `top_snackbar_flutter` | ^3.1.0 | 상단 스낵바 |
| `panara_dialogs` | ^0.1.5 | 커스텀 다이얼로그 |
| `numberpicker` | ^2.1.2 | 숫자 선택기 |
| `pin_code_fields` | ^8.0.1 | PIN 입력 |
| `percent_indicator` | ^4.2.5 | 프로그레스 인디케이터 |
| `simple_circular_progress_bar` | ^1.0.2 | 원형 프로그레스 |
| `flutter_spinkit` | ^5.2.1 | 로딩 인디케이터 |
| `smooth_page_indicator` | ^2.0.1 | 페이지 인디케이터 |

### 차트 & 데이터 시각화

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `fl_chart` | ^1.0.0 | 차트 라이브러리 |
| `flutter_heatmap_calendar` | path | 히트맵 캘린더 (내부 패키지) |

---

## 다국어 지원

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `easy_localization` | ^3.0.7 | 다국어 지원 |
| `flutter_localized_locales` | ^2.0.5 | 로케일 이름 |
| `timezone` | ^0.10.0 | 타임존 처리 |

---

## 유틸리티

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `permission_handler` | ^12.0.0+1 | 권한 관리 |
| `package_info_plus` | ^9.0.0 | 앱 정보 |
| `path_provider` | ^2.1.5 | 파일 경로 |
| `path` | ^1.9.1 | 경로 처리 |
| `url_launcher` | ^6.3.1 | URL 실행 |
| `share_plus` | ^12.0.1 | 공유 기능 |
| `file_picker` | ^10.1.9 | 파일 선택 |
| `screenshot` | ^3.0.0 | 스크린샷 캡처 |
| `flutter_dotenv` | ^6.0.0 | 환경 변수 (generated assets — `config/env/.env.*` 산출물 로드) |
| `collection` | ^1.18.0 | 컬렉션 유틸리티 |
| `archive` | ^4.0.7 | 압축 파일 처리 |
| `uuid` | ^4.5.0 | UUID 생성 |
| `http` | ^1.2.2 | HTTP 클라이언트 |
| `logger` | ^2.5.0 | 로깅 |
| `wakelock_plus` | ^1.4.0 | 화면 켜짐 유지 |
| `vibration` | ^3.1.3 | 진동 |
| `flutter_keyboard_visibility` | ^6.0.0 | 키보드 상태 감지 |
| `flutter_inappwebview` | ^6.0.0 | 인앱 웹뷰 |
| `app_tracking_transparency` | ^2.0.6 | ATT 추적 투명성 |
| `orange` | ^1.2.8 | 유틸리티 |

---

## 내부 패키지

| 패키지 | 경로 | 용도 |
|--------|------|------|
| `authentication` | packages/authentication | 인증 로직 |
| `utils` | packages/utils | 공통 유틸리티 |
| `ab_testing` | packages/ab_testing | A/B 테스팅 |
| `geofence_foreground_service` | packages/geofence_foreground_service | 지오펜싱 서비스 |
| `flutter_heatmap_calendar` | packages/flutter_heatmap_calendar | 히트맵 캘린더 위젯 |
| `flutter_openmoji` | (external) | OpenMoji 이모지 |

---

## 개발 도구

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `flutter_lints` | ^6.0.0 | 린트 규칙 |
| `flutter_launcher_icons` | ^0.14.1 | 앱 아이콘 생성 |
| `analyzer` | ^8.1.1 | 코드 분석 |
| `build` | ^4.0.3 | 빌드 시스템 |
| `source_gen` | ^4.1.1 | 소스 생성 |
| `code_builder` | ^4.10.0 | 코드 빌더 |

---

## 자동화 & CI/CD

### Fastlane

**주요 레인:**
- `create`: 앱 생성 및 메타데이터 초기화
- `metadata`: 메타데이터 업로드
- `screenshots`: 스크린샷 캡처
- `bump_version`: 버전 관리
- `setup_certs`: 인증서 설정
- `test`: 테스트 실행
- `deploy`: 통합 빌드 및 배포
- `codegen`: 코드 생성
- `firebase_config`: Firebase 설정

**Fastfile 모듈:**
- `library/`: env_loader, android, ios, firebase, screenshots, version, certificates, tests, release_notes, project_setup
- `stage/`: create, metadata, push, screenshot, version_manager, code_signing, testing, release, project_management

### GitHub Actions

**워크플로우:** `.github/workflows/ci.yml`
- **iOS**: macOS runner, Flutter 설치, Match 인증서, App Store 배포
- **Android**: Ubuntu runner, Keystore 설정, Google Play 배포
- **트리거**: main 브랜치 PR 또는 태그 푸시

---

## 아키텍처 패턴

### Clean Architecture + MVVM

```
┌─────────────────────────────────────┐
│         Presentation Layer          │
│      (Views & ViewModels)           │
├─────────────────────────────────────┤
│          Domain Layer               │
│    (Business Logic & Actions)       │
├─────────────────────────────────────┤
│           Data Layer                │
│  (Repositories & DataSources)       │
└─────────────────────────────────────┘
```

### Feature 기반 모듈 시스템

```
features/
└── [feature_name]/
    ├── models/
    ├── view_models/
    ├── views/
    ├── widgets/
    └── index.dart
```

---

## 환경 설정

### 환경 변수 파일 (자동 생성 산출물 — 손 편집 금지)

루트 `project.yaml`/`app_config.yaml`에서 `./build` · `./run gen-env` · `./init`이 생성:

- `config/env/.env.debug`: 개발 환경 (generated — Google 테스트 광고 ID 자동)
- `config/env/.env.profile`: 프로파일 환경 (generated — Google 테스트 광고 ID 자동)
- `config/env/.env.release`: 프로덕션 환경 (generated — `project.yaml admob.units` 실값)

### 에셋

- `assets/images/`: 이미지
- `assets/languages/`: 다국어 번역 파일
- `assets/lottie/`: Lottie 애니메이션
- `assets/fonts/`: 커스텀 폰트 (Roboto, Kalam)
- `assets/data/`: JSON 데이터 파일

---

*생성일: 2026-01-03*
