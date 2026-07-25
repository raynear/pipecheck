# A/B Testing Package

독립적인 A/B 테스팅 및 Feature Flag 관리 패키지입니다.

## 특징

- ✅ **플랫폼 독립적**: 어떤 백엔드든 사용 가능 (Provider 인터페이스)
- ✅ **효율적인 캐싱**: SharedPreferences로 할당 정보 캐싱
- ✅ **배치 이벤트 처리**: 효율적인 이벤트 전송
- ✅ **타입 안전성**: Freezed로 완전한 타입 안전성
- ✅ **위젯 통합**: ABTestWrapper로 쉽게 UI 변형 테스트

## 설치

```yaml
dependencies:
  ab_testing:
    path: packages/ab_testing
```

## 사용법

### 1. Provider 구현

```dart
// Firebase Remote Config 예제
class FirebaseRemoteConfigExperimentProvider implements ExperimentProvider {
  // ... 구현
}
```

### 2. 서비스 초기화

```dart
final abTestingService = ABTestingService(
  provider: experimentProvider,
  prefs: sharedPreferences,
  getUserId: () => currentUser?.id ?? '',
);
```

### 3. 위젯에서 사용

```dart
ABTestWrapper(
  experimentName: 'button_color_test',
  abTestingService: abTestingService,
  builder: (variant, config) {
    return variant == 'blue' 
      ? BlueButton() 
      : GreenButton();
  },
)
```

### 4. Feature Flag

```dart
FeatureFlagWrapper(
  flagKey: 'new_feature',
  abTestingService: abTestingService,
  child: NewFeatureWidget(),
  fallback: OldFeatureWidget(),
)
```

### 5. 이벤트 추적

```dart
// 노출 추적
abTestingService.trackEvent('button_viewed');

// 전환 추적
abTestingService.trackConversion(revenue: 10.99);
```

## Provider 인터페이스

다른 백엔드를 사용하려면 `ExperimentProvider` 인터페이스를 구현하면 됩니다:

- Firebase Remote Config
- LaunchDarkly
- Optimizely
- 자체 서버

## 설정 옵션

```dart
ABTestingConfig(
  cacheDuration: Duration(hours: 1),
  eventFlushInterval: Duration(seconds: 30),
  maxQueueSize: 100,
)
```