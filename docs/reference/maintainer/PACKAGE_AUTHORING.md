# 패키지 작성 가이드

> `app/packages/` 아래 로컬 패키지를 새로 만들거나, 코어 안의 기능을
> 패키지로 추출하는 방법. 경계 규칙·플래그 체계의 운영 기준은
> [MODULES.md](../../MODULES.md), 추출 로드맵 현행본은
> [GOAL_AUDIT_ROADMAP.md](GOAL_AUDIT_ROADMAP.md) §4 항목 19-20입니다.

---

## 0. 한눈에

| 단계 | 명령 / 파일 |
|---|---|
| 1. 분리 여부 판단 | [MODULES.md](../../MODULES.md) §1 경계 원칙 + §3 allowlist 대조 |
| 2. 디렉토리·pubspec 생성 | `app/packages/<name>/{pubspec.yaml, lib/<name>.dart, lib/src/}` |
| 3. 배럴 export + src 계층 | `lib/<name>.dart` ← `lib/src/{models,providers,services,widgets}` |
| 4. 앱에 path 의존 등록 | `app/pubspec.yaml`에 `<name>: { path: packages/<name> }` |
| 5. 코드 생성 | `./build` (app 기준) + 패키지 자체 `build.yaml`(필요 시) |
| 6. 기능 플래그 연결 | 추출 시 `AppFeatureConfig` 플래그 → 패키지 설정으로 이동 |

> **절대 제약 (위반 = 깨진 패키지)**: 서버 코드 0줄, local-only Drift 기본,
> 무료 티어만. Cloud Functions(Blaze) 전제 설계 금지. 자세한 배경은
> [MODULES.md](../../MODULES.md) §1-5.

---

## 1. 언제 패키지로 분리하나

### 1-1. core는 항상 컴파일되는 최소 셸

[MODULES.md](../../MODULES.md) §1의 경계 원칙:

- **core** = 라우팅·테마·설정 상태·부팅 순서 + §3 마이크로 의존성 allowlist만
  직접 의존하는, **무조건 컴파일되는** 최소 셸.
- **무겁거나 선택적인 기능**(광고/알림/수익화/인증/위치/Firebase/AB)은
  **패키지로** 가야 한다.

### 1-2. core 마이크로 의존성 allowlist (5개)

core가 패키지 추출 없이 직접 들 수 있는 **기능성 의존**은 아래 5개 조합뿐이다
([MODULES.md](../../MODULES.md) §3). 이외의 기능 의존은 전부 패키지행이다.

| 기능 | 플래그 | 허용 의존성 |
|---|---|---|
| force_update | `isForceUpdateEnabled` | `package_info_plus`, `url_launcher` |
| network | `isNetworkMonitoringEnabled` | `connectivity_plus` |
| consent | `isPrivacyConsentEnabled` | `app_tracking_transparency` |
| review | `isAppReviewPromptEnabled` | `in_app_review` |
| share | `isShareAppEnabled`(예약) | `share_plus` |

### 1-3. 판단 기준 (요약)

| → 패키지로 | → core에 유지 |
|---|---|
| pub 의존성(네이티브 플러그인 포함) 보유 | allowlist 5개 안에 드는 마이크로 의존 |
| 앱 특화 도메인 / 무거운 스택(ads·IAP·notifications) | 라우팅·테마·설정·부팅 셸 |
| 선택적 기능 (포크마다 on/off) | 모든 포크에 항상 필요 |

> **local-only Drift는 플래그 없이 무조건 생성**된다 ([MODULES.md](../../MODULES.md) §1-4).
> 원격 동기화는 기본 제공하지 않으며(서버 코드 0줄), 데이터 레이어는 패키지화 대상이 아니다.

---

## 2. 패키지 디렉토리 구조

현행 3개 패키지(`utils`, `authentication`, `ab_testing`)가 따르는 구조:

```
app/packages/<name>/
├── pubspec.yaml              # 패키지 매니페스트 (§3)
├── lib/
│   ├── <name>.dart           # 배럴 export — 외부 진입점 (§4)
│   └── src/                  # 구현 (배럴로만 노출)
│       ├── models/           # Freezed 모델 등
│       ├── providers/        # Riverpod 프로바이더 (선택)
│       ├── services/         # 서비스 / 비즈니스 로직
│       └── widgets/          # 위젯 (선택)
├── test/
│   └── <name>_test.dart
└── analysis_options.yaml     # (선택) 패키지별 lint
```

