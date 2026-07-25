// nextWallClockInstant + generateOccurrences — DST 안전 다음 발화 시각 계산 테스트.
//
// 파생 앱 voice-alarm의 BL-6 nextWallClockInstant(월-클록 hh:mm의 다음 순간, DST
// 정확)를 이식하고, 그 위에 recurrence×시각 → 다음 N개 발화 순간 확장을 얹는다.
// timezone 패키지의 명명 로케이션으로 결정적·테스트 가능(디바이스 존 비의존).

import 'package:boilerplate/core/services/scheduling/next_occurrence.dart';
import 'package:boilerplate/core/services/scheduling/reminder_recurrence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location ny;
  setUpAll(() {
    tzdata.initializeTimeZones();
    ny = tz.getLocation('America/New_York');
  });

  tz.TZDateTime at(int y, int m, int d, int h, [int min = 0]) =>
      tz.TZDateTime(ny, y, m, d, h, min);

  group('nextWallClockInstant', () {
    test('오늘 미래 hh:mm이면 오늘', () {
      final r = nextWallClockInstant(hour: 9, minute: 0, from: at(2026, 1, 2, 8));
      expect(r, at(2026, 1, 2, 9));
    });

    test('오늘 이미 지났으면 내일', () {
      final r = nextWallClockInstant(hour: 9, minute: 0, from: at(2026, 1, 2, 10));
      expect(r, at(2026, 1, 3, 9));
    });

    test('정확히 같은 시각이면 내일 (strictly after)', () {
      final r = nextWallClockInstant(hour: 9, minute: 0, from: at(2026, 1, 2, 9));
      expect(r, at(2026, 1, 3, 9));
    });

    test('결과는 항상 from 이후이고 요청 hh:mm', () {
      final from = at(2026, 3, 8, 5); // DST spring-forward 당일(NY 02:00→03:00)
      final r = nextWallClockInstant(hour: 7, minute: 30, from: from);
      expect(r.isAfter(from), isTrue);
      expect(r.hour, 7);
      expect(r.minute, 30);
    });
  });

  group('generateOccurrences', () {
    test('once → 정확히 1개 (다음 hh:mm, 요일 무관)', () {
      final r = generateOccurrences(
        recurrence: ReminderRecurrence.once(),
        hour: 9,
        minute: 0,
        from: at(2026, 1, 3, 8), // 토요일
        count: 5,
      );
      expect(r, [at(2026, 1, 3, 9)]);
    });

    test('daily count=3 → 연속 3일', () {
      final r = generateOccurrences(
        recurrence: ReminderRecurrence.daily(),
        hour: 21,
        minute: 0,
        from: at(2026, 1, 1, 22), // 이미 지남 → 내일부터
        count: 3,
      );
      expect(r, [at(2026, 1, 2, 21), at(2026, 1, 3, 21), at(2026, 1, 4, 21)]);
    });

    test('weekdays: 주말 건너뜀 (금 시작)', () {
      // 2026-01-02=금(5). 평일만 → 금, (토·일 스킵), 월, 화.
      final r = generateOccurrences(
        recurrence: ReminderRecurrence.weekdays(),
        hour: 9,
        minute: 0,
        from: at(2026, 1, 2, 8),
        count: 3,
      );
      expect(r, [at(2026, 1, 2, 9), at(2026, 1, 5, 9), at(2026, 1, 6, 9)]);
    });

    test('weekly {월} count=2 → 다음 두 월요일', () {
      final r = generateOccurrences(
        recurrence: ReminderRecurrence.weekly({1}),
        hour: 7,
        minute: 30,
        from: at(2026, 1, 2, 8), // 금
        count: 2,
      );
      expect(r, [at(2026, 1, 5, 7, 30), at(2026, 1, 12, 7, 30)]);
    });

    test('빈 마스크(weekly, 손상) → 빈 리스트', () {
      final r = generateOccurrences(
        recurrence: ReminderRecurrence.decode('weekly', 'garbage'),
        hour: 9,
        minute: 0,
        from: at(2026, 1, 2, 8),
        count: 3,
      );
      expect(r, isEmpty);
    });

    test('count<=0 → 빈 리스트', () {
      expect(
        generateOccurrences(
          recurrence: ReminderRecurrence.daily(),
          hour: 9,
          minute: 0,
          from: at(2026, 1, 2, 8),
          count: 0,
        ),
        isEmpty,
      );
    });

    test('첫 원소는 count와 무관하게 안정적 (결정적 생성기)', () {
      final one = generateOccurrences(
          recurrence: ReminderRecurrence.weekdays(),
          hour: 9,
          minute: 0,
          from: at(2026, 1, 2, 8),
          count: 1);
      final many = generateOccurrences(
          recurrence: ReminderRecurrence.weekdays(),
          hour: 9,
          minute: 0,
          from: at(2026, 1, 2, 8),
          count: 10);
      expect(one.first, many.first);
    });

    test('모든 순간은 from 이후, 오름차순, isUtc==false', () {
      final from = at(2026, 1, 2, 8);
      final r = generateOccurrences(
          recurrence: ReminderRecurrence.daily(),
          hour: 9,
          minute: 0,
          from: from,
          count: 5);
      for (var i = 0; i < r.length; i++) {
        expect(r[i].isAfter(from), isTrue);
        expect(r[i].isUtc, isFalse);
        if (i > 0) expect(r[i].isAfter(r[i - 1]), isTrue);
      }
    });

    group('마스크 커버리지', () {
      test('weekends: 토·일만', () {
        final r = generateOccurrences(
          recurrence: ReminderRecurrence.weekends(),
          hour: 9,
          minute: 0,
          from: at(2026, 1, 2, 8), // 금
          count: 2,
        );
        expect(r, [at(2026, 1, 3, 9), at(2026, 1, 4, 9)]); // 토, 일
      });

      test('custom {화,목}', () {
        final r = generateOccurrences(
          recurrence: ReminderRecurrence.custom({2, 4}),
          hour: 9,
          minute: 0,
          from: at(2026, 1, 5, 8), // 월
          count: 3,
        );
        expect(r, [at(2026, 1, 6, 9), at(2026, 1, 8, 9), at(2026, 1, 13, 9)]);
      });

      test('weekly, null 마스크 → 빈 (활성 요일 없음)', () {
        final r = generateOccurrences(
          recurrence: ReminderRecurrence.decode('weekly', null),
          hour: 9,
          minute: 0,
          from: at(2026, 1, 2, 8),
          count: 3,
        );
        expect(r, isEmpty);
      });

      test('단일 활성 요일 + 큰 count: 언더필 없음 (guard 상한 검증)', () {
        // 2026-01-07 = 수요일(3). weekly {수} 8회 → 8개 연속 수요일.
        final r = generateOccurrences(
          recurrence: ReminderRecurrence.weekly({3}),
          hour: 9,
          minute: 0,
          from: at(2026, 1, 1, 8),
          count: 8,
        );
        expect(r.length, 8);
        expect(r.every((d) => d.weekday == 3), isTrue);
        for (var i = 1; i < r.length; i++) {
          expect(r[i].difference(r[i - 1]).inDays, 7);
        }
      });
    });
  });

  // DST 경계 — nextWallClockInstant의 fall-back 프로브 경로 + generateOccurrences의
  // 캘린더-날짜 전진이 반복 시간대에서 중복 발화하지 않는지. (US 2026: spring-forward
  // 03-08, fall-back 11-01, 둘 다 일요일.)
  group('DST 경계', () {
    test('fall-back: 반복된 hh:mm의 두 번째 발생을 잡는다', () {
      // 11-01 01:30은 EDT/EST 두 번 존재. from을 첫 01:30(EDT)에 두면 다음은
      // 두 번째 01:30(EST) — 절대시간 1시간 뒤, 벽시계는 여전히 01:30.
      final from = tz.TZDateTime(ny, 2026, 11, 1, 1, 30);
      final r = nextWallClockInstant(hour: 1, minute: 30, from: from);
      expect(r.isAfter(from), isTrue);
      expect(r.hour, 1);
      expect(r.minute, 30);
      expect(r.difference(from).inMinutes, 60); // 두 번째 발생
    });

    test('spring-forward gap: 존재하지 않는 벽시계는 앞으로 정규화(비크래시)', () {
      // 03-08 02:30은 존재하지 않음(02:00→03:00). tz가 03:30으로 정규화.
      final from = tz.TZDateTime(ny, 2026, 3, 8, 0, 0);
      final r = nextWallClockInstant(hour: 2, minute: 30, from: from);
      expect(r.isAfter(from), isTrue);
      expect(r.day, 8); // 같은 날, 하루를 건너뛰지 않음
      expect(r.hour, 3); // gap → 앞으로 정규화
    });

    test('daily는 fall-back 날 한 번만 발화 (중복 금지 — 회귀)', () {
      // from=10-31, daily 01:30, 4회 → Nov1,2,3,4 각 1회. Nov1의 반복 01:30이
      // 두 번 들어가지 않아야 한다.
      final r = generateOccurrences(
        recurrence: ReminderRecurrence.daily(),
        hour: 1,
        minute: 30,
        from: tz.TZDateTime(ny, 2026, 10, 31, 12),
        count: 4,
      );
      expect(r.length, 4);
      expect(r.map((d) => d.day), [1, 2, 3, 4]); // 11월 연속 4일
      expect(r.where((d) => d.month == 11 && d.day == 1).length, 1); // Nov1 한 번
    });
  });
}
