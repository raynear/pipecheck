# Flutter BoilerPlate 개선 계획 (심층 분석)

> 목표: 원페이지 앱의 경우 `./setup init` → `./deploy` 두 명령으로 스토어 배포까지 완료
> 분석 일자: 2026-03-11

---

## 현재 상태 요약

| 영역 | 점수 | 핵심 이슈 |
|------|------|-----------|
| 데이터 레이어 | ★★★★★ | BaseRepository 패턴 우수, 샘플 테이블만 정리 필요 |
| Feature Flag | ★★★★☆ | 30+ 플래그 잘 구성됨, 프리셋/의존성 해결 부재 |
| 코어 서비스 | ★★★★☆ | 18개 서비스, 일부 중복/미완성 |
| 공통 위젯 | ★★★★★ | 60+ 컴포넌트, 카테고리별 정리 |
| CLI 도구 | ★★★☆☆ | 기본 기능만, Fastlane과 통합 안 됨 |
| Fastlane | ★★★★☆ | 24+ 레인, 환경 설정 분리 |
| 의존성 관리 | ★★☆☆☆ | 140개 중 11개만 필수, 나머지 정리 필요 |
| 자동화 통합 | ★★☆☆☆ | CLI/Fastlane/build.sh 각각 독립, 오케스트레이션 부재 |

---

## Part A: 정리 & 경량화

### A1. 의존성 3단계 분리

**Essential Core (11개) - 항상 포함:**
```
flutter, flutter_riverpod, go_router, drift, drift_sqflite,
freezed_annotation, json_annotation, path_provider,
shared_preferences, uuid, logger
```

**Recommended (10개) - 기본 포함, 제거 가능:**
```
easy_localization, flutter_localized_locales, flex_color_scheme,
google_fonts, cupertino_icons, http, flutter_secure_storage,
lottie, url_launcher, package_info_plus
```

**Optional (~30개) - Feature Flag 연동, 필요시만 추가:**
```
Firebase 6개, Supabase 1개, google_mobile_ads, in_app_purchase,
awesome_notifications 2개, local_auth, connectivity_plus
```

**제거 대상 (~20개) - examples/로 이동:**
```
camera, record, audioplayers, flutter_sound, audio_waveforms,
simple_audio_trimmer, google_maps_flutter, geolocator,
image_picker, image_gallery_saver, gallery_saver_plus,
screenshot, home_widget, icloud_storage, workmanager,
archive, confetti, vibration
```

- [ ] Feature CLI `enable` 시 pubspec.yaml에 의존성 자동 추가
- [ ] Feature CLI `disable` 시 의존성 자동 제거
- [ ] 의존성 간 충돌/중복 검증 로직

### A2. 샘플 데이터 & 패키지 정리

**Drift 테이블:**
- [ ] `user` 테이블만 유지 (인증 필수)
- [ ] `post`, `comment`, `tag`, `post_tag`, `badge` → `examples/sample_tables/`로 이동
- [ ] 예제 테이블에 "이렇게 추가하세요" 주석 가이드 포함

**Local Packages:**
| 패키지 | 결정 | 이유 |
|--------|------|------|
| `authentication` | 유지 | 거의 모든 앱에 필요 |
| `utils` | 유지 | 기반 유틸리티 |
| `ab_testing` | Optional | A/B 테스트 필요한 앱만 |
| `geofence_foreground_service` | 제거 → examples/ | 위치 기반 앱 전용 |
| `flutter_heatmap_calendar` | 제거 → examples/ | 특정 UI 컴포넌트 |
| `app_blocker` | 삭제 | 미완성, dead code |
| `flutter_openmoji` | 삭제 | pub.dev 버전 사용 권장 |

**환경 파일:**
- [ ] `.env.debug`: nofon 고유값 → 플레이스홀더로 변경
- [ ] `CONTAINER_ID=iCloud.com.YOUR_COMPANY.YOUR_APP`
- [ ] Product ID: `monthly.subscribe.com.YOUR_COMPANY.YOUR_APP`

### A3. 코드 중복 & 중복 제거

| 이슈 | 현재 | 개선 |
|------|------|------|
| Auth 상태 이중 관리 | `authStateProvider` + `globalVariableProvider` 둘 다 auth 추적 | `globalVariableProvider` 폐기, `authStateProvider`만 사용 |
| 알림 라이브러리 중복 | awesome_notifications + flutter_local_notifications | 하나로 통합 (awesome_notifications 권장) |
| Feature Flag 3중 레이어 | AppFeatureConfig + RemoteConfigService + FeatureFlagService | FeatureFlagService 하나로 통합, 나머지는 내부 구현 |
| 코드 생성 3중 진입점 | `./build` + `fastlane codegen` + `app/build.sh` | `./build` 하나로 통합 (내부에서 build.sh 호출) |
| 오디오 라이브러리 | audioplayers + flutter_sound | audioplayers만 유지 (더 경량) |
| 이미지 갤러리 | image_gallery_saver + gallery_saver_plus | gallery_saver_plus만 유지 |

