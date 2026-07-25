// AdMob UMP 동의/NPA 폴백/COPPA 노브 테스트 (P1-13c, P2-20c 패키지화)
//
// 플랫폼 채널이 필요한 UMP 호출(gatherConsent 등)은 단위 테스트 불가 —
// 순수 매핑 로직(AdRequest/RequestConfiguration 빌더)과 개인화 동의 주입만 고정.
// 앱 기능 플래그 캐스케이드 테스트는 앱 측(test/unit/ads_flag_config_test.dart).

import 'package:ads/ads.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  group('buildAdRequest (NPA 폴백 매핑)', () {
    test('개인화 허용 → nonPersonalizedAds 미지정 (UMP TC string이 통제)', () {
      final request =
          AdConsentManager.buildAdRequest(personalizedAdsAllowed: true);
      expect(request.nonPersonalizedAds, isNull);
    });

    test('개인화 불허 → npa=1 (nonPersonalizedAds: true)', () {
      final request =
          AdConsentManager.buildAdRequest(personalizedAdsAllowed: false);
      expect(request.nonPersonalizedAds, true);
    });
  });

  group('buildRequestConfiguration (COPPA/TFUA 노브)', () {
    test('노브 둘 다 꺼짐 → unspecified + 등급 제한 없음', () {
      final config = AdConsentManager.buildRequestConfiguration(
          childDirected: false, underAgeOfConsent: false);
      expect(config.tagForChildDirectedTreatment,
          TagForChildDirectedTreatment.unspecified);
      expect(config.tagForUnderAgeOfConsent, TagForUnderAgeOfConsent.unspecified);
      expect(config.maxAdContentRating, isNull);
    });

    test('COPPA 노브 → childDirected=yes + 등급 G', () {
      final config = AdConsentManager.buildRequestConfiguration(
          childDirected: true, underAgeOfConsent: false);
      expect(config.tagForChildDirectedTreatment, TagForChildDirectedTreatment.yes);
      expect(config.tagForUnderAgeOfConsent, TagForUnderAgeOfConsent.unspecified);
      expect(config.maxAdContentRating, MaxAdContentRating.g);
    });

    test('TFUA 노브 → underAge=yes + 등급 G', () {
      final config = AdConsentManager.buildRequestConfiguration(
          childDirected: false, underAgeOfConsent: true);
      expect(config.tagForChildDirectedTreatment,
          TagForChildDirectedTreatment.unspecified);
      expect(config.tagForUnderAgeOfConsent, TagForUnderAgeOfConsent.yes);
      expect(config.maxAdContentRating, MaxAdContentRating.g);
    });

    test('둘 다 켜짐 → COPPA 우선 (두 태그 동시 yes 금지)', () {
      final config = AdConsentManager.buildRequestConfiguration(
          childDirected: true, underAgeOfConsent: true);
      expect(config.tagForChildDirectedTreatment, TagForChildDirectedTreatment.yes);
      expect(config.tagForUnderAgeOfConsent, TagForUnderAgeOfConsent.unspecified);
      expect(config.maxAdContentRating, MaxAdContentRating.g);
    });
  });

  group('personalizedAdsAllowed (주입된 동의 콜백)', () {
    test('resolver가 true면 개인화 허용', () {
      AdConsentManager.configure(
        config: const AdsConfig.disabled(),
        personalizedAds: () => true,
      );
      expect(AdConsentManager.personalizedAdsAllowed(), true);
    });

    test('resolver가 false면 개인화 불허', () {
      AdConsentManager.configure(
        config: const AdsConfig.disabled(),
        personalizedAds: () => false,
      );
      expect(AdConsentManager.personalizedAdsAllowed(), false);
    });
  });
}
