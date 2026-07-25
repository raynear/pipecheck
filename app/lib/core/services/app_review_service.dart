import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utils/utils.dart';

import 'review/review_eligibility.dart';

export 'review/review_eligibility.dart' show ReviewSentiment, ReviewGateState;

/// Keys for SharedPreferences storage
const String _keyReviewRequestCount = 'app_review_request_count';
const String _keyLastReviewDate = 'app_review_last_date';
const String _keySessionCount = 'app_review_session_count';

/// 감정 게이트 상태 키 (WS-C).
const String _keyReviewCompleted = 'app_review_completed';
const String _keyReviewDismissedAt = 'app_review_dismissed_at';
const String _keyReviewNegativeAt = 'app_review_negative_at';

/// Service for managing in-app review requests
///
/// Wraps the `in_app_review` package with session tracking and
/// rate-limiting logic so review prompts are shown at appropriate times.
class AppReviewService {
  final InAppReview _inAppReview;

  AppReviewService({InAppReview? inAppReview})
      : _inAppReview = inAppReview ?? InAppReview.instance;

  /// Request an in-app review if the platform supports it
  ///
  /// Returns true if the review dialog was requested, false otherwise.
  Future<bool> requestReview() async {
    try {
      final isAvailable = await _inAppReview.isAvailable();
      if (!isAvailable) {
        logger.d('AppReviewService: in-app review not available');
        return false;
      }

      await _inAppReview.requestReview();
      await _recordReviewRequest();
      logger.d('AppReviewService: review requested successfully');
      return true;
    } catch (e) {
      logger.e('AppReviewService: failed to request review: $e');
      return false;
    }
  }

  /// Check whether conditions are met to request a review
  ///
  /// [minSessions] - minimum number of sessions before first prompt (default: 5)
  /// [daysBetweenRequests] - minimum days between review prompts (default: 90)
  Future<bool> shouldRequestReview({
    int minSessions = 5,
    int daysBetweenRequests = 90,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final sessionCount = prefs.getInt(_keySessionCount) ?? 0;
      if (sessionCount < minSessions) {
        logger.d(
          'AppReviewService: not enough sessions '
          '($sessionCount < $minSessions)',
        );
        return false;
      }

      final lastDateStr = prefs.getString(_keyLastReviewDate);
      if (lastDateStr != null) {
        final lastDate = DateTime.tryParse(lastDateStr);
        if (lastDate != null) {
          final daysSinceLastRequest =
              DateTime.now().difference(lastDate).inDays;
          if (daysSinceLastRequest < daysBetweenRequests) {
            logger.d(
              'AppReviewService: too soon since last request '
              '($daysSinceLastRequest < $daysBetweenRequests days)',
            );
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      logger.e('AppReviewService: shouldRequestReview failed: $e');
      return false;
    }
  }

  /// Increment the session counter
  ///
  /// Call this at app startup to track how many times the user has opened
  /// the app before prompting for a review.
  Future<void> incrementSessionCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_keySessionCount) ?? 0;
      await prefs.setInt(_keySessionCount, current + 1);
      logger.d('AppReviewService: session count incremented to ${current + 1}');
    } catch (e) {
      logger.e('AppReviewService: failed to increment session count: $e');
    }
  }

  // ===========================================================================
  // 감정 게이트 리뷰 플로우 (WS-C — 파생 앱 kanken·hanja·flowmodoro·voca 수렴)
  //
  // 위의 shouldRequestReview(세션수·시간축)와 달리 스토어 평점을 **보호**한다:
  // 만족·몰입 사용자에게만(injectable [engaged]), 충분한 쿨다운 뒤에만 프롬프트하고,
  // Android에선 감정 사전 체크로 불만족 사용자를 스토어 대신 피드백으로 우회시킨다.
  // 적격 판단은 순수 [isReviewEligible]에 있고(테스트됨), 다이얼로그 UI/카피/피드백
  // 목적지는 호출자가 콜백으로 주입한다.
  // ===========================================================================

  /// 영속 게이트 상태를 읽는다. [installedAt]는 앱이 아는 설치/첫실행 시각(선택).
  Future<ReviewGateState> loadGateState({DateTime? installedAt}) async {
    final prefs = await SharedPreferences.getInstance();
    DateTime? at(String key) {
      final raw = prefs.getString(key);
      return raw == null ? null : DateTime.tryParse(raw);
    }

    return ReviewGateState(
      completed: prefs.getBool(_keyReviewCompleted) ?? false,
      dismissedAt: at(_keyReviewDismissedAt),
      negativeFeedbackAt: at(_keyReviewNegativeAt),
      installedAt: installedAt,
    );
  }

