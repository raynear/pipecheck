# Getting Started (상세 온보딩)

> 프로젝트 시작부터 첫 실행까지 5분 가이드.
> **배포까지의 최단 경로(골든 패스)는 [quick-start.md](./quick-start.md)가 기준** — 내용이 다르면 그쪽을 따른다.

---

## 시작 전 요구사항

| 구분 | 최소 버전 | 확인 명령 |
|------|----------|----------|
| **Flutter SDK** | stable 최신 권장 | `flutter --version` |
| **Dart SDK** | 3.8.0 이상 (`app/pubspec.yaml` 기준) | `dart --version` |
| **Git** | - | `git --version` |

> 자세한 설치 가이드: [00-PREREQUISITES.md](./00-PREREQUISITES.md)

---

## Step 1: 프로젝트 시작

> **가장 빠른 길 — `provision` 한 줄 (권장):** 새 앱 레포 생성 + rename + fastlane
> submodule 확보 + `bundle install`까지 자동화한다. GitHub Template("Use this
> template")·git clone은 fastlane submodule **내용을 복사하지 않는 함정**이 있는데
> `provision`이 이를 해결한다.
> ```bash
> ~/Project/boiler_plate/scripts/provision --name "My App" \
>   --package "com.raynear.myapp" --dir ~/Project/my_app
> ```
> 아래 방법 A/B는 provision을 쓰지 않는 수동 경로다. 정전 절차: [quick-start.md](./quick-start.md).

### 방법 A: GitHub Template 사용 (수동)

1. [boiler_plate 리포지토리](https://github.com/[username]/boiler_plate)로 이동
2. **"Use this template"** 버튼 클릭
3. 새 리포지토리 이름 입력 (예: `my_awesome_app`)
4. 로컬로 Clone:

```bash
git clone https://github.com/[your-username]/my_awesome_app.git
cd my_awesome_app
```

### 방법 B: Git Clone

```bash
# 직접 Clone
git clone https://github.com/[username]/boiler_plate.git my_awesome_app
cd my_awesome_app

# Git 히스토리 초기화 (선택)
rm -rf .git
git init
git add .
git commit -m "Initial commit from boiler_plate template"
```

---

## Step 2: 프로젝트 초기화 (./init)

`project.yaml`(앱 정체성)과 `app_config.yaml`(인프라)을 편집한 후 초기화 명령을 실행합니다:

> **사전 조건:** Firebase를 켠 채로 초기화하면 `./init`이 Firebase를 새
> 프로젝트로 재설정하며, 실패 시 **하드 실패(exit 1)** 한다. 미리
> `firebase login`을 해두거나, Firebase 없이 진행하려면 `./init --skip-firebase`.
> Apple Team ID(`app_config.yaml`의 `platforms.ios.team_id`)를 채워두면 iOS
> 서명(DEVELOPMENT_TEAM)도 함께 설정된다. → [00-PREREQUISITES.md](./00-PREREQUISITES.md)

```bash
# 1. project.yaml 편집 (앱 이름, Bundle ID, 설명 등 — 정체성은 이 파일 소관)
vi project.yaml

# 2. app_config.yaml 편집 (플랫폼, 서비스, 서명 등 인프라)
vi app_config.yaml

# 3. Firebase 로그인 (Firebase 사용 시 1회)
firebase login

# 4. 프로젝트 초기화
./init
```

**./init이 수행하는 작업 (순서):**

```
1. project.yaml + app_config.yaml 읽기 (project.yaml 우선)
2. 프로젝트 이름 변경 — 패키지명/iOS Bundle ID/Android applicationId/
   Kotlin package+디렉토리/import 경로 자동 업데이트 (실패 시 하드 실패)
3. 기능 프로파일 적용 (app_feature_config 플래그)
4. 환경 산출물 생성 (app/config/env/.env.{debug,profile,release})
   + Privacy 매니페스트 + 딥링크 네이티브 선언
5. iOS 서명 설정 (Matchfile + DEVELOPMENT_TEAM ← team_id)
6. 의존성 설치 (flutter pub get, 실패 시 하드 실패)
7. 코드 생성 (Freezed/Drift/JSON — app/build.sh, 실패 시 하드 실패)
8. 앱 아이콘 생성 (project.yaml icon.prompt + adlab 서버 실행 중일 때)
9. 스토어 설명/메타데이터/연령등급/법적 문서 생성
10. Firebase 재설정 — flutterfire configure로 새 프로젝트에 재구성하고
    google-services.json project_id를 검증, 불일치/실패 시 하드 실패 (B1)
11. App Store Connect 앱 레코드 등록 (produce — ASC 자격증명 있을 때)
```
> 자세한 전·후 과정은 [quick-start.md](./quick-start.md) 참조.

### 개별 명령어 (필요시)

```bash
# 설정만 실행 (이름 변경 없이)
./setup

# 이름만 변경
./run rename my_awesome_app

# 환경 검증만
./setup --check-env

# 상세 로그 출력
./setup --verbose
```

### 이름 규칙

```
✅ 올바른 예시:
   - my_todo_app
   - fitness_tracker
   - daily_journal

❌ 잘못된 예시:
   - MyTodoApp (대문자 불가)
   - my-todo-app (하이픈 불가)
   - 1_todo_app (숫자로 시작 불가)
```

---

## Step 3: 앱 실행

```bash
# app 디렉토리로 이동
cd app

# 앱 실행
flutter run

# 또는 특정 디바이스 선택
flutter run -d chrome    # 웹 브라우저
flutter run -d ios       # iOS 시뮬레이터
flutter run -d android   # Android 에뮬레이터
```

### 첫 실행 화면

앱이 정상적으로 실행되면 다음 화면이 표시됩니다:
- 홈 화면 (기본 기능 목록)
- 설정 화면 (테마, 언어 설정)

---

## Step 4: 기능 설정 (선택)

### 현재 기능 상태 확인

```bash
./feature status
```

### 기능 활성화/비활성화

```bash
# 광고 활성화
./feature enable ads

# 알림 비활성화
./feature disable notification

# 새 기능 모듈 생성
./feature generate -n profile --full
```

### 기본 설정 상태

| 기능 | 기본값 | 설명 |
|------|--------|------|
| **인증** | ON | 생체인증/PIN |
| **Firebase** | OFF | Analytics, Crashlytics |
| **광고** | OFF | 테스트 ID 설정됨 |
| **구독/IAP** | OFF | 플레이스홀더 |
| **알림** | OFF | 로컬/푸시 알림 |

---

## 다음 단계

### 앱 커스터마이징

| 파일 | 용도 |
|------|------|
| `app/pubspec.yaml` | 앱 이름, 버전, 의존성 |
| `app/lib/config/app_feature_config.dart` | 기능 플래그 ON/OFF |
| `app/lib/core/design/` | 테마, 색상, 타이포그래피 |
| `project.yaml` / `app_config.yaml` / `.env` (루트) | 사용자 편집 설정 (앱 정체성 / 인프라 / 시크릿) |
| `app/config/env/.env.debug` | 자동 생성 산출물 (`project.yaml`/`app_config.yaml`에서 `./build`가 생성 — 손 편집 금지) |

### 새 기능 추가

```bash
# 기본 구조 생성
./feature generate -n payment

# 전체 구조 생성 (model, viewmodel 포함)
./feature generate -n payment --full

# 코드 생성 실행
cd app && ./build.sh
```

### 배포 준비

```bash
# Fastlane 설정 (선택)
cd fastlane
bundle install
bundle exec fastlane test      # 테스트 실행
# 배포는 프로젝트 루트에서 ./deploy (통합 오케스트레이터)
```

---

## 자주 발생하는 문제

### SDK 버전 오류

```
[ERROR] Flutter SDK 버전이 너무 낮습니다
```

**해결:**
```bash
flutter upgrade
# 또는
flutter channel stable && flutter upgrade
```

### 의존성 설치 실패

```
[ERROR] 의존성 설치에 실패했습니다
```

**해결:**
```bash
# 1. 인터넷 연결 확인
# 2. pubspec.yaml 유효성 확인
# 3. Flutter 환경 확인
flutter doctor

# 캐시 정리 후 재시도
flutter clean
flutter pub get
```

### 코드 생성 오류

```
[ERROR] build_runner 실행 중 오류 발생
```

**해결:**
```bash
cd app
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### iOS CocoaPods 오류

```bash
cd app/ios
pod deintegrate
pod install --repo-update
cd ..
flutter run -d ios
```

### app 디렉토리를 찾을 수 없습니다

**원인:** 프로젝트 루트가 아닌 다른 디렉토리에서 실행

**해결:**
```bash
# 프로젝트 루트로 이동
cd /path/to/my_awesome_app
./setup
```

---

## 참고 문서

| 문서 | 설명 |
|------|------|
| [00-PREREQUISITES.md](./00-PREREQUISITES.md) | 설치 요구사항 상세 |
| [TEMPLATE-GUIDE.md](./guides/TEMPLATE-GUIDE.md) | 템플릿 구조 설명 |
| [FEATURE_MANAGEMENT.md](./guides/FEATURE_MANAGEMENT.md) | 기능 관리 상세 |
| [EXTERNAL_SETUP.md](./guides/EXTERNAL_SETUP.md) | 외부 서비스 연동 |
| [FASTLANE_SETUP.md](./guides/FASTLANE_SETUP.md) | 배포 자동화 |
| [02-SPRINT-CHECKLIST.md](./02-SPRINT-CHECKLIST.md) | 개발 체크리스트 |

---

## 도움이 필요하신가요?

- 문서 확인: `docs/` 디렉토리
- 이슈 등록: GitHub Issues
- 명령어 도움말: `./setup --help`, `./feature --help`
