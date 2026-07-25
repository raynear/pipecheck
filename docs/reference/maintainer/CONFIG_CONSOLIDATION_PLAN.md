# 설정 파일 루트 통합 설계 (project.yaml / app_config.yaml / .env)

> 2026-06-11 작성. 멀티에이전트 감사(5 리더) + 경쟁 설계 2안(A: dotenv 산출물 / B: dart-define) + 적대적 비평을 거친 최종안.
> **평결: 하이브리드 — A 아키텍처 기반 + B의 핵심 5개 도입 + A 자체 결함 3개 수정. B(dart-define 전환)는 Phase 2(선택)로 보류.**

---

## 0. 목표

사용자가 손으로 편집하는 설정 파일은 루트의 **정확히 3개**:

| 파일 | 역할 | git |
|------|------|-----|
| `project.yaml` | 앱마다 다른 값 (이름, package, 스토어, **AdMob 앱 ID + 유닛 ID**, IAP) | 추적 |
| `app_config.yaml` | 프로젝트 공통 인프라 (플랫폼, 서비스, Supabase, 수익화 토글, 스토어 계정, 서명) | 추적 |
| `.env` | 진짜 시크릿만 (fastlane/CLI 전용 소비, **절대 앱 번들에 안 들어감**) | 무시 |

`app/config/env/.env.{debug,profile,release}` = **순수 생성 산출물**. 손 편집 금지, gitignore, 매 `./build`마다 재생성.

---

## 1. 이 repo에서 검증된 현재 버그 (전부 file:line 확인됨)

### 원래 3대 버그 (클론 감사 주장 → 본 repo에서 확인)
1. **init이 AD_ID 소실**: `generate_env_step.dart:36-39` 무조건 덮어쓰기 + `generateEnvDebug()`(`config_loader.dart:264-296`)는 AdMob 키를 한 줄도 안 씀.
2. **release = debug 복사본**: `generate_env_step.dart:37-39` — 헤더 주석만 치환. debug Supabase/IAP 값이 release에 그대로.
3. **AdMob 유닛 ID 거처 없음**: `project.yaml admob:`(57-58행)은 앱 ID 2칸뿐. 유닛 ID는 어떤 루트 파일에도 없음.

### 추가 발견 (이번 감사에서 새로)
- `.env.profile`: 앱이 로드(`app_config.dart:91`)하고 asset 선언(`pubspec.yaml:202`)인데 **어떤 생성기도 안 만듦** → fresh clone에서 profile 빌드 깨짐.
- **생성기 2개 공존**: `generate_env_step.dart`(현역) vs `setup_command.dart _setupEnvironmentFiles`(~271-400행, 레거시). setup 쪽은 죽은 키 스키마(`ADMOB_BANNER_ID` 등) — 런타임은 `{IOS|AOS}_*_AD_ID`(`ad_service.dart:57-61`)를 읽으므로 setup 산출물은 광고에 무효.
- **preflight 유령 검사**: `preflight_command.dart:233`이 root `.env`에 `APP_ID=`/`APP_NAME=` 요구 — 생성기는 그 키를 안 씀 → fresh init은 항상 preflight 실패. (참고: 이 repo의 preflight엔 클론에 있다던 AdMob 테스트 ID 검사 자체가 없음.)
- **실제 퍼블리셔 AdMob 앱 ID가 템플릿에 하드코딩 커밋됨**: `AndroidManifest.xml:43-45`, `Info.plist:43-44` (`ca-app-pub-3979736693761378~*`).
- `.gitignore:56-61` unanchored 패턴 → repo 어디서든 `.env.debug` 등이 그림자 ignore.
- **3개 env 파일 전부 모든 빌드에 번들** (`pubspec.yaml:201-203`) → release IPA/AAB 안에 debug 키 평문 동봉.
- dotenv race: `app_config.dart:46-57` `Future.wait`에서 `_loadEnvFile`과 `_initializeServices` 병렬 → Supabase가 비결정적으로 초기화 실패 가능. `banner_ad_manager.dart:43`은 try 밖에서 dotenv 접근.
- 죽은 것들: fastlane `switch_env` lane(`project_management.rb:121-127`), CI의 `app/.env` 기록(`ci.yml:29`, `qa-gate.yml:40` — 아무도 안 읽음), 고아 키(`API_URL`/`API_KEY`/`SUBSCRIPTION_EXPIRY_DATE`/`CONTAINER_ID` 일부), `.example` 파일의 flowmodoro 식별자 누출 + `a-app-pub-` 오타.
- 루트 `./init ./build ./deploy ./feature` 심볼릭 링크 부재 — `./run`만 존재 (문서와 불일치).

---

## 2. 최종 설계

### 2.1 스키마 변경

