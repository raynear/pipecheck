// 온보딩 화면 — 페이지 이동·건너뛰기·언어 선택, 구독 페이지의 가격 줄·구매·복원·약관 링크를
// 실제 위젯을 탭해 확인한다. 스토어와 URL 열기는 가짜로 바꾼다.

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:pipecheck/config/app_config.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/services/deep_link_service.dart';
import 'package:pipecheck/core/services/in_app_purchase_service.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:pipecheck/features/onboarding/views/onboarding_view.dart';

import '../../support/orange_harness.dart';

const _en = Locale('en', 'US');
const _ko = Locale('ko', 'KR');

/// 실제 en-US 번역 파일을 읽어 가격 줄 문구까지 진짜 번역으로 확인한다.
class _EnLoader extends AssetLoader {
  const _EnLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/languages/en-US.json').readAsStringSync()) as Map<String, dynamic>;
}

class _FakeIap extends Fake implements InAppPurchaseService {
  final bought = <String>[];
  int restored = 0;
  bool buyResult = true;
  @override
  Future<bool> buyProduct(ProductDetails prod) async {
    bought.add(prod.id);
    return buyResult;
  }

  @override
  Future<void> restorePurchase() async => restored++;
}

class _Launcher extends Fake with MockPlatformInterfaceMixin implements UrlLauncherPlatform {
  final launched = <String>[];
  @override
  Future<bool> canLaunch(String url) async => true;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

ProductDetails _product(String id, String price, double raw) =>
    ProductDetails(id: id, title: id, description: '', price: price, rawPrice: raw, currencyCode: 'USD');

late _FakeIap iap;
late _Launcher launcher;
late ProviderContainer container;

Future<void> _pump(WidgetTester tester, {Settings? initial}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (initial != null) await initial.saveToOrange();
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => const OnboardingView()),
    GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('home-page'))),
    GoRoute(path: '/settings', builder: (_, _) => const Scaffold(body: Text('settings-page'))),
  ]);
  container = ProviderContainer(overrides: [inAppPurchaseServiceProvider.overrideWithValue(iap)]);
  addTearDown(container.dispose);
  await tester.pumpWidget(EasyLocalization(
    supportedLocales: const [_en, _ko],
    path: 'unused',
    assetLoader: const _EnLoader(),
    fallbackLocale: _en,
    startLocale: _en,
    child: Builder(
      builder: (context) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
        ),
      ),
    ),
  ));
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _t(String s) => find.text(s);

/// 구독 페이지(마지막)까지 Next로 넘어간다.
Future<void> _toLastPage(WidgetTester tester, int pages) async {
  for (var i = 0; i < pages - 1; i++) {
    await _tap(tester, _t('Next'));
  }
}

