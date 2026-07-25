/// 테스트 중성화 탐지 — skip / markTestSkipped / 트리비얼 단언.
///
/// preflight feature 게이트가 "테스트가 통과한다"를 가짜로 만드는 흔한 수법을
/// 차단하려고 쓴다: `skip:` 파라미터, `markTestSkipped`, `expect(true, isTrue)`.
library;

enum TestQualityKind { skip, markSkipped, trivial }

class TestQualityIssue {
  const TestQualityIssue({required this.line, required this.kind});

  final int line;
  final TestQualityKind kind;

  String get label => switch (kind) {
        TestQualityKind.skip => 'skip: 파라미터',
        TestQualityKind.markSkipped => 'markTestSkipped',
        TestQualityKind.trivial => '트리비얼 단언',
      };
}

class TestQualityScan {
  static final RegExp _skip = RegExp(r'\bskip\s*:');
  static final RegExp _markSkipped = RegExp(r'\bmarkTestSkipped\b');
  static final RegExp _trivial =
      RegExp(r'expect\(\s*true\s*,\s*(is)?[Tt]rue');

  /// 한 파일 내용에서 중성화 패턴을 1-based 줄번호와 함께 찾는다.
  static List<TestQualityIssue> findIssues(String content) {
    final issues = <TestQualityIssue>[];
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      // 의도적 opt-out: `// preflight:allow-skip` 마커가 있으면 허용
      // (예: skip: !Platform.isIOS 같은 정당한 플랫폼 게이트).
      if (line.contains('preflight:allow-skip')) continue;
      // 순수 주석 줄은 건너뛴다(문서가 패턴을 언급해도 오탐 안 함).
      // 실코드의 트레일링 주석은 코드 부분이 그대로 매칭되므로 영향 없음.
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//') ||
          trimmed.startsWith('*') ||
          trimmed.startsWith('/*')) {
        continue;
      }
      void add(TestQualityKind kind) =>
          issues.add(TestQualityIssue(line: i + 1, kind: kind));
      if (_trivial.hasMatch(line)) {
        add(TestQualityKind.trivial);
      } else if (_markSkipped.hasMatch(line)) {
        add(TestQualityKind.markSkipped);
      } else if (_skip.hasMatch(line)) {
        add(TestQualityKind.skip);
      }
    }
    return issues;
  }
}
