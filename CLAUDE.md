# Flutter BoilerPlate - LLM Context Guide

> 이 파일은 Claude 및 다른 LLM이 이 프로젝트 기반 앱 개발을 도울 때 참고하는 컨텍스트입니다.

---

## 🚀 새 앱 시작 진입점 (Fork 후 — 필독, 가장 먼저)

> **사용자가 "이 템플릿으로 앱 만들어줘 / 새 앱 개발해줘"라고 하면, 코딩부터 시작하지 말 것.**
> 이 템플릿은 **PRD가 앱 정의의 SSOT**이고, 정전(正典) 순서는 [`docs/quick-start.md`](docs/quick-start.md)다.

**진입 절차 (이 순서를 건너뛰지 말 것):**

1. **`prd.md`를 먼저 연다.** 채워져 있으면 그 값으로 진행. 비어 있으면 **아래 "방향 잡기 스킬
   4단계"로 방향을 끌어낸 뒤 사용자와 함께 채운다** (빈 필수 칸은 합리적 기본값을 제안하고
   확인받은 뒤 기록). PRD 없이 임의로 코딩 시작 금지.
2. 그다음 [`docs/quick-start.md`](docs/quick-start.md)의 **Phase 0→6 순서대로** 진행한다.

```
Phase 0       Phase 1       Phase 2            Phase 3    Phase 4      Phase 5   Phase 6
사전준비   →  PRD 작성   →  설정(yaml 2개)  →  ./init  →  Play 등록  →  개발   →  ./deploy
(도구확인)    (prd.md)      (project/app_config) (자동)     (수동 1회)   (반복)    (자동)
```

### PRD를 채우기 전 — 방향 잡기 스킬 4단계 (필수)

> PRD의 §0(비전)·§12(화면/기능)·§5~9(인증/수익화 *전략*)는 "무엇을 만들지"를 결정하는 **열린
> 영역**이다. 칸을 바로 채우려 들지 말고 아래 스킬로 방향을 끌어낸 뒤 PRD에 받아 적는다.
> 반대로 **기계적 설정 칸**(플랫폼·인증 *방식*·연령등급·서명 등)은 brainstorming 대상이 아니라
> **기본값 제안 → 확인** 한 번으로 끝낸다 (12칸을 일일이 브레인스토밍하지 말 것).

1. **`superpowers:brainstorming`** (필수, 가장 먼저) — 앱 정체·타깃·핵심 가치·차별점·MVP 경계를
   질문으로 끌어낸다. 결과를 `prd.md §0`(한 줄 요약)·`§12`(화면/기능 목록)·전략(§5~9)에 반영.
2. **`/spec`** (선택) — 기능이 복잡해 PRD만으론 부족하면 "모호한 의도 → 5단계 실행 스펙"으로
   §12를 잘게 분해한다.
3. **`/plan-ceo-review`** — 초안 방향이 선 뒤 "이게 10점짜리 제품인가, 범위가 맞나" 전제를
   압박 테스트한다.
4. **`/plan-eng-review` → `superpowers:writing-plans`** — Phase 5 개발 직전, 아키텍처·실행
   계획을 잠근다.

(1·4의 `superpowers:*`는 superpowers 플러그인, 2·3의 `/spec`·`/plan-*`은 gstack 스킬. 정확한
이름은 호출 전 system-reminder의 available-skills 목록에서 대조할 것.)

- PRD 섹션 → 설정 매핑: §1~3·8·9 → `project.yaml`, §4·6·10·11 → `app_config.yaml`, §5~9 결정 → 기능 플래그.
- 세부 실행 8단계는 `prd.md` 부록 "Claude Code 실행 지침" 참조.

---

## 프로젝트 개요

- **아키텍처**: Clean Architecture + MVVM
- **상태관리**: Riverpod 3.0 (수동 Notifier — `@riverpod` 코드 생성 미사용)
- **라우팅**: GoRouter
- **로컬 DB**: Drift (SQLite, local-only 기본) — 서버 인증은 Firebase Auth(email, P1-16.5b 전환 완료), docs/MODULES.md §5 참조
- **코드 생성**: Freezed, JSON Serializable, Drift (Riverpod은 수동 Notifier — 코드 생성 안 함)

---

## 디렉토리 구조

