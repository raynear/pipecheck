// Feature Configuration 화면 — 스위치가 AppFeatureConfig에 즉시 반영되고, 메뉴가 일괄/프로파일 적용을 한다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/features/settings/views/feature_config_view.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: FeatureConfigView())));
  await tester.pump();
}

Future<void> _menu(WidgetTester tester, String label) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('기능 이름은 is/Enabled를 떼고 단어로 풀어 보여 준다', (tester) async {
    await _pump(tester);
    expect(find.text('Notification'), findsWidgets);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('Multi Language'), findsOneWidget);
  });

  testWidgets('모든 스위치를 뒤집으면 그 값이 AppFeatureConfig에 바로 들어간다', (tester) async {
    await _pump(tester);
    final before = AppFeatureConfig.toMap();
    final switches = find.byType(Switch);
    expect(switches, findsWidgets);
    for (var i = 0; i < switches.evaluate().length; i++) {
      await tester.tap(switches.at(i));
      await tester.pump();
    }
    final after = AppFeatureConfig.toMap();
    // 화면이 다루는 플래그(스위치가 있는 것)는 전부 반대로 바뀌어 있어야 한다.
    final flipped = after.entries.where((e) => before[e.key] != e.value).map((e) => e.key).toSet();
    expect(flipped, containsAll([
      'isNotificationEnabled', 'isReminderEnabled', 'isAuthenticationEnabled', 'isInAppPurchaseEnabled',
      'isSubscriptionEnabled', 'isAdsEnabled', 'isDarkModeEnabled', 'isMultiLanguageEnabled',
      'isFirebaseEnabled', 'isLocationEnabled', 'isABTestingEnabled',
    ]));
    for (final k in flipped) {
      expect(after[k], isNot(before[k]), reason: k);
    }
  });

  testWidgets('메뉴: 전체 끄기/켜기와 프로파일 적용이 상태를 바꾼다', (tester) async {
    await _pump(tester);
    await _menu(tester, 'Disable All');
    expect(AppFeatureConfig.toMap().values.where((v) => v), isEmpty);
    await _menu(tester, 'Enable All');
    expect(AppFeatureConfig.toMap().values.where((v) => !v), isEmpty);
    for (final p in ['minimal', 'standard', 'premium', 'enterprise']) {
      await _menu(tester, 'Profile: $p');
    }
    await _menu(tester, 'Print Summary');
    expect(tester.takeException(), isNull);
  });
}