---

## Part B: 공통 모듈 추가 구현

### B1. 강제 업데이트 & 버전 체크 (필수)

**현재 상태:** Remote Config에 `minAppVersion` 필드 있지만 **사용 안 함** (dead code)

```dart
// 현재: 값만 가져오고 아무것도 안 함
String get minAppVersion => _remoteConfig.getString('min_app_version');
```

**구현 필요:**
- [ ] `package_info_plus`로 현재 앱 버전 파싱
- [ ] Semantic version 비교 유틸리티 (`1.2.3` vs `1.3.0`)
- [ ] 강제 업데이트 다이얼로그 (스토어 링크 포함, 닫기 불가)
- [ ] 권장 업데이트 다이얼로그 (닫기 가능, 하루 1회 표시)
- [ ] 앱 시작 시 + 포그라운드 복귀 시 체크
- [ ] Feature flag: `isForceUpdateEnabled`

### B2. 네트워크 상태 모니터링 (필수)

**현재 상태:** 완전히 부재. Supabase sync 등 네트워크 의존 기능이 조용히 실패함.

**구현 필요:**
- [ ] `connectivity_plus` 기반 `NetworkStatusService`
- [ ] `StreamProvider<NetworkStatus>` (online/offline/limited)
- [ ] 오프라인 시 상단 배너 자동 표시
- [ ] API 요청 실패 시 자동 큐잉
- [ ] 온라인 복귀 시 자동 재시도
- [ ] Feature flag: `isNetworkMonitoringEnabled`

### B3. Privacy & 동의 플로우 (법적 필수)

**현재 상태:** Firebase consent가 **하드코딩** (항상 true) - GDPR 위반 가능

```dart
// 현재: 동의 없이 항상 허용 (문제!)
FirebaseAnalytics.instance.setConsent(
  analyticsStorageConsentGranted: true,  // 하드코딩!
  adStorageConsentGranted: true,         // 하드코딩!
);
```

**구현 필요:**
- [ ] 첫 실행 시 개인정보 동의 화면
- [ ] ATT (App Tracking Transparency) iOS 처리
- [ ] 동의 상태 로컬 저장 & 서비스 연동
- [ ] 설정에서 동의 철회 가능
- [ ] 약관 버전 관리 & 변경 시 재동의 요청
- [ ] Feature flag: `isPrivacyConsentEnabled`

### B4. 공통 에러 핸들링 레이어

**현재 상태:** 각 서비스에서 개별 try-catch, 통합 에러 처리 없음

**구현 필요:**
- [ ] `ErrorHandlingService` - 글로벌 에러 바운더리
- [ ] 에러 분류: UserError / AppError / NetworkError / ServerError
- [ ] API 에러 → 사용자 친화적 메시지 매핑
- [ ] Crashlytics 자동 리포팅 (분류별 필터링)
- [ ] 에러 발생 빈도 추적 (analytics 연동)

### B5. Deep Link / Universal Link

**현재 상태:** GoRouter 라우트 존재하지만 딥링크 파서 없음

**구현 필요:**
- [ ] URL → GoRouter 경로 매핑 핸들러
- [ ] 인증 체크 후 딥링크 네비게이션
- [ ] 대상 화면 없을 때 폴백 (홈으로)
- [ ] 마케팅/공유 링크 생성 유틸리티
- [ ] Feature flag: `isDeepLinkEnabled`

### B6. App Lifecycle 통합 서비스

**현재 상태:** `main.dart`에 lifecycle 로직이 흩어져 있음

**구현 필요:**
- [ ] `AppLifecycleService` 분리
- [ ] 포그라운드 복귀: 세션 재검증 + 업데이트 체크 + 뱃지 체크
- [ ] 백그라운드 전환: 알림 정리 + 센서 해제
- [ ] 메모리 경고: 캐시 정리
- [ ] main.dart에서 서비스 호출만

### B7. IAP/Subscription 완성

**현재 상태:** 상품 로딩만 있고 구매 트랜잭션 모니터링 없음

**구현 필요:**
- [ ] `InAppPurchaseService` 독립 서비스화 (현재 app_config에 분산)
- [ ] 구매 상태 스트림 리스너
- [ ] 영수증 검증 (서버사이드 또는 로컬)
- [ ] 구독 만료 체크 & 갱신 알림
- [ ] 환불/차지백 처리
- [ ] Feature flag: 이미 `isInAppPurchaseEnabled` 존재

