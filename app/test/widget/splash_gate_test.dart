// 시니어 리뷰 1008 — 스플래시가 소유하는 시작 게이트.
//
// H6 : 점검 모드·강제 업데이트 다이얼로그는 스플래시가 이동하기 **전에** 검사하고, 차단되면
//      이동하지 않는다 (예전엔 스플래시 위에 띄운 다이얼로그가 replace 때 함께 사라졌다).
// M3 : 스플래시 이동 전에 도착한 딥링크(콜드 스타트 포함)는 보관했다가 이동 뒤에 소비한다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/router.dart';
import 'package:pipecheck/core/services/deep_link_service.dart';
import 'package:pipecheck/core/services/force_update_service.dart';
import 'package:pipecheck/core/services/maintenance_service.dart';
import 'package:pipecheck/core/services/privacy_consent_service.dart';
import 'package:pipecheck/core/widgets/dialogs/privacy_consent_dialog.dart';
import 'package:pipecheck/core/services/whats_new_service.dart';
import 'package:pipecheck/features/splash/index.dart';

import '../support/orange_harness.dart';

Future<GoRouter> _pump(
  WidgetTester tester, {
  bool maintenance = false,
  UpdateStatus update = UpdateStatus.upToDate,
  List<Override> overrides = const [],
  List<GoRoute> extraRoutes = const [],
  Future<bool> Function({required VoidCallback onDone})? showAd,
}) async {
  final router = GoRouter(
    initialLocation: Routes.splash,
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, _) => SplashView(
          isUnderMaintenance: () => maintenance,
          checkForUpdate: () async => update,
          showStartupAd: showAd ?? ({required onDone}) async => false,
        ),
      ),
      GoRoute(
          path: Routes.home,
          builder: (_, _) => const Scaffold(body: Text('HOME'))),
      GoRoute(
          path: Routes.settings,
          builder: (_, _) => const Scaffold(body: Text('SETTINGS'))),
      ...extraRoutes,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
  // 스플래시 지연(2s) + 비동기 검사
  await tester.pump(const Duration(seconds: 3));
  await tester.pump();
  await tester.pump();
  return router;
}

void main() {
  setUpOrange('splash_gate_test');

  setUp(() {
    AppFeatureConfig.applyBootConfig(profileName: 'minimal');
    AppFeatureConfig.isForceUpdateEnabled = true;
    AppFeatureConfig.isOnboardingEnabled = false;
    PendingDeepLink.reset();
  });
  tearDown(PendingDeepLink.reset);

  testWidgets('H6 · 점검 중이면 점검 화면이 뜨고 스플래시에서 이동하지 않는다', (tester) async {
    await _pump(tester, maintenance: true);
    expect(find.byType(MaintenanceView), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    expect(find.byType(SplashView), findsOneWidget);
    // 시간이 더 흘러도 사라지지 않는다.
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(MaintenanceView), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('H6 · 강제 업데이트가 필요하면 다이얼로그가 뜨고 이동하지 않는다', (tester) async {
    await _pump(tester, update: UpdateStatus.updateRequired);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('H6 · 차단 사유가 없으면 평소처럼 이동한다', (tester) async {
    await _pump(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(MaintenanceView), findsNothing);
  });

  testWidgets('M3 · 스플래시 전에 도착한 딥링크는 이동 뒤에 소비된다', (tester) async {
    PendingDeepLink.reset(); // 앞 테스트의 스플래시 dispose가 남긴 상태 제거
    expect(PendingDeepLink.offer('/settings'), isNull,
        reason: '스플래시 이동 전이므로 바로 이동하지 않고 보관');
    await _pump(tester);
    expect(find.text('SETTINGS'), findsOneWidget);
  });

  testWidgets('동의가 필요하면 이동 전에 동의 시트를 띄운다 (이동하지 않는다)', (tester) async {
    AppFeatureConfig.isPrivacyConsentEnabled = true;
    await _pump(tester, overrides: [needsConsentProvider.overrideWithValue(true)]);
    expect(find.byType(PrivacyConsentDialog), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });

  group('시작 광고', () {
    setUp(() => AppFeatureConfig.isAdsEnabled = true);

    testWidgets('광고를 보여 주면 광고가 끝날 때(onDone) 이동한다', (tester) async {
      late VoidCallback done;
      await _pump(tester, showAd: ({required onDone}) async {
        done = onDone;
        return true;
      });
      expect(find.text('HOME'), findsNothing, reason: '광고 중에는 이동하지 않는다');
      done();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('광고를 못 쓰면(false) 막히지 않고 바로 이동한다', (tester) async {
      await _pump(tester, showAd: ({required onDone}) async => false);
      expect(find.text('HOME'), findsOneWidget);
    });
  });

  group('What\'s-new는 이동 뒤에 평가된다', () {
    var seen = 0;
    WhatsNewService fake() => WhatsNewService(
      readVersion: () async => '1.2.0',
      readLastSeen: () async => '1.1.0',
      writeLastSeen: (_) async => seen++,
    );

    setUp(() {
      seen = 0;
      AppFeatureConfig.isWhatsNewEnabled = true;
    });

    testWidgets('정상 진입: 이동하고 표시 기록을 남긴다', (tester) async {
      await _pump(tester, overrides: [whatsNewServiceProvider.overrideWithValue(fake())]);
      expect(find.text('HOME'), findsOneWidget);
      expect(seen, 1);
    });

    testWidgets('점검으로 막히면 평가하지 않는다 (차단 화면 뒤에서 소모되지 않는다)', (tester) async {
      await _pump(tester,
          maintenance: true, overrides: [whatsNewServiceProvider.overrideWithValue(fake())]);
      expect(seen, 0);
    });
  });

  group('PendingDeepLink', () {
    test('이동 전엔 보관(마지막 것만), markReady가 한 번 꺼내 준다', () {
      expect(PendingDeepLink.offer('/a'), isNull);
      expect(PendingDeepLink.offer('/b'), isNull);
      expect(PendingDeepLink.markReady(), '/b');
      expect(PendingDeepLink.markReady(), isNull);
    });

    test('이동 뒤 도착한 링크는 바로 통과한다', () {
      PendingDeepLink.markReady();
      expect(PendingDeepLink.offer('/settings'), '/settings');
    });
  });
}
