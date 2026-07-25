// 인앱 리뷰 프롬프트의 적격 판단 (WS-C — 파생 앱 kanken·hanja·flowmodoro·voca 수렴).
//
// 스토어 평점을 지키려면 프롬프트를 아무에게나 내지 않는다: 만족·몰입한 사용자에게만,
// 충분한 쿨다운 뒤에만 낸다. 여기 있는 건 순수 결정 로직 — 시계·저장소·플랫폼에
// 의존하지 않아 완전히 단위 테스트된다(상태는 [ReviewGateState]로 주입).

/// 감정 사전 체크 응답.
enum ReviewSentiment { positive, negative }

/// 감정 응답(또는 닫음)에 따른 후속 동작(순수).
///
/// 평점 보호 불변식을 테스트 가능하게 못박는다: **부정은 절대 완료 래치하지 않고**
/// 피드백으로 우회하며, 닫음은 짧은 거절 쿨다운, 긍정만 스토어로 보낸다.
enum SentimentOutcome {
  /// 스토어 리뷰 요청 + (실제 표시됐으면) 완료 래치.
  storeReviewAndComplete,

  /// 부정 피드백 쿨다운(기본 90일) 기록 + 피드백 경로로 우회.
  recordNegativeAndFeedback,

  /// 거절 쿨다운(기본 30일) 기록.
  recordDismiss,
}

/// 감정 응답 → 후속 동작(순수). `null`(다이얼로그 닫음) = 거절.
SentimentOutcome outcomeForSentiment(ReviewSentiment? sentiment) =>
    switch (sentiment) {
      ReviewSentiment.positive => SentimentOutcome.storeReviewAndComplete,
      ReviewSentiment.negative => SentimentOutcome.recordNegativeAndFeedback,
      null => SentimentOutcome.recordDismiss,
    };

/// 리뷰 게이트의 영속 상태 스냅샷(SharedPreferences 등에서 읽어 주입).
class ReviewGateState {
  const ReviewGateState({
    this.completed = false,
    this.dismissedAt,
    this.negativeFeedbackAt,
    this.installedAt,
  });

  /// 리뷰를 이미 완료(또는 스토어로 보냄) — 다시 묻지 않는다.
  final bool completed;

  /// 마지막으로 프롬프트를 닫은(거절) 시각.
  final DateTime? dismissedAt;

  /// 마지막으로 부정 피드백을 남긴 시각(더 긴 쿨다운).
  final DateTime? negativeFeedbackAt;

  /// 설치(또는 첫 실행) 시각. null이면 설치일 게이트를 적용하지 않는다.
  final DateTime? installedAt;
}

/// 지금 리뷰 프롬프트를 낼 수 있는가(순수).
///
/// [engaged]는 앱이 계산한 "몰입/만족" 신호다(예: `streak >= 3 || isPremium`,
/// 최근 정답률 ≥ 60%). 도메인 지표를 서비스에서 떼어내 호출자가 주입하므로
/// 학습앱·타이머·습관앱 어디에도 맞출 수 있다.
///
/// 다음 중 하나라도 걸리면 false: 이미 완료(latch) / 부정 피드백 쿨다운
/// (기본 90일) / 거절 쿨다운(기본 30일) / 설치 후 최소 경과일(기본 7일) 미만 /
/// [engaged]가 아님. 쿨다운은 "경과 시간"이므로 경계값(정확히 N일)은 통과다.
bool isReviewEligible(
  ReviewGateState s, {
  required bool engaged,
  required DateTime now,
  int minDaysAfterInstall = 7,
  int dismissCooldownDays = 30,
  int negativeCooldownDays = 90,
}) {
  if (s.completed) return false;

  final neg = s.negativeFeedbackAt;
  if (neg != null && now.difference(neg).inDays < negativeCooldownDays) {
    return false;
  }

  final dismissed = s.dismissedAt;
  if (dismissed != null &&
      now.difference(dismissed).inDays < dismissCooldownDays) {
    return false;
  }

  final installed = s.installedAt;
  if (installed != null &&
      now.difference(installed).inDays < minDaysAfterInstall) {
    return false;
  }

  return engaged;
}
