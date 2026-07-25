<!--
  prd.md — 이 템플릿으로 새 앱을 만들 때의 단일 진실 공급원(SSOT).

  사람:        아래 블록의 「채움」 값을 채운다. 빈 칸은 비워둬도 된다.
  Claude Code: 채워진 값을 읽고 → project.yaml / app_config.yaml 갱신 +
               기능 플래그 설정 + 화면 스캐폴딩(테스트 포함) → ./init → ./build →
               테스트 주도 개발(게이트 ./preflight --mode feature 초록까지) → ./deploy.
               빈 칸은 합리적 기본값을 제안하고 사용자 확인 후 채운다.

  전체 진행 순서(생성→배포)는 docs/quick-start.md가 정전(正典)이다.
  플래그의 최종 권위는 app/lib/config/app_feature_config.dart, 설정 필드의
  최종 권위는 project.yaml / app_config.yaml 이다. 충돌 시 그 파일을 따른다.
-->

# PRD — <앱 이름>

> **상태**: 초안 / 검토중 / 확정
> **작성일**: <YYYY-MM-DD>

---

## 0. 한 줄 요약

- **무엇을**: <한 문장으로 — 이 앱이 하는 일>
- **누구를 위해**: <타깃 사용자>
- **핵심 가치**: <왜 쓰는가 — 경쟁 앱 대비 차별점>
- **수익 모델**: <무료 / 광고 / 구독 / 일회성 구매 / 혼합>

---

## 1. 앱 정체성 → `project.yaml: project.*`

```yaml
name: ""                 # 앱 표시 이름 (스토어)                      [필수]
package_name: ""         # Bundle ID / Package Name (com.회사.앱)     [필수]
version: "0.0.1"         # 시맨틱 버전                                [필수]
description: ""          # 한 줄 스토어 설명                          [선택]
github_repository: ""    # "owner/repo"                               [선택]
category: "productivity" # 아래 목록에서 1개                          [필수]
secondary_category: ""   # 보조 카테고리                              [선택]
```

> `category` 허용값: productivity, utility, business, developer_tools, education,
> reference, books, entertainment, games, music, photo_video, graphics_design,
> social, lifestyle, news, food_drink, health_fitness, medical, sports, finance,
> shopping, travel, navigation, weather, kids

---

## 2. 스토어 리스팅 → `project.yaml: listing.*`

```yaml
short_description: ""    # 부제 (Google 80자 / App Store 30자)        [선택]
keywords: []             # App Store 검색 키워드 (총 100자)           [선택]
primary_locale: "en-US"  # 기본 언어 (en-US, ko-KR …)                 [필수]
contact_email: ""        # 지원 이메일                                [선택]
contact_website: ""      # 지원/소개 웹사이트                          [선택]
privacy_policy_url: ""   # 비우면 ./init이 Firebase Hosting 도출      [선택]
terms_of_service_url: "" # 같은 호스트의 약관 페이지                   [선택]
apple_app_id: ""         # App Store 숫자 ID — 강제 업데이트 링크용    [선택, 출시 후]
```

> 법적 문서(개인정보처리방침·약관)는 `./init`이 `generate-legal`로 생성하고
> `./run deploy-legal`로 Firebase Hosting에 배포한다. URL을 비우면 호스팅
> 컨벤션(`https://<firebase-id>.web.app/privacy_policy.html`)으로 자동 도출된다.

---

## 3. 연령 등급 → `project.yaml: age_rating.*`

대부분 앱은 전부 `0`(없음). 해당 콘텐츠가 있으면 `1`(약함) 또는 `2`(빈번/강함)로.

```yaml
# 0 = None, 1 = Infrequent/Mild, 2 = Frequent/Intense
cartoon_fantasy_violence: 0
realistic_violence: 0
profanity_crude_humor: 0
mature_suggestive_themes: 0
gambling: 0              # 0 권장
sexual_content_nudity: 0
# … 전체 12개 항목은 project.yaml age_rating 블록 참조
```

---

## 4. 플랫폼 → `app_config.yaml: platforms.*`

```yaml
ios:
  team_id: ""            # Apple Developer Team ID                    [iOS 빌드 시 필수]
  deployment_target: "15.0"
android:
  min_sdk: 24            # Android 7.0
  target_sdk: 35         # Android 15
```

> 지원 플랫폼: **iOS + Android 양쪽**. 한쪽만 출시하려면 `./deploy --platform ios|android`.

---

## 5. 인증 전략 → feature flags

빌더가 결정하는 인증 플래그. (전체 권위: `app/lib/config/app_feature_config.dart`)

| 결정 | 플래그 | 기본 | 메모 |
|------|--------|------|------|
| 인증 셸 사용 | `isAuthenticationEnabled` | ON | 라우트 보호의 부모. 끄면 하위 전부 OFF |
| 생체 잠금 (Face/지문) | `isBiometricAuthEnabled` | ON | local_auth |
| 로컬 PIN 잠금 | `isPinAuthEnabled` | OFF | opt-in. 설정 화면에서 PIN 등록 |
| 이메일/비번 가입 | `isEmailAuthEnabled` | OFF | **Firebase Auth 필요** |
| 소셜 로그인 (Google/Apple) | `isSocialAuthEnabled` | OFF | OAuth 자격증명 설정 필요 |
| 계정 삭제 진입점 | `isAccountDeletionEnabled` | ON | **email/social 켜면 스토어 필수** |