> `src/` 하위 4계층은 **권장 형태**다. `utils`처럼 단순 유틸 모음은
> `src/` 평면(`color_utils.dart`, `logger.dart` …)으로도 충분하고,
> `ab_testing`처럼 모델·서비스·위젯이 있으면 해당 계층을 채운다.
> **공통 규칙: `lib/src/`는 직접 import 금지, 항상 배럴(`lib/<name>.dart`)을 통해 노출한다.**

---

## 3. pubspec.yaml 필수 항목

새 패키지의 매니페스트 템플릿. **freezed/json codegen이 필요한 경우**의
의존성 패턴(현행 `ab_testing` 실측 기준):

```yaml
name: <name>                 # 패키지명 = import 경로 (package:<name>/<name>.dart)
description: <한 줄 설명>
version: 0.0.1               # semver, 로컬 패키지도 명시
publish_to: 'none'          # pub.dev 발행 금지 (로컬 path 패키지)

environment:
  sdk: '>=3.7.0 <4.0.0'     # SDK floor — 신규 패키지는 앱과 맞춰 3.7+ 권장
  flutter: ">=3.0.0"

dependencies:
  flutter:
    sdk: flutter
  # 코드 생성 어노테이션 (런타임 의존)
  freezed_annotation: ^3.1.0
  json_annotation: ^4.9.0
  # 패키지가 실제로 쓰는 것만 추가 (예: Riverpod, shared_preferences …)
  flutter_riverpod: ^3.0.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  # 코드 생성기 (빌드 타임 전용)
  freezed: ^3.2.3
  json_serializable: ^6.8.0
  build_runner: ^2.4.15
```

### 필수 항목 체크리스트

| 항목 | 규칙 |
|---|---|
| `name` | 패키지명 = import 경로. lowercase_with_underscores |
| `version` | semver. 로컬 path 패키지도 `0.0.1`부터 명시 |
| `publish_to: 'none'` | pub.dev 발행 차단. **반드시 명시** |
| `environment.sdk` | SDK floor. 신규는 `'>=3.7.0 <4.0.0'`. `utils`는 `'>=3.4.3 <4.0.0'`(P2-19에서 인상 예정) |
| `dependencies` | 실제 소비하는 것만. codegen 패키지는 `freezed_annotation` + `json_annotation` |
| `dev_dependencies` | codegen 패키지는 `freezed` + `json_serializable` + `build_runner` |

> **codegen이 없는 패키지**(예: `utils` — 순수 함수 모음, `authentication` —
> local_auth 래퍼)는 `freezed`/`json_serializable`/`build_runner` 줄을 넣지 않는다.
> reader 0인 의존성은 만들지 않는다 ([MODULES.md](../../MODULES.md) §1-3 정신).

---

## 4. 배럴 export + src 계층

`lib/<name>.dart`가 **유일한 외부 진입점**이다. 소비자는 항상
`package:<name>/<name>.dart` 한 줄만 import한다.

`utils` 실측:

```dart
library utils;

export 'src/color_utils.dart';
export 'src/date_formatter.dart';
export 'src/logger.dart';
export 'src/text_utils.dart';
export 'src/validation_utils.dart';
```

`ab_testing` 실측:

```dart
// Models
export 'src/models/experiment_assignment.dart';
// Services
export 'src/services/ab_testing_service.dart';
export 'src/services/experiment_provider.dart';
// Widgets
export 'src/widgets/ab_test_wrapper.dart';
```

규칙:
- **공개하고 싶은 심볼만** 배럴에 export. `src/` 내부 헬퍼는 노출하지 않는다.
- 패키지 내부에서도 형제 패키지는 배럴로 참조한다 — 예: `authentication`은
  `import 'package:utils/utils.dart';`로 `logger`를 쓴다 (src 직접 참조 금지).
- Freezed 모델은 `part '<file>.freezed.dart';` / `part '<file>.g.dart';`를
  선언하고, 생성물은 git에 커밋하지 않는다(gitignore — `./build` 산출물).

---

## 5. app/pubspec.yaml에 path 의존 등록

`app/pubspec.yaml`의 `dependencies:`에 한 줄(2줄)로 등록한다. 현행 실측 위치:

