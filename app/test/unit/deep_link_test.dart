// 딥링크 URI→라우트 매핑 + 플래그 배선 테스트 (P2-23a Stage 1a).
//
// DeepLinkService 자체는 app_links 플랫폼 채널에 의존해 단위 테스트에서 제외.
// 실제 라우팅 로직(deepLinkLocation 순수 함수)과 플래그 배선만 고정한다.

import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deepLinkLocation', () {
    test('커스텀 스킴(host sentinel + path) → 라우트', () {
      expect(deepLinkLocation(Uri.parse('myapp://open/settings')), '/settings');
    });

    test('유니버설 링크(https host + path) → 라우트', () {
      expect(deepLinkLocation(Uri.parse('https://example.com/stats')), '/stats');
    });

    test('쿼리 문자열을 보존한다', () {
      expect(
        deepLinkLocation(Uri.parse('myapp://open/subscription?ref=promo')),
        '/subscription?ref=promo',
      );
      expect(
        deepLinkLocation(Uri.parse('https://x.com/badges?id=3')),
        '/badges?id=3',
      );
    });

    test('화이트리스트 밖 라우트는 null(무시)', () {
      expect(deepLinkLocation(Uri.parse('myapp://open/hack')), isNull);
    });

    test('플로우 내부 라우트(auth/login/splash/permission)는 null', () {
      for (final p in ['auth', 'login', 'splash', 'permission']) {
        expect(deepLinkLocation(Uri.parse('myapp://open/$p')), isNull,
            reason: '$p 는 딥링크로 도달 불가여야 함');
      }
    });

    test('path 없는 링크는 null', () {
      expect(deepLinkLocation(Uri.parse('myapp://open')), isNull);
      expect(deepLinkLocation(Uri.parse('https://example.com')), isNull);
    });
  });

  group('isDeepLinkEnabled 플래그 배선', () {
    test('기본 OFF (opt-in)', () {
      AppFeatureConfig.applyBootConfig(profileName: 'minimal');
      expect(AppFeatureConfig.isDeepLinkEnabled, false);
      AppFeatureConfig.applyBootConfig(profileName: 'enterprise');
      expect(AppFeatureConfig.isDeepLinkEnabled, true); // enterprise=enableAll
    });

    test('FF_ override로 켤 수 있다', () {
      AppFeatureConfig.applyBootConfig(
        profileName: 'minimal',
        overrides: {'isDeepLinkEnabled': true},
      );
      expect(AppFeatureConfig.isDeepLinkEnabled, true);
    });
  });
}
