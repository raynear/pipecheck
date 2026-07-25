// 리텐션 엔진 테스트 (WS-B — 파생 앱 kanken·hanja StudyHistoryService 역이식).
//
// 스트릭·이번달 지표를 카운터로 저장하지 않고 세션 기록에서 파생한다.
// 저장은 KV 스토어(StudyHistoryStore)로 주입 — SharedPreferences 플러그인 없이
// 검증한다. "지금"(clock)도 주입해 스트릭까지 결정적으로 테스트한다.

import 'package:pipecheck/core/services/study_history/session_record.dart';
import 'package:pipecheck/core/services/study_history/study_history_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 플러그인 프리 인메모리 스토어.
class _MemStore implements StudyHistoryStore {
  final Map<String, String> _m = {};
  @override
  String? read(String key) => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
}

SessionRecord _rec(DateTime t, double weight) =>
    SessionRecord(t: t, weight: weight);

void main() {
  group('completionWeight — 항목 수 기반 규칙(학습앱 헬퍼)', () {
    test('최소 항목 미만 → 0.0', () {
      expect(completionWeight(count: 4, complete: true), 0.0);
    });
    test('완주 → 1.0', () {
      expect(completionWeight(count: 5, complete: true), 1.0);
    });
    test('미완주 → 0.5', () {
      expect(completionWeight(count: 20, complete: false), 0.5);
    });
    test('minItems 조정 가능', () {
      expect(completionWeight(count: 2, complete: true, minItems: 2), 1.0);
      expect(completionWeight(count: 1, complete: true, minItems: 2), 0.0);
    });
  });

  group('SessionRecord.fromJson — 전방 호환', () {
    test('빠진 키는 기본값, 알 수 없는 키는 무시', () {
      final r = SessionRecord.fromJson({
        't': '2026-07-15T09:00:00.000',
        'weight': 1.0,
        'somethingNew': 'ignored',
      });
      expect(r.t, DateTime.parse('2026-07-15T09:00:00.000'));
      expect(r.weight, 1.0);
      expect(r.kind, '');
      expect(r.count, isNull);
    });
    test('저장된 weight는 0..1로 클램프', () {
      expect(SessionRecord.fromJson({'t': '2026-07-15T00:00:00.000', 'weight': 3.0}).weight, 1.0);
      expect(SessionRecord.fromJson({'t': '2026-07-15T00:00:00.000', 'weight': -2.0}).weight, 0.0);
    });
    test('toJson→fromJson 왕복 보존', () {
      final r = SessionRecord(
          t: DateTime(2026, 7, 15, 9),
          weight: 0.5,
          kind: 'quiz',
          count: 10,
          success: 7,
          seconds: 90);
      final back = SessionRecord.fromJson(r.toJson());
      expect(back.t, r.t);
      expect(back.weight, 0.5);
      expect(back.kind, 'quiz');
      expect(back.count, 10);
      expect(back.success, 7);
      expect(back.seconds, 90);
    });
  });

  group('recordStudy / monthRecords — 저장 왕복', () {
    test('기록이 같은 달 버킷에 쌓이고 스토어 공유 인스턴스 간 보존된다', () async {
      final store = _MemStore();
      final a = StudyHistoryService(store);
      await a.recordStudy(_rec(DateTime(2026, 7, 15, 9), 1.0));
      await a.recordStudy(_rec(DateTime(2026, 7, 15, 20), 0.5));

      final b = StudyHistoryService(store); // 같은 스토어를 쓰는 새 인스턴스
      final recs = b.monthRecords(DateTime(2026, 7, 1));
      expect(recs.length, 2);
      expect(recs.map((r) => r.weight), [1.0, 0.5]);
    });

    test('프로필별로 버킷이 분리된다', () async {
      final store = _MemStore();
      final s = StudyHistoryService(store);
      await s.recordStudy(_rec(DateTime(2026, 7, 15, 9), 1.0), profileId: 'p1');
      await s.recordStudy(_rec(DateTime(2026, 7, 15, 9), 1.0), profileId: 'p2');
      expect(s.monthRecords(DateTime(2026, 7, 1), profileId: 'p1').length, 1);
      expect(s.monthRecords(DateTime(2026, 7, 1), profileId: 'p2').length, 1);
    });

    test('깨진 JSON은 빈 목록으로 열리고 예외를 던지지 않는다', () {
      final store = _MemStore();
      store._m[StudyHistoryService.monthKey(
          StudyHistoryService.defaultProfileId, DateTime(2026, 7, 1))] = '{not json';
      final s = StudyHistoryService(store);
      expect(s.monthRecords(DateTime(2026, 7, 1)), isEmpty);
    });
  });

  group('monthDayWeights / 이번달 지표', () {
    test('하루 무게는 그날 세션 무게의 최댓값(합이 아님)', () async {
      final store = _MemStore();
      final s = StudyHistoryService(store);
      await s.recordStudy(_rec(DateTime(2026, 7, 15, 9), 0.5));
      await s.recordStudy(_rec(DateTime(2026, 7, 15, 20), 1.0));
      final w = s.monthDayWeights(DateTime(2026, 7, 1));
      expect(w[DateTime(2026, 7, 15)], 1.0);
    });

    test('무게 0인 세션·날은 지표에서 제외', () async {
      final store = _MemStore();
      final s = StudyHistoryService(store);
      await s.recordStudy(_rec(DateTime(2026, 7, 15, 9), 0.0));
      await s.recordStudy(_rec(DateTime(2026, 7, 16, 9), 1.0));
      expect(s.monthDayWeights(DateTime(2026, 7, 1)).containsKey(DateTime(2026, 7, 15)), false);
      expect(s.monthWeightedDays(DateTime(2026, 7, 1)), 1.0);
    });

    test('monthWeightedSessions = 세션 무게의 합', () async {
      final store = _MemStore();
      final s = StudyHistoryService(store);
      await s.recordStudy(_rec(DateTime(2026, 7, 15, 9), 0.5));
      await s.recordStudy(_rec(DateTime(2026, 7, 16, 9), 1.0));
      await s.recordStudy(_rec(DateTime(2026, 7, 16, 20), 0.5));
      expect(s.monthWeightedSessions(DateTime(2026, 7, 1)), 2.0);
    });
  });

  group('currentStreak — 파생 스트릭(clock 주입)', () {
    StudyHistoryService svc(_MemStore store, DateTime now) =>
        StudyHistoryService(store, clock: () => now);

    test('오늘 포함 3일 연속 → 3', () async {
      final store = _MemStore();
      final now = DateTime(2026, 7, 15, 12);
      final s = svc(store, now);
      for (final d in [13, 14, 15]) {
        await s.recordStudy(_rec(DateTime(2026, 7, d, 9), 1.0));
      }
      expect(s.currentStreak(), 3);
    });

    test('오늘 비었지만 어제까지 연속 → 어제부터 센다', () async {
      final store = _MemStore();
      final now = DateTime(2026, 7, 15, 8); // 아침, 오늘 아직 학습 안 함
      final s = svc(store, now);
      for (final d in [13, 14]) {
        await s.recordStudy(_rec(DateTime(2026, 7, d, 9), 1.0));
      }
      expect(s.currentStreak(), 2);
    });

    test('오늘도 어제도 없으면 0', () async {
      final store = _MemStore();
      final s = svc(store, DateTime(2026, 7, 15, 12));
      await s.recordStudy(_rec(DateTime(2026, 7, 10, 9), 1.0));
      expect(s.currentStreak(), 0);
    });

    test('무게 0인 날은 스트릭을 잇지 않는다', () async {
      final store = _MemStore();
      final now = DateTime(2026, 7, 15, 12);
      final s = svc(store, now);
      await s.recordStudy(_rec(DateTime(2026, 7, 15, 9), 1.0));
      await s.recordStudy(_rec(DateTime(2026, 7, 14, 9), 0.0)); // 끊김
      await s.recordStudy(_rec(DateTime(2026, 7, 13, 9), 1.0));
      expect(s.currentStreak(), 1);
    });

    test('월 경계를 넘어 이어진다', () async {
      final store = _MemStore();
      final now = DateTime(2026, 8, 1, 12);
      final s = svc(store, now);
      await s.recordStudy(_rec(DateTime(2026, 8, 1, 9), 1.0));
      await s.recordStudy(_rec(DateTime(2026, 7, 31, 9), 1.0));
      await s.recordStudy(_rec(DateTime(2026, 7, 30, 9), 1.0));
      expect(s.currentStreak(), 3);
    });
  });

  group('gapDaysForToday — 며칠 만인가', () {
    StudyHistoryService svc(_MemStore store, DateTime now) =>
        StudyHistoryService(store, clock: () => now);

    test('생애 첫 학습 → null', () async {
      final store = _MemStore();
      final s = svc(store, DateTime(2026, 7, 15, 12));
      await s.recordStudy(_rec(DateTime(2026, 7, 15, 12), 1.0));
      expect(s.gapDaysForToday(), null);
    });

    test('오늘 이미 학습(두 번째 세션) → 0', () async {
      final store = _MemStore();
      final s = svc(store, DateTime(2026, 7, 15, 20));
      await s.recordStudy(_rec(DateTime(2026, 7, 15, 9), 1.0));
      await s.recordStudy(_rec(DateTime(2026, 7, 15, 20), 1.0));
      expect(s.gapDaysForToday(), 0);
    });

    test('마지막 학습이 5일 전 → 5', () async {
      final store = _MemStore();
      final s = svc(store, DateTime(2026, 7, 15, 12));
      await s.recordStudy(_rec(DateTime(2026, 7, 10, 9), 1.0));
      await s.recordStudy(_rec(DateTime(2026, 7, 15, 12), 1.0));
      expect(s.gapDaysForToday(), 5);
    });

    test('무게 0 세션은 "오늘 학습함"으로 치지 않는다', () async {
      final store = _MemStore();
      final s = svc(store, DateTime(2026, 7, 15, 20));
      await s.recordStudy(_rec(DateTime(2026, 7, 10, 9), 1.0)); // 진짜 직전
      await s.recordStudy(_rec(DateTime(2026, 7, 15, 9), 0.0)); // 오늘 짧은 세션(무게0)
      await s.recordStudy(_rec(DateTime(2026, 7, 15, 20), 1.0)); // 오늘 첫 제대로 학습
      expect(s.gapDaysForToday(), 5);
    });
  });

  group('lastStudyAtBeforeToday', () {
    test('오늘 세션은 무시하고 이전 최종 학습 시각을 준다', () async {
      final store = _MemStore();
      final now = DateTime(2026, 7, 15, 20);
      final s = StudyHistoryService(store, clock: () => now);
      await s.recordStudy(_rec(DateTime(2026, 7, 12, 9), 1.0));
      await s.recordStudy(_rec(DateTime(2026, 7, 15, 9), 1.0));
      expect(s.lastStudyAtBeforeToday(), DateTime(2026, 7, 12, 9));
    });
  });

  group('lastStudyAt — 역방향 월 walk', () {
    test('두 달 전 기록도 찾는다(월 경계 거슬러 올라감)', () async {
      final store = _MemStore();
      final now = DateTime(2026, 7, 15, 12);
      final s = StudyHistoryService(store, clock: () => now);
      await s.recordStudy(_rec(DateTime(2026, 5, 20, 9), 1.0));
      expect(s.lastStudyAt(), DateTime(2026, 5, 20, 9));
    });

    test('1월 정규화: 작년 12월 기록을 찾는다', () async {
      final store = _MemStore();
      final now = DateTime(2026, 1, 10, 12);
      final s = StudyHistoryService(store, clock: () => now);
      await s.recordStudy(_rec(DateTime(2025, 12, 28, 9), 1.0));
      expect(s.lastStudyAt(), DateTime(2025, 12, 28, 9));
    });

    test('13개월 룩백 한계: 14개월 전은 안 보이고 12개월 전은 보인다', () async {
      final store = _MemStore();
      final now = DateTime(2026, 7, 15, 12);
      final s = StudyHistoryService(store, clock: () => now);
      await s.recordStudy(_rec(DateTime(2025, 5, 1, 9), 1.0)); // 14개월 전
      expect(s.lastStudyAt(), isNull);
      await s.recordStudy(_rec(DateTime(2025, 7, 20, 9), 1.0)); // 12개월 전
      expect(s.lastStudyAt(), DateTime(2025, 7, 20, 9));
    });
  });

  group('연 경계 스트릭', () {
    test('12/31 → 1/1 연속이 이어진다', () async {
      final store = _MemStore();
      final now = DateTime(2027, 1, 1, 12);
      final s = StudyHistoryService(store, clock: () => now);
      await s.recordStudy(_rec(DateTime(2027, 1, 1, 9), 1.0));
      await s.recordStudy(_rec(DateTime(2026, 12, 31, 9), 1.0));
      await s.recordStudy(_rec(DateTime(2026, 12, 30, 9), 1.0));
      expect(s.currentStreak(), 3);
    });
  });

  group('빈 스토어', () {
    test('스트릭 0 / lastStudyAt null / gap null', () {
      final store = _MemStore();
      final s = StudyHistoryService(store, clock: () => DateTime(2026, 7, 15, 12));
      expect(s.currentStreak(), 0);
      expect(s.lastStudyAt(), isNull);
      expect(s.gapDaysForToday(), isNull);
    });
  });

  group('자정 경계 레코드', () {
    test('자정(00:00:00) 기록도 그날에 정확히 버킷된다', () async {
      final store = _MemStore();
      final now = DateTime(2026, 7, 15, 12);
      final s = StudyHistoryService(store, clock: () => now);
      await s.recordStudy(_rec(DateTime(2026, 7, 15, 0, 0, 0), 1.0));
      expect(s.currentStreak(), 1);
      expect(s.monthDayWeights(DateTime(2026, 7, 1))[DateTime(2026, 7, 15)], 1.0);
    });
  });

  group('gapDaysForToday — DST 안전(캘린더 일수)', () {
    test('서머타임(봄 전진)이 낀 5일 공백도 5로 센다', () async {
      // 미 동부 2027-03-14 봄 전진(23시간 하루). now=3/16, 직전=3/11 → 5일.
      final store = _MemStore();
      final now = DateTime(2027, 3, 16, 12);
      final s = StudyHistoryService(store, clock: () => now);
      await s.recordStudy(_rec(DateTime(2027, 3, 11, 9), 1.0));
      await s.recordStudy(_rec(DateTime(2027, 3, 16, 12), 1.0));
      expect(s.gapDaysForToday(), 5);
    });
  });

  group('_read — 레코드 단위 관용', () {
    test('한 레코드가 깨져도 유효 레코드는 보존된다', () {
      final store = _MemStore();
      final key = StudyHistoryService.monthKey(
          StudyHistoryService.defaultProfileId, DateTime(2026, 7, 1));
      // 유효 1건 + 't' 누락으로 깨진 1건이 섞인 리스트.
      store._m[key] =
          '[{"t":"2026-07-15T09:00:00.000","weight":1.0},{"weight":1.0}]';
      final s = StudyHistoryService(store);
      final recs = s.monthRecords(DateTime(2026, 7, 1));
      expect(recs.length, 1);
      expect(recs.first.t, DateTime(2026, 7, 15, 9));
    });
  });
}
