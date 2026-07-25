# External Services Setup Checklist

> 외부 서비스 설정 가이드

---

## Overview

이 문서는 앱에서 사용하는 외부 서비스들의 설정 방법을 안내합니다.
각 서비스는 독립적이며, 필요한 서비스만 설정하면 됩니다.

**설정 방법**: 각 서비스마다 Fastlane 자동화와 수동 설정 두 가지 옵션을 제공합니다.

> **사전 요구사항**: [00-PREREQUISITES.md](../00-PREREQUISITES.md) 참조

---

## Firebase 설정

### Option A: Fastlane 사용 (권장)

```bash
cd fastlane

# 대화형 Firebase 설정 (프로젝트 생성/선택 + FlutterFire 구성)
bundle exec fastlane firebase_config

# 또는 프로젝트 설정 시 함께 진행
bundle exec fastlane setup firebase:true
```

이 명령은 다음을 자동으로 수행합니다:
- Firebase 프로젝트 생성 또는 기존 프로젝트 선택
- iOS/Android 앱 등록
- `GoogleService-Info.plist`, `google-services.json` 생성
- `firebase_options.dart` 생성
- 환경 변수 자동 업데이트

### Option B: 수동 설정

#### 1. Firebase 프로젝트 생성
```bash
# Firebase 로그인
firebase login

# 프로젝트 생성 (또는 Firebase Console에서 생성)
firebase projects:create your-app-name
```

#### 2. FlutterFire 설정
```bash
cd app
flutterfire configure --project=your-app-name
```

#### 3. 기능 활성화
`lib/config/app_feature_config.dart`:
```dart
static bool isFirebaseEnabled = true;
static bool isFirebaseAnalyticsEnabled = true;
static bool isFirebaseCrashlyticsEnabled = true;
```

### Verification
- [ ] Firebase Console에서 앱이 등록됨
- [ ] `firebase_options.dart` 파일 존재
- [ ] `flutter run` 시 Firebase 초기화 로그 확인

---

## iOS 인증서 설정 (Match)

### Option A: Fastlane 사용 (권장)

```bash
cd fastlane

# 인증서 저장소 초기화 (최초 1회)
bundle exec fastlane match init
# → Git URL 입력: git@github.com:yourcompany/certificates.git

# 인증서 설정 (개발 + 배포)
bundle exec fastlane setup_certs

# 개별 인증서 생성
bundle exec fastlane match development
bundle exec fastlane match appstore
bundle exec fastlane match adhoc

# 새 기기 추가 시 프로비저닝 갱신
bundle exec fastlane match development --force_for_new_devices

# 인증서 유효성 검증
bundle exec fastlane check_certificates

# 인증서 정보 확인
bundle exec fastlane show_certificate_info
```

### Option B: 수동 설정

1. Apple Developer Portal에서 인증서 생성
2. Xcode > Signing & Capabilities에서 직접 관리
3. 프로비저닝 프로파일 수동 다운로드/설치

### 환경 변수 설정
`.env` (프로젝트 루트):
```bash
APPLE_ID=your@email.com
TEAM_ID=XXXXXXXXXX
MATCH_GIT_URL=git@github.com:yourcompany/certificates.git
MATCH_PASSWORD=your_match_password
```

---

## Android Keystore 설정

> **공용 keystore 재사용 — 앱마다 만들지 않는다.** `app_config.yaml`의 기본값은 공용
> keystore(`signing.android.keystore_path: ~/key.jks`, `key_alias: android_signing_key`)를
> 가리킨다. 이 키는 **머신당 1회만 생성**하면 되고, 이후 모든 앱이 같은 파일을 재사용한다
> (앱마다 `keytool`을 다시 돌릴 필요 없음). 새 앱에서 할 일은 `.env`에
> `KEYSTORE_PASSWORD`/`KEY_PASSWORD`만 채우는 것뿐이다. 아래 생성 절차는 공용 키가
> 아직 없는 **최초 1회**에만 실행한다 (`~/key.jks`가 이미 있으면 건너뛴다).

### Option A: Fastlane 사용 (권장)

```bash
cd fastlane

# 키스토어 자동 생성 + key.properties 설정
bundle exec fastlane setup_certs

# SHA-1 fingerprint 확인 (Google Services용)
bundle exec fastlane sha1
```

이 명령은 다음을 자동으로 수행합니다:
- `upload-keystore.jks` 생성
- `key.properties` 파일 생성
- 환경 변수 연동

