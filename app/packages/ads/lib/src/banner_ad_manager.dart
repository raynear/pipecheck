import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:utils/utils.dart';

import 'ad_consent_manager.dart';
import 'ads_config.dart';

class BannerAdManager {
  static const double _fallbackAspectRatio = 6.4;

  final AdsConfig config;
  final String? bannerAdId;
  final Future<void> Function() ensureInitialized;

  // 배너 광고 관리 맵
  final Map<String, (BannerAd?, Widget)> _bannerAds = {};

  BannerAdManager({
    required this.config,
    required this.bannerAdId,
    required this.ensureInitialized,
  });

  // 배너 광고 생성 (통합된 방식)
  Future<(double, Widget)> createBannerAd([String key = 'default']) async {
    // 광고가 비활성화된 경우 빈 배너와 위젯 반환
    if (!config.adsEnabled) {
      logger.d('Ads are disabled - returning empty banner');
      return (_fallbackAspectRatio, const SizedBox.shrink());
    }

    // UMP 동의 게이트 (P1-13c)
    if (!AdConsentManager.canRequestAdsNow) {
      logger.d('Ad consent not granted - returning empty banner');
      return (_fallbackAspectRatio, const SizedBox.shrink());
    }

    await ensureInitialized();

    // 이미 존재하는 광고가 있다면 반환
    if (_bannerAds.containsKey(key) && _bannerAds[key]!.$1 != null) {
      final cached = _bannerAds[key]!;
      return (cached.$1!.size.width / cached.$1!.size.height, cached.$2);
    }

    final adId = bannerAdId;

    if (adId == null) {
      final fallbackWidget = Image.asset('assets/images/fallback_banner.jpg');
      _bannerAds[key] = (null, fallbackWidget);
      logger.w('Banner ad ID not found for key: $key, using fallback');
      return (_fallbackAspectRatio, fallbackWidget);
    }

    final newBannerAd = BannerAd(
      adUnitId: adId,
      request: AdConsentManager.currentAdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          logger.d('Banner ad loaded successfully for key: $key');
        },
        onAdFailedToLoad: (ad, error) async {
          logger.e('Banner ad failed to load for key $key: $error');
          ad.dispose();
          _bannerAds.remove(key);
        },
      ),
    );

    try {
      await newBannerAd.load();
      final adWidget = AdWidget(ad: newBannerAd);
      _bannerAds[key] = (newBannerAd, adWidget as Widget);
      return (newBannerAd.size.width / newBannerAd.size.height, adWidget as Widget);
    } catch (e) {
      logger.e('Error creating banner ad for key $key: $e');
      newBannerAd.dispose();
      final fallbackWidget = Image.asset('assets/images/fallback_banner.jpg');
      _bannerAds[key] = (null, fallbackWidget);
      return (_fallbackAspectRatio, fallbackWidget);
    }
  }

  // 배너 광고 해제
  void disposeBannerAd(String key) {
    final adPair = _bannerAds[key];
    if (adPair != null) {
      adPair.$1?.dispose();
      _bannerAds.remove(key);
      logger.d('Banner ad disposed for key: $key');
    }
  }

  // 배너 광고 새로고침 (화면 전환 시 호출)
  Future<(double, Widget)> refreshBannerAd(String key) async {
    // 광고가 비활성화된 경우 빈 배너와 위젯 반환
    if (!config.adsEnabled) {
      logger.d('Ads are disabled - returning empty banner');
      return (_fallbackAspectRatio, const SizedBox.shrink());
    }

    // UMP 동의 게이트 (P1-13c)
    if (!AdConsentManager.canRequestAdsNow) {
      logger.d('Ad consent not granted - returning empty banner');
      return (_fallbackAspectRatio, const SizedBox.shrink());
    }

    // 기존 배너 해제
    disposeBannerAd(key);

    // 새 배너 로드
    await ensureInitialized();

    final adId = bannerAdId;

    if (adId == null) {
      final fallbackWidget = Image.asset('assets/images/fallback_banner.jpg');
      _bannerAds[key] = (null, fallbackWidget);
      logger.w('Banner ad ID not found for key: $key, using fallback');
      return (_fallbackAspectRatio, fallbackWidget);
    }

    final newBannerAd = BannerAd(
      adUnitId: adId,
      request: AdConsentManager.currentAdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          logger.d('Banner ad refreshed successfully for key: $key');
        },
        onAdFailedToLoad: (ad, error) async {
          logger.e('Banner ad refresh failed for key $key: $error');
          ad.dispose();
          _bannerAds.remove(key);
        },
      ),
    );

    try {
      await newBannerAd.load();
      final adWidget = AdWidget(ad: newBannerAd);
      _bannerAds[key] = (newBannerAd, adWidget as Widget);
      return (newBannerAd.size.width / newBannerAd.size.height, adWidget as Widget);
    } catch (e) {
      logger.e('Error refreshing banner ad for key $key: $e');
      newBannerAd.dispose();
      final fallbackWidget = Image.asset('assets/images/fallback_banner.jpg');
      _bannerAds[key] = (null, fallbackWidget);
      return (_fallbackAspectRatio, fallbackWidget);
    }
  }

  // 리소스 해제
  void dispose() {
    for (final entry in _bannerAds.entries) {
      entry.value.$1?.dispose();
    }
    _bannerAds.clear();
  }
}
