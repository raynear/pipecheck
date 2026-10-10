// preflight:coverage-exempt: AdService 싱글톤·광고 SDK 시임 — 스플래시 테스트는 이 함수를 fake로 대체한다
import 'package:ads/ads.dart';
import 'package:flutter/foundation.dart';
import 'package:pipecheck/config/app_feature_config.dart';

/// 스플래시의 시작 광고. 앱 오프닝(1순위) 또는 스플래시 전면(2순위)을 보여 주고 true,
/// 광고가 없거나 못 불러오면 false를 돌려준다. 광고가 닫히거나 실패하면 [onDone]을 부른다.
Future<bool> showSplashAd({required VoidCallback onDone}) async {
  if (AppFeatureConfig.isAppOpenAdEnabled) {
    final ready = await AdService().waitForAppOpenAd(timeout: const Duration(seconds: 5));
    if (!ready) return false;
    await AdService().showAppOpenAd(onAdDismissed: onDone, onAdFailed: onDone);
    return true;
  }
  if (AppFeatureConfig.isSplashInterstitialAdEnabled) {
    final ready = await AdService().waitForInterstitialAd(timeout: const Duration(seconds: 5));
    if (!ready) return false;
    await AdService().showInterstitialAdWithCallback(onAdDismissed: onDone, onAdFailed: onDone);
    return true;
  }
  return false;
}
