// iOS 64-알림 상한 + 규칙별 다음-N 예산의 순수 창 플래너.
//
// 파생 앱 voice-alarm(AlarmOccurrencePlanner)·quran(buildAdhanSchedule)이 각자
// 재발명한 2-패스 공정 채움 알고리즘을 도메인 비결합으로 이식. iOS는 대기 알림
// 64개 하드 상한이 있어, 규칙이 많으면 "가장 이른 규칙부터 각 1회(liveness)" →
// "예산 남으면 반복 규칙의 다음 발화를 라운드로빈으로 버퍼(N일 미리 등록)"한다.
//
// 생성기(recurrence×시각 → 발화 리스트)는 주입 — 프로덕션은 next_occurrence.dart의
// generateOccurrences를 tz `from`으로 감싸 넘기고, 테스트는 합성 리스트로 tz 없이
// 순수 검증한다.
//
// ─── 언제 이 엔진을 쓰나 (native OS 반복과의 경계) ─────────────────────────
// **정적 반복 리마인더**(매주 월·수 09:00 "복습 시간" — 발화마다 내용 동일)는 이
// 엔진이 아니라 notifications 패키지의 native 반복(AwesomeNotifications
// `NotificationCalendar(weekday:, hour:, minute:, repeats: true)`)을 써라 — OS가
// 반복·벽시계·DST를 단일 등록으로 처리하고 64-상한을 소비하지 않는다.
//
// 이 엔진(발화를 명시 열거해 one-shot으로 등록)은 native 반복으로 안 되는 경우를
// 위한 것이다:
//   • 발화마다 내용이 다름(예: "오늘 12개 카드 due" — voca/hanja/kanken 카피가
//     현재 streak/due를 반영) → 반복 1건으로 불가, N개 one-shot 필요.
//   • 다가오는 N개 발화를 명시적으로 나열/취소해야 함(diff 리스케줄).
//   • 플러그인 비의존 경로 / 발화별 프리싱스 오디오(voice-alarm).
// Phase 2 리스케줄러는 이 경계를 지켜 정적 반복을 native로 위임할 것.
import 'package:utils/utils.dart';

import 'reminder_recurrence.dart';

/// INV: iOS 대기 알림 하드 상한 + 규칙별 사전 등록 창(N)의 예산 노브.
class ReschedulePolicy {
  /// iOS UNUserNotificationCenter 대기 요청 상한.
  static const int iosNotificationCap = 64;

  /// 반복 규칙당 미리 등록할 미래 발화 수("N"). 앱이 죽어 있어도 다음 며칠은
  /// 포그라운드 재동기화 없이 울리도록 버퍼.
  static const int defaultWindowPerRule = 7;

  const ReschedulePolicy({
    this.globalCap = iosNotificationCap,
    this.windowPerRule = defaultWindowPerRule,
  });

  /// 총 사전 등록 발화 수는 이 값 이하.
  final int globalCap;

  /// 규칙별 발화 수는 이 값 이하.
  final int windowPerRule;
}

/// 주입되는 반복 확장 seam. [rule]의 다음 [count]개 미래 발화(로컬 월-클록
/// `DateTime`, isUtc==false)를 [from]보다 엄격히 이후로, 가장 이른 것부터.
/// 비반복(`once`)은 최대 1개(이미 지났으면 빈). 첫 요소는 [count]와 무관하게 안정적.
typedef OccurrenceGenerator = List<DateTime> Function(
  ReminderRule rule,
  DateTime from,
  int count,
);

/// 예약 대상 반복 규칙. [payload]로 앱이 알림 제목/본문 등을 실어 나른다(플래너
/// 불투명). 발화 요일·시각은 [recurrence]+[hour]:[minute]로 결정.
class ReminderRule {
  const ReminderRule({
    required this.id,
    required this.recurrence,
    required this.hour,
    required this.minute,
    this.payload,
  });

  final String id;
  final ReminderRecurrence recurrence;
  final int hour;
  final int minute;
  final Object? payload;

  bool get isRecurring => !recurrence.isOnce;
}

/// 지금 등록할 하나의 발화.
class ScheduledOccurrence {
  const ScheduledOccurrence({required this.rule, required this.fireAt});

  final ReminderRule rule;
  final DateTime fireAt; // 로컬 월-클록, isUtc==false