### Option B: 수동 설정

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

`android/key.properties` 생성:
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

### 환경 변수 설정
`.env` (프로젝트 루트) — **비밀번호 2개만** 넣는다:
```bash
KEYSTORE_PASSWORD=your_keystore_password
KEY_PASSWORD=your_key_password
```

> keystore **경로/별칭은 `.env`가 아니라 `app_config.yaml`**의
> `signing.android.keystore_path`(기본 `~/key.jks`)·`key_alias`(기본
> `android_signing_key`)에서 온다 — fastlane이 이 값을 읽어 `KEYSTORE_PATH`/`KEY_ALIAS`
> 환경변수로 자동 주입하므로 손으로 설정하지 않는다. `.env`에는 진짜 시크릿인
> 비밀번호만 둔다.

---

## Firebase App Distribution 설정

> PR 기반 테스트 빌드를 테스터에게 자동 배포합니다. TestFlight/Play Store를 거치지 않고 빠르게 테스트할 수 있습니다.

### 사전 요구사항
- Firebase 프로젝트가 이미 설정되어 있어야 합니다 (위 Firebase 설정 참조)
- iOS 테스트 배포를 위해 Ad Hoc 프로비저닝 프로파일이 필요합니다

### Step 1: Firebase Console에서 App Distribution 활성화

