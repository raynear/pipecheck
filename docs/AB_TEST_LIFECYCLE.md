# A/B 테스트 라이프사이클 가이드

> 실험 한 건의 전체 흐름 — 기획부터 정리까지.
>
> **기술 가이드**: [AB_TEST_GUIDE.md](AB_TEST_GUIDE.md) (fastlane 명령, 콘솔 설정 등)

---

## 6단계 한눈에

```
① 기획       ② 정의 + 코드     ③ 등록 + 배포
     ↓              ↓               ↓
   가설 1줄    enum + isEnabled   rc_set + ga4_setup
   지표 1개      분기 추가          빌드 → 스토어
   판정 기준    flutter analyze    트래픽 할당 시작
     ↓              ↓               ↓
   ④ 측정       ⑤ 결정          ⑥ 정리
     ↓              ↓               ↓
   2주+ 대기    winner 선택       Stage 1: freeze
   GA4 Explore   유의성 확인       Stage 2: delete
   세그먼트 비교  채택 / 폐기       (1주 간격)
```

---

## ① 기획 (5분)

### 산출물 (한 페이지 안)

- **가설**: "X를 바꾸면 지표 Y가 N% 개선된다"
- **측정 지표**: 핵심 1개 (활성화율 / 완주율 / 매출 / D7 retention 등)
- **결정 기준**: 사전 정의 — "treatment가 control 대비 +5%p + p<0.05 → 채택"
- **위험**: 잘못 나오면 어떤 손실?
- **대상**: 신규만? 전체?

### 체크리스트

- [ ] 가설이 한 줄로 표현 가능
- [ ] 측정 지표가 GA에 이미 잡히는지 확인 (없으면 ②에서 추가)
- [ ] 결정 기준을 데이터 보기 **전에** 정함 (p-hacking 방지)
- [ ] 위험이 매출/리텐션 핵심 축인지 평가

### 흔한 함정

- ❌ 여러 지표를 동시에 보면서 "뭐든 좋아진 것 채택" → p-hacking
- ❌ 가설 없이 "한번 해보자" → 결과 해석 불가
- ❌ 측정 지표가 너무 거리감 (예: UI 변경 → 매출. 인과 약함)

---

## ② 정의 + 코드 작성 (30분~2시간)

### 작업 순서

1. `app/lib/core/services/ab_test_service.dart`의 `Experiment` enum(앱-측 실험 정의 SSOT)에 항목 추가 — `remoteKey`(킬스위치 키)와 `trafficPercent`(treatment 비율) 지정:

   ```dart
   featureX('feature_x_enabled', 50),
   ```

2. 화면에 분기 + 노출 측정 추가:

   ```dart
   // 화면 진입 시 한 번 (initState 또는 첫 영향 받는 지점)
   abTestService.logExposure(Experiment.featureX);

   // 분기
   if (abTestService.isEnabled(Experiment.featureX)) {
     // treatment
   } else {
     // control
   }
   ```

3. `flutter analyze` 통과 확인

### 노출 측정 위치 원칙

- `logExposure`는 **사용자가 실제로 영향받는 시점**에 호출
- 화면 전체에 영향 = `initState`에서 한 번
- 특정 조건일 때만 영향 = 그 조건 진입점에서만 (예: 4회차+ 사용자에게만 게이트 → 4회차 진입 시 호출)
- 세션당 1회만 발생 (`_exposureLogged` Set으로 서비스 내장)

### 흔한 함정

- ❌ `isEnabled`만 호출하고 `logExposure` 빼먹음 → variant 효과 받는 사용자 수 모름
- ❌ `build()` 안에서 `logExposure` 호출 → 매 rebuild마다 시도 (1회 보장 있어도 좋은 패턴 아님). `initState`로
- ❌ control branch가 비어 있음 = "treatment만 코드, control은 default" → 분기 동등성 보장 안 됨
- ❌ 두 실험 분기를 겹쳐 두고 동시에 켬 → interaction effect

---

## ③ 등록 + 배포 (10분 + 스토어 심사)

### 자동화 명령

```bash
cd fastlane

# 1. Remote Config 킬스위치 등록 (실험 중단 안전망)
bundle exec fastlane rc_set key:feature_x_enabled value:true description:"새 기능 A/B 킬스위치"

# 2. GA4 Custom Definition 등록 (variant 분석 가능하게)
#    fastlane/config/ga4_custom_definitions.yml에 항목 추가 후
bundle exec fastlane ga4_setup

# 3. 현재 상태 확인
bundle exec fastlane rc_list
bundle exec fastlane ga4_list
```

### 사전 1회 작업 (이미 했으면 스킵)

- `.env`에 `GA4_PROPERTY_ID=<숫자 ID>`
- 서비스 계정에 GA4 Property "편집자" 권한 부여
- `GOOGLE_APPLICATION_CREDENTIALS` 서비스 계정 JSON 경로 설정

### 빌드 + 배포

- `flutter build` → 스토어 심사 → 출시
- 출시 후 새 사용자부터 trafficPercent 비율로 자동 할당

### 흔한 함정

- ❌ GA4 dim 등록 안 함 → user property 데이터는 송신되지만 Explore에서 dimension으로 못 씀
- ❌ 등록 후 출시 안 한 채 데이터 기다림 → 사용자 앱에는 분기 없음. 영원히 변화 0
- ❌ 출시 후 GA4 dim 늦게 등록 → 등록 시점 이후 데이터만 잡힘 (소급 적용 ❌). 같이 진행

---

## ④ 측정 (최소 2주)

### 대기 기준

