# Fastlane Repo 관계

> fastlane 설정이 **별도 repo**(`raynear/flutter-fastlane`)에 있는 이유와,
> 템플릿이 그 repo를 **git submodule**로 어떻게 핀·확보·검증하며 계약하는지 설명합니다.

---

## 이 문서의 범위

이 문서는 **관계와 메커니즘**을 다룹니다 — 왜 분리했고, 어떻게 핀이 걸리고,
무엇이 계약을 검증하는지. 인증서·키스토어·Match 같은 **환경 구축 절차**는
[FASTLANE_SETUP.md](../../guides/FASTLANE_SETUP.md)를 보세요.

| 문서 | 다루는 것 |
|------|-----------|
| **이 문서** (FASTLANE_REPO.md) | 2-repo 구조, 핀 메커니즘, 자동 클론, 핀 검증, 레인 계약, 핀 범프 절차 |
| [FASTLANE_SETUP.md](../../guides/FASTLANE_SETUP.md) | 도구 설치, 인증서/키스토어 발급, Gemfile/Matchfile 설정, 레인 사용법 |

---

## 1. 2-repo 아키텍처 개요

이 템플릿의 fastlane 설정은 **별도 GitHub repo** `raynear/flutter-fastlane`에 있고,
템플릿은 그것을 **git submodule**(`.gitmodules`, 경로 `fastlane/`)로 핀해서 씁니다.
핀은 submodule gitlink가 보유하며, `project.yaml`의 `fastlane_ref`는 CI 체크아웃과
clone 폴백(submodule 미초기화 / 복사 기반 파생 앱)에서 쓰입니다.

```
┌─────────────────────────────┐        ┌──────────────────────────────┐
│ raynear/boiler_plate        │  핀    │ raynear/flutter-fastlane      │
│ (이 템플릿)                  │ ─────▶ │ (fastlane 설정 — 별도 repo)   │
│                             │ v0.2.5 │                              │
│ project.yaml                │        │ Fastfile / fastfiles/        │
│   tooling.fastlane_ref      │        │ library/  stage/  VERSION     │
│ tools/cli (호출부)          │        │                              │
│ scripts/check_lane_contract │        │ (태그 v0.2.x = 배포 가능 핀)  │
│ .gitmodules: fastlane       │        │                              │
└─────────────────────────────┘        └──────────────────────────────┘
         │ git submodule update --init  (clone 폴백: --branch v0.2.5 --depth 1)
         ▼
   fastlane/  (submodule — gitlink로 v0.2.5 커밋에 핀)
```

### 왜 분리했나 (P0-6)

- **템플릿 히스토리 분리** — 배포 자동화는 인증서 갱신·스토어 API 변경 때문에
  앱 코드와 다른 주기로 바쁘게 바뀝니다. 한 repo에 섞으면 템플릿 커밋 로그가
  fastlane 잡음으로 오염됩니다. 분리하면 각자 깨끗한 히스토리를 갖습니다.
- **여러 앱이 공유** — 파생 앱(`kanken` / `hanja` / `snapdic` / `flowmodoro`)이
  같은 fastlane repo를 같은 태그로 공유합니다. 배포 로직을 한 곳에서 고치고
  핀만 올리면 전 앱이 같은 동작을 얻습니다. 복붙 드리프트가 없습니다.
- **gitignore로 추적 제외** — `.gitignore`의 `/fastlane` 한 줄로 로컬 클론을
  추적에서 뺍니다. 그래서 `git ls-files fastlane/`는 **0건**입니다. fresh clone에는
  `fastlane/`가 아예 없고, 첫 배포성 명령 때 자동으로 채워집니다.

> 참고: GitHub Actions는 이 프로젝트에서 **영구 미사용**입니다(빌링). 검증·배포는
> 전부 로컬에서 돕니다. `.github/workflows/`의 파일들은 트리에 남아있으나 실행되지
> 않으므로, "CI가 fastlane을 클론/검증/배포한다"는 서술은 사실이 아닙니다.

---

## 2. 핀 메커니즘

fastlane repo는 **`project.yaml`의 `tooling.fastlane_ref` 태그 핀**으로 고정됩니다.

```yaml
# project.yaml
tooling:
  fastlane_ref: "v0.2.5"          # ← fastlane repo 태그 핀
  cli_ref: "cli-v1.0.0"           # tools/cli 핀 (파생 앱 CLI 활성화용)
  template_version: "template-v1.0.0"  # 템플릿 릴리즈 — template.lock에 기록
```

