# 문제 해결 가이드

> 자주 발생하는 문제와 해결 방법

---

## 목차

1. [설치 문제](#설치-문제)
2. [SDK 버전 문제](#sdk-버전-문제)
3. [의존성 문제](#의존성-문제)
4. [코드 생성 문제](#코드-생성-문제)
5. [iOS 빌드 문제](#ios-빌드-문제)
6. [Android 빌드 문제](#android-빌드-문제)
7. [실행 문제](#실행-문제)
8. [CLI 도구 문제](#cli-도구-문제)
9. [배포 게이트 문제](#배포-게이트-문제-preflightinit-hard-fail)

---

## 설치 문제

### Flutter를 찾을 수 없음

```
[ERROR] Flutter SDK를 찾을 수 없습니다
```

**원인:**
- Flutter가 설치되지 않음
- PATH 환경 변수에 Flutter가 없음

**해결:**

```bash
# Flutter 설치 확인
which flutter

# PATH에 Flutter 추가 (macOS/Linux)
export PATH="$PATH:$HOME/flutter/bin"

# 영구 설정 (~/.zshrc 또는 ~/.bashrc에 추가)
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
source ~/.zshrc

# 설치 확인
flutter doctor
```

### Dart를 찾을 수 없음

```
[ERROR] Dart SDK를 찾을 수 없습니다
```

**원인:**
- Dart가 별도로 설치되지 않음 (Flutter와 함께 설치됨)
- PATH 설정 문제

**해결:**

```bash
# Flutter가 설치되어 있다면 Dart는 자동 포함
flutter doctor

# PATH 확인
which dart

# Flutter의 dart 사용
export PATH="$PATH:$HOME/flutter/bin/cache/dart-sdk/bin"
```

---

## SDK 버전 문제

### Flutter SDK 버전이 너무 낮음

```
[ERROR] Flutter SDK 버전이 너무 낮습니다

현재 버전: 3.7.0
필요 버전: 3.8.0 이상
```

**해결:**

```bash
# Flutter 업그레이드
flutter upgrade

# 또는 stable 채널로 전환 후 업그레이드
flutter channel stable
flutter upgrade

# 버전 확인
flutter --version
```

### Dart SDK 버전이 너무 낮음

```
[ERROR] Dart SDK 버전이 너무 낮습니다

현재 버전: 2.19.0
필요 버전: 3.0.0 이상
```

**해결:**

```bash
# Flutter 업그레이드 (Dart도 함께 업데이트)
flutter upgrade

# 버전 확인
dart --version
```

---

## 의존성 문제

### flutter pub get 실패

```
[ERROR] 의존성 설치에 실패했습니다
```

**원인:**
- 인터넷 연결 문제
- pubspec.yaml 문법 오류
- 호환되지 않는 패키지 버전

**해결:**

```bash
# 1. 캐시 정리
flutter clean
flutter pub cache clean

# 2. 의존성 재설치
flutter pub get

# 3. pubspec.yaml 검증
flutter pub deps
```

### 패키지 버전 충돌

```
Because app depends on package_a ^1.0.0 which depends on package_b ^2.0.0,
and app depends on package_b ^3.0.0, version solving failed.
```

**해결:**

```bash
# 1. 의존성 트리 확인
flutter pub deps

# 2. pubspec.yaml에서 버전 조정
# 또는 dependency_overrides 사용 (임시 해결책)
dependency_overrides:
  package_b: ^3.0.0
```

---

## 코드 생성 문제

### build_runner 실행 오류

```
[ERROR] build_runner 실행 중 오류 발생
```

**해결:**

```bash
cd app

# 1. 기존 생성 파일 삭제
dart run build_runner clean

# 2. 충돌 파일 삭제 후 재생성
dart run build_runner build --delete-conflicting-outputs

# 3. 그래도 안 되면 전체 정리
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Freezed 코드 생성 실패

```
Could not generate code for `MyModel` because it has a type error.
```

**원인:**
- 모델 클래스 문법 오류
- import 누락

**해결:**

```dart
// 올바른 Freezed 모델 구조
import 'package:freezed_annotation/freezed_annotation.dart';

part 'my_model.freezed.dart';
part 'my_model.g.dart';

@freezed
class MyModel with _$MyModel {
  const factory MyModel({
    required String id,
    required String name,
  }) = _MyModel;

  factory MyModel.fromJson(Map<String, dynamic> json) =>
      _$MyModelFromJson(json);
}
```

### Drift 데이터베이스 생성 오류

```
Error: The part directive 'database.g.dart' does not match...
```

**해결:**

```bash
# 1. 기존 생성 파일 삭제
rm -f lib/data/datasources/local/database/database.g.dart

# 2. 재생성
dart run build_runner build --delete-conflicting-outputs
```

---

## iOS 빌드 문제

### CocoaPods 오류

```
Error running pod install
```

**해결:**

```bash
cd app/ios

# 1. CocoaPods 캐시 정리
pod deintegrate
rm -rf Pods
rm Podfile.lock

# 2. 재설치
pod install --repo-update

cd ..
flutter run -d ios
```

### Xcode 빌드 오류

```
Xcode build failed due to provisioning profile issues
```

**해결:**

1. Xcode에서 프로젝트 열기: `open ios/Runner.xcworkspace`
2. Runner 타겟 선택
3. Signing & Capabilities 탭에서 Team 설정
4. Provisioning Profile 자동 관리 체크

### iOS 시뮬레이터 문제

```
No iOS device found
```

**해결:**

```bash
# 시뮬레이터 목록 확인
flutter devices

# 시뮬레이터 직접 실행
open -a Simulator

# 특정 시뮬레이터 실행
xcrun simctl boot "iPhone 15"
```

---

## Android 빌드 문제

### Gradle 빌드 실패

```
FAILURE: Build failed with an exception.
```

**해결:**

```bash
cd app/android

# 1. Gradle 캐시 정리
./gradlew clean

# 2. Gradle wrapper 재생성
./gradlew wrapper

cd ..
flutter run -d android
```

### SDK 라이센스 문제

```
Android license status unknown
```

**해결:**

```bash
flutter doctor --android-licenses
# 모든 라이센스에 'y' 입력
```

### NDK 버전 문제

```
NDK version XX.XX.XXXXX is not compatible
```

**해결:**

1. Android Studio → SDK Manager
2. SDK Tools 탭 → NDK (Side by side) 체크
3. 필요한 버전 설치

---

## 실행 문제

### app 디렉토리를 찾을 수 없음

```
[ERROR] app 디렉토리를 찾을 수 없습니다
```

**원인:**
프로젝트 루트가 아닌 다른 디렉토리에서 실행

**해결:**

```bash
# 프로젝트 루트로 이동
cd /path/to/my_project

# 디렉토리 구조 확인
ls -la
# app/ 디렉토리가 보여야 함

./setup
```

### Hot Reload 작동 안 함

**해결:**

```bash
# Flutter 재시작
# 터미널에서 'r' 키 입력 (Hot Reload)
# 'R' 키 입력 (Hot Restart)

# 그래도 안 되면
flutter clean
flutter run
```

---

## CLI 도구 문제

### 실행 권한 없음

```
permission denied: ./setup
```

**해결:**

```bash
chmod +x init setup build deploy feature preflight run

# 또는 dart로 직접 실행
dart run tools/cli/bin/setup.dart
```

### 명령어를 찾을 수 없음

```
command not found: ./setup
```

**원인:**
- 프로젝트 루트가 아님
- 스크립트 파일이 없음

**해결:**

```bash
# 프로젝트 루트 확인
ls -la | grep setup

# 스크립트가 없으면 생성
cat > setup << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_DIR="$SCRIPT_DIR/tools/cli"
cd "$SCRIPT_DIR"
dart run "$CLI_DIR/bin/setup.dart" "$@"
EOF
chmod +x setup
```

---

## 환경별 문제

### macOS에서 권한 문제

```
Operation not permitted
```

**해결:**

1. 시스템 환경설정 → 보안 및 개인 정보 보호 → 개인 정보 보호
2. "전체 디스크 접근 권한"에 터미널 추가

### Windows에서 경로 문제

**해결:**

- 프로젝트 경로에 한글, 공백 없어야 함
- 경로를 짧게 유지 (예: `C:\dev\my_app`)

### Linux에서 권한 문제

```bash
# 실행 권한 추가
chmod +x init setup build deploy feature preflight run

# 또는 sudo 사용 (권장하지 않음)
```

---

## 배포 게이트 문제 (preflight/init hard-fail)

안전 게이트가 잘못된 출시를 막기 위해 의도적으로 중단시키는 경우입니다.

### `./init` — Firebase 재설정 실패로 중단 (B1)

`firebase login`이 안 됐거나 flutterfire가 실패하면 `boilerplate-2024` 설정이
남은 채로 진행되지 않도록 init이 중단합니다.

```bash
firebase login                       # 로그인 확인
./init                               # 재실행
./init --skip-firebase               # Firebase 없이 진행
```

### `./deploy` — 개인정보처리방침 URL 없음 (A1)

production 제출에는 호스팅된 개인정보 URL이 필수입니다.

```bash
./run generate-legal
./run deploy-legal [--target github] # 호스팅 후 URL 자동 도출
# 또는 project.yaml listing.privacy_policy_url에 직접 URL 지정
```

### `./deploy` — placeholder 자격증명 / 패키지명 (B4)

`app_config.yaml`의 `XXXX`/`you@example.com`/`your-org` placeholder나
`com.example.*` 패키지명을 실제 값으로 채우세요 (`project.yaml`, `app_config.yaml`).

### Android release 빌드 — 서명 키 없음 (B2)

`KEYSTORE_PATH` 없이 release를 빌드하면 디버그 서명 AAB(Play 거부)를 막기 위해
gradle이 중단합니다.

```bash
# app_config.yaml의 signing.android.keystore_path 설정 후 ./init (또는 ./run gen-env)
ALLOW_DEBUG_RELEASE_SIGNING=true flutter build appbundle  # 의도적 로컬 테스트만
```

### `./screenshot` — 요청한 시뮬레이터 없음 (B5)

ASC 사이즈 슬롯 누락을 막기 위해 hard-fail합니다.

```bash
# Xcode > Settings > Platforms에서 시뮬레이터 설치, 또는
./screenshot --devices "iPhone 16 Pro Max"   # 설치된 시뮬 지정
./screenshot --allow-missing-devices          # 의도적 부분 캡처
```

---

## 도움 요청

위 해결 방법으로도 문제가 해결되지 않으면:

1. **이슈 등록**: GitHub Issues에 문제 상황 설명
2. **로그 첨부**: `--verbose` 옵션으로 상세 로그 포함
3. **환경 정보**: `flutter doctor -v` 출력 포함

---

## 참고 문서

| 문서 | 설명 |
|------|------|
| [Flutter Docs](https://docs.flutter.dev/) | Flutter 공식 문서 |
| [Dart Docs](https://dart.dev/guides) | Dart 공식 가이드 |
| [00-PREREQUISITES.md](../00-PREREQUISITES.md) | 설치 요구사항 |
| [CLI_TOOLS.md](./CLI_TOOLS.md) | CLI 도구 사용법 |
