# 기능 전수 분류 매트릭스 (Capability Matrix)

**작성일**: 2026-06-11

> **감사 스냅샷 (동결).** 이 문서는 2026-06-11 시점의 전수 분류 기록이며 이후 변경(P1-16~17 실행, Supabase 철거 등)을 반영하지 않는다. 현행 경계 규칙·플래그 체계는 [MODULES.md](../../MODULES.md), 추출 계획 현행본은 [GOAL_AUDIT_ROADMAP.md](GOAL_AUDIT_ROADMAP.md) §4 항목 19-20 참조. (P2-20이 §3 패키지 내용물 표를 참조하므로 archive로 이동하지 않고 여기 유지.)

이 문서는 보일러플레이트의 **모든 기능/플래그/패키지/잔재를 전수 분류**한 결과다 — 각 항목의 **현재 위치 → 목표 위치**를 한 행씩 확정한다. 경계 규칙(MODULES.md, 로드맵 항목 16에서 확정 예정)과 [docs/GOAL_AUDIT_ROADMAP.md](GOAL_AUDIT_ROADMAP.md) 통합 로드맵(24항목)의 부속 문서이며, 분류 전 행은 저장소 직접 검증(40+ 스팟 체크, file:line 단위)과 비평가(critic) 교차 검증을 거쳤다. 본문 표의 R1-R5/C/M/Q 코드와 "항목 N"은 전부 GOAL_AUDIT_ROADMAP.md §2/§4를 가리킨다.

---

## 1. 경계 규칙 요약

GOAL_AUDIT_ROADMAP.md §3의 규칙을 분류 기준으로 사용했다:

| 버킷 | 규칙 |
|------|------|
| **runtime-flag** | 의존성 없는 공통 코드의 **행동 토글**만 (40개 → 12개) |
| **package** | pub 의존성·네이티브 코드·앱 특화 도메인 보유 — **컴파일 타임 포함**, pubspec 1줄 + init 1콜 |
| **core-always** | 항상 출하되는 공통 셸 (라우터·디자인·상태·위젯·필수 신뢰성 서비스) |
| **example** | 앱이 **소유/수정**할 코드만 복사해 가는 영역 (sample_tables 패턴), 패키지명 비의존 재작성 |
| **delete** | 아무것도 gate하지 않는 플래그, 소비자 0인 중복 메커니즘, 파생 앱 누출 잔재 |

### 비평가의 규칙 수정 1건 — core 마이크로 의존성 allowlist

최종 12개 플래그 중 **5개가 작은 pub dep을 동반**한다. 로드맵 §3의 "의존성 없는" 조항을 엄격히 읽으면 이들은 전부 퇴출 대상이 되므로, **MODULES.md(항목 16)에 core 마이크로 의존성 allowlist를 명문화**해야 경계 규칙이 집행 가능하다:

| 플래그 | 동반 micro-dep |
|--------|----------------|
| `isForceUpdateEnabled` | `package_info_plus`, `url_launcher` (force_update_service.dart:7-8 검증) |
| `isNetworkMonitoringEnabled` | `connectivity_plus` |
| `isPrivacyConsentEnabled` | `app_tracking_transparency` |
| `isAppReviewPromptEnabled` | `in_app_review` |
| `isShareAppEnabled` | `share_plus` |

---

## 2. 최종 런타임 플래그 12개

플래그 산수(비평가 보정): 검증된 static bool 40개 = 생존 8 + 즉시 삭제 13 + 패키지 이동 19 (`isEmailAuthEnabled`는 삭제가 아니라 supabase 패키지 옵션으로 **이동**). 최종 12 = 기존 8 + 신규 4. 플래그는 `static const`가 아닌 `static bool`(가변)임이 확인됨 — 12개 확정 후 부트 1회 결정(yaml profile → RC 오버라이드 → freeze) 의미론 채택.

| # | 이름 | 역할 | 비고 |
|---|------|------|------|
| 1 | `isAuthenticationEnabled` | 코어 인증 셸 on/off (라우터 리다이렉트, 라우트 보호) | 의존성 없는 진짜 토글로 검증됨 |
| 2 | `isOnboardingEnabled` | 신규 사용자 온보딩 리다이렉트 | 실제 라우터 토글로 검증됨 |
| 3 | `isDarkModeEnabled` | 테마 모드 전환 가용성 | 코어 테마 |
| 4 | `isMultiLanguageEnabled` | 언어 선택기 가용성 | 코어 i18n |
| 5 | `isForceUpdateEnabled` | 최소 버전 킬스위치 — 신규 배선되는 `ForceUpdateService` 경유 | micro-dep: `package_info_plus`, `url_launcher` (allowlist) |
| 6 | `isNetworkMonitoringEnabled` | 연결 모니터링 + 오프라인 배너 — 신규 배선되는 `NetworkStatusService` 경유 | micro-dep: `connectivity_plus` |
| 7 | `isPrivacyConsentEnabled` | ATT/동의 부트 게이트 | R2 수정 후 도달 가능; micro-dep: `app_tracking_transparency` |
| 8 | `isAppReviewPromptEnabled` | **신규**: 스마트 리뷰 트리거 — `AppReviewService`로 일원화 | micro-dep: `in_app_review` |
| 9 | `isMaintenanceModeEnabled` | **신규**: RC 소스 점검 모드 게이트 + `MaintenanceView` | firebase 패키지 없으면 no-op (코어에서는 dep-free) |
| 10 | `isDeveloperOptionsEnabled` | **재정의**: `feature_config_view` 개발 화면을 실제로 게이트, 기본 `kDebugMode` | 현재는 게이트 없음 검증됨 (router.dart:169-172) |
| 11 | `isDataExportEnabled` | **신규**: GDPR 데이터 내보내기 설정 행 | dep-free (Drift→JSON 덤프 + ShareService) |
| 12 | `isShareAppEnabled` | **신규**: 설정 '앱 공유' 행 — 신규 배선되는 `ShareService` 경유 | micro-dep: `share_plus` |

---

## 3. 최종 패키지 11개

추출 순서(항목 19→20): **utils → ab_testing → authentication/location/notifications/ads/firebase → supabase/monetization**. monetization·supabase는 **항목 21(IAP 서버 검증) 이후 하드 게이트** — 깨진 R3 권한 로직을 패키지화하면 버그가 파생 앱 4개에 동결된다.

| # | 패키지 | 내용물 / 흡수 대상 | 시점 / 게이트 |
|---|--------|--------------------|---------------|
| 1 | `packages/utils` (기존, 유지) | logger·i18n·format·validation 헬퍼; `app/lib/core/utils.dart` + `core/utils/`를 SSOT로 흡수. 임포터 44곳 검증 | 첫 pub workspace + pinned git dep 추출 (항목 19) |
| 2 | `packages/firebase` (신규) | Firebase.initializeApp, FirebaseService analytics, Crashlytics, RemoteConfigService, 선택적 firebase_performance(기본 off); 코어 no-op Analytics/Crash/RC seam 구현. `isFirebase*` 5종 흡수, `isAnalytics`/`isCrashReporting` 중복 제거 | P2 추출 1차 |
| 3 | `packages/notifications` (신규) | notification_service(852줄 검증, 분할), fcm_notification_service(supabase 결합 :6,:118,:129 → token-store 콜백 역전), notification_controller(라우터 콜백 seam), re_engagement + reminder 스케줄러(일반화); `isNotification`/`isReEngagement`/`isReminder`/`isBackgroundNotification`/`isFirebaseMessaging` 흡수. pub dep 5개(비평가 보정) | P2; FCM 옵션은 firebase 패키지 필요 |
| 4 | `packages/ads` (신규) | ad_service + app_open/banner/fullscreen 매니저 + ad_container 위젯; UMP/EEA 동의 + NPA 폴백 + COPPA 노브(항목 13에서 코어에 구축 → 항목 20에서 이전); isPremium은 코어 `settings.isSubscriptionActive` 위 콜백 주입; `isAds`/`isSplashInterstitialAd`/`isAppOpenAd` 흡수 | P2; 동의 코드는 P1(항목 13)에 선행 구축 |
| 5 | `packages/monetization` (신규) | in_app_purchase_service(권한 수리 후), 구독 페이월 feature, 온보딩 페이월 훅(onboarding_view_model 결합 검증), verify-subscription 에지 함수 배선, 이후 grace/promo/intro; `isInAppPurchase`/`isSubscription` 흡수 | **항목 21(서버 검증) 이후 하드 게이트** |
| 6 | `packages/supabase` (신규) | supabase_service 분할(auth/sync/token), feature:auth의 email 인증 경로, supabase 원격 datasource, 일반화된 코어 마이그레이션(habit 누출 테이블 + 중복 A/B 스토어 제거), push+sync 에지 함수, 신규 delete-account 에지 함수(항목 13에서 구축); `isSupabaseDatabase`/`isEmailAuth` 흡수 | 추출 순서상 항목 21 뒤 |
| 7 | `packages/ab_testing` (재구축) | `ABTestService`(RC 킬스위치 + `Experiment` enum SSOT)를 유일한 A/B 구현으로; 기존 Supabase impl + 마이그레이션 20240102 + assignment/tracking 에지 함수는 선택적 서브 라이브러리 또는 삭제; `isABTesting` 흡수. ab_test_experiment/ab_testing_provider/firebase_ab_testing_service/feature_flag_service 삭제 (메커니즘 4-6개 → 1개) | P2 추출 1차 (utils 직후) |
| 8 | `packages/authentication` (기존, 진짜 opt-in화) | 생체인증 local_auth 래퍼; 현재 path dep으로 항상 컴파일 + 런타임 플래그(역방향 오류 패턴 검증) → 컴파일 타임 포함으로 전환, authentication_service facade와 `isBiometricAuth` 흡수 | P2 |
| 9 | `packages/location` (신규) | geolocator + permission_handler; 코어 권한 플로우에 위치 행 주입(1010줄 뷰의 게이트 7개 섹션 검증); `isLocation` 흡수 | P2 |
| 10 | `packages/social_auth` (신규, **P2 — 제안된 P1에서 강등**) | Apple + Google 로그인, Kakao 서브 라이브러리; Supabase signInWithIdToken은 인터페이스 뒤로(supabase 패키지 하드 dep 없음); 삭제되는 R4 데모 인증 경로의 대체재 | 항목 14 + 19/20 이후 (신규 항목 21.5) |
| 11 | `tools/table_generator` (dev 패키지, `app/lib/data/`에서 이출) | 커스텀 drift/freezed/repo codegen을 dev_dependency로; 현재 lib/ 안에 살며(자체 build.yaml 포함) 출시 바이너리에 컴파일됨이 검증됨 | 항목 19에 +1-2d |