- 최소 **2주** + variant당 **500명 이상 노출**
- 일찍 보면 통계 노이즈에 흔들림

### Firebase Console 분석 위치

`Firebase 콘솔 → Analytics → Explore → 새 탐색 보고서`

1. 세그먼트 2개 만들기:
   - Treatment: User property `ab_xxx` = `treatment`
   - Control: User property `ab_xxx` = `control`
2. 측정 지표를 row/value에 배치
3. 비교 그래프 또는 표

### 실험 중단 (위험 발견 시)

```bash
# 즉시 강제 control (코드 배포 없이)
bundle exec fastlane rc_set key:feature_x_enabled value:false
```

다음 Remote Config fetch (앱 시작 시 또는 fetch interval 후)부터 모든 사용자가 control로 강제 전환된다.

### 흔한 함정

- ❌ 1주 후 "좋아 보임" → 종료. 통계 노이즈 가능성
- ❌ p-value 모르고 차이만 보고 결정 → 진짜 효과 아닐 수도
- ❌ 같은 사용자가 두 variant 사이를 오감 (디버그 override로 비교) → 측정 오염

---

## ⑤ 결정 (1시간)

### 4가지 결과

| 상황 | 결정 |
|---|---|
| treatment 우세 + 유의함 | ✅ treatment 채택 |
| control 우세 + 유의함 | ❌ treatment 폐기 |
| 차이 없음 + 충분한 표본 | ❌ treatment 폐기 (현 상태 유지) |
| 차이 있어 보임 + 표본 부족 | ⏸️ 2주 더 운영 |

### 판단 자료

- 핵심 지표 (①에서 정한 1개) **만** 봄. 부차 지표는 직감 보조용
- variant당 표본 ≥ 500
- 4주 넘어가면 결과 무관하게 종료 (실험 피로)

### 흔한 함정

- ❌ 결정 기준 사전 정의 무시하고 "느낌상" 결정
- ❌ 부차 지표가 좋아 보인다고 핵심 지표 무시
- ❌ "조금만 더 기다리면..." 무한 연장

---

## ⑥ 정리 — 2단계 cleanup

### Stage 1 — Freeze (즉시, 1~2주 유지)

분기 코드 그대로 두고 값을 하드코딩:

```dart
// Before
if (abTestService.isEnabled(Experiment.featureX)) { ... }

// After (treatment 채택)
if (true) { ... }   // ← 명시적 강제, 다음 단계에서 if 자체 제거

// 또는 control 채택
if (false) { ... }
```

- Remote Config 킬스위치는 **유지** (rollback 보존)
- 모니터링: regression 발생 여부, 매출/리텐션 변동
- 위급 시 `rc_set value:false` 한 줄로 즉시 되돌리기

### Stage 2 — Delete (1주 후, regression 없으면)

코드/설정 정리:

1. 분기 if 제거 → loser branch 코드 삭제, winner branch만 인라인
2. 더 이상 쓰이지 않는 helper 메소드/위젯/import 삭제
3. `Experiment` enum 항목 제거
4. Remote Config 파라미터 삭제 (Firebase 콘솔 또는 향후 lane)
6. GA4 dim은 **보존** (과거 데이터 분석용. archive 안 함)
7. `flutter analyze` 통과 확인

### 왜 단계로?

| 패턴 | 문제 |
|---|---|
| 즉시 삭제만 | winner에 숨은 regression 발견 시 rollback 불가 |
| flag freeze만 영구 | 분기 코드 = 영구 tech debt. 1년 후 "이 if 뭐였지?" |

**둘 다 한다**. freeze로 안전, cleanup으로 깨끗.

### 흔한 함정

- ❌ Stage 1 끝낸 후 cleanup 안 하고 다음 실험으로 넘어감 → 분기 코드 누적 (tech debt 폭증)
- ❌ Stage 1을 영원히 유지 = 영원한 dead code
- ❌ GA4 dim까지 archive → 과거 데이터 분석 불가

---

## 신규 실험 추가 시 체크리스트

```
[ ] ① 가설 1줄 + 지표 1개 + 결정 기준 문서화
[ ] ② Experiment enum 항목 추가 (앱-측 SSOT)
[ ] ② 화면에 isEnabled 분기 + logExposure 추가
[ ] ② flutter analyze 통과
[ ] ③ ga4_custom_definitions.yml에 ab_xxx user property 추가
[ ] ③ rc_set key:xxx_enabled value:true
[ ] ③ ga4_setup
[ ] ③ 빌드 + 스토어 출시
[ ] ④ 2주 대기 + GA4 Explore 세그먼트 비교
[ ] ⑤ 결정 (treatment / control / 연장)
[ ] ⑥ Stage 1: 분기 값 하드코딩, 1주 모니터링
[ ] ⑥ Stage 2: 분기 코드/enum/RC 제거, flutter analyze 통과
```

---

## 관련 파일

- `app/lib/core/services/ab_test_service.dart` — 코어 서비스 + `Experiment` enum (실험 정의 SSOT, 할당, GA 송신, 킬스위치)
- `fastlane/config/ab_experiments.yml` — Firebase A/B Testing 실험 정의 (선택)
- `fastlane/fastfiles/library/remote_config.rb` — `rc_list`, `rc_set` 등 RC lane
- `fastlane/fastfiles/library/ga4_admin.rb` — `ga4_list`, `ga4_setup` 등 GA4 dim lane
- `fastlane/config/ga4_custom_definitions.yml` — GA4 dim 일괄 등록 config
- 디버그 override UI: 설정 화면에 토글을 두면 QA가 두 variant를 모두 검증 가능
