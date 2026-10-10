// SnackBarService 큐 계약.
//
// 배경: 스낵바는 "탭하면 닫힘"(top_snackbar 기본)과 "표시 시간이 지나면 닫힘"(Timer)이 둘 다
// 완료 처리를 불렀다. 탭으로 닫은 뒤에도 Timer가 살아 있어 `removeFirst`가 두 번 일어나
// **큐의 다음 메시지가 한 번도 안 보이고 사라졌다**. 실제 오버레이로 재현한다 —
// 완료 처리 함수만 직접 부르면 탭 경로의 배선(onTap → 완료)이 검증되지 않는다.

import 'package:pipecheck/core/router.dart';
import 'package:pipecheck/core/services/snackbar_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: SizedBox.expand()),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [goRouterProvider.overrideWithValue(router)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

List<String> _queue(ProviderContainer c) =>
    c.read(snackBarProvider).map((s) => s.message).toList();

void main() {
  testWidgets('표시 시간이 지나면 맨 앞 항목만 제거된다', (tester) async {
    final container = await _pumpApp(tester);
    final service = container.read(snackBarServiceProvider);

    service.showInfo('A');
    service.showInfo('B');
    service.processSnackBarQueue();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('A'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(_queue(container), ['B']);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('탭으로 닫은 뒤 만료 타이머가 다음 메시지까지 지우지 않는다', (tester) async {
    final container = await _pumpApp(tester);
    final service = container.read(snackBarServiceProvider);

    service.showInfo('A');
    service.showInfo('B');
    service.processSnackBarQueue();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(
      const Duration(milliseconds: 1500),
    ); // 등장 애니메이션(1.2초)이 끝나야 탭이 닿는다
    expect(find.text('A'), findsOneWidget);

    await tester.tap(find.text('A'));
    await tester.pump(
      const Duration(milliseconds: 500),
    ); // 탭 바운스 애니메이션 뒤에 onTap이 불린다
    expect(_queue(container), ['B'], reason: '탭으로 A가 제거된다');

    // A의 표시 시간(3초+100ms)이 지나도 B는 큐에 남아 있어야 한다.
    await tester.pump(const Duration(seconds: 4));
    expect(_queue(container), [
      'B',
    ], reason: '만료 타이머가 두 번째 removeFirst로 B를 날렸다');
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('이미 제거된 항목의 완료 신호는 큐의 다른 항목을 건드리지 않는다', (tester) async {
    final container = await _pumpApp(tester);
    final service = container.read(snackBarServiceProvider);
    const a = SnackBarInfo(message: 'A', type: SnackBarType.info);

    service.showInfo('B');
    service.onSnackBarComplete(a); // 큐 맨 앞은 B — A의 늦은 완료 신호다

    expect(_queue(container), ['B']);
  });

  testWidgets('cancelAll은 대기 중인 만료 타이머도 취소한다', (tester) async {
    final container = await _pumpApp(tester);
    final service = container.read(snackBarServiceProvider);

    service.showInfo('A');
    service.processSnackBarQueue();
    await tester.pump(const Duration(milliseconds: 200));
    service.cancelAll();
    service.showInfo('C'); // cancelAll 뒤에 들어온 새 메시지

    await tester.pump(const Duration(seconds: 4));
    expect(_queue(container), ['C'], reason: '취소된 A의 타이머가 C를 지웠다');
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}
