# Fastlane Setup Guide

> 빌드, 테스트, 배포 자동화를 위한 Fastlane 설정 가이드

---

## Overview

이 보일러플레이트는 완전한 Fastlane 자동화를 제공합니다:

| 기능 | 상태 | 설명 |
|------|------|------|
| 버전 관리 | ✅ 완성 | 모든 플랫폼 동기화 |
| iOS 인증서 (Match) | ✅ 완성 | Git 저장소 기반 |
| Android 키스토어 | ✅ 완성 | 자동 생성/관리 |
| 테스트 자동화 | ✅ 완성 | Unit/Widget/Integration |
| 릴리스 노트 | ✅ 완성 | Git 기반 자동 생성 |
| 메타데이터 | ✅ 완성 | 다국어 지원 |
| 스크린샷 | ✅ 완성 | `generate_screenshots` 레인 (산출물: 루트 `screenshots/`) |
| Firebase 설정 | ✅ 완성 | 자동 구성 |

---

## Prerequisites

> 상세 설치 가이드: [00-PREREQUISITES.md](../00-PREREQUISITES.md)

```bash
# Fastlane 설치
cd fastlane
bundle install
```

---

## Initial Setup

### Step 1: 환경 변수 파일 생성

`.env` 파일 생성 (프로젝트 루트):

```bash
# ./init으로 자동 생성 (app_config.yaml 기반)
./init
```

### Step 2: 필수 환경 변수 설정

`.env` 파일 편집 (프로젝트 루트):

```bash
#=================================================
# 앱 기본 정보(APP_NAME/APP_ID/COMPANY_NAME)는 project.yaml이 SSOT —
# .env에 넣으면 project.yaml 값이 가려지므로 넣지 말 것
#=================================================

#=================================================
# iOS 설정
#=================================================
APPLE_ID=your@email.com
TEAM_ID=XXXXXXXXXX           # Apple Developer Team ID

# Match (인증서 관리)
MATCH_GIT_URL=git@github.com:yourcompany/certificates.git
MATCH_PASSWORD=your_match_password

#=================================================
# Android 설정
#=================================================
KEYSTORE_PATH=android/app/upload-keystore.jks
KEYSTORE_PASSWORD=your_keystore_password
KEY_PASSWORD=your_key_password
KEY_ALIAS=upload

# Google Play 서비스 계정 (배포용)
GOOGLE_PLAY_JSON_KEY=path/to/google-play-key.json

#=================================================
# GitHub (릴리스 노트용)
#=================================================
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
GITHUB_REPOSITORY=yourcompany/yourapp

#=================================================
# iOS 심사 제출 (P1-17 — ./deploy --submit-review 사용 시)
#=================================================
# App Review 연락처 — 누락 시 App Store Connect가 제출을 거부할 수 있음
REVIEW_FIRST_NAME=Gil-dong
REVIEW_LAST_NAME=Hong
REVIEW_PHONE=+82-10-0000-0000
REVIEW_EMAIL=review@yourcompany.com
# 심사용 데모 계정 (로그인 필요한 앱만)
REVIEW_DEMO_USER=
REVIEW_DEMO_PASSWORD=
REVIEW_NOTES=

# 승인 즉시 자동 출시 여부 (기본 true — 수동/단계적 출시는 false)
IOS_AUTOMATIC_RELEASE=true

# export compliance 자동응답 (기본 false = 비예외 암호화 미사용).
# 주의: 앱 Info.plist의 ITSAppUsesNonExemptEncryption 선언과 반드시
# 일치시킬 것 — 한쪽만 바꾸면 제출 답변과 빌드 선언이 모순됨.
EXPORT_COMPLIANCE_USES_ENCRYPTION=false
```

### Step 3: 설정 검증

```bash
cd fastlane
bundle exec fastlane validate
```

---

## iOS Certificate Setup

### Option A: Match 사용 (권장)

Match는 인증서를 Git 저장소에 암호화하여 저장합니다.

#### 1. 인증서 저장소 생성

```bash
# GitHub에 private repository 생성
# 예: github.com/yourcompany/certificates
```

#### 2. Match 초기화