### B8. App Profile 프리셋

**현재 상태:** 30+ Feature Flag를 일일이 설정해야 함

**구현 필요:**
```dart
enum AppProfile { minimal, standard, premium, enterprise }

// minimal: Auth + Local DB만
// standard: + Firebase + Analytics + Ads
// premium: + IAP + Subscription + Push + A/B Testing
// enterprise: 전부 ON
```
- [ ] `./setup profile minimal`로 한 번에 적용
- [ ] Profile별 의존성도 자동 추가/제거

---

## Part C: Setup CLI 완전 자동화 (핵심 목표)

### 현재 vs 목표

**현재 (7+ 수동 단계):**
```
./setup                           # 템플릿만 생성
→ 수동: .env 파일 편집
→ 수동: Firebase 프로젝트 생성 + credentials 복사
→ 수동: App Store Connect에서 앱 생성
→ 수동: Google Play Console에서 앱 생성
→ 수동: router.dart에 라우트 추가
→ 수동: 아이콘/스크린샷 제작
→ fastlane deploy              # 배포 (별도 환경 설정 필요)
```

**목표 (2 명령):**
```
./setup init                      # 모든 것 자동 설정
./deploy                          # 원버튼 배포
```

### C1. 통합 설정 파일 (Central Config)

**핵심 문제:** 설정이 `.env.*`, `pubspec.yaml`, `Fastfile`, `app_feature_config.dart`에 분산

**해결:** 단일 설정 파일 도입
```yaml
# app_config.yaml (Single Source of Truth)
project:
  name: My Awesome App
  package_name: com.example.myapp
  description: "앱 설명"
  category: productivity        # 스토어 카테고리
  version: 1.0.0

platforms:
  ios:
    team_id: ABC123DEF456
    bundle_id: com.example.myapp
  android:
    package: com.example.myapp
    keystore_path: ~/.android/release.keystore

services:
  firebase:
    enabled: true
    project_id: my-project-123
  supabase:
    enabled: false
  admob:
    enabled: true
    app_id_ios: ca-app-pub-xxx
    app_id_android: ca-app-pub-xxx

monetization:
  ads: true
  subscription:
    enabled: true
    products:
      - id: monthly
        type: subscription
        price_tier: 1
      - id: yearly
        type: subscription
        price_tier: 5
      - id: lifetime
        type: non_consumable
        price_tier: 10

profile: standard  # minimal | standard | premium | enterprise

features:          # profile 기반 자동 설정 + 개별 오버라이드
  force_update: true
  privacy_consent: true
  deep_link: false
```

- [ ] `app_config.yaml` → `.env.*`, `pubspec.yaml`, `app_feature_config.dart` 자동 생성
- [ ] 설정 변경 시 관련 파일 모두 동기화
- [ ] 유효성 검증 (필수 필드, 형식 체크)

### C2. 프로젝트 생성 자동화

```
./setup init
  ├─ Step 1: 인터랙티브 정보 입력 (또는 --config app_config.yaml)
  │   ├─ 앱 이름, 패키지명, 카테고리
  │   ├─ Profile 선택 (minimal/standard/premium/enterprise)
  │   └─ 추가 기능 선택
  │
  ├─ Step 2: 프로젝트 설정
  │   ├─ 패키지명/번들ID 업데이트 (rename 로직 통합)
  │   ├─ Profile 기반 의존성 설정 (pubspec.yaml)
  │   ├─ Feature flag 설정 (app_feature_config.dart)
  │   ├─ .env 파일 생성 & 채우기
  │   └─ 코드 생성 (build.sh)
  │
  ├─ Step 3: 외부 서비스 연결
  │   ├─ Firebase: `firebase projects:create` + `flutterfire configure`
  │   ├─ App Store Connect: `fastlane produce` (앱 등록)
  │   ├─ Google Play: `fastlane supply init` (앱 등록)
  │   └─ AdMob: 광고 단위 생성 (fastlane admob 레인 활용)
  │
  ├─ Step 4: 에셋 생성
  │   ├─ GPT API → 앱 아이콘 생성 (앱 설명 기반 프롬프트)
  │   ├─ flutter_launcher_icons → 모든 플랫폼 아이콘 생성
  │   ├─ flutter_native_splash → 스플래시 스크린 생성
  │   └─ GPT API → 앱 설명 다국어 생성 → fastlane metadata 구성
  │
  ├─ Step 5: 수익화 설정 (선택)
  │   ├─ App Store Connect IAP 상품 등록
  │   ├─ Google Play 구독 상품 등록
  │   └─ 상품 ID → .env 자동 설정
  │
  └─ Step 6: 검증 & 완료
      ├─ 환경 변수 전체 검증
      ├─ 빌드 테스트 (flutter build --debug)
      ├─ 설정 요약 출력
      └─ "Ready to deploy!" 메시지
```

