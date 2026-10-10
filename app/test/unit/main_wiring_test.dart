// main.dart 배선: 알림 탭·딥링크가 보류 슬롯을 거치는지(H6/N1/N4), app_start 순서(C1),
// 생명주기→앱 잠금(M1).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipecheck/core/services/deep_link_service.dart';
import 'package:pipecheck/core/state/auth_state.dart';
import 'package:pipecheck/main.dart';

class _RecordingAuth extends AuthStateNotifier {
  final calls = <String>[];
  @override
  void markBackgrounded({DateTime? now}) => calls.add('bg');
  @override
  bool relockIfBackgroundedLongerThan({Duration grace = kRelockGrace, DateTime? now}) {
    calls.add('relock');
    return false;
  }
}

void main() {
  setUp(PendingDeepLink.reset);
  tearDown(PendingDeepLink.reset);

  group('알림 탭 (N1)', () {
    test('콜드 스타트(스플래시 전) 탭은 이동하지 않고 보관한다', () {
      final went = <String>[];
      navigateFromNotification('/settings', went.add);
      expect(went, isEmpty);
      expect(PendingDeepLink.markReady(), '/settings');
    });

    test('웜 상태(스플래시 뒤) 탭은 즉시 이동한다', () {
      PendingDeepLink.markReady();
      final went = <String>[];
      navigateFromNotification('/settings', went.add);
      expect(went, ['/settings']);
    });
  });

  group('딥링크 핸들러 (N4)', () {
    test('화이트리스트 링크는 deepLinkLocation을 거쳐 보류/이동한다', () {
      final went = <String>[];
      navigateFromDeepLink(Uri.parse('myapp://open/settings'), went.add);
      expect(went, isEmpty);
      expect(PendingDeepLink.markReady(), '/settings');
      navigateFromDeepLink(Uri.parse('myapp://open/stats?x=1'), went.add);
      expect(went, ['/stats?x=1']);
    });

    test('판정 함수가 거른 링크(하위 경로·미등록)는 보류도 이동도 없다', () {
      PendingDeepLink.markReady();
      final went = <String>[];
      navigateFromDeepLink(Uri.parse('myapp://open/settings/pin'), went.add);
      navigateFromDeepLink(Uri.parse('myapp://open/hack'), went.add);
      expect(went, isEmpty);
    });
  });

  test('C1: app_start는 동의 적용이 끝나기 전엔 나가지 않는다', () async {
    final consent = Completer<void>();
    var sent = 0;
    final f = sendAppStartAfterConsent(
      consentApplied: consent.future,
      log: () => sent++,
    );
    await Future<void>.delayed(Duration.zero);
    expect(sent, 0);
    consent.complete();
    await f;
    expect(sent, 1);
  });

  test('M1: paused는 기록, resumed는 재잠금 시도 — 그 외 상태는 무시', () {
    final auth = _RecordingAuth();
    final container = ProviderContainer(
      overrides: [authStateProvider.overrideWith(() => auth)],
    );
    addTearDown(container.dispose);
    final n = container.read(authStateProvider.notifier) as _RecordingAuth;
    applyLockLifecycle(AppLifecycleState.inactive, n);
    applyLockLifecycle(AppLifecycleState.paused, n);
    applyLockLifecycle(AppLifecycleState.resumed, n);
    expect(n.calls, ['bg', 'relock']);
  });
}
