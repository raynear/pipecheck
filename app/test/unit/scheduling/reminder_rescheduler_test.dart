// ReminderRescheduler — 원하는 발화 집합 ↔ 현재 등록된 발화의 diff 리스케줄 테스트.
//
// 파생 앱 voice-alarm(syncSchedules)·quran(PrayerScheduleCoordinator)이 재발명한
// "계획 → 차분 → 취소/추가" 동기화. 순수 diff(computeReminderDiff)와, ReminderSink
// (알림 플러그인 추상화) 뒤의 얇은 서비스로 나눠 tz/플러그인 없이 검증한다.

import 'package:boilerplate/core/services/scheduling/occurrence_planner.dart';
import 'package:boilerplate/core/services/scheduling/reminder_recurrence.dart';
import 'package:boilerplate/core/services/scheduling/reminder_rescheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class _FakeSink implements ReminderSink {
  final Set<String> _ids = {};
  final List<String> scheduled = [];
  final List<String> cancelled = [];

  /// 취소·추가를 호출 순서대로 기록('cancel:id' / 'schedule:id') — 순서 불변식 검증용.
  final List<String> events = [];

  _FakeSink([Iterable<String> initial = const []]) {
    _ids.addAll(initial);
  }

  @override
  Future<Set<String>> scheduledIds() async => {..._ids};

  @override
  Future<void> schedule(ScheduledOccurrence o) async {
    _ids.add(o.occurrenceId);
    scheduled.add(o.occurrenceId);
    events.add('schedule:${o.occurrenceId}');
  }

  @override
  Future<void> cancel(String occurrenceId) async {
    _ids.remove(occurrenceId);
    cancelled.add(occurrenceId);
    events.add('cancel:$occurrenceId');
  }
}