```yaml
dependencies:
  # ── Local Packages (Core) ──
  authentication:            # app/pubspec.yaml — path 줄 L17
    path: packages/authentication
  utils:                     # app/pubspec.yaml — path 줄 L19
    path: packages/utils

  # ... (중략) ...

  ab_testing:                # app/pubspec.yaml — path 줄 L136
    path: packages/ab_testing
```

- 경로는 `app/` 기준 상대 경로 `packages/<name>`.
- 등록 후 `cd app && flutter pub get` (또는 `./build`가 자동 실행).
- 패키지 간 의존(예: `authentication` → `utils`)은 **패키지의 pubspec**에서
  `utils: { path: ../utils }`로 선언한다 (`app/pubspec.yaml` 아님).

---

## 6. 코드 생성

`./build`는 **app/ 디렉토리 기준**으로 `build_runner`를 돌린다
(`tools/cli` `build_command.dart` → `dart run build_runner build
--delete-conflicting-outputs`, `workingDirectory: app/`). 이때:

- app 본체의 Freezed/Drift/Riverpod 생성 + `table_generator` 빌더가
  `database.dart`를 동기화한다 (app `build.yaml`의 `boilerplate:table_generator`).
- **path 의존 패키지**는 app의 패키지 그래프에 포함되므로, 그 패키지에
  `freezed`/`json_serializable` 어노테이션이 있으면 같은 실행에서 생성된다.

### 패키지 자체 build.yaml (필요 시)

기본 builder(freezed/json_serializable) 외의 **커스텀 빌더**나, 패키지별
include/exclude 글롭 제어가 필요하면 패키지 루트에 자체 `build.yaml`을 둔다.

- 현재 3개 패키지에는 **자체 `build.yaml`이 없다** — `ab_testing`은 기본
  freezed/json 빌더만 쓰므로 별도 설정이 불필요하다.
- 커스텀 builder의 실제 예시는 `app/build.yaml`과
  `app/lib/data/table_generator/build.yaml`(table_generator 빌더 정의)을 참고.
  table_generator는 P2-20에서 dev 패키지(`tools/table_generator`)로 분리 예정이며
  ([GOAL_AUDIT_ROADMAP.md](GOAL_AUDIT_ROADMAP.md) §4 항목 19), **현재 `app/lib`
  안에 있어 모든 출시 바이너리에 컴파일된다** — 이것이 dev 패키지 분리의 동기다.

> codegen 후 변경된 모델/뷰모델이 있으면 **반드시 `./build` 재실행**.
> 빌드/배포 자동화 맥락은 [FASTLANE_SETUP.md](../../guides/FASTLANE_SETUP.md),
> CLI 명령 전반은 [CLI_TOOLS.md](../../guides/CLI_TOOLS.md) 참조.

---

## 7. 기능 플래그 연결

### 7-1. two-phase 표기 규칙

P2-20 추출 **전까지** 기능은 코어 안에서 동작을 유지하되,
`app_feature_config.dart`의 해당 플래그에 추출 대상 패키지를 표기한다
([MODULES.md](../../MODULES.md) §1-2, §4):

```dart
// 예: ab_testing 추출 전
static bool isABTestingEnabled = false;  // [two-phase → packages/ab_testing]
```

### 7-2. 추출 시 플래그 → 패키지 설정 이동

기능 플래그는 [MODULES.md](../../MODULES.md) §2의 **12개가 전부**(현행 8 + 예약 4).
패키지행 플래그(§4의 19개, two-phase)는 추출 시 **`AppFeatureConfig`에서 빠지고**
해당 패키지의 설정으로 이동한다.

| 향후 패키지 | 이동할 플래그(예) |
|---|---|
| `ab_testing` | `isABTestingEnabled` |
| `authentication` | `isBiometricAuthEnabled`, `isAccountDeletionEnabled` |
| `ads` | `isAdsEnabled`, `isAppOpenAdEnabled`, `isUmpConsentEnabled` … |
| `firebase` | `isFirebaseEnabled`, `isFirebaseAnalyticsEnabled` … |
| `notifications` | `isNotificationEnabled`, `isReEngagementEnabled` … |

전체 매핑은 [MODULES.md](../../MODULES.md) §4 표 참조. 플래그 관리 CLI 운영은
[FEATURE_MANAGEMENT.md](../../guides/FEATURE_MANAGEMENT.md).

> **reader 0인 플래그는 만들지 않는다.** 예약 4개(§2)는 소비자(기능)와 **같은 PR**에서만 추가한다.

