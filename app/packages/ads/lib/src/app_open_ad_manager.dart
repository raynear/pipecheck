import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:utils/utils.dart';

import 'ad_consent_manager.dart';
import 'ads_config.dart';
import 'ads_constants.dart';

class AppOpenAdManager {
  final AdsConfig config;
  final String? appOpenAdId;

  AppOpenAd? _appOpenAd;
  DateTime? _appOpenAdLoadTime;
  static const Duration _appOpenAdValidDuration = Duration(hours: 4);
  bool _isShowingAppOpenAd = false;

  // 재시도 카운터
  int _numAppOpenLoadAttempts = 0;

  AppOpenAdManager({
    required this.config,
    required this.appOpenAdId,
  });

  // 앱 오프닝 광고 유효성 검사 (4시간 이내 로드된 광고만 유효)
  bool _isAppOpenAdValid() {
    if (_appOpenAdLoadTime == null) return false;
    return DateTime.now().difference(_appOpenAdLoadTime!) < _appOpenAdValidDuration;
  }

  // 앱 오프닝 광고 준비 상태 확인
  bool get isAppOpenAdReady => _appOpenAd != null && _isAppOpenAdValid();

  // 앱 오프닝 광고 로드
  Future<void> loadAppOpenAd() async {
    // UMP 동의 게이트 (P1-13c)
    if (!AdConsentManager.canRequestAdsNow) {
      logger.d('Ad consent not granted - skipping App Open ad load');
      return;
    }

    if (appOpenAdId == null) {
      logger.w('App Open ad ID not found, skipping');
      return;
    }

    // 이미 로드된 유효한 광고가 있으면 스킵
    if (_appOpenAd != null && _isAppOpenAdValid()) {
      return;
    }

    try {
      await AppOpenAd.load(
        adUnitId: appOpenAdId!,
        request: AdConsentManager.currentAdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (AppOpenAd ad) {
            _appOpenAd = ad;
            _appOpenAdLoadTime = DateTime.now();
            _numAppOpenLoadAttempts = 0;
            logger.d('App Open ad loaded successfully');
          },
          onAdFailedToLoad: (LoadAdError error) async {
            logger.e('App Open ad failed to load: $error');
            _numAppOpenLoadAttempts += 1;
            _appOpenAd = null;

            if (_numAppOpenLoadAttempts < maxFailedLoadAttempts) {
              await Future.delayed(const Duration(seconds: 1));
              await loadAppOpenAd();
            } else {
              _numAppOpenLoadAttempts = 0;
              logger.w('App Open ad failed to load after max attempts');
            }
          },
        ),
      );
    } catch (e) {
      logger.e('Error in _loadAppOpenAd: $e');
    }
  }

  /// 앱 오프닝 광고가 로드될 때까지 대기합니다
  /// 타임아웃 내에 로드되면 true, 아니면 false 반환
  Future<bool> waitForAppOpenAd({Duration timeout = const Duration(seconds: 5)}) async {
    if (!config.adsEnabled || !config.appOpenAdEnabled) {
      return false;
    }

    // 동의 없으면 로드가 시작되지 않으므로 타임아웃 대기 없이 즉시 false
    if (!AdConsentManager.canRequestAdsNow) {
      return false;
    }

    if (isAppOpenAdReady) {
      return true;
    }

    // 이미 로드 중이면 기다림
    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime) < timeout) {
      if (isAppOpenAdReady) {
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return isAppOpenAdReady;
  }

  // 앱 오프닝 광고 표시
  Future<void> showAppOpenAd({VoidCallback? onAdDismissed, VoidCallback? onAdFailed}) async {
    // 광고가 비활성화된 경우
    if (!config.adsEnabled || !config.appOpenAdEnabled) {
      logger.d('App Open ad is disabled - skipping');
      onAdDismissed?.call();
      return;
    }

    // 이미 광고를 표시 중이면 스킵
    if (_isShowingAppOpenAd) {
      logger.d('App Open ad is already showing - skipping');
      return;
    }

    // 광고가 준비되지 않았거나 유효하지 않으면 로드 후 스킵
    if (!isAppOpenAdReady) {
      logger.d('App Open ad not ready or expired - loading new ad');
      loadAppOpenAd();
      onAdFailed?.call();
      return;
    }

    _isShowingAppOpenAd = true;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (AppOpenAd ad) {
        logger.d('App Open ad showed');
      },
      onAdDismissedFullScreenContent: (AppOpenAd ad) {
        logger.d('App Open ad dismissed');
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd(); // 다음 광고 미리 로드
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (AppOpenAd ad, AdError error) {
        logger.e('App Open ad failed to show: $error');
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd(); // 다음 광고 미리 로드
        onAdFailed?.call();
      },
    );

    try {
      await _appOpenAd!.show();
    } catch (e) {
      logger.e('Error showing App Open ad: $e');
      _isShowingAppOpenAd = false;
      onAdFailed?.call();
    }
  }

  // 리소스 해제
  void dispose() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
  }
}
