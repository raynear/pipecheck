// RC→플래그 override 브리지 메커니즘 테스트 (P2-23.5b).
//
// AppFeatureConfig.applyRemoteOverrides의 방향별 정책을 고정한다:
// - OFF(false)는 무조건 적용 (kill-switch),
// - ON(true)은 능력 가드를 통과할 때만 적용 (미초기화 서비스 force-ON 차단).
//
// 입력 맵은 RemoteConfigService.remoteFeatureOverrides()가 source=remote 키만
// 추려 넘겨준다(Firebase 의존이라 여기서는 테스트하지 않음) — 이 테스트는
// 이미 필터된 맵을 받았다고 가정한다.

import 'package:pipecheck/config/app_feature_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RC 플래그 override — OFF (kill-switch)', () {
    test('OFF는 가드 없이 항상 적용된다', () {
      AppFeatureConfig.applyBootConfig(profileName: 'premium');
      expect(AppFeatureConfig.isAdsEnabled, true);

      AppFeatureConfig.applyRemoteOverrides({'isAdsEnabled': false});
      expect(AppFeatureConfig.isAdsEnabled, false);
    });

    test('부모를 끄면 자식 플래그도 캐스케이드로 꺼진다', () {
      AppFeatureConfig.applyBootConfig(profileName: 'premium');
      expect(AppFeatureConfig.isFirebaseEnabled, true);
      expect(AppFeatureConfig.isFirebaseAnalyticsEnabled, true);

      AppFeatureConfig.applyRemoteOverrides({'isFirebaseEnabled': false});
      expect(AppFeatureConfig.isFirebaseEnabled, false);
      // resolveDependencies가 자식을 강제 OFF
      expect(AppFeatureConfig.isFirebaseAnalyticsEnabled, false);
      expect(AppFeatureConfig.isFirebaseRemoteConfigEnabled, false);
    });
  });

  group('RC 플래그 override — ON (능력 가드)', () {
    test('가드가 없으면 ON 요청은 거부된다', () {
      AppFeatureConfig.applyBootConfig(profileName: 'standard');
      expect(AppFeatureConfig.isAdsEnabled, false);

      AppFeatureConfig.applyRemoteOverrides({'isAdsEnabled': true});
      expect(AppFeatureConfig.isAdsEnabled, false);
    });

    test('가드가 false를 반환하면 ON 요청은 거부된다', () {
      AppFeatureConfig.applyBootConfig(profileName: 'standard');

      AppFeatureConfig.applyRemoteOverrides(
        {'isAdsEnabled': true},
        onGuards: {'isAdsEnabled': () => false},
      );
      expect(AppFeatureConfig.isAdsEnabled, false);
    });

    test('가드가 통과하면 ON 요청이 적용된다', () {
      AppFeatureConfig.applyBootConfig(profileName: 'standard');
      expect(AppFeatureConfig.isAdsEnabled, false);

      AppFeatureConfig.applyRemoteOverrides(
        {'isAdsEnabled': true},
        onGuards: {'isAdsEnabled': () => true},
      );
      expect(AppFeatureConfig.isAdsEnabled, true);
    });

    test('부모가 꺼져 있으면 가드를 통과한 자식 ON도 의존성으로 다시 꺼진다', () {
      AppFeatureConfig.applyBootConfig(profileName: 'minimal');
      // minimal = firebase OFF
      expect(AppFeatureConfig.isFirebaseEnabled, false);

      AppFeatureConfig.applyRemoteOverrides(
        {'isFirebaseAnalyticsEnabled': true},
        onGuards: {'isFirebaseAnalyticsEnabled': () => true},
      );
      // 가드는 통과했지만 부모(isFirebaseEnabled)가 OFF → resolveDependencies가 OFF
      expect(AppFeatureConfig.isFirebaseAnalyticsEnabled, false);
    });
  });

  group('RC 플래그 override — 견고성', () {
    test('알 수 없는 키는 무시되고 예외를 던지지 않는다', () {
      AppFeatureConfig.applyBootConfig(profileName: 'standard');

      expect(
        () => AppFeatureConfig.applyRemoteOverrides({
          'isNotARealFlag': false,
          'anotherGhost': true,
        }),
        returnsNormally,
      );
    });

    test('빈 맵은 플래그를 바꾸지 않는다', () {
      AppFeatureConfig.applyBootConfig(profileName: 'standard');
      final before = AppFeatureConfig.toMap();

      AppFeatureConfig.applyRemoteOverrides(const {});
      expect(AppFeatureConfig.toMap(), before);
    });
  });
}
