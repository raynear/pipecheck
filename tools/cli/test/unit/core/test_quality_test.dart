import 'package:boilerplate_cli/core/test_quality.dart';
import 'package:test/test.dart';

void main() {
  group('TestQualityScan.findIssues', () {
    test('skip: 파라미터를 잡는다', () {
      final issues = TestQualityScan.findIssues(
        "test('x', () {}, skip: 'not ready');",
      );
      expect(issues, hasLength(1));
      expect(issues.first.line, 1);
      expect(issues.first.kind, TestQualityKind.skip);
    });

    test('markTestSkipped를 잡는다', () {
      final issues = TestQualityScan.findIssues(
        "void main() {\n  markTestSkipped('미구현');\n}",
      );
      expect(issues, hasLength(1));
      expect(issues.first.line, 2);
      expect(issues.first.kind, TestQualityKind.markSkipped);
    });

    test('트리비얼 expect(true, isTrue)를 잡는다', () {
      final issues = TestQualityScan.findIssues(
        'expect(true, isTrue);\nexpect(true, true);',
      );
      expect(issues, hasLength(2));
      expect(issues.every((i) => i.kind == TestQualityKind.trivial), isTrue);
    });

    test('주석 줄의 패턴은 오탐하지 않는다', () {
      final issues = TestQualityScan.findIssues(
        '/// 트리비얼 expect(true, isTrue)는 쓰지 마세요\n'
        '// skip: 이건 설명 주석\n'
        ' * markTestSkipped 언급',
      );
      expect(issues, isEmpty);
    });

    test('실코드의 트레일링 주석 뒤 패턴은 여전히 잡는다', () {
      final issues = TestQualityScan.findIssues('expect(true, isTrue); // x');
      expect(issues, hasLength(1));
    });

    test('preflight:allow-skip 마커가 있으면 정당한 skip을 허용한다', () {
      final issues = TestQualityScan.findIssues(
        'testWidgets(name, () {}, skip: !isIOS); // preflight:allow-skip',
      );
      expect(issues, isEmpty);
    });

    test('정상 테스트는 지적이 없다', () {
      final issues = TestQualityScan.findIssues(
        "expect(model.id, equals('x'));\nexpect(state.isLoading, isFalse);",
      );
      expect(issues, isEmpty);
    });

    test('skipped/skipping 같은 단어는 오탐하지 않는다', () {
      final issues = TestQualityScan.findIssues(
        '// this test is not skipping anything\nfinal skipped = 0;',
      );
      expect(issues, isEmpty);
    });
  });
}
