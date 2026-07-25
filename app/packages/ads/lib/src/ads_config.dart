/// 광고 엔진 기능 게이트 + 광고 단위 ID 주입 구조체.
///
/// 패키지는 앱의 `AppFeatureConfig`나 `flutter_dotenv`에 의존하지 않는다 —
/// 앱이 부팅 시점에 플래그 값을 [AdsConfig]로, .env에서 해석한 광고 단위 ID를
/// [AdUnitIds]로 스냅샷해 `AdService.configure`로 주입한다.
library;

/// 광고 엔진이 읽는 기능 플래그 묶음. 앱 `AppFeatureConfig`의 해당 플래그를
/// 부팅 시점에 스냅샷한 값. 의존성 캐스케이드(ads off → 자식 off)는 앱이
/// 스냅샷 전에 이미 적용하므로 패키지에서 재구현하지 않는다.
class AdsConfig {
  const AdsConfig({
    required this.adsEnabled,
    required this.appOpenAdEnabled,
    required this.umpConsentEnabled,
    required this.childDirectedAdsEnabled,
    required this.underAgeOfConsentEnabled,
  });

  /// 모든 광고 비활성. `configure` 전 기본값이며 엔진은 이 값으로 no-op.
  const AdsConfig.disabled()
      : adsEnabled = false,
        appOpenAdEnabled = false,
        umpConsentEnabled = false,
        childDirectedAdsEnabled = false,
        underAgeOfConsentEnabled = false;

  /// 광고 전체 on/off (마스터 게이트). AppFeatureConfig.isAdsEnabled.
  final bool adsEnabled;

  /// 앱 오프닝 광고 on/off. isAppOpenAdEnabled.
  final bool appOpenAdEnabled;

  /// UMP/EEA 동의 수집 여부. isUmpConsentEnabled.
  final bool umpConsentEnabled;

  /// COPPA(아동 대상) 노브. isChildDirectedAdsEnabled.
  final bool childDirectedAdsEnabled;

  /// TFUA(동의 연령 미만) 노브. isUnderAgeOfConsentEnabled.
  final bool underAgeOfConsentEnabled;
}

/// .env에서 해석된 광고 단위 ID 묶음(플랫폼 무관 — 앱이 IOS/AOS 접두를 해석).
///
/// 패키지는 dotenv 키 명명이나 ID 출처를 알지 못한다 — 앱이 해석해 주입한다.
class AdUnitIds {
  const AdUnitIds({
    this.banner,
    this.rewarded,
    this.rewardedInterstitial,
    this.interstitial,
    this.native,
    this.appOpen,
  });

  final String? banner;
  final String? rewarded;
  final String? rewardedInterstitial;
  final String? interstitial;
  final String? native;
  final String? appOpen;
}
