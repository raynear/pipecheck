# Google Analytics 이벤트 설계 가이드

Firebase Analytics를 사용한 효과적인 앱 분석을 위한 이벤트 설계 가이드입니다.

## 목차

1. [기본 개념](#1-기본-개념)
2. [자동 수집 이벤트](#2-자동-수집-이벤트)
3. [권장 이벤트](#3-권장-이벤트)
4. [커스텀 이벤트 설계](#4-커스텀-이벤트-설계)
5. [이벤트 구현](#5-이벤트-구현)
6. [대시보드 설정](#6-대시보드-설정)
7. [분석 전략](#7-분석-전략)

---

## 1. 기본 개념

### 이벤트 구조

```
이벤트명 (event_name)
├── 파라미터 1 (parameter)
├── 파라미터 2
└── 파라미터 N
```

### 네이밍 규칙

| 규칙 | 좋은 예 | 나쁜 예 |
|------|---------|---------|
| snake_case 사용 | `button_click` | `buttonClick` |
| 동사_명사 형식 | `view_item` | `item_viewed` |
| 40자 이내 | `complete_onboarding` | `user_has_completed_the_onboarding_flow` |
| 영문 소문자만 | `add_to_cart` | `Add_To_Cart` |

### 파라미터 규칙

- 최대 25개 파라미터/이벤트
- 파라미터명: 40자 이내
- 문자열 값: 100자 이내
- 숫자 값: 권장

---

## 2. 자동 수집 이벤트

Firebase가 자동으로 수집하는 이벤트 (설정 불필요):

| 이벤트 | 설명 | 용도 |
|--------|------|------|
| `first_open` | 앱 최초 실행 | 신규 사용자 추적 |
| `session_start` | 세션 시작 | 활성 사용자 측정 |
| `app_update` | 앱 업데이트 | 버전별 사용자 분포 |
| `app_remove` | 앱 삭제 (Android) | 이탈 분석 |
| `os_update` | OS 업데이트 | 호환성 분석 |
| `screen_view` | 화면 조회 | 화면별 방문 분석 |

> 💡 `screen_view`는 자동 수집되지만, 화면 이름을 명시적으로 설정하면 더 정확합니다.

---

## 3. 권장 이벤트

Google이 권장하는 표준 이벤트 (분석 리포트 자동 생성):

### 온보딩/인증

| 이벤트 | 트리거 시점 | 필수 파라미터 |
|--------|-------------|---------------|
| `tutorial_begin` | 온보딩 시작 | - |
| `tutorial_complete` | 온보딩 완료 | - |
| `sign_up` | 회원가입 완료 | `method` |
| `login` | 로그인 성공 | `method` |

```dart
// 예시: 회원가입
FirebaseAnalytics.instance.logSignUp(signUpMethod: 'email');

// 예시: 로그인
FirebaseAnalytics.instance.logLogin(loginMethod: 'google');
```

### 이커머스 (구독/인앱결제)

| 이벤트 | 트리거 시점 | 필수 파라미터 |
|--------|-------------|---------------|
| `view_item` | 상품 상세 조회 | `items` |
| `add_to_cart` | 장바구니 추가 | `items`, `value`, `currency` |
| `begin_checkout` | 결제 시작 | `items`, `value`, `currency` |
| `purchase` | 결제 완료 | `transaction_id`, `value`, `currency`, `items` |

```dart
// 예시: 구독 상품 조회
FirebaseAnalytics.instance.logViewItem(
  items: [
    AnalyticsEventItem(
      itemId: 'premium_monthly',
      itemName: 'Premium 월간 구독',
      itemCategory: 'subscription',
      price: 4900,
    ),
  ],
  currency: 'KRW',
  value: 4900,
);

// 예시: 구독 완료
FirebaseAnalytics.instance.logPurchase(
  transactionId: 'txn_123456',
  currency: 'KRW',
  value: 4900,
  items: [
    AnalyticsEventItem(
      itemId: 'premium_monthly',
      itemName: 'Premium 월간 구독',
    ),
  ],
);
```

### 콘텐츠 참여

| 이벤트 | 트리거 시점 | 필수 파라미터 |
|--------|-------------|---------------|
| `share` | 콘텐츠 공유 | `content_type`, `item_id` |
| `search` | 검색 실행 | `search_term` |
| `select_content` | 콘텐츠 선택 | `content_type`, `item_id` |

---

## 4. 커스텀 이벤트 설계

### 4.1 MVP 필수 이벤트 템플릿

앱 유형에 따른 권장 커스텀 이벤트:

#### 📝 생산성 앱 (투두, 메모 등)

```dart
// 핵심 기능 사용
'create_item'       // 항목 생성
  - item_type: String     // 'task', 'note', 'reminder'
  - has_due_date: bool    // 마감일 설정 여부

'complete_item'     // 항목 완료
  - item_type: String
  - completion_time_hours: int  // 생성~완료 소요시간

'delete_item'       // 항목 삭제
  - item_type: String
  - item_age_days: int    // 생성 후 경과일

// 사용자 행동 패턴
'use_feature'       // 기능 사용
  - feature_name: String  // 'filter', 'sort', 'search', 'export'
```

#### 🏃 건강/피트니스 앱

```dart
'start_activity'    // 활동 시작
  - activity_type: String // 'running', 'walking', 'cycling'

'complete_activity' // 활동 완료
  - activity_type: String
  - duration_minutes: int
  - distance_km: double

'log_health_data'   // 건강 데이터 기록
  - data_type: String     // 'weight', 'water', 'sleep'
  - value: double
```

#### 📊 콘텐츠/미디어 앱

```dart
'view_content'      // 콘텐츠 조회
  - content_type: String  // 'article', 'video', 'image'
  - content_id: String
  - content_category: String

'engage_content'    // 콘텐츠 참여
  - engagement_type: String // 'like', 'comment', 'save'
  - content_id: String

'consume_content'   // 콘텐츠 소비 완료
  - content_type: String
  - consumption_time_seconds: int
  - completion_rate: double  // 0.0 ~ 1.0
```

### 4.2 이벤트 설계 체크리스트

새 이벤트 추가 시 확인:

- [ ] 이미 존재하는 권장 이벤트가 아닌가?
- [ ] 이벤트명이 명확하고 일관성 있는가?
- [ ] 필요한 파라미터가 모두 포함되었는가?
- [ ] 파라미터 값이 분석에 유용한가?
- [ ] PII(개인식별정보)가 포함되지 않았는가?

### 4.3 피해야 할 패턴

```dart
// ❌ 나쁜 예: 너무 구체적
'click_blue_submit_button_on_signup_page'

// ✅ 좋은 예: 범용적 + 파라미터로 구분
'button_click'
  - button_name: 'submit'
  - screen_name: 'signup'

// ❌ 나쁜 예: PII 포함
'user_search'
  - search_term: 'john@email.com'

// ✅ 좋은 예: PII 제외
'user_search'
  - search_term: '***@***'  // 마스킹
  - search_type: 'email'
```

---

## 5. 이벤트 구현

### 5.1 Boilerplate 통합

보일러플레이트의 기본 Analytics 래퍼는 `lib/core/services/firebase_service.dart`(`FirebaseService.logEvent` / `logScreenView`). 앱 특화 이벤트는 아래처럼 `analytics_service.dart`를 새로 만들어 활용:

```dart
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // 화면 추적
  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  // 커스텀 이벤트
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  // === 앱 특화 이벤트 ===

  // 온보딩
  static Future<void> logOnboardingStart() async {
    await _analytics.logTutorialBegin();
  }

  static Future<void> logOnboardingComplete() async {
    await _analytics.logTutorialComplete();
  }

  // 핵심 기능
  static Future<void> logCreateItem({
    required String itemType,
    bool hasDueDate = false,
  }) async {
    await logEvent(
      name: 'create_item',
      parameters: {
        'item_type': itemType,
        'has_due_date': hasDueDate,
      },
    );
  }

  static Future<void> logCompleteItem({
    required String itemType,
    required int completionTimeHours,
  }) async {
    await logEvent(
      name: 'complete_item',
      parameters: {
        'item_type': itemType,
        'completion_time_hours': completionTimeHours,
      },
    );
  }

  // 기능 사용
  static Future<void> logFeatureUse(String featureName) async {
    await logEvent(
      name: 'use_feature',
      parameters: {'feature_name': featureName},
    );
  }

  // 에러 추적
  static Future<void> logError({
    required String errorType,
    required String errorMessage,
    String? screenName,
  }) async {
    await logEvent(
      name: 'app_error',
      parameters: {
        'error_type': errorType,
        'error_message': errorMessage.substring(0, 100), // 100자 제한
        if (screenName != null) 'screen_name': screenName,
      },
    );
  }
}
```

### 5.2 사용 예시

```dart
// 화면 진입 시
@override
void initState() {
  super.initState();
  AnalyticsService.logScreenView('home');
}

// 항목 생성 시
void _createTask() {
  // ... 로직 ...
  AnalyticsService.logCreateItem(
    itemType: 'task',
    hasDueDate: _selectedDate != null,
  );
}

// 기능 사용 시
void _onFilterTap() {
  AnalyticsService.logFeatureUse('filter');
  // ... 필터 로직 ...
}
```

---

## 6. 대시보드 설정

### 6.1 Firebase Console 설정

1. **Firebase Console** → 프로젝트 선택 → **Analytics**

2. **맞춤 정의** → **맞춤 측정기준** 생성:
   - `item_type` - 항목 유형
   - `feature_name` - 기능명
   - `screen_name` - 화면명

3. **맞춤 측정항목** 생성 (숫자 값):
   - `completion_time_hours` - 완료 소요시간
   - `value` - 금액

### 6.2 핵심 보고서 설정

**퍼널 분석** (사용자 여정):
```
온보딩 시작 → 온보딩 완료 → 첫 항목 생성 → 첫 항목 완료
```

**유지율 분석**:
- Day 1, Day 7, Day 30 리텐션
- 기능별 사용 빈도

**수익 분석** (인앱결제/구독):
```
상품 조회 → 결제 시작 → 결제 완료
```

---

## 7. 분석 전략

### 7.1 MVP 단계 핵심 지표

| 지표 | 측정 방법 | 목표 |
|------|-----------|------|
| DAU/MAU | `session_start` | 비율 20%+ |
| 온보딩 완료율 | `tutorial_complete` / `tutorial_begin` | 70%+ |
| 핵심 기능 사용률 | `create_item` / DAU | 50%+ |
| Day 1 리텐션 | Firebase 자동 | 40%+ |
| Day 7 리텐션 | Firebase 자동 | 20%+ |

### 7.2 분석 주기

**일간 확인:**
- DAU
- 크래시 발생 여부
- 에러 이벤트

**주간 확인:**
- 신규 vs 재방문 비율
- 기능별 사용 빈도
- 퍼널 전환율

**월간 확인:**
- MAU 추세
- 리텐션 코호트
- 수익 분석 (해당 시)

### 7.3 A/B 테스트 연동

Firebase Remote Config + Analytics로 A/B 테스트:

```dart
// Remote Config에서 변형 가져오기
final variant = FirebaseRemoteConfig.instance.getString('onboarding_variant');

// 변형 로깅
AnalyticsService.logEvent(
  name: 'experiment_exposure',
  parameters: {
    'experiment_name': 'onboarding_flow',
    'variant': variant,
  },
);
```

---

## 부록: 이벤트 명세서 템플릿

새 이벤트 추가 시 문서화:

```markdown
### 이벤트: [이벤트명]

**설명:** [이 이벤트가 측정하는 것]

**트리거 시점:** [언제 발생하는지]

**파라미터:**
| 파라미터명 | 타입 | 필수 | 설명 | 예시 값 |
|-----------|------|------|------|---------|
| param1 | String | Y | ... | ... |

**사용 예시:**
```dart
// 코드 예시
```

**분석 용도:** [이 데이터로 무엇을 알 수 있는지]
```

---

## 참고 자료

- [Firebase Analytics 공식 문서](https://firebase.google.com/docs/analytics)
- [권장 이벤트 목록](https://support.google.com/analytics/answer/9267735)
- [이벤트 파라미터 가이드](https://support.google.com/analytics/answer/9234069)