```
app/
├── lib/
│   ├── config/
│   │   ├── app_config.dart           # 앱 설정 (이름, 버전)
│   │   └── app_feature_config.dart   # 기능 플래그 (30+개)
│   │
│   ├── core/
│   │   ├── design/                   # 디자인 시스템 (테마, 색상, 타이포)
│   │   ├── services/                 # 외부 서비스 (Firebase, Ad 등)
│   │   ├── state/                    # 전역 상태 (auth_state.dart, settings.dart)
│   │   ├── utils/                    # 유틸리티
│   │   └── widgets/                  # 공통 위젯
│   │
│   ├── data/
│   │   ├── database/                 # Drift DB 설정
│   │   ├── definitions/              # 테이블 정의
│   │   └── repositories/             # Repository 구현
│   │
│   └── features/                     # 기능별 모듈
│       ├── auth/
│       ├── home/
│       ├── settings/
│       └── [새기능]/
│           ├── models/
│           ├── repositories/
│           ├── view_models/
│           └── views/
│
├── config/env/                       # 생성 산출물 (.env.{debug,profile,release} — ./build가 생성, 손 편집 금지)
└── build.sh                          # 코드 생성 스크립트

fastlane/                             # 빌드/배포 자동화
│   ├── fastfiles/library/            # 재사용 함수 (primitives)
│   └── fastfiles/stage/              # 워크플로우 (orchestration)
│
tools/
├── cli/                              # Dart CLI (init, setup, deploy 등)
│   ├── bin/                          # 실행 스크립트
│   └── lib/
│       ├── commands/                 # 명령어 구현
│       └── core/                     # 공통 모듈 (Fastlane 출력 파서 등)
└── feature_cli/                      # Feature CLI (기능 관리)

scripts/                              # Shell 래퍼 (심볼릭 링크 대상)
app_config.yaml                       # SSOT 설정 파일
```

---

## 핵심 명령어

### 프로젝트 초기화 (Fork 후 최초 1회)
```bash
./init                               # app_config.yaml 기반 이름 변경 + 설정 + 코드 생성
```

### 코드 생성 (모델/DB 변경 후)
```bash
./build                              # Freezed, Drift, JSON Serializable 코드 생성
```

### 배포
```bash
./deploy                             # 원버튼 배포 (preflight → build → upload)
```

### Fastlane (개별 실행)
```bash
cd fastlane
bundle exec fastlane codegen         # 코드 생성
bundle exec fastlane test            # 테스트
bundle exec fastlane bump_version type:patch  # 버전 증가
# 통합 배포는 루트의 ./deploy 사용 (fastlane deploy 레인은 v0.2.0에서 제거)
```

---

## Feature 추가 방법

### 1. Feature CLI 사용 (권장)
```bash
# 기본 구조 생성
./feature generate -n [feature_name]

# 전체 구조 (model, viewmodel, widgets 포함)
./feature generate -n [feature_name] --full

# 선택적 생성
./feature generate -n [feature_name] --with-model --with-viewmodel
```

생성되는 구조:
```
lib/features/[feature_name]/
├── models/[feature_name]_model.dart
├── view_models/[feature_name]_view_model.dart
├── views/[feature_name]_view.dart
└── index.dart
```

### 2. 라우트 등록
`lib/core/router.dart`에 추가:
```dart
GoRoute(
  path: '/[feature_name]',
  builder: (context, state) => const [FeatureName]View(),
),
```

---

## 기능 플래그 시스템

`lib/config/app_feature_config.dart`에서 기능 ON/OFF:

```dart
class AppFeatureConfig {
  // 인증 (static bool — feature CLI가 런타임 토글하므로 const 아님)
  static bool isAuthenticationEnabled = true;
  static bool isBiometricAuthEnabled = true;
  static bool isEmailAuthEnabled = false;

  // 외부 서비스
  static bool isFirebaseEnabled = true;
  static bool isFirebaseAnalyticsEnabled = true;

  // 수익화
  static bool isAdsEnabled = false;
  static bool isSubscriptionEnabled = false;

  // 기능
  static bool isOnboardingEnabled = true;
  static bool isNotificationEnabled = false;
}
```

### Feature CLI
```bash
# 기능 상태 확인
./feature status

# 기능 활성화
./feature enable ads
./feature enable subscription

# 기능 비활성화
./feature disable ads

# 사용 가능한 기능 목록
./feature list
```

