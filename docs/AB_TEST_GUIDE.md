# A/B 테스트 운영 가이드

> 보일러플레이트의 A/B 테스트 패턴, 자동화 명령, 운영 절차.
>
> **라이프사이클 가이드**: [AB_TEST_LIFECYCLE.md](AB_TEST_LIFECYCLE.md) (기획~정리 6단계)

---

## 개요

보일러플레이트가 권장하는 A/B 테스트 구조는 **코드 레벨 로컬 랜덤 할당 + Firebase Remote Config 킬스위치**다.

```
사용자 첫 실행 → 로컬 50:50 랜덤 할당 → SharedPreferences에 영구 저장
                                          ↓
Remote Config 킬스위치 ON  → 할당된 variant 적용 (control/treatment)
Remote Config 킬스위치 OFF → 강제 control (실험 중단)
```

Firebase A/B Testing 콘솔의 자동 할당은 사용하지 않는다. GA4 user property로 variant를 기록하여 Firebase Analytics에서 세그먼트 비교로 분석한다.

### 왜 이 패턴인가

| 비교 항목 | 코드 레벨 + RC 킬스위치 | Firebase A/B Testing 콘솔 자동 할당 |
|---|---|---|
| variant 할당 시점 | 앱 첫 실행 즉시 | Remote Config fetch 후 |
| 첫 세션 일관성 | 보장 | 첫 fetch 전까지 control |
| 디버그 오버라이드 | 코드에서 직접 가능 | 별도 우회 필요 |
| 콘솔 의존도 | 낮음 (분석만 콘솔) | 높음 (실험 등록/할당 모두 콘솔) |
| 다중 실험 격리 | 코드에서 통제 | 콘솔 조건 의존 |

### 보일러플레이트 내 다른 구현 옵션

보일러플레이트에는 동일한 목적에 사용 가능한 별도 구현이 함께 존재한다:

- `app/packages/ab_testing/` — 백엔드 할당/이벤트 수집용 패키지 (Supabase Edge Function 백엔드는 P1-16.5a에서 철거됨 — 현재 연결 백엔드 없음)

이 가이드는 가장 단순하고 검증된 **로컬 할당 + RC 킬스위치** 패턴 (`app/lib/core/services/ab_test_service.dart`)을 다룬다.

---

## 자동화 가능한 작업 (Fastlane)

### 1. 실험 정의 → Remote Config 동기화

`app/lib/core/services/ab_test_service.dart`의 `Experiment` enum(앱-측 실험 정의 SSOT)에 실험을 정의한 뒤, 해당 항목의 `remoteKey`(킬스위치 키)를 `rc_set`으로 Remote Config에 등록한다.

```bash
cd fastlane

# 실험 킬스위치 파라미터를 Remote Config에 등록
bundle exec fastlane rc_set key:feature_x_enabled value:true description:"feature_x A/B 킬스위치"
```

> 여러 실험을 일괄 등록하려면 `ab_setup` (YAML 정의) 또는 `rc_import` (JSON 템플릿) lane을 활용할 수 있다.

### 2. 킬스위치 제어

```bash
# 특정 실험 비활성화 (킬스위치 OFF → 강제 control)
bundle exec fastlane rc_set key:feature_x_enabled value:false

# 특정 실험 재활성화 (킬스위치 ON)
bundle exec fastlane rc_set key:feature_x_enabled value:true
```

### 3. 상태 확인

```bash
# 현재 Remote Config 상태 출력
bundle exec fastlane rc_list

# AB 관련 파라미터만 조회
bundle exec fastlane ab_list
```

### 4. GA4 Custom Dimension 일괄 등록

variant 값을 분석 가능한 dimension으로 등록한다 (이 단계를 건너뛰면 Explore에서 variant 비교 불가).

```bash
# fastlane/config/ga4_custom_definitions.yml의 모든 dim 등록
bundle exec fastlane ga4_setup

# 등록된 dim 목록 조회
bundle exec fastlane ga4_list
```

### 5. 새 실험 추가 워크플로우