**project.yaml** — `admob:` 확장:
```yaml
admob:
  ios_app_id: ""        # ca-app-pub-xxx~yyy → init이 Info.plist에 주입
  android_app_id: ""    # ca-app-pub-xxx~yyy → init이 AndroidManifest에 주입
  units:                # RELEASE 빌드용 실제 광고 단위 ID (시크릿 아님 — 번들에 포함됨)
    ios:      { banner: "", interstitial: "", rewarded: "", rewarded_interstitial: "", native: "", app_open: "" }
    android:  { banner: "", interstitial: "", rewarded: "", rewarded_interstitial: "", native: "", app_open: "" }
```
- debug/profile 빌드 = Google 공식 테스트 ID 자동 (yaml에 안 적음, 생성기 상수).
- 비워두면 release를 preflight가 차단.

**app_config.yaml** — Supabase debug 분리 (B에서 도입 #1 — 이것 없으면 버그 2가 Supabase 축에서 영구 미해결):
```yaml
services:
  supabase:
    enabled: false
    url: ""              # release 값
    anon_key: ""
    debug:               # 선택 — 없으면 url/anon_key로 폴백
      url: ""
      anon_key: ""
```

**.env** — 변경 없음 (시크릿 + fastlane 자동 기록 섹션). 단 `.env.example` 헤더에 머신 기록 키 예시 추가해 구조 드리프트 종료.

### 2.2 생성 파이프라인 (단일 작성기)

- **신규 `tools/cli/lib/core/env_artifacts.dart`**: 유일한 산출물 작성기.
  - Google 테스트 유닛 ID 상수 맵 (iOS/Android × 6종).
  - `writeRuntimeEnvArtifacts()`: 모드별 **독립** 생성 ×3 (debug/profile = 테스트 ID, release = `admob.units` 값 그대로). `.env.profile` 최초로 정식 생성.
  - 헤더: `AUTO-GENERATED — DO NOT EDIT / Source: project.yaml + app_config.yaml / mode + source-hash(sha256 12자)`. 타임스탬프 없음 → 결정적 출력, 해시로 staleness 감지.
  - **시크릿 누출 게이트**: 산출물 **값**이 root `.env`의 알려진 진짜 시크릿 키(KEYSTORE_PASSWORD/KEY_PASSWORD/MATCH_PASSWORD/GITHUB_TOKEN/DEEPL_API_KEY/OPENAI_API_KEY/GOOGLE_CLOUD_AUTH_TOKEN) 값과 일치하면 FAIL. 키 **이름** 중복은 WARN만 (이름 교집합 FAIL은 오탐 제조기 — 비평가 지적 수용).
- **신규 `tools/cli/bin/gen_env.dart`**: CI/fastlane용 entrypoint. `./run gen-env` 케이스 추가.
- `./build` 첫 단계에서 항상 재생성 (stale 원천 차단). `app_config.yaml` 없으면: 최소 산출물(패키지명+테스트 ID) 생성 또는 **명시적 실패** — 조용히 성공하면서 asset 구멍 남기는 분기 금지 (A 결함 수정 b).
- `setup_command.dart` 레거시 생성기(_setupEnvironmentFiles/_createEnvFile/하드코딩 템플릿) **전부 삭제**.
- **신규 init 단계 `inject_admob_app_id_step`** (B에서 도입 #2): `project.yaml admob.{ios,android}_app_id` → `Info.plist GADApplicationIdentifier` / `AndroidManifest APPLICATION_ID` 멱등 주입. 커밋된 실제 퍼블리셔 ID는 플레이스홀더로 교체.
- **일회성 마이그레이션 도우미** (B에서 도입 #3): `generate_env_step`에서 기존 `.env.release`가 있고 `admob.units`가 전부 빈 값이면, 기존 `IOS_/AOS_*_AD_ID` 값을 파싱해 붙여넣기용 `admob.units` YAML 블록을 출력 — 4개 파생 앱의 값 소실 창 제거.

### 2.3 가드 (preflight/deploy)

- `preflight_command.dart`:
  - 유령 `APP_ID=/APP_NAME=` 검사 삭제 → KEYSTORE_PASSWORD/KEY_PASSWORD 빈 값 WARN으로 대체.
  - 신규 `_checkRuntimeEnvArtifacts`: ① 3개 산출물 존재 ② source-hash 신선도 ③ **release 광고 게이트**: ads enabled인데 release 산출물의 유닛 ID가 비었거나 Google 테스트 ID(`ca-app-pub-3940256099942544`)면 FAIL ④ 시크릿 값 누출 검사.
- `deploy_command.dart` `_preflight`: 산출물 stale이면 경고 대신 **자동 재생성** (결정적이므로 안전).

### 2.4 정리 (죽은 코드/파일)

- `git rm` `.env.{debug,profile,release}.example` 3개 → `app/config/env/README.md` 5줄 포인터로 대체.
- fastlane repo(별도, https://github.com/raynear/flutter-fastlane.git) PR: `project_setup.rb:97-113` example 복사 제거(→ gen_env 호출 or 존재 검증), `project_management.rb:121-127` `switch_env` 삭제 (B에서 도입 #4).
- CI 3개 워크플로우: `ENV_DEBUG/ENV_PROFILE/ENV_RELEASE` secret echo 단계 + `app/.env` 기록 삭제 → `dart run tools/cli/bin/gen_env.dart` 단계로 대체. 전부 green 확인 **후** GitHub secrets 삭제.
- `.gitignore` anchored로 교체: `/.env`, `/.env.backup`, `/app/config/env/.env.debug` 등.
- `config_loader.dart`: `generateEnvDebug()` 삭제, `admob.units` getter 추가, root `.env` 생성은 allowlist 재발행 → **merge-preserve**로 (사용자 추가 키 보존).

### 2.5 명시할 정책 변화

- **[사용자 확정 2026-06-11]** Supabase URL/anon key는 git 추적 `app_config.yaml`에 커밋 (4개 파생 앱 영향). anon key는 공개 설계값이지만 repo-privacy posture 변화이므로 문서에 명시 + service_role JWT 휴리스틱 WARN 추가 (실수로 service_role 키 넣으면 차단).
- 산출물 3개가 여전히 모든 빌드에 번들됨 (dotenv 유지 한계) — debug Supabase 분리값이 release 바이너리에 동봉되는 점은 Phase 2에서 해소.

### 2.6 문서 8곳 갱신

`CLAUDE.md`(환경 변수/광고 추가/외부 서비스 섹션 — 유령 키 제거), `docs/02-SPRINT-CHECKLIST.md`, `docs/guides/EXTERNAL_SETUP.md`, `docs/guides/FEATURE_MANAGEMENT.md`, `docs/01-GETTING_STARTED.md`, `docs/project-overview.md`, `docs/technology-stack.md`, `docs/reference/technical/setup.md`(현존하지 않는 dart-define 구조 기술 중 — "Phase 2" 라벨로 전환), `.env.example`.

---

## 3. 마이그레이션 순서 (순서 중요 — 시퀀싱 사고 방지)

1. **(파생 앱별, CLI 업그레이드 전)** `.env.release`의 실제 유닛 ID 12개 → `project.yaml admob.units` 포팅 (2.2의 도우미가 YAML 블록 출력).
2. CLI 코어: `env_artifacts.dart` + `gen_env.dart` 생성, `config_loader.dart` 수정 + **단위 테스트** (debug=테스트ID/release=실ID/release≠debug/3파일 생성/supabase 조건부/시크릿 게이트).
3. 호출부 배선: `generate_env_step` / `build_command` / `setup_command`(삭제) / `preflight` / `deploy` / `run`.
4. `project.yaml` 스키마 + `.gitignore` anchored. 검증: `git check-ignore -v` 전체 통과.
5. `.example` 3개 git rm + README.md 생성.
6. **E2E 포크 시뮬레이션**: /tmp fresh clone → init → `flutter build apk --debug` exit 0 + debug 산출물에 테스트 ID 확인.
7. **데이터 소실 회귀 테스트**: 산출물 손 편집 → `./build` → 재생성 확인(산출물은 사용자 데이터 아님이 정상), root `.env` 사용자 키는 보존 확인.
8. fastlane repo PR (별도 클론 주의 — `scripts/provision`이 가져감).
9. CI 컷오버: 워크플로우 3개 수정 → 각 1회 green → **그 후** GitHub secrets(`ENV_DEBUG/ENV_PROFILE/ENV_RELEASE/APP_DOTENV`) 삭제.
10. 문서 스윕 (2.6).
11. 파생 앱 전파: `scripts/sync-to-apps` 파일 목록에 `tools/cli` + `.github/workflows` 포함 여부 **9단계 전에 먼저 검증**, `check-drift` 실행, 각 앱 `./build` + preflight green 확인.

**스코프**: ~2-3일. tools/cli 8개 파일(+신규 2) / app/lib 변경 **1** (`app_config.dart` race 수정만 — 런타임 키 계약은 동일: 같은 경로, 같은 키) / 워크플로우 3 / fastlane PR 1 / 문서 9.

---

## 4. Phase 2 (선택, 보류): dart-define-from-file 전환

산출물 파이프라인이 4개 포크에서 릴리즈 1회 이상 검증된 후 앱별로:
- flutter_dotenv 제거, `AppConfig` → const `String.fromEnvironment`, 번들에서 env 파일 완전 제거 (시크릿/설정이 asset 평문으로 안 들어감).
- 차단 요인 (보류 사유): iOS fastlane이 gym 직빌드(`ios.rb:67-106`) → `--config-only` 사이드채널 필요, 버전 스큐 시 **사용자 첫 실행에서 깨짐**(fail-at-launch), bare `flutter run` 깨짐(IDE 사용자), `AppConfig.getValue<T>`/동적 키 조합(`'${prefix}_${adType}_AD_ID'`) 등 API 호환성 파괴, 3개 repo + 4개 포크 동시 갱신 필요.
- **[사용자 확정 2026-06-11]** dotenv race는 Phase 1에 포함: `app_config.dart:46-57`의 `Future.wait` → env 로드 완료 후 서비스 초기화 순차 실행으로 수정 (app/lib 유일한 변경). try-밖 dotenv 접근(`banner_ad_manager.dart:43`)은 별도 이슈로 기록, Phase 2에서 자연 해소.
