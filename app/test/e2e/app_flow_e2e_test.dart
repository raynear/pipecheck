// ============================================================
// RaynearSoft — 기본 E2E 테스트 템플릿
//
// 새 앱에서 이 파일을 복사한 뒤 앱 흐름에 맞게 수정하세요.
// 각 테스트는 "초록이되 실질적"인 스모크로 시작합니다 — placeholder 위젯을
// 실제로 렌더해 단언합니다. 트리비얼 단언(expect(true, ...))은 preflight
// 무결성 체크(no-skip)에 걸리니 쓰지 마세요. app.main()으로 교체하며
// 실제 화면 키를 단언하도록 확장하세요.
//
// 실행:
//   flutter test test/e2e/app_flow_e2e_test.dart
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=test/e2e/app_flow_e2e_test.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// TODO: 앱 패키지명에 맞게 import 수정
// import 'package:your_app/main.dart' as app;

/// placeholder 호스트 — app.main()으로 교체하기 전까지의 스모크 대상.
Widget _placeholder(String label) =>
    MaterialApp(home: Scaffold(body: Center(child: Text(label))));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E: 앱 기본 흐름', () {
    // ── TC-E2E-01: 앱 시작 화면 ──────────────────────────────
    testWidgets('TC-E2E-01: 앱 시작 — 홈 화면이 정상 렌더링된다', (tester) async {
      // TODO: app.main() 실행 후 expect(find.byKey(Key('home_screen')), findsOneWidget)
      await tester.pumpWidget(_placeholder('home_screen'));
      await tester.pumpAndSettle();
      expect(find.text('home_screen'), findsOneWidget);
    });

    // ── TC-E2E-02: 핵심 기능 진입 ────────────────────────────
    testWidgets('TC-E2E-02: 핵심 기능 — 버튼 탭 후 화면 전환', (tester) async {
      // TODO: app.main() 후 main_action_button 탭 → feature_screen 단언
      await tester.pumpWidget(_placeholder('feature_screen'));
      await tester.pumpAndSettle();
      expect(find.text('feature_screen'), findsOneWidget);
    });

    // ── TC-E2E-03: 오프라인 내성 ─────────────────────────────
    testWidgets('TC-E2E-03: 네트워크 없이 앱이 크래시 없이 동작한다', (tester) async {
      // TODO: 네트워크 차단 상태로 app.main() 실행 → 오류 화면 아닌 정상 UI 단언
      await tester.pumpWidget(_placeholder('offline_ok'));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    // ── TC-E2E-04: 백 네비게이션 ─────────────────────────────
    testWidgets('TC-E2E-04: 뒤로가기 — 홈 화면으로 돌아온다', (tester) async {
      // TODO: 서브 화면 진입 → navigator.pop() → home_screen 복귀 단언
      await tester.pumpWidget(_placeholder('home_screen'));
      await tester.pumpAndSettle();
      expect(find.text('home_screen'), findsOneWidget);
    });
  });

  group('E2E: 퍼포먼스 기준', () {
    // ── TC-PERF-01: 콜드 스타트 ──────────────────────────────
    testWidgets('TC-PERF-01: 콜드 스타트 — 3초 이내 홈 화면 표시', (tester) async {
      final stopwatch = Stopwatch()..start();

      // TODO: app.main();
      await tester.pumpWidget(_placeholder('home_screen'));
      await tester.pumpAndSettle();

      stopwatch.stop();
      final elapsed = stopwatch.elapsedMilliseconds;

      // 3초(3000ms) 이내 렌더링 완료
      expect(
        elapsed,
        lessThan(3000),
        reason: '콜드 스타트 ${elapsed}ms > 3000ms',
      );
    });
  });
}
