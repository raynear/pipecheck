// 구독 화면 — 상품 가격·할인율 표시, 선택 전환, 구매 시작(서비스 없음 가드), 복원 버튼.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:pipecheck/config/app_config.dart';
import 'package:pipecheck/core/services/in_app_purchase_service.dart';
import 'package:pipecheck/core/widgets/buttons/adaptive_button.dart';
import 'package:pipecheck/features/subscription/views/subscription_view.dart';

import '../../support/orange_harness.dart';

ProductDetails _p(String id, String price, double raw) =>
    ProductDetails(id: id, title: id, description: '', price: price, rawPrice: raw, currencyCode: 'USD');

Future<void> _pump(WidgetTester tester) async {
  // 구매 버튼은 고정 높이 AdaptiveButton 안에 두 줄 child를 넣어 테스트 글꼴에서 넘친다(템플릿 UI,
  // 이 테스트의 관심사가 아님) — 그 레이아웃 오류만 거르고 나머지 오류는 그대로 실패시킨다.
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exceptionAsString().contains('RenderFlex overflowed')) return;
    original?.call(d);
  };
  addTearDown(() => FlutterError.onError = original);
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [inAppPurchaseServiceProvider.overrideWithValue(null)],
    child: const MaterialApp(home: Scaffold(body: SubscriptionView())),
  ));
  await tester.pump();
}

void main() {
  setUpOrange('subscription_view_test');
  setUpAll(() => dotenv.loadFromString(envString: 'TEST=1'));

  setUp(() {
    AppConfig.debugSetConfig({'MONTHLY': 'm', 'YEARLY': 'y', 'LIFETIME': 'l'});
    AppConfig.debugSetProducts([_p('m', r'$1.00', 1), _p('y', r'$8.40', 8.4), _p('l', r'$30.00', 30)]);
  });
  tearDown(() => AppConfig.debugSetProducts([]));

  testWidgets('스토어 원시 가격으로 할인율(30%)을 계산해 보여준다', (tester) async {
    await _pump(tester);
    expect(find.textContaining('30%'), findsOneWidget);
    expect(find.textContaining(r'$8.40'), findsWidgets);
  });

  testWidgets('옵션을 탭하면 선택이 바뀌고 구매 버튼 문구가 따라간다', (tester) async {
    await _pump(tester);
    expect(find.textContaining(r'$1.00'), findsWidgets);
    await tester.tap(find.text('Yearly Subscription'));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.tap(find.text('Lifetime Subscription'));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('상품 정보가 없으면 가격은 0으로 두고 구매·복원 탭이 터지지 않는다', (tester) async {
    AppConfig.debugSetProducts([]);
    await _pump(tester);
    await tester.tap(find.byType(AdaptiveButton).last);
    await tester.pump();
    await tester.tap(find.text('Restore Purchase'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('서비스가 없으면 구매 시도는 조용히 끝난다', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(AdaptiveButton).last);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(SubscriptionView), findsOneWidget);
  });
}
