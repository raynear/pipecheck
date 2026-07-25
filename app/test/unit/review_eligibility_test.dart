// 리뷰 프롬프트 적격 게이트 테스트 (WS-C — 파생 앱 kanken·hanja·flowmodoro·voca
// 수렴). 스토어 평점을 보호하려면 프롬프트를 만족·몰입 사용자에게만, 충분한
// 쿨다운 뒤에만 낸다. 순수 함수라 플러그인/시계 없이 검증한다.

import 'package:boilerplate/core/services/review/review_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 15, 12);
  DateTime daysAgo(int d) => now.subtract(Duration(days: d));

  ReviewGateState state({
    bool completed = false,
    DateTime? dismissedAt,
    DateTime? negativeFeedbackAt,
    DateTime? installedAt,
  }) =>
      ReviewGateState(
        completed: completed,
        dismissedAt: dismissedAt,
        negativeFeedbackAt: negativeFeedbackAt,
        installedAt: installedAt,
      );

  group('isReviewEligible', () {
    test('모든 조건 통과 + engaged → true', () {
      expect(
        isReviewEligible(state(installedAt: daysAgo(30)),
            engaged: true, now: now),
        true,
      );
    });

    test('이미 완료(latch) → 항상 false', () {
      expect(
        isReviewEligible(state(completed: true, installedAt: daysAgo(365)),
            engaged: true, now: now),
        false,
      );
    });

    test('engaged=false → false (불만족/저몰입 사용자 프롬프트 금지)', () {
      expect(
        isReviewEligible(state(installedAt: daysAgo(30)),
            engaged: false, now: now),
        false,
      );
    });

    group('부정 피드백 쿨다운(기본 90일)', () {
      test('89일 전 → false', () {
        expect(
          isReviewEligible(
              state(installedAt: daysAgo(365), negativeFeedbackAt: daysAgo(89)),
              engaged: true,
              now: now),
          false,
        );
      });
      test('90일 경과 → true(정확히 경계는 통과)', () {
        expect(
          isReviewEligible(
              state(installedAt: daysAgo(365), negativeFeedbackAt: daysAgo(90)),
              engaged: true,
              now: now),
          true,
        );
      });
    });

    group('거절 쿨다운(기본 30일)', () {
      test('29일 전 → false', () {
        expect(
          isReviewEligible(
              state(installedAt: daysAgo(365), dismissedAt: daysAgo(29)),
              engaged: true,
              now: now),
          false,
        );
      });
      test('30일 경과 → true', () {
        expect(
          isReviewEligible(
              state(installedAt: daysAgo(365), dismissedAt: daysAgo(30)),
              engaged: true,
              now: now),
          true,
        );
      });
    });

    group('설치 후 최소 경과일(기본 7일)', () {
      test('6일 전 설치 → false', () {
        expect(
          isReviewEligible(state(installedAt: daysAgo(6)),
              engaged: true, now: now),
          false,
        );
      });
      test('7일 경과 → true', () {
        expect(
          isReviewEligible(state(installedAt: daysAgo(7)),
              engaged: true, now: now),
          true,
        );
      });
      test('installedAt 미제공 → 설치일 게이트 없음(통과)', () {
        expect(
          isReviewEligible(state(), engaged: true, now: now),
          true,
        );
      });
    });

    test('커스텀 임계값 적용', () {
      // dismiss 쿨다운을 7일로 줄이면 10일 전 거절은 통과.
      expect(
        isReviewEligible(
            state(installedAt: daysAgo(365), dismissedAt: daysAgo(10)),
            engaged: true,
            now: now,
            dismissCooldownDays: 7),
        true,
      );
    });

    test('여러 쿨다운이 겹치면 하나라도 걸리면 false', () {
      expect(
        isReviewEligible(
            state(
                installedAt: daysAgo(365),
                dismissedAt: daysAgo(100),
                negativeFeedbackAt: daysAgo(10)),
            engaged: true,
            now: now),
        false, // 거절은 지났지만 부정 피드백 10일 전 → 걸림
      );
    });
  });

  group('outcomeForSentiment — 평점 보호 불변식', () {
    test('긍정 → 스토어 리뷰 + 완료', () {
      expect(outcomeForSentiment(ReviewSentiment.positive),
          SentimentOutcome.storeReviewAndComplete);
    });

    test('부정 → 완료 래치 없이 피드백 우회(스토어로 안 보냄)', () {
      final o = outcomeForSentiment(ReviewSentiment.negative);
      expect(o, SentimentOutcome.recordNegativeAndFeedback);
      expect(o, isNot(SentimentOutcome.storeReviewAndComplete)); // 절대 래치/스토어 금지
    });

    test('닫음(null) → 거절 쿨다운(완료·부정 아님)', () {
      expect(outcomeForSentiment(null), SentimentOutcome.recordDismiss);
    });
  });
}