---

## 4. 전수 분류표 (111행)

근거 끝 `[ ]`는 공수 (XS <0.5d / S 0.5-1d / M 1-3d / L 3-5d / XL 1-2주). 여러 행이 하나의 추출을 공유하면 대표 서비스 행에 1회 계상. `※`는 비평가 보정 반영 표시.

### 4.1 package (44행)

| 대상 | 현재 위치 | 이동 | 근거 요약 |
|------|-----------|------|-----------|
| flag:`isNotificationEnabled` | app/lib/config/app_feature_config.dart:19 | flag→package | pub dep 5개(※보정: awesome_notifications_core 포함) 네이티브 스택을 플래그가 가림 — 경계 규칙상 notifications 패키지 컴파일 타임 포함 [S, 추출은 notification_service 행에 계상] |
| flag:`isReEngagementEnabled` | app_feature_config.dart:20 | flag→package-option | notifications 스택의 하위 행동; 코어 최상위 플래그가 아닌 패키지 설정 옵션으로 [XS] |
| flag:`isReminderEnabled` | app_feature_config.dart:21 | flag→package-option | notifications 패키지 옵션; reminder_scheduler 문서의 habit 앱 카피 누출은 이동 시 일반화 [XS] |
| flag:`isBackgroundNotificationEnabled` | app_feature_config.dart:22 | flag→package-option | notifications 패키지 내부 스케줄링 옵션 [XS] |
| flag:`isSupabaseDatabaseEnabled` | app_feature_config.dart:26 | flag→package | supabase_flutter init을 가림; 컴파일 타임 supabase 패키지 포함으로 대체. R1이 release에서 init 없이 강제 ON(late 접근 크래시 위험) [S] |
| flag:`isBiometricAuthEnabled` | app_feature_config.dart:31 | flag→package | local_auth 네이티브는 항상 컴파일되고 플래그만 토글 — 패턴의 잘못된 절반. 컴파일 타임 포함으로 전환 [S] |
| flag:`isEmailAuthEnabled` | app_feature_config.dart:32 | flag→package-option | isSupabaseDatabaseEnabled 의존이 인코딩 안 된 Supabase 경로; supabase 패키지 인증 옵션으로. 플래그 분기 제거가 R4 데모 우회도 함께 제거 [S] |
| flag:`isFirebaseEnabled` | app_feature_config.dart:37 | flag→package | firebase_core + 플러그인 5종을 가리는 전형적 wrong-bucket. 코어는 no-op analytics/crash seam 유지로 의존부 우아한 저하 [M, firebase_service 행에 계상] |
| flag:`isFirebaseAnalyticsEnabled` | app_feature_config.dart:38 | flag→package-option | firebase 패키지 옵션 (consent-mode 토글은 패키지 설정, 코어 프라이버시 동의가 공급) [XS] |
| flag:`isFirebaseCrashlyticsEnabled` | app_feature_config.dart:39 | flag→package-option | firebase 패키지 옵션; FlutterError.onError 연결은 코어 error_handler seam으로 일원화 [XS] |
| flag:`isFirebaseRemoteConfigEnabled` | app_feature_config.dart:40 | flag→package-option | firebase 패키지 옵션; 코어 소비자(강제 업데이트·점검 모드·플래그 오버라이드)는 기본 no-op RC seam으로 읽음 [XS] |
| flag:`isFirebaseMessagingEnabled` | app_feature_config.dart:41 | flag→package-option | FCM은 notifications/firebase 패키지 경계 — notifications 패키지의 FCM 옵션(firebase 패키지 필요) [XS] |
| flag:`isInAppPurchaseEnabled` | app_feature_config.dart:44 | flag→package | in_app_purchase 네이티브 dep을 가림; monetization 패키지 포함으로. R1이 빈 상품 설정으로 release 강제 ON — 플래그 형태의 라이브 실패 모드 [S] |
| flag:`isSubscriptionEnabled` | app_feature_config.dart:45 | flag→package-option | monetization 패키지 옵션(페이월 표면); IAP 포함의 하위 의존으로 인코딩 필요 — 현재 그 의존성이 누락 [XS] |
| flag:`isAdsEnabled` | app_feature_config.dart:46 | flag→package | google_mobile_ads를 가림; ads 패키지 포함으로. R1 release 강제 ON이 현재 AdService late field 크래시 유발 [S] |
| flag:`isSplashInterstitialAdEnabled` | app_feature_config.dart:47 | flag→package-option | 콜사이트 1곳, ads 내부 행동; 패키지 설정 옵션. R2 splash 도달 불가로 현재도 죽은 코드 [XS] |
| flag:`isAppOpenAdEnabled` | app_feature_config.dart:48 | flag→package-option | ads 패키지 내부 옵션; splash 경로 절반은 R2로 죽어 있음 [XS] |
| flag:`isABTestingEnabled` | app_feature_config.dart:52 | flag→package | A/B 스택을 가리며 현재 잘못된 서비스가 배선됨(app_config.dart:184 = FirebaseABTestingService init, 검증). 일원화 후 ab_testing 패키지 포함으로 [S] |
| flag:`isLocationEnabled` | app_feature_config.dart:58 | flag→package | geolocator+permission_handler를 끌어오고 코어 뷰 7개 섹션을 게이트; release 강제 ON이면 비위치 앱이 위치 권한 요청(심사 리스크) [M, permission 뷰 분할 포함] |
| svc:ab_test_service.dart (`ABTestService`) | app/lib/core/services/ab_test_service.dart | unwired→package+wire | 유일한 양품 A/B 구현(결정적 할당·RC 킬스위치·노출 로깅)인데 콜사이트 0 검증 — 재구축 ab_testing 패키지의 심장 [M 배선 즉시 / L 패키지화는 추후] |
| svc:ad/ad_service.dart + barrel | app/lib/core/services/ad/ | core→package | google_mobile_ads 오케스트레이터 — 순수 패키지 재료. 패키지 init이 플래그 대체, UMP 동의 게이트 추가 지점 [L, ads 패키지 전체] |
| svc:ad/app_open_ad_manager.dart | app/lib/core/services/ad/app_open_ad_manager.dart | core→package | ads 패키지 내부; 도달성은 R2 splash 수리로 회복 [ads 추출에 계상] |
| svc:ad/banner_ad_manager.dart | app/lib/core/services/ad/banner_ad_manager.dart | core→package | ads 패키지 내부; env 광고 단위 ID 읽기는 설정 주도 유지 [ads 추출에 계상] |
| svc:ad/fullscreen_ad_manager.dart | app/lib/core/services/ad/fullscreen_ad_manager.dart | core→package | ads 패키지 내부 (544줄 — 이동 시 분할) [ads 추출에 계상] |
| svc:authentication_service.dart | app/lib/core/services/authentication_service.dart | facade→package | packages/authentication 위의 얇은 facade — 패키지로 흡수해 포함을 pubspec 1줄 + init 1콜로 [S] |
| svc:firebase_service.dart | app/lib/core/services/firebase_service.dart | core→package (코어 no-op seam 유지) | firebase 패키지로 이동; 코어는 AnalyticsClient/CrashClient no-op 인터페이스 정의로 dep-free 이벤트 로깅 — 기존 graceful-degradation 패턴 유지 [M] |
| svc:in_app_purchase_service.dart | app/lib/core/services/in_app_purchase_service.dart | core→package (항목 21 하드 게이트) | monetization 패키지 중심이지만 권한 로직이 깨짐(R3: 클라이언트 +1달/+1년/+100년 만료, verifySubscription 콜사이트 0). 추출은 서버 검증 이후 [XL, 항목 21 포함] |
| svc:notification/notification_service.dart | app/lib/core/services/notification/notification_service.dart | core→package | 네이티브 스택 위 852줄 — notifications 패키지 코어. 추출 시 파일 분할(800줄 초과); 설정 영속은 코어 인터페이스 뒤로 [XL, notifications 패키지 전체] |
| svc:notification/fcm_notification_service.dart | app/lib/core/services/notification/fcm_notification_service.dart | core→package (supabase 결합 역전) | FCM 절반; 토큰 저장용 supabase_service 하드 import(:6,:118,:129 검증)를 token-store 콜백 인터페이스로 — 두 패키지 독립 유지 [M] |
| svc:notification/notification_controller.dart | app/lib/core/services/notification/notification_controller.dart | core→package (라우터 콜백 seam) | 탭/딥링크 처리를 go_router/코어 라우터 직접 import 대신 내비게이션 콜백으로 [S] |
| svc:notification/re_engagement_scheduler.dart | app/lib/core/services/notification/re_engagement_scheduler.dart | core→package | dep-free지만 notifications 스택 안에서만 의미; 패키지 옵션으로 출하 [notifications 추출에 계상] |
| svc:notification/reminder_scheduler.dart | app/lib/core/services/notification/reminder_scheduler.dart | core→package+일반화 | notifications 패키지 옵션; habit 앱 카피('습관 실행')는 이동 시 일반화(앱 특화 누출) [notifications 추출에 계상] |
| svc:remote_config_service.dart | app/lib/core/services/remote_config_service.dart | core→package (코어 RC seam 노출) | firebase_remote_config 래퍼는 firebase 패키지 소속; 코어 소비자는 기본 no-op 인터페이스로 읽음. zero-reader 키 정리 [M] |
| svc:supabase_service.dart | app/lib/core/services/supabase_service.dart | core→package+분할 | supabase_flutter 위 395줄 god-service; auth/sync/token 서브모듈로 분할된 supabase 패키지로. verifySubscription 래퍼는 monetization 경계로 [L] |
| feature:subscription | app/lib/features/subscription/ | feature→package | 기성 페이월 UI는 IAP 서비스와 함께 monetization 패키지로; 항목 21 권한 수리 게이트 [monetization 추출에 계상] |
| data:table_generator/ | app/lib/data/table_generator/ | lib→dev package (tools/) | 커스텀 build_runner codegen이 모든 출시 바이너리에 컴파일됨(검증) — wrong bucket. dev_dependency 패키지로 이출 [M] |
| pkg:utils | app/packages/utils/ | 유지 (첫 workspace 추출) | 이미 사실상 코어 공유 라이브러리(임포터 44곳 검증), 올바른 버킷. 첫 pub workspace + pinned git dep 후보(항목 19); app/lib/core/utils 흡수 [M] |
| pkg:authentication | app/packages/authentication/ | 유지, 진짜 opt-in화 | 형태는 맞고 포함 방식이 틀림: local_auth 네이티브가 항상 컴파일 + 런타임 플래그 토글(역방향 오류). opt-in 컴파일 타임 포함으로 [S-M] |
| pkg:ab_testing | app/packages/ab_testing/ | ABTestService 중심 재구축 | 현재 패키지는 Supabase 중복(임포터 2곳, 그중 1곳은 읽으면 크래시). ABTestService(RC 킬스위치 + `Experiment` enum SSOT) 중심 재구축 [L, 항목 20] |
| supabase/functions/verify-subscription | supabase/functions/verify-subscription/index.ts | unwired→wire (monetization, 항목 21) | 최고 가치 미배선 자산: 에지 함수 + 클라이언트 래퍼 존재, 콜사이트 0 — 배선이 곧 항목 21이자 monetization 추출·프로모 기능의 하드 게이트 [L, 3-4d] |
| supabase/functions A/B 3종 (get-experiment-assignment, track-experiment-event, analyze-experiment) | supabase/functions/ | A/B 일원화 따라감 | assignment+tracking은 중복 Supabase A/B 스택 전용 → ab_testing의 선택적 supabase 서브 라이브러리로 이동 또는 함께 삭제; analyze-experiment는 콘솔 도구로 생존 [S, 결정 종속] |
| supabase/functions push+sync (send-push-notification, sync-user-data) | supabase/functions/ | supabase 패키지 잔류 | 둘 다 SupabaseService 경유 배선이라 함께 이동; sync-user-data 운명은 오프라인 sync 결정 항목에 종속(클라이언트 호출 콜사이트 0) [S] |
| supabase/migrations/20240101 초기 스키마 | supabase/migrations/20240101000001_initial_schema.sql | 일반 vs 앱 도메인 분할 | supabase 패키지와 동행하되 habit 누출(user_habits, total_habits_completed, habit RLS)은 제거; 중복 A/B 테이블(ab_test_configs/user_ab_tests)은 무조건 드롭 [M] |
| supabase/migrations/20240102 A/B 시스템 | supabase/migrations/20240102000001_ab_testing_system.sql | A/B 일원화 따라감 | 8테이블 실험 스키마는 Supabase A/B 서브 라이브러리와 짝 — ab_testing의 선택적 impl에 들어가거나 함께 삭제 [S, 결정 종속] |

