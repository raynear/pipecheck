// 광고 매니저 생명주기 테스트 — 로드 중 가드·dispose 뒤 콜백·표시 중 재호출·초기화 실패 재시도.
//
// google_mobile_ads의 플랫폼 채널을 가짜로 갈아 끼우고, 플랫폼이 보내는 `onAdEvent`를
// 테스트가 직접 쏜다(채널 이름·코덱은 플러그인 내부 값 — 업그레이드 시 이 파일이 먼저 깨진다).
// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:ads/ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'
    show InitializationStatus;
import 'package:google_mobile_ads/src/ad_instance_manager.dart'
    show AdMessageCodec;

const _channelName = 'plugins.flutter.io/google_mobile_ads';
final _codec = StandardMethodCodec(AdMessageCodec());
final _channel = MethodChannel(_channelName, _codec);

/// 가짜 플랫폼: 호출 기록 + 메서드별 실패/지연 주입 + 이벤트 발사.
class _FakePlatform {
  final List<MethodCall> calls = [];
  final Set<String> failOnce = {};
  final Map<String, Completer<void>> gates = {};

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          if (failOnce.remove(call.method)) {
            throw PlatformException(code: 'boom', message: call.method);
          }
          final gate = gates[call.method];
          if (gate != null) await gate.future;
          if (call.method == 'MobileAds#initialize')
            return InitializationStatus({});
          return null;
        });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }

  int count(String method) => calls.where((c) => c.method == method).length;

  /// 마지막 [method] 호출이 받은 adId.
  int lastAdId(String method) =>
      calls.lastWhere((c) => c.method == method).arguments['adId'] as int;

  Future<void> emit(int adId, String eventName) async {
    final message = _codec.encodeMethodCall(
      MethodCall('onAdEvent', {'adId': adId, 'eventName': eventName}),
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(_channelName, message, (_) {});
  }
}

const _enabled = AdsConfig(
  adsEnabled: true,
  appOpenAdEnabled: false,
  umpConsentEnabled: false,
  childDirectedAdsEnabled: false,
  underAgeOfConsentEnabled: false,
);

