# Quick Start: PRD → 배포 (정전 가이드)

> **이 문서가 정전(正典)이다.** clone부터 스토어 배포까지의 표준 경로는 이 문서가 기준이다 —
> 다른 진입 문서(README, 01-GETTING_STARTED)와 내용이 다르면 이 문서를 따른다.
> 기존 인증서/키가 있으면 clone부터 첫 베타 배포까지 약 25분.

> **🤖 Claude Code 진입점**: 사용자가 "이 템플릿으로 앱 만들어줘"라고 하면 —
> ① 루트 [`prd.md`](../prd.md)를 먼저 읽는다(채워져 있으면 그 값으로, 비어 있으면
> 사용자와 함께 채운다). ② 이 문서의 **Phase 0→6 순서대로** 실행한다. 각 Phase는
> prd.md의 섹션과 1:1 대응한다.

전 과정 한눈에:

```
Phase 0        Phase 1      Phase 2        Phase 3   Phase 4         Phase 5   Phase 6
사전준비  →   PRD 작성  →  설정 생성  →  ./init  →  Play 등록  →   개발   →  ./deploy
(도구)        (prd.md)     (yaml 2개)    (자동)    (수동 1회)      (반복)    (자동)
```

---

## Phase 0 — 사전 준비물

### 필수 도구