### 4.2 runtime-flag (8행)

| 대상 | 현재 위치 | 이동 | 근거 요약 |
|------|-----------|------|-----------|
| flag:`isAuthenticationEnabled` | app_feature_config.dart:30 | 유지 | 코어 라우터/인증 셸의 진짜 의존성 없는 행동 토글(리다이렉트·라우트 보호). 최종 12 생존 [XS] |
| flag:`isOnboardingEnabled` | app_feature_config.dart:56 | 유지 | 항상 출하되는 온보딩 셸의 dep-free 라우터 리다이렉트 토글. 최종 12 생존 [XS] |
| flag:`isDarkModeEnabled` | app_feature_config.dart:61 | 유지 | 코어 테마의 dep-free 토글. 최종 12 생존 [XS] |
| flag:`isMultiLanguageEnabled` | app_feature_config.dart:62 | 유지 | 코어 i18n 선택기의 dep-free 토글. 최종 12 생존 [XS] |
| flag:`isForceUpdateEnabled` | app_feature_config.dart:64 | 유지+배선 | ForceUpdateService가 부트에 배선되면 실토글이 됨(현재 콜사이트 0 검증). 강제 업데이트는 core-always, 플래그는 정당한 킬 노브 [XS, 배선은 서비스 행에 계상] |
| flag:`isNetworkMonitoringEnabled` | app_feature_config.dart:65 | 유지+배선 | 연결 모니터링은 저렴한 상시 코어(오프라인 배너는 누락 필수재); 소비자가 생기면 실플래그화. 최종 12 생존 [XS] |
| flag:`isPrivacyConsentEnabled` | app_feature_config.dart:66 | 유지+배선 | ATT/동의는 상시 컴플라이언스 코어, 현재 R2 splash 우회로 죽어 있음; 트래킹 전무 앱을 위한 희귀한 opt-out으로 생존 [XS, 도달성 수정은 splash 행에 계상] |
| flag:`isDeveloperOptionsEnabled` | app_feature_config.dart:71 | 재정의 | 현재 아무것도 gate 안 함(feature_config_view 라우트 게이트 없음 검증). 개발 플래그 토글 화면을 실제로 gate하도록 재정의, 기본 kDebugMode — prod 출하 중인 개발 화면 수리 [S] |

### 4.3 core-always (25행)

