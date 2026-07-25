# Prerequisites

> 개발 시작 전 설치해야 할 도구들

---

## 필수 도구

### Flutter & Dart

```bash
# 설치 확인
flutter --version  # 3.8.0 이상
dart --version     # 3.0.0 이상

# 환경 진단
flutter doctor
```

설치 안내: https://docs.flutter.dev/get-started/install

---

### 플랫폼별 도구

#### macOS (iOS + Android 개발)

```bash
# Xcode Command Line Tools
xcode-select --install

# Xcode 설치 후
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# CocoaPods
sudo gem install cocoapods
```

- **Xcode**: App Store에서 설치
- **Android Studio**: https://developer.android.com/studio

#### Windows/Linux (Android만)

- **Android Studio**: https://developer.android.com/studio
- Android SDK 설정 완료

---

## 스토어 배포 계정 (출시 시 필수, 자동화 불가)

> 앱을 실제로 스토어에 올리려면 아래 계정/등록이 선행되어야 한다. 모두 Apple/
> Google 포털에서만 처리되는 수동 단계이며, 어떤 스크립트도 대신할 수 없다.

### Apple (App Store)

- **Apple Developer Program 가입** — 연 **$99**.
  https://developer.apple.com/programs/ (개인/조직 선택, 조직은 D-U-N-S 번호 필요 — 발급에 수일 소요될 수 있음)
- 가입 후 **Team ID**(10자) 확인 → `app_config.yaml`의 `platforms.ios.team_id`.
- **유료 애플리케이션 계약(Paid Applications Agreement) + 은행/세금 정보**
  (IAP/구독/유료 앱이면 필수) — App Store Connect → **비즈니스 → 계약/세금/금융**.
  미완료 시 IAP 상품이 심사에 오르지 못해 앱 심사가 거부된다.
  > **계정 단위 1회 서명이다** — 개발자 계정 하나에 한 번만 하면 이후 그 계정으로
  > 내는 **모든 앱은 추가 작업 0**이다. 공용 개발자 계정을 쓰면 **이미 서명됐을
  > 가능성이 높다** — 새 앱마다 다시 할 필요 없다. **자동화 API는 없다**(ASC는 상태
  > 조회 엔드포인트조차 제공하지 않는다). 확인은 위 콘솔 경로에서 계약이 "활성"인지
  > 눈으로 본다.
- App Store Connect **API 키(.p8)** 생성 → `store.apple.api_key_id`/`api_issuer_id`/
  `api_key_file` (자세히는 [FASTLANE_SETUP.md](./guides/FASTLANE_SETUP.md)).

### Google (Play Store)

- **Google Play Developer 등록** — 1회 **$25**.
  https://play.google.com/console/signup
- 앱 레코드는 Play Console에서 **수동 생성** (Play API로는 앱을 만들 수 없음).
- **결제 프로필 + 은행/세금 정보** (IAP/구독/유료 앱이면 필수) — Play Console →
  **결제 설정**에서 판매자 계정(결제 프로필)을 만들고 은행·세금을 등록한다.
  > Apple과 마찬가지로 **계정 단위 1회**다 — 공용 계정이면 이미 완료됐을 가능성이
  > 높고, 이후 앱은 추가 작업이 없다. 자동화 불가, 콘솔 수동.

### 콘텐츠 생성용 (선택)

- **OPENAI_API_KEY**: `./init`의 설명 자동 생성에 사용. 미설정 시 해당 단계가
  **조용히 스킵**되어 placeholder 카피가 남는다 — 출시 전
  `./run generate-description`으로 채우거나 직접 입력할 것.
- **adlab 서버**: `./init`의 아이콘 생성과 `./screenshot --enhance`(마케팅
  목업화)에 사용. 로컬에서 `~/Project/adlab`을 uvicorn으로 띄운다 (기본
  `http://127.0.0.1:8791`, 다른 주소면 `ADLAB_URL`). 미실행 시 아이콘 단계는
  **조용히 스킵** — 출시 전 `./run generate-icon`으로 재생성할 것.

---

## 선택 도구

> 필요한 기능에 따라 설치

### Fastlane (빌드/배포 자동화)

> macOS 전용 (iOS 빌드/서명이 macOS를 요구). 이 템플릿은 CI를 쓰지 않으며
> 빌드/배포/검증은 전부 로컬에서 실행한다.

```bash
# Ruby 확인 (2.7 이상)
ruby --version

# Bundler 설치
gem install bundler

# Fastlane 의존성 설치
# fastlane/ 디렉토리는 별도 repo(raynear/flutter-fastlane)의 클론 산출물 —
# fresh clone에는 없고, ./run 계열 명령 첫 실행 시 project.yaml의
# tooling.fastlane_ref 핀으로 자동 클론된다. 클론된 뒤에:
cd fastlane
bundle install
```

### Firebase CLI

> Firebase 서비스 사용 시

```bash
# npm으로 설치
npm install -g firebase-tools

# 또는 curl로 설치
curl -sL https://firebase.tools | bash

# 로그인
firebase login
```

### FlutterFire CLI

> Firebase 자동 설정용

```bash
dart pub global activate flutterfire_cli

# PATH에 추가 필요시
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

---

## 권장 IDE 설정

### VS Code Extensions

- Flutter
- Dart
- Error Lens
- GitLens
- Thunder Client (API 테스트)

### Android Studio Plugins

- Flutter
- Dart

---

## 설치 확인

```bash
# 전체 확인
flutter doctor -v

# 예상 출력:
# [✓] Flutter (Channel stable, 3.x.x)
# [✓] Android toolchain
# [✓] Xcode (macOS만)
# [✓] Chrome
# [✓] Android Studio
# [✓] VS Code
```

---

## 다음 단계

설치 완료 후 → [01-GETTING_STARTED.md](./01-GETTING_STARTED.md)