FullscreenAdManager _fullscreen({Future<void> Function()? init}) =>
    FullscreenAdManager(
      config: _enabled,
      rewardedAdId: 'r',
      rewardedInterstitialAdId: 'ri',
      interstitialAdId: 'i',
      nativeAdId: null,
      ensureInitialized: init ?? () async {},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakePlatform platform;

  setUp(() {
    platform = _FakePlatform()..install();
    AdConsentManager.canRequestAdsNow = true;
  });

  tearDown(() {
    platform.uninstall();
    AdConsentManager.canRequestAdsNow = false;
  });

  group('FullscreenAdManager 로드', () {
    test('로드 콜백이 오기 전 재호출하면 플랫폼 요청은 1번만 나간다', () async {
      final manager = _fullscreen();
      await manager.loadInterstitialAd();
      await manager.loadInterstitialAd();
      await manager.loadRewardedAd();
      await manager.loadRewardedAd();
      await manager.loadRewardedInterstitialAd();
      await manager.loadRewardedInterstitialAd();

      expect(platform.count('loadInterstitialAd'), 1);
      expect(platform.count('loadRewardedAd'), 1);
      expect(platform.count('loadRewardedInterstitialAd'), 1);
    });

    test('로드 완료 후엔 준비 상태가 되고 다시 요청하지 않는다', () async {
      final manager = _fullscreen();
      await manager.loadInterstitialAd();
      await platform.emit(
        platform.lastAdId('loadInterstitialAd'),
        'onAdLoaded',
      );

      expect(manager.isInterstitialAdReady, isTrue);
      await manager.loadInterstitialAd();
      expect(platform.count('loadInterstitialAd'), 1);
    });

    test('dispose 뒤에 도착한 로드 성공은 광고를 해제하고 들고 있지 않는다', () async {
      final manager = _fullscreen();
      await manager.loadInterstitialAd();
      final adId = platform.lastAdId('loadInterstitialAd');
      manager.dispose();

      await platform.emit(adId, 'onAdLoaded');

      expect(manager.isInterstitialAdReady, isFalse);
      expect(
        platform.calls.any(
          (c) => c.method == 'disposeAd' && c.arguments['adId'] == adId,
        ),
        isTrue,
      );
    });

    test('dispose 뒤에는 새 로드를 시작하지 않는다', () async {
      final manager = _fullscreen()..dispose();
      await manager.loadRewardedAd();
      expect(platform.count('loadRewardedAd'), 0);
    });
  });

  group('FullscreenAdManager 표시', () {
    test('보상형 표시 중 재호출은 앞 콜백을 덮어쓰지 않고 onAdFailed로 끝난다', () async {
      final manager = _fullscreen();
      await manager.loadRewardedAd();
      final adId = platform.lastAdId('loadRewardedAd');
      await platform.emit(adId, 'onAdLoaded');

      var firstDismissed = 0;
      var secondFailed = 0;
      await manager.showRewardedAd(
        onUserEarnedReward: (_) {},
        onAdDismissed: () => firstDismissed++,
      );
      await manager.showRewardedAd(
        onUserEarnedReward: (_) {},
        onAdFailed: () => secondFailed++,
      );

      expect(secondFailed, 1);
      expect(platform.count('showAdWithoutView'), 1);

      await platform.emit(adId, 'onAdDismissedFullScreenContent');
      expect(firstDismissed, 1);
    });

    test('전면(콜백형) 표시 중 재호출도 앞 콜백을 보존한다', () async {
      final manager = _fullscreen();
      await manager.loadInterstitialAd();
      final adId = platform.lastAdId('loadInterstitialAd');
      await platform.emit(adId, 'onAdLoaded');

      var firstDismissed = 0;
      var secondFailed = 0;
      await manager.showInterstitialAdWithCallback(
        onAdDismissed: () => firstDismissed++,
      );
      await manager.showInterstitialAdWithCallback(
        onAdDismissed: () {},
        onAdFailed: () => secondFailed++,
      );

      expect(secondFailed, 1);
      await platform.emit(adId, 'onAdDismissedFullScreenContent');
      expect(firstDismissed, 1);
    });

    test('SDK 초기화가 던지면 show 계열은 예외 대신 onAdFailed를 부른다', () async {
      final manager = _fullscreen(
        init: () async => throw StateError('init failed'),
      );
      var rewardedFailed = 0;
      var rewardedInterstitialFailed = 0;

      await manager.showRewardedAd(
        onUserEarnedReward: (_) {},
        onAdFailed: () => rewardedFailed++,
      );
      await manager.showRewardedInterstitialAd(
        onUserEarnedReward: (_) {},
        onAdFailed: () => rewardedInterstitialFailed++,
      );

      expect(rewardedFailed, 1);
      expect(rewardedInterstitialFailed, 1);
    });
  });

  group('BannerAdManager', () {
    BannerAdManager banner({Future<void> Function()? init}) => BannerAdManager(
      config: _enabled,
      bannerAdId: 'b',
      ensureInitialized: init ?? () async {},
    );

    test('로드 중 dispose하면 로드가 끝난 배너를 즉시 해제한다 (누수 없음)', () async {
      final manager = banner();
      platform.gates['loadBannerAd'] = Completer<void>();

      final pending = manager.createBannerAd('home');
      await pumpEventQueue();
      final adId = platform.lastAdId('loadBannerAd');
      manager.dispose();
      platform.gates['loadBannerAd']!.complete();
      await pending;

      expect(
        platform.calls.any(
          (c) => c.method == 'disposeAd' && c.arguments['adId'] == adId,
        ),
        isTrue,
      );
      // 해제된 매니저에 캐시가 되살아나지 않는다 — 다시 부르면 새로 만들지 않고 빈 배너.
      final again = await manager.createBannerAd('home');
      expect(again.$2, isA<SizedBox>());
    });

    test('로드 중 같은 키를 해제하면 늦게 끝난 배너를 해제한다', () async {
      final manager = banner();
      platform.gates['loadBannerAd'] = Completer<void>();

      final pending = manager.createBannerAd('home');
      await pumpEventQueue();
      final adId = platform.lastAdId('loadBannerAd');
      manager.disposeBannerAd('home');
      platform.gates['loadBannerAd']!.complete();
      await pending;

      expect(
        platform.calls.any(
          (c) => c.method == 'disposeAd' && c.arguments['adId'] == adId,
        ),
        isTrue,
      );
    });

    test('옛 소유자의 dispose는 같은 키 새 소유자의 진행 중 로드를 취소하지 않는다', () async {
      final manager = banner();
      final oldOwner = Object();
      final newOwner = Object();
      platform.gates['loadBannerAd'] = Completer<void>();

      final pending = manager.createBannerAd('shell', newOwner);
      await pumpEventQueue();
      final adId = platform.lastAdId('loadBannerAd');
      manager.disposeBannerAd('shell', oldOwner); // 퇴장 애니메이션이 끝난 옛 State
      platform.gates['loadBannerAd']!.complete();
      final result = await pending;

      expect(result.$2, isNot(isA<SizedBox>()));
      expect(
        platform.calls.any(
          (c) => c.method == 'disposeAd' && c.arguments['adId'] == adId,
        ),
        isFalse,
      );
    });

    test('옛 소유자의 dispose는 새 소유자가 쓰는 캐시된 배너를 해제하지 않는다', () async {
      final manager = banner();
      final oldOwner = Object();
      final newOwner = Object();

      await manager.createBannerAd('shell', oldOwner);
      final adId = platform.lastAdId('loadBannerAd');
      await manager.createBannerAd('shell', newOwner); // 캐시 적중
      manager.disposeBannerAd('shell', oldOwner);

      expect(
        platform.calls.any(
          (c) => c.method == 'disposeAd' && c.arguments['adId'] == adId,
        ),
        isFalse,
      );
      // 현재 소유자가 dispose하면 해제된다.
      manager.disposeBannerAd('shell', newOwner);
      expect(
        platform.calls.any(
          (c) => c.method == 'disposeAd' && c.arguments['adId'] == adId,
        ),
        isTrue,
      );
    });

    test('SDK 초기화가 던져도 createBannerAd는 던지지 않고 빈 배너를 돌려준다', () async {
      final manager = banner(init: () async => throw StateError('init failed'));
      final result = await manager.createBannerAd('home');
      expect(result.$2, isA<SizedBox>());
      expect(platform.count('loadBannerAd'), 0);
    });
  });

  group('AdService SDK 초기화', () {
    test('초기화 실패는 캐시되지 않아 다음 호출이 다시 시도한다', () async {
      platform.failOnce.add(
        'MobileAds#updateRequestConfiguration',
      ); // 초기화 경로의 첫 플랫폼 호출
      final service = AdService();
      service.configure(
        config: _enabled,
        adUnitIds: const AdUnitIds(),
        personalizedAds: () => true,
      );

      Object? firstError;
      try {
        await service.ensureInitialized();
      } catch (e) {
        firstError = e;
      }
      final callsAfterFirst = platform.calls.length;

      await service.ensureInitialized(); // 영구 캐시된 실패면 여기서도 던지거나 호출이 늘지 않는다

      expect(firstError, isNotNull, reason: '첫 호출은 실패를 알린다');
      expect(
        platform.calls.length,
        greaterThan(callsAfterFirst),
        reason: '두 번째 호출은 초기화를 다시 시도한다',
      );
    });
  });
}
