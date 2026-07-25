# 소스 트리 분석 (Source Tree Analysis)

> Flutter BoilerPlate 프로젝트의 디렉토리 구조 및 파일 조직

---

## 프로젝트 루트 구조

```
boiler_plate/
├── app/                        # 📱 Flutter 메인 앱
│   ├── lib/                    # Dart 소스 코드
│   ├── android/                # Android 네이티브 코드
│   ├── ios/                    # iOS 네이티브 코드
│   ├── test/                   # 테스트 코드
│   ├── packages/               # 내부 패키지
│   ├── config/                 # 환경 설정
│   ├── assets/                 # 에셋 (이미지, 폰트, 로티 등)
│   ├── pubspec.yaml            # Flutter 의존성
│   └── build.sh                # 코드 생성 스크립트
│
├── fastlane/                   # 🚀 빌드/배포 자동화
│   ├── Fastfile                # 메인 Fastfile
│   ├── fastfiles/              # 모듈화된 레인
│   │   ├── library/            # 라이브러리 레인
│   │   └── stage/              # 스테이지 레인
│   ├── metadata/               # 앱 스토어 메타데이터
│   ├── Appfile                 # 앱 정보
│   ├── Matchfile               # 인증서 설정
│   └── Gemfile                 # Ruby 의존성
│
├── tools/                      # 🔧 개발 도구
│   └── feature_cli/            # Feature CLI
│       ├── bin/                # CLI 실행 파일
│       ├── lib/                # CLI 소스 코드
│       └── pubspec.yaml        # CLI 의존성
│
├── docs/                       # 📚 문서
│   ├── README.md               # 문서 진입점
│   ├── 00-PREREQUISITES.md     # 사전 요구사항
│   ├── 01-GETTING_STARTED.md   # 빠른 시작
│   ├── 02-SPRINT-CHECKLIST.md  # 스프린트 체크리스트
│   ├── guides/                 # 상세 가이드
│   └── reference/              # 참조 문서
│
├── _bmad/                      # 🤖 BMAD 프레임워크
│   ├── core/                   # 코어 워크플로우
│   └── bmm/                    # BMad Method 모듈
│
├── .github/                    # 🔄 GitHub 설정
│   └── workflows/              # CI/CD 워크플로우
│       └── ci.yml              # 메인 CI 워크플로우
│
├── CLAUDE.md                   # LLM 컨텍스트 가이드
├── README.md                   # 프로젝트 README
└── feature                     # Feature CLI 실행 심볼릭 링크
```

---

## app/lib/ 상세 구조

```
lib/
├── main.dart                   # 🚀 앱 진입점
│
├── config/                     # ⚙️ 앱 설정
│   ├── app_config.dart         # 앱 기본 설정
│   └── app_feature_config.dart # 기능 플래그 (30+개)
│
├── core/                       # 🏗️ 코어 레이어
│   ├── design/                 # 디자인 시스템
│   │   ├── colors.dart
│   │   ├── typography.dart
│   │   └── theme.dart
│   │
│   ├── router/                 # 라우팅
│   │   └── router.dart         # GoRouter 설정
│   │
│   ├── services/               # 서비스 레이어 (16개)
│   │   ├── firebase_service.dart
│   │   ├── supabase_service.dart
│   │   ├── ad_service.dart
│   │   ├── notification_service.dart
│   │   └── ...
│   │
│   ├── state/                  # 전역 상태
│   │   └── app_state.dart
│   │
│   ├── utils/                  # 유틸리티
│   │   └── ...
│   │
│   └── widgets/                # 공통 위젯 (20개 카테고리)
│       ├── ads/
│       ├── buttons/
│       ├── cards/
│       ├── dialogs/
│       ├── inputs/
│       ├── navigation/
│       └── ...
│
├── data/                       # 💾 데이터 레이어
│   ├── core/                   # 코어 데이터 유틸
│   │   └── models/
│   │       └── base_model.dart
│   │
│   ├── definitions/            # 테이블 정의
│   │   ├── user.dart
│   │   ├── post.dart
│   │   ├── badge.dart
│   │   ├── comment.dart
│   │   ├── tag.dart
│   │   └── post_tag.dart
│   │
│   ├── generated/              # 자동 생성 코드
│   │   ├── models/             # Freezed 모델
│   │   ├── database/           # Drift 테이블
│   │   └── repositories/       # Repository
│   │
│   ├── datasources/            # 데이터 소스 추상화
│   │   └── ...
│   │
│   └── table_generator/        # 코드 생성기
│       ├── annotations.dart
│       └── generators/
│
├── domain/                     # 🎯 도메인 레이어
│   └── actions/                # 비즈니스 로직
│       └── ...
│
└── features/                   # 📦 기능 모듈
    ├── README.md               # Features 가이드
    │
    ├── auth/                   # 인증
    │   ├── views/
    │   │   ├── authentication_view.dart
    │   │   └── login_view.dart
    │   └── view_models/
    │       └── auth_view_model.dart
    │
    ├── home/                   # 홈
    │   ├── views/
    │   ├── view_models/
    │   └── models/
    │
    ├── settings/               # 설정
    │   ├── views/
    │   ├── view_models/
    │   └── widgets/
    │
    ├── onboarding/             # 온보딩
    │   ├── views/
    │   └── view_models/
    │
    ├── subscription/           # 구독
    │   ├── views/
    │   └── view_models/
    │
    ├── splash/                 # 스플래시
    │   └── views/
    │
    └── permission/             # 권한 요청
        └── views/
```