| 대상 | 현재 위치 | 이동 | 근거 요약 |
|------|-----------|------|-----------|
| svc:app_lifecycle_service.dart | app/lib/core/services/app_lifecycle_service.dart | unwired→core-always+배선 | main.dart:169-191 인라인 라이프사이클 중복을 대체하려 작성된 서비스; 배선 후 인라인 삭제. 라이프사이클 훅이 패키지용 seam이 됨. ※순서 제약: 항목 14 배선 **전에** badge 훅(:47) 제거 — 안 하면 badge/Drift 결합이 상시 코어에 재유입 [S] |
| svc:app_review_service.dart | app/lib/core/services/app_review_service.dart | unwired→core-always+배선 | 스마트 리뷰 프롬프트는 콜사이트 0인데 naive launch-count==3 중복이 배선됨(app_config.dart:209-223) + 설정 수동 경로까지 3중. 스마트 쪽으로 일원화 [S] |
| svc:force_update_service.dart | app/lib/core/services/force_update_service.dart | unwired→core-always+배선 | 콜사이트 0 검증. fork-to-ship 신뢰성 필수재; 항목 4 부팅 순서 수정 후 부트 배선, RC seam으로 최소 버전 읽음 [S] |
| svc:network_status_service.dart | app/lib/core/services/network_status_service.dart | unwired→core-always+배선 | Provider는 있는데 소비자 0; 오프라인 UX는 누락된 상시 필수재. 오프라인 배너 소비자 배선; connectivity_plus는 코어 허용 가능 micro-dep [S] |
| svc:privacy_consent_service.dart | app/lib/core/services/privacy_consent_service.dart | 유지+배선 (R2 도달성 수정) | ATT + 동의 영속은 상시 컴플라이언스 코어 — 유일한 진입점이 도달 불가 splash라 현재 죽음. 부트 가드 배선으로 부활; UMP/EEA는 ads 패키지 쪽 [S, 항목 13 내] |
| svc:share_service.dart | app/lib/core/services/share_service.dart | unwired→core-always+배선 | share_plus는 가볍고 '앱 공유'는 보편적 설정 행; 죽은 dep을 지고 가는 대신 신규 isShareAppEnabled 뒤에 배선 [XS-S] |
| svc:snackbar_service.dart | app/lib/core/services/snackbar_service.dart | 유지 | 잘 배선된 전역 피드백 프리미티브 — 이미 올바른 버킷 [없음] |
| feature:auth | app/lib/features/auth/ | 분할 (셸 잔류, email 경로→패키지, 풋건 삭제) | 잠금화면/인증 게이트 셸은 코어; email/password 경로는 supabase 패키지 동행; R4 데모 우회 즉시 삭제(auth_view_model.dart:81,139); '/authentication' 유령 내비게이션 수정(실제 Routes.auth='/auth') [M] |
| feature:onboarding | app/lib/features/onboarding/ | 유지 (페이월 스텝→monetization 훅) | 플래그 토글 코어 셸; 페이월 스텝은 monetization 패키지 제공 훅으로 바꿔 IAP 없이 컴파일. 미사용 introduction_screen dep 제거(검증) [S-M] |
| feature:permission | app/lib/features/permission/ | 분할 (위치 행→location 패키지, 1010줄 분할) | 순차 권한 플로우 셸은 코어; isLocationEnabled로 게이트된 7개 geolocator 섹션은 location 패키지가 주입하는 행으로. 800줄 규칙 초과로 분할 [M] |
| feature:settings | app/lib/features/settings/ | 유지 (feature_config_view 게이트) | 거의 출시급 설정 셸은 코어 잔류; feature_config_view(런타임 플래그 변조·영속 없음·게이트 없음 검증)는 재정의된 isDeveloperOptionsEnabled 뒤로 [M] |
| feature:splash | app/lib/features/splash/ | 유지+도달성 수정 (R2) | 부트 파이프라인(동의→ATT→라우팅 결정)은 코어; router.redirect 우회 재검증됨 — 수정하면 ATT 컴플라이언스·동의·스플래시 광고 기회 부활 [M] |
| core:router.dart | app/lib/core/router.dart | 유지 (R2 수정) | 코어 셸; 수리는 /splash 무조건 우회와, 광고 셸 래퍼(router.dart:138-145 검증)의 패키지 등록형 라우트 데코레이터화뿐 [S] |
| core:error_handler.dart | app/lib/core/error_handler.dart | 유지+setupGlobalErrorHandling 배선 | runApp 전 main에서 배선(현재 콜사이트 0); app_config.dart:169의 병렬 Crashlytics 연결 중복 제거; crash seam 경유 보고로 firebase 없이도 dep-free 동작 [S-M] |
| core:design/ (시스템 2종) | app/lib/core/design/ | 유지 | 듀얼 디자인 시스템은 의도된 앱별 선택 표면; flex_color_scheme/google_fonts는 허용 가능한 코어 dep [없음] |
| core:widgets/ (~20개 카테고리) | app/lib/core/widgets/ | 유지 (ads/→ads 패키지, media/ barrel→삭제) | 적응형 위젯 라이브러리는 상시 코어의 심장; ads/ad_container는 ads 패키지 동행. ※결합 지점은 ad_container.dart:57의 코어 상태 `settings.isSubscriptionActive` — 계획이 코어에 남기는 바로 그 isPremium seam이며, 역전은 패키지 방향성 문제일 뿐(콜백/프로바이더 주입, 공수 불변). 빈 media/ barrel은 죽은 코드 [S] |
| core:responsive/ | app/lib/core/responsive/ | 유지 | dep-free 반응형 인프라, 올바른 버킷 [없음] |
| core:state/ | app/lib/core/state/ | 유지 | 영속 설정 + 인증 상태 머신은 코어; 구독 상태는 코어 잔류. ※settings.dart:356은 빈 `checkAndUpdateSubscription()` stub(+아래 주석 처리된 죽은 블록)이며 verifySubscription 참조가 아님 — 항목 21에서 정리 [S] |
| core:utils.dart + core/utils/ | app/lib/core/utils.dart, app/lib/core/utils/ | packages/utils로 병합 | 유틸 거처 중복; workspace 추출(항목 19) 전에 이미 보편화된 utils 패키지로 단일 SSOT [S] |
| data:Drift 레이어 | app/lib/data/ | 유지 (user/badge 테이블→example, definitions/ vs generated/ SSOT 정리) | 로컬 DB는 무조건 코어(죽은 isLocalDatabaseEnabled가 방증). user/badge 테이블은 sample_tables 패턴 따라 example 복사로 [M] |
| data:datasources/remote | app/lib/data/datasources/remote/ | 분할 (api_client 잔류, supabase_*→supabase 패키지) | 평범한 HTTP api_client는 가벼운 코어; supabase_database/supabase_datasource는 supabase_flutter dep 보유로 패키지 동행 [S] |
| domain/ (auth_actions, action_result, domain_providers) | app/lib/domain/ | 유지 | 얇은 dep-free 액션 레이어, 올바른 버킷 [없음] |
| feature_cli definitions (21개) | tools/feature_cli/lib/feature_definitions.dart | 새 분류 체계 중심 재작성 | 툴링은 템플릿 잔류하되 정의는 최종 분류에서 재생성: 패키지 항목이 실제 pubspec 편집 + init 삽입 수행(M2 수리). ※재작성 시점은 항목 16에서 **P2(항목 20 인접)로 연기** — MODULES.md 분류 동결이 선행 [M-L] |
| feature_cli generate (스캐폴더) | tools/feature_cli/lib/commands/generate_command.dart | 유지 | feature_cli의 가장 건강한 부분; 템플릿 툴링으로 올바른 버킷 [없음] |
| i18n: 8개 로케일 | app/assets/languages/ | 유지 | 작동하는 i18n 인프라는 코어; 하드코딩 한국어 103파일은 별도 스윕(항목 23) + 신규 하드코딩 lint [스윕은 항목 23] |

### 4.4 delete (24행)

