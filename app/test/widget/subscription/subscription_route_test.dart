// /subscription 단독 진입(딥링크 콜드 스타트) 닫기 경로 · 요금제 행 시맨틱 · 결제 계정 문구.
//
// 배경: 이 화면은 설정에서 시트로 열리기도 하고 `/subscription` 라우트로 단독 진입하기도 한다.
// 예전엔 Scaffold·닫기 버튼이 없어 단독 진입 시 갇혔고, 구매 성공의 `context.pop()`은
// 쌓인 화면이 없으면 예외를 냈다. 요금제 행은 GestureDetector라 스크린리더가 선택 상태를 못 읽었고,
// 법적 고지가 Android에서도 "App Store account"라고 말했다.

import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:pipecheck/config/app_config.dart';
import 'package:pipecheck/core/router.dart' show Routes;
import 'package:pipecheck/core/services/in_app_purchase_service.dart';
import 'package:pipecheck/core/widgets/buttons/adaptive_button.dart';
import 'package:pipecheck/features/subscription/views/subscription_view.dart';

import '../../support/orange_harness.dart';

ProductDetails _p(String id, String price, double raw) =>
    ProductDetails(id: id, title: id, description: '', price: price, rawPrice: raw, currencyCode: 'USD');

class _BuyOk extends Fake implements InAppPurchaseService {
  @override
  Future<bool> buyProduct(ProductDetails prod) async => true;
}

Future<void> _pumpCold(WidgetTester tester, {InAppPurchaseService? iap}) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Routes.subscription,
    routes: [
      GoRoute(path: Routes.subscription, builder: (_, _) => const SubscriptionView()),
      GoRoute(path: Routes.home, builder: (_, _) => const Scaffold(body: Text('HOME'))),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [inAppPurchaseServiceProvider.overrideWithValue(iap)],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
}

void main() {
  setUpOrange('subscription_route_test');
  setUpAll(() => dotenv.loadFromString(envString: 'TEST=1'));

  setUp(() {
    AppConfig.debugSetConfig({'MONTHLY': 'm', 'YEARLY': 'y', 'LIFETIME': 'l'});
    AppConfig.debugSetProducts([_p('m', r'$1.00', 1), _p('y', r'$8.40', 8.4), _p('l', r'$30.00', 30)]);
  });
  tearDown(() => AppConfig.debugSetProducts([]));

  testWidgets('콜드 스타트: 닫기 버튼이 예외 없이 홈으로 보낸다', (tester) async {
    await _pumpCold(tester);
    expect(find.byType(Material), findsWidgets);
    await tester.tap(find.byKey(const Key('subscription.close')));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(SubscriptionView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('콜드 스타트: 구매에 성공해도 nothing-to-pop 예외 없이 홈으로 간다', (tester) async {
    await _pumpCold(tester, iap: _BuyOk());
    await tester.tap(find.byType(AdaptiveButton).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('시트로 열렸을 때: 닫기 버튼이 시트만 닫고 아래 화면은 남는다', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [inAppPurchaseServiceProvider.overrideWithValue(null)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const SubscriptionView(),
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionView), findsOneWidget);
    await tester.tap(find.byKey(const Key('subscription.close')));
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionView), findsNothing);
    expect(find.text('OPEN'), findsOneWidget);
  });

  testWidgets('요금제 행은 선택 상태를 가진 버튼 그룹이고 안쪽 글자가 이름으로 읽힌다', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpCold(tester);
    SemanticsData rowOf(String title) =>
        tester.getSemantics(find.text(title)).getSemanticsData();

    final monthly = rowOf('Monthly Subscription');
    expect(monthly.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(monthly.hasFlag(SemanticsFlag.isInMutuallyExclusiveGroup), isTrue);
    expect(monthly.hasFlag(SemanticsFlag.isSelected), isTrue); // 기본 선택
    expect(monthly.label, contains('Monthly Subscription'));

    final yearly = rowOf('Yearly Subscription');
    expect(yearly.hasFlag(SemanticsFlag.isSelected), isFalse);

    await tester.tap(find.text('Yearly Subscription'));
    await tester.pump();
    expect(rowOf('Yearly Subscription').hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(rowOf('Monthly Subscription').hasFlag(SemanticsFlag.isSelected), isFalse);
    handle.dispose();
  });

  testWidgets('선택되지 않은 요금제의 갱신 문구는 onSurfaceVariant(대비 확보)로 그린다', (tester) async {
    await _pumpCold(tester);
    final unselected = tester.widget<Text>(find.text('Auto-renews yearly'));
    final scheme = Theme.of(tester.element(find.byType(SubscriptionView))).colorScheme;
    expect(unselected.style?.color, scheme.onSurfaceVariant);
  });

  group('결제 계정 문구는 플랫폼의 스토어 이름을 쓴다', () {
    test('Android는 Google Play, iOS는 App Store', () {
      final android = purchaseTermsKeyFor(TargetPlatform.android);
      final ios = purchaseTermsKeyFor(TargetPlatform.iOS);
      expect(android, contains('Google Play'));
      expect(android, isNot(contains('App Store')));
      expect(ios, contains('App Store'));
    });

    testWidgets('Android에서는 화면에 App Store가 나오지 않는다', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await _pumpCold(tester);
        expect(find.textContaining('Google Play account'), findsOneWidget);
        expect(find.textContaining('App Store account'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null; // 불변식 검사 전에 되돌린다
      }
    });
  });
}
