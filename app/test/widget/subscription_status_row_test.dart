// 설정 화면의 구독 상태 행 — 평생 구매(만료일 null)에서도 깨지지 않는지.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:pipecheck/features/settings/views/settings_view.dart';

Widget _host(Settings s) => MaterialApp(home: Scaffold(body: SubscriptionStatusRow(settings: s)));

void main() {
  final base = Settings.initial();

  testWidgets('평생(hasLifetime, 만료일 null)은 예외 없이 Lifetime', (tester) async {
    await tester.pumpWidget(_host(base.copyWith(hasLifetime: true, subscriptionExpiryDate: null)));
    expect(tester.takeException(), isNull);
    expect(find.text('Lifetime'), findsOneWidget);
  });

  testWidgets('열린 구독은 날짜 없이 Active', (tester) async {
    await tester.pumpWidget(_host(base.copyWith(
        subscriptionOpenEnded: true, subscriptionExpiryDate: DateTime(2026, 10, 15))));
    expect(find.text('Active'), findsOneWidget);
    expect(find.textContaining('2026'), findsNothing);
  });

  testWidgets('만료일이 있는 구독은 날짜를 보여 준다', (tester) async {
    await tester.pumpWidget(_host(base.copyWith(subscriptionExpiryDate: DateTime(2026, 11, 8))));
    expect(find.textContaining('2026-11-08'), findsOneWidget);
  });
}
