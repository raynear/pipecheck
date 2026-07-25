import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utils/utils.dart';

import 'session_record.dart';

/// 세션 기록을 담는 KV 스토어 추상화.
///
/// 읽기는 **동기** — 스트릭 계산이 최대 13개월 버킷을 루프로 훑기 때문에 매 키마다
/// await 하지 않도록 한다(프로덕션에선 이미 로드된 SharedPreferences를 감싼다).
/// 테스트는 인메모리 구현을 주입해 플러그인 없이 검증한다.
abstract class StudyHistoryStore {
  String? read(String key);
  Future<void> write(String key, String value);
}

/// 이미 로드된 [SharedPreferences]를 감싸는 프로덕션 스토어.
class SharedPreferencesStudyHistoryStore implements StudyHistoryStore {
  SharedPreferencesStudyHistoryStore(this._prefs);
  final SharedPreferences _prefs;

  @override
  String? read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);
}

/// 학습/활동 이력의 유일한 출처 (WS-B — 파생 앱 kanken·hanja 역이식).
///
/// 스트릭·이번달 일수·이번달 횟수를 카운터로 유지하지 않고 [SessionRecord]에서
/// 파생한다. 새 활동 경로가 생겨도 [recordStudy] 한 줄이면 모든 지표가 따라온다.
///
/// 저장 키는 프로필·월 단위로 쪼갠다: 세션이 끝날 때마다 이번 달치(많아야 백여 건)만
/// 다시 직렬화하므로 몇 년을 써도 쓰기 비용이 그대로다. 삭제 정책도 필요 없다.
class StudyHistoryService {
  StudyHistoryService(this._store, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final StudyHistoryStore _store;

  /// "지금"을 주입 가능하게 해 스트릭/공백일수를 결정적으로 테스트한다.
  final DateTime Function() _now;

  static const String _keyPrefix = 'study_sessions_v1';

  /// 단일 프로필 앱의 기본 프로필 ID. 멀티 프로필 앱은 명시적으로 전달한다.
  static const String defaultProfileId = 'default';

  /// `study_sessions_v1|<profileId>|2026-07`
  static String monthKey(String profileId, DateTime month) {
    final mm = month.month.toString().padLeft(2, '0');
    return '$_keyPrefix|$profileId|${month.year}-$mm';
  }

  /// 유일한 쓰기 경로.
  Future<void> recordStudy(
    SessionRecord r, {
    String profileId = defaultProfileId,
  }) async {
    final key = monthKey(profileId, r.t);
    final records = _read(key)..add(r);
    await _store.write(
      key,
      jsonEncode(records.map((e) => e.toJson()).toList()),
    );
  }

  /// [month]가 속한 달의 세션 기록. 날짜순 보장 없음(기록 순서 그대로).
  List<SessionRecord> monthRecords(
    DateTime month, {
    String profileId = defaultProfileId,
  }) =>
      _read(monthKey(profileId, month));

  /// 그 달에 학습한 날 → 하루 무게. **무게가 0인 날은 들어 있지 않다.**
  /// 하루 무게는 그날 세션 무게의 최댓값이다(하루가 2일이 될 수 없으므로 더하지 않음).
  Map<DateTime, double> monthDayWeights(
    DateTime month, {
    String profileId = defaultProfileId,
  }) {
    final out = <DateTime, double>{};
    for (final r in monthRecords(month, profileId: profileId)) {
      if (r.weight == 0.0) continue;
      final day = DateTime(r.t.year, r.t.month, r.t.day);
      final prev = out[day] ?? 0.0;
      if (r.weight > prev) out[day] = r.weight;
    }
    return out;
  }

  /// 이번달 날짜 수 — 하루 무게의 합(12.5처럼 소수 가능).
  double monthWeightedDays(
    DateTime month, {
    String profileId = defaultProfileId,
  }) =>
      monthDayWeights(month, profileId: profileId)
          .values
          .fold(0.0, (a, b) => a + b);

  /// 이번달 횟수 — 세션 무게의 합("N회"는 원시 세션 수가 아니라 이 값).
  double monthWeightedSessions(
    DateTime month, {
    String profileId = defaultProfileId,
  }) =>
      monthRecords(month, profileId: profileId)
          .fold(0.0, (a, r) => a + r.weight);

  /// 무게 > 0인 세션 중 가장 최근 시각.
  ///
  /// [before]가 주어지면 그보다 **엄격히 이전**인 세션만 본다(방금 기록한 세션을
  /// 빼고 "직전 학습이 언제였나"). 최대 13개월치 버킷만 거슬러 본다 — 1년 넘게
  /// 안 온 유저의 정확한 공백일수는 문구에 쓸모가 없다.
  DateTime? lastStudyAt({
    DateTime? before,
    String profileId = defaultProfileId,
  }) {
    final from = before ?? _now();
    var cursor = DateTime(from.year, from.month, 1);
    for (var i = 0; i < 13; i++) {
      DateTime? best;
      for (final r in monthRecords(cursor, profileId: profileId)) {
        if (r.weight == 0.0) continue;
        if (!r.t.isBefore(from)) continue;
        if (best == null || r.t.isAfter(best)) best = r.t;
      }
      if (best != null) return best;
      cursor = DateTime(cursor.year, cursor.month - 1, 1);
    }
    return null;
  }

  /// 오늘보다 **이전**의 마지막 학습 시각(완료 화면 "며칠 만인가"용).
  DateTime? lastStudyAtBeforeToday({String profileId = defaultProfileId}) {
    final now = _now();
    return lastStudyAt(
      before: DateTime(now.year, now.month, now.day),
      profileId: profileId,
    );
  }

  /// 방금 기록한 세션 기준 "며칠 만인가".
  ///
  /// `null` = 생애 첫 학습, `0` = 오늘 이미 학습(이번이 오늘 두 번째 이상), `N` = N일 만.
  ///
  /// **오늘 세션 수는 무게 > 0인 것만 센다.** 원시 세션 수로 세면 판정의 두 짝이
  /// 서로 다른 기준을 쓰게 되어(짧은 무게-0 세션이 "오늘 두 번째"를 만들어) 생애
  /// 첫 제대로 된 학습에 "오늘 두 번째"가 뜨는 버그가 난다 — 파생 앱에서 실제로 겪음.
  int? gapDaysForToday({String profileId = defaultProfileId}) {
    final at = _now();
    final today = DateTime(at.year, at.month, at.day);

    final todaySessions = monthRecords(today, profileId: profileId)
        .where((r) =>
            DateTime(r.t.year, r.t.month, r.t.day) == today && r.weight > 0)
        .length;

    final previous = todaySessions >= 2
        ? today
        : _dayOf(lastStudyAt(before: today, profileId: profileId));
    if (previous == null) return null;
    return _calendarDaysBetween(previous, today);
  }

  DateTime? _dayOf(DateTime? t) =>
      t == null ? null : DateTime(t.year, t.month, t.day);

  /// 두 (자정 정규화) 로컬 날짜 사이 캘린더 일수. UTC로 환산해 세므로 서머타임
  /// 전환(23/25시간 하루)이 있어도 `Duration.inDays`가 하루 적게/많이 세지 않는다.
  int _calendarDaysBetween(DateTime earlier, DateTime later) =>
      DateTime.utc(later.year, later.month, later.day)
          .difference(DateTime.utc(earlier.year, earlier.month, earlier.day))
          .inDays;

  /// 하루 무게 > 0인 날의 연속 개수(정수).
  ///
  /// 오늘 기록이 없으면 어제부터 센다 — 아침에 앱을 열었다고 어제까지 쌓은 스트릭이
  /// 0으로 보이면 안 된다. 오늘도 어제도 없으면 0이다.
  int currentStreak({String profileId = defaultProfileId}) {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    // 달이 바뀌는 지점에서 버킷을 다시 읽지 않도록 캐시한다.
    final cache = <String, Map<DateTime, double>>{};
    double weightOf(DateTime day) {
      final k = monthKey(profileId, day);
      final m = cache[k] ??= monthDayWeights(day, profileId: profileId);
      return m[day] ?? 0.0;
    }

    var cursor = today;
    if (weightOf(today) == 0.0) {
      if (weightOf(yesterday) == 0.0) return 0;
      cursor = yesterday;
    }

    var n = 0;
    while (weightOf(cursor) > 0.0) {
      n++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return n;
  }

  List<SessionRecord> _read(String key) {
    final raw = _store.read(key);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list;
    try {
      list = jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      // 버킷 전체가 깨졌다(JSON 파싱 불가). 앱은 죽지 않고 빈 목록으로 연다.
      logger.w('StudyHistoryService._read($key) not a JSON list: $e');
      return [];
    }
    // 레코드 단위로 관용한다: 한 건이 깨져도 그달의 유효 기록은 보존한다.
    // (버킷 전체를 버리면 다음 recordStudy가 한 달치 이력을 영구히 덮어쓴다.)
    final out = <SessionRecord>[];
    for (final e in list) {
      try {
        out.add(SessionRecord.fromJson(e as Map<String, dynamic>));
      } catch (e) {
        logger.w('StudyHistoryService._read($key) skipped bad record: $e');
      }
    }
    return out;
  }
}

/// 앱(SharedPreferences)에 배선된 [StudyHistoryService].
///
/// 스토어 읽기가 동기라 로드된 prefs가 필요하므로 FutureProvider로 감싼다.
final studyHistoryServiceProvider =
    FutureProvider<StudyHistoryService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return StudyHistoryService(SharedPreferencesStudyHistoryStore(prefs));
});
