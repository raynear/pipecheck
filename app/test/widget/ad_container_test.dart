// AdContainer 라이프사이클 테스트 — 광고 OFF 빌드에서 dispose가 크래시하지 않아야 한다.
//
// 결함(Sevenfall E2E): AdService의 매니저 필드가 `late final`이고 initialize()
// 안에서만 대입되는데, initialize()는 광고 OFF면 아예 호출되지 않는다.
// 그래서 AdContainer.dispose()의 무가드 AdService().disposeBannerAd()가
// LateInitializationError를 던졌다 (화면을 벗어날 때마다).

import 'package:ads/ads.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:pipecheck/core/widgets/ads/ad_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'
    show AdWidget, InitializationStatus;
import 'package:google_mobile_ads/src/ad_instance_manager.dart'
    show AdMessageCodec;

class _Settings extends SettingsNotifier {
  @override
  Settings build() => Settings.initial();
}

/// 구독 중 — 배너 위젯은 그리지 않지만 initState의 createBannerAd는 그대로 돈다.
/// (실제 AdWidget은 같은 광고를 두 트리에 못 올리고 플랫폼 뷰도 테스트에 없다.)
class _SubscribedSettings extends SettingsNotifier {
  @override
  Settings build() => Settings.initial().copyWith(
    subscriptionExpiryDate: DateTime.now().add(const Duration(days: 30)),
  );
}

