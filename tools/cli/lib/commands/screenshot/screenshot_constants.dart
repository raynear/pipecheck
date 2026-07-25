/// 스크린샷 명령어의 기본 설정값.
class ScreenshotConstants {
  ScreenshotConstants._();

  /// 기본 iOS 디바이스 목록 (ASC 필수 해상도: 6.9" iPhone + 13" iPad).
  /// 설치된 Xcode에 없는 이름이면 디바이스 탐색이 안내를 출력한다 —
  /// `--devices`로 가용 시뮬레이터를 지정할 것.
  static const String defaultDevices =
      'iPhone 16 Pro Max,iPad Pro 13-inch (M4)';

  /// 기본 언어 목록.
  static const String defaultLanguages = 'ko,en';

  /// 기본 출력 디렉토리 — 경로 SSOT (P1-17b).
  ///
  /// `<root>/screenshots/{platform}/{language}/` 레이아웃은 하니스
  /// (app/test/screenshot)가 만들고, iOS는 deliver `screenshots_path`
  /// (`<root>/screenshots/ios`)가 그대로 읽는다.
  /// (구 값 'fastlane/screenshots/'는 gitignored fastlane 클론 내부라
  ///  deliver가 읽는 경로와 불일치했음)
  static const String defaultOutput = 'screenshots';

  /// 기본 통합 테스트 파일 경로 — 실제 테스트 진입점
  /// (구 값은 드라이버 파일을 타깃으로 지정하는 오류였음).
  static const String defaultTestFile =
      'test/screenshot/examples/example_screenshot_test.dart';
}