### C3. 원버튼 배포

```
./deploy [--target beta|production] [--platform ios|android|all]
  ├─ Pre-flight 검증
  │   ├─ 환경 변수 전체 체크
  │   ├─ Firebase/Supabase/AdMob 연결 확인
  │   ├─ 인증서/서명 키 유효성 확인
  │   ├─ 필수 에셋 존재 확인 (아이콘, 스크린샷)
  │   └─ 이전 배포 이후 변경사항 확인
  │
  ├─ 빌드 준비
  │   ├─ 코드 생성 (build.sh)
  │   ├─ flutter analyze (린트)
  │   ├─ 테스트 실행
  │   └─ 버전 범프 (patch/minor/major)
  │
  ├─ 스크린샷 (첫 배포 또는 UI 변경 시)
  │   ├─ Integration test 기반 자동 캡처
  │   ├─ 다국어 × 디바이스별 생성
  │   └─ fastlane frameit 프레임 추가
  │
  ├─ 빌드 & 업로드 (iOS/Android 병렬)
  │   ├─ iOS: fastlane build + upload to App Store Connect
  │   ├─ Android: fastlane build + upload to Play Store
  │   └─ 릴리즈 노트 자동 생성 (git log 기반)
  │
  └─ Post-deploy
      ├─ 스토어 제출 상태 확인
      ├─ git tag 생성
      └─ 배포 완료 알림 (선택: Slack/Discord)
```

### C4. CLI-Fastlane 통합

**현재 문제:** CLI(Dart)와 Fastlane(Ruby)이 독립적으로 동작

**해결 방안:**
- [ ] `./setup init` → Dart CLI가 오케스트레이션, 필요시 `fastlane` 호출
- [ ] `./deploy` → Dart CLI가 pre-flight 검증 후 `fastlane deploy` 위임
- [ ] 환경 변수: `app_config.yaml` → `.env` 자동 생성 → Fastlane에서 로드
- [ ] 코드 생성: `./build` 하나가 `build.sh` + build_runner 통합 호출

### C5. Feature Generation 완성

**현재 누락:**
- [ ] `./feature generate -n auth --full` 시 `router.dart`에 라우트 자동 등록
- [ ] Feature 의존성 자동 해결 (subscription → firebase 자동 활성화)
- [ ] Feature disable 시 의존성 경고 (analytics가 firebase에 의존)
- [ ] 테스트 파일 자동 생성 (widget_test, viewmodel_test 템플릿)

---

## Part D: 구조적 개선

### D1. Feature Module Auto-Registration

**현재:** router.dart에 모든 라우트 하드코딩
**개선:** Feature flag에 따라 라우트 자동 등록/해제

```dart
// 각 feature가 자신의 라우트를 선언
class AuthFeature implements AppFeature {
  @override
  bool get isEnabled => AppFeatureConfig.isAuthenticationEnabled;

  @override
  List<RouteBase> get routes => [
    GoRoute(path: '/auth', builder: (_, __) => const AuthView()),
  ];
}

// router.dart에서 자동 수집
final enabledRoutes = AppFeature.all
  .where((f) => f.isEnabled)
  .expand((f) => f.routes)
  .toList();
```

### D2. 코드 생성 통합 & 최적화

- [ ] 3개 진입점 → `./build` 하나로 통합
- [ ] Incremental build: 변경된 파일만 재생성 (해시 비교)
- [ ] sync_database.dart의 regex → Dart AST 파싱으로 교체 (안정성)
- [ ] 빌드 캐시로 30% 성능 개선

### D3. 테스트 자동화 강화

- [ ] Feature 생성 시 테스트 파일도 자동 생성
- [ ] Widget test, ViewModel test, Repository test 템플릿
- [ ] Coverage 임계치 설정 (80% 미만 시 경고)
- [ ] CI에서 테스트 실패 시 배포 차단

---

## 원페이지 앱 완전 자동화 최종 플로우