void main() {
  final adsWas = AppFeatureConfig.isAdsEnabled;
  tearDown(() {
    AppFeatureConfig.isAdsEnabled = adsWas;
    // AdService는 싱글톤 — 테스트 간 설정이 새지 않게 되돌린다.
    AdService().configure(
      config: const AdsConfig.disabled(),
      adUnitIds: const AdUnitIds(),
      personalizedAds: () => true,
    );
  });

  testWidgets('광고 OFF: pump → dispose가 예외를 던지지 않는다', (tester) async {
    AppFeatureConfig.isAdsEnabled = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_Settings.new)],
        child: const MaterialApp(
          home: AdContainer(adKey: 'test', child: Text('BODY')),
        ),
      ),
    );
    expect(find.text('BODY'), findsOneWidget);

    // 화면 이탈 → State.dispose()
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  // 느린 콜드스타트에서 실제로 일어나는 순서: AppConfig._initializeServices에
  // 5초 타임아웃이 있고 타임아웃은 "기본값으로 계속 진행"이라, 광고 블록 앞의
  // Firebase/Consent/Crashlytics가 5초를 넘기면 runApp이 먼저 돌아
  // AdContainer(createBannerAd)·splash(waitForAppOpenAd)가 configure() 전에
  // 매니저를 만든다. 그 스냅샷이 영구 고정되면 그 세션 광고는 전부 0이 된다.
  test('configure()가 델리게이트 첫 접근보다 늦어도 실설정이 실린다', () {
    final ads = AdService();

    expect(
      ads.bannerAds.config.adsEnabled,
      isFalse,
      reason: 'configure() 전 기본값은 disabled',
    );

    ads.configure(
      config: const AdsConfig(
        adsEnabled: true,
        appOpenAdEnabled: true,
        umpConsentEnabled: false,
        childDirectedAdsEnabled: false,
        underAgeOfConsentEnabled: false,
      ),
      adUnitIds: const AdUnitIds(banner: 'ca-app-pub-1/2'),
      personalizedAds: () => true,
    );

    expect(
      ads.bannerAds.config.adsEnabled,
      isTrue,
      reason: 'late final 스냅샷이면 이 세션 광고가 영구 무음이 된다',
    );
    expect(ads.bannerAds.bannerAdId, 'ca-app-pub-1/2');
    expect(ads.fullscreenAds.config.adsEnabled, isTrue);
    expect(ads.appOpenAd.config.appOpenAdEnabled, isTrue);
  });

  test('광고 OFF: AdService 델리게이트는 initialize() 없이도 던지지 않는다', () {
    // 근본 원인 지점 — 형제 호출자(splash_view의 waitFor*, settings의 새로고침)도
    // 같은 late 필드를 만진다. 게이트는 AdService에 있어야 한다.
    final ads = AdService();
    expect(() => ads.disposeBannerAd('test'), returnsNormally);
    expect(() => ads.isInterstitialAdReady, returnsNormally);
    expect(() => ads.isRewardedAdReady, returnsNormally);
    expect(() => ads.isAppOpenAdReady, returnsNormally);
    expect(() => ads.dispose(), returnsNormally);
  });

  // 배너 소유자 연결 경로: AdContainer → AdService → BannerAdManager.
  // 매니저 단위 테스트(ads 패키지)는 owner를 직접 넘겨서, AdContainer가 `this`를 안 넘기거나
  // AdService가 owner를 흘리지 않아도 초록이었다. 여기서는 실제 위젯 두 개로 끝까지 잰다.
  group('배너 소유자 연결', () {
    final codec = StandardMethodCodec(AdMessageCodec());
    final channel = MethodChannel(
      'plugins.flutter.io/google_mobile_ads',
      codec,
    );
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      // AdWidget이 만드는 안드로이드 플랫폼 뷰 — 테스트에는 구현이 없어 id만 돌려준다.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            SystemChannels.platform_views,
            (call) async => call.method == 'create'
                ? 0
                : <String, Object?>{'width': 0.0, 'height': 0.0},
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'MobileAds#initialize') {
              return InitializationStatus({});
            }
            return null;
          });
      AdConsentManager.canRequestAdsNow = true;
      AppFeatureConfig.isAdsEnabled = true;
      AdService().configure(
        config: const AdsConfig(
          adsEnabled: true,
          appOpenAdEnabled: false,
          umpConsentEnabled: false,
          childDirectedAdsEnabled: false,
          underAgeOfConsentEnabled: false,
        ),
        adUnitIds: const AdUnitIds(banner: 'ca-app-pub-1/2'),
        personalizedAds: () => true,
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform_views, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      AdConsentManager.canRequestAdsNow = false;
    });

    testWidgets('같은 adKey의 옛 AdContainer가 dispose돼도 새 인스턴스의 배너는 해제되지 않는다', (
      tester,
    ) async {
      Widget tree(List<Key> keys) => ProviderScope(
        overrides: [settingsProvider.overrideWith(_SubscribedSettings.new)],
        child: MaterialApp(
          home: Column(
            children: [
              for (final k in keys)
                SizedBox(
                  height: 250,
                  child: AdContainer(
                    key: k,
                    adKey: 'shell',
                    child: const SizedBox(),
                  ),
                ),
            ],
          ),
        ),
      );
      const oldKey = ValueKey('old');
      const newKey = ValueKey('new');

      await tester.runAsync(() async {
        await tester.pumpWidget(tree([oldKey]));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(calls.where((c) => c.method == 'loadBannerAd'), hasLength(1));

      // 새 인스턴스가 캐시된 배너를 받고, 옛 인스턴스가 퇴장한다.
      await tester.runAsync(() async {
        await tester.pumpWidget(tree([oldKey, newKey]));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      await tester.pumpWidget(tree([newKey]));
      await tester.pump();

      expect(
        calls.where((c) => c.method == 'disposeAd'),
        isEmpty,
        reason: '옛 State의 dispose가 새 소유자의 배너를 해제했다',
      );

      // 대조군: 현재 소유자가 사라지면 해제된다.
      await tester.pumpWidget(tree([]));
      await tester.pump();
      expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
    });

    // 셸 전환 중 옛 화면과 새 화면이 같은 adKey로 동시에 마운트된다. 같은 BannerAd를 두 AdWidget이
    // 그리면 "AdWidget is already in the Widget tree" assertion(debug 빨간 화면 / release 플랫폼 뷰 충돌).
    // 구독 설정으로 렌더를 막지 않고, 실제로 그려지는 AdWidget 수를 센다.
    testWidgets('같은 adKey 두 컨테이너가 동시에 떠도 AdWidget은 소유자 쪽 1개만 그려진다', (
      tester,
    ) async {
      Widget tree(List<Key> keys) => ProviderScope(
        overrides: [settingsProvider.overrideWith(_Settings.new)],
        child: MaterialApp(
          home: Column(
            children: [
              for (final k in keys)
                SizedBox(
                  height: 250,
                  child: AdContainer(
                    key: k,
                    adKey: 'shell',
                    child: const SizedBox(),
                  ),
                ),
            ],
          ),
        ),
      );
      const oldKey = ValueKey('old');
      const newKey = ValueKey('new');

      await tester.runAsync(() async {
        await tester.pumpWidget(tree([oldKey]));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(find.byType(AdWidget), findsOneWidget);

      await tester.runAsync(() async {
        await tester.pumpWidget(tree([oldKey, newKey]));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
      expect(find.byType(AdWidget), findsOneWidget);
      // 소유자가 아닌 컨테이너도 같은 높이의 자리를 지킨다(레이아웃이 튀지 않게).
      expect(
        find.descendant(
          of: find.byKey(oldKey),
          matching: find.byType(AdWidget),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(newKey),
          matching: find.byType(AdWidget),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(
          find.descendant(
            of: find.byKey(oldKey),
            matching: find.byType(AspectRatio),
          ),
        ),
        tester.getSize(
          find.descendant(
            of: find.byKey(newKey),
            matching: find.byType(AspectRatio),
          ),
        ),
      );

      // 새 컨테이너가 퇴장하면 키가 해제되고 둘 다 AdWidget이 없다(기존 #404 동작 유지).
      await tester.pumpWidget(tree([oldKey]));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    // 홈(A)이 떠 있는 채로 같은 adKey 화면(B)을 push했다 pop하면, B의 dispose가 광고를 해제한다.
    // A가 빈 자리로 남으면 앱을 다시 켤 때까지 배너가 사라진다 — A가 소유권을 되찾아 다시 그려야 한다.
    testWidgets('같은 adKey 화면을 push했다 pop해도 남은 컨테이너가 배너를 되찾는다', (tester) async {
      Widget tree(List<Key> keys) => ProviderScope(
        overrides: [settingsProvider.overrideWith(_Settings.new)],
        child: MaterialApp(
          home: Column(
            children: [
              for (final k in keys)
                SizedBox(
                  height: 250,
                  child: AdContainer(
                    key: k,
                    adKey: 'shell',
                    child: const SizedBox(),
                  ),
                ),
            ],
          ),
        ),
      );
      const aKey = ValueKey('a');
      const bKey = ValueKey('b');

      Future<void> settle() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump();
        }
      }

      await tester.pumpWidget(tree([aKey]));
      await settle();
      await tester.pumpWidget(tree([aKey, bKey]));
      await settle();
      await tester.pumpWidget(tree([aKey]));
      await settle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AdWidget), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(aKey), matching: find.byType(AdWidget)),
        findsOneWidget,
        reason: 'B가 pop된 뒤 A의 배너가 영구히 사라졌다',
      );
    });
  });
}