  /// 지금 감정 게이트 프롬프트를 낼 수 있는가. [engaged]는 앱이 계산한 만족/몰입
  /// 신호(예: `streak >= 3 || isPremium`). 임계값은 [isReviewEligible] 기본값
  /// (설치 7일 / 거절 30일 / 부정 90일) — 커스텀이 필요하면 순수 게이트를 직접 쓴다.
  ///
  /// 형제 [shouldRequestReview]처럼 fail-closed: 저장소 오류 시 false(프롬프트 안 함).
  Future<bool> isEligible({
    required bool engaged,
    DateTime? installedAt,
  }) async {
    try {
      final state = await loadGateState(installedAt: installedAt);
      return isReviewEligible(state, engaged: engaged, now: DateTime.now());
    } catch (e) {
      logger.e('AppReviewService: isEligible failed: $e');
      return false;
    }
  }

  /// 리뷰를 완료(또는 스토어로 보냄)로 래치 — 다시 묻지 않는다.
  Future<void> markCompleted() => _setBool(_keyReviewCompleted, true);

  /// 프롬프트 거절 기록 → 거절 쿨다운(기본 30일) 시작.
  Future<void> recordDismiss() => _setNow(_keyReviewDismissedAt);

  /// 부정 피드백 기록 → 더 긴 쿨다운(기본 90일) 시작.
  Future<void> recordNegativeFeedback() => _setNow(_keyReviewNegativeAt);

  /// 감정 게이트 리뷰 플로우를 돌린다.
  ///
  /// 적격이 아니면 아무것도 하지 않는다. 적격이면:
  /// - iOS: Apple 가이드라인대로 시스템 리뷰 다이얼로그를 바로 띄운다.
  /// - Android: [askSentiment]로 "도움이 되나요?"를 먼저 묻고 [outcomeForSentiment]
  ///   대로 — 긍정 → 스토어 리뷰 / 부정 → 90일 쿨다운 + [openFeedback] / 닫음 →
  ///   30일 거절 쿨다운.
  ///
  /// **완료 래치는 리뷰가 실제로 표시됐을 때만** 찍는다([requestReview]가 true를
  /// 반환한 경우) — 미표시(플러그인 미가용 등)에 래치하면 그 사용자를 영원히
  /// 다시 못 묻는다. [askSentiment]/[openFeedback]는 앱 UI다(카피·네비 앱 소유).
  Future<void> requestReviewFlow({
    required bool engaged,
    required Future<ReviewSentiment?> Function() askSentiment,
    Future<void> Function()? openFeedback,
    DateTime? installedAt,
  }) async {
    if (!await isEligible(engaged: engaged, installedAt: installedAt)) return;

    if (Platform.isIOS) {
      await _requestStoreReviewAndLatch();
      return;
    }

    switch (outcomeForSentiment(await askSentiment())) {
      case SentimentOutcome.storeReviewAndComplete:
        await _requestStoreReviewAndLatch();
      case SentimentOutcome.recordNegativeAndFeedback:
        await recordNegativeFeedback();
        if (openFeedback != null) await openFeedback();
      case SentimentOutcome.recordDismiss:
        await recordDismiss();
    }
  }

  /// 스토어 리뷰를 요청하고, **실제 표시됐을 때만** 완료 래치.
  Future<void> _requestStoreReviewAndLatch() async {
    if (await requestReview()) await markCompleted();
  }

  Future<void> _setBool(String key, bool value) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(key, value);
    } catch (e) {
      logger.e('AppReviewService: failed to set $key: $e');
    }
  }

  Future<void> _setNow(String key) async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(key, DateTime.now().toIso8601String());
    } catch (e) {
      logger.e('AppReviewService: failed to set $key: $e');
    }
  }

  /// Record that a review request was made
  Future<void> _recordReviewRequest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_keyReviewRequestCount) ?? 0;
      await prefs.setInt(_keyReviewRequestCount, current + 1);
      await prefs.setString(
        _keyLastReviewDate,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      logger.e('AppReviewService: failed to record review request: $e');
    }
  }
}

/// Provider for AppReviewService
final appReviewServiceProvider = Provider<AppReviewService>((ref) {
  return AppReviewService();
});