| 도구 | 설치 확인 | 설치 방법 |
|------|----------|----------|
| Flutter SDK (stable 최신) | `flutter --version` | [flutter.dev](https://flutter.dev) |
| Dart SDK 3.8+ (`app/pubspec.yaml` 기준) | `dart --version` | Flutter에 포함 |
| Git | `git --version` | `brew install git` |
| Fastlane | `fastlane --version` | `brew install fastlane` |
| Ruby Bundler | `bundle --version` | `gem install bundler` |

### 재사용 가능한 기존 자산 (다른 프로젝트에서 가져오기)

| 자산 | 용도 | 설정 위치 |
|------|------|----------|
| Match Git 저장소 | iOS 인증서/프로비저닝 | `app_config.yaml: signing.ios.match_git_url` |
| Android Keystore (.jks) | Android 앱 서명 | `app_config.yaml: signing.android.keystore_path` |
| Apple Developer 계정 | iOS 빌드/배포 | `app_config.yaml: store.apple.apple_id` |
| App Store Connect API 키 (.p8) | iOS 앱 자동 등록 | `app_config.yaml: store.apple.api_key_file` |
| Google Play 서비스 계정 JSON | Android 배포 | `app_config.yaml: store.google.json_key_file` |
| Firebase 서비스 계정 JSON | Firebase 관리 | `app_config.yaml: services.firebase.service_account_file` |

> 위 자산은 프로젝트 간 공유 가능. 새로 만들 필요 없이 기존 파일 경로만 지정한다.
> 처음이라 자산이 없으면 → [EXTERNAL_SETUP.md](./guides/EXTERNAL_SETUP.md)에서 발급.

### 새 앱 레포 생성

**권장 — `provision` 한 줄:** GitHub Template에서 새 앱 레포를 만들고 rename +
fastlane 확보(submodule init / 핀 clone) + `bundle install`까지 자동화한다.

```bash
~/Project/boiler_plate/scripts/provision \
  --name "My New App" \
  --package "com.raynear.mynewapp" \
  --dir ~/Project/my_new_app
```

> `provision`은 뒤따르는 Phase 1의 정체성 치환과 Phase 3(`./init`)의 앞단을 대신
> 처리한다 — 레포 생성 + `project.yaml`(name/package/repo) 치환 + `init.dart` 실행까지.
> 실행 후 `prd.md`를 채우는 것부터 이어가면 된다. (`gh` 인증 필요: `gh auth login`.)

**수동 경로 (GitHub Template "Use this template" 또는 git clone):**

```bash
git clone https://github.com/raynear/boiler_plate.git my_new_app
cd my_new_app
```

> ⚠ **submodule 미복사 함정**: GitHub Template("Use this template") 버튼으로 만든
> 레포는 fastlane submodule **내용을 복사하지 않는다**(`.gitmodules`만 들어옴) —
> `provision`은 이걸 자동으로 해결한다. 수동 경로에서는 `./run`/`./init` 첫 실행 시
> 자동으로 가져오며, 미리 받으려면 `git submodule update --init`.

---

## Phase 1 — PRD 작성 (`prd.md`)

루트 [`prd.md`](../prd.md)를 연다. 12개 섹션의 「채움」 블록을 채운다 — 이것이 앱 정의의 SSOT다.

- **사람**: 아는 만큼 채우고, 모르는 칸은 비워둔다.
- **Claude Code**: 빈 필수 칸(이름, package_name, 인증 방식, 수익 모델 등)은 합리적
  기본값을 제안하고 사용자 확인을 받은 뒤 채운다. 빈 선택 칸은 기본값으로 둔다.

PRD의 각 섹션이 어느 설정으로 흘러가는지는 prd.md 안에 `→ 매핑`으로 표시돼 있다.
(예: §1 앱 정체성 → `project.yaml: project.*`, §10 프로파일 → `app_config.yaml: profile`)

---

## Phase 2 — 설정 생성 (루트 yaml 2개)

PRD 값을 손편집 설정 파일에 반영한다. **사용자가 편집하는 파일은 루트 3개뿐**:
`project.yaml`(앱 정체성) / `app_config.yaml`(공통 인프라) / `.env`(시크릿).
`app/config/env/.env.*`는 `./build` 산출물이므로 손대지 않는다.

### project.yaml — 앱마다 달라지는 정체성 (PRD §1·2·3·8·9)

```yaml
project:
  name: "My New App"
  package_name: "com.mycompany.mynewapp"
  description: "앱 설명"
  github_repository: "mycompany/mynewapp"
  category: "productivity"
# listing / age_rating / admob / iap / privacy / deep_link — PRD 해당 섹션 값
```

### app_config.yaml — 인프라/서비스 (PRD §4·6·10·11, 기존 자산 경로 재사용)

```yaml
company_name: "MyCompany"
platforms:
  ios:
    team_id: "XXXXXXXXXX"               # Apple Developer Team ID
profile: "standard"                     # minimal / standard / premium / enterprise
services:
  firebase:
    enabled: true
    service_account_file: "~/serviceAccount.json"
store:
  apple:
    apple_id: "your@email.com"
    api_key_id: "XXXXXXXXXX"
    api_issuer_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    api_key_file: "~/AuthKey_XXXXXXXXXX.p8"
  google:
    json_key_file: "~/google-play-key.json"
signing:
  ios:
    match_git_url: "https://github.com/mycompany/cert.git"
  android:
    keystore_path: "~/key.jks"
```

> 기능 ON/OFF는 `profile` + `features:` 오버라이드로 결정된다. 개별 토글이 필요하면
> Phase 5의 `./feature enable/disable`. 플래그 체계 상세: [FEATURE_MANAGEMENT.md](./guides/FEATURE_MANAGEMENT.md).

---

## Phase 3 — `./init` 실행

```bash
./init
```

**자동으로 수행되는 작업 (14단계):**

| 단계 | 작업 | 수동 개입 |
|------|------|----------|
| 1 | project.yaml + app_config.yaml 로드 | - |
| 2 | 패키지명/번들ID 변경 | - |
| 3 | 환경 파일 생성 (루트 .env + app/config/env/.env.* 산출물) | - |
| 4 | Profile 기반 Feature Flag 적용 | - |
| 5 | 코드 서명 설정 (Match/Keystore) | - |
| 6 | 의존성 설치 (flutter pub get) | - |
| 7 | 코드 생성 (Freezed, Drift, JSON Serializable) | - |
| 8 | 앱 아이콘 생성 (adlab, 선택) | 프롬프트 미설정·adlab 미실행 시 스킵 |
| 9 | 스토어 설명 생성 (GPT-4o, 선택) | - |
| 10 | Fastlane 메타데이터 설정 | - |
| 11 | 법적 문서 생성 (개인정보처리방침·약관) | - |
| 12 | Firebase 프로젝트 자동 생성 + 연동 | project_id 비어있으면 자동 생성 |
| 13 | iOS 앱 자동 등록 (App Store Connect) | ASC API 키 필요 |
| 14 | 빌드 검증 (flutter analyze) | - |

### 빠르게 실행 (AI 생성 스킵)

```bash
./init --skip-icon --skip-description
```

> 코드 생성은 **수동 Riverpod Notifier 패턴**을 쓴다 — `@riverpod` 코드 생성은 하지 않는다.
> 생성되는 건 Freezed(`.freezed.dart`), JSON(`.g.dart`), Drift(`database.g.dart`)뿐이다.

---

## Phase 4 — Google Play 앱 등록 (유일한 수동 작업)

> Google Play Developer API는 앱 *생성*을 지원하지 않아 수동 등록이 필요하다.
> (iOS는 Phase 3의 13단계에서 자동 등록됨.)

1. [Google Play Console](https://play.google.com/console) 접속
2. **"앱 만들기"** 클릭
3. 패키지명: `project.yaml`의 `project.package_name` 입력
4. 기본 정보 입력 후 저장

> 첫 배포 전까지만 완료하면 된다. `./init` 직후에 하지 않아도 괜찮다.

---

## Phase 5 — 개발

```bash
cd app
flutter run
```

### 기능 추가 (테스트와 함께 — born-tested)

```bash
./feature generate -n payment --full     # lib/features/payment/ + 짝이 되는 테스트까지 생성
# → lib/core/router.dart 에 라우트 등록, ./build 자동 실행(모델 codegen)
```

`--full`은 model/viewmodel/view/repository 테스트를 함께 만들고 변경-기능 80% 게이트를
스스로 통과한다. `--with-test`는 **요청한 컴포넌트의** 테스트만 생성(`--no-test`로 끔).
생성된 `// ponytail: TODO`를 채우며 확장한다.

### 기능 플래그 관리

```bash
./feature status              # 현재 플래그 상태
./feature list                # 토글 가능한 기능 목록
./feature enable ads          # 켜기
./feature disable ads         # 끄기
```

### 개발 루프 (테스트 주도 — 게이트 초록까지 반복)

```
RED      로직은 실패 테스트 먼저 (./test --watch 로 빨강 확인)
GREEN    최소 코드  →  ./build (모델/DB 변경 시 codegen)
REFACTOR 초록 유지하며 정리  →  flutter run (실기기 확인)
GATE     ./preflight --mode feature   ← 초록 아니면 RED로 복귀. 탈출 금지.
```

게이트 = analyze + flutter test + 테스트 무결성(no-skip) + **변경 기능 커버리지 ≥80%**.
완료(Definition of Done)·스킬 매핑(TDD/ponytail/verification/finishing)·PR 2종 리뷰는
루트 `CLAUDE.md`의 **"테스트 주도 개발 루프"** 및 **"개발 워크플로우"** 섹션 참조.

> 코드 패턴(ViewModel/Model/Repository/View), DB 테이블 추가, A/B 실험 추가는
> 루트 `CLAUDE.md`와 [MODULES.md](./MODULES.md) 참조.

---

## Phase 6 — 배포

### 사전 검증

```bash
./preflight
```

검증: config, .env, 도구 설치, 서명, flutter analyze, 에셋(아이콘), 스토어 인증,
Firebase, Google Play 등록, **release 광고 단위 ID**(비었거나 테스트 ID면 차단).

> `./deploy --target production`은 추가로 **패키지명 placeholder(`com.example.*`),
> Android keystore 미설정(디버그 서명 차단), iOS 스토어/서명 자격증명 placeholder,
> 호스팅된 개인정보처리방침 URL 부재**를 hard-fail로 차단한다(B2/B4/A1). 개인정보 URL은
> `./run deploy-legal`(아래) 후 자동 도출되거나 `listing.privacy_policy_url`로 지정한다.

### 배포 실행

```bash
./deploy                              # 전체 (preflight → build → upload)
./deploy --target beta                # 베타 (Firebase App Distribution)
./deploy --target production          # 프로덕션 (App Store + Google Play)
./deploy --target production --no-skip-screenshots --submit-review
                                      # 첫 제출용: 스크린샷 생성+업로드 후 심사 제출
./deploy --platform ios               # 한 플랫폼만
./deploy --bump minor                 # 버전 증가 (patch 기본)
./deploy --dry-run                    # 검증만, 실제 업로드 없음
```

> `./deploy`는 preflight → 코드생성+lint → (테스트) → 버전 bump → 스크린샷 →
> 릴리즈노트 → build & upload → (프로덕션) 메타데이터 + **App Privacy·연령등급**(iOS)
> + **IAP/구독 상품 등록**(설정 시) → (--submit-review) iOS 심사 → git 태그 순으로
> fastlane 레인을 오케스트레이션한다. 상세: [FASTLANE_SETUP.md](./guides/FASTLANE_SETUP.md).
>
> **첫 App Store 제출 주의:** 스크린샷은 심사 필수다. 기본 `./deploy`는 스크린샷을
> 건너뛰므로(`--skip-screenshots` 기본 true), 첫 제출은 `--no-skip-screenshots`로
> 생성+업로드를 함께 해야 한다(이 플래그가 deliver에 `SKIP_SCREENSHOTS=false`를
> 주입). 수익화 앱이면 **유료 앱 계약/은행/세금**(ASC 콘솔 수동)이 선행돼야 IAP
> 심사를 통과한다 → [APP_STORE_REGISTRATION_CHECKLIST.md](./reference/APP_STORE_REGISTRATION_CHECKLIST.md).

### 개인정보처리방침 호스팅 (제출 필수)

```bash
./run generate-legal                 # docs/legal/*.html 생성
./run deploy-legal                   # Firebase Hosting (<id>.web.app)
./run deploy-legal --target github   # GitHub Pages (<owner>.github.io/<repo>)
```

> 호스팅 방식은 `project.yaml listing.legal_hosting`(firebase|github)로 선택한다.
> 배포된 URL은 gen_env가 앱·스토어 메타데이터에 자동 주입한다 — production
> preflight가 이 URL을 요구하므로 첫 배포 전 1회 실행한다. (github는
> `.github/workflows/legal-pages.yml`가 처리하며 private repo는 GitHub 유료 플랜 필요.)

### GA4 커스텀 정의 등록 (A/B 테스트 사용 시 · 1회성 수동)

```bash
cd fastlane
bundle exec fastlane ga4_setup      # ga4_custom_definitions.yml의 dim 일괄 등록
```

> `ga4_setup`은 **`./init`/`./deploy`에 배선되지 않은 수동 전용 레인**이다. A/B 실험의
> `ab_xxx` user property를 GA4에 등록하려면 직접 실행해야 하며, `.env`에
> `GA4_PROPERTY_ID=<숫자 ID>`가 필요하다(미설정 시 레인이 에러로 중단). A/B 테스트를
> 안 쓰면 건너뛴다. 상세: [AB_TEST_LIFECYCLE.md](./AB_TEST_LIFECYCLE.md).

---

## 전체 흐름 요약

```
clone → prd.md 작성 → yaml 2개 반영 → ./init → (Play Console 등록) → 개발 → ./deploy
 1분       5분            3분           10분         5분               ...      5분
```

| Phase | 단계 | 소요 | 자동화 |
|-------|------|------|--------|
| 0 | Clone + 도구 확인 | ~2분 | 수동 |
| 1 | PRD 작성 | ~5분 | 사람/Claude |
| 2 | yaml 2개 반영 | ~3분 | 수동/Claude |
| 3 | ./init | ~10분 | 완전 자동 |
| 4 | Google Play 등록 | ~5분 | 수동 (API 제한) |
| 5 | 개발 | - | - |
| 6 | ./deploy | ~5분 | 완전 자동 |

> 기존 자산(인증서, 키)이 준비돼 있으면 **clone부터 첫 베타 배포까지 약 25분**.

---

## 문제 해결

### ./init 실패

```bash
./init --verbose                                        # 상세 로그
./init --skip-firebase --skip-signing --skip-icon --skip-description   # 단계 스킵
```

### Firebase 프로젝트 생성 실패

```bash
firebase login && firebase projects:list                # CLI 로그인 확인
firebase projects:create my-new-app-20260618            # 수동 생성 후 app_config.yaml에 project_id 입력
```

### iOS 앱 등록 실패

```bash
cat ~/AuthKey_XXXXXXXXXX.p8                              # ASC API 키 확인
# 수동: App Store Connect → My Apps → + 버튼
```

### preflight 경고

```bash
./preflight --verbose         # 상세
./preflight --fix             # 자동 수정 가능 항목 수정
```

자세한 증상별 해결: [TROUBLESHOOTING.md](./guides/TROUBLESHOOTING.md).

---

## 참고 문서

| 문서 | 내용 | 참조 시점 |
|------|------|----------|
| [prd.md](../prd.md) | PRD 템플릿 (앱 정의 SSOT) | Phase 1 |
| [00-PREREQUISITES.md](./00-PREREQUISITES.md) | 도구 설치 상세 | Phase 0 |
| [01-GETTING_STARTED.md](./01-GETTING_STARTED.md) | 처음 쓰는 사람용 온보딩 | Phase 0~3 |
| [02-SPRINT-CHECKLIST.md](./02-SPRINT-CHECKLIST.md) | 4주 스프린트 체크리스트 | Phase 5 |
| [EXTERNAL_SETUP.md](./guides/EXTERNAL_SETUP.md) | 외부 서비스 발급 (Firebase, AdMob, 인증서) | Phase 0·2 |
| [FEATURE_MANAGEMENT.md](./guides/FEATURE_MANAGEMENT.md) | 기능 플래그 상세 | Phase 2·5 |
| [CLI_TOOLS.md](./guides/CLI_TOOLS.md) | CLI 명령 상세 | Phase 3·5·6 |
| [FASTLANE_SETUP.md](./guides/FASTLANE_SETUP.md) | 배포 자동화 상세 | Phase 6 |
| [MODULES.md](./MODULES.md) | 모듈 경계 + 플래그 운영 기준 | 개발 중 |

> 템플릿 자체를 유지보수(패키지 추출, 파생 앱 전파, fastlane repo 핀)하는 문서는
> [reference/maintainer/](./reference/maintainer/) 참조 — 앱을 만드는 데는 필요 없다.