---

## 코드 작성 원칙 — ponytail (최소·게으른 해법, 적극 사용)

> **코드를 새로 쓰거나 고칠 때는 기본으로 `ponytail` 스킬을 적용한다.** "동작하는 가장
> 게으른 해법"을 강제해 LOC·토큰·시간을 줄이되, **검증(신뢰 경계)·에러 처리·보안·접근성·
> 데이터 손실 방지는 절대 깎지 않는다.** 작게 쓰는 건 억지 축소가 아니라 딱 필요한 만큼만
> 쓰기 때문이다.

**작성 전 사다리 (가장 먼저 들어맞는 단계에서 멈춘다):**

1. 이게 있을 필요가 있나? → 없으면 건너뛴다 (YAGNI)
2. 이미 이 코드베이스에 있나? → 다시 짜지 말고 **재사용** (공통 위젯 `core/widgets/`,
   `context.colors`/스페이싱 확장, 기존 Repository/Service, `./feature generate` 스캐폴딩)
3. 표준 라이브러리/Dart·Flutter 기본기로 되나? → 쓴다
4. 네이티브 플랫폼/프레임워크 위젯으로 되나? → 새 위젯 만들지 말고 쓴다
5. 이미 깔린 의존성(Riverpod·Drift·Freezed·GoRouter 등)이 푸나? → **새 패키지 추가 전에** 쓴다
6. 한 줄로 되나? → 한 줄
7. 그제서야: 돌아가는 최소한

**규칙:**
- **해법엔 게을러도 읽는 데는 게으르지 말 것.** 변경이 닿는 코드를 읽고 실제 흐름을 따라가
  본 *뒤에* 단계를 고른다 (단계가 이해를 대신하지 않는다).
- 이 프로젝트의 확립된 패턴(Clean Arch + 수동 Notifier + Freezed + 기능 플래그)을 **재발명
  하지 말고 그대로 따른다** — ponytail의 "이미 있는 걸 써라"와 같은 방향.
- 의도적으로 단순화/보류한 지점은 `// ponytail: <이유·상한·업그레이드 경로>` 주석으로 표시
  (나중에 `/ponytail-debt`로 부채 원장에 수집됨).
- 강도: 기본 `full`. 사소·기계적 작업은 `lite`, 과잉설계가 의심되는 큰 작업은 `ultra`.