void main() {
  final from = DateTime(2026, 1, 1);
  DateTime day(int d) => DateTime(2026, 1, d, 9);

  ScheduledOccurrence occ(String ruleId, DateTime at) => ScheduledOccurrence(
        rule: ReminderRule(
            id: ruleId, recurrence: ReminderRecurrence.daily(), hour: 9, minute: 0),
        fireAt: at,
      );

  group('computeReminderDiff — 순수 차분', () {
    test('현재 없음 → 전부 추가, 취소 없음', () {
      final desired = [occ('a', day(1)), occ('a', day(2))];
      final d = computeReminderDiff(desired, const {});
      expect(d.toCancel, isEmpty);
      expect(d.toSchedule.map((o) => o.occurrenceId),
          desired.map((o) => o.occurrenceId));
    });

    test('전부 동일 → 무변화 (멱등)', () {
      final desired = [occ('a', day(1)), occ('a', day(2))];
      final current = desired.map((o) => o.occurrenceId).toSet();
      final d = computeReminderDiff(desired, current);
      expect(d.toCancel, isEmpty);
      expect(d.toSchedule, isEmpty);
    });

    test('원하지 않는 현재 발화 → 취소', () {
      final desired = [occ('a', day(2))];
      final current = {occ('a', day(1)).occurrenceId, occ('a', day(2)).occurrenceId};
      final d = computeReminderDiff(desired, current);
      expect(d.toCancel, {occ('a', day(1)).occurrenceId}); // day1은 stale
      expect(d.toSchedule, isEmpty); // day2는 이미 있음
    });

    test('혼합: stale 취소 + 신규 추가 + 기존 유지', () {
      final desired = [occ('a', day(2)), occ('b', day(3))];
      final current = {occ('a', day(1)).occurrenceId, occ('a', day(2)).occurrenceId};
      final d = computeReminderDiff(desired, current);
      expect(d.toCancel, {occ('a', day(1)).occurrenceId});
      expect(d.toSchedule.map((o) => o.occurrenceId),
          {occ('b', day(3)).occurrenceId}); // day2 유지, b 신규
    });
  });

  group('ReschedulerService.sync — 계획→차분→적용', () {
    OccurrenceGenerator fromMap(Map<String, List<DateTime>> m) =>
        (r, f, count) =>
            (m[r.id] ?? const []).where((x) => x.isAfter(f)).take(count).toList();

    ReminderRule rule(String id) => ReminderRule(
        id: id, recurrence: ReminderRecurrence.daily(), hour: 9, minute: 0);

    test('첫 sync: 빈 sink → 계획된 발화 등록', () async {
      final sink = _FakeSink();
      final svc = ReschedulerService(
        sink: sink,
        now: () => from,
        planner: OccurrencePlanner(
          generator: fromMap({
            'a': [day(1), day(2)]
          }),
          policy: const ReschedulePolicy(windowPerRule: 2),
        ),
      );
      final d = await svc.sync([rule('a')]);
      expect(sink.scheduled.length, 2);
      expect(sink.cancelled, isEmpty);
      expect(d.toSchedule.length, 2);
    });

    test('같은 규칙 재sync → 멱등 (추가·취소 없음)', () async {
      final sink = _FakeSink();
      final gen = fromMap({
        'a': [day(1), day(2)]
      });
      final svc = ReschedulerService(
        sink: sink,
        now: () => from,
        planner: OccurrencePlanner(
            generator: gen, policy: const ReschedulePolicy(windowPerRule: 2)),
      );
      await svc.sync([rule('a')]);
      sink.scheduled.clear();
      sink.cancelled.clear();
      await svc.sync([rule('a')]); // 두 번째
      expect(sink.scheduled, isEmpty);
      expect(sink.cancelled, isEmpty);
    });

    test('규칙 제거 → 그 발화가 취소됨', () async {
      final sink = _FakeSink();
      final svc = ReschedulerService(
        sink: sink,
        now: () => from,
        planner: OccurrencePlanner(
          generator: fromMap({
            'a': [day(1)],
            'b': [day(2)],
          }),
          policy: const ReschedulePolicy(windowPerRule: 1),
        ),
      );
      await svc.sync([rule('a'), rule('b')]);
      sink.scheduled.clear();
      // 이제 b를 뺀다 → b의 발화가 취소돼야.
      await svc.sync([rule('a')]);
      expect(sink.cancelled.length, 1);
      expect(sink.cancelled.single, contains('b'));
    });

    test('sync([]) → 전량 취소 (모든 리마인더 끄기)', () async {
      final sink = _FakeSink();
      final svc = ReschedulerService(
        sink: sink,
        now: () => from,
        planner: OccurrencePlanner(
          generator: fromMap({
            'a': [day(1), day(2)],
            'b': [day(3)],
          }),
          policy: const ReschedulePolicy(windowPerRule: 2),
        ),
      );
      await svc.sync([rule('a'), rule('b')]);
      final scheduledCount = sink.scheduled.length;
      expect(scheduledCount, 3);
      sink.cancelled.clear();
      // 빈 규칙 → 현재 등록된 전부 취소.
      final d = await svc.sync([]);
      expect(d.toSchedule, isEmpty);
      expect(sink.cancelled.length, scheduledCount);
      expect(await sink.scheduledIds(), isEmpty);
    });

    test('취소가 추가보다 먼저 (iOS 64-cap 예산 회수 순서 불변식)', () async {
      final sink = _FakeSink();
      final svc = ReschedulerService(
        sink: sink,
        now: () => from,
        planner: OccurrencePlanner(
          generator: fromMap({
            'a': [day(1), day(2), day(3)],
          }),
          policy: const ReschedulePolicy(windowPerRule: 3),
        ),
      );
      await svc.sync([rule('a')]); // day1,2,3 등록
      sink.events.clear();
      // now를 day2 직후로 → day1은 과거(취소), day4가 새로(추가). 취소·추가 혼재.
      final svc2 = ReschedulerService(
        sink: sink,
        now: () => DateTime(2026, 1, 2, 10),
        planner: OccurrencePlanner(
          generator: fromMap({
            'a': [day(2), day(3), day(4), day(5)],
          }),
          policy: const ReschedulePolicy(windowPerRule: 3),
        ),
      );
      await svc2.sync([rule('a')]);
      final firstSchedule = sink.events.indexWhere((e) => e.startsWith('schedule:'));
      final lastCancel = sink.events.lastIndexWhere((e) => e.startsWith('cancel:'));
      expect(sink.events.any((e) => e.startsWith('cancel:')), isTrue);
      expect(sink.events.any((e) => e.startsWith('schedule:')), isTrue);
      expect(lastCancel, lessThan(firstSchedule)); // 모든 취소가 모든 추가보다 앞
    });

    test('now 전진 시 슬라이딩: head만 드롭·tail만 추가 (프로덕션 멱등)', () async {
      final sink = _FakeSink();
      final gen = fromMap({
        'a': [day(1), day(2), day(3)],
      });
      final svc = ReschedulerService(
        sink: sink,
        now: () => from,
        planner:
            OccurrencePlanner(generator: gen, policy: const ReschedulePolicy(windowPerRule: 2)),
      );
      await svc.sync([rule('a')]); // day1, day2
      sink.scheduled.clear();
      sink.cancelled.clear();
      // now를 day1 직후로 전진 → 원함=day2,day3(창2). day1 과거→취소, day3 신규→추가.
      final svc2 = ReschedulerService(
        sink: sink,
        now: () => DateTime(2026, 1, 1, 10),
        planner:
            OccurrencePlanner(generator: gen, policy: const ReschedulePolicy(windowPerRule: 2)),
      );
      await svc2.sync([rule('a')]);
      expect(sink.cancelled.length, 1); // head(day1)만
      expect(sink.cancelled.single, contains('01T09')); // day1
      expect(sink.scheduled.length, 1); // tail(day3)만
      expect(sink.scheduled.single, contains('03T09')); // day3
    });
  });

  group('tzReminderGenerator — tz 브리지 (스모크)', () {
    setUpAll(tzdata.initializeTimeZones);

    test('tz from으로 발화 생성', () {
      final ny = tz.getLocation('America/New_York');
      final rule = ReminderRule(
          id: 'a', recurrence: ReminderRecurrence.daily(), hour: 9, minute: 0);
      final r = tzReminderGenerator(rule, tz.TZDateTime(ny, 2026, 1, 1, 8), 3);
      expect(r.length, 3);
      expect(r.every((d) => d.hour == 9), isTrue);
    });

    test('평범한 DateTime을 넘기면 assert (오배선 방어)', () {
      final rule = ReminderRule(
          id: 'a', recurrence: ReminderRecurrence.daily(), hour: 9, minute: 0);
      expect(() => tzReminderGenerator(rule, DateTime(2026, 1, 1, 8), 3),
          throwsA(isA<AssertionError>()));
    });
  });
}
