// Diff 기반 리마인더 리스케줄 (Phase 2 — 얇은 불순 오케스트레이션).
//
// 파생 앱 voice-alarm(syncSchedules)·quran(PrayerScheduleCoordinator)이 재발명한
// "원하는 발화 계획 → 현재 등록분과 차분 → 취소/추가"를 이식. 순수 diff
// (computeReminderDiff)와, 알림 플러그인을 감춘 ReminderSink 뒤의 얇은 서비스로
// 나눠 tz/플러그인 없이 검증 가능하게 한다.
//
// 알림 플러그인 호출·부트/타임존-변경 트리거 배선은 앱(또는 후속)이 소유한다 —
// 이 파일은 "무엇을 취소/추가할지"만 결정하고, ReminderSink가 "어떻게"를 맡는다.
import 'package:timezone/timezone.dart' as tz;
import 'package:utils/utils.dart';

import 'next_occurrence.dart';
import 'occurrence_planner.dart';

/// 프로덕션용 tz 기반 [OccurrenceGenerator] — [OccurrencePlanner]에 주입.
/// `from`은 tz.TZDateTime여야 한다(서비스가 tz now를 넘긴다). 평범한 DateTime을
/// 넘기는 오배선을 혼란스러운 캐스트 크래시 대신 명확한 assert로 잡는다.
List<DateTime> tzReminderGenerator(
  ReminderRule rule,
  DateTime from,
  int count,
) {
  assert(from is tz.TZDateTime,
      'tzReminderGenerator requires a tz.TZDateTime `from` (DST-correct calc). '
      'Wire via ReschedulerService.tz(now: () => tz.TZDateTime.now(location)).');
  return generateOccurrences(
    recurrence: rule.recurrence,
    hour: rule.hour,
    minute: rule.minute,
    from: from as tz.TZDateTime,
    count: count,
  );
}

/// 알림 플러그인 추상화 — 리스케줄러가 "어떻게 등록/취소하나"를 모르게 한다.
/// 앱이 notifications 패키지 위에 구현한다. 키는 [ScheduledOccurrence.occurrenceId].
abstract class ReminderSink {
  /// 현재 등록된 발화들의 occurrenceId 집합.
  Future<Set<String>> scheduledIds();

  /// 한 발화를 등록. 이미 있으면 no-op이어도 무방(diff가 중복을 거른다).
  Future<void> schedule(ScheduledOccurrence occurrence);

  /// occurrenceId로 한 발화를 취소.
  Future<void> cancel(String occurrenceId);
}

/// 순수 차분 결과.
class ReminderDiff {
  const ReminderDiff({required this.toCancel, required this.toSchedule});

  /// 더 이상 원하지 않아 취소할 현재 발화 id.
  final Set<String> toCancel;

  /// 아직 등록 안 된 새로 추가할 발화.
  final List<ScheduledOccurrence> toSchedule;
}

/// PURE. 원하는 발화 [desired]와 현재 등록된 [currentIds]로 취소/추가 집합을 계산.
/// 이미 있고 여전히 원하는 발화는 손대지 않는다(멱등 — 재sync는 no-op).
ReminderDiff computeReminderDiff(
  List<ScheduledOccurrence> desired,
  Set<String> currentIds,
) {
  final desiredIds = {for (final o in desired) o.occurrenceId};
  return ReminderDiff(
    toCancel: currentIds.difference(desiredIds),
    toSchedule: [
      for (final o in desired)
        if (!currentIds.contains(o.occurrenceId)) o,
    ],
  );
}

/// 규칙 집합을 플러그인의 실제 예약과 동기화한다. 계획(플래너) → 차분 → 적용.
///
/// [now]는 tz.TZDateTime를 반환해야 한다(플래너/생성기가 DST 정확 계산에 사용).
/// [planner]를 직접 주입 — 프로덕션은 [ReschedulerService.tz]로 tz 생성기를 배선하고,
/// 테스트는 합성 생성기로 tz 없이 검증한다.
class ReschedulerService {
  ReschedulerService({
    required this.sink,
    required this.now,
    required this.planner,
  });

  /// tz 생성기를 배선한 프로덕션 팩토리.
  factory ReschedulerService.tz({
    required ReminderSink sink,
    required tz.TZDateTime Function() now,
    ReschedulePolicy policy = const ReschedulePolicy(),
  }) =>
      ReschedulerService(
        sink: sink,
        now: now,
        planner: OccurrencePlanner(generator: tzReminderGenerator, policy: policy),
      );

  final ReminderSink sink;

  /// 현재 시각 리더. 프로덕션은 tz.TZDateTime를 반환해야 한다([tzReminderGenerator]가
  /// DST 정확 계산에 캐스팅) — `tz.TZDateTime Function()`은 반환형 공변으로 여기에
  /// 대입 가능. 합성 생성기 테스트는 평범한 DateTime을 넘긴다.
  final DateTime Function() now;
  final OccurrencePlanner planner;

  /// [rules]를 계획해 현재 예약과 동기화한다. 적용한 차분을 반환.
  ///
  /// 부트/타임존-변경/포그라운드 진입 어디서 불러도 안전(멱등) — 전량 재계산이
  /// 곧 리스케줄이다. 취소를 먼저(예산 회수) 적용한 뒤 추가한다.
  Future<ReminderDiff> sync(List<ReminderRule> rules) async {
    final desired = planner.plan(rules, now());
    final current = await sink.scheduledIds();
    final diff = computeReminderDiff(desired, current);
    // 개별 발화 실패(권한 취소·플러그인 예외·iOS 64-cap 경합)가 나머지를 굶기지
    // 않도록 op별로 격리해 로그하고 계속한다. 다음 sync가 멱등하게 자가 치유한다.
    for (final id in diff.toCancel) {
      try {
        await sink.cancel(id);
      } catch (e, s) {
        logger.w('ReschedulerService.sync: cancel($id) failed — continuing',
            error: e, stackTrace: s);
      }
    }
    for (final o in diff.toSchedule) {
      try {
        await sink.schedule(o);
      } catch (e, s) {
        logger.w(
            'ReschedulerService.sync: schedule(${o.occurrenceId}) failed — continuing',
            error: e, stackTrace: s);
      }
    }
    return diff;
  }
}
