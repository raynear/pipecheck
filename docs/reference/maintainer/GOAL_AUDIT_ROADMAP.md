# 보일러플레이트 목표 감사 + 통합 로드맵

> 2026-06-11 (v1.1 — capability 전수 분류 병합, 부속 문서: [CAPABILITY_MATRIX.md](CAPABILITY_MATRIX.md)). 목표: ① fork → 약간의 수정 → 스토어 배포 가능 ② 공통 기능 내장 + 앱별 기능 패키지화 ③ flutter-fastlane repo 포함.
>
> **v1.2 (2026-06-12) — 운영 제약 2건 확정 + 백엔드 전환 반영:**
> ① **GitHub Actions 영구 미사용** (빌링 안 함) — 모든 검증은 로컬(fresh worktree 스모크 + flutter analyze/test + tools/cli dart test). Actions 의존 항목은 로컬/branch 방식으로 전환 (신규 항목 15.5).
> ② **외부 서비스는 무료 티어만** — 유료 전제 설계 금지. Firebase Cloud Functions(Blaze 필요) 사용 불가 → **서버 코드 0줄 원칙**.
> ③ **Supabase 폐기 확정** (유지관리 부담) — 확정 대체 스택: Firebase Auth(인증) + 클라이언트 직접 계정 삭제 + RevenueCat 무료 티어(IAP 검증) + local-only Drift 기본(원격 필요 시 Firestore Spark 한도) + Firebase Hosting(법적 호스팅 — Pages branch 방식은 private repo가 Free 플랜에서 미지원이라 15.5b에서 재전환). 신규 항목 16.5, 기존 20/21/21.5/23.5 개정.
> 진행 상태: P0 전체 + P1-10~15 완료 (PR #4~#18, template-v1.0.0/cli-v1.0.0, fastlane v0.2.2 핀). **다음 작업: 15.5 → 16 → 16.5 → 17 → 18.**
> 방법: 8개 영역 병렬 감사(앱 런타임/패키지 시스템/tools-cli/fastlane/문서/품질 게이트/전파/포크 워크스루) → 3개 전략(모듈화/배포속도/유지보수) → 적대적 비평 + 통합. 모든 핵심 주장 repo 대조 검증됨 (검증 중 신규 버그 1개 추가 발견: sync-to-apps가 존재하지 않는 `scripts/build`를 동기화).

---

## 1. 한 줄 결론

**자동화 천장은 동급 최고 수준인데 바닥이 부서져 있다.** ./run init은 rename→env→서명→Firebase 생성→GCloud IAM→ASC 등록→AI 아이콘/설명→법적 문서까지 자동화하지만, fresh fork가 문서대로 따라가면 **첫 명령부터 죽고**, 살려서 끝까지 가도 **보일러플레이트 번들 ID로 + debug 설정으로 + beta 트랙에만** 출시된다. 목표 #2(패키지화)는 메커니즘 5개가 난립하고 경계 규칙이 없으며, 파생 앱 4개로의 전파는 사실상 죽어 있다. **수리 순서: 이음새 수리(P0, 10-14일) → 컴플라이언스+전파+문서(P1, ~3주) → 패키지화(P2)** — 코어가 수술 중일 때 패키지로 추출하면 모든 수정을 두 번 하게 됨.

---

## 2. 검증된 블로커 (전부 file:line 확인)

### 런타임 (앱이 release에서 깨짐)
| # | 내용 | 증거 |
|---|------|------|
| R1 | **release 빌드 = enableAllFeatures 클로버**: 서비스 init **후**에 `applyProductionConfig()`가 모든 플래그 강제 ON → AdService late-field 크래시, Supabase 미초기화 late 접근, IAP 가격 0원, 포크의 기능 선택 무효화 | `main.dart:21,30-34`, `app_feature_config.dart:162-169` |
| R2 | **SplashView 도달 불가**: router.redirect가 /splash를 무조건 우회 → ATT 요청·프라이버시 동의·스플래시 광고 전부 데드코드 (App Store ATT 컴플라이언스 리스크). splash는 존재하지 않는 `/authentication`으로 navigate (실제 `/auth`) | `router.dart:204-214`, `splash_view.dart:112-185,193` |
| R3 | **IAP 권한 클라이언트 전용**: 만료를 구매 시점 로컬 계산(+1달/+1년/+100년), `checkAndUpdateSubscription` 빈 stub, `verifySubscription` 콜사이트 0 → 갱신자는 한 달 뒤 프리미엄 상실, 해지자는 유지 | `in_app_purchase_service.dart:248-275`, `settings.dart:356` |
| R4 | 데모 인증 풋건: Supabase/email-auth off면 아무 이메일/비번이나 'demo-user'로 통과 | auth viewmodel |
| R5 | 만든 서비스 미배선: ForceUpdateService·AppReviewService·ErrorHandler.setupGlobalErrorHandling 콜사이트 0 — 조잡한 중복이 대신 배선됨. A/B 시스템 4-5개 공존 (ABTestService만 양품) | |

### tools/cli (포크가 잘못 출시됨)
| # | 내용 | 증거 |
|---|------|------|
| C1 | **rename 영구 실패 + 묵살**: init이 `--name` 전달하나 ArgParser에 미정의 → FormatException; dotted bundle id를 Dart 패키지 검증기가 거부; `com.example.*` 가정 (실제 `com.raynear.boilerplate`) → **포크가 보일러플레이트 번들 ID로 출시, init은 성공 보고** | `rename_package_step.dart:12-19` |
| C2 | **deploy target/platform 버려짐**: `build_and_upload` 레인이 옵션 없이 `push` 호출 → `--target production`이 조용히 beta 경로로 | `deploy_command.dart`, `Fastfile:53-55` |
| C3 | fresh clone에서 ./run 즉사 (tools/cli `dart pub get` 선행 필요, 가드 없음) | `run:55-67` |
| C4 | applyProfileStep = 로그 한 줄 (profile 기반 플래그 설정 광고는 허위) | init steps |
| C5 | env 3종 버그 = CONFIG_CONSOLIDATION_PLAN 그대로 (재설계 금지, 실행만) | `docs/CONFIG_CONSOLIDATION_PLAN.md` |

### fastlane repo (배포 마지막 1마일 부재)
| # | 내용 | 증거 |
|---|------|------|
| F1 | `setup_ios_certificates` **미정의 함수** → 플래그십 `deploy` 레인 크래시 | `code_signing.rb:34`, `Fastfile:94-107` |
| F2 | `create` 레인이 존재하지 않는 `setup_firebase_project` 레인 호출 | `create.rb:18` |
| F3 | metadata 경로 3곳 충돌 (레인은 `<root>/metadata` 읽는데 템플릿에 없음, CLI는 gitignored fastlane/ 안에 씀 → 생성 리스팅 유실), IAP JSON glob 불일치 (`<root>/store_data` vs `app/store_data` → 등록 '성공' 0건) | `ios.rb:267` 등 |
| F4 | Play 레인 14개 전부 **Firebase 서비스 계정**으로 업로드 (GOOGLE_PLAY_JSON_KEY 죽은 노브), keystore alias `upload` 하드코딩 (key_alias 죽은 노브), IAP 가격 JPN/JPY 하드코딩 | |
| F5 | iOS 심사 제출 레인 부재 (`submit_for_review: false` 하드코딩) — 마지막 1마일 수동 | |
| F6 | **태그 0개, 버전 핀 전무**: CI가 fastlane HEAD 추적 → main 푸시 한 번에 전 앱 파손 가능. run_tests가 fastlane 내장 scan 섀도잉 | |

### CI/품질 게이트 (전부 RED)
| # | 내용 | 증거 |
|---|------|------|
| Q1 | qa-gate에 **codegen 단계 없음** + `*.g.dart` gitignored → CI에서 컴파일 불가, **최근 5/5 실패** (4개 파생 앱에 동기화된 게이트) | `qa-gate.yml:48-60` |
| Q2 | 기본 테스트 2개 로컬에서도 컴파일 실패 (counter 테스트 잔재, ProviderScope 없는 pump) | `app/test/widget_test.dart` |
| Q3 | `v*` 태그 푸시 → 테스트 0개 거치고 스토어 배포 직행 | `ci.yml` |
| Q4 | 진짜 테스트 ~2개 / lib 176파일, 서비스 28파일 테스트 0, tools/cli 테스트 21개는 CI 미실행, fastlane repo CI 자체가 없음 | |
| Q5 | 템플릿 스모크 테스트 부재 — "fork→init→build" 약속을 검증하는 게이트 없음 | |

### 전파 (목표의 절반이 여기서 죽음)
| # | 내용 | 증거 |
|---|------|------|
| P1 | sync-to-apps가 **죽은 래퍼 배포**: 래퍼는 tools/cli 위임인데 파생 앱 4개 중 **0개**에 tools/cli 존재 (kanken/hanja는 tools/ 자체 없음). blind `cp`, 충돌 처리 없음, 존재하지 않는 `scripts/build` 동기화(검증 중 발견된 신규 버그), 깨진 release-notes.yml 배포 중 | `sync-to-apps:28-44,101` |
| P2 | **공통 Dart 코드 전파 경로 전무** — 파생 앱은 포크 시점에 동결. 템플릿 버전 스탬프/CHANGELOG/마이그레이션 노트 없음 | |
| P3 | fastlane 통합 패턴 3개 혼재 (provision clone / kanken submodule-main추적 / CI ref 없는 checkout) | |

### 문서 (골든 패스 없음)
| # | 내용 |
|---|------|
| D1 | **fastlane/이 fresh fork에 없는데 어떤 문서도 모름** (gitignored, provision만 클론하는데 provision은 raynear 개인 인프라 하드코딩 + 번호 문서에서 미언급) |
| D2 | 유령 루트 명령(./init 등 — ./run만 존재), 유령 fastlane 레인 8+개 (deploy_testflight 등), 유령 .env 키 계약 |
| D3 | 진입 문서 5개 상호 모순; 온보딩이 project.yaml 존재를 모름 (quick-start는 분리 전 스키마); 01-GETTING_STARTED 플래그 기본값 표가 코드와 반대 |
| D4 | 2026-01-03 스냅샷 생성 문서들이 LLM 컨텍스트 오염 (root packages/ 등 허위 경로) |

### 패키지화 (목표 #2)
| # | 내용 |
|---|------|
| M1 | **옵션 기능 메커니즘 5개 난립**: path 패키지 / examples 복사 / 40개 런타임 플래그 / pubspec 주석 블록 / 원격 플래그 — 경계 규칙 없음 |
| M2 | feature_cli enable/disable = 플래그 regex 치환만 (deps/코드 추가 안 함, 유령 타깃 존재) |
| M3 | vendored 잔재 257 추적 파일 (heatmap 123, geofence 134 — 파생 앱 누출물), app_blocker/openmoji 미추적 stub |
| M4 | examples/에 `package:boilerplate` import 26곳 → ./init rename 후 전부 파손. README/문서 0 |
| M5 | 파생 앱 패키지 배포 메커니즘 부재 (melos/workspace/태그 없음) |

**강점 (재발명 금지)**: 서비스 폭 거의 완성 (Analytics/Crashlytics/RC/FCM/광고 4종/IAP+복원/ATT+동의/강제업데이트/리뷰/뱃지/8개 로케일 i18n/디자인 시스템 2종), graceful-degradation 플래그 패턴 일관 적용, ABTestService는 진짜 양품, 페이월 UI 2종 기성, settings 900줄 거의 출시급, home은 의도적 박형(~290줄)이라 교체 저렴, env_loader.rb는 이미 3파일 SSOT 구현.

---

## 3. 전략 평결

- **척추 = S2 배포속도**: 6개 이음새(부트스트랩→rename→env→부팅순서→deploy 계약→CI)가 fork와 TestFlight 사이의 전부. 목표 DX 정의: *fork → 루트 3파일 편집 → `./run init`·`./run preflight`·`./run deploy --target beta` → 60분 내 TestFlight+internal track, home 교체 후 production 제출.*
- **배포 메커니즘 = S3 유지보수 승**: tools/cli는 복사 금지 → 태그 + `dart pub global activate --git-path --git-ref` (템플릿 본체는 path 실행 유지). fastlane repo는 **분리 유지** + 태그/VERSION/`fastlane_ref` 핀. sync 표면은 축소(런처+워크플로우 2개만, Dart 코드 절대 금지) + 단일 manifest + template.lock 스탬프.
- **패키지화 = S1 모듈화는 방향 맞고 타이밍 틀림**: workspace+추출은 P2 (스모크 green + IAP 수리 후). 단 **경계 규칙(MODULES.md)과 잔재 퇴거는 저렴하므로 P1로 선행**:
  - **런타임 플래그** = 의존성 없는 공통 코드의 행동 토글 (40개 → ~12-15개)
  - **패키지** = pub 의존성/네이티브 코드/앱 특화 도메인 보유 (ads, IAP, supabase, geofence…) — 컴파일 타임 포함, pubspec 1줄 + init 1콜
  - **examples 복사** = 앱이 소유/수정할 코드만 (sample_tables 패턴), 패키지명 비의존으로 재작성
- **메커니즘 확정**: 단일 repo 유지(템플릿 겸 패키지 모노레포), `app/packages/` → 루트 `packages/`, Dart **pub workspace** (Dart 3.6+, 앱 SDK >=3.8.0 확인됨 — melos 불필요), 파생 앱은 **pinned git deps** (`url+path+ref` 태그). bp_ 일괄 개명 기각(순수 churn). pub.dev 발행/멀티레포 분리/melos/PR-sync는 트리거 발생 시만 (§로드맵 24).
- **비평가 보정 2건**: ① 스모크 테스트를 마지막이 아니라 **P0 첫 단계에 informational 모드로** 스캐폴드 — 이후 모든 수리가 체크를 green으로 뒤집는 구조. ② 컴플라이언스 번들 3-5일 추정 기각 → 1.5-2주로 재산정 (UMP+계정삭제+ATT 복원은 솔로 기준 2-3배).

---

## 4. 통합 로드맵 (24항목, 위에서 아래로 실행 가능)

### P0 — 골든 패스 복구 (~10-14일)
1. **CONFIG_CONSOLIDATION_PLAN 그대로 실행** (2-3일) — env 3종 + AdMob 거처 + preflight 유령 검사 + 레거시 생성기 삭제. 재설계 금지.
2. **template-smoke.yml informational 모드 스캐폴드** (1일) — fresh checkout → pub get 부트스트랩 → `./run init` (CI fixture project.yaml, --skip-icon 등) → codegen → `flutter build apk --debug`. Linux PR + macOS 주간 cron. 항목 5까지 non-required.
3. **부트스트랩 수리 + home-widget 잔재 삭제** (1-1.5일) — ./run에 pub-get 가드, fastlane/ 부재 시 pinned ref 자동 클론, 루트 심볼릭링크(./init ./deploy ./feature ./preflight ./setup) + **신규 build 래퍼** (존재한 적 없음 — 심볼릭링크로 해결 불가). **[v1.1 추가, 라이브 빌드 블로커]** `HomeWidget.kt`/`HomeWidgetReceiver.kt`(kotlin/com/raynear/nofon/widget/)가 pubspec.lock에 없는 home_widget 플러그인 클래스를 import → `flutter build apk --debug` Kotlin 컴파일 실패. 두 Kotlin 파일 + AndroidManifest.xml:31-38 receiver 블록 + res/xml 위젯 리소스 삭제 — 이거 없으면 항목 2의 스모크가 영원히 red.
4. **부팅 순서 수정** (1-2일) — `applyProductionConfig=enableAllFeatures` 삭제, app_config.yaml의 profile+feature_overrides를 **서비스 init 전에** 로드, applyProfileStep 실구현. 파생 앱 플래그 덤프 마이그레이션 노트 포함.
5. **rename 재작성 + init soft-fail 문화 제거** (2-3일) — --name 지원, dotted id 검증기, 현재 applicationId를 build.gradle/pbxproj에서 읽기, Manifest label/Info.plist/kotlin 디렉토리/app_config.yaml writeback까지. init step 실패 = 종료 코드 ≠0.
6. **flutter-fastlane 핀** (1일) — v0.1.0 태그 + VERSION + compat 레인, provision `--branch $fastlane_ref`, CI `ref:`, preflight 핀 대조, kanken submodule 패턴 제거. **항목 7보다 먼저** (레인 시그니처 변경이 4개 앱 HEAD로 즉시 전파되는 사고 방지).
7. **deploy 계약** (2-3일) — build_and_upload `|options|` + push.rb 스레드 서브프로세스에 옵션 직렬화 전달, production 라우팅, setup_ios_certificates/setup_firebase_project 미정의 수리, 오케스트레이터는 tools/cli 단일화.
8. **경로 계약 통일** (1일) — `<root>/metadata` 단일 SSOT, IAP JSON 경로 일치, 아이콘 경로 단일화.
9. **CI green** (1일) — qa-gate에 codegen 단계, 깨진 기본 테스트 → ProviderScope 부팅 스모크 1개로 교체, Discord 알림 버그, v* 태그 배포에 게이트 의존성.

### P1 — 컴플라이언스·전파·문서 (~3주)

> **완료 (2026-06-12):** 10(PR #5) · 11(PR #6) · 12(PR #7) · 13 전체 a~f(PR #8~#13) · 14 전체 a~c(PR #14~#16) · 15 전체(PR #17~#18, fastlane v0.2.2) · 15.5(legal-pages branch 전환, PR #20) · 16 전체(플래그 13 삭제 PR #21 / MODULES.md PR #22 / 잔재 퇴거 PR #23) · 16.5 전체(Supabase 철거 PR #24 + 문서 스윕 PR #25 / Firebase Auth 전환 PR #26 / fastlane v0.2.3 핀) · 17 전체(IAP 계약 PR #28 / 스크린샷 단일화 PR #29 / submit_ios_review + fastlane v0.2.4 핀) · **18 전체(문서 골든 패스, 2026-06-13, PR #33~#37): 스냅샷 5종 아카이브 #33 / 진입 문서 일원화 #34 / 살아있는 문서 유령 130건 퍼지 #35 / 스프린트 체크리스트 재정합 #36 / 신규 가이드 3종 #37). P1 완료.** 상세는 CHANGELOG [Unreleased].

10. tools/cli 버전 배포 (태그 + pub global activate, 런처 10줄화; 템플릿 본체는 path 유지) (2-3일)
11. sync-manifest.yaml 단일화 + template.lock + apps.yaml 레지스트리 + 더티트리 거부 + 깨진 항목 제거 (1-1.5일)
12. 릴리즈 규율 lite (CHANGELOG+semver, breaking만 마이그레이션 노트, sync는 untagged HEAD 거부) + fastlane 레인 계약 CI (1일)
13. **스토어 컴플라이언스 번들** (1.5-2주, 정직 재산정) — SplashView 도달성 복구(ATT/동의, 0.5-1일), **계정 삭제**(설정 진입점 + supabase delete-account 에지 함수 신규, 2-3일 — 현재 repo 전체 0건), AdMob **UMP/EEA 동의 + NPA 폴백 + COPPA 노브**(3-5일, 추출 전 현 ad_service 단일 지점에 구현 → 항목 20에서 패키지로 통째 이동), PrivacyInfo.xcprivacy(트리 내 0개 확인, tools/cli가 앱별 tracking domain 패치), 법적 HTML GitHub Pages 자동 호스팅, Data Safety 생성기(활성 패키지 셋에서 생성 — correct-by-construction).
14. 죽은/중복 서비스 정리 + 양품 배선 (**4-5일**, v1.1 재산정) — A/B: ABTestService 부팅 배선, FirebaseABTestingService un-wire(app_config.dart:184) 후 삭제 + ab_test_experiment + ab_testing_provider(읽히면 크래시) + feature_flag_service(271줄, 콜사이트 0) 삭제. ForceUpdate/AppReview/전역 에러핸들러 배선(신규 플래그 isForceUpdateEnabled/isAppReviewPromptEnabled), 데모 인증 풋건 제거. **[v1.1 추가]** crash 분류 메타데이터(setCustomKey: flavor/템플릿 버전/플래그 스냅샷/AB variant — repo 전체 0건, 0.5일), 세션 만료/토큰 갱신 실패 처리(supabase_service.dart:77-100은 signedIn/Out/Updated만 처리, 1일).
15. 하드코딩 → 설정 3파일로 (1-2일) — 프라이버시 URL 4곳, 'idYOUR_APP_ID', 구독 카피, fastlane JPN/JPY·tester group·keyAlias·kotlin glob, Play 자격증명 분리. **[v1.1 추가]** RC zero-reader 기본 키 정리(maintenance_mode는 항목 23에서 소비자 획득, subscription_variant류는 항목 21에서 — 나머지 퍼지, 0.25일).
15.5. **[v1.2 신규] legal-pages branch 방식 전환** (0.5일) — Actions 미사용 확정으로 `legal-pages.yml` 실행 불가. generate-legal 산출물(+index)을 `docs/legal/`로 커밋하고 Pages Source=branch(main /docs) 사용. **[15.5b 개정: repo가 private이라 Free 플랜에서 Pages 미지원 — Firebase Hosting으로 재전환.** `./run deploy-legal` 신설(firebase.json hosting.public=docs/legal), URL 도출은 google-services.json 프로젝트 ID 기반 `https://<id>.web.app/<file>`. **수동 1회: npm i -g firebase-tools + firebase login.]**

16. **MODULES.md 경계 규칙 + 40→12 플래그 채택 + 잔재 퇴거** (**4-5일**, v1.1 확장) **[v1.2 주의: supabase 관련 플래그(isSupabaseDatabaseEnabled/isDatabaseSyncEnabled)와 서비스는 여기서 '폐기 예정' 표기만 — 삭제는 16.5에서 일괄]** — [CAPABILITY_MATRIX.md](CAPABILITY_MATRIX.md)의 분류 채택: **죽은 플래그 13개 즉시 삭제**(전부 기능 gate 0 검증), 패키지행 19개는 two-phase 표기(P2 추출 전까지 동작 유지), 최종 12개 확정(기존 8 + 신규 4). 규칙 수정 1건: core 마이크로 의존성 allowlist(force_update/network/consent/review/share 5개). app_blocker/openmoji 삭제, heatmap/geofence는 소유 앱(flowmodoro) repo로, 'boilerplate' 패키지명 비의존화(examples 26곳). feature_cli 재작성은 P2로 이연.
16.5. **[v1.2 신규] Supabase 철거 + 무료 백엔드 전환** (3-5일) — 확정 스택(무료 전용, 서버 코드 0줄): **Firebase Auth**(email/social) + **클라이언트 직접 계정 삭제**(`currentUser.delete()` + 본인 데이터 삭제, Firestore rules로 본인 한정 — 서버 함수 불필요) + **RevenueCat**(IAP 검증, 항목 21) + **local-only Drift 기본**(원격 필요 시 Firestore Spark 한도 내).
    - 철거: `supabase_service.dart`, `supabase/` 디렉토리 전체(에지 함수 7개 — 13b delete-account 포함, **배포 불필요해짐**), supabase 플래그 2종, `app_config.yaml services.supabase` 스키마, gen_env SUPABASE_* 키, `syncUserData` 죽은 코드(23.5(a) local-only 확정 반영), supabase_flutter pubspec 의존.
    - 전환: auth_view_model email auth → Firebase Auth, `AuthState.deleteAccount` → 클라 직삭제 경로(13b의 진입점/플래그/상태 구조는 백엔드 무관이라 재사용), FCM 토큰 저장처 결정(Firestore or 제거), Data Safety 생성기(13f)·legal 생성기 입력 기준 갱신(supabaseEnabled → Firebase Auth 기준), 13b deno 테스트 삭제 + 전환 후 동등 테스트.
    - 순서: 16(플래그 정리) 이후 — two-phase 표기가 선행돼야 삭제 대상이 확정됨.

17. 마지막 1마일 (2-3일) — iOS submit_for_review 레인 + export-compliance 자동응답, 스크린샷 파이프라인 단일화(죽은 fastlane 레인 제거, tools/cli 하니스 표준).
18. 문서 골든 패스 (2-3일, **코드 수리 후에만**) — 진입 문서 5개 → quick-start 중심 일원화, 유령 명령/레인/키 퍼지, 스냅샷 문서 아카이브, 신규 3문서(패키지 작성 가이드 / 파생 앱 업데이트 가이드 / fastlane repo 관계). **[완료 2026-06-13, PR #33~#37]** — quick-start를 골든 패스 SSOT로 승격, 스냅샷 5종 docs/reference/archive/로 이동, 정찰 워크플로우로 confirmed된 유령 296건 중 살아있는 문서 분(~170건) 퍼지, 신규 3문서는 docs/guides/{PACKAGE_AUTHORING,DERIVED_APP_UPDATES,FASTLANE_REPO}.md. **알려진 잔재(P2-20 몫): app/packages/ab_testing가 supabase_flutter 의존 + app에서 미소비 — 재구축 시 정리, PACKAGE_AUTHORING.md §8에 격리 기록.**

### P2 — 목표 #2 본체 (안정화된 코어 위에서)
19. pub workspace + git-dep 증명 (**3-5일**, v1.1 확장) — packages/ 루트 이동, workspace 루트 pubspec, utils SDK floor 인상, pkgs-v1.0.0 태그, 파생 앱 1개에서 utils 핀 소비 + 빌드 증명. **[v1.1 추가]** 추출 전 utils SSOT 통합(app/lib/core/utils.dart + core/utils/ 흡수 — importer 44곳 검증) + `app/lib/data/table_generator/`를 dev 패키지로 이동(현재 lib/ 안이라 ~~모든 출시 바이너리에 컴파일됨~~ 검증).
    - **[v1.2 실측 정정 (2026-06-13, PR #39·#40)]:** ①utils 통합 = **19a 완료(PR #39)** — 실측은 죽은 배럴 1개 삭제 + validators(2 importer) 이동뿐(브리핑 "44곳"은 과대평가). ②**table_generator dev 패키지 이동은 폐기.** 실측 결과 전제가 거짓 — analyzer/build/source_gen/code_builder는 전부 `dev_dependencies`고, builder/generators는 런타임(main) 미도달(build 엔트리포인트만 import → tree-shake 제외)이라 **이미 출시 바이너리에 안 들어감**. dev 패키지 추출은 출시 크기 이득 0 + workspace(아래)도 이동 불필요 + rename_command fork 경로(P0-5) 결합 위험만 큼 → 추출 대신 **죽은 `code_builder` dep 제거(PR #40)**만. ③**workspace 전환 = 19c 완료(PR #42).** 사용자 결정으로 packages/ 물리 이동 없이 **제자리** workspace 선언(루트 pubspec + resolution:workspace + 단일 lock + SDK floor 인상 + flutter_lints 통일). fresh worktree ./build+test green. ④**pkgs-v1.0.0 태그 + 파생 앱 git-dep 증명 = 19d 완료(PR #44 + 태그).** 파생 앱(snapdic) worktree에서 utils를 git 의존(`ref: pkgs-v1.0.0, path: app/packages/utils`)으로 핀 소비 — pub get 해석 성공(lock에 resolved-ref), import 46파일 utils 에러 0, resolution:workspace는 외부 git-dep로 정상 해석(블로커 아님). **P2-19 전체 완료.** project.yaml tooling.pkgs_ref 추가. 상세 [[p2-19-plan]].
20. 추출 1차 (**1.5-2.5주** 단계적, v1.1 순서 확정 / **v1.2: supabase 패키지 취소 — 16.5에서 선철거됨, 11개→10개**) — **순서: utils → ab_testing**(ABTestService 중심 재구축, 중복 A/B 스토어 migration 정리) **→ authentication**(진짜 opt-in화 — 현재 path dep으로 항상 컴파일되는 역방향 오류; Firebase Auth 포함) **→ location/notifications/ads/firebase → monetization**(항목 21 이후 하드 게이트). 패키지 내 codegen 커밋 + drift CI(로컬 스크립트 — Actions 미사용). 패키지 목록·내용물은 [CAPABILITY_MATRIX.md](CAPABILITY_MATRIX.md) §3.
21. **IAP 검증 — RevenueCat 통합** (2-3일, **v1.2 전면 재설계** — verify-subscription 에지 함수 배선 계획 폐기, 함수는 16.5에서 삭제) — RevenueCat 무료 티어(월 추적수익 $2.5K, 카드 등록 불필요)로 영수증 검증/갱신/해지/grace period/billing retry 전부 외주화, 로컬 만료 계산 대체. purchases_flutter 도입 + InAppPurchaseService 어댑터. 이후: **paywall RC/A-B variant 배선**(subscriptionVariant getter 콜사이트 0 검증 — 권한 수리 후에만 의미), promo/offer 코드(+1-2일, RevenueCat Offerings 사용). 수익화 출시 전 필수로 README 명시.
21.5. **[v1.1 신규] social_auth 패키지** (1주 + Kakao 2-3일) — Apple+Google 로그인, Kakao 서브 라이브러리. 검증: 현 authentication 패키지는 local_auth 전용, google_sign_in/sign_in_with_apple/kakao 사용 0. **[v1.2 개정]** Firebase Auth `signInWithCredential`을 인터페이스 뒤에 (특정 백엔드 하드 의존 금지 원칙 유지). 순서: 항목 16.5(Firebase Auth 전환) + 19(workspace) 이후.
22. **파생 앱 4개 이전 = [v1.2 완료 (PR #80, 문서+검증)]** — **사용자 결정: 메커니즘+문서+1앱 비침습 증명**(실 마이그레이션·외부 repo 착지 안 함). 정찰 결과 인프라 대부분 선구축(CLI 런처 `./run`=P1-10 / sync+template.lock 메커니즘=P1-11 / git-dep 핀 증명=P2-19d / flowmodoro 특화 퇴거=P1-16c) → 항목 22 = reality 정렬. **실측 4앱 2종**: snapdic·flowmodoro=utils·auth·ab_testing를 vendored-copy(`path:`) 소비(stale — snapdic ab_testing에 철거된 supabase 잔존) / kanken·hanja=패키지화 이전 완전 분리 포크(provider·자체 디렉토리·템플릿 패키지 0)=**수동 sync only·스코프 외**(사용자 결정). [DERIVED_APP_UPDATES.md](DERIVED_APP_UPDATES.md)에 누락됐던 4번째 전파 갈래(`pkgs_ref` git-dep 핀) + 파생 앱 현황 2종 + vendored→git-dep 전환·비침습 worktree 검증법·**pkgs-v1.0.0 stale 경고**(9패키지 추출 이전 → 실 업그레이드 전 새 `pkgs-v*` 태그 발행) 문서화, 태그 네임스페이스 3→4종(`pkgs-v*` 추가). **검증(비침습)**: `./run` 부팅 / `sync-to-apps --dry-run --app snapdic`(WOULD WRITE template.lock) / snapdic worktree `utils@pkgs-v1.0.0` git-dep resolved-ref `2a0613b`. 자동 sync 금지(의도적 로컬 변경 보유 스냅샷).
23. 공통 기능 완성 (**~2주** 단계적, v1.1 사이징) — 딥링크(사용자 결정 "둘 다"=커스텀 스킴+유니버설. **Stage 1a 런타임 = [v1.2 완료 (PR P2-23a)]**: app_links 7.1.2 + DeepLinkService[onUri 주입·콜드 getInitialLink+웜 uriLinkStream·sync dispose] + 순수 deepLinkLocation[화이트리스트 라우팅·플로우내부 제외] + 신규 isDeepLinkEnabled[opt-in] + main.dart post-frame 게이트. **Stage 1b CLI = [v1.2 완료 (PR P2-23a-1b)]**: `./run generate-deeplink`(generate-privacy 트리오 미러 — 순수 injector + command + bin + init step + 4 등록) project.yaml deep_link.scheme→Android intent-filter+iOS CFBundleURLTypes **마커 멱등 주입**(.MainActivity 닫힘 특정·루트 dict 특정). ConfigLoader.deepLinkScheme/UniversalLinks. 빈 스킴=no-op라 템플릿 클린 유지. E2E 실파일 검증. **Stage 2a CLI = [v1.2 완료 (PR P2-23a-2a, #62)]**=유니버설/앱링크: injectAndroidUniversal(autoVerify https intent-filter, 스킴과 별도 마커 DEEPLINK-UNIVERSAL)+injectIosAssociatedDomains(entitlements)+AASA/assetlinks 본문(docs/legal/.well-known/, assetlinks SHA-256=외부값 빈 placeholder, AASA는 team_id 시만). 선수정: Runner.entitlements 죽은 App Group 제거+pbxproj 3 Runner config CODE_SIGN_ENTITLEMENTS 배선(사용자 결정 "제거+항상 배선"). 부수 fix: ConfigLoader._getStringList _value 래퍼 언래핑(잠재 버그, E2E 발견). **Stage 2b 호스팅 = [v1.2 완료 (PR P2-23a-2b, #63)]**=firebase.json ignore `**/.*`→`**/.DS_Store`(.well-known dotdir 제외 해제)+AASA Content-Type application/json 헤더(deploy-legal이 .well-known 서빙). **→ 딥링크 전체 완료**), **maintenance mode = [v1.2 완료 (PR P2-23b)]** (RC `maintenance_mode` 소스 게이트 + MaintenanceView 전체화면 차단 + 신규 isMaintenanceModeEnabled[→isFirebaseRemoteConfigEnabled 의존 = firebase 없으면 no-op] + MaintenanceService fail-open. force_update와 동일 패턴, standard+ 기본 ON·실차단은 RC 값이 결정. main.dart post-frame 게이트), **AsyncValueView 프레임워크 = [v1.2 완료 (PR P2-23c)]**(AsyncValue<T>→로딩/에러/빈/데이터 4상태 합성, 기존 LoadingIndicator/AppErrorWidget/EmptyState 재사용 + isEmpty/onRetry/errorMessage/커스텀 슬롯, lib/core/widgets/async/, riverpod when 위임), **하드코딩 한국어 i18n 스윕 = [v1.2 완료 (PR P2-23d, #65~#70)]**(실측 ~32파일·~140문자열 — "103파일" 과대평가. easy_localization `'key'.tr()`. **dart 하드코딩 lint 가드**[`test/lint/hardcoded_string_test.dart`, allowlist=burndown 추적]. PR1 #65 코어위젯·다이얼로그 / PR2 #66 domain·service / PR3a #67 permission[const 기본값→nullable+build resolve, 센티넬 `!=한글`→`!=null`] / PR3b #68 auth[VM이 bare 키 반환·snackbar 해석] / PR3c #69 settings·home / PR4 #70 입력위젯[const 기본 hint→nullable]. 신규 네임스페이스 errors/auth/router/authActions/permission/login/settings/notificationSettings/home/inputs × 8 로케일 실번역. **allowlist=영구예외 3개[table_generator/design/config]만 잔존 → lint가 전 lib/ 스캔·통과 = 코드베이스 하드코딩 한글 0**. 패턴: SText·SnackBarService 자동 `.tr()`→소비처 bare 키 / Text·state·notif은 리터럴 `.tr()` / const 기본값→nullable+resolve / DB 시드는 i18n-ignore / 보간은 `.tr(args:)`), **Riverpod 패턴 단일화 = [v1.2 완료 (PR P2-23e, #72)]**(코드 현실 = 수동 Notifier로 문서 정렬), **데이터 내보내기 = [v1.2 완료 (PR P2-23f)]**(GDPR 이동권: DataExportService가 모든 로컬 Drift 테이블[DatabaseDataSource.tableNames]→JSON 임시파일, ShareService.shareFile[share_plus shareXFiles]로 공유. 신규 isDataExportEnabled[의존 없음·기본 ON]. settings 진입점. listTables/readTable 람다 주입으로 DB 무결합 테스트), **온보딩 퍼널 이벤트 = [v1.2 완료 (PR P2-23g, #73)]**(스텝별 5종 FirebaseService.logEvent: start/step_view/skip/complete[get_started·subscribe], 내부 isAnalyticsAvailable 가드). **PIN UX = [v1.2 완료 (PR P2-23h, #74~#78)]**(5 PR: 엔진[PinService salted-hash + 점진 잠금 30s→30m·시계 되돌림 가드] / ① 오입력 피드백[PinEntry shake+햅틱+잔여횟수+잠금 카운트다운] / ② 설정·변경[보안 섹션 + PinSetupView set/change + isPinAuthEnabled opt-in] / ④ 생체+PIN 통합[PIN 기반+생체 가속, biometric 값 재정의로 enum 마이그레이션 0] / ③ 분실 복구[계층 폴백 생체→이메일 재인증→앱 데이터 wipe, fail-closed]). → 항목 23 전체 완료.
23.5. **[v1.1 신규] 결정 2건** — (a) **오프라인 sync: [v1.2 확정] local-only 공식 기본** — 죽은 코드(sync-user-data/syncUserData)는 16.5에서 삭제, 잔여 작업은 MODULES.md에 local-only 기본 선언 1줄뿐. (b) **RC→플래그 override 브리지 = [v1.2 완료 (PR P2-23.5b)]**: yaml profile → RC override → freeze 부팅 패스. `AppFeatureConfig.applyRemoteOverrides`(OFF=무조건 kill-switch / ON=능력 가드 통과 시만 — 미초기화 서비스 force-ON 크래시 P0-4류 차단) + `RemoteConfigService.remoteFeatureOverrides`(source=valueRemote 키만 추려 미설정 키의 false 몰살 방지) + 멱등 `initialize()`. firebase 패키지 없는 포크는 no-op(firebase+RC 플래그 게이트). 양방향 ON은 정책 토글로 처음부터 가능(사용자 결정). 삭제된 271줄 FeatureFlagService의 유일한 좋은 아이디어 대체.
24. 트리거 발동 시만 — packages/ 별도 repo 분리(템플릿 히스토리가 pub fetch 노이즈 될 때), melos(8+ 패키지). **[v1.1 추가]** 광고 mediation(트리거: 수익 최적화 필요한 포크), deferred deep link/설치 어트리뷰션(트리거: 유료 UA), referral 코드(**명시적 non-goal로 MODULES.md 기록** — 앱 특화 백엔드), 앱 숏컷/홈 위젯 example.
    - **[v1.2 완료 (사용자 지시로 §24에서 졸업)]** **로컬 백업/복원 = PR #82**(RestoreService — 백업 JSON→로컬 DB merge[현재 우선] + runInTransaction 원자화, 백업=DataExportService 재사용, share sheet/file_picker, isBackupRestoreEnabled opt-in) · **what's-new 다이얼로그 = PR #83**(WhatsNewService — semver 마이너 이상 트리거[패치 스킵]·로컬 SharedPreferences, WhatsNewDialog, isWhatsNewEnabled opt-in). 둘 다 i18n 8 로케일.
    - **[제외 — 사용자 결정으로 안 함]** ~~pub.dev 발행(외부 소비자)~~ · ~~PR-sync(메인테이너 2인 시)~~.

---

## 5. 수용 기준 (목표 달성 정의)

- **목표 #1**: template-smoke.yml required-green 상태에서 — fresh fork → 루트 3파일 편집 → 명령 3개 → TestFlight + Play internal 빌드 라이브 (활성 작업 60분 내). production은 home 교체 + `./run deploy --target production` → 심사 제출까지 자동.
- **목표 #2**: MODULES.md 규칙 하에 플래그 ~12-15개 / 패키지는 pubspec 1줄+init 1콜로 포함 / 파생 앱은 pinned git dep으로 버전 업그레이드. 파생 앱 1개에서 실증 완료가 증거.
- **fastlane**: 분리 유지, 태그 핀 3종(template_version/cli_ref/fastlane_ref)이 project.yaml에, 레인 계약 CI green.
