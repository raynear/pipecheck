# Flutter 버전 호환성 정책

> Flutter BoilerPlate 프로젝트의 버전 관리 및 호환성 정책

---

## 목차

1. [지원 버전](#지원-버전)
2. [버전 정책](#버전-정책)
3. [호환성 테스트](#호환성-테스트)
4. [마이그레이션 가이드](#마이그레이션-가이드)
5. [Breaking Changes 대응](#breaking-changes-대응)

---

## 지원 버전

### 현재 지원 버전

| 구성 요소 | 최소 버전 | 권장 버전 | 테스트된 버전 |
|----------|----------|----------|--------------|
| **Flutter SDK** | 3.8.0 | 최신 stable | 최신 stable (로컬 검증) |
| **Dart SDK** | 3.8.0 | Flutter stable 동봉 버전 | Flutter stable 동봉 버전 |
| **iOS** | 13.0 | 15.0+ | 14.0, 15.0, 16.0, 17.0 |
| **Android** | API 21 (5.0) | API 33+ | API 28, 31, 33, 34 |

### 버전 확인

```bash
# Flutter 버전 확인
flutter --version

# Dart 버전 확인
dart --version

# 프로젝트 요구사항 확인 (pubspec.yaml)
environment:
  sdk: '>=3.8.0 <4.0.0'
```

---

## 버전 정책

### Semantic Versioning (SemVer)

프로젝트는 [Semantic Versioning 2.0.0](https://semver.org/)을 따릅니다.

```
MAJOR.MINOR.PATCH

예: 1.2.3
    │ │ └── PATCH: 버그 수정, 보안 패치
    │ └──── MINOR: 새 기능 추가 (하위 호환)
    └────── MAJOR: Breaking changes (하위 호환 불가)
```

---

## 호환성 테스트

모든 호환성 검증은 로컬에서 수행합니다 (CI/GitHub Actions 미사용).

### 테스트 항목

| 카테고리 | 테스트 항목 | 검증 방법 |
|----------|-----------|----------|
| **빌드** | Android/iOS 빌드 성공 | 로컬 빌드 (`flutter build`) |
| **단위 테스트** | 모든 단위 테스트 통과 | `./run test --unit` |
| **통합 테스트** | 핵심 기능 통합 테스트 | `./run test --integration` |
| **UI 테스트** | 주요 화면 렌더링 | Widget 테스트 |
| **성능** | 성능 회귀 없음 | Benchmark 테스트 |

---

## 마이그레이션 가이드

### Flutter 버전 업그레이드 절차

#### 1. 사전 준비

```bash
# 현재 버전 확인
flutter --version

# 프로젝트 의존성 상태 확인
flutter pub outdated

# Git 브랜치 생성
git checkout -b feature/flutter-upgrade
```

#### 2. Flutter SDK 업그레이드

```bash
# FVM 사용 시 (권장)
fvm install 3.24.0
fvm use 3.24.0

# 또는 직접 업그레이드
flutter upgrade
```

#### 3. 의존성 업데이트

```bash
cd app

# 의존성 업데이트
flutter pub upgrade

# Outdated 패키지 확인
flutter pub outdated

# 주요 패키지 수동 업데이트 (필요 시)
flutter pub upgrade --major-versions
```

#### 4. 코드 마이그레이션

```bash
# Deprecated API 자동 수정
dart fix --apply

# 코드 분석
flutter analyze

# 포맷팅
dart format .
```

#### 5. 테스트 및 검증

```bash
# 코드 생성
./build --clean

# 전체 테스트
./run test

# 빌드 테스트
flutter build apk --debug
flutter build ios --debug --no-codesign
```

#### 6. 완료

```bash
# 커밋
git add .
git commit -m "chore: upgrade to Flutter 3.24.x"

# PR 생성
gh pr create --title "Flutter 3.24.x 업그레이드" --body "..."
```

---

## Breaking Changes 대응

### Breaking Change 감지

```bash
# 업그레이드 전 변경 사항 확인
flutter upgrade --dry-run

# 채널별 변경 사항
flutter channel stable
flutter upgrade
```

### 일반적인 Breaking Changes

#### 1. Deprecated API 교체

```dart
// Before (Deprecated)
RaisedButton(onPressed: () {}, child: Text('Click'))

// After
ElevatedButton(onPressed: () {}, child: Text('Click'))
```

#### 2. Null Safety 관련

```dart
// Before
String name;

// After
String? name;  // nullable
String name = '';  // non-nullable with default
late String name;  // late initialization
```

#### 3. Material 3 마이그레이션

```dart
// Before (Material 2)
ThemeData(
  primarySwatch: Colors.blue,
)

// After (Material 3)
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
)
```

### 도움 받기

Breaking Change로 인한 문제 발생 시:

1. **공식 마이그레이션 가이드 확인**
   - [Flutter Breaking Changes](https://docs.flutter.dev/release/breaking-changes)
   - [Dart Migration Guide](https://dart.dev/guides/language/evolution)

2. **GitHub Issues 검색**
   - 동일 문제 경험자 확인
   - 해결 방법 참조

3. **커뮤니티 지원**
   - Flutter Discord
   - Stack Overflow

4. **프로젝트 이슈 생성**
   - 재현 가능한 예제 포함
   - Flutter doctor 결과 첨부

---

## 의존성 버전 관리

### 주요 의존성 버전

| 패키지 | 현재 버전 | 업데이트 정책 |
|--------|----------|--------------|
| `flutter_riverpod` | ^3.0.3 | Major 신중, Minor 즉시 |
| `go_router` | ^17.0.1 | Minor 즉시 |
| `freezed` | ^3.2.3 | Minor 즉시 |
| `drift` | ^2.21.0 | Minor 테스트 후 |

### 의존성 업데이트 가이드라인

```yaml
# pubspec.yaml 버전 지정 방식

# ✅ 권장: 캐럿 (^) 사용 - Minor/Patch 자동 업데이트
dependencies:
  flutter_riverpod: ^3.0.3

# ⚠️ 주의: 범위 지정 - 필요 시에만
dependencies:
  some_package: ">=1.0.0 <2.0.0"

# ❌ 비권장: 정확한 버전 고정 - 특별한 이유 없이 사용 금지
dependencies:
  some_package: 1.2.3
```

---

## 참고 자료

- [Flutter Release Notes](https://docs.flutter.dev/release/release-notes)
- [Flutter Breaking Changes](https://docs.flutter.dev/release/breaking-changes)
- [Dart Language Evolution](https://dart.dev/guides/language/evolution)
- [pub.dev Version Constraints](https://dart.dev/tools/pub/dependencies)