| 대상 | 현재 위치 | 이동 | 근거 요약 |
|------|-----------|------|-----------|
| flag:`isLocalDatabaseEnabled` | app_feature_config.dart:25 | flag→삭제 | 아무것도 gate 안 함 — Drift DB는 무조건 생성되는 상시 코어; feature_flag 문자열 맵만 읽음 [XS] |
| flag:`isDatabaseSyncEnabled` | app_feature_config.dart:27 | flag→삭제 | sync 코드 어디에도 reader 0; 실제 sync 기능이 생길 때 supabase 패키지 옵션으로 재추가 [XS] |
| flag:`isSocialAuthEnabled` | app_feature_config.dart:33 | flag→삭제 | gate하는 코드 0. 미래 social_auth 패키지 안에서 재창조 [XS] |
| flag:`isICloudEnabled` | app_feature_config.dart:36 | flag→삭제 | 컴파일되지도 않는 서비스의 설정 UI 섹션만 토글(icloud_storage 주석 처리, 구현은 examples) [XS] |
| flag:`isAnalyticsEnabled` | app_feature_config.dart:51 | flag→삭제 | isFirebaseAnalyticsEnabled의 죽은 중복 — 실코드 reader 없음 [XS] |
| flag:`isCrashReportingEnabled` | app_feature_config.dart:53 | flag→삭제 | 죽은 중복 — error_handler/app_config는 isFirebaseCrashlyticsEnabled 사용 [XS] |
| flag:`isCameraEnabled` | app_feature_config.dart:57 | flag→삭제 | 템플릿 내 gate 0 (camera dep 주석 처리, 구현은 examples/). 카메라 기능은 example 복사로 존속 [XS] |
| flag:`isFileStorageEnabled` | app_feature_config.dart:59 | flag→삭제 | gate 0 — file_picker/image_picker는 lib/ 어디서도 import 안 됨, 구현은 examples/ [XS] |
| flag:`isBadgeSystemEnabled` | app_feature_config.dart:60 | flag→삭제 | ※실제 reader 2곳 존재(app_lifecycle_service.dart:47, notification_settings_widget.dart:93)하나 main.dart:107-110/184-186이 무조건 배선해 우회 — 삭제+배선 정리에 순서 제약(4.3 라이프사이클 행 참조). badge 시스템 자체는 example로 [XS] |
| flag:`isHomeWidgetEnabled` | app_feature_config.dart:63 | flag→삭제 | 어디에도 read 0; dep 주석 처리; 깨진 nofon 네이티브 잔재도 함께 삭제(§8 참조). 구현 없는 플래그 = 정의상 wrong bucket [XS] |
| flag:`isTestMode` | app_feature_config.dart:69 | flag→삭제 | 69행에만 존재, _fields 레지스트리에도 부재 — fromMap으로 토글조차 불가. 완전 사망 [XS] |
| flag:`isDebugMode` | app_feature_config.dart:70 | flag→삭제 | Flutter kDebugMode를 기능적 reader 0으로 섀도잉; kDebugMode 직접 사용 [XS] |
| flag:`isVerboseLoggingEnabled` | app_feature_config.dart:72 | flag→삭제 | logger가 읽지 않음; bool 플래그 대신 설정의 logger 레벨로 대체 [XS] |
| svc:ab_test_experiment.dart | app/lib/core/services/ab_test_experiment.dart | 삭제 | A/B 메커니즘 #2, 외부 콜사이트 0; 4→1 일원화에서 소멸 [XS] |
| svc:ab_testing_provider.dart | app/lib/core/services/ab_testing_provider.dart | 삭제 | A/B 메커니즘 #3 글루; 읽히는 순간 크래시(main.dart ProviderScope에 sharedPreferencesProvider 오버라이드 부재 검증). 일원화에서 소멸 [XS] |
| svc:firebase_ab_testing_service.dart | app/lib/core/services/firebase_ab_testing_service.dart | 삭제 | A/B 메커니즘 #4 — 현재 유일하게 배선된 쪽(app_config.dart:184 검증)이지만 항목 14에서 ABTestService로 교체: **먼저 un-wire** 후 삭제 [S] |
| svc:feature_flag_service.dart | app/lib/core/services/feature_flag_service.dart | 삭제+얇은 대체 | 271줄 플래그 메커니즘 #5, 콜사이트 0, 죽은 플래그를 비추는 40키 문자열 맵. 유용한 아이디어(RC > 로컬 기본값)만 ~50줄 부트 타임 RC 브리지로 회귀 [S 삭제, M 브리지] |
| pkg:flutter_heatmap_calendar | app/packages/flutter_heatmap_calendar/ | flowmodoro repo로 퇴거 | 추적 파일 123개, 소비자 0, flowmodoro 잔재(M3). 모든 클론의 죽은 무게 [XS] |
| pkg:geofence_foreground_service | app/packages/geofence_foreground_service/ | flowmodoro repo로 퇴거 | 네이티브 플러그인 추적 파일 134개, 인앱 소비자 0; geofence example도 동반 퇴거 [XS] |
| pkg:app_blocker (stub) | app/packages/app_blocker/ | 삭제 | 미추적 빈 stub + com.flowmodoro 경로 누출; pubspec도 lib도 없음 [XS] |
| pkg:flutter_openmoji (stub) | app/packages/flutter_openmoji/ | 삭제 | 빈 미추적 디렉토리 스켈레톤; 실기능은 아이콘 example이 참조하는 pub.dev 패키지 [XS] |
| examples/geofence_service.dart | examples/optional_services/geofence_service.dart | vendored 플러그인과 동반 퇴거 | 퇴거되는 vendored 플러그인 없이는 동작 불가한 flowmodoro 도메인 코드; 소유 앱 repo로 (항목 16) [XS] |
| pubspec: zero-import dep 13개 | app/pubspec.yaml | 코어 pubspec에서 삭제 | firebase_in_app_messaging, fl_chart, auto_animated, flutter_inappwebview, morphing_text, numberpicker, simple_circular_progress_bar, wakelock_plus, screenshot, file_picker 등 lib/ import 0 검증. ※단 **네이티브 참조 스윕 필수**: MainActivity.kt:6에 image_picker import가 활성(§8 참조) [S] |
| pubspec: 주석 처리 dep 블록 (20항목) | app/pubspec.yaml:142-169 | 블록 삭제; example 연계 항목→example README로 | 경쟁하는 옵션 기능 메커니즘 5개 중 #4. 순수 comment-ware 고아 8개(audio_session, audioplayers, flutter_soloud, google_maps_flutter, image_gallery_saver 등)는 삭제, example 연계 항목은 README의 dep 라인으로 이관 [S] |

### 4.5 example (10행)

| 대상 | 현재 위치 | 이동 | 근거 요약 |
|------|-----------|------|-----------|
| svc:badge_service.dart | app/lib/core/services/badge_service.dart | core→example | 앱 소유 Drift badge 테이블 + badges.json 샘플 데이터에 결합된 게이미피케이션 도메인 — 경계 규칙상 앱이 소유/수정할 코드. sample_tables 옆 복사용으로 출하 [M] |
| feature:home | app/lib/features/home/ | 유지 (소유형 replace-me 표면으로 공식화) | 의도적으로 얇은 앱별 placeholder — 경계 규칙상 앱 소유 코드. 부팅을 위해 물리적으로 lib에 남되 example로 문서화·취급 [XS, 문서만] |
| examples/camera_service.dart | examples/optional_services/camera_service.dart | 유지+수리 (이름 비의존, README, dep 라인) | 정당한 복사용(자체 네이티브 dep)이나 깨짐: package:boilerplate import가 rename 후 사망(M4), 필수 dep 3개가 주석 처리에 문서 0 [S] |
| examples/file_service.dart | examples/optional_services/file_service.dart | 유지+수리 (icloud 순환 import 절단) | 복사용이나 icloud example과의 미문서화 순환 의존 + 주석 처리된 archive dep; import 수리, 페어링 문서화 또는 분리 [S] |
| examples/home_widget_service.dart | examples/optional_services/home_widget_service.dart | 유지+수리 (깨진 네이티브 잔재 삭제) | Dart 쪽은 복사용으로 유지하되 템플릿의 깨진 네이티브 절반은 삭제. ※보정: Kotlin 2파일이 pubspec.lock에 없는 home_widget 플러그인 클래스를 import → **라이브 Android 빌드 블로커**(§8); manifest↔클래스명 불일치 주장은 부정확(패키지 선언은 일치, nofon 디렉토리는 lint 경고일 뿐) [S] |
| examples/icloud_service.dart | examples/optional_services/icloud_service.dart | 유지+수리 (순환 import, entitlements 문서) | 복사용; file_service와의 순환 페어링 수리, iOS entitlements와 icloud_storage dep 라인 문서화 [S] |
| examples/audio_recorder.dart | examples/optional_widgets/audio_recorder.dart | 유지+수리 (README, dep 라인, 930줄 분할) | 플래그/정의/README 없는 고아 기능 + 주석 처리 dep 3개; 문서 갖춘 복사용으로 유지, 930줄 파일 분할 [S] |
| examples/icon_map.dart + icon_picker_dialog.dart | examples/optional_widgets/ | 유지+수리 (2파일 복사 절차 문서화) | picker가 미문서화 복사 후에만 존재하는 lib/core/constants/icon_map.dart를 import; 목적지 + flutter_openmoji dep 라인 문서화 [XS] |
| examples/sample_tables/ | examples/sample_tables/ | 유지 (골드 스탠다드) | 모범 복사 패턴(유일하게 README 보유); 유일한 수리는 package:boilerplate import 12곳의 이름 비의존 재작성(M4) [S] |
| webapp/ (랜딩 + 프라이버시) | webapp/ | 유지+placeholder 필러 배선 | 앱별 소유 HTML 복사용. 유령 tools/cli 필러 구현(README가 존재하지 않는 webapp_generator.py와 HTML에 없는 placeholder 참조), lang= 하드코딩 해제. privacy-policy.html은 항목 13 법적 HTML 자동 호스팅의 입력 자산 [S-M] |

---

## 5. 삭제 확정 13개 플래그

전부 "**아무것도 gate 안 함**"이 저장소 직접 검증으로 확인됨 (reader는 _fields 레지스트리, 콜사이트 0인 FeatureFlagService 문자열 맵, 게이트 없는 개발 화면뿐). 삭제는 P0/P1에 즉시 가능(항목 16에 편입, 2-phase 규칙 비대상).

