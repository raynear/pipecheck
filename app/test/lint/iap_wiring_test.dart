import 'dart:io';

import 'package:test/test.dart';

/// 구독 권리 재조회 배선 가드 — 지워도 컴파일·단위 테스트는 초록이고 갱신·해지·환불이
/// 앱에 반영되지 않는다. main.dart 전체를 띄울 수 없어 소스 구조로 못 박는다
/// (notification_cold_start_wiring_test.dart와 같은 방식).
void main() {
  final main = File('lib/main.dart').readAsStringSync();

  test('부팅 때 IAP 서비스를 즉시 만든다(initState)', () {
    final init = RegExp(r'void initState\(\)[\s\S]*?\n  \}').firstMatch(main)!.group(0)!;
    expect(init, contains('ref.read(inAppPurchaseServiceProvider)'));
  });

  test('앱 복귀(resumed)마다 스토어 권리를 다시 읽는다', () {
    final resumed = RegExp(r'AppLifecycleState\.resumed\) \{[\s\S]*?\n    \}').firstMatch(main)!.group(0)!;
    expect(resumed, contains('inAppPurchaseServiceProvider'));
    expect(resumed, contains('refreshEntitlement()'));
  });
}