1. `app/lib/core/services/ab_test_service.dart`의 `Experiment` enum에 항목 추가 (앱-측 SSOT)
2. 앱 코드에서 `abTestService.isEnabled(Experiment.xxx)` 분기 + `abTestService.logExposure(Experiment.xxx)` 호출
3. `fastlane/config/ga4_custom_definitions.yml`에 `ab_xxx` user property 추가
4. `bundle exec fastlane rc_set key:xxx_enabled value:true`
5. `bundle exec fastlane ga4_setup`

---

## 수동 필요 작업 (Firebase 콘솔)

### GA4 세그먼트 생성 (분석용)

**경로:** Firebase 콘솔 → Analytics → Explore → 새 탐색 보고서

각 실험마다 세그먼트 2개를 만든다:

1. **Treatment**: User property `ab_xxx` = `treatment`
2. **Control**: User property `ab_xxx` = `control`

이 세그먼트로 핵심 지표를 variant별 비교한다.

### 서비스 계정 권한 (1회 셋업)

GA4 dim 자동 등록을 사용하려면:

- 서비스 계정 JSON 키 발급 (Firebase 콘솔 → 프로젝트 설정 → 서비스 계정)
- GA4 Property에서 해당 서비스 계정에 **편집자** 권한 부여
  (Admin → Property access management)
- `.env`에 `GA4_PROPERTY_ID=<숫자 ID>` 설정

---

## 실험 운영 기준

### 테스트 기간

- 최소 **2주**, variant당 **최소 500명 이상 노출** 권장
- DAU에 따라 필요 기간이 달라짐 — 노출 수가 부족하면 통계 노이즈에 흔들림

### 종료 조건

- 95% 신뢰수준에서 통계적 유의성 확인
- 또는 4주 경과 시 결과와 무관하게 종료 후 판단 (실험 피로 방지)

### 실험 종료 후

1. 결과 분석 (GA4 Explore 세그먼트 비교)
2. 결정: **treatment 채택** / **control 유지** / **재실험**
3. 정리 작업은 [라이프사이클 가이드 ⑥ 정리 단계](AB_TEST_LIFECYCLE.md#%E2%91%A5-정리--2단계-cleanup) 참고

---

## 디버그 & 테스트

### 앱 내 강제 오버라이드 (개발 모드)

```dart
// 강제 treatment
await abTestService.setOverride(Experiment.featureX, true);

// 강제 control
await abTestService.setOverride(Experiment.featureX, false);

// 오버라이드 해제 (원래 할당으로 복원)
await abTestService.clearOverride(Experiment.featureX);
```

오버라이드는 SharedPreferences에 저장되어 앱 재시작 후에도 유지된다. 디버그 메뉴에 토글 UI를 두면 QA에 유용하다.

### 할당 리셋 (테스트용)

SharedPreferences에서 `ab_assignment_*` 키를 삭제하면 다음 앱 실행 시 재할당된다. 한 기기에서 두 variant를 모두 검증할 때 사용.

---

## 아키텍처 요약

```
Experiment enum                      ← 실험 정의 SSOT
(app/lib/core/services/ab_test_service.dart)
              ↓
rc_set (remoteKey)                   ← Remote Config 파라미터 등록
              ↓
Firebase Remote Config               ← 킬스위치 역할 (true/false)
              ↓
ab_test_service.dart                 ← 로컬 랜덤 할당 + 킬스위치 반영
              ↓
GA4 user property (ab_xxx)           ← variant 자동 동기화 (분석용)
              ↓
GA4 Explore                          ← 세그먼트별 지표 비교 (수동 분석)
```

### 관련 파일

- `app/lib/core/services/ab_test_service.dart` — 코어 서비스 + `Experiment` enum (실험 정의 SSOT, 할당, GA 송신, 킬스위치)
- `fastlane/config/ab_experiments.yml` — Firebase A/B Testing 실험 정의 (선택)
- `fastlane/fastfiles/library/remote_config.rb` — `rc_list`, `rc_set`, `rc_import` 등 RC lane
- `fastlane/fastfiles/library/ga4_admin.rb` — `ga4_list`, `ga4_setup` 등 GA4 dim lane
- `fastlane/config/ga4_custom_definitions.yml` — GA4 dim 일괄 등록 config

### 기능 플래그 의존

`AppFeatureConfig.isABTestingEnabled = true`로 활성화. `isFirebaseRemoteConfigEnabled` + `isFirebaseAnalyticsEnabled`도 함께 켜야 킬스위치/송신이 동작한다.
