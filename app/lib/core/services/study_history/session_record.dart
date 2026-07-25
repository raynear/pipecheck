/// 학습/활동 세션 한 건의 기록 (WS-B 리텐션 엔진).
///
/// 스트릭·이번달 일수·이번달 횟수는 전부 이 레코드들에서 [StudyHistoryService]가
/// 파생한다. 카운터를 따로 저장하지 않는다 — 기록 훅을 하나 빠뜨리면 카운터가
/// 거짓말을 하게 되고(파생 앱에서 실제로 겪은 버그), 이벤트 소싱은 그 부류를 없앤다.
///
/// [weight]는 **앱이 결정**한다: 0.0=집계 제외(너무 짧음/스킵), 0.5=부분 완료,
/// 1.0=완주. 서비스는 weight만 보고 파생하므로 학습앱뿐 아니라 타이머·습관앱 등
/// 어떤 세션 기반 앱에도 쓸 수 있다. 항목 수 기반(플래시카드/퀴즈) 앱은
/// [completionWeight] 헬퍼로 검증된 규칙을 그대로 얻는다.
class SessionRecord {
  /// 세션 종료 시각 (기기 로컬).
  final DateTime t;

  /// 집계 무게 0.0~1.0. [completionWeight] 또는 앱 정책으로 산출.
  final double weight;

  /// 자유 형식 분류(예: 'quiz', 'timer', 'workout'). 기본 ''.
  final String kind;

  /// 선택 분석 메타: 처리한 항목 수.
  final int? count;

  /// 선택 분석 메타: 성공/정답 항목 수.
  final int? success;

  /// 선택 분석 메타: 소요 초.
  final int? seconds;

  const SessionRecord({
    required this.t,
    required this.weight,
    this.kind = '',
    this.count,
    this.success,
    this.seconds,
  });

  Map<String, dynamic> toJson() => {
        't': t.toIso8601String(),
        'weight': weight,
        'kind': kind,
        'count': count,
        'success': success,
        'seconds': seconds,
      };

  /// 알 수 없는 키는 무시하고, 빠진 키는 기본값으로 연다. 저장 포맷이 나중에
  /// 늘어나도 옛 기록이 그대로 열려야 한다. 저장된 [weight]는 0..1로 클램프한다.
  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
        t: DateTime.parse(json['t'] as String),
        weight: ((json['weight'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0),
        kind: json['kind'] as String? ?? '',
        count: json['count'] as int?,
        success: json['success'] as int?,
        seconds: json['seconds'] as int?,
      );
}

/// 항목 수 기반 세션 무게(학습앱 규칙, 파생 앱 kanken·hanja에서 검증).
///
/// [count] < [minItems]이면 0.0(짧은 세션이 스트릭을 부풀리지 않게), 그 외에는
/// 완주 1.0 / 미완주 0.5. 무게를 저장 시점에 정하지 않고 이 함수로 뽑아 두면
/// 규칙이 바뀌어도 앱이 일관되게 적용할 수 있다.
double completionWeight({
  required int count,
  required bool complete,
  int minItems = 5,
}) {
  if (count < minItems) return 0.0;
  return complete ? 1.0 : 0.5;
}
