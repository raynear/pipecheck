# Flutter BoilerPlate Project Overview

## Purpose
Flutter 앱 개발을 위한 프로덕션 레디 보일러플레이트 프로젝트. Clean Architecture + MVVM 패턴을 사용하며, 30개 이상의 기능 플래그로 기능을 ON/OFF 가능.

## Tech Stack

### Core
- **Framework**: Flutter (SDK >=3.8.0 <4.0.0)
- **Language**: Dart
- **State Management**: Riverpod 3.0 (코드 생성 방식)
- **Routing**: GoRouter

### Data Layer
- **Local DB**: Drift (SQLite)
- **Remote DB**: Supabase (선택)
- **Code Generation**: Freezed, JSON Serializable, Riverpod Generator

### External Services
- Firebase (Analytics, Crashlytics, Remote Config, Messaging)
- AdMob (광고)
- In-App Purchase
- iCloud Storage
- Push Notifications

## Project Structure
```
boiler_plate/
├── app/                    # Flutter 앱 메인
│   ├── lib/
│   │   ├── config/         # 앱 설정, 기능 플래그
│   │   ├── core/           # 공통 모듈
│   │   │   ├── design/     # 디자인 시스템
│   │   │   ├── services/   # 외부 서비스 (Firebase, Ad 등)
│   │   │   ├── state/      # 전역 상태
│   │   │   ├── utils/      # 유틸리티
│   │   │   └── widgets/    # 공통 위젯
│   │   ├── data/           # 데이터 레이어
│   │   │   ├── database/   # Drift DB 설정
│   │   │   ├── definitions/# 테이블 정의
│   │   │   └── repositories/
│   │   ├── domain/         # 도메인 레이어
│   │   └── features/       # 기능별 모듈
│   │       ├── auth/
│   │       ├── home/
│   │       ├── settings/
│   │       ├── splash/
│   │       ├── subscription/
│   │       ├── permission/
│   │       └── onboarding/
│   ├── packages/           # 로컬 패키지
│   └── config/env/         # 환경 변수
├── fastlane/               # 빌드/배포 자동화
├── tools/                  # CLI 도구들
│   └── cli/                # Feature CLI
├── webapp/                 # 웹앱 (랜딩 페이지 등)
└── supabase/               # Supabase 설정
```

## Key Features (via AppFeatureConfig)
- Notification (로컬/푸시 알림)
- Authentication (생체인증, 이메일, 소셜)
- Database (로컬 Drift, 원격 Supabase, 동기화)
- Cloud Services (Firebase, iCloud)
- Monetization (IAP, Subscription, Ads)
- Analytics & Tracking
- Onboarding, Dark Mode, Multi-Language, Home Widget

## Services (app/lib/core/services/)
- firebase_service.dart
- supabase_service.dart
- ad_service.dart
- notification_service.dart
- in_app_purchase_service.dart
- authentication_service.dart
- camera_service.dart
- badge_service.dart
- icloud_service.dart
- home_widget_service.dart
- feature_flag_service.dart
- remote_config_service.dart
