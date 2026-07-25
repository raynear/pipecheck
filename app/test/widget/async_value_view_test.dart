// AsyncValueView 상태 매핑 테스트 (P2-23c).
//
// 기본 위젯(LoadingIndicator/AppErrorWidget/EmptyState)은 디자인 시스템
// (context.colors 등 = ProviderScope.containerOf)을 쓰므로 ProviderScope로 감싼다.

import 'package:boilerplate/core/widgets/async/async_value_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('AsyncValueView', () {
    testWidgets('loading → 기본 LoadingIndicator(CircularProgressIndicator)', (tester) async {
      await tester.pumpWidget(_host(
        AsyncValueView<int>(
          value: const AsyncLoading(),
          data: (v) => Text('value=$v'),
        ),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('data → 데이터 빌더를 렌더', (tester) async {
      await tester.pumpWidget(_host(
        AsyncValueView<int>(
          value: const AsyncData(42),
          data: (v) => Text('value=$v'),
        ),
      ));
      expect(find.text('value=42'), findsOneWidget);
    });

    testWidgets('error → 기본 에러 위젯 + 재시도 콜백', (tester) async {
      var retried = 0;
      await tester.pumpWidget(_host(
        AsyncValueView<int>(
          value: AsyncError(Exception('boom'), StackTrace.empty),
          onRetry: () => retried++,
          data: (v) => Text('value=$v'),
        ),
      ));
      // EasyLocalization 미초기화 테스트 환경 → .tr()는 키를 그대로 반환한다.
      expect(find.text('async.error'), findsOneWidget);
      await tester.tap(find.text('common.retry'));
      expect(retried, 1);
    });

    testWidgets('errorMessage 매핑이 기본 문구를 대체', (tester) async {
      await tester.pumpWidget(_host(
        AsyncValueView<int>(
          value: AsyncError(Exception('boom'), StackTrace.empty),
          errorMessage: (e) => '커스텀 에러',
          data: (v) => Text('value=$v'),
        ),
      ));
      expect(find.text('커스텀 에러'), findsOneWidget);
    });

    testWidgets('data가 비었고 isEmpty=true → 기본 EmptyState', (tester) async {
      await tester.pumpWidget(_host(
        AsyncValueView<List<int>>(
          value: const AsyncData<List<int>>([]),
          isEmpty: (l) => l.isEmpty,
          data: (l) => Text('len=${l.length}'),
        ),
      ));
      expect(find.text('async.empty'), findsOneWidget);
      expect(find.text('len=0'), findsNothing);
    });

    testWidgets('빈 데이터 + 커스텀 empty 위젯', (tester) async {
      await tester.pumpWidget(_host(
        AsyncValueView<List<int>>(
          value: const AsyncData<List<int>>([]),
          isEmpty: (l) => l.isEmpty,
          empty: const Text('아무것도 없어요'),
          data: (l) => Text('len=${l.length}'),
        ),
      ));
      expect(find.text('아무것도 없어요'), findsOneWidget);
    });

    testWidgets('isEmpty=false → 데이터 빌더 렌더', (tester) async {
      await tester.pumpWidget(_host(
        AsyncValueView<List<int>>(
          value: const AsyncData<List<int>>([1, 2, 3]),
          isEmpty: (l) => l.isEmpty,
          data: (l) => Text('len=${l.length}'),
        ),
      ));
      expect(find.text('len=3'), findsOneWidget);
    });
  });
}
