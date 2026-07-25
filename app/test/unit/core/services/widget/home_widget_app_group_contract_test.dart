// App Group ID 3자 문자열 일치 계약 (INV-H1).
//
// 홈 위젯 데이터 공유가 동작하려면 (1) 메인 앱 entitlement, (2) 위젯 확장
// entitlement, (3) Dart [HomeWidgetService.appGroupId] 이 셋이 **정확히 동일한**
// App Group ID를 가져야 한다. 하나라도 어긋나면 iOS가 공유 컨테이너 접근을
// 거부해 위젯이 조용히 빈 데이터를 읽는다(런타임 크래시 없는 무증상 실패).
//
// 원본 결함(승격 전): 메인 앱 Runner.entitlements에 App Group이 아예 없었고
// (메인 앱 write 불가), Dart 상수·확장 entitlement가 코드 리뷰 없이 드리프트할 수
// 있었다. 이 테스트가 그 3자 결합을 기계 검증으로 못박아 재발을 CI에서 잡는다.
//
// 값은 하드코딩하지 않는다 — entitlement에서 읽어 서로 같은지만 본다.
// 따라서 ./init 이 번들 ID를 리네임해도(예: group.com.foo.bar) 세 파일이 함께
// 바뀌기만 하면 통과하고, 하나라도 빠지면 실패한다.

import 'dart:io';

import 'package:pipecheck/core/services/widget/home_widget_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// entitlements plist의 `com.apple.security.application-groups` 배열에서 첫
/// `group.*` 문자열을 뽑는다. (없으면 null.)
String? _appGroupOf(String plistPath) {
  final content = File(plistPath).readAsStringSync();
  final match = RegExp(r'<string>(group\.[^<]+)</string>').firstMatch(content);
  return match?.group(1);
}

void main() {
  // flutter test는 패키지 루트(app/)에서 돈다.
  const runnerEntitlements = 'ios/Runner/Runner.entitlements';
  const widgetEntitlements = 'ios/widgetExtension.entitlements';

  group('App Group ID 3자 일치 (INV-H1)', () {
    test('메인 앱 Runner.entitlements에 App Group이 선언돼 있다', () {
      expect(File(runnerEntitlements).existsSync(), isTrue,
          reason: 'Runner.entitlements missing');
      expect(_appGroupOf(runnerEntitlements), isNotNull,
          reason: 'Main app has no application-group → cannot write shared '
              'container that the widget reads.');
    });

    test('위젯 확장 entitlement에 App Group이 선언돼 있다', () {
      expect(_appGroupOf(widgetEntitlements), isNotNull,
          reason: 'Widget extension has no application-group.');
    });

    test('메인 앱 == 위젯 확장 App Group', () {
      expect(_appGroupOf(runnerEntitlements), _appGroupOf(widgetEntitlements),
          reason: 'Main app and widget extension must share the SAME app '
              'group or data sharing silently fails.');
    });

    test('Dart appGroupId == entitlement App Group', () {
      expect(HomeWidgetService.appGroupId, _appGroupOf(widgetEntitlements),
          reason: 'HomeWidgetService.appGroupId drifted from the native '
              'entitlement — setAppGroupId would target the wrong container.');
    });
  });
}