void main() {
  setUpOrange('onboarding_view_test');

  late bool subscriptionFlag;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    dotenv.loadFromString(envString: 'PRIVACY_POLICY_URL=https://example.com/privacy');
  });

  setUp(() async {
    AppConfig.debugSetConfig({'MONTHLY': 'm', 'YEARLY': 'y', 'LIFETIME': 'l'});
    AppConfig.debugSetProducts([
      _product('m', r'$1.00', 1),
      _product('y', r'$6.00', 6),
      _product('l', r'$20.00', 20),
    ]);
    iap = _FakeIap();
    launcher = _Launcher();
    UrlLauncherPlatform.instance = launcher;
    subscriptionFlag = AppFeatureConfig.isSubscriptionEnabled;
    AppFeatureConfig.isSubscriptionEnabled = true;
    supportedLocales.add(_ko);
    await Settings.initial().saveToOrange();
  });

  tearDown(() {
    AppFeatureConfig.isSubscriptionEnabled = subscriptionFlag;
    supportedLocales.remove(_ko);
    AppConfig.debugSetProducts([]);
  });

  group('소개 페이지', () {
    setUp(() => AppFeatureConfig.isSubscriptionEnabled = false);

    testWidgets('Next/Previous로 오가고, 마지막 페이지에서는 Get Started가 나온다', (tester) async {
      await _pump(tester);
      expect(_t('Welcome to BoilerPlate'), findsOneWidget);
      expect(_t('Previous'), findsNothing);

      await _tap(tester, _t('Next'));
      expect(_t('Beautiful Design'), findsOneWidget);
      expect(_t('Previous'), findsOneWidget);

      await _tap(tester, _t('Previous'));
      expect(_t('Welcome to BoilerPlate'), findsOneWidget);

      await _toLastPage(tester, 4);
      expect(_t('Secure & Private'), findsOneWidget);
      expect(_t('Next'), findsNothing);
      expect(_t('Get Started'), findsOneWidget);
    });

    testWidgets('Get Started는 온보딩 완료를 저장하고 홈으로 간다', (tester) async {
      await _pump(tester);
      await _toLastPage(tester, 4);
      await _tap(tester, _t('Get Started'));
      expect(container.read(settingsProvider).onBoard, isTrue);
      expect(_t('home-page'), findsOneWidget);
    });

    testWidgets('N8: 온보딩 중 보관된 딥링크는 건너뛰기 뒤에 이어 열린다(한 번만)', (tester) async {
      PendingDeepLink.reset();
      addTearDown(PendingDeepLink.reset);
      PendingDeepLink.holdForUnlock('/settings');
      await _pump(tester);
      await _tap(tester, _t('Skip'));
      expect(_t('settings-page'), findsOneWidget);
      expect(PendingDeepLink.takeAfterUnlock('/x'), '/x');
    });

    testWidgets('N8: 보관된 딥링크는 Get Started 뒤에도 이어 열린다', (tester) async {
      PendingDeepLink.reset();
      addTearDown(PendingDeepLink.reset);
      PendingDeepLink.holdForUnlock('/settings');
      await _pump(tester);
      await _toLastPage(tester, 4);
      await _tap(tester, _t('Get Started'));
      expect(_t('settings-page'), findsOneWidget);
    });

    testWidgets('Skip은 중간 페이지에서도 완료를 저장하고 홈으로 간다', (tester) async {
      await _pump(tester);
      await _tap(tester, _t('Next'));
      await _tap(tester, _t('Skip'));
      expect(container.read(settingsProvider).onBoard, isTrue);
      expect(_t('home-page'), findsOneWidget);
    });
  });

  group('언어 선택', () {
    testWidgets('목록에서 고르면 설정이 바뀌고 시트가 닫힌다', (tester) async {
      await _pump(tester);
      await _tap(tester, _t('English (United States)'));
      expect(_t('Select Language'), findsOneWidget);
      await _tap(tester, find.text('ko-KR'));
      expect(container.read(settingsProvider).language, _ko);
      expect(_t('Select Language'), findsNothing);
    });
  });

  group('구독 페이지', () {
    testWidgets('스토어 가격과 연간 할인율을 보여 준다', (tester) async {
      await _pump(tester);
      await _toLastPage(tester, 5);
      expect(_t(r'$1.00/month'), findsOneWidget);
      expect(_t(r'$6.00/year (50% discount)'), findsOneWidget);
      expect(_t(r'$20.00'), findsOneWidget);
    });

    testWidgets('상품을 아직 못 불러왔으면 "Loading..."이고 구매는 아무 일도 하지 않는다', (tester) async {
      AppConfig.debugSetProducts([]);
      await _pump(tester);
      await _toLastPage(tester, 5);
      expect(_t('Loading...'), findsNWidgets(3));
      await _tap(tester, _t('Subscribe Now'));
      expect(iap.bought, isEmpty);
      expect(_t('home-page'), findsNothing);
    });

    testWidgets('기본은 월간, 연간/평생을 고르면 그 상품으로 구매하고 성공하면 홈으로 간다', (tester) async {
      await _pump(tester);
      await _toLastPage(tester, 5);
      await _tap(tester, _t('Subscribe Now'));
      expect(iap.bought, ['m']);
      expect(container.read(settingsProvider).onBoard, isTrue);
      expect(_t('home-page'), findsOneWidget);
    });

    testWidgets('N8: 보관된 딥링크는 구독 성공 뒤에도 이어 열린다', (tester) async {
      PendingDeepLink.reset();
      addTearDown(PendingDeepLink.reset);
      PendingDeepLink.holdForUnlock('/settings');
      await _pump(tester);
      await _toLastPage(tester, 5);
      await _tap(tester, _t('Subscribe Now'));
      expect(_t('settings-page'), findsOneWidget);
    });

    testWidgets('연간 선택', (tester) async {
      await _pump(tester);
      await _toLastPage(tester, 5);
      await _tap(tester, _t('Yearly'));
      await _tap(tester, _t('Subscribe Now'));
      expect(iap.bought, ['y']);
    });

    testWidgets('평생 선택', (tester) async {
      await _pump(tester);
      await _toLastPage(tester, 5);
      await _tap(tester, _t('Lifetime'));
      await _tap(tester, _t('Subscribe Now'));
      expect(iap.bought, ['l']);
    });

    testWidgets('구매를 시작하지 못하면 온보딩을 끝내지 않는다', (tester) async {
      iap.buyResult = false;
      await _pump(tester);
      await _toLastPage(tester, 5);
      await _tap(tester, _t('Subscribe Now'));
      expect(container.read(settingsProvider).onBoard, isFalse);
      expect(_t('home-page'), findsNothing);
    });

    testWidgets('Restore Purchase는 복원을 요청한다', (tester) async {
      await _pump(tester);
      await _toLastPage(tester, 5);
      await _tap(tester, _t('Restore Purchase'));
      expect(iap.restored, 1);
    });

    testWidgets('개인정보·약관 링크를 연다(약관 URL이 없으면 Apple 표준 EULA)', (tester) async {
      await _pump(tester);
      await _toLastPage(tester, 5);
      await _tap(tester, _t('Privacy Policy'));
      await _tap(tester, _t('Terms of Use'));
      expect(launcher.launched, ['https://example.com/privacy', 'https://www.apple.com/legal/macapps/stdeula']);
    });

    testWidgets('이미 프리미엄이면 구독 대신 환영 페이지', (tester) async {
      await _pump(tester, initial: Settings.initial().copyWith(hasLifetime: true));
      await _toLastPage(tester, 5);
      expect(_t('Welcome Back, Premium Member!'), findsOneWidget);
      expect(_t('Subscribe Now'), findsNothing);
    });

    testWidgets('열린 구독(Google Play)도 프리미엄으로 본다', (tester) async {
      await _pump(tester, initial: Settings.initial().copyWith(subscriptionOpenEnded: true));
      await _toLastPage(tester, 5);
      expect(_t('Welcome Back, Premium Member!'), findsOneWidget);
    });
  });
}
