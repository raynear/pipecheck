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

  // 매니저들
  late final FullscreenAdManager fullscreenAds;
  late final BannerAdManager bannerAds;
  late final AppOpenAdManager appOpenAd;

  /// 앱이 부팅 시점에 플래그 + 해석된 광고 단위 ID + 개인화 동의 콜백을 주입한다.
  /// AdConsentManager에도 같은 설정을 전달한다. initialize() 전에 호출해야 한다.
  void configure({
    required AdsConfig config,
    required AdUnitIds adUnitIds,
    required bool Function() personalizedAds,
  }) {
    _config = config;
    _adUnitIds = adUnitIds;
    AdConsentManager.configure(config: config, personalizedAds: personalizedAds);
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
    _initializationFuture ??= _initialize();
    await _initializationFuture;
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

    // 매니저 초기화 — 동의 게이트보다 먼저 생성한다 (SDK 호출 없음).
    // 동의가 거부돼도 delegate 접근(createBannerAd 등)이 크래시하지 않고,
    // 각 로드 메서드의 동의 게이트가 빈 위젯/no-op으로 처리한다.
    fullscreenAds = FullscreenAdManager(
      config: _config,
      rewardedAdId: rewardedAdId,
      rewardedInterstitialAdId: rewardedInterstitialAdId,
      interstitialAdId: interstitialAdId,
      nativeAdId: nativeAdId,
      ensureInitialized: ensureInitialized,
    );

    bannerAds = BannerAdManager(
      config: _config,
      bannerAdId: bannerAdId,
      ensureInitialized: ensureInitialized,
    );

    appOpenAd = AppOpenAdManager(
      config: _config,
      appOpenAdId: appOpenAdId,
    );

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
  Future<(double, Widget)> createBannerAd([String key = 'default']) =>
      bannerAds.createBannerAd(key);

  // 배너 광고 해제
  void disposeBannerAd(String key) => bannerAds.disposeBannerAd(key);

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
    fullscreenAds.dispose();
    bannerAds.dispose();
    appOpenAd.dispose();
    logger.d('All ads disposed');
  }
}