```bash
bundle exec fastlane match init

# 저장소 URL 입력: git@github.com:yourcompany/certificates.git
```

#### 3. 인증서 생성

```bash
# 개발용 인증서
bundle exec fastlane match development

# 배포용 인증서
bundle exec fastlane match appstore

# AdHoc (테스트 배포용)
bundle exec fastlane match adhoc
```

#### 4. 새 기기 추가 시

```bash
# 새 기기 등록 후 프로비저닝 프로파일 갱신
bundle exec fastlane match development --force_for_new_devices

# 또는 Fastlane 레인 사용
bundle exec fastlane setup_certs
```

### Option B: 수동 설정

1. Apple Developer Portal에서 인증서 생성
2. Xcode에서 직접 인증서 관리
3. `.env`에서 Match 관련 변수 제거

---

## Android Keystore Setup

### 자동 생성 (권장)

```bash
bundle exec fastlane setup_certs
```

이 명령은 다음을 수행합니다:
1. 키스토어 파일 생성 (`android/app/upload-keystore.jks`)
2. `key.properties` 파일 생성
3. 환경 변수 연동

### 수동 생성

```bash
cd app/android/app

keytool -genkey -v \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD \
  -dname "CN=Your Company, OU=Development, O=Your Company, L=Seoul, S=Seoul, C=KR"
```

### key.properties 파일

`android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

### SHA-1 확인 (Google Services용)

```bash
bundle exec fastlane sha1
```

---

## Firebase Setup

### 자동 설정 (권장)

```bash
# 대화형 설정
bundle exec fastlane firebase_config

# 또는 프로젝트 설정 시 함께 설정
bundle exec fastlane setup firebase:true
```

### 수동 설정

1. Firebase Console에서 프로젝트 생성
2. iOS/Android 앱 추가
3. 설정 파일 다운로드:
   - iOS: `GoogleService-Info.plist` → `ios/Runner/`
   - Android: `google-services.json` → `android/app/`
4. FlutterFire 설정:
   ```bash
   cd app
   flutterfire configure
   ```

---

## Directory Structure

```
fastlane/
├── Fastfile              # 메인 레인 정의 (import 순서 중요!)
├── Appfile              # 앱 정보 설정
├── Matchfile            # Match (인증서) 설정
├── Gemfile              # Ruby 의존성
│
├── fastfiles/
│   ├── library/         # 재사용 가능한 함수 (primitives)
│   │   ├── env_loader.rb      # 환경 변수 로더 (가장 먼저 로드)
│   │   ├── paths.rb           # 경로 헬퍼
│   │   ├── certificates.rb    # 인증서 + 코드 서명 통합 관리
│   │   ├── android.rb         # Android 빌드
│   │   ├── ios.rb             # iOS 빌드 (certificates.rb 의존)
│   │   ├── firebase.rb        # Firebase (토큰, dSYM)
│   │   ├── app_distribution.rb # Firebase App Distribution
│   │   ├── version.rb         # 버전 관리
│   │   ├── tests.rb           # 테스트
│   │   ├── release_notes.rb   # 릴리스 노트
│   │   ├── project_setup.rb   # 프로젝트 설정
│   │   ├── remote_config.rb   # Firebase Remote Config + A/B Testing
│   │   ├── ab_testing.rb      # Firebase A/B Testing 실험 관리
│   │   ├── ga4_admin.rb       # GA4 Admin API (Custom Definitions)
│   │   ├── privacy.rb         # ASC 개인정보/콘텐츠 권한 + Play Data Safety(upload_data_safety)
│   │   └── review_status.rb   # 심사 상태 + 리젝 사유 조회
│   │
│   └── stage/           # 워크플로우 단계 (orchestration)
│       ├── create.rb          # 앱 생성
│       ├── metadata.rb        # 메타데이터
│       ├── push.rb            # 업로드
│       ├── version_manager.rb # 버전
│       ├── code_signing.rb    # 서명
│       ├── testing.rb         # 테스트
│       ├── release.rb         # 릴리스
│       ├── review_status.rb   # 심사 상태 조회
│       ├── project_management.rb  # 프로젝트
│       └── firebase_management.rb # Firebase 관리
│
└── config/              # 설정 파일
```

> 앱 스토어 메타데이터는 루트 `metadata/`(ios/, android/, data_safety/, in_app_purchases/ — 로케일: en-US, ko-KR, de-DE, fr-FR, ja-JP, pt-BR, ru-RU, zh-CN), 스크린샷은 루트 `screenshots/`(android/, ios/)에 있습니다. `fastlane/` 내부가 아닙니다.

### 아키텍처 원칙

- **library/**: 재사용 가능한 단위 함수 (primitives). 다른 파일에서 호출됨
- **stage/**: 여러 library 함수를 조합한 워크플로우 (orchestration)
- **Import 순서**: `env_loader.rb` → `certificates.rb` → `ios.rb` (의존성 순서)
- **certificates.rb**: iOS Match + Android Keystore + App Extension 서명 통합 관리

---

## Common Commands

### 프로젝트 설정

```bash
# 새 프로젝트 설정 (대화형)
bundle exec fastlane setup

