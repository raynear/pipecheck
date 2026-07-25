// 알림 권한 프라이밍 정책 — 순수 결정 + 플러그인 비의존 컨트롤러.
//
// 파생 앱 수렴: voice-alarm은 소프트 사전질문 게이트(설명이 OS 프롬프트에 **선행**)를,
// hanja/kanken은 "한 번만 묻는다" 플래그를 각자 재발명했다. 이 코어는 그 둘의 합성이다.
// iOS 알림 프롬프트는 **원샷**(한 번 뜨면 다시 안 뜸)이라, 리스케줄 같은 배경 경로에서
// 태우면 가치를 보여주기도 전에 소진된다 — 그래서 "peek(안 물음) vs request(물음)"를
// 타입으로 분리하고, 신선 사용자에게만 사전질문 뒤 프롬프트한다.
//
// UI(사전질문 다이얼로그 카피·아이콘)와 네비게이션은 앱이 소유한다 — 코어는 카피를
// 갖지 않고 [showRationale] 콜백으로 주입받는다.

/// 현재 권한 상태의 순수 스냅샷.
class PrimingState {
  const PrimingState({
    required this.isGranted,
    this.isPermanentlyDenied = false,
    this.hasAskedBefore = false,
  });

  /// 라이브 peek 결과(프롬프트 없이 조회).
  final bool isGranted;

  /// OS가 영구 거부로 표시(다시 프롬프트 불가 → 설정으로 보내야).
  final bool isPermanentlyDenied;

  /// 과거에 한 번이라도 프롬프트/사전질문을 낸 적 있음(한 번만 규칙).
  final bool hasAskedBefore;
}

/// 상태로부터 결정되는 다음 행동.
enum PrimingDecision { doNothing, showRationale, openSettings }

/// PURE. 상태 → 다음 행동. (파생 앱 어디에도 없던 순수 함수 — voice-alarm의 소프트
/// 게이트 + hanja/kanken의 한 번만 규칙을 합성.)
///
/// 우선순위: 허용 → 영구거부 → 이미 물음 → 신선. 즉 이미 허용이면 아무것도 안 하고,
/// 영구거부면 설정으로, 이미 물었는데 미허용이면 (배경 경로에서 조르지 않도록) 아무것도
/// 안 하며, 그 외 신선 사용자에게만 사전질문을 낸다(수락 시 컨트롤러가 프롬프트).
PrimingDecision decidePriming(PrimingState s) {
  if (s.isGranted) return PrimingDecision.doNothing;
  if (s.isPermanentlyDenied) return PrimingDecision.openSettings;
  if (s.hasAskedBefore) return PrimingDecision.doNothing;
  return PrimingDecision.showRationale;
}

/// 게이트 종료 결과. [settingsRequired]는 영구 거부라 앱 내에서 프롬프트 불가 →
/// 사용자를 설정으로 보내야 하는 상태(컨트롤러는 기본적으로 자동 이동하지 않는다).
enum NotificationGateResult { granted, denied, settingsRequired }

/// 권한 플러그인 추상화 — "어떻게" 묻고 조회하나를 감춘다. **기본 구현은 동봉하지
/// 않는다**: 앱이 자신의 알림 플러그인(보일러플레이트 notifications 패키지의
/// awesome_notifications, 또는 permission_handler) 위에 구현한다 — 알림 권한 경로를
/// 하나로 유지해 중복/분기를 피하려는 의도.
///
/// **peek/prompt 분리가 핵심**: [isGranted]/[isPermanentlyDenied]는 조회만(절대 다이얼로그
/// 금지 — 리스케줄 안전 경로), [requestAndRecheck]만 OS 프롬프트를 띄운다(iOS 원샷 소비).
abstract class NotificationPermissionClient {
  /// READ-ONLY peek — OS 다이얼로그/설정을 절대 띄우지 않는다.
  Future<bool> isGranted();

  /// READ-ONLY peek — 영구 거부 여부.
  Future<bool> isPermanentlyDenied();

  /// OS 프롬프트를 띄우고(원샷 소비) 재조회한 허용 여부를 반환. 사용자가 사전질문을
  /// 수락한 뒤에만 호출한다(설명이 프롬프트에 선행).
  Future<bool> requestAndRecheck();

  /// 앱 설정 화면을 연다(영구 거부 복구 경로).
  Future<void> openAppSettings();
}

/// "한 번만 묻는다" 플래그의 영속 저장(hanja/kanken reminderPromptShown). 앱이
/// SharedPreferences 등으로 구현.
abstract class PrimingFlagStore {
  Future<bool> hasAskedBefore();
  Future<void> markAsked();
}

/// 프라이밍 흐름을 엮는다: 상태 조회 → [decidePriming] → 행동. 플러그인·저장·사전질문
/// UI를 주입받아 순수 로직만 담아 테스트 가능(BuildContext 비의존).
class NotificationPrimingController {
  NotificationPrimingController({required this.client, required this.store});

  final NotificationPermissionClient client;
  final PrimingFlagStore store;

  Future<NotificationGateResult>? _inFlight;

  /// 알림 권한을 (필요하면 사전질문 후) 확보한다.
  ///
  /// [showRationale]: 앱이 소유한 사전질문 UI를 띄우는 콜백 — `true`=수락,
  /// `false`/`null`=거절/닫음. 코어는 카피·네비를 갖지 않는다.
  ///
  /// [redirectToSettings]: 영구 거부 시 설정으로 **자동 이동**할지. 기본 false —
  /// ensure()는 배경/리스케줄 경로에서도 안전해야 하므로(설정 이동은 프롬프트보다
  /// 방해적) 기본적으로 이동하지 않고 [NotificationGateResult.settingsRequired]만
  /// 반환한다. 사용자-개시 맥락(설정 토글 등)에서만 true로 넘겨 이동을 허용한다.
  ///
  /// 사전질문을 낸 경우(수락이든 거절이든) "이미 물음"으로 마킹해 한 번만 조른다.
  /// 재진입 가드: 진행 중 호출이 있으면 그 결과를 공유해 다이얼로그/프롬프트가
  /// 겹치지 않게 한다.
  Future<NotificationGateResult> ensure({
    required Future<bool?> Function() showRationale,
    bool redirectToSettings = false,
  }) {
    return _inFlight ??= _run(
      showRationale: showRationale,
      redirectToSettings: redirectToSettings,
    ).whenComplete(() => _inFlight = null);
  }

  Future<NotificationGateResult> _run({
    required Future<bool?> Function() showRationale,
    required bool redirectToSettings,
  }) async {
    final state = PrimingState(
      isGranted: await client.isGranted(),
      isPermanentlyDenied: await client.isPermanentlyDenied(),
      hasAskedBefore: await store.hasAskedBefore(),
    );

    switch (decidePriming(state)) {
      case PrimingDecision.doNothing:
        return state.isGranted
            ? NotificationGateResult.granted
            : NotificationGateResult.denied;
      case PrimingDecision.openSettings:
        if (redirectToSettings) await client.openAppSettings();
        return NotificationGateResult.settingsRequired;
      case PrimingDecision.showRationale:
        final accepted = await showRationale();
        await store.markAsked();
        if (accepted == true) {
          return await client.requestAndRecheck()
              ? NotificationGateResult.granted
              : NotificationGateResult.denied;
        }
        return NotificationGateResult.denied;
    }
  }
}
