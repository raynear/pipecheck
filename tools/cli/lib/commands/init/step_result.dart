/// init 스텝의 결과와 종료 요약.
///
/// soft-skip(크리덴셜/서버 미비로 조용히 넘어가는 스텝)이 마지막 "완료!"
/// 메시지에 은폐되던 사고 경로를 막는다 — 각 스텝이 done/skipped/failed를
/// 돌려주고, [InitSummary]가 미완 스텝만 모아 종료 시 출력한다.
enum StepStatus { done, skipped, failed }

class StepResult {
  const StepResult(this.status, [this.reason]);

  const StepResult.done() : this(StepStatus.done);

  factory StepResult.skipped(String reason) =>
      StepResult(StepStatus.skipped, reason);

  factory StepResult.failed(String reason) =>
      StepResult(StepStatus.failed, reason);

  final StepStatus status;
  final String? reason;

  bool get ok => status == StepStatus.done;
}

/// (스텝 이름, 결과) 한 줄.
typedef SummaryEntry = ({String step, StepResult result});

/// init 스텝 결과 수집기 — 미완 스텝만 요약해 종료 시 출력.
class InitSummary {
  final List<SummaryEntry> _entries = [];

  void add(String step, StepResult result) =>
      _entries.add((step: step, result: result));

  /// done이 아닌(=skipped/failed) 스텝만.
  List<SummaryEntry> get incomplete =>
      _entries.where((e) => !e.result.ok).toList();

  bool get allDone => incomplete.isEmpty;

  /// 미완 스텝 요약 블록. 전부 done이면 빈 문자열.
  String render() {
    final rows = incomplete;
    if (rows.isEmpty) return '';

    final buf = StringBuffer();
    buf.writeln('⚠️  ${rows.length}개 스텝이 완료되지 않았습니다:');
    for (final (:step, :result) in rows) {
      final mark = result.status == StepStatus.failed ? '✗' : '⊘';
      final reason = result.reason ?? '';
      buf.writeln('  $mark $step${reason.isEmpty ? '' : ' — $reason'}');
    }
    return buf.toString();
  }
}

/// init 종료 출력 렌더 — 정상 완료 / 일부 미완(soft-skip) / hard-fail 중단을
/// 한 곳에서 포맷한다. [hardFailStep]이 주어지면 필수 스텝 실패로 초기화가
/// 중단됐음을 표시하고, 성공용 "다음 단계" 안내는 찍지 않는다. hard-fail 경로도
/// 그때까지의 요약(성공/미완 + 실패 스텝)을 반드시 보여준다.
String renderInitOutcome({
  required InitSummary summary,
  required String appName,
  required String packageName,
  required String profile,
  String? hardFailStep,
}) {
  final hardFailed = hardFailStep != null;
  final allDone = summary.allDone;
  final buf = StringBuffer();
  buf.writeln('');
  buf.writeln('========================================');
  buf.writeln('');
  if (hardFailed) {
    buf.writeln('  프로젝트 초기화 중단 — 필수 스텝 실패: $hardFailStep');
  } else {
    buf.writeln(
        allDone ? '  프로젝트 초기화 완료!' : '  프로젝트 초기화 완료 (일부 스텝 미완)');
  }
  buf.writeln('');
  buf.writeln('========================================');
  buf.writeln('');
  buf.writeln('  앱: $appName ($packageName)');
  buf.writeln('  Profile: $profile');
  buf.writeln('');
  if (!allDone) {
    // 미완/실패 스텝을 항상 명시 — 성공 오인·soft-skip 은폐 방지.
    buf.write(summary.render());
    if (hardFailed) {
      buf.writeln('  필수 스텝 실패로 초기화를 중단했습니다 — 위 원인을 해결한 뒤');
      buf.writeln('  ./scripts/init 을 다시 실행하세요 (멱등).');
    } else {
      buf.writeln('  위 스텝은 크리덴셜/서버 미비로 건너뛰었습니다 — 필요 시 보완 후');
      buf.writeln('  ./scripts/init 을 다시 실행하세요 (멱등).');
    }
    buf.writeln('');
  }
  if (!hardFailed) {
    buf.writeln('  다음 단계:');
    buf.writeln('  1. app/lib/features/home/views/home_view.dart 편집');
    buf.writeln('  2. 앱 코어 로직 개발');
    buf.writeln('  3. ./scripts/preflight  (배포 전 검증)');
    buf.writeln('  4. ./scripts/deploy --target beta  (베타 배포)');
  }
  return buf.toString();
}