# 설정 검증
bundle exec fastlane validate

# 프로젝트 정보 확인
bundle exec fastlane info

# 코드 생성 (build_runner)
bundle exec fastlane codegen
```

### 버전 관리

```bash
# 패치 버전 증가 (1.0.0 → 1.0.1)
bundle exec fastlane bump_version type:patch

# 마이너 버전 증가 (1.0.0 → 1.1.0)
bundle exec fastlane bump_version type:minor

# 메이저 버전 증가 (1.0.0 → 2.0.0)
bundle exec fastlane bump_version type:major

# 빌드 번호만 증가
bundle exec fastlane bump_version type:build
```

### 테스트

```bash
# 모든 테스트 실행
bundle exec fastlane test

# 단위 테스트만
bundle exec fastlane test type:unit

# 위젯 테스트만
bundle exec fastlane test type:widget

# 통합 테스트
bundle exec fastlane test type:integration

# 커버리지 포함
bundle exec fastlane test coverage:true
```

### 빌드 & 배포

```bash
# 전체 배포 프로세스 (프로젝트 루트에서 — 통합 오케스트레이터)
./deploy --bump patch

# 스크린샷 포함 배포
./deploy --bump patch --no-skip-screenshots

# production + iOS 심사 자동 제출 (메타데이터 업로드 후 submit_ios_review)
./deploy --target production --submit-review

# 빌드 및 업로드만 (target: beta|production, platform: ios|android|all)
bundle exec fastlane build_and_upload target:beta platform:all
```

### 인증서 관리

```bash
# 인증서 설정 (iOS Match + Android Keystore)
bundle exec fastlane setup_certs

# 인증서 유효성 검사
bundle exec fastlane check_certificates

# 인증서 정보 확인
bundle exec fastlane show_certificate_info
```

### Firebase Remote Config & A/B Testing

```bash
# Remote Config 파라미터 목록 조회
bundle exec fastlane rc_list

# 파라미터 설정
bundle exec fastlane rc_set key:feature_dark_mode value:true

# AB 테스트 기본값 설정
bundle exec fastlane rc_set_ab experiment:subscription_paywall variant:control

# Remote Config 백업/복원
bundle exec fastlane rc_export file:config/remote_config_backup.json
bundle exec fastlane rc_import file:config/remote_config.json

# AB 실험 목록 조회 / YAML로 일괄 등록
bundle exec fastlane ab_list
bundle exec fastlane ab_setup file:config/ab_experiments.yml
```

### Firebase App Distribution

```bash
# iOS + Android → Firebase 배포
bundle exec fastlane distribute

