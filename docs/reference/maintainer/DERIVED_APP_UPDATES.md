# 파생 앱 업데이트 가이드

> 템플릿(이 repo)의 변경분을 fork한 파생 앱(`kanken` / `hanja` / `snapdic` / `flowmodoro`)에
> 전파하는 방법.

---

## 목차

1. [개요 — 수동 전파 + 의도적 로컬 변경 보유](#개요)
2. [파생 앱 현황 — 2종 (패키지 소비 vs 분리 포크)](#파생-앱-현황)
3. [현재 동기화 버전 확인](#현재-동기화-버전-확인)
4. [업데이트 가능 판단](#업데이트-가능-판단)
5. [실행 — `scripts/sync-to-apps`](#실행--scriptssync-to-apps)
6. [`template.lock` 갱신 확인](#templatelock-갱신-확인)
7. [패키지 핀 업그레이드 (git-dep)](#패키지-핀-업그레이드-git-dep)
8. [tools/cli 업데이트 (별도)](#toolscli-업데이트-별도)
9. [fastlane 업데이트 (별도 repo)](#fastlane-업데이트-별도-repo)
10. [breaking 대응 + 트러블슈팅](#breaking-대응--트러블슈팅)

---

## 개요

**결론부터: 파생 앱 업데이트는 자동이 아니라 수동 1회성 명령(`scripts/sync-to-apps`)으로만 전파한다.**
도서관 사서가 신간을 일괄 입고하는 게 아니라, 각 지점이 필요할 때 직접 주문하는 방식에 가깝다.

이 템플릿은 **의도적 로컬 변경 보유** 원칙을 따른다 — 파생 앱은 템플릿에서 갈라진 뒤
앱마다 고유한 로직(피처, 설정값, 특화 코드)을 갖는다. 템플릿 변경분을 무차별 덮어쓰면
이 로컬 변경이 손실된다. 그래서:

- **자동 sync 금지** — CI 스케줄이나 봇으로 주기 동기화하지 않는다
  (GOAL_AUDIT_ROADMAP §4 항목 22 "의도적 로컬 변경 보유 스냅샷").
- **동기화 대상은 화이트리스트** — `sync-manifest.yaml`에 명시된 파일만 복사한다
  (주로 진입점 스크립트·CI 워크플로우). `app/lib`의 앱 코드는 동기화하지 않는다.
- **수동 실행만** — 사람이 `scripts/sync-to-apps`를 직접 호출하고, `--dry-run`으로 먼저 확인한다.

> 참고: 이 repo는 [GitHub Actions를 영구 미사용](../../CLAUDE.md)한다(빌링 사유). 워크플로우
> 파일은 트리에 존재하지만 실행되지 않으며, 동기화·검증·배포는 전부 로컬에서 수행한다.
> "CI가 자동으로 sync한다" 같은 동작은 존재하지 않는다.

전파에는 네 갈래가 있고, 각각 핀과 메커니즘이 다르다:

| 대상 | 메커니즘 | 핀 (`project.yaml tooling`) |
|------|----------|------------------------------|
| 템플릿 진입점/CI 파일 | `scripts/sync-to-apps` (이 가이드) | `template_version` |
| 공통 패키지 (`app/packages/*`) | 파생 앱 pubspec **git dep** ([7. 패키지 핀](#패키지-핀-업그레이드-git-dep)) | `pkgs_ref` |
| `tools/cli` (`bp` CLI) | `dart pub global activate --git-ref` | `cli_ref` |
| fastlane 설정 (별도 repo) | 각 앱에서 직접 clone/pull | `fastlane_ref` |

**fastlane/는 sync 대상이 아니다.** 별도 repo([raynear/flutter-fastlane])로 분리되어
각 앱이 핀된 ref로 직접 clone/pull 하므로 `sync-manifest.yaml`에 포함되지 않는다
([fastlane 업데이트](#fastlane-업데이트-별도-repo) 참조).

---

## 파생 앱 현황

> **2종으로 갈린다 — 공통 패키지를 소비하는 포크와, 패키지화 이전에 갈라진 분리 포크.**
> 어느 쪽인지에 따라 받을 수 있는 전파 갈래가 다르다.

| 앱 | 공통 패키지 소비 | 동기화 가능 갈래 |
|----|------------------|------------------|
| `snapdic` | utils·authentication·ab_testing (`app/packages/`에 **vendored-copy**, `path:`) | 진입점/CI sync + **패키지 핀(git-dep) 업그레이드**(§7) |
| `flowmodoro` | utils·authentication·ab_testing (동일 vendored-copy) | 진입점/CI sync + **패키지 핀(git-dep) 업그레이드**(§7) |
| `kanken` | **없음** — pub.dev 직접 의존, `provider` 상태관리, 자체 디렉토리 | 진입점/CI sync만 (패키지 정렬 비대상) |
| `hanja` | **없음** — pub.dev 직접 의존, `provider` 상태관리, 자체 디렉토리 | 진입점/CI sync만 (패키지 정렬 비대상) |

### 패키지 소비 포크 — `snapdic` / `flowmodoro`

템플릿 공통 패키지 중 `utils` / `authentication` / `ab_testing` **3개**를 `app/packages/` 아래
물리 복사본(vendored-copy)으로 두고 `path:`로 물린다. 나머지 능력(firebase/notifications/
ads 등)은 패키지를 경유하지 않고 pub.dev SDK를 직접 의존한다.

- 이 복사본은 **stale 스냅샷**이다 — 예: `snapdic`의 `ab_testing` 복사본엔 템플릿이
  [P1-16.5a에서 철거](../../../CHANGELOG.md)한 `supabase_flutter`가 아직 남아 있다.
- vendored-copy를 **git-dep 핀**으로 바꾸면 핀 한 줄로 버전을 올릴 수 있다
  ([7. 패키지 핀 업그레이드](#패키지-핀-업그레이드-git-dep)).

### 분리 포크 — `kanken` / `hanja`

둘 다 패키지화([GOAL_AUDIT_ROADMAP](GOAL_AUDIT_ROADMAP.md) §4 항목 19-20) **이전**에 갈라진
완전 독립 포크다. `provider` 상태관리 + 자체 디렉토리 구조(`controllers/`·`screens/`·`views/` 등)이며,
템플릿 공통 패키지·pub workspace·`tools/cli`·`template.lock` 어느 것과도 연결되어 있지 않다.

- **수동 sync only** — 진입점 스크립트·CI 워크플로우는 `sync-to-apps`로 받을 수 있으나,
  공통 패키지/workspace 정렬은 아키텍처 재작성(`provider`→Riverpod, 디렉토리 개편)이라
  **비대상**이다. 이들에 패키지 핀을 강제하지 않는다(의도적 분리).

> **flowmodoro 특화 패키지**(heatmap/geofence/app_blocker)는
> [P1-16c에서 소유 앱(`flowmodoro`) repo로 퇴거](../../MODULES.md) 완료됐다 —
> 템플릿 `app/packages/`엔 공통 9개 패키지만 남아 있고 앱 특화 패키지는 없다.

---

## 현재 동기화 버전 확인

파생 앱이 **어느 템플릿 버전에서 마지막으로 sync 받았는지**를 먼저 확인한다.
세 가지 소스를 본다.

### 1. 파생 앱 `template.lock` (가장 정확)

`scripts/sync-to-apps`는 sync 성공 시 각 앱 루트에 `template.lock`을 기록한다.
이 파일이 **마지막 동기화 스냅샷의 SSOT**다 (손 편집 금지 — sync가 덮어쓴다).

```bash
cat ~/Project/kanken/template.lock
```

```yaml
# template.lock — scripts/sync-to-apps 가 생성 (손 편집 금지)
template_version: template-v1.0.0
template_commit: <40자 커밋 해시>
synced_at: 2026-06-13T00:00:00Z
files:
  - scripts/build
  - scripts/deploy
  - ...
```

> 참고: 2026-06 현재 4개 파생 앱은 **아직 최초 sync를 받지 않아 `template.lock`이 없다**
> ([파생 앱 현황](#파생-앱-현황)). 위 블록은 첫 sync 후 생길 형식이다.

- `template_version` — sync 당시 HEAD가 가리키던 `template-v*` 태그
- `template_commit` — sync 당시 템플릿의 정확한 커밋 (재현/대조용)
- `files` — 그 sync에 포함된 파일 목록 (`sync-manifest.yaml`의 enabled 항목)

### 2. 템플릿 측 `project.yaml tooling.template_version`

템플릿(이 repo)이 현재 어떤 버전을 릴리즈하려 하는지를 보여준다.

```bash
grep template_version /Users/raynear/Project/boiler_plate/project.yaml
# tooling.template_version: "template-v1.0.0"
```

파생 앱의 `template.lock` `template_version`이 이 값보다 낮으면 **업데이트 후보**다.

### 3. CHANGELOG

[`CHANGELOG.md`](../../../CHANGELOG.md)의 `[Unreleased]`와 마지막 `[template-vX.Y.Z]`
섹션을 비교해 그 사이에 무엇이 바뀌었는지, breaking이 있는지 확인한다.

---

## 업데이트 가능 판단

### 태그 네임스페이스 (4종 — 혼동 금지)

이 repo는 태그를 용도별로 분리한다 ([CHANGELOG](../../../CHANGELOG.md) 릴리즈 규칙).

| 네임스페이스 | 용도 | 소비처 |
|--------------|------|--------|
| `template-v*` | **템플릿 릴리즈** | `sync-to-apps`가 `template.lock`·`tooling.template_version`에 기록 |
| `pkgs-v*` | 공통 패키지(`app/packages/*`) 릴리즈 | 파생 앱 pubspec **git dep** 핀 (`tooling.pkgs_ref`) |
| `cli-v*` | `tools/cli` 릴리즈 | 파생 앱의 `dart pub global activate --git-ref` 핀 (`tooling.cli_ref`) |
| `v*` | **배포 게이트 트리거 전용** | 동기화·CLI 핀으로 **절대 사용 금지** |

> `v*`는 배포 게이트용이라 `sync-to-apps`가 거부한다. 템플릿 릴리즈는 반드시
> `template-v*` 태그에서만 sync할 수 있다 (가드 2 참조).

### semver와 breaking 판정

- 버전은 [semver](https://semver.org/)를 따른다. MAJOR 증가 = breaking
  (설정 스키마 변경, 경로 계약 변경, CLI 인터페이스 변경 등 — 파생 앱이 추가 작업 없이는
  sync를 받을 수 없는 변경).
- **breaking이 있으면** 해당 릴리즈 항목의 [`CHANGELOG`](../../../CHANGELOG.md) `### Migration`
  섹션에 파생 앱이 해야 할 작업이 명시된다. non-breaking 릴리즈에는 Migration 섹션이 없다.

판단 순서:

1. `template.lock`의 `template_version` < 템플릿 `tooling.template_version` → 업데이트 후보.
2. CHANGELOG에서 두 버전 사이에 `### Migration`이 있는지 확인.
3. Migration이 있으면 **sync 전에** 그 작업을 먼저 수행한다
   ([breaking 대응](#breaking-대응--트러블슈팅) 참조).
4. 없으면 바로 `--dry-run`으로 진행.

---

## 실행 — `scripts/sync-to-apps`

템플릿 repo 루트에서 실행한다. **항상 `--dry-run`으로 먼저 확인**한 뒤 실제 실행한다.

```bash
cd /Users/raynear/Project/boiler_plate

# 1) 무엇이 바뀔지 미리보기 (파일 변경 없음, 가드는 경고로 완화)
./scripts/sync-to-apps --dry-run

# 2) 특정 앱만 미리보기
./scripts/sync-to-apps --dry-run --app kanken

# 3) 실제 동기화 (전체 앱)
./scripts/sync-to-apps

# 4) 특정 앱만 실제 동기화
./scripts/sync-to-apps --app kanken
```

### 옵션

| 옵션 | 동작 |
|------|------|
| `--dry-run` | 변경 없이 동기화 내용만 출력 (`WOULD CREATE/UPDATE`). 가드는 경고로 완화되어 계속 진행 |
| `--app <name>` | `apps.yaml`에 등록된 특정 앱만 동기화 |
| `--force` | 더티트리/untagged HEAD 가드를 경고만 출력하고 우회 |
| `-h`, `--help` | 도움말 |

### SSOT 두 파일

`sync-to-apps`는 루트의 두 YAML을 읽는다. 동기화 대상/앱을 바꾸려면 **이 파일들만** 수정한다.

- [`sync-manifest.yaml`](../../../sync-manifest.yaml) — **동기화 파일 목록 SSOT**.
  `path:`(템플릿 루트 기준 상대경로) 항목만 복사한다. `enabled: false`면 제외(`reason` 필수).
  현재 등록된 파일: `scripts/`의 진입점 스크립트(`build`/`deploy`/`feature`/`init`/`preflight`/
  `rename`/`screenshot`/`test`/`generate-*`/`iap-register`), `scripts/generate_release_notes.py`,
  `scripts/check_lane_contract.rb`, `.github/workflows/`의 `qa-gate.yml`·`release-notes.yml`·
  `lane-contract.yml`. **fastlane/는 명시적으로 제외**(별도 repo).
- [`apps.yaml`](../../../apps.yaml) — **파생 앱 레지스트리**.
  `name`(=`--app` 인자)과 `path`(`~`는 `$HOME`으로 확장). 현재 등록:
  `kanken` / `hanja` / `snapdic` / `flowmodoro` (모두 `~/Project/<name>`).

### 가드 (3종)

`sync-to-apps`는 잘못된 sync를 막기 위해 세 가지 가드를 건다.
`--force`는 1·2를 우회, `--dry-run`은 경고 후 계속 진행한다.

1. **템플릿 더티트리 거부** — `git status --porcelain`이 비어 있어야 진행한다.
   커밋되지 않은 변경이 파생 앱으로 새는 것을 막는다.
   ```
   [ERROR] 템플릿 working tree 가 더티합니다. 커밋/스태시 후 다시 실행하세요
   ```
2. **untagged HEAD 거부** — HEAD가 `template-v*` 태그가 정확히 가리키는 커밋이어야 한다.
   임의 커밋이나 `v*`(배포 게이트) 태그에서는 sync할 수 없다.
   ```
   [ERROR] HEAD 가 태그를 가리키지 않습니다. template-v* 태그에서만 sync 가능합니다
   ```
3. **대상 앱 더티트리** — 해당 앱만 skip하고 경고한다(**전체 중단 아님**). git repo가
   아닌 경로도 skip. 다른 앱은 계속 동기화된다.
   ```
   [WARN] [kanken] SKIP -- working tree 가 더티합니다. 커밋/스태시 후 다시 실행하세요
   ```

### 동작 흐름

각 enabled 파일에 대해 `diff`로 동일하면 스킵하고, 다르면 복사한다(실행 비트 보존).
앱당 sync가 끝나면 그 앱 루트에 `template.lock`을 기록한다. 마지막에 synced/skipped 앱 수를 요약한다.

---

## `template.lock` 갱신 확인

sync 직후 대상 앱의 `template.lock`이 새 버전·커밋으로 갱신됐는지 확인한다.

```bash
cat ~/Project/kanken/template.lock
```

- `template_version`이 방금 sync한 `template-v*` 태그와 일치하는지
- `template_commit`이 템플릿 현재 HEAD와 일치하는지
- `files` 목록이 `sync-manifest.yaml`의 enabled 항목과 일치하는지

> `template.lock`은 sync가 생성·덮어쓰는 산출물이다. **손으로 편집하지 않는다** —
> 다음 sync가 무조건 덮어쓴다.

이후 각 파생 앱 repo에서 변경분을 커밋한다(파생 앱 리포지토리 기준).

```bash
cd ~/Project/kanken
git add -A && git status   # sync로 바뀐 파일 + template.lock 확인
git commit -m "chore: sync template template-v1.0.0"
```

---

## 패키지 핀 업그레이드 (git-dep)

**공통 패키지(`app/packages/*`)는 `sync-manifest.yaml` 대상이 아니다** — 앱 코드라
무차별 복사하지 않는다. 대신 파생 앱이 **git dep으로 핀**해서 소비하고, 핀을 올려
버전을 업그레이드한다. 핀은 `project.yaml tooling.pkgs_ref`(현재 `pkgs-v1.0.0`)에 있다.

> 이 경로는 **패키지 소비 포크**(`snapdic`/`flowmodoro`)에만 해당한다.
> 분리 포크(`kanken`/`hanja`)는 공통 패키지를 쓰지 않는다([파생 앱 현황](#파생-앱-현황)).

### vendored-copy → git-dep 전환

현재 `snapdic`/`flowmodoro`는 패키지를 `app/packages/`에 복사(vendored-copy)해 `path:`로
물린다. 이를 git dep으로 바꾸면 복사본을 지우고 핀 한 줄로 버전을 추적한다.

```yaml
# 파생 앱 app/pubspec.yaml
dependencies:
  utils:
    git:
      url: https://github.com/raynear/boiler_plate.git
      ref: pkgs-v1.0.0          # = project.yaml tooling.pkgs_ref
      path: app/packages/utils  # 템플릿 repo 안의 패키지 위치
```

- `path:`는 **템플릿 repo 내** 패키지 경로(`app/packages/<name>`)다(파생 앱 경로가 아니다).
- **전이 의존도 같이 핀한다** — `authentication`이 `utils`를 `path: ../utils`로 참조하므로,
  `authentication`도 git dep으로 바꾸거나 `dependency_overrides`로 `utils`만 핀해
  복사본과 git 버전이 섞이지 않게 한다.
- 파생 앱이 pub workspace 멤버라도 외부 git dep은 정상 해석된다(P2-19d 증명).

### 검증 (비침습)

파생 앱 작업 브랜치를 건드리지 않고 **worktree**에서 핀을 먼저 시험한다.

```bash
# 파생 앱에서 (예: snapdic) — 작업 브랜치 무손상 detached worktree
git -C ~/Project/snapdic worktree add --detach /tmp/pin-proof HEAD
# /tmp/pin-proof/app/pubspec.yaml 에 dependency_overrides 로 utils 를 git 핀
cd /tmp/pin-proof/app && flutter pub get
grep -A6 '^  utils:' pubspec.lock   # source: git / ref / resolved-ref 확인
git -C ~/Project/snapdic worktree remove --force /tmp/pin-proof
```

`pubspec.lock`의 `utils`가 `source: git` + `resolved-ref`(태그 커밋)로 해석되면 통과다.
(P2-19d / 항목 22 — `snapdic`에서 `utils@pkgs-v1.0.0` → `resolved-ref: 2a0613b…` 확인.)

### ⚠️ pkgs-v1.0.0 은 stale — 실 업그레이드 전 새 태그 발행

현재 `pkgs-v1.0.0` 태그는 **공통 패키지 9개 추출 이전**(P2-19d 시점)을 가리킨다.
그 태그엔 `utils`/`authentication`/`ab_testing` **3개만** 있고, `ab_testing` 복사본엔
[철거된 `supabase_flutter`](../../../CHANGELOG.md)가 남아 있다. 나머지 6개 패키지
(`ads`/`biometric_auth`/`firebase_services`/`notifications`/`notifications_fcm`/`positioning`)는
그 태그에 **존재하지 않는다**.

따라서 **실제 업그레이드 시엔**:

1. 현재 `main`의 9패키지 상태에서 새 `pkgs-v*` 태그를 발행한다
   ([CHANGELOG](../../../CHANGELOG.md) 릴리즈 규칙 — `pkgs-v*` 네임스페이스).
2. `project.yaml tooling.pkgs_ref`를 새 태그로 올린다.
3. 파생 앱 pubspec의 `ref:`를 그 값으로 교체하고 `flutter pub get` → `analyze`/`build`.

`pkgs-v1.0.0`은 **메커니즘 증명용**으로만 쓴다(파생 앱 실 마이그레이션 핀 아님).

---

## tools/cli 업데이트 (별도)

`bp` CLI(`./run <command>`의 실체)는 sync 대상이 아니다. 파생 앱은 **git 핀으로
전역 활성화**해서 쓴다 (템플릿 본체는 `./run` path 실행을 유지).

핀은 `project.yaml tooling.cli_ref`(현재 `cli-v1.0.0`)에 있다. 파생 앱에서:

```bash
dart pub global activate \
  --source git \
  --git-url https://github.com/raynear/boiler_plate.git \
  --git-path tools/cli \
  --git-ref cli-v1.0.0
```

- `--git-ref`에는 파생 앱 `project.yaml`의 `tooling.cli_ref` 값을 넣는다.
- CLI를 업데이트하려면 새 `cli-v*` 태그로 `cli_ref`를 올리고, 위 명령을 새 ref로 다시 실행한다.
- 등록된 CLI 명령: `init`·`build`·`gen-env`·`deploy`·`deploy-legal`·`test`·`preflight`·
  `rename`·`setup`·`screenshot`·`generate-icon`·`generate-legal`·`generate-privacy`·
  `generate-data-safety`·`generate-desc`·`iap-register` (디스패치는
  `tools/cli/lib/core/cli_registry.dart`). `feature`는 별도 패키지(`tools/feature_cli`) 위임.

자세한 CLI 사용법은 [CLI_TOOLS.md](../../guides/CLI_TOOLS.md) 참조.

---

## fastlane 업데이트 (별도 repo)

**fastlane 설정은 이 repo가 아니라 별도 repo [raynear/flutter-fastlane]에 있다.**
로컬 `fastlane/`는 `.gitignore`(`/fastlane`)되어 추적되지 않으며, sync 대상도 아니다.

- 핀: `project.yaml tooling.fastlane_ref`(현재 `v0.2.5`).
- `fastlane/` 부재 시 `tools/cli/lib/core/bootstrap.dart`의 `ensureFastlane(projectRoot)`가
  핀 ref로 자동 클론한다. URL 오버라이드는 `FASTLANE_REPO` 환경변수
  (기본 `https://github.com/raynear/flutter-fastlane.git`).
- fastlane를 업데이트하려면 새 태그로 `tooling.fastlane_ref`를 올린 뒤, 각 앱에서
  `cd fastlane && git fetch && git checkout <새핀>`으로 클론을 핀에 맞춘다.
- `preflight`('Fastlane 핀' 체크)가 로컬 클론이 핀과 일치하는지 검증한다
  — 불일치면 FAIL하며 `cd fastlane && git checkout <pin>`을 안내한다.

fastlane 자동 클론·핀·레인 계약의 전체 동작은 [FASTLANE_SETUP.md](../../guides/FASTLANE_SETUP.md) 참조.

---

## breaking 대응 + 트러블슈팅

### breaking 변경 대응 절차

[`CHANGELOG`](../../../CHANGELOG.md)의 해당 릴리즈에 `### Migration` 섹션이 있으면 breaking이다.
**sync 전에** 거기 명시된 작업을 파생 앱에 먼저 적용한다.

예시(P1-16.5 Supabase 철거 — 실제 CHANGELOG Migration 항목):

1. Migration 노트를 읽고 파생 앱에서 제거/교체할 게이트·설정을 확인한다
   (예: `app_config.yaml services.supabase` 블록, 삭제된 기능 플래그를 자체 상수로 대체).
2. 그 변경을 파생 앱에 적용·커밋해 working tree를 클린으로 만든다.
3. env 산출물은 `./run gen-env`로 재생성한다(source-hash 변동 시 preflight가 stale을 차단).
4. 이제 `sync-to-apps`를 실행한다(앱이 클린이라 가드 3을 통과).

> Supabase는 P1-16.5에서 완전히 철거됐다. 백엔드는 Firebase Auth(email) +
> 클라이언트 직접 계정 삭제 + local-only Drift이며 서버 코드는 0줄이다. **신규 설정에
> Supabase를 다시 도입하지 않는다** ([MODULES.md](../../MODULES.md) §5 참조).

### 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `템플릿 working tree 가 더티합니다` | 가드 1 — 템플릿에 커밋 안 된 변경 | 템플릿에서 커밋/스태시 후 재실행. 의도된 우회면 `--force` |
| `HEAD 가 태그를 가리키지 않습니다` | 가드 2 — HEAD가 `template-v*` 태그가 아님 | `git checkout template-vX.Y.Z` 후 재실행. `v*` 태그는 불가(배포 게이트 전용) |
| `HEAD 태그 '...' 는 템플릿 릴리즈 태그가 아닙니다` | 가드 2 — `cli-v*`/`v*` 등 비-template 태그 | `template-v*` 태그 커밋으로 이동 후 재실행 |
| `[<app>] SKIP -- working tree 가 더티합니다` | 가드 3 — 대상 앱에 커밋 안 된 변경 | 해당 앱에서 커밋/스태시 후 재실행(다른 앱은 정상 sync됨) |
| `[<app>] SKIP -- directory not found` | `apps.yaml`의 `path`에 디렉토리 없음 | 경로 확인 또는 `apps.yaml` 수정 |
| `매니페스트 항목이 템플릿에 없습니다` | `sync-manifest.yaml`에 등록됐으나 파일 부재 | 매니페스트에서 제거하거나 파일 복구 |
| `Unknown app '<name>'` | `--app`에 미등록 앱 | `apps.yaml`에 등록된 이름만 사용 |

`--force`는 가드 1·2를 우회한다. **로컬 변경 손실 위험**이 있으니
반드시 `--dry-run`으로 영향 범위를 먼저 확인한 뒤 사용한다.

---

## 관련 문서

- [MODULES.md](../../MODULES.md) — 모듈 경계 규칙 + 기능 플래그 체계
- [GOAL_AUDIT_ROADMAP.md](GOAL_AUDIT_ROADMAP.md) — §4 항목 19-22 (패키지 추출, 파생 앱 이전)
- [CAPABILITY_MATRIX.md](CAPABILITY_MATRIX.md) — 기능/패키지 매트릭스(동결 스냅샷)
- [VERSION_POLICY.md](../../guides/VERSION_POLICY.md) — 버전 정책
- [FASTLANE_SETUP.md](../../guides/FASTLANE_SETUP.md) — fastlane 별도 repo·핀·레인 계약
- [CLI_TOOLS.md](../../guides/CLI_TOOLS.md) — `bp` CLI 명령 레퍼런스
- [CHANGELOG.md](../../../CHANGELOG.md) — 릴리즈 + Migration 노트
- [sync-manifest.yaml](../../../sync-manifest.yaml) / [apps.yaml](../../../apps.yaml) — sync SSOT