---

## 8. ⚠️ 주의 — 서버 의존 금지, ab_testing의 잔재를 베끼지 말 것

### 8-1. 절대 제약 (재강조)

- **서버 코드 0줄** — Cloud Functions(Blaze) 등 유료 전제 설계 금지.
- **local-only Drift 기본** — 원격 DB 동기화 기본 제공 안 함.
- **무료 티어만** — 확정 백엔드 스택은 Firebase Auth(email) + 클라이언트 직접
  계정 삭제 + local-only Drift ([MODULES.md](../../MODULES.md) §5).
- **Supabase는 완전 철거됨**(P1-16.5). 신규 패키지에서 `supabase_flutter` 등
  Supabase 의존을 **절대 추가하지 말 것**. supabase 패키지는 로드맵에서
  **취소**되었다 ([GOAL_AUDIT_ROADMAP.md](GOAL_AUDIT_ROADMAP.md) §4 항목 20:
  "supabase 패키지 취소 — 16.5에서 선철거").

### 8-2. ab_testing 패키지 supabase 잔재 — 정리 완료 (P2-20a-1)

`app/packages/ab_testing`의 `supabase_flutter: ^2.5.9` 의존과
`supabase_experiment_provider.dart`(유일한 supabase 운반자)는
**P2-20a-1에서 제거됐다**. 배럴 export·pubspec 모두 supabase-free.
이제 ab_testing pubspec/배럴 구조를 그대로 본보기로 삼아도 된다.

- 현재 `app/lib`·`app/test`에서 `package:ab_testing` import는 **0건**(미소비).
  P1-14a에서 A/B가 코어의 `ab_test_service.dart`(`ABTestService`)로 단일화됐고,
  `ab_testing` 패키지는 P2-20a-2에서 `ABTestService` 중심으로 **재구축**된다
  (코어 → 패키지 이동 + 죽은 중복 A/B 스토어 정리).
- §8-1의 "신규 패키지에 supabase 의존 절대 추가 금지" 제약은 **계속 유효**하다.

---

## 9. P2-20 추출 순서/대상

[GOAL_AUDIT_ROADMAP.md](GOAL_AUDIT_ROADMAP.md) §4 항목 19-20 확정 순서
(**supabase 제외, 10개**):

```
utils
  → ab_testing (ABTestService 중심 재구축, 중복 A/B 스토어 migration 정리)
  → authentication (진짜 opt-in화 — 현재 path dep으로 항상 컴파일되는 역방향 오류 수리; Firebase Auth 포함)
  → location / notifications / ads / firebase
  → monetization (항목 21 — IAP 서버 검증 이후 하드 게이트)
```

추가로 `tools/table_generator`를 **dev 패키지로 분리**(항목 19) — 현재
`app/lib/data/table_generator/`에 있어 모든 출시 바이너리에 컴파일된다.

추출 전제(항목 19): packages/ 루트 이동 + Dart **pub workspace** 채택 +
`utils` SDK floor 인상 + 파생 앱 1개에서 핀 소비 빌드 증명. 패키지 내용물·흡수
대상 표는 [CAPABILITY_MATRIX.md](CAPABILITY_MATRIX.md) §3(동결 스냅샷)을 참조하되,
**그 표에 남아있는 `supabase` 행은 취소되었으므로 신규 작업에서 계획된 패키지로
간주하지 말 것** (§8 참조).

---

## 관련 문서

- [MODULES.md](../../MODULES.md) — 경계 규칙 + 기능 플래그 12개 체계 (운영 기준)
- [GOAL_AUDIT_ROADMAP.md](GOAL_AUDIT_ROADMAP.md) — P2-20 추출 로드맵 (현행본)
- [CAPABILITY_MATRIX.md](CAPABILITY_MATRIX.md) — 전수 분류 스냅샷 (동결, §3 패키지 내용물)
- [VERSION_POLICY.md](../../guides/VERSION_POLICY.md) — 태그 네임스페이스 / semver / CHANGELOG 규율
- [FEATURE_MANAGEMENT.md](../../guides/FEATURE_MANAGEMENT.md) — 기능 플래그 CLI 운영
- [FASTLANE_SETUP.md](../../guides/FASTLANE_SETUP.md) — 빌드/배포 자동화
- [CLI_TOOLS.md](../../guides/CLI_TOOLS.md) — `./run` CLI 명령 전반
