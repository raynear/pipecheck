// ReminderRecurrence — 주간 반복 규칙의 순수 값 모델 테스트.
//
// 파생 앱 voice-alarm의 RepeatSchedule(다중 앱이 재발명한 (type, daysMask) 쌍의
// 타입드 뷰)을 도메인 비결합 형태로 이식. DB TEXT 쌍과의 인코드/디코드는 total
// (절대 throw 안 함, 손상 입력은 안전 폴백), activeDays는 ISO 요일(월=1..일=7).

import 'package:boilerplate/core/services/scheduling/reminder_recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('activeDays — 어떤 요일에 울리나 (ISO 월=1..일=7)', () {
    test('프리셋', () {
      expect(ReminderRecurrence.once().activeDays, <int>{});
      expect(ReminderRecurrence.daily().activeDays, {1, 2, 3, 4, 5, 6, 7});
      expect(ReminderRecurrence.weekdays().activeDays, {1, 2, 3, 4, 5});
      expect(ReminderRecurrence.weekends().activeDays, {6, 7});
    });

    test('custom/weekly 마스크에서 유도', () {
      expect(ReminderRecurrence.custom({1, 3, 5}).activeDays, {1, 3, 5});
      expect(ReminderRecurrence.weekly({7}).activeDays, {7});
    });

    test('activeDays는 수정 불가', () {
      final days = ReminderRecurrence.daily().activeDays;
      expect(() => days.add(9), throwsUnsupportedError);
    });
  });

  group('decode — DB (type, mask) → 객체, total (never throws)', () {
    test('프리셋은 마스크 무시', () {
      expect(ReminderRecurrence.decode('daily', null).type, RecurrenceType.daily);
      // 프리셋에 딸린 stray 마스크는 비정합 → 버림.
      expect(ReminderRecurrence.decode('weekdays', '1111111').daysMask, isNull);
    });

    test('알 수 없는 타입 → once 안전 폴백', () {
      expect(ReminderRecurrence.decode('garbage', null).type, RecurrenceType.once);
      expect(ReminderRecurrence.decode('DAILY', null).type, RecurrenceType.once);
    });

    test('weekly/custom: 잘 형성된 마스크만 보존, 아니면 null', () {
      expect(ReminderRecurrence.decode('weekly', '1000001').daysMask, '1000001');
      expect(ReminderRecurrence.decode('custom', 'xyz').daysMask, isNull);
      expect(ReminderRecurrence.decode('weekly', '101').daysMask, isNull);
    });
  });

  group('encode — 객체 → DB 쌍', () {
    test('프리셋은 mask null', () {
      final s = ReminderRecurrence.weekdays();
      expect(s.repeatType, 'weekdays');
      expect(s.repeatDaysMask, isNull);
    });
    test('custom은 7자 월-우선 마스크', () {
      final s = ReminderRecurrence.custom({1, 7});
      expect(s.repeatType, 'custom');
      expect(s.repeatDaysMask, '1000001');
    });
  });

  group('validatePair — 저장 전 검증 (null=유효)', () {
    test('유효', () {
      expect(ReminderRecurrence.validatePair('daily', null), isNull);
      expect(ReminderRecurrence.validatePair('weekly', '1000000'), isNull);
    });
    test('고정 순서의 오류 사유', () {
      expect(ReminderRecurrence.validatePair('nope', null),
          RecurrenceError.unknownType);
      expect(ReminderRecurrence.validatePair('daily', '1111111'),
          RecurrenceError.unexpectedMask);
      expect(ReminderRecurrence.validatePair('weekly', null),
          RecurrenceError.missingMask);
      expect(ReminderRecurrence.validatePair('custom', '11'),
          RecurrenceError.malformedMask);
      expect(ReminderRecurrence.validatePair('weekly', '0000000'),
          RecurrenceError.emptyMask);
    });
  });

  group('maskFromDays / fromDays', () {
    test('maskFromDays: 빈/범위밖은 ArgumentError (호출자 버그)', () {
      expect(() => ReminderRecurrence.maskFromDays({}), throwsArgumentError);
      expect(() => ReminderRecurrence.maskFromDays({0}), throwsArgumentError);
      expect(() => ReminderRecurrence.maskFromDays({8}), throwsArgumentError);
      expect(ReminderRecurrence.maskFromDays({2, 4}), '0101000');
    });

    test('fromDays: 신선한 선택을 친근한 프리셋으로 정규화', () {
      expect(ReminderRecurrence.fromDays({1, 2, 3, 4, 5, 6, 7}).type,
          RecurrenceType.daily);
      expect(ReminderRecurrence.fromDays({1, 2, 3, 4, 5}).type,
          RecurrenceType.weekdays);
      expect(ReminderRecurrence.fromDays({6, 7}).type, RecurrenceType.weekends);
      expect(ReminderRecurrence.fromDays({2, 4}).type, RecurrenceType.custom);
    });
  });

  group('isOnce + 값 동등성', () {
    test('isOnce', () {
      expect(ReminderRecurrence.once().isOnce, isTrue);
      expect(ReminderRecurrence.daily().isOnce, isFalse);
    });
    test('== / hashCode (값 기반)', () {
      expect(ReminderRecurrence.custom({1, 3}),
          ReminderRecurrence.custom({1, 3}));
      expect(ReminderRecurrence.custom({1, 3}).hashCode,
          ReminderRecurrence.custom({1, 3}).hashCode);
      expect(ReminderRecurrence.daily() == ReminderRecurrence.weekdays(),
          isFalse);
    });
  });

  // 왕복: decode(encode(x)) == x (정규형에서).
  test('round-trip decode∘encode', () {
    for (final s in [
      ReminderRecurrence.once(),
      ReminderRecurrence.daily(),
      ReminderRecurrence.weekdays(),
      ReminderRecurrence.weekends(),
      ReminderRecurrence.weekly({1, 4, 7}),
      ReminderRecurrence.custom({3}),
    ]) {
      expect(ReminderRecurrence.decode(s.repeatType, s.repeatDaysMask), s);
    }
  });
}
