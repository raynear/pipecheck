// AdaptiveButton 접근성 계약 — 버튼 역할·활성 상태·로딩 중 이름.

import 'package:pipecheck/core/widgets/buttons/adaptive_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget body) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(home: Scaffold(body: body)),
  ),
);

void main() => _semanticsTests();

// 스크린리더가 이 위젯을 **버튼으로** 읽는지. GestureDetector+Container 조합은 탭 동작은
// 있어도 "버튼"·"비활성" 역할이 없어, 페이월 CTA(이 위젯)가 일반 텍스트처럼 읽혔다.
void _semanticsTests() {
  group('AdaptiveButton 접근성', () {
    testWidgets('활성 버튼은 버튼 역할·활성 상태·라벨을 가진다', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, AdaptiveButton(label: 'Go', onPressed: () {}));

      expect(
        tester.getSemantics(find.text('Go')),
        isSemantics(
          label: 'Go',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('라벨이 시맨틱 트리에 한 번만 나오고 탭 동작도 한 노드에만 있다', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, AdaptiveButton(label: 'Go', onPressed: () {}));

      var labelNodes = 0;
      var tapNodes = 0;
      void walk(SemanticsNode n) {
        if (n.isMergedIntoParent) return; // MergeSemantics가 합친 하위 노드는 읽히지 않는다
        final d = n.getSemanticsData();
        if (d.label.contains('Go')) labelNodes++;
        if (d.hasAction(SemanticsAction.tap)) tapNodes++;
        n.visitChildren((c) {
          walk(c);
          return true;
        });
      }

      walk(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
      expect(labelNodes, 1, reason: '하위 Text·InkWell이 라벨을 또 노출하면 두 번 읽힌다');
      expect(tapNodes, 1);
      handle.dispose();
    });

    testWidgets('onPressed가 없으면 비활성 버튼으로 읽힌다', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const AdaptiveButton(label: 'Go'));

      expect(
        tester.getSemantics(find.text('Go')),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
      handle.dispose();
    });

    testWidgets('로딩 중에는 이름을 유지한 채 비활성이고 탭 동작이 없다', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        AdaptiveButton(label: 'Go', isLoading: true, onPressed: () {}),
      );

      final node = tester.getSemantics(find.byType(CircularProgressIndicator));
      expect(
        node,
        isSemantics(
          label: 'Go',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('child 경로(label 빈 문자열)도 child 글자가 버튼 라벨이 된다', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        AdaptiveButton(label: '', onPressed: () {}, child: const Text('Start')),
      );

      expect(
        tester.getSemantics(find.text('Start')),
        isSemantics(
          label: 'Start',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
        ),
      );
      handle.dispose();
    });
  });
}
