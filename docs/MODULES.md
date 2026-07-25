# MODULES.md — 모듈 경계 규칙 + 기능 플래그 체계

> P1-16에서 [CAPABILITY_MATRIX.md](reference/maintainer/CAPABILITY_MATRIX.md)(전수 감사 스냅샷)의
> 분류를 채택해 확정한 **현행 규칙**입니다. 매트릭스는 감사 기록이고,
> 이 문서가 운영 기준입니다. 로드맵 참조: [GOAL_AUDIT_ROADMAP.md](reference/maintainer/GOAL_AUDIT_ROADMAP.md) §4-16.

## 1. 경계 원칙

1. **core는 항상 컴파일되는 최소 셸** — 라우팅, 테마, 설정 상태, 부팅 순서,
   그리고 §3의 마이크로 의존성 allowlist만 직접 의존한다.
2. **기능은 패키지로** — 무겁거나 선택적인 기능(광고/알림/수익화/인증/위치/Firebase)은
   P2-20에서 `packages/`로 추출한다. 추출 전까지는 코어 안에서 동작을 유지하되
   플래그에 two-phase 표기를 남긴다 (§4).
3. **플래그는 코어 셸 토글만** — 기능 플래그는 §2의 12개가 전부다.
   패키지행 플래그(§4)는 추출 시 해당 패키지의 설정으로 이동한다.
   **reader 0인 플래그는 만들지 않는다** (P1-16a에서 13개 삭제한 원인).
4. **로컬 DB는 local-only가 공식 기본** (P2-23.5a 확정) — Drift는 무조건
   생성되며 플래그가 없다. 원격 동기화는 기본 제공하지 않는다
   (필요 시 Firestore Spark 한도 내 — 서버 코드 0줄 원칙).
5. **서버 코드 0줄** — 외부 서비스는 무료 티어만 사용한다. Cloud Functions(Blaze)
   등 유료 전제 설계 금지. (배경: [GOAL_AUDIT_ROADMAP.md](reference/maintainer/GOAL_AUDIT_ROADMAP.md) v1.2 헤더)

## 2. 최종 기능 플래그 12개

### 현행 8개 (코어 셸)

| 플래그 | 역할 |
|---|---|
| `isAuthenticationEnabled` | 인증 셸 on/off (라우터 리다이렉트, 라우트 보호) |
| `isOnboardingEnabled` | 신규 사용자 온보딩 리다이렉트 |
| `isDarkModeEnabled` | 테마 모드 전환 가용성 |
| `isMultiLanguageEnabled` | 언어 선택기 가용성 |
| `isForceUpdateEnabled` | 최소 버전 킬스위치 (ForceUpdateService) |
| `isNetworkMonitoringEnabled` | 연결 모니터링 + 오프라인 배너 |
| `isPrivacyConsentEnabled` | ATT/동의 부트 게이트 |
| `isDeveloperOptionsEnabled` | feature_config_view 개발 화면 게이트 (kDebugMode 종속) |

### 예약 4개 — 기능과 함께 추가 (지금 만들지 않음)

| 플래그 | 추가 시점 | 역할 |
|---|---|---|
| `isAppReviewPromptEnabled` | **이미 존재** (P1-14b) | 스마트 리뷰 트리거 (AppReviewService) |
| `isMaintenanceModeEnabled` | P2-23 | RC 점검 모드 게이트 + MaintenanceView |
| `isDataExportEnabled` | P2-23 | GDPR 데이터 내보내기 (Drift→JSON + ShareService) |
| `isShareAppEnabled` | P2-23 | 설정 '앱 공유' 행 (ShareService — 서비스는 존재, 소비자 0) |

> 합계 12 = 현행 8 + 예약 4 (이 중 isAppReviewPromptEnabled는 이미 배선됨).
> 예약 플래그는 소비자(기능)와 **같은 PR**에서만 추가한다.

## 3. core 마이크로 의존성 allowlist

core가 패키지 추출 없이 직접 들 수 있는 기능성 의존은 아래 5개 조합뿐이다.
이외의 기능 의존 추가는 P2-20 패키지로 갈 것.

| 기능 | 플래그 | 허용 의존성 |
|---|---|---|
| force_update | `isForceUpdateEnabled` | `package_info_plus`, `url_launcher` |
| network | `isNetworkMonitoringEnabled` | `connectivity_plus` |
| consent | `isPrivacyConsentEnabled` | `app_tracking_transparency` |
| review | `isAppReviewPromptEnabled` | `in_app_review` |
| share | `isShareAppEnabled`(예약) | `share_plus` |

## 4. 패키지행 플래그 19개 — two-phase