# 플랫폼별 배포
bundle exec fastlane distribute platform:android
bundle exec fastlane distribute platform:ios
```

---

## CI/CD

> **이 프로젝트는 GitHub Actions로 배포하지 않습니다** (Actions 영구 미사용 — [GOAL_AUDIT_ROADMAP.md](../reference/maintainer/GOAL_AUDIT_ROADMAP.md) 참조).

- 배포는 로컬 `./deploy` 단일 경로입니다 (preflight → build → upload).
- 테스트/검증도 전부 로컬에서 실행합니다.
- 시크릿은 GitHub Secrets가 아닌 루트 `.env`(gitignore)에 보관하며, fastlane/CLI만 소비합니다 (앱 번들 포함 금지). 앱 정체성/인프라 설정은 `project.yaml`/`app_config.yaml`에 있습니다.

---

## Google Play Console Setup

### 1. 서비스 계정 생성

1. Google Cloud Console → IAM & Admin → Service Accounts
2. Create Service Account
3. 권한: Service Account User
4. JSON 키 다운로드

### 2. Google Play Console 연결

1. Google Play Console → Setup → API access
2. Link to Google Cloud project
3. Grant access to service account

### 3. 환경 변수 설정

```bash
GOOGLE_PLAY_JSON_KEY=/path/to/google-play-key.json
```

---

## App Store Connect Setup

### 1. App Store Connect API Key

1. App Store Connect → Users and Access → Keys
2. Generate API Key
3. Role: App Manager 이상
4. AuthKey 파일 다운로드

### 2. 환경 변수 설정

```bash
APP_STORE_CONNECT_API_KEY_FILE=/path/to/AuthKey_XXXXXXXXXX.p8
APP_STORE_CONNECT_API_KEY_ID=XXXXXXXXXX
APP_STORE_CONNECT_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

---

## Troubleshooting

### "No matching provisioning profiles found"

```bash
# 프로비저닝 프로파일 갱신
bundle exec fastlane match appstore --force

# 또는 인증서 일괄 재설정 (iOS Match + Android Keystore)
bundle exec fastlane setup_certs
```

### "Code signing error"

```bash
# 인증서 유효성 확인
bundle exec fastlane check_certificates

# 인증서 정보 확인
bundle exec fastlane show_certificate_info
```

### "Environment file not found"

```bash
# .env 파일 생성 확인
ls -la .env

# 환경 변수 출력
bundle exec fastlane info
```

### "Keystore not found"

```bash
# 키스토어 자동 생성
bundle exec fastlane setup_certs

# 또는 수동 경로 확인
echo $KEYSTORE_PATH
```

### "firebase projects:create failed"

```bash
# Firebase CLI 로그인 상태 확인
firebase login

# 프로젝트 목록 확인
firebase projects:list

# 수동으로 Firebase 설정
cd app && flutterfire configure
```

### Match 관련 오류

```bash
# Match 저장소 접근 확인
git clone $MATCH_GIT_URL /tmp/test-match

# SSH 키 확인
ssh -T git@github.com

# HTTPS 대신 SSH 사용
MATCH_GIT_URL=git@github.com:yourcompany/certificates.git
```

---

## Best Practices

### 1. 환경 분리

```bash
# 환경별 설정은 ./build이 자동 생성 — 수동 전환 명령 없음
./build   # app/config/env/.env.{debug,profile,release} 생성
```

`app/config/env/.env.*`는 생성 산출물이므로 손으로 편집하지 않습니다.

### 2. Commit Convention

Conventional Commits를 사용하면 릴리스 노트가 자동 생성됩니다:

```
feat: 새로운 기능 추가
fix: 버그 수정
perf: 성능 개선
refactor: 리팩토링
docs: 문서 수정
chore: 기타 변경사항
```

### 3. 버전 전략

- **Patch**: 버그 수정, 작은 변경
- **Minor**: 새 기능, 하위 호환 유지
- **Major**: 주요 변경, 하위 호환 깨짐

### 4. 보안

- `.env` 파일은 `.gitignore`에 포함
- 키스토어 파일은 Git에 커밋하지 않음
- 시크릿은 루트 `.env`에만 두고 fastlane/CLI만 소비 (앱 번들 포함 금지)

---

## Reference

- [Fastlane 공식 문서](https://docs.fastlane.tools)
- [Match 가이드](https://docs.fastlane.tools/actions/match/)
- [Deliver (App Store)](https://docs.fastlane.tools/actions/deliver/)
- [Supply (Google Play)](https://docs.fastlane.tools/actions/supply/)
- [README_FASTLANE.md](../../fastlane/README_FASTLANE.md) - 상세 사용법 (`fastlane/`은 `./run`이 클론하는 산출물 — 클론 후에만 존재)
