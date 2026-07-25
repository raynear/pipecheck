import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:utils/utils.dart';

import 'ad_consent_manager.dart';
import 'ads_config.dart';
import 'ads_constants.dart';

class FullscreenAdManager {
  final AdsConfig config;
  final String? rewardedAdId;
  final String? rewardedInterstitialAdId;
  final String? interstitialAdId;
  final String? nativeAdId;
  final Future<void> Function() ensureInitialized;

  // 광고 인스턴스들
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  RewardedInterstitialAd? _rewardedInterstitialAd;

  // 재시도 카운터들
  int _numInterstitialLoadAttempts = 0;
  int _numRewardedLoadAttempts = 0;
  int _numRewardedInterstitialLoadAttempts = 0;
  int _numNativeLoadAttempts = 0;

  // 폴백 위젯들
  Widget? fallbackRewarded;
  Widget? fallbackInterstitial;

  FullscreenAdManager({
    required this.config,
    required this.rewardedAdId,
    required this.rewardedInterstitialAdId,
    required this.interstitialAdId,
    required this.nativeAdId,
    required this.ensureInitialized,
  });

  // 보상형 광고 준비 상태 확인
  bool get isRewardedAdReady => _rewardedAd != null;

  // 보상형 전면 광고 준비 상태 확인
  bool get isRewardedInterstitialAdReady => _rewardedInterstitialAd != null;

  // 전면 광고가 로드되었는지 확인
  bool get isInterstitialAdReady => _interstitialAd != null;

  // --- Load methods ---

