# Feature Management Guide

> Feature CLI를 사용한 기능 관리 가이드

---

## Quick Start

### 설치
```bash
cd tools/feature_cli
dart pub get
```

### 기본 사용법
프로젝트 루트에서 `./feature` 명령어 사용:

```bash
# 도움말
./feature --help

# 기능 상태 확인
./feature status

# 기능 목록
./feature list

# 기능 활성화/비활성화
./feature enable ads
./feature disable ads
```

---

## 명령어 레퍼런스

### `status` (별칭: st)
현재 기능 플래그 상태를 표시합니다.

```bash
./feature status
```

### `list` (별칭: ls)
사용 가능한 기능 목록을 표시합니다.

```bash
./feature list              # 토글 가능한 기능 목록
./feature list --features   # 생성된 feature 모듈 목록
```

### `enable` (별칭: add, on)
기능을 활성화합니다. `AppFeatureConfig`의 플래그를 `true`로 설정합니다.

```bash
./feature enable ads
./feature enable subscription
./feature enable ads --dry-run  # 변경 없이 미리보기
```

### `disable` (별칭: remove, off)
기능을 비활성화합니다. `AppFeatureConfig`의 플래그를 `false`로 설정합니다.

```bash
./feature disable ads
./feature disable subscription
```

### `generate` (별칭: gen, g)
새 feature 모듈 스캐폴딩을 생성합니다.

```bash
# 기본 구조 (view만)
./feature generate -n profile

# 전체 구조 (model, viewmodel, widgets)
./feature generate -n profile --full

# 선택적 생성
./feature generate -n profile --with-model --with-viewmodel
./feature generate -n profile --with-widgets
```

**생성되는 구조:**
```
lib/features/[name]/
├── models/[name]_model.dart        # --with-model 또는 --full
├── view_models/[name]_view_model.dart  # --with-viewmodel 또는 --full
├── views/[name]_view.dart          # 기본 생성
├── widgets/                        # --with-widgets 또는 --full
└── index.dart
```

---

## 지원 기능 목록 (15개)

### 기본 기능

| 기능 | 설명 | 관련 플래그 | 패키지 |
|------|------|-------------|--------|
| `ads` | Google AdMob 광고 | `isAdsEnabled` | `google_mobile_ads` |
| `subscription` | 인앱 결제 및 구독 | `isSubscriptionEnabled`, `isInAppPurchaseEnabled` | `in_app_purchase` |
| `firebase` | Firebase 서비스 | `isFirebaseEnabled`, `isFirebaseAnalyticsEnabled`, etc. | `firebase_*` |
| `notification` | 알림 (기본) | `isNotificationEnabled` | `awesome_notifications` |
| `biometric` | 생체 인증 | `isBiometricAuthEnabled` | `local_auth` |
| `location` | 위치 서비스 | `isLocationEnabled` | `geolocator`, `geocoding` |
| `onboarding` | 온보딩 화면 | `isOnboardingEnabled` | - |

### 세부 기능 (개별 제어)

| 기능 | 설명 | 관련 플래그 | 의존성 |
|------|------|-------------|--------|
| `reEngagement` | 재참여 알림 | `isReEngagementEnabled` | `notification` |
| `reminder` | 리마인더 알림 | `isReminderEnabled` | `notification` |
| `backgroundNotification` | 백그라운드 알림 | `isBackgroundNotificationEnabled` | `notification` |
| `darkMode` | 다크 모드 | `isDarkModeEnabled` | - |
| `multiLanguage` | 다국어 지원 | `isMultiLanguageEnabled` | - |
| `abTesting` | A/B 테스팅 | `isABTestingEnabled` | - |
| `crashReporting` | 크래시 리포팅 | `isFirebaseCrashlyticsEnabled` | `firebase` |
| `splashAd` | 스플래시 전면 광고 | `isSplashInterstitialAdEnabled` | `ads` |

---

## 수동 설정 방법

CLI를 사용하지 않고 수동으로 기능을 설정할 수도 있습니다.

### 1. AppFeatureConfig 수정

`lib/config/app_feature_config.dart` 파일에서 플래그 변경:

```dart
class AppFeatureConfig {
  // 광고 활성화
  static bool isAdsEnabled = true;  // false → true

  // 구독 활성화
  static bool isSubscriptionEnabled = true;
  static bool isInAppPurchaseEnabled = true;
}
```

