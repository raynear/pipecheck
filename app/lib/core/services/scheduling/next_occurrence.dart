// DST 안전 다음 발화 시각 계산 — recurrence(요일) × 시각(hh:mm) → 다음 N개 순간.
//
// nextWallClockInstant: 파생 앱 voice-alarm의 BL-6를 이식(월-클록 hh:mm의 다음
// 순간, DST fall-back 모호 시각까지 정확). generateOccurrences: 그 위에 주간 반복
// 확장을 얹어 planner가 소비할 발화 리스트를 만든다. timezone의 명명 로케이션에서
// 결정적으로 계산 — UTC 순간을 절대 영속하지 않는다(월-클록 유지).
import 'package:timezone/timezone.dart' as tz;

import 'reminder_recurrence.dart';

/// PURE. `from.location`에서 월-클록 [hour]:[minute]의 다음 순간, from보다 **엄격히
/// 이후**. DST 정확 — `from`의 로케이션에서 라이브로 유도.
tz.TZDateTime nextWallClockInstant({
  required int hour,
  required int minute,
  required tz.TZDateTime from,
}) {
  assert(hour >= 0 && hour <= 23, 'hour out of range: $hour');
  assert(minute >= 0 && minute <= 59, 'minute out of range: $minute');

  final location = from.location;
  var candidate =
      tz.TZDateTime(location, from.year, from.month, from.day, hour, minute);
  if (!candidate.isAfter(from)) {
    // DST fall-back: 모호한 월-클록은 위에서 첫 발생으로 해석된다. from이 반복된
    // 시간대 안에 있으면(예: 미국 fall-back일 01:30 EST) 진짜 다음 hh:mm은 같은
    // 시간의 두 번째 발생일 수 있다 — 하루를 통째로 넘기기 전에 UTC-전진으로 탐색
    // (실세계 fall-back 델타는 15분 배수 ≤ 2h).
    for (var shift = const Duration(minutes: 15);
        shift <= const Duration(hours: 2);
        shift += const Duration(minutes: 15)) {
      final probe = candidate.add(shift);
      if (probe.hour == hour && probe.minute == minute && probe.isAfter(from)) {
        return probe;
      }
    }
    candidate = tz.TZDateTime(
        location, from.year, from.month, from.day + 1, hour, minute);
  }
  return candidate;
}

/// PURE. [recurrence]의 활성 요일에 맞춰 월-클록 [hour]:[minute]의 다음 [count]개
/// 발화 순간을 오름차순으로. [from]보다 엄격히 이후, 각 요소는 월-클록(isUtc==false).
///
/// - `once`: 요일 무관, 다음 hh:mm 하나만(최대 1).
/// - 그 외: `recurrence.activeDays`(ISO 월=1..일=7)에 드는 날만. 활성 요일이 없으면
///   (weekly/custom 손상 마스크) 빈 리스트.
/// - [count] <= 0 → 빈 리스트.
///
/// 첫 요소는 요청한 [count]와 무관하게 안정적(결정적 생성기).
List<tz.TZDateTime> generateOccurrences({
  required ReminderRecurrence recurrence,
  required int hour,
  required int minute,
  required tz.TZDateTime from,
  required int count,
}) {
  if (count <= 0) return const [];

  final first = nextWallClockInstant(hour: hour, minute: minute, from: from);
  if (recurrence.isOnce) return [first];

  final active = recurrence.activeDays;
  if (active.isEmpty) return const [];

  final location = from.location;
  final result = <tz.TZDateTime>[];
  // 첫 발화는 nextWallClockInstant(from 이후, fall-back 두 번째 발생까지 정확).
  // 이후는 **캘린더 날짜**로 하루씩 전진 — 하루 1회. (candidate에 nextWallClockInstant
  // 을 다시 쓰면 fall-back 반복 시간대에서 같은 날 두 번째 hh:mm을 잡아 중복 발화한다.)
  var candidate = first;
  // 안전 상한: 활성 요일이 있으면 최악 7일에 1회 → count*7 + 7 스텝이면 충분.
  var guard = count * 7 + 7;
  while (result.length < count && guard-- > 0) {
    if (active.contains(candidate.weekday)) result.add(candidate);
    // 다음 캘린더 날의 hh:mm(원본 hour/minute로 재구성 — spring-forward gap에서
    // candidate.hour가 정규화돼도 다음 날 계산이 흔들리지 않게). DateTime 정규화가
    // 월/연 경계를 처리한다.
    candidate = tz.TZDateTime(
        location, candidate.year, candidate.month, candidate.day + 1, hour, minute);
  }
  return result;
}