| 플래그 | 증거 1줄 |
|--------|----------|
| `isLocalDatabaseEnabled` | Drift DB는 무조건 생성 — 플래그는 feature_flag 문자열 맵만 읽음 |
| `isDatabaseSyncEnabled` | sync 코드 어디에도 reader 0 |
| `isSocialAuthEnabled` | gate하는 코드 0 — 기능 자체가 부재 (신규 기능 P2로 재창조) |
| `isICloudEnabled` | 컴파일되지 않는 서비스(icloud_storage 주석 처리)의 설정 UI 섹션만 토글 |
| `isAnalyticsEnabled` | isFirebaseAnalyticsEnabled의 죽은 중복, 실코드 reader 없음 |
| `isCrashReportingEnabled` | 죽은 중복 — 실코드는 isFirebaseCrashlyticsEnabled를 읽음 |
| `isCameraEnabled` | camera dep 주석 처리, 구현은 examples/ — 템플릿 내 gate 0 |
| `isFileStorageEnabled` | file_picker/image_picker lib/ import 0, 구현은 examples/ |
| `isBadgeSystemEnabled` | ※실제 reader 2곳 존재(app_lifecycle_service.dart:47, notification_settings_widget.dart:93)하나 main.dart가 무조건 배선해 우회 — **삭제+배선 정리 시 순서 제약**: 항목 14의 라이프사이클 배선 전에 badge 훅 제거, badge 이동과 함께 설정 위젯 게이트 제거 |
| `isHomeWidgetEnabled` | read 0 + dep 주석 처리 + 네이티브 잔재는 깨짐 — 구현 없는 플래그 |
| `isTestMode` | app_feature_config.dart:69에만 존재, _fields 레지스트리 부재로 토글 불가 |
| `isDebugMode` | kDebugMode 섀도잉, 기능적 reader 0 |
| `isVerboseLoggingEnabled` | logger가 읽지 않음 — logger 레벨 설정으로 대체 |

---

## 6. 신규 기능 우선순위 (32건)

`†` = 비평가 강등/재배치 (보정 9: 분류가 제안한 P1 묶음은 P1을 ~5주로 팽창시킴 → 강등 적용 후 P1 ≈ 4주). 핵심 강등: **social_auth P1→P2** (신규 항목 21.5; 신규 패키지 작업은 로드맵 자체의 추출 게이트상 P2 소속). AsyncValueView·온보딩 퍼널 이벤트는 P1→P2(항목 23), 페이월 RC 배선은 P1→P2(항목 21 이후), 딥링크·점검 모드는 P1 승격 기각(항목 23 잔류), 스켈레톤·데이터 내보내기는 항목 23으로 합류.

| 우선순위 | 기능 | 목표 위치 | 공수 | 근거 |
|----------|------|-----------|------|------|
| P0 | 인앱 계정 삭제 | core-always (인증 활성 시 설정 진입점) + supabase 패키지 delete-account 에지 함수 | 2-3d | 계정 생성 지원 시 Play+App Store 하드 요구사항 — 템플릿은 Supabase 인증 출하 중. 부재 검증(항목 13 편입) |
| P0 | ATT + 프라이버시 동의 부트 도달성 (R2 수정) | core-always (부트 가드 / splash 도달성) | 0.5-1d (항목 13 내) | 완전한 ATT/동의 구현이 존재하나 라우터가 /splash를 무조건 우회(검증) — App Store 컴플라이언스 블로커이자 동의·스플래시 광고 부활 지점 |
| P0 | iOS PrivacyInfo.xcprivacy 프라이버시 매니페스트 | core-always (app/ios/Runner 커밋; tools/cli가 앱별 패치) | 0.5-1d | 2024년 5월부터 required-reason API(shared_preferences, path_provider) 사용 시 Apple 필수. 트리에 .xcprivacy 0개 — 최저가 컴플라이언스 수리 |
| P0 | AdMob UMP/EEA 동의 + NPA 폴백 + COPPA 노브 | package (ads; 항목 13에서 코어 선구축) | 3-5d (통합) | 2024년부터 EEA 광고 송출에 인증 CMP 필수; UMP API는 google_mobile_ads ^7에 내장. 현재 모든 광고 경로에 동의 체크 0 |
| P1 | 강제 업데이트 / 최소 버전 배선 | core-always (부트, isForceUpdateEnabled 뒤) | 0.5-1d | ForceUpdateService 완성 + 콜사이트 0 검증 — 포크가 깨진 릴리즈를 회수 못함. 배선만; 항목 4 이후 |
| P1 | 전역 에러 핸들러 배선 | core-always (runApp 전 main.dart, crash seam 경유) | 1-2d | setupGlobalErrorHandling 콜사이트 0 — 모든 포크에서 미포착 zone/Flutter 에러가 미보고. app_config의 병렬 Crashlytics 연결 중복 제거 (항목 14) |
| P1 | 크래시 분류 메타데이터 (custom keys / user id / 플래그+변형 스냅샷) | core-always (firebase 패키지가 구현) | 0.5d | setCustomKey/setUserIdentifier 저장소 전체 0; 파생 앱 4개+에서 flavor/템플릿 버전/플래그 상태 없는 크래시 리포트는 분류 불능 (항목 14) |
| P1→P2† | 점검 모드 게이트 | core-always (라우터/부트 가드 + MaintenanceView, RC 소스, 신규 isMaintenanceModeEnabled 뒤) | 1d | RC 키와 getter가 존재하나 reader 0 — 광고된 원격 킬 기능이 허구. 승격 기각, 항목 23 잔류 |
| P1→P2† | 딥링크 / universal + app links | core-always (app_links + GoRouter; tools/cli가 intent-filter/entitlements 생성) | 2-3d | 2026 기준 성장 인프라가 전무 — GoRouter 덕에 배선은 저렴; push-to-screen·공유 왕복이 의존. 승격 기각, 항목 23 잔류 |
| P1 | 스마트 인앱 리뷰 일원화 | core-always + runtime flag (isAppReviewPromptEnabled) | 0.5-1d | 경쟁 경로 3개: naive launch-count==3 배선됨, 스마트 AppReviewService 미배선(콜사이트 0), 설정 수동 버튼. 스마트로 일원화 (항목 14) |
| P1→P2† | 소셜 로그인: Apple + Google (Kakao 서브 라이브러리) | package (social_auth, Supabase signInWithIdToken 백엔드) | 1주 (+2-3d Kakao) | 현재 생체인증 전용; 삭제되는 R4 데모 인증이 이 공백을 메우고 있어 제거(항목 14)가 공백 생성. **비평가 강등: 신규 항목 21.5 (P2)** |
| P1→P2† | 온보딩 퍼널 분석 이벤트 | core-always (이벤트 컨벤션 + analytics seam 경유 호출) | 0.5-1d | 온보딩이 이벤트 0개 방출 — 가장 중요한 퍼널의 이탈 측정 불가; FirebaseService.logEvent 기존재. 항목 23으로 |
| P1→P2† | 통합 비동기 상태 프레임워크 (AsyncValueView) | core-always (core/widgets, 기존 error/loading/empty 위젯 + retry 조합) | 1-2d | 3개 부품이 미사용으로 존재하는데 모든 화면이 when/loading/error를 수제작. 항목 23으로 |
| P1→P2† | 페이월 RC/A-B 변형 배선 | runtime-flag 인프라 (RC 주도 선택) + monetization 패키지 페이월 | 1-2d | subscriptionVariant/showDiscountFirst RC getter 콜사이트 0 + ABTestService도 양 페이월에 미연결. **항목 21 이후로 (권한 수리 선행)** |
| P1 | 세션 만료 / 토큰 갱신 실패 처리 | core-always (인증 상태 배관 + 라우트 가드 리다이렉트) | 1d | onAuthStateChange가 signedIn/signedOut/userUpdated만 처리; 만료 세션은 조용히 실패. 코어 인증 셸 소폭 수정 (항목 14) |
| P1 | Play Data Safety 선언 생성기 | tools/cli + fastlane (활성 패키지 셋에서 생성) | 1-2d | FA+Crashlytics+FCM+AdMob+위치 출하로 모든 포크가 까다로운 폼 직면; 패키지 분류에서 생성하면 correct-by-construction (항목 13) |
| P2 | IAP grace period / billing-retry 권한 처리 | package (monetization, 항목 21 내부) | 항목 21에 +1-2d | 서버 검증(R3) 전에는 무의미, 이후에는 유료 구독자 이탈 방지에 필수. 클라이언트 전용 권한 위에 절대 구축 금지 |
| P2 | 프로모/오퍼 코드 + 인트로 가격 | package (monetization, 항목 21 이후) | 2-3d | 표준 런칭 가격/윈백 레버지만 깨진 권한 위 구축은 낭비 — 항목 21 하드 게이트 |
| P2 | RC → 플래그 오버라이드 브리지 | runtime-flag 인프라 (부트: yaml profile → RC 오버라이드 → freeze) | 1-2d | 생존 12개 플래그에 진짜 원격 다이얼 제공; 삭제되는 271줄 FeatureFlagService를 ~50줄로 대체. 항목 4·16 이후 엄격 순서 |
| P2 | Drift 스키마 마이그레이션 규율 | core-always (onUpgrade 스캐폴드 + 스키마 export + step-migration CI) | 1-2d | schemaVersion=1 + onCreate 전용 전략은 포크가 v2를 출하하는 날 사용자 DB를 깨뜨림; 항목 20의 drift CI와 정렬 |
| P2 | 사용자 데이터 내보내기 (GDPR 이동권) | core-always (isDataExportEnabled 뒤 설정 행; dep-free Drift→JSON + ShareService) | 1-2d | GDPR 20조 + Play 리스팅 가점; 계정 삭제·신규 배선 공유 서비스와 자연 페어링. 항목 23으로† |
| P2 | 스켈레톤 로더 | core-always (dep-free shimmer ~100줄, AsyncValueView와 페어) | 1d | 기본적 체감 성능 패턴이 전무; 비동기 프레임워크 후 저렴. 항목 23으로† |
| P2 | 성능 모니터링 (firebase_performance) | package (firebase 패키지 옵션, 기본 off) | 0.5-1d | 'production-ready' 템플릿의 포크 4개+에 콜드스타트/네트워크 텔레메트리 0; 기존 패키지 경계 안 dep 1개 + init 1개 |
| P2 | 접근성 채택 스윕 (S* 위젯 + textScaler 정책) | core-always (기존 369줄 시맨틱 라이브러리 채택; MODULES.md 컨벤션) | 2-3d (i18n 스윕과 통합) | 강력한 미채택 자산(176파일 중 ~10개만 사용); EU 접근성법이 기준 상향. 항목 23 i18n 스윕에 합류 |
| P2 | 오프라인 sync 결정 (supabase sync 패키지 구축 vs local-only 기본 선언) | package (supabase sync) 또는 죽은 syncUserData 삭제 + MODULES.md 입장 문서화 | 0.5d 디스코프 / 1-2주 구축 | 현재 반쪽 상태(에지 함수 + 클라이언트 메서드, 콜사이트 0, 큐/충돌 정책 없음)가 최악의 선택지 — 명시적 로드맵 결정 항목으로 |
| P3-later | What's-new / 체인지로그 다이얼로그 | core-always (버전 키 다이얼로그, 콘텐츠는 앱별 자산) | 1d | 좋은 리텐션 터치지만 현재 어떤 포크에도 런칭 무관 |
| P3-later | 광고 미디에이션 준비 | package (ads, opt-in 어댑터) | 1-2d (트리거 시) | eCPM 최적화 + 네이티브 어댑터·SKAdNetwork 유지비; 최적화할 수익이 있는 포크가 아직 없음 |
| P3-later | deferred 딥링크 / 설치 어트리뷰션 | package (자체 SDK dep) | 2-3d (트리거 시) | 포크가 유료 UA를 돌릴 때만 유효; 트리거까지 연기 |
| P3-later | 추천인 코드 | example / 앱 특화 패키지 | 1-2주 (필요 시) | 백엔드 발급 + 앱 특화 보상 로직 필요 — 템플릿 일반화 불가; MODULES.md에 non-goal로 문서화 |
| P3-later | 로컬 백업/복원 (iCloud/Drive) | package 또는 example 복사 | 3-5d | local-first 앱에 가치 있으나 오프라인 sync 결정에 블로킹 — 두 스토리 충돌 방지 |
| P3-later | 앱 숏컷 / quick actions | example (액션은 앱 특화) + 소형 코어 훅 | 1d | 저렴한 리텐션 표면, 외형적 우선순위 |
| P3-later | 백그라운드 태스크(workmanager) + 햅틱(vibration) 승격 | package (포크 수요 시; 아니면 comment-ware와 함께 삭제) | 각 2-3d (트리거 시) | comment-ware 고아 8개 중 실패키지 가치가 있는 유일한 2개; 나머지는 주석 블록과 함께 삭제 |

