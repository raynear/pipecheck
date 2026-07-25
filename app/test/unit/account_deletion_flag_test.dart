// 계정 삭제 플래그 배선 테스트 (P1-13b)
//
// isAccountDeletionEnabled가 프로파일/의존성 해석에 올바르게 참여하는지 고정.
// 컴플라이언스 플래그라 기본 ON(opt-out)이어야 하고, 인증 자체가 꺼지면
// 함께 꺼져야 한다.

import 'package:pipecheck/config/app_feature_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('모든 프로파일에서 기본 ON (컴플라이언스 opt-out)', () {
    for (final profile in ['minimal', 'standard', 'premium', 'enterprise']) {
      AppFeatureConfig.applyBootConfig(profileName: profile);
      expect(AppFeatureConfig.isAccountDeletionEnabled, true,
          reason: '$profile 프로파일에서 계정 삭제가 기본 OFF면 컴플라이언스 위반 소지');
    }
  });

  test('isAuthenticationEnabled가 꺼지면 함께 꺼진다 (의존성 해석)', () {
    AppFeatureConfig.applyBootConfig(
      profileName: 'standard',
      overrides: {'isAuthenticationEnabled': false},
    );
    expect(AppFeatureConfig.isAccountDeletionEnabled, false);
  });

  test('명시적 opt-out 가능', () {
    AppFeatureConfig.applyBootConfig(
      profileName: 'standard',
      overrides: {'isAccountDeletionEnabled': false},
    );
    expect(AppFeatureConfig.isAccountDeletionEnabled, false);
  });
}