세 핀은 서로 다른 네임스페이스를 씁니다(태그 규약 SSOT는 루트
[CHANGELOG.md](../../../CHANGELOG.md) 릴리즈 규칙 절):

| 핀 | 네임스페이스 | 가리키는 곳 | 용도 |
|----|--------------|-------------|------|
| `tooling.fastlane_ref` | `v*` | `raynear/flutter-fastlane` 태그 | fastlane 클론 ref |
| `tooling.cli_ref` | `cli-v*` | `boiler_plate` tools/cli | 파생 앱 CLI 활성화 |
| `tooling.template_version` | `template-v*` | `boiler_plate` 템플릿 릴리즈 | `template.lock` 기록 |

### URL 오버라이드 — `FASTLANE_REPO`

클론 URL은 환경변수 `FASTLANE_REPO`로 갈아끼울 수 있습니다. 기본값은
`https://github.com/raynear/flutter-fastlane.git`입니다.

```bash
# 포크된 fastlane repo로 테스트
FASTLANE_REPO=https://github.com/me/my-fastlane.git ./deploy --dry-run
```

핀 ref 자체(`v0.2.5`)는 오버라이드 변수가 없습니다 — `project.yaml`을 바꿔야
합니다. URL만 바뀌고 ref는 동일하게 적용됩니다.

---

## 3. 자동 클론 흐름

`fastlane/`가 없으면 **fastlane을 필요로 하는 명령**을 처음 실행할 때 핀 ref로
자동 클론됩니다. 구현은 `tools/cli/lib/core/bootstrap.dart`의
`ensureFastlane(projectRoot)`입니다.

```
./deploy 실행
   │
   ▼
bp.dart: name이 fastlaneRequiringCommands에 있나?
   │  (deploy / setup / screenshot / generate-desc / iap-register)
   ▼ 예
ensureFastlane(projectRoot)
   │
   ├─ fastlane/ 있음 → 그대로 사용 (재클론 안 함)
   │
   └─ fastlane/ 없음
        ├─ readFastlaneRef(): project.yaml에서 fastlane_ref 파싱 (없으면 'main')
        ├─ repo = $FASTLANE_REPO ?? 기본 URL
        └─ git clone --branch <ref> --depth 1 <repo> fastlane
             └─ 실패 시: 프라이빗 repo 권한 / FASTLANE_REPO 안내 후 exit 1
```

핵심 사실:

- **트리거는 5개 명령만** — `cli_registry.dart`의 `fastlaneRequiringCommands`
  집합: `deploy`, `setup`, `screenshot`, `generate-desc`, `iap-register`.
  `build`나 `feature` 같은 순수 로컬 명령은 fastlane을 클론하지 않습니다.
- **fresh clone엔 `fastlane/`가 없다** — 정상입니다. 첫 배포성 명령이 채웁니다.
- **`readFastlaneRef`는 보수적 파싱** — `ConfigLoader` 전체 로드 없이 핀 한 줄만
  정규식으로 뽑습니다. 콜론 뒤 공백은 `[ \t]`만 허용해서, 값이 비었을 때 다음 줄
  토큰을 오캡처하지 않습니다(P1-10 리뷰 발견).
- **`--depth 1` 얕은 클론** — 핀 태그 시점의 스냅샷만 받습니다.

> `scripts/provision`(새 앱 프로비저닝)도 동일하게 핀을 따릅니다 — `project.yaml`의
> `tooling.fastlane_ref`를 읽어 그 태그에 detached로 클론합니다(더 이상 `main`을
> 하드코딩하지 않음). 핀을 못 찾으면 경고 후 `main`으로 폴백합니다. 이전에 `main`에
> attached로 남은 로컬 `fastlane/`는 다음으로 핀 태그에 고정하세요(얕은 클론이라
> `fetch --tags` 먼저 필요):
>
> ```bash
> git -C fastlane fetch --tags && git -C fastlane checkout v0.2.5
> ```

---

## 4. 핀 검증 게이트 (preflight 'Fastlane 핀')

`./preflight`(그리고 `./deploy`의 1단계)는 로컬 `fastlane/` 클론이
`project.yaml` 핀과 일치하는지 검사합니다. 구현은
`tools/cli/lib/commands/preflight_command.dart`의 `_checkFastlanePin`입니다.

**4가지 상태:**