### 2. pubspec.yaml 패키지 관리

#### 광고 추가
```yaml
dependencies:
  google_mobile_ads: ^7.0.0
```

#### 구독/IAP 추가
```yaml
dependencies:
  in_app_purchase: ^3.2.0
```

### 3. 환경 설정

루트 설정 파일에 필요한 값 추가 후 `./build` 실행 (`app/config/env/.env.*`는 자동 생성):

```yaml
# project.yaml — 광고 (debug/profile은 테스트 ID 자동, release용 실값만 입력)
admob:
  units:
    ios:     { banner: "ca-app-pub-xxx/...", ... }
    android: { banner: "ca-app-pub-xxx/...", ... }
```

---

## 기능별 상세 가이드

### 광고 (Ads)

**활성화 시 필요한 작업:**
1. AdMob 계정 생성
2. 앱 등록 및 광고 단위 ID 생성
3. `project.yaml`의 `admob.units`에 release용 실제 단위 ID 입력 후 `./build` (debug/profile은 테스트 ID 자동)
4. `project.yaml`의 `admob.ios_app_id`/`android_app_id` 입력 → `./init`이 `Info.plist`/`AndroidManifest.xml`에 주입

**관련 파일:**
- `lib/core/services/ad/ad_service.dart`
- `lib/core/widgets/ads/`

### 구독/IAP (Subscription)

**활성화 시 필요한 작업:**
1. App Store Connect / Google Play Console에서 제품 생성
2. `project.yaml`의 `iap:` 섹션에 상품 정의 후 `./build`
3. 테스트 계정 설정

**관련 파일:**
- `lib/features/subscription/`
- `lib/core/services/in_app_purchase_service.dart`

> 💡 Supabase는 P1-16.5a에서 철거됨 (`./feature enable supabase` 불가) — 백엔드는 local-only Drift 기본 + Firebase Auth 전환 완료(16.5b). docs/MODULES.md §5 참조.

### Firebase

**활성화 시 필요한 작업:**
1. Firebase 프로젝트 생성
2. `flutterfire configure` 실행
3. `firebase_options.dart` 생성 확인

**관련 파일:**
- `lib/core/services/firebase_service.dart`
- `lib/firebase_options.dart`

---

## 기능 의존성

일부 기능은 다른 기능에 의존합니다:

| 기능 | 의존하는 기능 |
|------|---------------|
| `crashReporting` | `firebase` |
| `abTesting` | - |
| `reEngagement` | `notification` |
| `reminder` | `notification` |
| `backgroundNotification` | `notification` |
| `splashAd` | `ads` |

의존 기능이 비활성화되면 종속 기능도 작동하지 않습니다.

**예시:**
```bash
# reEngagement를 사용하려면 notification이 먼저 활성화되어야 함
./feature enable notification
./feature enable reEngagement
```

---

## 프로덕션 설정

프로덕션 빌드 시 별도 호출이 필요 없습니다. `AppFeatureConfig.applyBootConfig()`가 부팅 시 자동 호출되어 `app_config.yaml`의 profile/features 값(env 산출물 `APP_PROFILE`, `FF_*` 경유)을 적용합니다 — `main.dart`에서 직접 호출하지 마세요.

---

## 마이그레이션 노트

Feature CLI는 기존 두 도구를 대체합니다:
- `tools/feature_generator/` → `./feature generate`
- `tools/feature_manager/` → `./feature enable/disable/status`

기존 도구들은 삭제되었습니다. 모든 기능 관리는 Feature CLI를 사용하세요.

---

## 문제 해결

### "Feature not found" 오류
- 지원되는 기능 이름 확인: `./feature list`

### 플래그가 변경되지 않음
- `app_feature_config.dart` 파일 경로 확인
- 수동으로 파일 편집 시도

### 패키지 오류
- `flutter pub get` 실행
- `pubspec.yaml`에 패키지가 있는지 확인

---

## 참고

- [02-SPRINT-CHECKLIST.md](../02-SPRINT-CHECKLIST.md) - 메인 가이드
- [EXTERNAL_SETUP.md](./EXTERNAL_SETUP.md) - 외부 서비스 설정
- [Feature CLI README](../../tools/feature_cli/README.md) - CLI 상세 문서
- [app_feature_config.dart](../../app/lib/config/app_feature_config.dart) - 전체 플래그 목록
