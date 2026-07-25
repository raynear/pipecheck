# Changelog

이 템플릿 repo의 주요 변경 사항을 기록합니다.

형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/)를 따르고,
버전은 [Semantic Versioning](https://semver.org/lang/ko/)을 준수합니다.

## 릴리즈 규칙 (release discipline lite)

- **태그 네임스페이스**: 이 repo의 `v*` 태그는 배포 게이트(`.github/workflows/ci.yml`)
  트리거 전용이므로 릴리즈 태그로 쓰지 않는다.
  - 템플릿 릴리즈: `template-v*` (예: `template-v1.0.0`) — `scripts/sync-to-apps`가
    파생 앱의 `template.lock`에 기록 (`project.yaml tooling.template_version`)
  - tools/cli 릴리즈: `cli-v*` (예: `cli-v1.0.0`) — 파생 앱의
    `dart pub global activate --git-ref` 핀 (`project.yaml tooling.cli_ref`)
  - 로컬 패키지 릴리즈: `pkgs-v*` (예: `pkgs-v1.0.0`) — 파생 앱이
    `app/packages/<name>`를 git 의존으로 핀 소비할 때의 ref
    (`project.yaml tooling.pkgs_ref`). pub workspace 멤버라도 외부
    git 의존으로 정상 해석됨(P2-19d 검증)
  - fastlane (별도 repo [raynear/flutter-fastlane]): `v*` (현재 핀:
    `project.yaml tooling.fastlane_ref`)
- **semver 준수**:
  - MAJOR: breaking — 파생 앱이 추가 작업 없이는 sync를 받을 수 없는 변경
    (설정 스키마 변경, 경로 계약 변경, CLI 인터페이스 변경 등)
  - MINOR: 하위 호환 기능 추가
  - PATCH: 하위 호환 버그 수정
- **마이그레이션 노트는 breaking 변경에만 필수**: breaking이 포함된 릴리즈 항목에는
  `### Migration` 섹션으로 파생 앱이 해야 할 작업을 명시한다.
  non-breaking 릴리즈에는 Migration 섹션을 두지 않는다.
- **[Unreleased] 운용**: 머지되는 변경은 [Unreleased]에 누적하고, 릴리즈 시
  버전 섹션으로 옮긴 뒤 `template-vX.Y.Z` 태그를 붙인다.

## [Unreleased]

### Added
- **개인정보처리방침 GitHub Pages 호스팅 (A1)**: `listing.legal_hosting: github`
  + `.github/workflows/legal-pages.yml`(docs/legal → Pages, 최초 1회 자동 활성화)
  + `./run deploy-legal --target github`(URL 도출·워크플로 트리거). gen_env가
    `https://<owner>.github.io/<repo>/privacy_policy.html`를 자동 주입. (firebase
    호스팅은 그대로 유지 — `legal_hosting`로 선택. private repo Pages는 유료 플랜.)
- **스크린샷 크기 검증 (B5)**: 캡처 후 각 PNG의 IHDR 크기를 읽어 손상(0크기)은
  hard-fail, 너무 작은 사이즈(잘못된 시뮬레이터)는 경고. 요청한 시뮬레이터가 없으면
  hard-fail(opt-out `--allow-missing-devices`) — 과거엔 iPad 슬롯이 무음 누락.
- 로컬 패키지 git-dep 핀 + `pkgs-v*` 네임스페이스 (P2-19d, P2-19 4/4):
  `pkgs-v1.0.0` 태그 발행 — 파생 앱이 `app/packages/<name>`를 git 의존으로
  핀 소비하는 경로 확립. `project.yaml tooling.pkgs_ref` 추가, CHANGELOG
  태그 규약에 4번째 네임스페이스 등록. **검증: 파생 앱(snapdic) worktree에서
  utils를 `git: {url, ref: pkgs-v1.0.0, path: app/packages/utils}}`로 핀 소비 —
  pub get 해석 성공(pubspec.lock에 resolved-ref 기록), 46개 import 파일
  utils 에러 0, 핀된 utils에 19a 산출물(validators.dart) 포함 확인.
  `resolution: workspace` 멤버라도 외부 git 의존으로 정상 해석됨(블로커 아님).**
- 신규 가이드 3종 (P1-18e): `docs/guides/PACKAGE_AUTHORING.md`(패키지
  작성/추출 — 경계 규칙, pubspec 구조, two-phase 플래그, P2-20 추출
  순서, ab_testing의 supabase 잔재 격리), `docs/guides/DERIVED_APP_UPDATES.md`
  (파생 앱 전파 — sync-manifest/apps.yaml/sync-to-apps 가드, template.lock,
  태그 네임스페이스, 자동 sync 금지), `docs/guides/FASTLANE_REPO.md`
  (별도 repo 관계 — 핀/자동 클론/preflight 게이트/레인 계약 13/핀 범프
  절차). docs/README + CLAUDE.md 인덱스에 등록. 작성 후 문서별 적대적
  팩트체크(실파일 대조)로 검증
- Firebase Auth 전환 (P1-16.5b, 백엔드 전환 2/2): email 로그인/가입/
  비밀번호 재설정을 `firebase_auth`(^6.1.0)로 배선 — 세 경로가 단일
  게이트(isEmailAuthEnabled + isFirebaseEnabled + Firebase 초기화)를
  공유(과거 게이트 비대칭 풋건 해소), 가입 시 인증 메일 best-effort
  발송. 계정 삭제는 클라이언트 직접(`currentUser.delete()` + 본인
  로컬 데이터 삭제, requires-recent-login 시 재로그인 안내) — 서버
  함수 0줄. authStateChanges 구독으로 원격 로그아웃/만료 시 로컬 정리
  (P1-14c 계약 보존). FCM 토큰 서버 저장은 제거 확정(토픽 브로드캐스트
  + 콘솔 캠페인). Data Safety 생성기에 Firebase Auth 기준 Email/User ID
  선언 재도입. 게이트 테스트 5종 신규(13b deno 테스트 동등 대체).
  **수동 1회(email auth 켜는 포크만): Firebase 콘솔 → Authentication →
  Email/Password 활성화**
- Data Safety 생성기: `./run generate-data-safety` — 활성 기능 셋에서
  Google Play Data Safety 폼 답안지(md) + Apple Privacy Nutrition 라벨
  대응표 + 기계가독 json을 `metadata/data_safety/`에 생성
  (correct-by-construction; Play CSV 임포트는 콘솔 export 샘플 확보 후
  후속). 계정 삭제(P1-13b) 배선 시 삭제 요청 경로 자동 반영 (P1-13f)
- 법적 HTML Firebase Hosting 배포: generate-legal 산출물
  (privacy/terms/index, `docs/legal/`)을 신규 `./run deploy-legal`로
  배포 — `https://<firebase프로젝트ID>.web.app/privacy_policy.html`.
  프로젝트 ID는 google-services.json SSOT (파생 앱 자동 정합), 호스팅
  설정은 루트 firebase.json. **수동 1회: npm i -g firebase-tools +
  firebase login** (P1-13e → 15.5 Pages branch → 15.5b Firebase로 전환
  — private repo는 Free 플랜에서 Pages 미지원)
- Apple Privacy Manifest (PrivacyInfo.xcprivacy): `./run generate-privacy`
  신규 + init 단계 통합 — 활성 기능 셋(광고/Firebase)과 project.yaml
  `privacy.tracking_domains`에서 생성 (correct-by-construction). 트리 내
  0개였던 매니페스트를 템플릿에 포함하고 Xcode 등록(pbxproj)도 커밋 —
  생성기는 내용만 갱신. 광고 앱은 NSPrivacyTracking=true + DeviceID/
  AdvertisingData, Firebase는 ProductInteraction/CrashData/PerformanceData,
  UserDefaults(CA92.1) 사유 상시 선언 (P1-13d)
- AdMob UMP/EEA 동의 + NPA 폴백 + COPPA 노브 (스토어 컴플라이언스):
  `AdConsentManager` 신규 — 부팅 시 UMP 동의 수집(EEA는 네이티브 폼),
  `canRequestAds` 게이트가 SDK 초기화·광고 로드 전부를 차단, 인하우스
  adConsent 미수집/거부 시 npa=1 폴백, 설정 화면에 프라이버시 옵션
  재진입점. 신규 플래그 `isUmpConsentEnabled`(기본 ON) /
  `isChildDirectedAdsEnabled`(COPPA) / `isUnderAgeOfConsentEnabled`(TFUA) —
  노브 동시 설정 시 COPPA 우선, 켜면 maxAdContentRating=G (P1-13c)
- 계정 삭제 (스토어 컴플라이언스): 설정 화면 진입점(파괴적 확인 다이얼로그) +
  `SupabaseService.deleteAccount()` + `supabase/functions/delete-account` 에지
  함수 신규 — JWT로만 본인 식별(body userId 불신), 사용자 테이블 best-effort
  삭제 후 auth 계정 삭제, deno 핸들러 테스트 5종. 신규 플래그
  `isAccountDeletionEnabled`(기본 ON, `isAuthenticationEnabled` 종속).
  **에지 함수 배포는 수동**: `supabase functions deploy delete-account` (P1-13b)

- `docs/MODULES.md` 신설 (P1-16b): 모듈 경계 규칙 + 기능 플래그 체계의
  운영 기준 — 최종 플래그 12개(현행 8 + 예약 4, 예약은 소비자와 같은
  PR에서만 추가), core 마이크로 의존성 allowlist 5개
  (force_update/network/consent/review/share), 패키지행 19개 two-phase
  표기, local-only Drift 공식 기본(P2-23.5a), supabase 폐기 예정(§5),
  non-goal 기록(referral 등)

### Added
- iOS 심사 제출 자동화 (P1-17c): `./deploy --target production
  --submit-review` — 메타데이터 업로드 **이후** fastlane
  `submit_ios_review` 레인 호출 (역순이면 제출된 버전에 메타데이터
  덮어쓰기). opt-in 기본 false (첫 제출은 ASC 필수 항목 미비 실패
  가능). `IOS_AUTOMATIC_RELEASE`(기본 true)/`REVIEW_*`/
  `EXPORT_COMPLIANCE_USES_ENCRYPTION` env — FASTLANE_SETUP.md 문서화.
  Android는 production 업로드 = 제출이라 별도 단계 없음

### Changed
- **저자 자격증명 스크럽 (B4)**: 커밋된 `app_config.yaml`의 저자 실제 Apple
  Team ID/Apple ID/ASC 키 id·issuer/match repo/도메인과 `project.pbxproj`의
  `DEVELOPMENT_TEAM`을 placeholder로 교체. `./init` 서명 단계가 pbxproj
  `DEVELOPMENT_TEAM`을 `platforms.ios.team_id`로 재기록. `./deploy` production이
  미편집 placeholder/저자 기본값을 hard-fail로 차단. (주의: 과거 git 히스토리에는
  값이 남아 있으나 `.p8` 비밀키 자체는 커밋된 적 없음.)
- fastlane 핀 v0.2.4 → v0.2.5 (raynear/flutter-fastlane PR #2): age-rating
  `app_rating_config_path` 연결 + App Privacy 업로드 경로를 메타데이터 SSOT로.
  submodule gitlink + `project.yaml tooling.fastlane_ref` 동시 갱신.
- pub workspace 전환 (P2-19c, P2-19 3/4): 루트 `pubspec.yaml`(`app_workspace`)
  신규 — 멤버 = app + app/packages/{utils,authentication,ab_testing}.
  각 멤버 + app에 `resolution: workspace` → 단일 루트 `pubspec.lock`으로
  공유 해석(app/ab_testing 멤버 lock 통합 제거). 파일 이동 없이 제자리
  선언(저위험). utils/authentication SDK floor 3.4.3→3.8.0 인상(app 정렬,
  ab_testing 3.7.0은 P2-20 재구축 몫). workspace 단일 해석 충돌 해소 —
  멤버 flutter_lints ^3.0.0→^6.0.0(유일 충돌), flutter_lints ^6 신규
  린트로 드러난 배럴의 불필요한 library 이름 제거. tools/cli·feature_cli는
  독립 프로젝트라 멤버 아님. 검증: 루트 pub get 단일 lock, app+패키지 3
  analyze 0, app test 36+1skip, utils 패키지 44 pass, cli dart test 522,
  fresh worktree ./build 7단계 codegen + flutter test green
- table_generator 위생 정리 + 전제 정정 (P2-19b): 죽은 `code_builder`
  의존(repo 전체 import 0건) 제거. **로드맵 v1.1의 "table_generator가
  lib/ 안이라 모든 출시 바이너리에 컴파일됨" 전제는 거짓으로 확인** —
  analyzer/build/source_gen/code_builder는 전부 dev_dependencies고
  builder/generators는 런타임(main) 미도달(build 엔트리포인트만 import →
  tree-shake 제외)이라 이미 출시 바이너리에서 제외됨. 따라서 위험한
  dev 패키지 추출(rename_command fork 경로 결합)은 폐기 — 출시 크기
  이득 0 + workspace 전환에도 불필요. 검증: flutter analyze 0 error,
  `./build` codegen 정상 완주(산출물 재생성), flutter test 36+1skip.
- utils SSOT 통합 (P2-19a, P2-19 1/4): 로컬/패키지 이중 utils 정리.
  `app/lib/core/utils.dart`(최상위 포맷 함수 9개 — importer 0건 죽은
  배럴) 삭제, `app/lib/core/utils/validators.dart`(Validators 클래스,
  importer 2건) → `packages/utils/lib/src/validators.dart`로 이동하고
  배럴(`utils.dart`)에 export 추가. 소비처 2곳(`login_view.dart`,
  validators 테스트)을 `package:utils/utils.dart`로 전환, 테스트는
  `packages/utils/test/`로 이동(패키지에 실 테스트 확보). `package:utils`를
  import하는 나머지 43개 파일은 무변경. **검증: flutter analyze 0 error/
  warning, app flutter test 36+1skip + utils 패키지 44 pass(이동 43 + 더미
  1) = 베이스라인 79 보존.** SDK floor 인상·workspace 전환은 P2-19c 몫.
  유령 밀도 최고(39건) 문서. `./build.sh`(19곳)→`./build` 통일(루트 래퍼 —
  `cd app` 선행 블록은 깨지므로 제거), 죽은 fastlane 레인 일괄 교정
  (deploy_testflight/deploy_playstore/deploy_appstore/hotfix/snapshot/
  screengrab/switch_env → `./deploy --target beta|production`·`./run
  screenshot`·`./build` 자동 env), 서비스 표 7개 죽은 항목 제거 + 실경로
  부여(FeatureFlagService/ICloudService/HomeWidgetService/ABTestingProvider/
  GeofenceService/FileService/CameraService 삭제), 공통 위젯 실명 교정
  (LoadingWidget→LoadingIndicator, ErrorWidget→AppErrorWidget,
  EmptyStateWidget→EmptyState, AdBannerWidget→AdContainer), 디자인 트리
  실파일화(design_system.dart), feature 목록 21→15(SSOT), GitHub
  Actions/Secrets 기반 배포 안내 제거, Firebase Auth 전환 완료 시제,
  bump_version `version:` 미지원 교정(type:만)
- 살아있는 문서 유령 참조 퍼지 (P1-18c, 21파일 −588/+211): 정찰에서
  confirmed된 유령 130건 수리 — 죽은 fastlane 레인 교정(deploy→./deploy,
  validate_all_certificates→check_certificates, switch_env→./build 산출물,
  renew_all_certificates→setup_certs 등), GitHub Actions 기반 CI/CD·
  GitHub Secrets 절차 섹션 제거(Actions 영구 미사용 — 로컬 배포 단일
  경로로 교체), feature 표를 featureDefinitions SSOT 15개로 정합화
  (feature_cli README 유령 7행·FEATURE_MANAGEMENT 유령 6행 삭제),
  VERSION_POLICY의 픽션 운영 체계 4개 섹션(지원기간/보안패치 SLA/
  릴리스 일정/compatibility CI 매트릭스+가짜 테스트 결과) 삭제 및
  버전 표를 pubspec 실값으로 교정, 구경로·깨진 링크·삭제된 서비스
  참조 일괄 교정. CLI_TOOLS에 누락 명령 4개(gen-env/deploy-legal/
  generate-privacy/generate-data-safety) 보강. project.yaml IAP 주석
  구경로(app/store_data) 교정
- 진입 문서 일원화 (P1-18b): docs/quick-start.md를 골든 패스 SSOT로 승격
  (분리 전 단일 yaml 스키마 → 루트 3파일 체계 반영 — project.yaml 정체성 +
  app_config.yaml 인프라 + .env 시크릿; Play Console 패키지명 안내의
  잘못된 파일 참조는 따라하면 업로드 거부되는 파손 경로였음).
  README/docs/README/01-GETTING_STARTED가 quick-start를 기준 문서로
  링크하도록 정렬(기존엔 quick-start가 어디서도 링크 안 됨 + 4벌의
  서로 모순되는 시작 절차). CLAUDE.md 유령 18건 수리(./build.sh→./build,
  삭제된 FirebaseABTestingService 행, 구경로 링크 4개, 플래그 예시
  실명·실선언 정렬, Firebase Auth 전환 완료 시제 등). Dart SDK 최소
  버전 표기 3.0→3.8 교정(pubspec 기준 — 3.0대로 따라하면 pub get 실패)
- 스냅샷 문서 아카이브 (P1-18a): 2026-01-03 코드베이스 스캔 산출물 5종
  (`docs/{index,project-overview,technology-stack,component-inventory,data-models}.md`
  — Supabase 철거 전·플래그 정리 전 시점 서술 잔존)을
  `docs/reference/archive/`로 이동, archive README를 동결 기록 인덱스로
  재작성. CAPABILITY_MATRIX.md에 감사 스냅샷 동결 표기 추가(P2-20이
  §3을 참조하므로 이동하지 않음). 미실현 청사진 `tools/scripts/README.md`
  삭제 (디렉토리에 README 외 파일 0개 — 셸 래퍼는 루트 `scripts/`,
  복잡 로직은 `tools/cli`로 정착)
- fastlane 핀 v0.2.3 → v0.2.4 (P1-17 fastlane측 일괄):
  ①submit_ios_review 레인 신설 + create_new_version_ios에
  run_precheck_before_submit 명시(암묵 precheck 방지), ②죽은 스크린샷
  체인 제거(lane :screenshots/take_screenshots/upload_screenshots —
  빈 test/integration 타깃으로 전체 즉사 상태였음;
  capture_screenshots는 내장 snapshot 섀도잉이라 호출부와 동시 제거),
  generate_screenshots(계약 레인)는 템플릿 `./run screenshot` 위임
  shim으로, upload_metadata_android에 skip_upload_screenshots 명시
  (Play 기존 스크린샷 의도치 않은 대체 방지), ③IAP 가드(android Hash
  계약 가드/ios consumable 경고/README 계약 명세)
- 스크린샷 파이프라인 단일화 — 템플릿측 (P1-17b): 경로 SSOT =
  `<root>/screenshots/{platform}/{language}/` (iOS는 deliver
  `screenshots_path`가 그대로 읽는 레이아웃, gitignore 산출물).
  하니스 ScreenshotConfig가 dart-define(SCREENSHOT_OUTPUT/LANGUAGE/MODE)
  실소비 — 구 기본값 'app/store_data/screenshots'는 cwd=app 이중 경로
  잠복 버그였음. tools/cli 기본값 교정(출력 'fastlane/screenshots/'→
  SSOT, 테스트 파일 드라이버→실진입점, 디바이스 목록 현행화), flutter
  test 폴백에 --run-skipped(P0-9 태그 스킵 해제), 산출물 생성 시 테스트
  teardown 실패를 경고로 강등. `./run screenshot` E2E 실검증(PNG 4장).
  app/store_data/{screenshots,preview} 잔존물 삭제(소비처 0).
  **iOS 빌드 차단 잔재 수리**: AppDelegate.swift의 workmanager/GoogleMaps
  import(주석 처리된 의존) 제거, Info.plist의 죽은 GMSApiKey 실값 제거.
  fastlane측 죽은 레인 제거는 v0.2.4에서 일괄
- **[breaking]** IAP JSON 포맷 3중 불일치 해소 (P1-17a, P0-8 잔여):
  단일 계약 = 소비자(fastlane upload_iap_*) 포맷 — flat
  `metadata/in_app_purchases/{ios,android}/<productId>.json` 객체.
  공유 라이터 `iap_contract_writer.dart` 신설(직렬화 SSOT), 생산자
  2곳(./init setupStoreInfoStep, ./run iap-register) 정렬. 상품 ID
  `<id>.<package_name>` 통일, priceMicros = round(usd×1e6) (구
  tier×990000 근사 제거, 미정의 tier 명시 에러). 구포맷(iOS
  서브디렉토리/배열형 JSON 3종 — iOS 레인 무음 no-op·Android 레인
  크래시 원인)은 생성 시 자동 정리. stale 산출물 재생성. 계약 명세는
  docs/reference/technical/deployment.md
- fastlane 핀 v0.2.2 → v0.2.3: supabase 설정 가이드 제거
  (print_supabase_setup_guide + setup_project supabase confirm 분기 —
  템플릿 P1-16.5 철거 동행)
- legal 호스팅 전환 (P1-15.5 → 15.5b): Actions 영구 미사용 확정으로
  `legal-pages.yml` 삭제, `generate-legal` 기본 출력 `app/assets/legal/`
  → `docs/legal/` + index.html 동시 생성 (15.5). repo가 private이라
  Free 플랜 Pages 불가 → **Firebase Hosting으로 재전환** (15.5b):
  `derivePagesUrl`(github.io) → `deriveLegalHostingUrl`(web.app, 프로젝트
  ID는 google-services.json에서 도출), `docs/.nojekyll` 제거
- fastlane 핀 v0.2.1 → v0.2.2: IAP/구독 가격 기준 territory 설정화 —
  `store.apple.iap_base_currency`/`iap_base_territory` (생략 시 기존
  JPY/JPN 동작 보존) (P1-15 fastlane측)
- 하드코딩 → 설정 3파일 (P1-15 템플릿측): 프라이버시/약관 URL 4곳을
  `listing.privacy_policy_url`/`terms_of_service_url`(비면 Pages URL
  자동 도출)로, `idYOUR_APP_ID`를 신규 `listing.apple_app_id`로
  (미설정 시 스토어 열기 스킵), 구독 카피를 `iap.headline_copy`/
  `benefits_copy`로 (비면 기본 번역 키). env 신규 키 5종. RC zero-reader
  키 `show_discount_first`/`new_home_ui_enabled` 퍼지
  (`subscription_variant`→P2-21, `maintenance_mode`→P2-23 유지)
- crash 분류 메타데이터 + 세션 만료 처리 (P1-14c): Crashlytics
  setCustomKey — flavor/app_profile/template_version(신규 env 키
  `TEMPLATE_VERSION`)/enabled_flags + AB variant(`ab_<experiment>`,
  ABTestService 초기화 시). app_config의 `FlutterError.onError` 재할당
  제거 — main()의 전역 핸들러를 덮어쓰던 버그. supabase auth 스트림에
  onError 추가 — 토큰 갱신 실패/세션 만료 시 로컬 상태 정리
  (기존엔 만료 세션으로 API를 계속 호출)
- 양품 서비스 배선 + 풋건 제거 (P1-14b): 전역 에러핸들러
  (`ErrorHandler.setupGlobalErrorHandling` — main 최우선, Crashlytics는
  내부 가드), ForceUpdate 검사(첫 프레임 후 RC min_app_version 대조,
  fail-open), AppReview를 `AppReviewService`(세션 추적 + 90일 간격 제한)
  로 통합 + 신규 플래그 `isAppReviewPromptEnabled`. **데모 인증 우회
  제거** — supabase/email auth 꺼진 구성에서 아무 자격증명이나 통과시키던
  더미 로그인/회원가입을 실패 반환으로 교체
- A/B 테스트 단일화: 부팅 배선을 `ABTestService`(로컬 할당 + RC 킬스위치,
  Firebase 미필수)로 교체하고 중복/죽은 구현 4파일 삭제 —
  `FirebaseABTestingService`(un-wire 후), `feature_flag_service`(271줄,
  콜사이트 0), `ab_test_experiment`, `ab_testing_provider`(읽히면
  sharedPreferencesProvider 미오버라이드 크래시) (P1-14a)

### Removed
- **[breaking]** Supabase 전면 철거 (P1-16.5a, 백엔드 전환 1/2 — 전환은
  16.5b에서 Firebase Auth로): `supabase_service.dart`(+provider 3종),
  `supabase/` 디렉토리 전체(에지 함수 7개 — 13b delete-account 포함,
  배포된 적 없음), `isSupabaseDatabaseEnabled` 플래그,
  `app_config.yaml services.supabase` 스키마, gen_env `SUPABASE_*` 키,
  data 레이어 supabase datasource/database + USE_SUPABASE 분기,
  table_generator SQL/RLS 생성 경로, `supabase_flutter` 의존,
  feature_cli supabase 정의, 13b deno 테스트. email 로그인/가입/계정삭제는
  시그니처 보존 스텁(항상 실패 반환, 기본 플래그 OFF라 비노출) —
  16.5b 전환 작업 목록은 docs/MODULES.md §5
- 잔재 패키지 퇴거 (P1-16c): vendored `flutter_heatmap_calendar`(123파일)·
  `geofence_foreground_service`(134파일)를 소유 앱 flowmodoro repo로 이전
  (브랜치 `chore/vendor-geofence-from-template`; heatmap은 이미 보유) 후
  템플릿에서 삭제, `examples/optional_services/geofence_service.dart` 동반
  퇴거. 미추적 빈 stub `app_blocker/`·`flutter_openmoji/` 디스크 정리.
  rename이 `examples/`의 `package:<앱이름>/` import도 동행 치환하도록 확장
  ('boilerplate' 패키지명 비의존화 26곳 — 포크 후 복사-사용 가능)
- **[breaking]** 죽은 기능 플래그 13개 삭제 (P1-16a, CAPABILITY_MATRIX 분류
  채택): `isLocalDatabaseEnabled`(Drift 무조건 생성) ·
  `isDatabaseSyncEnabled`(reader 0) · `isSocialAuthEnabled`(gate 0,
  P2-21.5에서 재도입) · `isICloudEnabled`(icloud_storage 의존 주석 —
  설정 iCloud UI도 삭제) · `isAnalyticsEnabled`/`isCrashReportingEnabled`
  (isFirebase* 중복) · `isCameraEnabled`/`isFileStorageEnabled`(의존성
  주석, gate는 examples뿐) · `isBadgeSystemEnabled`(main.dart 무조건
  배선 — 게이트 2곳을 무조건 실행으로 정렬) · `isHomeWidgetEnabled`
  (P0-3에서 네이티브 잔재 삭제됨) · `isTestMode`/`isDebugMode`/
  `isVerboseLoggingEnabled`(reader 0, kDebugMode 직접 사용). feature_cli
  정의 6개(camera/analytics/badge/icloud/fileStorage/homeWidget) 동반
  삭제.

### Migration
- Supabase 철거 (16.5a): supabase를 실사용하던 파생 앱은 sync 전에
  자체 백엔드 경로를 분리하거나 16.5b(Firebase Auth 전환) 머지까지 sync
  보류 권장. `app_config.yaml services.supabase` 블록과
  `isSupabaseDatabaseEnabled` 게이트는 sync 시 제거 필요. env 산출물은
  `./run gen-env`로 재생성 (source-hash 변동으로 preflight가 stale 차단).
- 플래그 13개 삭제: 파생 앱이 위 플래그를 읽고 있으면 sync 전에 해당
  게이트를 제거하거나 자체 상수로 대체할 것.
  `isAnalyticsEnabled`→`isFirebaseAnalyticsEnabled`,
  `isCrashReportingEnabled`→`isFirebaseCrashlyticsEnabled`,
  `isDebugMode`/`isTestMode`→`kDebugMode` 또는 자체 플래그.

### Fixed
- fork-to-ship 안전 게이트/무음 결함 복구 (B1·B2·B3):
  - **Firebase 재설정 hard-fail (B1)**: `setup_firebase_step`이 `bool`을 반환하고
    google-services.json이 실제 목표 프로젝트로 교체됐는지 검증 — 실패 시 init이
    중단(과거: void 반환 + 전 실패분기 무음 skip → boilerplate-2024가 그대로 출시).
  - **Android release 서명 게이트 (B2)**: `build.gradle`이 KEYSTORE_PATH 없이
    release 조립 시 hard-fail(opt-out `ALLOW_DEBUG_RELEASE_SIGNING`), `./deploy`
    preflight가 production에서 패키지명/Android keystore/iOS 자격증명/개인정보 URL을
    검사(과거: 디버그 서명 AAB가 무음 통과).
  - **feature 토글 무음 no-op (B3)**: `biometric`·`abTesting`·`crashReporting`·
    `splashAd`의 `FF_` 필드명 명시 매핑 + 모든 CLI 키가 실제 `AppFeatureConfig`
    필드에 매칭되는지 검증 테스트.
- 스토어 제출 메타데이터/컴플라이언스 배선 3건 복구 (생성됐으나 소비되지
  않던 "끊긴 고리"):
  - **설명 카피**: `init`이 GPT 생성 카피를 `fastlane/metadata/`(submodule)에
    써서 deliver(루트 `metadata/` 읽음)에 영영 반영되지 않고 placeholder가
    업로드되던 문제 — `generate_description_step`을 루트 `metadata/` SSOT로 수정.
  - **연령등급**: `setup_store_info_step`이 `store_info.json`에만 쓰고 어떤
    레인도 읽지 않던 age rating을 deliver가 소비하도록 — flat
    `metadata/rating_config.json` 생성 + `ios.rb` `app_rating_config_path` 연결.
    deliver 미인식 키 3개(`PROLONGED_GRAPHIC_SADISTIC_REALISTIC_VIOLENCE` 등)
    정정 (fastlane 2.233.0 `AgeRatingDeclaration` 스키마 대조).
  - **App Privacy(iOS 영양표시)**: 생성기 부재 + `./deploy` 미연결이던 것을
    — `renderAppPrivacyJson`(기능 셋 → ASC `app_privacy_details.json`) 추가,
    `generate-data-safety`가 함께 생성, `privacy.rb`가 메타데이터 SSOT 경로에서
    읽기, `./deploy`(production·iOS)가 생성 후 `upload_privacy_details` 호출.
- SplashView 도달성 복구: router redirect가 `/splash`를 즉시 가로채
  ATT/프라이버시 동의 플로우가 영원히 실행되지 않던 문제 수정 — SplashView가
  동의 수집과 후속 네비게이션을 직접 소유, 죽은 `/authentication` 경로도
  `/auth`로 수정 + 도달성 회귀 테스트 (P1-13a)

## [template-v1.0.0] - 2026-06-12

P0 마일스톤 완료 — fork → ship 골든 패스 확립. 첫 템플릿 릴리즈
(P1-10/11/12 인프라 포함).

### Added
- tools/cli 버전 배포: `bp` 통합 진입점 + pubspec `executables` —
  파생 앱은 `dart pub global activate --source git --git-path tools/cli
  --git-ref <tooling.cli_ref>`로 설치, 템플릿 본체는 path 실행 유지.
  `./run` 런처 116→12줄 (부트스트랩을 Dart로 이전) (P1-10)
- sync 매니페스트 단일화: `sync-manifest.yaml`(파일 SSOT) + `apps.yaml`(앱
  레지스트리) + 더티트리/untagged HEAD 가드 + 파생 앱 `template.lock` 기록 (P1-11)
- 릴리즈 규율 lite: CHANGELOG + 릴리즈 태그 네임스페이스(`template-v*` / `cli-v*`)
  + 배포 태그(`v*`) semver 형식 게이트 (P1-12)
- fastlane 레인 계약 CI: `.github/workflows/lane-contract.yml` +
  `scripts/check_lane_contract.rb` — tools/cli·CI 워크플로우가 호출하는 레인이
  핀된 fastlane ref에 모두 존재하는지 PR마다 검증 (P1-12)
- `project.yaml tooling`에 `cli_ref` / `template_version` 핀 추가 (P1-10/12)
- 루트 진입점 `./run` + 부트스트랩 가드(dart pub get, fastlane 핀 클론) (P0-3)
- 루트 3파일 SSOT 설정 스키마(`project.yaml` / `app_config.yaml` / `.env`) +
  단일 env 산출물 파이프라인(`gen_env`, `app/config/env/.env.{debug,profile,release}`)
- deploy 계약 확립: fastlane 핀 + 인자 계약 테스트 (P0-7)
- template-smoke CI: fork 골든 패스 검증 스캐폴드 (P0-2)
- qa-gate CI: analyze + test + coverage, fresh checkout에서 결정적 green (P0-9)
- A/B test service + 운영/라이프사이클 가이드
- 멀티 로캘 스토어 메타데이터 + 릴리즈 노트 생성기

### Changed
- fastlane/을 별도 repo([raynear/flutter-fastlane])로 분리하고
  `project.yaml tooling.fastlane_ref` 태그 핀으로 소비 (P0-6)
- 경로 계약 통일: `<root>/metadata` 단일 SSOT (P0-8)
- rename 재작성: 트리의 현재 식별자 기준 치환 + init hard-fail (P0-5)
- `v*` 배포 게이트(ci.yml)가 qa 잡 통과에 의존하도록 변경 (P0-9)

### Fixed
- 부팅 순서: 기능 플래그를 서비스 init 전에 yaml 기반으로 확정 (P0-4)
- drift codegen 파이프라인 수리 — BadgeType 미해결 / 패키지명 하드코딩 / 단계 누락 (P0-3)
- Android Gradle/AGP 정렬 — fresh fork가 현 Flutter stable에서 빌드 (P0-3)
- home_widget 잔재 제거 — 라이브 빌드 블로커 해소 (P0-3)
- `release-notes.yml`: fastlane repo 분리 이후 끊겨 있던
  `fastlane/release_notes_config.json` 참조 수리 — 핀된 ref로 fastlane checkout
  추가, 릴리즈 노트 산출물 경로를 `<root>/metadata` SSOT(P0-8 계약)로 정렬 (P1-12)

[Unreleased]: https://github.com/raynear/boiler_plate/compare/template-v1.0.0...HEAD
[template-v1.0.0]: https://github.com/raynear/boiler_plate/releases/tag/template-v1.0.0
[raynear/flutter-fastlane]: https://github.com/raynear/flutter-fastlane