---

## 내부 패키지 (app/packages/)

```
packages/
├── authentication/             # 인증 패키지
│   ├── lib/
│   └── pubspec.yaml
│
├── utils/                      # 유틸리티 패키지
│   ├── lib/
│   └── pubspec.yaml
│
├── ab_testing/                 # A/B 테스팅 패키지
│   ├── lib/
│   └── pubspec.yaml
│
├── geofence_foreground_service/ # 지오펜싱 패키지
│   ├── lib/
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
│
└── flutter_heatmap_calendar/   # 히트맵 캘린더 패키지
    ├── lib/
    ├── example/
    └── pubspec.yaml
```

---

## fastlane/ 상세 구조

```
fastlane/
├── Fastfile                    # 메인 엔트리
│
├── fastfiles/
│   ├── library/                # 재사용 가능한 함수
│   │   ├── env_loader.rb       # 환경 변수 로더
│   │   ├── android.rb          # Android 빌드
│   │   ├── ios.rb              # iOS 빌드
│   │   ├── firebase.rb         # Firebase 설정
│   │   ├── screenshots.rb      # 스크린샷 캡처
│   │   ├── version.rb          # 버전 관리
│   │   ├── certificates.rb     # 인증서 관리
│   │   ├── tests.rb            # 테스트
│   │   ├── release_notes.rb    # 릴리스 노트
│   │   └── project_setup.rb    # 프로젝트 설정
│   │
│   └── stage/                  # 스테이지 레인
│       ├── create.rb           # 앱 생성
│       ├── metadata.rb         # 메타데이터
│       ├── push.rb             # 빌드/업로드
│       ├── screenshot.rb       # 스크린샷
│       ├── version_manager.rb  # 버전 관리
│       ├── code_signing.rb     # 코드 서명
│       ├── testing.rb          # 테스트
│       ├── release.rb          # 릴리스
│       └── project_management.rb # 프로젝트 관리
│
├── metadata/                   # 앱 스토어 메타데이터
│   └── ...
│
├── Appfile                     # 앱 ID, 팀 설정
├── Matchfile                   # Match 인증서 설정
├── Gemfile                     # Ruby 의존성
└── Gemfile.lock
```

---

## 주요 진입점

| 파일 | 용도 |
|------|------|
| `app/lib/main.dart` | 앱 진입점 |
| `app/lib/core/router/router.dart` | 라우팅 설정 |
| `app/lib/config/app_config.dart` | 앱 기본 설정 |
| `app/lib/config/app_feature_config.dart` | 기능 플래그 |
| `fastlane/Fastfile` | Fastlane 진입점 |
| `tools/feature_cli/bin/feature.dart` | Feature CLI 진입점 |

---

## 환경 설정 파일

| 파일 | 용도 |
|------|------|
| `app/config/env/.env.debug` | 개발 환경 변수 |
| `app/config/env/.env.profile` | 프로파일 환경 변수 |
| `app/config/env/.env.release` | 프로덕션 환경 변수 |
| `app/pubspec.yaml` | Flutter 의존성 |
| `fastlane/Gemfile` | Ruby 의존성 |
| `.github/workflows/ci.yml` | CI/CD 워크플로우 |

---

## 자동 생성 파일

> `build_runner`로 생성되는 파일들 (수동 편집 금지)

| 패턴 | 생성기 |
|------|--------|
| `*.freezed.dart` | Freezed |
| `*.g.dart` | JSON Serializable / Riverpod Generator |
| `*.drift.dart` | Drift |
| `data/generated/*` | 커스텀 테이블 생성기 |

---

*생성일: 2026-01-03*
