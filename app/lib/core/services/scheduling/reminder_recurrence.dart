// 주간 반복 규칙의 순수 값 모델 — (repeatType, repeatDaysMask) DB 쌍의 타입드 뷰.
//
// 파생 앱 voice-alarm의 RepeatSchedule(BL-10)을 도메인 비결합 형태로 이식.
// 여러 파생 앱(voice-alarm 알람, hanja/kanken 학습 요일, voca 데일리)이 재발명한
// "어떤 요일에 울리나"를 한 곳으로. 순수(no Drift/service/plugin) — DB TEXT 쌍과의
// 인코드/디코드만 담당하고, 시각·타임존은 next_occurrence.dart가 결합한다.
import 'package:collection/collection.dart';

/// DB에 저장되는 enum 이름(member name == 저장 문자열). 컬럼은 TEXT로 두고 이 enum은
/// 인메모리 타입드 뷰.
enum RecurrenceType { once, daily, weekdays, weekends, weekly, custom }

/// 저장 전 검증 실패 사유(null이면 유효).
enum RecurrenceError {
  unknownType,
  unexpectedMask,
  missingMask,
  malformedMask,
  emptyMask,
}

const List<int> _isoWeekdays = [1, 2, 3, 4, 5, 6, 7];

bool _isWellFormedMask(String mask) =>
    mask.length == 7 && mask.split('').every((c) => c == '0' || c == '1');

/// `(repeatType, repeatDaysMask)` 쌍의 불변 타입드 형태.
///
/// 정규형: `daysMask`는 프리셋(once/daily/weekdays/weekends)에서 null, weekly/custom
/// 에서만 검증된 7자 월-우선(ISO 월=1..일=7) 마스크.
class ReminderRecurrence {
  const ReminderRecurrence._({required this.type, this.daysMask});

  final RecurrenceType type;
  final String? daysMask;

  // ── 명명 생성자 (쓰기 방향) ────────────────────────────────────────────
  factory ReminderRecurrence.once() =>
      const ReminderRecurrence._(type: RecurrenceType.once);
  factory ReminderRecurrence.daily() =>
      const ReminderRecurrence._(type: RecurrenceType.daily);
  factory ReminderRecurrence.weekdays() =>
      const ReminderRecurrence._(type: RecurrenceType.weekdays);
  factory ReminderRecurrence.weekends() =>
      const ReminderRecurrence._(type: RecurrenceType.weekends);
  factory ReminderRecurrence.custom(Set<int> days) => ReminderRecurrence._(
      type: RecurrenceType.custom, daysMask: maskFromDays(days));
  factory ReminderRecurrence.weekly(Set<int> days) => ReminderRecurrence._(
      type: RecurrenceType.weekly, daysMask: maskFromDays(days));

  /// DB → 객체. Total, 절대 throw 안 함 — 손상 입력은 안전 폴백.
  factory ReminderRecurrence.decode(String repeatType, String? repeatDaysMask) {
    final type =
        RecurrenceType.values.firstWhereOrNull((e) => e.name == repeatType);
    if (type == null) {
      // 알 수 없는/오타 타입 → 안전한 once 폴백.
      return const ReminderRecurrence._(type: RecurrenceType.once);
    }
    switch (type) {
      case RecurrenceType.once:
      case RecurrenceType.daily:
      case RecurrenceType.weekdays:
      case RecurrenceType.weekends:
        // 프리셋은 항상 mask null로 정규화 — 딸린 stray 마스크는 비정합, 버림.
        return ReminderRecurrence._(type: type);
      case RecurrenceType.custom:
      case RecurrenceType.weekly:
        final normalized =
            (repeatDaysMask != null && _isWellFormedMask(repeatDaysMask))
                ? repeatDaysMask
                : null;
        return ReminderRecurrence._(type: type, daysMask: normalized);
    }
  }

  // ── 객체 → DB 쌍 ──────────────────────────────────────────────────────
  String get repeatType => type.name;
  String? get repeatDaysMask => daysMask;

  /// 시각 제약이 없는 1회성(요일 무관, 다음 hh:mm에 한 번).
  bool get isOnce => type == RecurrenceType.once;

  /// 어떤 요일에 울리나 (ISO 월=1..일=7). 수정 불가.
  Set<int> get activeDays {
    switch (type) {
      case RecurrenceType.once:
        return const <int>{};
      case RecurrenceType.daily:
        return const {1, 2, 3, 4, 5, 6, 7};
      case RecurrenceType.weekdays:
        return const {1, 2, 3, 4, 5};
      case RecurrenceType.weekends:
        return const {6, 7};
      case RecurrenceType.custom:
      case RecurrenceType.weekly:
        final mask = daysMask;
        if (mask == null || !_isWellFormedMask(mask)) return const <int>{};
        return Set.unmodifiable(<int>{
          for (final d in _isoWeekdays)
            if (mask[d - 1] == '1') d,
        });
    }
  }

  /// RAW 쌍의 저장 전 검증(null이면 유효). 고정 순서:
  /// unknownType → (프리셋 ⇒ unexpectedMask) →
  /// (custom/weekly ⇒ missingMask → malformedMask → emptyMask).
  static RecurrenceError? validatePair(String repeatType, String? mask) {
    final type =
        RecurrenceType.values.firstWhereOrNull((e) => e.name == repeatType);
    if (type == null) return RecurrenceError.unknownType;
    switch (type) {
      case RecurrenceType.once:
      case RecurrenceType.daily:
      case RecurrenceType.weekdays:
      case RecurrenceType.weekends:
        if (mask != null) return RecurrenceError.unexpectedMask;
        return null;
      case RecurrenceType.custom:
      case RecurrenceType.weekly:
        if (mask == null) return RecurrenceError.missingMask;
        if (!_isWellFormedMask(mask)) return RecurrenceError.malformedMask;
        if (!mask.contains('1')) return RecurrenceError.emptyMask;
        return null;
    }
  }

  /// `days`는 `{1..7}`의 비어있지 않은 부분집합이어야 함 — 아니면 [ArgumentError]
  /// (호출자 버그, 사용자 데이터 아님).
  static String maskFromDays(Set<int> days) {
    if (days.isEmpty) {
      throw ArgumentError.value(days, 'days', 'must not be empty');
    }
    for (final d in days) {
      if (d < 1 || d > 7) {
        throw ArgumentError.value(days, 'days', 'day must be within 1..7');
      }
    }
    return _isoWeekdays.map((d) => days.contains(d) ? '1' : '0').join();
  }

  /// 신선한 요일 선택을 가장 친근한 프리셋으로 정규화(decode와 반대 정책).
  static ReminderRecurrence fromDays(Set<int> days) {
    final mask = maskFromDays(days);
    switch (mask) {
      case '1111111':
        return ReminderRecurrence.daily();
      case '1111100':
        return ReminderRecurrence.weekdays();
      case '0000011':
        return ReminderRecurrence.weekends();
      default:
        return ReminderRecurrence._(
            type: RecurrenceType.custom, daysMask: mask);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderRecurrence &&
      other.type == type &&
      other.daysMask == daysMask;

  @override
  int get hashCode => Object.hash(type, daysMask);

  @override
  String toString() =>
      'ReminderRecurrence(${type.name}${daysMask == null ? '' : ', $daysMask'})';
}