| 상황 | 상태 | 동작 |
|------|------|------|
| `fastlane/` 부재 | **PASS** | 필요 시 핀으로 자동 클론됨 — 막지 않음 |
| 핀이 브랜치(`v`로 시작 안 함) | **WARN** | 태그 핀(`v*`)으로 교체 권장 (P0-6 과도기) |
| 핀이 태그인데 로컬 클론 불일치 | **FAIL** | `cd fastlane && git checkout <pin>`으로 수정 |
| 핀이 태그이고 로컬 클론 일치 | **PASS** | 정상 |

정확 대조 방법은 다음 명령입니다:

```bash
git -C fastlane describe --tags --exact-match HEAD
# 출력이 핀(v0.2.5)과 정확히 같아야 PASS.
# untagged HEAD이거나 다른 태그면 FAIL.
```

FAIL이 났을 때 복구:

```bash
cd fastlane && git fetch --tags && git checkout v0.2.5
```

---

## 5. 레인 계약 (13개)

템플릿이 호출하는 fastlane 레인이 **핀된 클론에 전부 존재하는지** 검증하는
계약입니다. 구현은 `scripts/check_lane_contract.rb`이고,
`bundle exec fastlane lanes` 출력을 파싱해 필수 레인의 존재를 확인합니다.

**로컬 실행 (표준):**

```bash
ruby scripts/check_lane_contract.rb [fastlane_dir]
# fastlane_dir 기본값: ./fastlane
# 종료 코드 0 = 계약 충족, 1 = 레인 누락 또는 실행 실패
```

> `.github/workflows/lane-contract.yml`도 존재하지만 Actions가 미실행이므로
> **로컬 실행이 표준**입니다.

**필수 레인 13개 — 3분류:**

| 분류 (5/4/4) | 레인 | 호출 주체 |
|--------------|------|-----------|
| **CLI 호출 (5)** | `build_and_upload`, `bump_version`, `generate_release_notes`, `generate_screenshots`, `upload_metadata` | `tools/cli` (`deploy_command.dart`) |
| **워크플로우 호출 (4)** | `build_and_upload_ios`, `build_and_upload_android`, `distribute_ios`, `distribute_android` | `.github/workflows/*`(Actions 미실행이나 계약상 유지) |
| **문서화 운영 (4)** | `codegen`, `ensure_version`, `test`, `version` | CLAUDE.md / docs의 사용자 진입점 |

레인이 누락되면 스크립트는 누락 목록을 출력하고 exit 1 하며, fastlane repo에
레인을 추가하거나 호출부(`tools/cli`·워크플로우)와 핀을 함께 갱신하라고 안내합니다.

---

## 6. fastlane/ 구조

클론된 `fastlane/`의 핵심 골격(자세한 트리는
[FASTLANE_SETUP.md §Directory Structure](../../guides/FASTLANE_SETUP.md)):

```
fastlane/
├── Fastfile              # 메인 레인 정의 (import 순서 중요)
├── VERSION               # fastlane repo 버전 파일
├── fastfiles/
│   ├── library/          # primitives — 재사용 단위 함수
│   │   ├── env_loader.rb / certificates.rb / ios.rb / android.rb ...
│   │   └── (다른 파일에서 호출되는 단위 빌딩블록)
│   └── stage/            # orchestration — 워크플로우 단계
│       ├── push.rb / metadata.rb / release.rb ...
│       └── (여러 library 함수를 조합한 단계)
└── config/
```

**library vs stage — 핵심 구분:**

- **`library/` (primitives)**: 재사용 가능한 단위 함수. 인증서 발급, 단일
  플랫폼 빌드, 버전 읽기 같은 작은 빌딩블록. 다른 파일에서 호출됨.
- **`stage/` (orchestration)**: 여러 library 함수를 조합한 워크플로우 단계.
  "메타데이터 업로드", "릴리스" 같은 상위 단계.
- **`VERSION` 파일**: fastlane repo가 자기 버전을 기록 — 태그 `v0.2.x`와 동기화.

> 메타데이터·스크린샷은 `fastlane/` 안이 아니라 **템플릿 루트**의 `metadata/`,
> `screenshots/`에 있습니다(FASTLANE_SETUP.md 참조).

---

## 7. deploy 오케스트레이션

**통합 배포는 fastlane 레인이 아니라 루트의 `./deploy` 단일 진입점입니다.**
`tools/cli`의 `deploy_command.dart`가 레인을 **순서대로** 호출합니다(개별
fastlane `deploy` 레인은 v0.2.0에서 제거됨).