  // 보상형 광고 (Rewarded Ad) 로드
  Future<void> loadRewardedAd() async {
    // UMP 동의 게이트 (P1-13c)
    if (!AdConsentManager.canRequestAdsNow) {
      logger.d('Ad consent not granted - skipping rewarded ad load');
      return;
    }

    if (rewardedAdId == null) {
      fallbackRewarded = Image.asset('assets/images/fallback_fullscreen.jpg');
      logger.w('Rewarded ad ID not found, using fallback');
      return;
    }

    if (_rewardedAd != null) {
      return; // 이미 로드된 광고가 있음
    }

    try {
      await RewardedAd.load(
        adUnitId: rewardedAdId!,
        request: AdConsentManager.currentAdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            _rewardedAd = ad;
            _numRewardedLoadAttempts = 0;
            _rewardedAd!.setImmersiveMode(true);
            logger.d('Rewarded ad loaded successfully');
          },
          onAdFailedToLoad: (LoadAdError error) async {
            logger.e('RewardedAd failed to load: $error');
            _numRewardedLoadAttempts += 1;
            _rewardedAd = null;

            if (_numRewardedLoadAttempts < maxFailedLoadAttempts) {
              await Future.delayed(const Duration(seconds: 1));
              await loadRewardedAd();
            } else {
              _numRewardedLoadAttempts = 0;
              fallbackRewarded = Image.asset('assets/images/fallback_fullscreen.jpg');
              logger.w('Rewarded ad failed to load after max attempts, using fallback');
            }
          },
        ),
      );
    } catch (e) {
      logger.e('Error in _loadRewardedAd: $e');
      fallbackRewarded = Image.asset('assets/images/fallback_fullscreen.jpg');
    }
  }

  // 보상형 전면 광고 (Rewarded Interstitial Ad) 로드
  Future<void> loadRewardedInterstitialAd() async {
    // UMP 동의 게이트 (P1-13c)
    if (!AdConsentManager.canRequestAdsNow) {
      logger.d('Ad consent not granted - skipping rewarded interstitial load');
      return;
    }

    if (rewardedInterstitialAdId == null) {
      logger.w('Rewarded Interstitial ad ID not found, skipping');
      return;
    }

    if (_rewardedInterstitialAd != null) {
      return; // 이미 로드된 광고가 있음
    }

    try {
      await RewardedInterstitialAd.load(
        adUnitId: rewardedInterstitialAdId!,
        request: AdConsentManager.currentAdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (RewardedInterstitialAd ad) {
            _rewardedInterstitialAd = ad;
            _numRewardedInterstitialLoadAttempts = 0;
            _rewardedInterstitialAd!.setImmersiveMode(true);
            logger.d('Rewarded Interstitial ad loaded successfully');
          },
          onAdFailedToLoad: (LoadAdError error) async {
            logger.e('RewardedInterstitialAd failed to load: $error');
            _numRewardedInterstitialLoadAttempts += 1;
            _rewardedInterstitialAd = null;

            if (_numRewardedInterstitialLoadAttempts < maxFailedLoadAttempts) {
              await Future.delayed(const Duration(seconds: 1));
              await loadRewardedInterstitialAd();
            } else {
              _numRewardedInterstitialLoadAttempts = 0;
              logger.w('Rewarded Interstitial ad failed to load after max attempts');
            }
          },
        ),
      );
    } catch (e) {
      logger.e('Error in _loadRewardedInterstitialAd: $e');
    }
  }

  // 전면 광고 로드
  Future<void> loadInterstitialAd() async {
    // UMP 동의 게이트 (P1-13c)
    if (!AdConsentManager.canRequestAdsNow) {
      logger.d('Ad consent not granted - skipping interstitial load');
      return;
    }

    if (interstitialAdId == null) {
      fallbackInterstitial = Image.asset('assets/images/fallback_fullscreen.jpg');
      logger.w('Interstitial ad ID not found, using fallback');
      return;
    }

    if (_interstitialAd != null) {
      return; // 이미 로드된 광고가 있음
    }

    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdId!,
        request: AdConsentManager.currentAdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _interstitialAd = ad;
            _numInterstitialLoadAttempts = 0;
            _interstitialAd!.setImmersiveMode(true);
            logger.d('Interstitial ad loaded successfully');
          },
          onAdFailedToLoad: (LoadAdError error) async {
            logger.e('InterstitialAd failed to load: $error');
            _numInterstitialLoadAttempts += 1;
            _interstitialAd = null;

            if (_numInterstitialLoadAttempts < maxFailedLoadAttempts) {
              await Future.delayed(const Duration(seconds: 1));
              await loadInterstitialAd();
            } else {
              _numInterstitialLoadAttempts = 0;
              fallbackInterstitial = Image.asset('assets/images/fallback_fullscreen.jpg');
              logger.w('Interstitial ad failed to load after max attempts, using fallback');
            }
          },
        ),
      );
    } catch (e) {
      logger.e('Error in _loadInterstitialAd: $e');
      fallbackInterstitial = Image.asset('assets/images/fallback_fullscreen.jpg');
    }
  }

  // --- Show methods ---

  // 보상형 광고 (Rewarded Ad) 표시
  Future<void> showRewardedAd({
    required void Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailed,
  }) async {
    // 광고가 비활성화된 경우 조기 종료
    if (!config.adsEnabled) {
      logger.d('Ads are disabled - skipping rewarded ad');
      onAdFailed?.call();
      return;
    }

    await ensureInitialized();

    if (_rewardedAd == null) {
      logger.w('Rewarded ad not ready');
      onAdFailed?.call();
      loadRewardedAd(); // 다음 광고 로드 시도
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        logger.d('Rewarded ad dismissed');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // 다음 광고 미리 로드
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        logger.e('Rewarded ad failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // 다음 광고 미리 로드
        onAdFailed?.call();
      },
    );

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem item) {
          logger.d('User earned reward: ${item.amount} ${item.type}');
          onUserEarnedReward(item);
        },
      );
    } catch (e) {
      logger.e('Error showing rewarded ad: $e');
      onAdFailed?.call();
    }
  }

  // 보상형 전면 광고 (Rewarded Interstitial Ad) 표시
  Future<void> showRewardedInterstitialAd({
    required void Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailed,
  }) async {
    // 광고가 비활성화된 경우 조기 종료
    if (!config.adsEnabled) {
      logger.d('Ads are disabled - skipping rewarded interstitial ad');
      onAdFailed?.call();
      return;
    }

    await ensureInitialized();

    if (_rewardedInterstitialAd == null) {
      logger.w('Rewarded Interstitial ad not ready');
      onAdFailed?.call();
      loadRewardedInterstitialAd(); // 다음 광고 로드 시도
      return;
    }

    _rewardedInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedInterstitialAd ad) {
        logger.d('Rewarded Interstitial ad dismissed');
        ad.dispose();
        _rewardedInterstitialAd = null;
        loadRewardedInterstitialAd(); // 다음 광고 미리 로드
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (RewardedInterstitialAd ad, AdError error) {
        logger.e('Rewarded Interstitial ad failed to show: $error');
        ad.dispose();
        _rewardedInterstitialAd = null;
        loadRewardedInterstitialAd(); // 다음 광고 미리 로드
        onAdFailed?.call();
      },
    );

    try {
      await _rewardedInterstitialAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem item) {
          logger.d('User earned reward (interstitial): ${item.amount} ${item.type}');
          onUserEarnedReward(item);
        },
      );
    } catch (e) {
      logger.e('Error showing rewarded interstitial ad: $e');
      onAdFailed?.call();
    }
  }

  // 전면 광고 로드 대기 (타임아웃 포함)
  Future<bool> waitForInterstitialAd({Duration timeout = const Duration(seconds: 5)}) async {
    if (!config.adsEnabled) {
      return false;
    }

    // 동의 없으면 로드가 시작되지 않으므로 타임아웃 대기 없이 즉시 false
    if (!AdConsentManager.canRequestAdsNow) {
      return false;
    }

    if (_interstitialAd != null) {
      return true;
    }

    // 이미 로드 중이면 기다림
    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime) < timeout) {
      if (_interstitialAd != null) {
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return _interstitialAd != null;
  }

  // 전면 광고 표시 (콜백 포함 - splash용)
  Future<void> showInterstitialAdWithCallback({required VoidCallback onAdDismissed, VoidCallback? onAdFailed}) async {
    // 광고가 비활성화된 경우 바로 콜백 호출
    if (!config.adsEnabled) {
      logger.d('Ads are disabled - skipping interstitial ad');
      onAdDismissed();
      return;
    }

    if (_interstitialAd == null) {
      logger.w('Interstitial ad not ready, calling fallback');
      (onAdFailed ?? onAdDismissed)();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        logger.d('Interstitial ad dismissed');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // 다음 광고 미리 로드
        onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        logger.e('Interstitial ad failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // 다음 광고 미리 로드
        (onAdFailed ?? onAdDismissed)();
      },
    );

    try {
      await _interstitialAd!.show();
    } catch (e) {
      logger.e('Error showing interstitial ad: $e');
      (onAdFailed ?? onAdDismissed)();
    }
  }

  // 전면 광고 표시
  void showInterstitialAd(BuildContext context) {
    // 광고가 비활성화된 경우 조기 종료
    if (!config.adsEnabled) {
      logger.d('Ads are disabled - skipping interstitial ad');
      return;
    }

    if (_interstitialAd == null) {
      if (fallbackInterstitial != null) {
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            content: fallbackInterstitial,
            actions: [
              TextButton(
                child: Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      } else {
        logger.w('Warning: attempt to show interstitial before loaded.');
      }
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        logger.d('Interstitial ad dismissed');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // 다음 광고 미리 로드
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        logger.e('Interstitial ad failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // 다음 광고 미리 로드
      },
    );

    try {
      _interstitialAd!.show();
    } catch (e) {
      logger.e('Error showing interstitial ad: $e');
    }
  }

  // 세션 완료 후 전면 광고 표시 (프리미엄 사용자는 제외)
  Future<void> showSessionCompleteInterstitial({required bool isPremium, VoidCallback? onComplete}) async {
    debugPrint(
      '[AdService] showSessionCompleteInterstitial called (isPremium=$isPremium, adsEnabled=${config.adsEnabled})',
    );

    // 프리미엄 사용자는 광고 표시하지 않음
    if (isPremium) {
      debugPrint('[AdService] Premium user - skipping session complete interstitial ad');
      onComplete?.call();
      return;
    }

    // 광고가 비활성화된 경우 바로 콜백 호출
    if (!config.adsEnabled) {
      debugPrint('[AdService] Ads are disabled - skipping session complete interstitial ad');
      onComplete?.call();
      return;
    }

    debugPrint('[AdService] Calling showInterstitialAdWithCallback (interstitialAd=${_interstitialAd != null})');

    await showInterstitialAdWithCallback(
      onAdDismissed: () {
        debugPrint('[AdService] Session complete interstitial ad dismissed');
        onComplete?.call();
      },
      onAdFailed: () {
        debugPrint('[AdService] Session complete interstitial ad failed to show');
        onComplete?.call();
      },
    );
  }

  // 네이티브 광고 생성
  Future<NativeAd> _createNativeAd() async {
    // UMP 동의 게이트 (P1-13c)
    if (!AdConsentManager.canRequestAdsNow) {
      throw Exception('Ad consent not granted - native ad unavailable');
    }

    await ensureInitialized();

    if (nativeAdId == null) {
      throw Exception('Native Ad ID is not initialized');
    }

    final completer = Completer<NativeAd>();

    final nativeAd = NativeAd(
      adUnitId: nativeAdId!,
      request: AdConsentManager.currentAdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          completer.complete(ad as NativeAd);
          _numNativeLoadAttempts = 0;
          logger.d('Native ad loaded successfully');
        },
        onAdFailedToLoad: (ad, error) async {
          logger.e('Native ad failed to load: $error');
          ad.dispose();
          _numNativeLoadAttempts += 1;

          if (_numNativeLoadAttempts < maxFailedLoadAttempts) {
            completer.completeError(Exception('Native ad load failed: $error'));
          } else {
            _numNativeLoadAttempts = 0;
            completer.completeError(Exception('Native ad failed after max attempts: $error'));
          }
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 10.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.blue,
          style: NativeTemplateFontStyle.normal,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.grey,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.grey,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 12.0,
        ),
      ),
    );

    nativeAd.load();
    return completer.future;
  }

  // 네이티브 광고 위젯 반환
  Widget getNativeAdWidget(BuildContext context) {
    // 광고가 비활성화된 경우 빈 위젯 반환
    if (!config.adsEnabled) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<NativeAd>(
      future: _createNativeAd(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final nativeAd = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Container(
              height: 300.0,
              alignment: Alignment.center,
              child: AdWidget(ad: nativeAd),
            ),
          );
        } else if (snapshot.hasError) {
          logger.e('Native ad widget error: ${snapshot.error}');
          return const SizedBox.shrink();
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  // 리소스 해제
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;

    _rewardedAd?.dispose();
    _rewardedAd = null;

    _rewardedInterstitialAd?.dispose();
    _rewardedInterstitialAd = null;
  }
}
