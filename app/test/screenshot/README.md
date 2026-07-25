# Screenshot Automation Framework

Flutter 앱의 App Store 스크린샷을 자동으로 캡처하는 프레임워크입니다.

## 기능

- 다국어 스크린샷 자동 캡처 (한국어, 영어 등)
- 다크/라이트 테마 지원
- Provider override를 통한 상태 모킹
- 유연한 설정 시스템
- 재사용 가능한 유틸리티 함수

## 디렉토리 구조

```
test/screenshot/
├── README.md                          # 이 문서
├── screenshot_driver.dart             # 스크린샷 저장 드라이버
├── screenshot_test_base.dart          # 테스트 베이스 클래스
├── config/
│   └── screenshot_config.dart         # 설정 관리
├── providers/
│   └── mock_providers_base.dart       # 모킹 베이스 클래스
├── utils/
│   └── screenshot_utils.dart          # 유틸리티 함수
└── examples/
    └── example_screenshot_test.dart   # 예제 테스트
```

## 빠른 시작

### 1. 테스트 파일 생성

`test/screenshot/` 디렉토리에 새 테스트 파일을 생성합니다:

```dart
// test/screenshot/my_screenshot_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'screenshot_test_base.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Korean Screenshots', (tester) async {
    // 테스트 구현
  });
}
```

### 2. 테스트 실행

```bash
# iOS 시뮬레이터에서 실행
flutter drive \
  --driver=test/screenshot/screenshot_driver.dart \
  --target=test/screenshot/my_screenshot_test.dart \
  -d <simulator_id>

# Android 에뮬레이터에서 실행
flutter drive \
  --driver=test/screenshot/screenshot_driver.dart \
  --target=test/screenshot/my_screenshot_test.dart \
  -d <emulator_id>
```

### 3. 스크린샷 확인

스크린샷은 다음 경로에 저장됩니다:

```
<root>/screenshots/   # 경로 SSOT (P1-17b) — deliver screenshots_path가 읽는 레이아웃
├── ios/
│   ├── ko/
│   │   ├── 01_home.png
│   │   └── 02_settings.png
│   └── en/
│       ├── 01_home.png
│       └── 02_settings.png
└── android/
    ├── ko/
    │   └── ...
    └── en/
        └── ...
```

## 상세 사용법

### 설정 커스터마이징

```dart
import 'config/screenshot_config.dart';

void main() {
  // 설정 커스터마이징
  ScreenshotConfig.instance.configure(
    outputDir: '../screenshots', // 기본값 — ./run screenshot이 SCREENSHOT_OUTPUT으로 덮어씀
    supportedLocales: [
      ScreenshotLocale(locale: Locale('ko', 'KR'), code: 'ko', name: 'Korean'),
      ScreenshotLocale(locale: Locale('en', 'US'), code: 'en', name: 'English'),
      ScreenshotLocale(locale: Locale('ja', 'JP'), code: 'ja', name: 'Japanese'),
    ],
    defaultTheme: ThemeMode.dark,
    navigationWaitMs: 1500,
    continueOnFailure: true,
  );
}
```

### Provider Overriding

```dart
import 'providers/mock_providers_base.dart';

final container = ProviderContainer(
  overrides: [
    // Settings override
    settingsProvider.overrideWith(
      () => MockSettingsNotifier(
        locale: const Locale('ko', 'KR'),
        themeMode: ThemeMode.dark,
        isPremium: true,
      ),
    ),

    // 앱별 provider override
    myFeatureProvider.overrideWith(() => MockMyFeatureProvider()),
  ],
);
```

### 유틸리티 함수 사용

```dart
import 'utils/screenshot_utils.dart';

// 스크린샷 캡처
await takeScreenshot(tester, '01_home', 'ko');

// 위젯 대기
await pumpUntilFound(tester, find.byType(HomeView));

// 프레임 펌프 (애니메이션 있는 화면용)
await pumpFrames(tester, frameCount: 30);

// 탭 선택
await selectTab(tester, 1);
```

### Scene 기반 테스트

```dart
// 씬 정의
final scenes = [
  ScreenshotScene(
    id: '01',
    name: 'home_idle',
    description: 'Home screen idle state',
    waitForWidget: HomeView,
  ),
  ScreenshotScene(
    id: '02',
    name: 'home_active',
    description: 'Home screen active state',
    waitForWidget: HomeView,
  ),
  ScreenshotScene(
    id: '03',
    name: 'settings',
    description: 'Settings screen',
    route: '/settings',
    waitForWidget: SettingsView,
  ),
];

// 간단한 테스트 러너 사용
runScreenshotTests(
  scenes: scenes,
  buildOverrides: (locale, theme) => [
    settingsProvider.overrideWith(
      () => MockSettingsNotifier(locale: locale, themeMode: theme),
    ),
  ],
);
```

## 앱별 확장

### 커스텀 Mock Provider 생성

```dart
// my_mock_providers.dart
import 'providers/mock_providers_base.dart';

class MyMockFeatureProvider extends MyFeatureNotifier {
  final MyFeatureState _fixedState;

  MyMockFeatureProvider(this._fixedState);

  @override
  MyFeatureState build() => _fixedState;

  // 실제 동작 방지
  @override
  Future<void> doSomething() async {}
}
```

### 커스텀 Mock 데이터

```dart
class MyMockDataProvider extends MockDataProviderBase {
  MyMockDataProvider({super.locale});

  List<MyModel> getMockItems() {
    return [
      MyModel(id: '1', name: localized('항목 1', 'Item 1')),
      MyModel(id: '2', name: localized('항목 2', 'Item 2')),
    ];
  }
}
```

## 팁 & 트러블슈팅

### 애니메이션이 있는 화면

`pumpAndSettle()`은 애니메이션이 무한히 실행되는 화면에서 타임아웃됩니다. 대신 `pumpFrames()`를 사용하세요:

```dart
// Bad - 무한 애니메이션에서 타임아웃
await tester.pumpAndSettle();

// Good - 지정된 프레임만 펌프
await pumpFrames(tester, frameCount: 30);
```

### 네비게이션

GoRouter를 사용하는 경우 BuildContext에서 `go()`를 호출해야 합니다:

```dart
final homeViewFinder = find.byType(HomeView);
final context = tester.element(homeViewFinder.first);
context.go('/settings');
```

### 스크린샷이 저장되지 않음

1. `screenshot_driver.dart`가 올바른 위치에 있는지 확인
2. 출력 디렉토리 권한 확인
3. 디바이스 ID가 올바른지 확인

### Feature Flag 설정

스크린샷 테스트 전에 방해가 되는 기능들을 비활성화하세요:

```dart
AppFeatureConfig.isAuthenticationEnabled = false;
AppFeatureConfig.isOnboardingEnabled = false;
AppFeatureConfig.isAdsEnabled = false;
```

## 참고

- [Flutter Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- [Riverpod Testing](https://riverpod.dev/docs/essentials/testing)
- [easy_localization](https://pub.dev/packages/easy_localization)