**점검·정리 스킬 (호출 전 available-skills 목록과 이름 대조):**
- `/ponytail-review` — 변경 diff의 과잉설계(재발명·불필요 의존성·투기적 추상)만 찾아 "지울 것" 제시
- `/ponytail-audit` — repo 전체 과잉설계 스캔 (대청소 시; 과거 PR #87 dead-code 정리가 이 방식)
- `/ponytail-debt` — 코드의 `ponytail:` 주석을 부채 원장으로 수집

---

## 코드 패턴

### ViewModel (수동 Notifier)

> 이 프로젝트는 Riverpod 코드 생성(`@riverpod`)을 쓰지 않는다. 모든 상태는 수동
> `Notifier`/`NotifierProvider`로 작성하며(앱 전역 22곳), `./feature generate`도
> 이 패턴을 생성한다. ViewModel에는 `.g.dart` 파트가 없다.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final [name]ViewModelProvider =
    NotifierProvider<[Name]ViewModel, [StateType]>(
  [Name]ViewModel.new,
);

class [Name]ViewModel extends Notifier<[StateType]> {
  @override
  [StateType] build() {
    return [initialState];
  }

  Future<void> someAction() async {
    state = state.copyWith(isLoading: true);
    // 로직
    state = state.copyWith(isLoading: false);
  }
}
```

### Model (Freezed)
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part '[name]_model.freezed.dart';
part '[name]_model.g.dart';

@freezed
class [Name]Model with _$[Name]Model {
  const factory [Name]Model({
    required String id,
    required String name,
    @Default(false) bool isActive,
  }) = _[Name]Model;

  factory [Name]Model.fromJson(Map<String, dynamic> json) =>
      _$[Name]ModelFromJson(json);
}
```

### Repository
```dart
abstract class [Name]Repository {
  Future<List<[Name]Model>> getAll();
  Future<[Name]Model?> getById(String id);
  Future<void> create([Name]Model item);
  Future<void> update([Name]Model item);
  Future<void> delete(String id);
}
```

### View
```dart
class [Name]View extends ConsumerWidget {
  const [Name]View({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch([name]ViewModelProvider);
    final vm = ref.read([name]ViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('[Name]')),
      body: // UI
    );
  }
}
```

---

## 데이터베이스

### Drift 테이블 추가
`lib/data/definitions/`에 테이블 정의:
```dart
class [Name]Table extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

`./build` 실행 (database.dart 자동 동기화됨)

> 원격 DB(Supabase)는 P1-16.5a에서 철거됨 — local-only Drift가 공식 기본, 서버 인증은 Firebase Auth(email, 16.5b 전환 완료). docs/MODULES.md §5 참조.

---

## 환경 변수

사용자가 직접 편집하는 설정 파일은 루트의 **3개뿐**:

| 파일 | 역할 | git |
|------|------|-----|
| `project.yaml` | 앱 정체성 (이름, package, 스토어, AdMob 앱 ID + `admob.units` 유닛 ID, IAP) | 추적 |
| `app_config.yaml` | 공통 인프라 (플랫폼, 서비스, 수익화 토글, 서명) | 추적 |
| `.env` | 진짜 시크릿 전용 (fastlane/CLI만 소비, **앱 번들 포함 금지**) | 무시 |

`app/config/env/.env.{debug,profile,release}`는 `./build` · `./run gen-env` · `./init`이 생성하는 **산출물** (손 편집 금지, gitignore):
- debug/profile: Google 공식 테스트 광고 ID 자동 주입
- release: `project.yaml admob.units`의 실값 — 비어 있거나 테스트 ID면 preflight가 release를 차단

---

## 주요 서비스

| 서비스 | 파일 | 용도 |
|--------|------|------|
| FirebaseService | `core/services/firebase_service.dart` | Analytics, Crashlytics |
| AdService | `core/services/ad/ad_service.dart` | 광고 (Banner, Interstitial) |
| NotificationService | `core/services/notification/notification_service.dart` | 로컬/푸시 알림 |
| InAppPurchaseService | `core/services/in_app_purchase_service.dart` | 구독, IAP |
| ABTestService | `core/services/ab_test_service.dart` | A/B 할당 + RC 킬스위치 (단일 A/B 경로 — P1-14a) |

---

## 자주 하는 작업

> 아래 모든 작업은 **`./build`에서 끝나지 않는다** — 테스트를 쓰고(또는 생성된 테스트를 채우고)
> **`./preflight --mode feature`가 초록**일 때 완료다("테스트 주도 개발 루프" 섹션).

### 새 화면 추가
1. Feature Generator로 생성
2. router.dart에 라우트 추가
3. `./build` 실행

### 새 모델 추가
1. `features/[name]/models/`에 Freezed 모델 생성
2. `./build` 실행

### DB 테이블 추가
1. `data/definitions/`에 테이블 정의
2. `./build` 실행 (자동으로 database.dart 동기화)
3. Repository 구현

### 외부 서비스 연동
1. `app_feature_config.dart`에서 플래그 활성화
2. `app_config.yaml`에 서비스 설정 추가 (예: `services.firebase`) 후 `./build`
3. 해당 서비스 초기화 확인

### 광고 추가
1. `AppFeatureConfig.isAdsEnabled = true`
2. `project.yaml`의 `admob.units`에 실제 광고 단위 ID 입력 후 `./build` (debug/profile은 테스트 ID 자동)
3. `AdBannerWidget` 또는 `AdService.showInterstitialAd()` 사용

### A/B 실험 추가
1. `core/services/ab_test_service.dart`의 `Experiment` enum에 항목 추가 (SSOT — `remoteKey`가 Remote Config 킬스위치 키)
2. 화면에 `abTestService.isEnabled(Experiment.xxx)` 분기 + `abTestService.logExposure(...)` 호출
3. `fastlane/config/ga4_custom_definitions.yml`에 `ab_xxx` user property 추가
4. `cd fastlane && bundle exec fastlane rc_set key:<remoteKey> value:true && bundle exec fastlane ga4_setup`
5. 자세한 절차: [docs/AB_TEST_LIFECYCLE.md](docs/AB_TEST_LIFECYCLE.md)

---

## 테스트 주도 개발 루프 (Phase 5 — 단단한 루프)

> 기능을 만들 때는 **테스트로 확인하며** 진행하고, **게이트가 초록일 때까지 루프를
> 탈출하지 않는다.** 게이트 한 줄: **`./preflight --mode feature`**
> (= flutter analyze + flutter test + 테스트 무결성[no-skip] + 전역 커버리지[정보]
> + **변경 기능 커버리지 ≥80%**, 하나라도 FAIL이면 exit≠0).

**기능 단위 루프 (초록까지 반복):**

```
worktree 격리 (superpowers:using-git-worktrees)
  └ 반복:
     RED      로직(ViewModel/Repository/Service)은 실패 테스트 먼저
              (superpowers:test-driven-development) — ./test --watch로 빨강 확인
     GREEN    최소 코드 (ponytail 사다리)
     REFACTOR 초록 유지하며 정리
     GATE     ./preflight --mode feature   ← 초록 아니면 RED로 복귀. 탈출 금지.
  완료 주장 전: superpowers:verification-before-completion (게이트 fresh 출력이 증거)
```

- **로직=엄격 TDD / UI=실용**: ViewModel·Repository·Service 로직은 실패 테스트 먼저.
  순수 UI 위젯은 "완료 전 테스트 필수"로 완화.
- **`./feature generate`는 테스트와 함께 기능을 만든다**(born-tested): `--full`(또는 `--with-test`)이면
  **요청한 컴포넌트마다** 테스트를 생성 — model/viewmodel/view/repository(정상/로딩/에러 분기까지).
  `--no-test`로 끔. **스캐폴드 그대로의 `--full` 기능은** 변경-기능 80% 게이트를 통과한다(repository
  테스트는 `--full`처럼 model이 함께일 때만 생성되므로, 부분 조합은 80% 보장 대상 아님).
  생성된 `// ponytail: TODO`를 채우며 확장.
- **테스트 중성화 금지**: `skip:`/`markTestSkipped`/트리비얼 `expect(true, isTrue)`는 게이트가 FAIL.
  플랫폼 게이트 등 정당한 skip은 그 줄에 `// preflight:allow-skip` 마커로 허용.
- **변경 기능 자동 감지**: 게이트는 `git diff`(작업트리+스테이지)로 바뀐 `lib/features/<F>/`를 잡아
  80%를 요구한다. **감지된 기능이 없으면 게이트는 통과(permissive)** — 따라서 미추적(새 생성) 기능은
  반드시 `git add` 후 잡히게 하거나 `./preflight --mode feature --feature <F>`로 명시해야 실제 게이트된다.

**Definition of Done (완료의 정의):**
> 기능은 `./preflight --mode feature`가 **fresh 출력에서 exit 0**일 때만(verification-before-completion),
> 그리고 아래 워크플로우의 2종 리뷰(하나는 테스트가 엣지·에러를 덮는지 확인) 후
> `superpowers:finishing-a-development-branch`로만 머지될 때 "완료"다.

---

## 개발 워크플로우 (작업 분리 · PR · 에이전트 리뷰)

> Phase 5(개발 반복)에서 코드를 만들 때 따르는 절차. main 직접 푸시 금지.

1. **작업은 나눠서, git worktree로 분리한다.** 독립적인 기능·작업은 각각 별도 worktree에서
   격리해 개발한다 (`superpowers:using-git-worktrees` 스킬, 또는 Agent 툴 `isolation: "worktree"`).
   서로 충돌 없이 병렬 진행하고, 작업은 **브랜치 → PR → 머지**로만 본선에 들어간다.
2. **PR 전 게이트**: `./preflight --mode feature`가 **초록**이어야 PR을 연다(위 "테스트 주도 개발 루프").
3. **PR 리뷰는 구현자가 아닌 다른 에이전트가 한다.** 자기 PR 셀프 승인 금지. 머지 전 별도
   에이전트(Agent 툴)로 **2종 리뷰를 각 1회** 돌린다:
   - **`/ponytail-review` 1회** — 과잉설계·재발명·불필요 의존성 (지울 것)
   - **`/code-review` 1회** — 정확성 버그·로직 결함
   - 둘 중 **하나는 테스트 품질**도 본다: "테스트가 엣지·에러 케이스를 덮나, happy-path뿐인가,
     스킵·트리비얼 단언은 없나" (세 번째 에이전트 추가 아님).
   두 리뷰의 지적을 반영(또는 근거 있게 기각)한 뒤에 머지한다.
4. **머지는 `superpowers:finishing-a-development-branch`로** — 테스트 통과를 머지 게이트로 강제.

---

## 주의사항

1. **테스트 없는 기능 금지**: 로직은 실패 테스트 먼저(엄격 TDD), UI는 완료 전 테스트.
   `./feature generate`가 만든 테스트(특히 `// ponytail: TODO`)를 채우고, 완료는
   `./preflight --mode feature` 초록으로 확인("테스트 주도 개발 루프" 섹션).
2. **코드 생성 필수**: 모델, ViewModel 변경 후 반드시 `./build` 실행
3. **import 경로**: 패키지명으로 import (예: `package:myapp/...`)
4. **기능 플래그**: 새 기능은 플래그로 제어 가능하게 설계
5. **Riverpod**: `ref.watch`는 build에서, `ref.read`는 콜백에서 사용
6. **Freezed**: `copyWith` 사용, 직접 속성 수정 불가 (immutable)

---

## 문서 참조

- [prd.md](prd.md) - PRD 템플릿 (앱 정의 SSOT — fork 후 채워서 Claude가 소비)
- [quick-start.md](docs/quick-start.md) - 정전 가이드 (PRD → 배포 전 과정 순서)
- [01-GETTING_STARTED.md](docs/01-GETTING_STARTED.md) - 상세 온보딩
- [MODULES.md](docs/MODULES.md) - 모듈 경계 규칙 + 기능 플래그 체계 (운영 기준)
- [FEATURE_MANAGEMENT.md](docs/guides/FEATURE_MANAGEMENT.md) - 기능 추가/제거
- [EXTERNAL_SETUP.md](docs/guides/EXTERNAL_SETUP.md) - 외부 서비스 설정
- [FASTLANE_SETUP.md](docs/guides/FASTLANE_SETUP.md) - 빌드/배포 자동화
- [FASTLANE_REPO.md](docs/reference/maintainer/FASTLANE_REPO.md) - Fastlane 별도 repo 관계 (핀/클론/레인 계약) · 템플릿 유지보수
- [PACKAGE_AUTHORING.md](docs/reference/maintainer/PACKAGE_AUTHORING.md) - 패키지 작성/추출 가이드 · 템플릿 유지보수
- [DERIVED_APP_UPDATES.md](docs/reference/maintainer/DERIVED_APP_UPDATES.md) - 파생 앱에 템플릿 변경 전파 · 템플릿 유지보수
- [AB_TEST_GUIDE.md](docs/AB_TEST_GUIDE.md) - A/B 테스트 운영 (fastlane, RC, GA4)
- [AB_TEST_LIFECYCLE.md](docs/AB_TEST_LIFECYCLE.md) - A/B 6단계 라이프사이클

Serena Usage (MANDATORY)
Always use serena MCP tools:
find_symbol: Locate classes, functions, variables
get_symbols_overview: Understand file structure
find_referencing_symbols: Check dependencies before changes
insert_after_symbol / insert_before_symbol: For code insertion
replace_symbol: For refactoring
Never use grep/ripgrep when serena can do semantic search.
Never read entire files - use serena to get relevant symbols only.

---

## gstack

Use the `/browse` skill from gstack for all web browsing. Never use `mcp__claude-in-chrome__*` tools.

### Available Skills

| Skill | Purpose |
|-------|---------|
| `/plan-ceo-review` | CEO/founder-mode plan review |
| `/plan-eng-review` | Eng manager-mode plan review |
| `/review` | Pre-landing PR review |
| `/ship` | Ship workflow (merge, test, bump, PR) |
| `/browse` | Headless browser for QA and browsing |
| `/qa` | QA test + auto-fix loop |
| `/setup-browser-cookies` | Import cookies for authenticated testing |
| `/retro` | Weekly engineering retrospective |
| `/document-release` | Post-ship documentation update |

### Troubleshooting

If gstack skills aren't working, rebuild and re-register:
```bash
cd .claude/skills/gstack && ./setup
```