**채움**: <예: 생체 + PIN, 서버 계정 없음 / 또는 이메일 + 소셜 + 계정삭제>

---

## 6. 클라우드·분석 → flags + `app_config.yaml: services.firebase.*`

| 결정 | 플래그 | 기본 | 부모 |
|------|--------|------|------|
| Firebase 코어 | `isFirebaseEnabled` | ON | — |
| Analytics (이벤트) | `isFirebaseAnalyticsEnabled` | ON | Firebase |
| Crashlytics (크래시) | `isFirebaseCrashlyticsEnabled` | ON | Firebase |
| Remote Config (킬스위치/플래그) | `isFirebaseRemoteConfigEnabled` | ON | Firebase |
| 점검 모드 (서버 차단) | `isMaintenanceModeEnabled` | ON | Remote Config |
| 강제 업데이트 | `isForceUpdateEnabled` | ON | — |
| A/B 테스트 | `isABTestingEnabled` | OFF | Remote Config |

```yaml
# app_config.yaml: services.firebase
enabled: true
service_account_file: "~/serviceAccount.json"   # Firebase Admin SDK     [Firebase 시 필수]
tester_groups: "qa-testers"                       # App Distribution 그룹
testers: ""                                        # 개별 테스터 (콤마 구분)
```

> Firebase 프로젝트는 `./init`이 자동 생성(project_id 비우면)하거나 기존 것을 연동한다.
> **서버 코드 0줄** — Firebase는 Auth/Analytics/Crashlytics/RC만 쓴다 (local-only Drift가 데이터 기본).

---

## 7. 알림 → feature flags

| 결정 | 플래그 | 기본 | 부모 |
|------|--------|------|------|
| 푸시/로컬 알림 | `isNotificationEnabled` | OFF | — |
| FCM 푸시 | `isFirebaseMessagingEnabled` | (premium ON) | Firebase + Notifications |
| 재참여 캠페인 | `isReEngagementEnabled` | ON | Notifications |
| 예약 리마인더 | `isReminderEnabled` | ON | Notifications |
| 백그라운드 알림 | `isBackgroundNotificationEnabled` | ON | Notifications |

**채움**: <알림 사용 여부 + 어떤 알림(리마인더/재참여/FCM 푸시)>

---

## 8. 수익화 → flags + `project.yaml: admob.* / iap.*`

### 광고 (AdMob)

```yaml
# 플래그
isAdsEnabled: false                # 광고 표시
isSplashInterstitialAdEnabled: true
isAppOpenAdEnabled: false
isUmpConsentEnabled: true          # EEA 동의 (광고 켜면 자동, opt-out)
isChildDirectedAdsEnabled: false   # 아동 대상 앱이면 ON (COPPA)
isUnderAgeOfConsentEnabled: false  # EEA 미성년 대상이면 ON (TFUA)

# project.yaml: admob — RELEASE 빌드용 실제 단위 ID (비우면 preflight가 release 차단)
ios_app_id: ""                     # ca-app-pub-xxx~yyy
android_app_id: ""
units:                             # banner/interstitial/rewarded/rewarded_interstitial/native/app_open × ios/android
  ios: { banner: "", interstitial: "", ... }
  android: { banner: "", interstitial: "", ... }
```

> debug/profile 빌드는 Google 테스트 ID 자동. 실값은 release에만 주입.

### 인앱 구매 / 구독

```yaml
# 플래그
isInAppPurchaseEnabled: false      # 일회성 구매
isSubscriptionEnabled: false       # 자동 갱신 구독

# project.yaml: iap — 상품 정의 (subscriptions[].products[], products[])
headline_copy: ""                  # 구독 화면 헤드라인 (비우면 기본 번역 키)
benefits_copy: ""
# subscriptions: group_id/group_name + products(id, duration P1M/P1Y, price_tier, free_trial P7D)
# products:      non_consumable (id, price_tier)
```

> `price_tier`: 5 → $4.99, 30 → $29.99, 60 → $59.99 (App Store 가격 티어).
> `./init`이 `metadata/in_app_purchases/`에 상품 파일 생성. id에 package_name 자동 접두.

**채움**: <수익 모델 + 구독 티어/가격 또는 광고 포맷>

---

## 9. 프라이버시·딥링크 → flags + `project.yaml: privacy.* / deep_link.*`

| 결정 | 플래그 | 기본 |
|------|--------|------|
| 개인정보 동의 (ATT/GDPR) | `isPrivacyConsentEnabled` | ON |
| 데이터 내보내기 (GDPR) | `isDataExportEnabled` | ON |
| 백업/복원 (로컬 DB → JSON) | `isBackupRestoreEnabled` | OFF |
| 네트워크 모니터링 (오프라인 배너) | `isNetworkMonitoringEnabled` | ON |

