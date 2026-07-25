// 회귀 테스트 (P1-13a): SplashView 도달성
//
// 과거 router.redirect가 /splash를 즉시 onboarding/auth/home으로 튕겨내
// SplashView가 영원히 렌더링되지 않았다 — ATT/프라이버시 동의 플로우 전체가
// 도달 불가. 이 테스트는 첫 프레임에 SplashView가 실제로 그려지고,
// 스플래시 지연 후 자체 네비게이션으로 떠나는 것을 고정한다.

import 'package:boilerplate/config/app_feature_config.dart';
import 'package:boilerplate/core/router.dart';
import 'package:boilerplate/features/splash/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('SplashView가 첫 프레임에 렌더링된다 (redirect가 가로채지 않음)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppFeatureConfig.applyBootConfig(profileName: 'minimal');

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(goRouterProvider),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SplashView), findsOneWidget,
        reason: 'redirect가 /splash를 가로채면 동의 플로우가 도달 불가');

    // 스플래시 지연(2s) 경과 후 자체 네비게이션으로 splash를 떠나야 함
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byType(SplashView), findsNothing,
        reason: 'SplashView가 자체 네비게이션으로 다음 화면에 진입해야 함');
  });
}
