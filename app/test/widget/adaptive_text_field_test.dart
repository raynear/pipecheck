// AdaptiveTextField / AdaptiveSearchField가 **밖에서 받은** FocusNode·controller의
// 리스너를 위젯 수명 안에서만 쥐는지.
//
// 배경: 위젯이 외부 객체에 리스너를 달고 dispose에서 떼지 않으면, 위젯이 사라진 뒤에도
// 외부 객체가 죽은 State를 호출한다(`setState() called after dispose`). 부모가 노드를
// 교체(`didUpdateWidget`)해도 옛 노드에 리스너가 남고 새 노드는 구독되지 않았다.

import 'package:pipecheck/core/widgets/inputs/adaptive_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// hasListeners는 @protected라 하위 클래스 안에서만 읽을 수 있다.
class _SpyNode extends FocusNode {
  bool get listening => hasListeners;
}

class _SpyController extends TextEditingController {
  _SpyController({super.text});

  bool get listening => hasListeners;
}

Future<void> _pump(WidgetTester tester, Widget? field) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(home: Scaffold(body: field ?? const SizedBox())),
  ),
);

void main() {
  group('AdaptiveTextField', () {
    testWidgets('외부 FocusNode: 위젯이 사라지면 리스너가 모두 떼어진다', (tester) async {
      final node = _SpyNode();
      addTearDown(node.dispose);
      expect(node.listening, isFalse);

      await _pump(tester, AdaptiveTextField(focusNode: node));
      expect(node.listening, isTrue);

      await _pump(tester, null);
      expect(
        node.listening,
        isFalse,
        reason: '죽은 State의 _onFocusChange가 노드에 남았다',
      );
    });

    testWidgets('외부 FocusNode를 다른 노드로 바꾸면 리스너가 옮겨 간다', (tester) async {
      final a = _SpyNode();
      final b = _SpyNode();
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await _pump(tester, AdaptiveTextField(label: 'L', focusNode: a));
      await _pump(tester, AdaptiveTextField(label: 'L', focusNode: b));

      expect(a.listening, isFalse, reason: '옛 노드에 리스너가 남았다');
      expect(b.listening, isTrue);
      Color? labelColor() => tester.widget<Text>(find.text('L')).style?.color;
      final before = labelColor();

      // 새 노드의 포커스가 스타일 상태에 닿는지(구독되어 있는지)까지 본다.
      b.requestFocus();
      await tester.pump();
      await tester.pump(); // 포커스 변경 통지 → setState → 재빌드
      expect(b.hasFocus, isTrue);
      expect(
        labelColor(),
        isNot(before),
        reason: '새 노드의 포커스가 라벨 강조에 닿지 않았다 — 구독되지 않았다',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('내부 노드 → 외부 노드로 바꿔도 내부 노드를 정리하고 새 노드를 구독한다', (tester) async {
      final external = _SpyNode();
      addTearDown(external.dispose);

      await _pump(tester, const AdaptiveTextField());
      await _pump(tester, AdaptiveTextField(focusNode: external));
      expect(external.listening, isTrue);

      await _pump(tester, null);
      expect(external.listening, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('외부 controller를 바꿔도 새 controller 글자를 보여 준다', (tester) async {
      final a = _SpyController(text: 'first');
      final b = _SpyController(text: 'second');
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await _pump(tester, AdaptiveTextField(controller: a));
      expect(find.text('first'), findsOneWidget);
      await _pump(tester, AdaptiveTextField(controller: b));
      expect(find.text('second'), findsOneWidget);
    });
  });

  group('AdaptiveSearchField', () {
    testWidgets('외부 controller: 위젯이 사라지면 리스너가 떼어진다', (tester) async {
      final controller = _SpyController();
      addTearDown(controller.dispose);

      await _pump(tester, AdaptiveSearchField(controller: controller));
      expect(controller.listening, isTrue);

      await _pump(tester, null);
      expect(
        controller.listening,
        isFalse,
        reason: '죽은 State의 _onTextChanged가 controller에 남았다',
      );

      controller.text = 'typed after dispose'; // 리스너가 남았다면 여기서 죽은 State를 부른다
      expect(tester.takeException(), isNull);
    });

    testWidgets('controller를 바꾸면 리스너가 옮겨 가고 지우기 버튼 상태가 새 글자를 따른다', (
      tester,
    ) async {
      final a = _SpyController(text: 'abc');
      final b = _SpyController();
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await _pump(tester, AdaptiveSearchField(controller: a));
      expect(find.byIcon(Icons.clear), findsOneWidget);

      await _pump(tester, AdaptiveSearchField(controller: b));
      expect(
        find.byIcon(Icons.clear),
        findsNothing,
        reason: '새 controller는 비어 있다',
      );

      b.text = 'x';
      await tester.pump();
      expect(
        find.byIcon(Icons.clear),
        findsOneWidget,
        reason: '새 controller를 구독하지 않았다',
      );
      expect(a.listening, isFalse);
    });
  });
}