```yaml
# project.yaml: privacy
tracking_domains: []     # 앱 고유 트래킹 도메인 (SDK 도메인은 자동)

# project.yaml: deep_link  (켜려면 isDeepLinkEnabled: true)
scheme: ""               # 커스텀 스킴 (예: "myapp" → myapp://open/settings)
universal_links: []      # 유니버설/앱링크 도메인 (예: ["myapp.web.app"])
```

---

## 10. 기능 프로파일 → `app_config.yaml: profile` + overrides

하나를 고르면 플래그 묶음이 자동 설정된다. 세부는 `features:`로 개별 오버라이드.

| profile | 포함 |
|---------|------|
| `minimal` | Auth + 로컬 DB + 온보딩 (유틸리티 앱) |
| `standard` | + Firebase + Analytics + Crashlytics + RC (일반 앱) |
| `premium` | + 광고 + IAP + 구독 + 푸시 + A/B (수익화 앱) |
| `enterprise` | 전체 ON |

```yaml
profile: "standard"
features:                # profile보다 우선. 켤/끌 플래그만 (is 접두 제거, snake_case)
  # deep_link: true
  # location: true
```

**채움**: profile = <minimal/standard/premium/enterprise>, 오버라이드 = <...>

---

## 11. 외부 자산·시크릿 → `app_config.yaml: store.*/signing.*` + `.env`

프로젝트 간 **재사용 가능** — 기존 파일 경로만 지정하면 된다.

```yaml
# app_config.yaml: store.apple — iOS 배포 시
apple_id: ""             # Apple Developer 계정 이메일
itc_team_id: ""          # App Store Connect 팀 ID
api_key_id: ""           # ASC API 키 ID
api_issuer_id: ""        # ASC API 발급자 ID
api_key_file: "~/AuthKey_XXX.p8"

# app_config.yaml: store.google — Android 배포 시
json_key_file: "~/serviceAccount.json"   # Play Console API 서비스 계정

# app_config.yaml: signing
ios.match_git_url: ""    # 인증서 Git repo (Match, private)
android.keystore_path: "~/key.jks"
```

> 진짜 시크릿(키스토어 비번, GITHUB_TOKEN, OPENAI_API_KEY)은 루트 `.env`에만.
> `.env`는 gitignore + merge-preserve — `./init`이 관리 키만 갱신하고 사용자 키는 보존.

---

## 12. 화면 / 기능 스캐폴딩 목록 → `./feature generate`

`lib/features/<name>/` (models · view_models · views · repositories, 수동 Notifier 패턴)으로
생성할 화면들. 코어 화면(splash/onboarding/auth/settings/home)은 이미 존재.

| feature 이름 | `--full`? | 설명 |
|--------------|-----------|------|
| <예: tracker> | yes | <핵심 기능 화면> |
| <예: stats> | no | <통계 화면> |

> 생성: `./feature generate -n <name> --full` → 라우트는 `lib/core/router.dart`에 등록 → `./build`.

---

## 부록 — Claude Code 실행 지침

채워진 이 PRD를 받으면 아래 순서로 진행한다. 각 단계 세부는 **docs/quick-start.md**의 해당 Phase.

1. **PRD 파싱·확인** — 빈 필수 칸은 기본값을 제안하고 사용자 확인을 받는다 (Phase 1).
2. **설정 반영** — §1~3·8~9를 `project.yaml`에, §4·6·10·11을 `app_config.yaml`에 기록 (Phase 2).
3. **플래그 설정** — §5~9 결정을 `profile` + `features:` 오버라이드로. 개별 토글은 `./feature enable/disable` (Phase 2).
4. **화면 스캐폴딩 (테스트와 함께)** — §12 목록을 `./feature generate -n … --full`로 생성
   (model/viewmodel/view/repository **+ 짝이 되는 테스트**), 라우트 등록. 이후 개발은
   **테스트 주도 루프**: 로직은 실패 테스트 먼저, 생성된 `// ponytail: TODO`를 채운다 (Phase 5).
5. **`./init`** — 이름변경·env·서명·코드생성·아이콘·법적문서·Firebase·스토어등록 (Phase 3).
6. **`./build`** — 모델/DB/플래그 변경 후 코드 재생성 (Phase 5).
7. **검증 — 게이트 초록까지 반복**: `./preflight --mode feature`
   (analyze + flutter test + 테스트 무결성 + **변경 기능 커버리지 ≥80%**)가 초록일 때 기능 완료.
   배포 전 전체 검증은 `./preflight`(deploy 모드, Phase 6 사전).
8. **배포** — `./deploy --target beta` → 확인 후 `--target production` (Phase 6).

> 정합성 규칙: 이 PRD가 인용하는 모든 yaml 키·플래그명은 `project.yaml`/`app_config.yaml`/
> `app_feature_config.dart`의 실제 심볼과 일치해야 한다. 불일치 시 그 소스 파일이 정답이다.
