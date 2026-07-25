# Beta 배포 가이드

TestFlight (iOS)와 Google Play 테스트 트랙을 활용한 Beta 배포 전략 가이드입니다.

---

## 목차

1. [배포 트랙 이해하기](#1-배포-트랙-이해하기)
2. [Firebase App Distribution (권장 테스트 배포)](#2-firebase-app-distribution-권장-테스트-배포)
3. [iOS TestFlight 배포](#3-ios-testflight-배포)
4. [Android 테스트 트랙 배포](#4-android-테스트-트랙-배포)
5. [Staged Rollout (단계적 출시)](#5-staged-rollout-단계적-출시)
6. [자동화 워크플로우](#6-자동화-워크플로우)
7. [베스트 프랙티스](#7-베스트-프랙티스)

---

## 1. 배포 트랙 이해하기

### iOS 배포 경로

```
빌드 → TestFlight (내부) → TestFlight (외부) → App Store 심사 → Production
        └─ 즉시 사용      └─ 베타 심사 필요      └─ 정식 심사
```

| 단계 | 테스터 | 심사 | 제한 |
|------|--------|------|------|
| 내부 테스트 | App Store Connect 팀원 | 없음 | 100명 |
| 외부 테스트 | 이메일 초대 또는 공개 링크 | 베타 심사 | 10,000명 |
| Production | 모든 사용자 | 정식 심사 | 무제한 |

### Android 배포 경로

```
빌드 → Internal → Closed (Alpha) → Open (Beta) → Production
        └─ 즉시      └─ 초대 기반     └─ 공개 가입    └─ Staged 가능
```

| 트랙 | 테스터 | 심사 | 제한 |
|------|--------|------|------|
| Internal | Google Groups 또는 이메일 | 없음 | 100명 |
| Closed (Alpha) | 초대된 테스터 그룹 | 없음 | 무제한 |
| Open (Beta) | 누구나 참여 가능 | 없음 | 무제한 |
| Production | 모든 사용자 | 자동 검토 | Staged Rollout |

---

## 2. Firebase App Distribution (권장 테스트 배포)

> **스토어를 거치지 않는 가장 빠른 테스트 배포 방법**. 로컬에서 distribute 레인을 실행해 테스터에게 배포합니다.

### 2.1 개요

```
로컬 distribute 레인 실행 → Firebase App Distribution → 테스터 알림 → 설치
```

| 특징 | iOS | Android |
|------|-----|---------|
| 배포 방식 | Ad Hoc IPA | APK |
| 심사 | 없음 | 없음 |
| 설치 | 링크 클릭 | 링크 클릭 |
| 제약 | UDID 등록 필요 | 없음 |
| 빌드 넘버 | build_number 파라미터 (스토어와 독립) | build_number 파라미터 (스토어와 독립) |

### 2.2 Fastlane 명령어

```bash
# Android만 Firebase App Distribution에 배포
bundle exec fastlane distribute_android

# iOS만 Firebase App Distribution에 배포
bundle exec fastlane distribute_ios

# 양 플랫폼 모두 배포
bundle exec fastlane distribute

# 빌드 넘버 지정
bundle exec fastlane distribute_android build_number:42
```

### 2.3 CI/CD 자동 배포 (미사용)

이 보일러플레이트는 GitHub Actions를 사용하지 않습니다. `.github/workflows/firebase-distribution.yml`은 트리에 존재하지만 실행되지 않으며, 배포는 §2.2의 distribute 레인을 로컬에서 직접 실행합니다.

### 2.4 테스터 관리

**Firebase Console에서 관리:**
1. Firebase Console → App Distribution → Testers & Groups
2. 그룹 생성 (예: `qa-testers`, `stakeholders`)
3. 이메일로 테스터 추가

**테스터 설치 방법:**
1. Firebase에서 초대 이메일 수신
2. Firebase App Tester 앱 설치 (또는 웹 링크)
3. 새 빌드가 올라오면 자동 알림

### 2.5 릴리스 노트

distribute 레인 실행 시 자동 생성됩니다:
```
Build #42 | PR #15: 로그인 화면 리디자인
Commit: abc1234
2026-02-15 14:30
```

### 2.6 스토어 배포와의 차이점

| | Firebase App Distribution | TestFlight / Play Store |
|---|---|---|
| **트리거** | 로컬 `distribute` 레인 실행 | 로컬 `./deploy` 실행 |
| **빌드 넘버** | `build_number` 파라미터 | pubspec.yaml 기반 |
| **용도** | 일상 테스트, PR 리뷰 | 최종 출시 전 확인 |
| **속도** | 즉시 (심사 없음) | iOS: 심사 대기 가능 |

### 2.7 설정 가이드

초기 설정은 [EXTERNAL_SETUP.md](../guides/EXTERNAL_SETUP.md#firebase-app-distribution-설정)를 참조하세요.

---

## 3. iOS TestFlight 배포

### 3.1 빌드 및 업로드

```bash
# TestFlight에 빌드 업로드
bundle exec fastlane build_and_upload_ios
```

**내부 동작:**
1. `sync_version_ios` - 버전 동기화
2. `build_ios` - IPA 빌드
3. `upload_to_testflight` - TestFlight 업로드
4. `upload_dsym` - 크래시 심볼 업로드

### 3.2 테스터 관리

**내부 테스터 (App Store Connect):**
- App Store Connect → 사용자 및 액세스 → 팀원 추가
- 역할: Admin, Developer, Marketing 등
- 빌드 업로드 즉시 접근 가능

**외부 테스터:**
1. App Store Connect → TestFlight → 외부 테스트
2. 그룹 생성 → 테스터 추가 (이메일)
3. 빌드 선택 → 테스트 시작
4. **베타 심사 대기** (최초 또는 주요 변경 시)

### 3.3 공개 링크 (권장)

```
App Store Connect → TestFlight → 외부 테스트 → 그룹 → 공개 링크 활성화
```

- 링크 공유로 누구나 참여 가능
- 10,000명 제한
- 90일 후 자동 만료

### 3.4 TestFlight 자동화

> `fastlane/`은 버전 핀된 클론(git 미추적)이므로 `fastlane/Fastfile`에 커스텀 레인을 추가해도 재클론 시 사라집니다.

외부 테스터 그룹 배포는 `build_and_upload_ios`로 TestFlight에 업로드한 뒤, App Store Connect → TestFlight에서 빌드를 그룹에 할당합니다 (§3.2 참조).

---

## 4. Android 테스트 트랙 배포

### 4.1 Internal Testing (내부 테스트)

```bash
# 내부 테스트 트랙에 업로드 (기본)
bundle exec fastlane build_and_upload_android
```

**특징:**
- 가장 빠른 배포 (심사 없음)
- 최대 100명 테스터
- Google 계정으로 초대

### 4.2 Closed Testing (비공개 테스트)

```bash
# Alpha 트랙에 업로드
bundle exec fastlane build_and_upload_alpha_testing

# 또는 Internal → Alpha 승격
bundle exec fastlane promote_to_alpha
```

**특징:**
- 테스터 그룹 기반 (이메일 리스트, Google Groups)
- 제한 없는 테스터 수
- 심사 없음

### 4.3 Open Testing (공개 테스트)

```bash
# Internal → Beta 승격
bundle exec fastlane promote_to_beta

# 특정 버전으로 승격
bundle exec fastlane promote_to_beta_with_version version_code:123
```

**특징:**
- Play Store에서 "오픈 테스트" 참여 가능
- 리뷰 작성 불가 (본 앱 리뷰에 영향 없음)
- 선착순 제한 가능

### 4.4 Production 배포

```bash
# Production 트랙에 직접 업로드
bundle exec fastlane build_and_upload_android_production

# 또는 Alpha → Production 승격
bundle exec fastlane promote_to_production
```

---

## 5. Staged Rollout (단계적 출시)

### 5.1 Android Staged Rollout

**개념:** Production 사용자 중 일부에게만 먼저 배포

```
10% → 문제 없음 → 50% → 문제 없음 → 100%
      ↓ 문제 발생           ↓ 문제 발생
      중단 또는 롤백         중단 또는 롤백
```

**Fastlane 명령어:**

```bash
# 10% 롤아웃
bundle exec fastlane staged_rollout rollout:0.1

# 50% 확대
bundle exec fastlane staged_rollout rollout:0.5

# 전체 출시
bundle exec fastlane staged_rollout rollout:1.0

# 롤아웃 중단 (문제 발생 시)
bundle exec fastlane halt_rollout
```

### 5.2 iOS Staged Rollout (Phased Release)

**개념:** 7일에 걸쳐 자동으로 단계적 출시

| 일차 | 비율 |
|------|------|
| Day 1 | 1% |
| Day 2 | 2% |
| Day 3 | 5% |
| Day 4 | 10% |
| Day 5 | 20% |
| Day 6 | 50% |
| Day 7 | 100% |

**설정 방법:**
1. App Store Connect → 앱 버전 → 배포
2. "자동 업데이트를 위한 단계적 출시" 선택

**Fastlane 자동화:**
```ruby
# 심사 제출 시 단계적 출시 설정
deliver(
  phased_release: true,  # 단계적 출시 활성화
  automatic_release: false,  # 수동 출시 (심사 후)
  submit_for_review: true
)
```

### 5.3 권장 Rollout 전략

**새 기능 출시:**
```
Internal → Alpha (1-3일) → Beta (3-7일) → Production 10% → 50% → 100%
```

**긴급 버그 수정:**
```
Internal (확인) → Production 100%
```

**주요 업데이트:**
```
Internal → Alpha (테스터 피드백) → Beta (공개 피드백) → Production Staged
```

---

## 6. 자동화 워크플로우

> 이 보일러플레이트는 GitHub Actions를 사용하지 않습니다. 모든 배포·승격은 로컬에서 fastlane 레인을 직접 실행합니다.

### 6.1 베타 배포 (로컬 실행)

```bash
# iOS → TestFlight
bundle exec fastlane build_and_upload_ios

# Android → Internal 트랙
bundle exec fastlane build_and_upload_android
```

스토어 통합 배포(preflight → build → upload)는 루트의 `./deploy`를 사용합니다.

### 6.2 트랙 승격 (로컬 실행)

```bash
# Internal → Alpha / Beta 승격
bundle exec fastlane promote_to_alpha
bundle exec fastlane promote_to_beta

# Production 단계적 출시 (10%)
bundle exec fastlane staged_rollout rollout:0.1
```

---

## 7. 베스트 프랙티스

### 7.1 버전 관리 전략

```
Production:  1.0.0
Beta:        1.1.0-beta.1, 1.1.0-beta.2
Development: 1.1.0-dev.1
```

```bash
# 버전 증가 명령어
bundle exec fastlane bump_version type:patch  # 1.0.0 → 1.0.1
bundle exec fastlane bump_version type:minor  # 1.0.0 → 1.1.0
bundle exec fastlane bump_version type:major  # 1.0.0 → 2.0.0
```

### 7.2 테스터 피드백 수집

**iOS:**
- TestFlight 내장 피드백 기능
- 스크린샷 + 설명 자동 수집
- App Store Connect에서 확인

**Android:**
- Firebase App Distribution (권장)
- Play Console 내부 피드백
- 커스텀 피드백 폼

### 7.3 크래시 모니터링

```dart
// 베타 빌드에서 상세 로깅 활성화
if (kDebugMode || isBetaBuild) {
  FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
}
```

### 7.4 체크리스트

**베타 배포 전:**
- [ ] 모든 테스트 통과
- [ ] 릴리스 노트 작성
- [ ] 크래시 모니터링 설정
- [ ] 테스터 그룹 준비

**Rollout 전:**
- [ ] 베타 피드백 검토
- [ ] 크래시율 < 1%
- [ ] 주요 버그 해결
- [ ] 성능 지표 확인

**Production 출시 후:**
- [ ] 크래시율 모니터링 (24시간)
- [ ] 사용자 리뷰 확인
- [ ] Rollout 비율 조정
- [ ] 문제 시 즉시 중단

---

## Fastlane 명령어 요약

### Firebase App Distribution (테스트 배포)

| 명령어 | 설명 |
|--------|------|
| `bundle exec fastlane distribute` | iOS + Android 모두 배포 |
| `bundle exec fastlane distribute_android` | Android APK 배포 |
| `bundle exec fastlane distribute_ios` | iOS Ad Hoc IPA 배포 |

### iOS (스토어 배포)

| 명령어 | 설명 |
|--------|------|
| `bundle exec fastlane build_and_upload_ios` | TestFlight 업로드 |
| `bundle exec fastlane upload_ios` | IPA만 업로드 |

### Android (스토어 배포)

| 명령어 | 설명 |
|--------|------|
| `bundle exec fastlane build_and_upload_android` | Internal 트랙 업로드 |
| `bundle exec fastlane build_and_upload_alpha_testing` | Alpha 트랙 업로드 |
| `bundle exec fastlane promote_to_alpha` | Internal → Alpha |
| `bundle exec fastlane promote_to_beta` | Internal → Beta |
| `bundle exec fastlane promote_to_production` | Alpha → Production |
| `bundle exec fastlane staged_rollout rollout:0.1` | Staged Rollout 10% |
| `bundle exec fastlane halt_rollout` | Rollout 중단 |

---

## 참고 자료

- [TestFlight 개요](https://developer.apple.com/testflight/)
- [Google Play 테스트 트랙](https://support.google.com/googleplay/android-developer/answer/9845334)
- [Fastlane deliver](https://docs.fastlane.tools/actions/deliver/)
- [Fastlane supply](https://docs.fastlane.tools/actions/supply/)