P2-20 추출 전까지 코어에서 동작을 유지한다. 추출 시 플래그는
`AppFeatureConfig`에서 빠지고 해당 패키지 설정으로 이동한다.
패키지 목록·내용물·추출 순서는 [CAPABILITY_MATRIX.md](reference/maintainer/CAPABILITY_MATRIX.md) §3과
로드맵 항목 20 참조 (순서: utils → ab_testing → authentication →
location/notifications/ads/firebase → monetization).

| 향후 패키지 | 플래그 |
|---|---|
| notifications | `isNotificationEnabled`, `isReEngagementEnabled`, `isReminderEnabled`, `isBackgroundNotificationEnabled`, `isFirebaseMessagingEnabled`(firebase 공동) |
| firebase | `isFirebaseEnabled`, `isFirebaseAnalyticsEnabled`, `isFirebaseCrashlyticsEnabled`, `isFirebaseRemoteConfigEnabled` |
| ads | `isAdsEnabled`, `isSplashInterstitialAdEnabled`, `isAppOpenAdEnabled`, `isUmpConsentEnabled`, `isChildDirectedAdsEnabled`, `isUnderAgeOfConsentEnabled` |
| monetization | `isInAppPurchaseEnabled`, `isSubscriptionEnabled` |
| ab_testing | `isABTestingEnabled` |
| authentication | `isBiometricAuthEnabled`, `isAccountDeletionEnabled` |
| location | `isLocationEnabled` |

> UMP/COPPA/TFUA 노브 3종은 매트릭스의 19개 집계엔 없지만 ads 패키지와
> 함께 이동한다 (P1-13c에서 ad 단일 지점에 구현 — 로드맵 13 참조).

## 5. 백엔드 — Supabase 철거(16.5a) + Firebase Auth 전환(16.5b) 완료

> **신규 supabase 의존 작업 금지.** 확정 스택(v1.2, 무료/서버 0줄):
> **Firebase Auth**(email — 16.5b 배선 완료, social은 P2-21.5) +
> **클라이언트 직접 계정 삭제**(`currentUser.delete()`) +
> **RevenueCat**(IAP 검증, P2-21 예정) + **local-only Drift** 기본.

**16.5a 철거**: `supabase_service.dart`(+provider 3종), `supabase/`
디렉토리 전체(에지 함수 7개, 배포된 적 없음), supabase 플래그,
`app_config.yaml services.supabase` 스키마, gen_env `SUPABASE_*` 키,
data 레이어 supabase datasource/database, table_generator SQL/RLS 생성,
`supabase_flutter` 의존, feature_cli supabase 정의.

**16.5b 전환 (배선 완료)**:

| 항목 | 구현 |
|---|---|
| email auth | `AuthViewModel`이 Firebase Auth로 로그인/가입/비밀번호 재설정. 세 경로 모두 단일 게이트 `_emailAuthReady`(isEmailAuthEnabled + isFirebaseEnabled + Firebase 초기화) 공유 — 과거 게이트 비대칭 풋건 해소 |
| 계정 삭제 | `AuthStateNotifier.deleteAccount` = 본인 로컬 데이터 삭제 + `currentUser.delete()`. `requires-recent-login`이면 실패 반환 + 재로그인 안내(errorMessage) |
| 세션 에러 처리 | P1-14c 계약 보존 — `authStateChanges` 구독이 원격 로그아웃/만료 시 로컬 상태 정리 |
| FCM 토큰 저장처 | **제거 확정** (서버 0줄 원칙) — 개별 타깃 푸시 비지원, 토픽 브로드캐스트 + FCM 콘솔 캠페인. 필요한 포크는 Firestore Spark 한도 내 직접 배선 |
| Data Safety 생성기 | email auth → 'Firebase Auth' 소스로 Email/User ID 선언, accountDeletionEnabled = 계정삭제 ∧ firebase ∧ email auth |
| 이중 구현 금지 | 서버 인증(로그인/가입)은 `AuthViewModel`에만. 계정 삭제는 `AuthStateNotifier` 소유 (settings 진입점이 호출) |
| IAP 검증 키 안내 | RevenueCat(P2-21) 문서에서 제공 예정 (구 supabase/.env.example 안내 대체) |

**수동 1회 (사용자, email auth 켜는 포크만)**: Firebase 콘솔 →
Authentication → Sign-in method → Email/Password 활성화.

## 6. Non-goals (명시적)

- **referral 코드** — 앱 특화 백엔드가 필요해 템플릿 범위 밖 (로드맵 24).
- **원격 DB 동기화 기본 제공** — local-only가 기본 (§1-4).
- **서버 함수 계층** — 서버 코드 0줄 원칙 (§1-5).

## 7. 변경 이력

- P1-16a: 죽은 플래그 13개 삭제 — 목록/마이그레이션은 CHANGELOG [Unreleased] Removed 참조.
- P1-16b: 이 문서 신설, two-phase 표기, supabase 폐기 예정 표기.
