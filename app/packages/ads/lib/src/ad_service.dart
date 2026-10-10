import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:utils/utils.dart';

import 'ad_consent_manager.dart';
import 'ads_config.dart';
import 'app_open_ad_manager.dart';
import 'banner_ad_manager.dart';
import 'fullscreen_ad_manager.dart';

class AdService {
  static Future<void>? _initializationFuture;

  // SDK 초기화는 동의 게이트(ensureInitialized) 뒤로 지연한다 —
  // 생성자에서 시작하면 UMP 동의 전에 MobileAds가 초기화된다 (P1-13c).
  AdService._internal();

  static final AdService _instance = AdService._internal();

  factory AdService() {
    return _instance;
  }

  /// UMP 동의 관리자 (설정 화면의 프라이버시 옵션 진입점이 사용)
  final AdConsentManager consentManager = AdConsentManager();

  // 광고 ID들
  String? bannerAdId;
  String? rewardedAdId;
  String? rewardedInterstitialAdId;
  String? interstitialAdId;
  String? nativeAdId;
  String? appOpenAdId;

  AdsConfig _config = const AdsConfig.disabled();
  AdUnitIds _adUnitIds = const AdUnitIds();

  // 매니저들 — 첫 접근 시 **현재** _config/_adUnitIds로 만든다(미생성 접근이
  // 던지지 않아야 하고, configure()보다 먼저 닿아도 낡은 설정이 고정되면 안 된다).
  // 실제 광고 요청 안전판은 매니저의 config가 아니라
  // AdConsentManager.canRequestAdsNow(기본 false)다.
  FullscreenAdManager? _fullscreenAds;
  BannerAdManager? _bannerAds;
  AppOpenAdManager? _appOpenAd;

  FullscreenAdManager get fullscreenAds => _fullscreenAds ??= FullscreenAdManager(
        config: _config,
        rewardedAdId: _adUnitIds.rewarded,
        rewardedInterstitialAdId: _adUnitIds.rewardedInterstitial,
        interstitialAdId: _adUnitIds.interstitial,
        nativeAdId: _adUnitIds.native,
        ensureInitialized: ensureInitialized,
      );

  BannerAdManager get bannerAds => _bannerAds ??= BannerAdManager(
        config: _config,
        bannerAdId: _adUnitIds.banner,
        ensureInitialized: ensureInitialized,
      );

  AppOpenAdManager get appOpenAd => _appOpenAd ??= AppOpenAdManager(
        config: _config,
        appOpenAdId: _adUnitIds.appOpen,
      );

  /// 앱이 부팅 시점에 플래그 + 해석된 광고 단위 ID + 개인화 동의 콜백을 주입한다.
  /// AdConsentManager에도 같은 설정을 전달한다.
  ///
  /// 이미 만들어진 매니저는 낡은 설정 스냅샷을 들고 있으므로 버린다 — 순서가
  /// 뒤집혀도(configure()가 첫 접근보다 늦어도) 실설정이 실린다.
  void configure({
    required AdsConfig config,
    required AdUnitIds adUnitIds,
    required bool Function() personalizedAds,
  }) {
    _config = config;
    _adUnitIds = adUnitIds;
    _dropManagers();
    AdConsentManager.configure(config: config, personalizedAds: personalizedAds);
  }

  /// 만들어진 매니저만 해제하고 버린다 — 미생성 매니저를 **만들지 않는다**
  /// (만들면 그 시점 설정으로 스냅샷이 확정된다).
  void _dropManagers() {
    _fullscreenAds?.dispose();
    _bannerAds?.dispose();
    _appOpenAd?.dispose();
    _fullscreenAds = null;
    _bannerAds = null;
    _appOpenAd = null;
  }

  // SDK 초기화
  Future<void> _initialize() async {
    try {
      // COPPA/TFUA 노브는 SDK 초기화 전에 적용
      await MobileAds.instance.updateRequestConfiguration(
        AdConsentManager.buildRequestConfiguration(
          childDirected: _config.childDirectedAdsEnabled,
          underAgeOfConsent: _config.underAgeOfConsentEnabled,
        ),
      );
      await MobileAds.instance.initialize();
      logger.d('Mobile Ads SDK initialized successfully');
    } catch (e) {
      logger.e('Failed to initialize Mobile Ads SDK: $e');
      rethrow;
    }
  }

  // 초기화 완료 보장 (동의 게이트 통과 후에만 SDK를 초기화한다)
  Future<void> ensureInitialized() async {
    if (!AdConsentManager.canRequestAdsNow) {
      logger.d('Ad consent not granted - skipping SDK initialization');
      return;
    }
    final future = _initializationFuture ??= _initialize();
    try {
      await future;
    } catch (_) {
      // 실패를 캐시하면 일시적 오류(네트워크 등) 한 번으로 이 세션의 광고가 영구히 죽는다 —
      // 다음 호출이 다시 시도하게 비운다. 호출자(show 계열)는 던져진 예외를 onAdFailed로 처리한다.
      if (identical(_initializationFuture, future)) _initializationFuture = null;
      rethrow;
    }
  }