1. [Firebase Console](https://console.firebase.google.com) → 프로젝트 선택
2. 왼쪽 메뉴 → Release & Monitor → **App Distribution**
3. **Get Started** 클릭
4. **Testers & Groups** 탭 → **Add group** → 그룹명: `qa-testers`
5. 테스터 이메일 주소 추가

### Step 2: Firebase Service Account JSON 생성

Service Account JSON은 서버 측 인증 자격 증명으로, FlutterFire CLI로는 생성할 수 없습니다.
반드시 웹 콘솔에서 수동으로 다운로드해야 합니다.

#### 방법 A: Firebase Console (간편)

1. [Firebase Console](https://console.firebase.google.com) → 프로젝트 선택
2. 좌측 상단 **톱니바퀴** (설정) → **프로젝트 설정**
3. **서비스 계정** 탭 클릭
4. 하단의 **새 비공개 키 생성** 버튼 클릭
5. JSON 파일이 자동 다운로드됨
6. 파일을 `firebase-service-account.json`으로 이름 변경

#### 방법 B: Google Cloud Console (역할 세분화 가능)

1. [Google Cloud Console](https://console.cloud.google.com) → IAM & Admin → Service Accounts
2. **Create Service Account** 클릭
3. 이름: `firebase-app-distribution`
4. 역할 부여: **Firebase App Distribution Admin**
5. **Keys** 탭 → **Add Key** → **JSON** → 다운로드

> **참고**: 방법 A는 Firebase Admin SDK 전체 권한을 가진 키를 생성합니다.
> 권한 분리가 필요한 경우 방법 B로 App Distribution 전용 서비스 계정을 별도 생성하세요.

### Step 3: Match Ad Hoc 프로파일 생성 (iOS, 1회)

```bash
cd fastlane

# Ad Hoc 프로비저닝 프로파일 생성
bundle exec fastlane match adhoc

# 확인
bundle exec fastlane match adhoc --readonly
```

> Match repo에 development, appstore와 함께 adhoc 프로파일이 추가됩니다.

### Step 4: 환경 변수 설정

`.env` (프로젝트 루트):
```bash
# Firebase App Distribution
FIREBASE_SERVICE_CREDENTIALS_FILE=firebase-service-account.json
FIREBASE_TESTER_GROUPS=qa-testers

# App ID는 firebase.json / google-services.json에서 자동 감지됩니다.
# 수동 설정 시 아래 주석을 해제하세요 (환경변수가 자동 감지보다 우선합니다):
# FIREBASE_ANDROID_APP_ID=1:000000000000:android:xxxxxxxxxxxxxx
# FIREBASE_IOS_APP_ID=1:000000000000:ios:xxxxxxxxxxxxxx
```

### 로컬 테스트

```bash
cd fastlane

# Android만 배포
bundle exec fastlane distribute_android

# iOS만 배포
bundle exec fastlane distribute_ios

# 양 플랫폼 모두 배포
bundle exec fastlane distribute
```

### CI/CD 자동 배포 (미사용)

`.github/workflows/firebase-distribution.yml` 워크플로우 파일이 존재하지만, 이 저장소는 GitHub Actions를 사용하지 않습니다 (영구 미사용).
배포는 위의 로컬 distribute 레인으로만 수행합니다.

### Verification
- [ ] Firebase Console → App Distribution에서 업로드된 빌드 확인
- [ ] 테스터가 초대 이메일 수신
- [ ] 테스터 기기에서 앱 설치 성공
- [ ] iOS: 테스터 UDID가 Ad Hoc 프로파일에 등록됨

---

## Google Cloud IAM 설정

> Firebase App Distribution 등 Firebase 관련 자동화에 필요한 서비스 계정 IAM 역할을 설정합니다.

### 자동 설정 (./run init)

`./run init` 실행 시 Firebase 설정 직후 자동으로 GCloud IAM 역할이 부여됩니다.

**필요 조건:**
- `gcloud` CLI 설치 및 인증 (`gcloud auth login`)
- Firebase 프로젝트 ID 설정 (`app_config.yaml` 또는 `.env`)
- 서비스 계정 JSON 파일 (`app_config.yaml`의 `service_account_file`)

**자동 부여 역할:**

| 역할 | Role ID | 용도 |
|------|---------|------|
| Firebase Admin SDK 관리자 서비스 에이전트 | `roles/firebase.sdkAdminServiceAgent` | Firebase 리소스 관리 |
| Firebase 앱 배포 관리자 | `roles/firebaseappdistro.admin` | App Distribution 빌드 업로드/관리 |

**서비스 계정 이메일 해석 순서:**
1. `app_config.yaml` → `services.firebase.service_account_email` (명시 설정)
2. `service_account_file` JSON → `client_email` 필드 (자동 추출)

### 수동 설정

`gcloud` CLI가 없거나 자동 설정이 실패한 경우:

```bash
# 1. gcloud CLI 설치
# macOS
brew install google-cloud-sdk

# 2. 인증
gcloud auth login
gcloud config set project <FIREBASE_PROJECT_ID>

# 3. IAM 역할 부여
gcloud projects add-iam-policy-binding <FIREBASE_PROJECT_ID> \
  --member="serviceAccount:<SERVICE_ACCOUNT_EMAIL>" \
  --role="roles/firebase.sdkAdminServiceAgent"

gcloud projects add-iam-policy-binding <FIREBASE_PROJECT_ID> \
  --member="serviceAccount:<SERVICE_ACCOUNT_EMAIL>" \
  --role="roles/firebaseappdistro.admin"
```

**예시** (실제 값으로 대체):
```bash
gcloud projects add-iam-policy-binding nofon-2024 \
  --member="serviceAccount:fastlane@fastlane-429002.iam.gserviceaccount.com" \
  --role="roles/firebase.sdkAdminServiceAgent"

gcloud projects add-iam-policy-binding nofon-2024 \
  --member="serviceAccount:fastlane@fastlane-429002.iam.gserviceaccount.com" \
  --role="roles/firebaseappdistro.admin"
```

### app_config.yaml 설정

```yaml
services:
  firebase:
    enabled: true
    project_id: "nofon-2024"
    service_account_file: "~/serviceAccount.json"
    service_account_email: ""  # 비워두면 JSON에서 자동 추출
```

### Verification
- [ ] `gcloud projects get-iam-policy <PROJECT_ID>` 에서 역할 확인
- [ ] `bundle exec fastlane distribute` 정상 동작
- [ ] Firebase App Distribution에 빌드 업로드 성공

---

## Google Analytics (GA4) 설정

Firebase Analytics가 GA4와 자동 연동됩니다. (별도 Fastlane 명령 없음)

### Setup Steps

#### 1. Firebase Analytics 활성화
Firebase Console > Analytics > Enable

#### 2. GA4 속성 확인
Firebase Console > Project Settings > Integrations > Google Analytics
→ GA4 속성이 자동 생성됨

#### 3. 커스텀 이벤트 로깅
```dart
import 'package:yourapp/core/services/firebase_service.dart';

// 화면 조회
FirebaseService.logScreenView(screenName: 'home');

// 커스텀 이벤트
FirebaseService.logEvent(name: 'purchase_complete', parameters: {
  'product_id': 'premium_subscription',
  'price': 9.99,
});
```

### Verification
- [ ] Firebase Console > Analytics > DebugView에서 이벤트 확인
- [ ] 실시간 이벤트 수신 확인

---

## Google AdMob 설정

> AdMob은 웹 콘솔에서만 설정 가능합니다. (Fastlane 자동화 없음)

### Setup Steps

#### 1. AdMob 앱 등록
1. AdMob Console > Apps > Add App
2. iOS와 Android 각각 등록
3. App ID 기록

#### 2. 광고 단위 생성
Apps > 앱 선택 > Ad units > Add ad unit
- Banner
- Interstitial
- Rewarded
- Native (선택)

#### 3. 광고 단위 ID 설정 (`project.yaml`)
debug/profile 빌드는 Google 공식 테스트 ID가 **자동** 주입되므로 아무것도 적을 필요 없습니다.

release용 실제 단위 ID는 `project.yaml`의 `admob.units`에 입력 후 `./build`:
```yaml
admob:
  ios_app_id: "ca-app-pub-xxx~yyy"
  android_app_id: "ca-app-pub-xxx~yyy"
  units:
    ios:     { banner: "ca-app-pub-xxx/...", interstitial: "...", rewarded: "...", rewarded_interstitial: "...", native: "...", app_open: "..." }
    android: { banner: "ca-app-pub-xxx/...", interstitial: "...", rewarded: "...", rewarded_interstitial: "...", native: "...", app_open: "..." }
```
비워 두거나 테스트 ID를 넣으면 preflight가 release 빌드를 차단합니다.

#### 4. 플랫폼 설정

**iOS** - `ios/Runner/Info.plist`:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX</string>
<key>SKAdNetworkItems</key>
<array>
  <dict>
    <key>SKAdNetworkIdentifier</key>
    <string>cstr6suwn9.skadnetwork</string>
  </dict>
</array>
```

**Android** - `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
```

### Verification
- [ ] 테스트 광고 표시됨
- [ ] AdMob Console에서 요청 수 확인

---

## Push Notifications (FCM) 설정

> Firebase 설정이 먼저 완료되어야 합니다.

### Fastlane으로 가능한 것
```bash
# Crashlytics에 dSYM 업로드 (빌드 후)
bundle exec fastlane upload_dsym
```

### 수동 설정 필요 항목

#### 1. Firebase Messaging 활성화
```dart
static bool isFirebaseMessagingEnabled = true;
```

#### 2. iOS APNs 설정

**APNs 키 생성:**
1. Apple Developer > Certificates, Identifiers & Profiles
2. Keys > Create a key
3. Enable "Apple Push Notifications service (APNs)"
4. 다운로드 (.p8 파일)

**Firebase에 업로드:**
1. Firebase Console > Project Settings > Cloud Messaging
2. iOS app configuration > APNs Authentication Key 업로드

**Xcode 설정:**
1. Signing & Capabilities > + Capability
2. Push Notifications 추가
3. Background Modes > Remote notifications 체크

#### 3. Android 설정
Firebase 설정이 완료되면 자동으로 작동합니다.

#### 4. 테스트 메시지 전송
Firebase Console > Cloud Messaging > Send your first message

### Verification
- [ ] iOS: APNs 키 업로드됨
- [ ] Xcode에서 Push Notifications capability 추가됨
- [ ] 테스트 푸시 수신됨

---

## In-App Purchase 설정

> **상품 생성**은 각 스토어 콘솔에서 수동으로 해야 합니다. Fastlane은 메타데이터(이름, 설명) 업로드만 지원합니다.

### Fastlane으로 가능한 것 (⚠️ 부분 자동화)

```bash
cd fastlane

# iOS: App Store Connect에 이미 생성된 IAP 상품의 메타데이터 업로드
bundle exec fastlane deliver --skip_binary_upload --skip_screenshots

# 메타데이터 파일 위치 (P0-8 SSOT): metadata/ios/[locale]/
# IAP 계약 파일 (P1-17a): metadata/in_app_purchases/{ios,android}/<productId>.json
```

**Fastlane이 할 수 있는 것:**
- IAP 상품의 이름, 설명 다국어 업로드
- 스크린샷, 앱 설명 업로드
- 앱 제출 자동화

**Fastlane이 할 수 없는 것 (수동 필수):**
- IAP 상품 생성 (Product ID 생성)
- 가격 설정
- 구독 그룹 생성
- 상품 심사 제출

### App Store Connect (iOS)

#### 1. 앱 등록
App Store Connect > My Apps > New App

#### 2. 인앱 구매 생성
App > In-App Purchases > Create
- Consumable
- Non-Consumable
- Auto-Renewable Subscription
- Non-Renewing Subscription

#### 3. Product ID 설정
`project.yaml`의 `iap:` 섹션에서 상품을 정의합니다 (id에 package_name이 자동 접두사로 붙음):
```yaml
iap:
  subscriptions:
    - group_id: "premium_group"
      products:
        - id: "premium_monthly"
          duration: P1M
          # ...
```

#### 4. Sandbox 테스터 설정
Users and Access > Sandbox Testers > Add

### Google Play Console (Android)

#### 1. 앱 등록
Google Play Console > Create app

#### 2. 인앱 상품 생성
Monetize > Products > In-app products (또는 Subscriptions)

#### 3. 테스트 설정
Settings > License testing > 테스터 이메일 추가

### Verification
- [ ] iOS: Sandbox 계정으로 테스트 구매 성공
- [ ] Android: 테스트 트랙에서 구매 테스트 성공

---

## 환경 변수 보안

### 설정 파일 모델
사용자가 편집하는 파일은 루트 3개뿐이며, `app/config/env/.env.{debug,profile,release}`는 `./build` · `./run gen-env` · `./init`이 만드는 **생성 산출물**입니다 (손 편집 금지, gitignore, 매 빌드마다 재생성).

| 파일 | 내용 | 보안 등급 |
|------|------|----------|
| `project.yaml` | AdMob 앱/단위 ID 등 (시크릿 아님 — 번들에 포함됨) | git 추적 |
| `app_config.yaml` | 서비스 토글 등 공통 인프라 | git 추적 |
| `.env` (루트) | 진짜 시크릿 (서명 비밀번호, API 토큰 등) | git 무시 |

### 원칙
- **루트 `.env`의 시크릿은 절대 앱 번들에 들어가지 않음** — fastlane/CLI만 소비합니다. 생성기는 산출물 값이 루트 `.env`의 시크릿 값과 일치하면 빌드를 실패시킵니다.
- `firebase_options.dart`의 API 키는 노출되어도 Firebase Security Rules로 보호됨
- 민감한 서버 키는 절대 클라이언트에 포함하지 않음
- App Check 활성화 권장

---

## Fastlane 명령어 요약

| 서비스 | Fastlane 명령 | 자동화 수준 |
|--------|--------------|------------|
| Firebase | `firebase_config` | ✅ 완전 자동화 |
| App Distribution | `distribute`, `distribute_android`, `distribute_ios` | ✅ 완전 자동화 |
| iOS 인증서 | `setup_certs`, `match` | ✅ 완전 자동화 |
| Android Keystore | `setup_certs` | ✅ 완전 자동화 |
| SHA-1 확인 | `sha1` | ✅ 완전 자동화 |
| 프로젝트 설정 | `setup` | ✅ 완전 자동화 |
| GCloud IAM | `./run init` (자동) | ✅ 완전 자동화 |
| AdMob | - | ❌ 수동 설정 |
| FCM/APNs | `upload_dsym` | ⚠️ 부분 자동화 |
| IAP | `deliver` | ⚠️ 부분 자동화 (메타데이터만) |

---

## Checklist Summary

### 필수 (프로덕션 전)
- [ ] Firebase 프로젝트 설정
- [ ] Firebase App Distribution 설정 (테스터 배포용)
- [ ] iOS 인증서 설정 (Match - development, appstore, adhoc)
- [ ] Android Keystore 설정
- [ ] Crashlytics 활성화
- [ ] 프로덕션 광고 ID 설정 (광고 사용 시)
- [ ] IAP 상품 등록 (구독 사용 시)
- [ ] APNs 설정 (푸시 사용 시)

### 권장
- [ ] GA4 커스텀 이벤트 정의
- [ ] Remote Config 초기값 설정
- [ ] App Check 활성화

### 선택
- [ ] A/B 테스트 설정
- [ ] 성능 모니터링 활성화
- [ ] Sentry/Datadog 연동

---

## 참고 링크

- [Firebase Documentation](https://firebase.google.com/docs)
- [AdMob Documentation](https://developers.google.com/admob)
- [Apple Developer](https://developer.apple.com)
- [Google Play Console](https://play.google.com/console)
- [Fastlane Documentation](https://docs.fastlane.tools)