```
# 1. 프로젝트 생성 (5분)
./setup init
  → "앱 이름?" → My Simple App
  → "패키지명?" → com.raynear.mysimpleapp
  → "카테고리?" → productivity
  → "Profile?" → standard (Firebase + Analytics + Ads)
  → "수익화?" → Subscription (monthly $2.99, yearly $19.99)
  → "아이콘 자동 생성?" → Yes (GPT API 사용)
  → "앱 설명 자동 생성?" → Yes (다국어)

  [자동 실행]
  ✅ 패키지명/번들ID 설정 완료
  ✅ Firebase 프로젝트 생성 + 연동 완료
  ✅ App Store Connect 앱 등록 완료
  ✅ Google Play Console 앱 등록 완료
  ✅ 아이콘 생성 + 모든 플랫폼 적용 완료
  ✅ 앱 설명 30개 언어 생성 + metadata 배치 완료
  ✅ IAP 상품 등록 완료 (App Store + Play Store)
  ✅ AdMob 광고 단위 설정 완료
  ✅ 코드 생성 완료
  ✅ 테스트 빌드 성공

  🎉 Ready to deploy!

# 2. 앱 개발 (원페이지면 이미 기본 화면 있음)
# home_view.dart만 수정하면 됨

# 3. 배포 (10분)
./deploy --target production
  [Pre-flight]
  ✅ 환경 변수 검증 통과
  ✅ 인증서 유효
  ✅ 에셋 존재 확인

  [Build & Upload]
  ✅ 코드 생성 완료
  ✅ 테스트 12/12 통과
  ✅ 버전 1.0.0+1
  ✅ iOS 빌드 + App Store 업로드 완료
  ✅ Android 빌드 + Play Store 업로드 완료
  ✅ 스크린샷 6개 디바이스 × 30개 언어 생성 + 업로드
  ✅ 릴리즈 노트 생성
  ✅ 심사 제출 완료

  🚀 Deployed! Review estimated: 24-48h
```

---

## 실행 순서 (우선순위)

### Sprint 1: 정리 & 기반 (1-2주)
| # | 작업 | 효과 | 난이도 |
|---|------|------|--------|
| 1 | 의존성 Core/Optional 분리 | 빌드 시간 50%↓, 앱 사이즈↓ | 중 |
| 2 | 샘플 테이블/패키지 정리 | 클린 시작점 | 하 |
| 3 | 코드 중복 제거 (auth 이중관리, 알림 라이브러리) | 복잡도↓ | 중 |
| 4 | .env 플레이스홀더화 | 즉시 사용 가능 | 하 |

### Sprint 2: 공통 모듈 (2-3주)
| # | 작업 | 효과 | 난이도 |
|---|------|------|--------|
| 5 | 강제 업데이트 모듈 | 모든 앱 필수 | 하 |
| 6 | 네트워크 모니터링 | UX 안정성 | 하 |
| 7 | Privacy/동의 플로우 | 법적 필수 (GDPR) | 중 |
| 8 | App Profile 프리셋 | 설정 시간 90%↓ | 하 |
| 9 | App Lifecycle 서비스 분리 | main.dart 정리 | 하 |
| 10 | 공통 에러 핸들링 | 디버깅 효율↑ | 중 |

### Sprint 3: CLI 자동화 (3-4주)
| # | 작업 | 효과 | 난이도 |
|---|------|------|--------|
| 11 | 통합 설정 파일 (app_config.yaml) | 설정 일원화 | 중 |
| 12 | CLI-Fastlane 통합 오케스트레이션 | 단일 진입점 | 상 |
| 13 | `./setup init` 프로젝트 생성 자동화 | 핵심 목표 | 상 |
| 14 | Feature generation 완성 (라우트, 의존성) | 개발 속도↑ | 중 |
| 15 | 코드 생성 통합 (`./build` 하나) | 혼란 제거 | 중 |

### Sprint 4: 에셋 & 배포 자동화 (2-3주)
| # | 작업 | 효과 | 난이도 |
|---|------|------|--------|
| 16 | GPT API 아이콘 생성 | 디자이너 불필요 | 중 |
| 17 | GPT API 앱 설명 다국어 생성 | 번역 불필요 | 중 |
| 18 | 스크린샷 자동 캡처 + 업로드 | 배포 시간↓ | 상 |
| 19 | `./deploy` 원버튼 배포 | 핵심 목표 | 상 |
| 20 | IAP/Subscription 자동 등록 | 수익화 자동화 | 상 |

### Sprint 5: 고급 기능 (선택)
| # | 작업 | 효과 | 난이도 |
|---|------|------|--------|
| 21 | Deep Link 기본 구조 | 마케팅 지원 | 중 |
| 22 | Feature Auto-Registration | 코드 최적화 | 중 |
| 23 | IAP 완성 (구매 모니터링, 영수증 검증) | 수익 보호 | 상 |
| 24 | GitHub Actions CI/CD | 자동 빌드/배포 | 중 |
