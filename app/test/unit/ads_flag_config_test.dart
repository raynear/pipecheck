// 광고 기능 플래그 배선/의존성 캐스케이드 테스트 (P1-13c).
//
// 광고 엔진(AdConsentManager 등)은 ads 패키지로 추출됨 (P2-20c) — 순수 매핑
// 로직 테스트는 app/packages/ads/test/ad_consent_test.dart. 여기서는 앱 소유의
// AppFeatureConfig 플래그 배선만 고정한다.

import 'package:boilerplate/config/app_feature_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('광고 플래그 배선', () {
    test('premium 프로파일 → 광고와 함께 UMP 동의도 ON (컴플라이언스 opt-out)', () {
      AppFeatureConfig.applyBootConfig(profileName: 'premium');
      expect(AppFeatureConfig.isAdsEnabled, true);
      expect(AppFeatureConfig.isUmpConsentEnabled, true);
    });

    test('광고가 꺼지면 UMP/COPPA/TFUA 노브도 함께 꺼진다', () {
      AppFeatureConfig.applyBootConfig(
        profileName: 'premium',
        overrides: {
          'isAdsEnabled': false,
          'isUmpConsentEnabled': true,
          'isChildDirectedAdsEnabled': true,
          'isUnderAgeOfConsentEnabled': true,
        },
      );
      expect(AppFeatureConfig.isUmpConsentEnabled, false);
      expect(AppFeatureConfig.isChildDirectedAdsEnabled, false);
      expect(AppFeatureConfig.isUnderAgeOfConsentEnabled, false);
    });
  });
}
