// `context.design`/`context.colors`가 디자인 시스템 교체에 **반응**하는지.
//
// 배경: 예전 `context.design`은 `container.read(designSystemProvider)`라 구독이 아니었다.
// 디자인 시스템을 바꿔도 `context.colors`만 쓰고 `Theme.of`는 안 부르는 위젯(앱에 152곳)은
// 다시 그려지지 않아 옛 색을 유지했다. 이제 테마(ThemeExtension)로 내려 받으므로,
// 테마가 바뀌면 의존한 위젯이 다시 그려진다.
//
// 위젯 인스턴스를 한 번만 만들어 `MaterialApp.home`에 넘긴다 — 같은 인스턴스는 부모가
// 다시 빌드돼도 프레임워크가 건너뛰므로, **의존성으로만** 다시 그려질 수 있다.

import 'package:pipecheck/core/design/design.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _Settings extends SettingsNotifier {
  @override
  Settings build() => Settings(
    onBoard: true,
    displayMode: ThemeMode.light,
    themeColor: defaultThemeColor,
    bodyFont: 'Roboto', // 번들된 폰트 — 네트워크 조회 방지(theme_locale_test와 같은 이유)
    fontSize: defaultFontSize,
    bold: false,
    language: const Locale('en'),
    userAuthOption: UserAuthOption.none,
    useICloud: false,
    useNotification: false,
    useReminder: false,
    reminderTime: const TimeOfDay(hour: 9, minute: 0),
    appLaunchCount: 1,
  );

  void pickDesign(DesignSystemType type) =>
      state = state.copyWith(designSystem: type);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('디자인 시스템을 바꾸면 context.design만 쓰는 위젯도 다시 그려진다', (tester) async {
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(_Settings.new)],
    );
    addTearDown(container.dispose);

    var builds = 0;
    final probe = Builder(
      builder: (context) {
        builds++;
        // Theme.of를 부르지 않는다 — 앱의 152개 호출부와 같은 모양이다.
        return Text(context.design.name, textDirection: TextDirection.ltr);
      },
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final (light, dark, mode) = ref.watch(themeProvider);
            return MaterialApp(
              theme: light,
              darkTheme: dark,
              themeMode: mode,
              home: probe,
            );
          },
        ),
      ),
    );
    expect(find.text('Material Design 3'), findsOneWidget);

    (container.read(settingsProvider.notifier) as _Settings).pickDesign(
      DesignSystemType.boldMinimalism,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Bold Minimalism'),
      findsOneWidget,
      reason: '옛 디자인 시스템 이름이 남았다 — 구독이 아니다',
    );
    expect(builds, greaterThan(1));
  });

  testWidgets('앱 테마가 없는 컨텍스트(기본 MaterialApp)에서는 provider 값으로 폴백한다', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(_Settings.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Builder(builder: (c) => Text(c.design.name))),
      ),
    );

    expect(find.text('Material Design 3'), findsOneWidget);
  });

  test('themeProvider의 모든 테마가 현재 디자인 시스템을 확장으로 싣는다', () {
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(_Settings.new)],
    );
    addTearDown(container.dispose);

    String? nameOf(ThemeData t) =>
        t.extension<DesignSystemExtension>()?.design.name;

    var (light, dark, _) = container.read(themeProvider);
    expect(nameOf(light), 'Material Design 3');
    expect(nameOf(dark), 'Material Design 3');

    (container.read(settingsProvider.notifier) as _Settings).pickDesign(
      DesignSystemType.boldMinimalism,
    );
    (light, dark, _) = container.read(themeProvider);
    expect(nameOf(light), 'Bold Minimalism');
    expect(nameOf(dark), 'Bold Minimalism');
  });
}
