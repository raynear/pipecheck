// OccurrencePlanner — iOS 64-알림 상한 + 규칙별 다음-N 예산의 순수 창 플래너 테스트.
//
// 파생 앱 voice-alarm(AlarmOccurrencePlanner)·quran(buildAdhanSchedule)이 각자
// 재발명한 2-패스 공정 채움 알고리즘을 도메인 비결합으로 이식. 생성기를 주입해
// tz 없이 순수 검증(합성 발화 리스트).

import 'package:boilerplate/core/services/scheduling/occurrence_planner.dart';
import 'package:boilerplate/core/services/scheduling/reminder_recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final from = DateTime(2026, 1, 1, 0);

  ReminderRule rule(String id, ReminderRecurrence r) =>
      ReminderRule(id: id, recurrence: r, hour: 9, minute: 0);

  // 규칙id → 미리 정한 발화 리스트를 주는 합성 생성기(from 이후만, count까지).
  OccurrenceGenerator fromMap(Map<String, List<DateTime>> m) =>
      (r, f, count) =>
          (m[r.id] ?? const []).where((d) => d.isAfter(f)).take(count).toList();

  DateTime day(int d, [int h = 9]) => DateTime(2026, 1, d, h);

  test('빈 규칙 → 빈 결과', () {
    final p = OccurrencePlanner(generator: fromMap({}));
    expect(p.plan([], from), isEmpty);
  });

  test('발화 없는 규칙(생성기가 빈 리스트)은 드롭', () {
    final p = OccurrencePlanner(generator: fromMap({'a': []}));
    expect(p.plan([rule('a', ReminderRecurrence.daily())], from), isEmpty);
  });

  test('once 규칙은 최대 1회 (버그성 생성기가 여러 개 줘도 플래너가 상한)', () {
    // 생성기가 once에 3개를 줘도 pass2는 비반복을 라운드로빈하지 않음 → 1개.
    final p = OccurrencePlanner(
        generator: fromMap({
      'o': [day(1), day(2), day(3)]
    }));
    final r = p.plan([rule('o', ReminderRecurrence.once())], from);
    expect(r.length, 1);
    expect(r.single.fireAt, day(1));
  });

  test('반복 규칙은 windowPerRule까지 버퍼 채움', () {
    final p = OccurrencePlanner(
      generator: fromMap({
        'a': [for (var d = 1; d <= 10; d++) day(d)]
      }),
      policy: const ReschedulePolicy(windowPerRule: 3),
    );
    final r = p.plan([rule('a', ReminderRecurrence.daily())], from);
    expect(r.map((o) => o.fireAt), [day(1), day(2), day(3)]);
  });

  test('공정 라운드로빈: 두 반복 규칙이 다음 발화를 번갈아 채움', () {
    // a: 1,3,5 / b: 2,4,6 — globalCap=4면 pass1에서 a#0,b#0(=1,2),
    // pass2에서 a#1,b#1(=3,4)까지 → 오름차순 [1,2,3,4].
    final p = OccurrencePlanner(
      generator: fromMap({
        'a': [day(1), day(3), day(5)],
        'b': [day(2), day(4), day(6)],
      }),
      policy: const ReschedulePolicy(globalCap: 4, windowPerRule: 7),
    );
    final r = p.plan([
      rule('a', ReminderRecurrence.daily()),
      rule('b', ReminderRecurrence.daily()),
    ], from);
    expect(r.map((o) => o.fireAt), [day(1), day(2), day(3), day(4)]);
  });

  test('globalCap 초과: 가장 이른 cap개 규칙만 #0, 나머지 드롭 (P1/liveness)', () {
    final p = OccurrencePlanner(
      generator: fromMap({
        'a': [day(1)],
        'b': [day(2)],
        'c': [day(3)],
      }),
      policy: const ReschedulePolicy(globalCap: 2, windowPerRule: 7),
    );
    final r = p.plan([
      rule('c', ReminderRecurrence.daily()),
      rule('a', ReminderRecurrence.daily()),
      rule('b', ReminderRecurrence.daily()),
    ], from);
    // 가장 이른 2개(a=day1, b=day2)만.
    expect(r.map((o) => o.fireAt), [day(1), day(2)]);
    expect(r.length, lessThanOrEqualTo(2));
  });

  test('결정적 정렬: 같은 nextFireAt이면 id 오름차순으로 tie-break', () {
    final p = OccurrencePlanner(
      generator: fromMap({
        'z': [day(1)],
        'a': [day(1)],
      }),
      policy: const ReschedulePolicy(globalCap: 1, windowPerRule: 7),
    );
    final r = p.plan([
      rule('z', ReminderRecurrence.once()),
      rule('a', ReminderRecurrence.once()),
    ], from);
    // 동시각 → id 'a'가 이겨 cap 1을 차지.
    expect(r.single.rule.id, 'a');
  });

  test('출력 불변식: length<=cap, from 이후, 오름차순 fireAt', () {
    final p = OccurrencePlanner(
      generator: fromMap({
        'a': [for (var d = 1; d <= 10; d++) day(d)],
        'b': [for (var d = 1; d <= 10; d++) day(d, 10)],
      }),
      policy: const ReschedulePolicy(globalCap: 8, windowPerRule: 5),
    );
    final r = p.plan([
      rule('a', ReminderRecurrence.daily()),
      rule('b', ReminderRecurrence.daily()),
    ], from);
    expect(r.length, lessThanOrEqualTo(8));
    for (var i = 0; i < r.length; i++) {
      expect(r[i].fireAt.isAfter(from), isTrue);
      if (i > 0) {
        expect(r[i].fireAt.isBefore(r[i - 1].fireAt), isFalse);
      }
    }
    // 규칙별 windowPerRule 상한.
    final perRule = <String, int>{};
    for (final o in r) {
      perRule[o.rule.id] = (perRule[o.rule.id] ?? 0) + 1;
    }
    expect(perRule.values.every((c) => c <= 5), isTrue);
  });

  test('동시각 최종 정렬은 결정적: occurrenceId로 tie-break', () {
    // a·b 둘 다 day1·day2에 발화. 동시각이면 List.sort가 불안정하므로
    // occurrenceId(=ruleId@fireAt)로 tie-break해 [a@1,b@1,a@2,b@2] 고정.
    final p = OccurrencePlanner(
      generator: fromMap({
        'a': [day(1), day(2)],
        'b': [day(1), day(2)],
      }),
      policy: const ReschedulePolicy(globalCap: 4, windowPerRule: 2),
    );
    final r = p.plan([
      rule('b', ReminderRecurrence.daily()),
      rule('a', ReminderRecurrence.daily()),
    ], from);
    expect(r.map((o) => o.rule.id), ['a', 'b', 'a', 'b']);
    expect(r.map((o) => o.fireAt), [day(1), day(1), day(2), day(2)]);
  });

  test('라운드로빈: 발화 수 불균형 (한 규칙이 먼저 소진)', () {
    // a=[1,3,5,7,9], b=[2] — pass1: a#0=1,b#0=2. pass2: b는 1개뿐이라 즉시
    // 소진되고 a만 창(5)까지 채움. progressed/exhaust 경로를 실제로 밟는다.
    final p = OccurrencePlanner(
      generator: fromMap({
        'a': [day(1), day(3), day(5), day(7), day(9)],
        'b': [day(2)],
      }),
      policy: const ReschedulePolicy(globalCap: 10, windowPerRule: 5),
    );
    final r = p.plan([
      rule('a', ReminderRecurrence.daily()),
      rule('b', ReminderRecurrence.daily()),
    ], from);
    final perRule = <String, int>{};
    for (final o in r) {
      perRule[o.rule.id] = (perRule[o.rule.id] ?? 0) + 1;
    }
    expect(perRule['a'], 5);
    expect(perRule['b'], 1);
    expect(r.map((o) => o.fireAt),
        [day(1), day(2), day(3), day(5), day(7), day(9)]);
  });

  test('budget이 창보다 먼저 소진: P1/P2 상호작용', () {
    // 2 규칙 × 창3 = 최대 6이지만 globalCap=4 → 총 4개만(P1), 규칙별 ≤3(P2).
    final p = OccurrencePlanner(
      generator: fromMap({
        'a': [day(1), day(3), day(5)],
        'b': [day(2), day(4), day(6)],
      }),
      policy: const ReschedulePolicy(globalCap: 4, windowPerRule: 3),
    );
    final r = p.plan([
      rule('a', ReminderRecurrence.daily()),
      rule('b', ReminderRecurrence.daily()),
    ], from);
    expect(r.length, 4);
    final perRule = <String, int>{};
    for (final o in r) {
      perRule[o.rule.id] = (perRule[o.rule.id] ?? 0) + 1;
    }
    expect(perRule.values.every((c) => c <= 3), isTrue);
  });

  test('occurrenceId는 rule.id + fireAt로 안정적·고유', () {
    final p = OccurrencePlanner(
        generator: fromMap({
      'a': [day(1), day(2)]
    }));
    final r = p.plan([rule('a', ReminderRecurrence.daily())], from);
    expect(r.map((o) => o.occurrenceId).toSet().length, r.length);
    expect(r.first.occurrenceId, contains('a'));
  });
}