  // 메인 초기화 메서드
  Future<void> initialize() async {
    // 광고가 비활성화된 경우 조기 종료
    if (!_config.adsEnabled) {
      logger.d('Ads are disabled by feature flag - skipping initialization');
      return;
    }

    bannerAdId = _adUnitIds.banner;
    rewardedAdId = _adUnitIds.rewarded;
    rewardedInterstitialAdId = _adUnitIds.rewardedInterstitial;
    interstitialAdId = _adUnitIds.interstitial;
    nativeAdId = _adUnitIds.native;
    appOpenAdId = _adUnitIds.appOpen;

    // UMP 동의 수집 — SDK 초기화/광고 로드 전에 수행 (P1-13c).
    // EEA에서 동의가 거부/미수집되면 이 세션은 광고 없이 동작한다.
    if (_config.umpConsentEnabled) {
      await consentManager.gatherConsent();
    } else {
      AdConsentManager.canRequestAdsNow = true;
    }

    if (!AdConsentManager.canRequestAdsNow) {
      logger.w('Ad consent unavailable - ads disabled for this session');
      return;
    }

    await ensureInitialized();

    // 광고들을 병렬로 로드
    await Future.wait([
      fullscreenAds.loadRewardedAd(),
      fullscreenAds.loadRewardedInterstitialAd(),
      fullscreenAds.loadInterstitialAd(),
      if (_config.appOpenAdEnabled) appOpenAd.loadAppOpenAd(),
    ]);
  }

  // --- Public convenience methods (delegates to managers) ---

  // 보상형 광고 준비 상태 확인
  bool get isRewardedAdReady => fullscreenAds.isRewardedAdReady;

  // 보상형 전면 광고 준비 상태 확인
  bool get isRewardedInterstitialAdReady => fullscreenAds.isRewardedInterstitialAdReady;

  // 전면 광고가 로드되었는지 확인
  bool get isInterstitialAdReady => fullscreenAds.isInterstitialAdReady;

  // 앱 오프닝 광고 준비 상태 확인
  bool get isAppOpenAdReady => appOpenAd.isAppOpenAdReady;

  // 폴백 위젯 접근
  Widget? get fallbackRewarded => fullscreenAds.fallbackRewarded;
  set fallbackRewarded(Widget? value) => fullscreenAds.fallbackRewarded = value;

  Widget? get fallbackInterstitial => fullscreenAds.fallbackInterstitial;
  set fallbackInterstitial(Widget? value) => fullscreenAds.fallbackInterstitial = value;

  // 보상형 광고 표시
  Future<void> showRewardedAd({
    required void Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailed,
  }) => fullscreenAds.showRewardedAd(
    onUserEarnedReward: onUserEarnedReward,
    onAdDismissed: onAdDismissed,
    onAdFailed: onAdFailed,
  );

  // 보상형 전면 광고 표시
  Future<void> showRewardedInterstitialAd({
    required void Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailed,
  }) => fullscreenAds.showRewardedInterstitialAd(
    onUserEarnedReward: onUserEarnedReward,
    onAdDismissed: onAdDismissed,
    onAdFailed: onAdFailed,
  );

  // 전면 광고 표시
  void showInterstitialAd(BuildContext context) =>
      fullscreenAds.showInterstitialAd(context);

  // 전면 광고 표시 (콜백 포함)
  Future<void> showInterstitialAdWithCallback({
    required VoidCallback onAdDismissed,
    VoidCallback? onAdFailed,
  }) => fullscreenAds.showInterstitialAdWithCallback(
    onAdDismissed: onAdDismissed,
    onAdFailed: onAdFailed,
  );

  // 전면 광고 로드 대기
  Future<bool> waitForInterstitialAd({Duration timeout = const Duration(seconds: 5)}) =>
      fullscreenAds.waitForInterstitialAd(timeout: timeout);

  // 세션 완료 후 전면 광고 표시
  Future<void> showSessionCompleteInterstitial({
    required bool isPremium,
    VoidCallback? onComplete,
  }) => fullscreenAds.showSessionCompleteInterstitial(
    isPremium: isPremium,
    onComplete: onComplete,
  );

  // 네이티브 광고 위젯 반환
  Widget getNativeAdWidget(BuildContext context) =>
      fullscreenAds.getNativeAdWidget(context);

  // 배너 광고 생성
  Future<(double, Widget)> createBannerAd([String key = 'default', Object? owner]) =>
      bannerAds.createBannerAd(key, owner);

  // 배너 광고 해제
  void disposeBannerAd(String key, [Object? owner]) => bannerAds.disposeBannerAd(key, owner);

  // 배너 광고 새로고침
  Future<(double, Widget)> refreshBannerAd(String key) =>
      bannerAds.refreshBannerAd(key);

  // 앱 오프닝 광고 대기
  Future<bool> waitForAppOpenAd({Duration timeout = const Duration(seconds: 5)}) =>
      appOpenAd.waitForAppOpenAd(timeout: timeout);

  // 앱 오프닝 광고 표시
  Future<void> showAppOpenAd({VoidCallback? onAdDismissed, VoidCallback? onAdFailed}) =>
      appOpenAd.showAppOpenAd(onAdDismissed: onAdDismissed, onAdFailed: onAdFailed);

  // 모든 리소스 해제
  void dispose() {
    _dropManagers();
    logger.d('All ads disposed');
  }
}
