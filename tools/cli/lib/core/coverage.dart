/// lcov.info 파서 — 전역/변경-기능 커버리지 산출.
///
/// preflight 게이트가 (1) 생성 코드(.g/.freezed/.drift/generated/table_generator)를
/// 분모에서 제외하고 (2) 변경된 기능(lib/features/<name>/)별로 손작성 커버리지를
/// 측정하기 위해 쓴다. qa-gate.yml의 awk 필터와 동일 규칙.
library;

/// lcov의 한 SF 섹션 (파일 단위 LF/LH).
class LcovSection {
  const LcovSection({required this.path, required this.lf, required this.lh});

  final String path;
  final int lf;
  final int lh;
}

class LcovReport {
  LcovReport(this.sections);

  factory LcovReport.parse(String lcov) {
    final sections = <LcovSection>[];
    String? path;
    int lf = 0;
    int lh = 0;
    for (final raw in lcov.split('\n')) {
      final line = raw.trim();
      if (line.startsWith('SF:')) {
        path = line.substring(3);
        lf = 0;
        lh = 0;
      } else if (line.startsWith('LF:')) {
        lf = int.tryParse(line.substring(3)) ?? 0;
      } else if (line.startsWith('LH:')) {
        lh = int.tryParse(line.substring(3)) ?? 0;
      } else if (line == 'end_of_record' && path != null) {
        sections.add(LcovSection(path: path, lf: lf, lh: lh));
        path = null;
      }
    }
    // end_of_record 없이 끝나는 마지막 레코드도 집계 (awk END 블록과 동일).
    if (path != null) {
      sections.add(LcovSection(path: path, lf: lf, lh: lh));
    }
    return LcovReport(sections);
  }

  final List<LcovSection> sections;

  static final RegExp _generated = RegExp(
    r'\.g\.dart|\.freezed\.dart|\.drift\.dart|/generated/|table_generator/',
  );

  /// 생성 코드 경로 판별 — qa-gate.yml과 동일 패턴.
  static bool isGenerated(String path) => _generated.hasMatch(path);

  /// 전역 커버리지(%) — 생성 코드 분모 제외. 손작성 라인이 없으면 null.
  double? globalCoverage() {
    return _pct(sections.where((s) => !isGenerated(s.path)));
  }

  /// 변경 기능(lib/features/<feature>/) 손작성 커버리지(%). 생성 코드 제외.
  /// 해당 기능에 커버 가능한 손작성 라인이 없으면 null.
  double? featureCoverage(String feature) {
    final needle = 'lib/features/$feature/';
    return _pct(sections.where(
        (s) => s.path.contains(needle) && !isGenerated(s.path)));
  }

  double? _pct(Iterable<LcovSection> selected) {
    var lf = 0;
    var lh = 0;
    for (final s in selected) {
      lf += s.lf;
      lh += s.lh;
    }
    if (lf == 0) return null;
    return lh / lf * 100;
  }
}
