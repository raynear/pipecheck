// 부팅 스모크 테스트 (P0-9)
//
// 이전의 템플릿 기본 counter 테스트는 이 앱과 무관한 위젯을 찾아 항상
// 실패했다. 대신 부팅 배선이 깨지지 않는지를 검증한다:
// ProviderScope 컨테이너에서 라우터/테마 프로바이더가 조립되는지.

import 'package:boilerplate/config/app_feature_config.dart';
import 'package:boilerplate/core/design/design_system_provider.dart';
import 'package:boilerplate/core/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('boot smoke: ProviderScope 핵심 프로바이더 조립', (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppFeatureConfig.applyBootConfig(profileName: 'minimal');

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(goRouterProvider), isNotNull,
        reason: '라우터 프로바이더 조립 실패 = 부팅 불가');
    expect(container.read(themeProvider), isNotNull,
        reason: '테마 프로바이더 조립 실패 = 부팅 불가');
  });
}