```
./deploy --target <beta|production> [--submit-review]
   │
   ├─ 1. preflight            (env / 인증서 / 에셋 / Fastlane 핀 대조)
   ├─ 2. codegen + lint       (build.sh → flutter analyze)
   ├─ 3. test                 (flutter test, --skip-tests로 생략)
   ├─ 4. bump_version         (레인: bump_version type:<patch|minor|major|build>)
   ├─ 5. generate_screenshots (레인 — 기본 skip, --skip-screenshots 기본 true)
   ├─ 6. generate_release_notes (레인 — git log 기반 SSOT)
   ├─ 7. build_and_upload     (레인: target:.. platform:..)
   ├─ 8. upload_metadata      (production 대상만)
   └─ 9. submit_ios_review    (production + --submit-review + iOS — 메타데이터 이후)
```

세부 규칙:

- **screenshots는 기본 skip** — `--skip-screenshots` 기본값이 `true`라서
  단계 5는 명시적으로 끄지 않는 한 건너뜁니다.
- **메타데이터는 production만** — `--target beta`에서는 단계 8을 건너뜁니다.
- **iOS 심사 제출은 메타데이터 이후** — `submit_ios_review`는 반드시 메타데이터
  업로드 다음에 호출됩니다(제출된 버전에 메타데이터를 덮어쓰는 역순 방지).
  `production + --submit-review + (iOS or all)` 모두 만족할 때만 실행되고,
  실패 시 hard fail합니다(조용한 출시 누락 방지). Android는 production 업로드가
  곧 제출이라 별도 단계가 없습니다.

CLI 옵션 전체는 [CLI_TOOLS.md §deploy](../../guides/CLI_TOOLS.md)를 보세요.

---

## 8. 핀 범프 절차

fastlane repo를 고친 뒤 템플릿이 그 변경을 받으려면, 양쪽 repo를 함께 올리고
검증해야 합니다.

```
① flutter-fastlane repo에서
   git commit + git push
   git tag v0.2.x && git push --tags     # 배포 가능 핀(v*)

② 템플릿(boiler_plate)에서
   project.yaml  tooling.fastlane_ref: "v0.2.5" → "v0.2.x"
   .github/fixtures/smoke-project.yaml 핀도 같은 값으로 동기화

③ 검증
   cd fastlane && git fetch --tags && git checkout v0.2.x   # 로컬 클론을 새 핀으로
   ./preflight                              # 'Fastlane 핀' 체크 PASS 확인
   ruby scripts/check_lane_contract.rb      # 레인 계약 13/13 충족 확인
```

체크리스트:

- [ ] flutter-fastlane에 커밋 + push, `v0.2.x` 태그 + push
- [ ] `project.yaml`의 `tooling.fastlane_ref` 범프
- [ ] `.github/fixtures/smoke-project.yaml` 핀 동기화 (대조 테스트 fixture)
- [ ] 로컬 `fastlane/` 클론을 새 태그로 checkout
- [ ] `./preflight` 'Fastlane 핀' = **PASS** (`git describe --tags --exact-match HEAD` 일치)
- [ ] `ruby scripts/check_lane_contract.rb` = **13/13** 충족

> breaking 변경이면 루트 [CHANGELOG.md](../../../CHANGELOG.md) 릴리즈 규칙(semver +
> breaking만 `### Migration`)에 따라 마이그레이션 노트를 남깁니다.

---

## 관련 문서

- [FASTLANE_SETUP.md](../../guides/FASTLANE_SETUP.md) — fastlane 환경 구축(인증서, 키스토어, Match, 레인 사용)
- [CLI_TOOLS.md](../../guides/CLI_TOOLS.md) — `./run` 명령 레퍼런스(deploy 옵션 포함)
- [../../CHANGELOG.md](../../../CHANGELOG.md) — 태그 네임스페이스(`v*` / `cli-v*` / `template-v*`)와 릴리즈 규율 SSOT
- [DERIVED_APP_UPDATES.md](DERIVED_APP_UPDATES.md) — 파생 앱에 템플릿/fastlane 핀 전파
- [../MODULES.md](../../MODULES.md) — 모듈 경계 규칙, 기능 플래그 체계
- [../GOAL_AUDIT_ROADMAP.md](GOAL_AUDIT_ROADMAP.md) — fork-to-ship 이음새, 패키지화 로드맵
- [../CAPABILITY_MATRIX.md](CAPABILITY_MATRIX.md) — 기능 전수 분류(동결 스냅샷)