---

## 7. 누락/부분 기능 전체 목록 (35건)

상태: **absent** = 부재 / **partial** = 부분 구현 / **present-unwired** = 구현 존재하나 배선 0. 전 건 저장소 직접 grep/find로 검증 (문서 인용 아님).

| 상태 | 분류 | 기능 | 제안 위치 | 근거 1줄 |
|------|------|------|-----------|----------|
| absent | store-compliance | 인앱 계정 삭제 | core-always (설정 진입점) + supabase delete-account 에지 함수 | 계정 생성 지원 앱에 Play+App Store 공통 필수 — 템플릿은 Supabase 인증 출하 중 |
| absent | store-compliance | AdMob UMP / EEA 동의 플로우 | package (ads — ad_service init에서 광고 로드 전 동의 요청) | 2024년부터 EEA/UK 광고 송출에 인증 CMP 필수; ConsentInformation 게이트 없으면 EEA 광고 수익 0 + 정책 위반 |
| absent | store-compliance | iOS PrivacyInfo.xcprivacy | core-always (app/ios/Runner 템플릿 커밋; tools/cli가 앱별 추적 도메인 패치) | required-reason API(shared_preferences, path_provider) 사용 시 2024년 5월부터 Apple 필수; 트리에 0개 |
| absent | store-compliance | Play Data Safety 선언 생성기 | tools/cli + fastlane (활성 패키지 셋에서 생성) | FA+Crashlytics+FCM+AdMob+위치 출하로 모든 포크가 비자명한 폼 직면; 항목 13에 명기됨 |
| present-unwired | store-compliance | ATT + 프라이버시 동의 도달성 | core-always (부트 파이프라인: /splash 도달성 복구 또는 부트 가드 이전) | 완전한 구현 존재(PrivacyConsentService.requestTrackingAuthorization 등)하나 R2 우회로 전부 데드코드 |
| absent | store-compliance | 아동 대상 / COPPA 광고 토글 | package (ads 설정: app_config.yaml 주도 RequestConfiguration 블록 1개) | Families 정책·COPPA가 tagForChildDirectedTreatment / maxAdContentRating 요구 — 다앱 지향 템플릿에 노브 필수 |
| absent | growth | 딥링크 + universal/app links | core-always (app_links + GoRouter; tools/cli가 intent-filter + entitlements 생성) | 마케팅 캠페인·push-to-screen·공유 왕복 전부 URL→route 필요; GoRouter 기사용으로 배선 저렴 |
| absent | growth | deferred 딥링크 / 설치 어트리뷰션 | package (자체 SDK dep — appsflyer/adjust/Install Referrer) | 유료 UA 전까지 불요 — 트리거 시 연기 |
| present-unwired | growth | 공유 서비스 배선 | core-always (설정 '앱 공유' 행에 배선; share_plus는 가벼움) | share_plus ^10.1.4 출하 + share_service.dart 존재하나 콜사이트 0 |
| partial | growth | 인앱 리뷰 프롬프트 (스마트 트리거) | runtime-flag + core-always (AppReviewService로 일원화, naive 경로 삭제) | naive 트리거가 배선됨(main.dart:103, appLaunchCount==3에서 1회) 반면 스마트 서비스는 콜사이트 0 |
| absent | growth | 추천인 코드 | package 또는 example (앱 특화 도메인) | 백엔드 발급/상환 + 앱 특화 보상 필요 — 템플릿 일반화 불가, non-goal 문서화 |
| present-unwired | growth | Firebase In-App Messaging — 배선 또는 삭제 | 코어 pubspec에서 삭제; 포크 수요 시 package로 재도입 | firebase_in_app_messaging ^0.9.0+5가 Dart 참조 0으로 컴파일됨 — 모든 포크의 순수 바이너리/기동 무게 |
| present-unwired | growth | 홈 화면 위젯 네이티브 잔재 (깨짐 + 파생 앱 누출) | 네이티브 잔재 삭제 (manifest receiver, res/xml/home_widget.xml, kotlin nofon/widget/*); Dart는 example 복사 유지; 고아 isHomeWidgetEnabled 폐기 | ※보정: Kotlin이 pubspec.lock에 없는 home_widget 플러그인 클래스를 import — **라이브 Android 빌드 블로커**(§8); M3 확장 |
| absent | growth | 앱 숏컷 / quick actions | example (액션은 앱 특화) + 소형 코어 훅 | 저렴한 리텐션 표면; quick_actions dep + 앱별 액션 정의 필요 (저우선) |
| absent | growth | 온보딩 퍼널 분석 이벤트 | core-always (이벤트 네이밍 컨벤션 + features/onboarding 내 호출) | 온보딩이 분석 0건 방출 — 핵심 퍼널 이탈 측정 불가; FirebaseService.logEvent 기존재 |
| present-unwired | monetization | 페이월 RC / 실험 배선 | runtime-flag (코어 RC 변형 선택) → monetization 패키지 페이월 | subscriptionVariant·showDiscountFirst getter 콜사이트 0; ABTestService도 양 페이월에 미연결 |
| absent | monetization | 프로모/오퍼 코드 + 인트로 가격 | package (monetization; 항목 21 서버 검증 게이트) | presentCodeRedemptionSheet·Play 프로모·introductoryPrice 처리 전무 — 권한 SSOT 수리 선행 |
| absent | monetization | grace period / billing-retry 권한 처리 | package (monetization — 항목 21 내부 구현) | billing retry/grace 구독자가 프리미엄 상실(또는 영구 보유) — 만료가 구매 시점 클라이언트 계산이기 때문 |
| absent | monetization | 동의 인지 광고 로드 (NPA 폴백) | package (ads: 동의 상태 키의 AdRequest extras; ad_service.dart 단일 관문) | PrivacyConsentService 데이터가 있어도 광고 요청이 동의를 안 읽음 — UMP의 필수 동반 작업 |
| absent | monetization | 광고 미디에이션 준비 | package (ads, opt-in 어댑터) | AdMob 단독; 미디에이션은 eCPM 상승 대신 네이티브 어댑터 + SKAdNetwork 유지비 — 수익 생긴 포크까지 연기 |
| present-unwired | reliability | 점검 모드 게이트 | core-always (부트/라우터 가드 + MaintenanceView; firebase 패키지 존재 시 RC 소스, 아니면 no-op) | RC 기본값 'maintenance_mode'와 getter 존재하나 reader 0, 차단 뷰 부재 — 원격 킬 기능이 허구 |
| present-unwired | reliability | 강제 업데이트 / 최소 버전 킬스위치 배선 | core-always (항목 4 순서 수정 후 부트 배선; 항목 14 일부) | ForceUpdateService가 RC min_app_version을 읽으나(force_update_service.dart:73) 콜사이트 0 (R5) |
| present-unwired | reliability | 오프라인 우선 sync 스토리 (큐 + 충돌) | package (supabase sync) 또는 'local-only 기본' MODULES.md 문서화 + 죽은 메서드 삭제 | Drift+NetworkStatusService+sync 에지 함수+syncUserData 전부 존재하나 syncUserData 콜사이트 0, 큐/충돌 정책 부재 |
| present-unwired | reliability | 전역 에러 핸들러 + 원격 로그 수집 | core-always (runApp 전 main.dart 배선; firebase 시 logger→Crashlytics.log 브레드크럼) | ErrorHandler의 Crashlytics recordError 존재(error_handler.dart:106,191)하나 setupGlobalErrorHandling 콜사이트 0 (R5) |
| absent | reliability | 크래시 분류 메타데이터 (custom keys / user id / 플래그 스냅샷) | core-always (Firebase init: flavor·template_version·활성 플래그·A/B 변형 설정) | setCustomKey/setUserIdentifier 어디에도 0 — 다앱 운영에서 크래시 분류 불능 |
| absent | reliability | 성능 모니터링 (firebase_performance) | package (firebase 패키지 경계 내 init 1콜, 기본 off) | firebase_performance dep 없음 — 콜드스타트/네트워크/커스텀 트레이스 텔레메트리 0 |
| partial | reliability | 원격 플래그 오버라이드 브리지 (RC → AppFeatureConfig) | runtime-flag 인프라 in core-always (부트: yaml profile → RC 오버라이드 → freeze) | remote_config_service.isFeatureEnabled와 RC 읽는 FeatureFlagService가 존재하나 40개 static 플래그와 미연결 |
| partial | ux-core | 통합 비동기 상태 프레임워크 (loading/error/empty) | core-always (기존 위젯 3종 + retry 콜백 조합 AsyncValueView) | 부품(error_widget·loading_indicator·empty_state)은 따로 존재하나 AsyncValue 인지 통합 뷰 부재 |
| absent | ux-core | 스켈레톤 로더 | core-always (dep-free 커스텀 shimmer ~100줄 또는 skeletonizer) | shimmer/skeleton dep도 구현도 없음; 2026 기준 체감 성능 기본 패턴 |
| partial | ux-core | 접근성 채택 (시맨틱 위젯 + 동적 타입) | core-always (S* 위젯 채택 스윕 + MODULES.md 컨벤션 + textScaler 정책) | 진지한 369줄 시맨틱 래퍼 라이브러리(SText/SImage 등)가 176파일 중 ~10개만 사용 |
| absent | auth-data | 소셜 로그인 (Apple/Google/Kakao) | package (social_auth — 네이티브 설정·URL 스킴·자체 dep; Supabase signInWithIdToken 백엔드) | authentication 패키지는 생체인증 전용; google_sign_in/sign_in_with_apple/kakao dep 0, signInWithOAuth 0 |
| partial | auth-data | 세션 만료 / 토큰 갱신 실패 처리 | core-always (만료 이벤트 → 라우트 가드 리다이렉트) | onAuthStateChange 청취 중(supabase_service.dart:77)이나 signedIn/signedOut/userUpdated만 분기 — 만료는 조용히 실패 |
| absent | auth-data | 사용자 데이터 내보내기 (GDPR 이동권) | core-always (설정 진입점, 일반 Drift→JSON 덤프; 계정 삭제와 페어) | GDPR 20조 + Play 리스팅 가점; dep-free 구현 가능 |
| absent | auth-data | 로컬 백업/복원 | package (자체 네이티브 dep) 또는 example 복사; sync 결정 뒤로 연기 | local-first 기본 템플릿은 기기 분실 시 전 데이터 소실; sqlite 파일의 iCloud/Drive 백업이 표준 답 |
| partial | auth-data | Drift 스키마 마이그레이션 규율 | core-always (onUpgrade 스캐폴드 + drift 스키마 export + CI step-migration 테스트) | schemaVersion=1 + onCreate 전용 — 어떤 포크든 스키마 v2 출하 순간 단계 마이그레이션 필요 |

---

## 8. 즉시 주의 2건

### (a) home-widget Kotlin 잔재 = 라이브 Android 빌드 블로커 (P0)

`app/android/app/src/main/kotlin/com/raynear/nofon/widget/HomeWidget.kt` / `HomeWidgetReceiver.kt`가 `es.antonborri.home_widget.*` 및 `HomeWidgetGlance*` 클래스를 import하는데, home_widget 플러그인은 `app/pubspec.yaml`에서 주석 처리되어 **pubspec.lock에 부재**한다. `androidx.glance`는 `app/android/app/build.gradle:136-138`로 해석되지만 플러그인 클래스는 해석 불가하고, gradle sourceSets 제외도 없다(build.gradle:66 주석 처리됨) → **모든 `flutter build apk`의 Kotlin 컴파일이 실패**. 정적 분석 평결이며 증명 게이트는 로드맵 항목 2의 스모크 테스트. 수리: Kotlin 2파일 + AndroidManifest receiver 블록(AndroidManifest.xml:31) + `res/xml/home_widget.xml` 삭제 — **로드맵 P0 항목 3(부트스트랩 수리)에 편입됨** (+0.5d).

참고(비평가 보정): 두 Kotlin 파일 모두 `package com.raynear.boilerplate.widget`을 선언해 manifest의 해석된 receiver 이름(`.widget.HomeWidgetReceiver`)과 **일치**한다 — 기존 감사가 주장한 manifest↔클래스 불일치는 부정확하며, `com/raynear/nofon/` 디렉토리 vs 패키지 불일치는 lint 경고일 뿐(클래스 해석 무관). 실제 블로커는 위의 플러그인 클래스 부재다.

### (b) zero-import pubspec dep 13개 삭제 시 네이티브 참조 스윕 필수

'lib/ import 0'은 '네이티브 참조 0'이 아니다: `app/android/app/src/main/kotlin/com/raynear/nofon/MainActivity.kt:6`에 `import io.flutter.plugins.imagepicker.ImagePickerPlugin`이 **활성** 상태다(사용처는 전부 주석이나 import는 살아 있음). image_picker를 pubspec에서 지우는 순간 빌드가 즉시 깨진다. 따라서 §4.4의 13개 dep 삭제 행은 반드시 **android/ios 네이티브 참조 스윕 + MainActivity.kt 정리**를 동반해야 한다.

---

*분류 출처: 워크플로우 감사 (인벤토리 2종 + 누락 감사 + 분류 + 비평가 교차 검증, 저장소 40+ 스팟 체크). 상위 문서: [GOAL_AUDIT_ROADMAP.md](GOAL_AUDIT_ROADMAP.md), MODULES.md(항목 16 예정).*
