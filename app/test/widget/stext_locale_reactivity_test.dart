// SText가 런타임 언어 변경에 즉시 반응하는지 검증 (포크 앱 고질 버그 회귀 가드).
//
// 근본 원인: SText가 context 없는 `String.tr()`(전역 Localization.instance)를 써서
// locale InheritedWidget을 구독하지 않았다. 그래서 context.setLocale() 후에도
// GoRouter가 보존한 현재 화면의 SText는 rebuild되지 않아, 화면 전환/재시작 전까지
// 옛 언어가 남았다.
//
// 이 테스트는 그 시나리오를 재현한다: SText를 **const 페이지** 안에 두어, 언어가
// 바뀌어도 부모가 SText를 rebuild시키지 않게 한다(= GoRouter 페이지 보존과 동형).
// 오직 SText 자신이 locale을 구독할 때만 다시 그려진다. 번역은 실제 에셋 대신
// 인메모리 AssetLoader로 주입해(en=Settings / ko=설정) 테스트를 밀폐·결정적으로 둔다.

import 'dart:async';

import 'package:pipecheck/core/widgets/common/semantics.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _en = Locale('en', 'US');
const _ko = Locale('ko', 'KR');

// 에셋 없이 locale별 번역을 즉시 반환(microtask 해소 → pump로 진행).
class _MemLoader extends AssetLoader {
  const _MemLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      locale.languageCode == 'ko'
          ? {'Settings': '설정'}
          : {'Settings': 'Settings'};
}

// const → EasyLocalization/MaterialApp이 rebuild돼도 이 페이지는 다시 build되지
// 않는다(동일 const 인스턴스). SText가 스스로 locale을 구독해야만 갱신된다.
class _Page extends StatelessWidget {
  const _Page();
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: SText('Settings')));
}

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) => MaterialApp(
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        home: const _Page(),
      );
}

Future<void> settle(WidgetTester tester) async {
  // easy_localization 로드를 pumpAndSettle이 정착시키지 못해 유한 pump로 대체.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('언어 변경 시 현재 화면 SText가 부모 rebuild 없이 즉시 갱신된다', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [_en, _ko],
        path: 'unused',
        assetLoader: const _MemLoader(),
        fallbackLocale: _en,
        startLocale: _en,
        child: const _App(),
      ),
    );
    await settle(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('설정'), findsNothing);

    // 실제 버그 트리거: setLocale만 호출 (부모 페이지는 const라 rebuild 안 됨).
    // await하지 않고 발사 후 pump — 직접 await하면 pump가 멈춰 데드락.
    unawaited(tester.element(find.byType(Scaffold)).setLocale(_ko));
    await settle(tester);

    expect(find.text('설정'), findsOneWidget,
        reason: 'SText가 locale을 구독하지 않으면 부모 미rebuild 시 옛 언어가 남는다.');
    expect(find.text('Settings'), findsNothing);
  });
}
