// isPinAuthEnabled 플래그 배선 테스트 (P2-23h ②).

import 'package:pipecheck/config/app_feature_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isPinAuthEnabled 플래그', () {
    test('기본 OFF (opt-in)', () {
      AppFeatureConfig.applyBootConfig(profileName: 'standard');
      expect(AppFeatureConfig.isPinAuthEnabled, false);
    });

    test('FF override로 켤 수 있다', () {
      AppFeatureConfig.applyBootConfig(
        profileName: 'standard',
        overrides: {'isPinAuthEnabled': true},
      );
      expect(AppFeatureConfig.isPinAuthEnabled, true);
    });

    test('isAuthenticationEnabled가 OFF면 의존성으로 자동 OFF', () {
      AppFeatureConfig.applyBootConfig(
        profileName: 'standard',
        overrides: {
          'isPinAuthEnabled': true,
          'isAuthenticationEnabled': false,
        },
      );
      expect(AppFeatureConfig.isPinAuthEnabled, false);
    });
  });
}