  /// 규칙 + 발화 시각으로 결정적·고유. cancel/diff에 안정 키로 사용.
  String get occurrenceId => '${rule.id}@${fireAt.toIso8601String()}';
}

/// 한 규칙의 후보 발화(최대 windowPerRule개), 정렬·라운드로빈용으로 규칙과 함께.
class _RuleCandidates {
  _RuleCandidates(this.rule, this.occurrences);
  final ReminderRule rule;
  final List<DateTime> occurrences; // 이른 순, length >= 1
  DateTime get nextFireAt => occurrences.first;
}

class OccurrencePlanner {
  OccurrencePlanner({
    required this.generator,
    this.policy = const ReschedulePolicy(),
  });

  final OccurrenceGenerator generator;
  final ReschedulePolicy policy;

  /// 지금 등록할 발화들을 계획한다.
  ///
  /// 사후조건:
  ///   (P1) result.length <= policy.globalCap
  ///   (P2) rule별 count <= policy.windowPerRule; 비반복 <= 1
  ///   (P3) 미래 발화가 있는 규칙은 예산이 남는 한 nextFireAt 오름차순으로 >=1회 등장
  ///   (P4) 모든 fireAt이 from 이후, 출력은 fireAt 오름차순
  List<ScheduledOccurrence> plan(List<ReminderRule> rules, DateTime from) {
    // rule.id는 occurrenceId·round-robin nextIndex 맵의 키다. 중복 id면 발화가
    // 조용히 사라지고 버퍼가 오염되므로 호출자 버그를 크게 잡는다(사용자 데이터 아님).
    assert(
      rules.map((r) => r.id).toSet().length == rules.length,
      'ReminderRule.id must be unique (occurrence dedup + round-robin key). '
      'Got: ${rules.map((r) => r.id).toList()}',
    );
    // 1단계: 규칙별 후보 발화 수집; 미래 발화 없는 규칙은 드롭. (nextFireAt asc,
    // id asc)로 안정 정렬.
    final candidates = <_RuleCandidates>[];
    for (final rule in rules) {
      final occurrences = generator(rule, from, policy.windowPerRule);
      if (occurrences.isEmpty) continue;
      candidates.add(_RuleCandidates(rule, occurrences));
    }
    candidates.sort((a, b) {
      final byTime = a.nextFireAt.compareTo(b.nextFireAt);
      if (byTime != 0) return byTime;
      return a.rule.id.compareTo(b.rule.id);
    });

    // 2단계(pass 1, liveness): globalCap개 가장 이른 규칙의 #0.
    final List<_RuleCandidates> included;
    if (candidates.length > policy.globalCap) {
      logger.w(
        'OccurrencePlanner.plan: ${candidates.length} rules exceed '
        'globalCap=${policy.globalCap}; dropping the '
        '${candidates.length - policy.globalCap} latest-firing rule(s).',
      );
      included = candidates.sublist(0, policy.globalCap);
    } else {
      included = candidates;
    }

    final result = <ScheduledOccurrence>[
      for (final c in included)
        ScheduledOccurrence(rule: c.rule, fireAt: c.occurrences[0]),
    ];

    // 3단계(pass 2, buffer): 반복 규칙의 다음 발화를 예산/창이 다할 때까지 라운드로빈.
    var budget = policy.globalCap - result.length;
    if (budget > 0) {
      final recurring = included.where((c) => c.rule.isRecurring).toList();
      final nextIndex = {for (final c in recurring) c.rule.id: 1};
      var progressed = true;
      while (budget > 0 && progressed) {
        progressed = false;
        for (final c in recurring) {
          if (budget <= 0) break;
          final i = nextIndex[c.rule.id]!;
          if (i >= policy.windowPerRule || i >= c.occurrences.length) continue;
          result.add(
              ScheduledOccurrence(rule: c.rule, fireAt: c.occurrences[i]));
          nextIndex[c.rule.id] = i + 1;
          budget--;
          progressed = true;
        }
      }
    }

    // 4단계: 안정 출력 순서(P4). Dart List.sort는 불안정하므로 동시각은
    // occurrenceId(=ruleId@fireAt)로 tie-break해 결정적 순서를 보장.
    result.sort((a, b) {
      final byTime = a.fireAt.compareTo(b.fireAt);
      if (byTime != 0) return byTime;
      return a.occurrenceId.compareTo(b.occurrenceId);
    });
    return result;
  }
}
