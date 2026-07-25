// 알림 권한 프라이밍 정책 테스트.
//
// 파생 앱 수렴: voice-alarm은 소프트 사전질문 게이트(설명이 OS 프롬프트에 선행)를,
// hanja/kanken은 "한 번만 묻는다"(reminderPromptShown) 플래그를 각자 만들었다.
// 이 코어는 그 둘의 합성 — 순수 decidePriming이 상태로부터 다음 행동을 결정하고
// (어떤 앱에도 없던 순수 함수), 컨트롤러는 클라이언트/스토어/사전질문 UI를 엮는다.
// iOS 프롬프트는 원샷이라, 리스케줄 같은 배경 경로에서 태우지 않는 게 핵심.

import 'dart:async';

import 'package:pipecheck/core/services/permission/notification_priming.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClient implements NotificationPermissionClient {
  _FakeClient({
    this.granted = false,
    this.permanentlyDenied = false,
    this.grantedAfterRequest = false,
  });

  bool granted;
  bool permanentlyDenied;
  bool grantedAfterRequest;

  int requestCount = 0;
  int settingsCount = 0;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<bool> isPermanentlyDenied() async => permanentlyDenied;

  @override
  Future<bool> requestAndRecheck() async {
    requestCount++;
    granted = grantedAfterRequest;
    return grantedAfterRequest;
  }

  @override
  Future<void> openAppSettings() async {
    settingsCount++;
  }
}

class _FakeStore implements PrimingFlagStore {
  _FakeStore([this._asked = false]);
  bool _asked;
  int markCount = 0;

  @override
  Future<bool> hasAskedBefore() async => _asked;

  @override
  Future<void> markAsked() async {
    _asked = true;
    markCount++;
  }
}

void main() {
  group('decidePriming — 순수 결정 (합성 정책)', () {
    test('이미 허용 → 아무것도 안 함', () {
      expect(decidePriming(const PrimingState(isGranted: true)),
          PrimingDecision.doNothing);
    });

    test('영구 거부 → 설정으로', () {
      expect(
        decidePriming(const PrimingState(
            isGranted: false, isPermanentlyDenied: true)),
        PrimingDecision.openSettings,
      );
    });

    test('이미 물었고 미허용 → 아무것도 안 함 (한 번만 규칙)', () {
      expect(
        decidePriming(
            const PrimingState(isGranted: false, hasAskedBefore: true)),
        PrimingDecision.doNothing,
      );
    });

    test('신선(미허용·미영구거부·안 물음) → 사전질문 표시', () {
      expect(decidePriming(const PrimingState(isGranted: false)),
          PrimingDecision.showRationale);
    });

    test('허용이 영구거부보다 우선', () {
      expect(
        decidePriming(const PrimingState(
            isGranted: true, isPermanentlyDenied: true)),
        PrimingDecision.doNothing,
      );
    });

    test('영구거부가 "이미 물음"보다 우선', () {
      expect(
        decidePriming(const PrimingState(
            isGranted: false,
            isPermanentlyDenied: true,
            hasAskedBefore: true)),
        PrimingDecision.openSettings,
      );
    });

    test('허용이 "이미 물음"보다 우선 (granted+asked)', () {
      expect(
        decidePriming(
            const PrimingState(isGranted: true, hasAskedBefore: true)),
        PrimingDecision.doNothing,
      );
    });
  });

  group('NotificationPrimingController.ensure — 흐름 (fake)', () {
    Future<bool?> accept() async => true;
    Future<bool?> decline() async => false;
    Future<bool?> dismiss() async => null;

    test('이미 허용: 사전질문·프롬프트·마킹 없이 granted', () async {
      final client = _FakeClient(granted: true);
      final store = _FakeStore();
      var shown = 0;
      final r = await NotificationPrimingController(client: client, store: store)
          .ensure(showRationale: () async {
        shown++;
        return true;
      });
      expect(r, NotificationGateResult.granted);
      expect(shown, 0);
      expect(client.requestCount, 0);
      expect(store.markCount, 0); // 사전질문 안 냈으면 마킹 안 함 (불변식 음성면)
    });

    test('신선 + 수락 + 허용됨 → granted, 프롬프트 1회, asked 마킹', () async {
      final client = _FakeClient(grantedAfterRequest: true);
      final store = _FakeStore();
      final r = await NotificationPrimingController(client: client, store: store)
          .ensure(showRationale: accept);
      expect(r, NotificationGateResult.granted);
      expect(client.requestCount, 1);
      expect(store.markCount, 1);
    });

    test('신선 + 거절 → denied, 프롬프트 안 태움, asked 마킹', () async {
      final client = _FakeClient();
      final store = _FakeStore();
      final r = await NotificationPrimingController(client: client, store: store)
          .ensure(showRationale: decline);
      expect(r, NotificationGateResult.denied);
      expect(client.requestCount, 0); // iOS 원샷 보존
      expect(store.markCount, 1);
    });

    test('닫음(null)도 거절로 취급', () async {
      final client = _FakeClient();
      final store = _FakeStore();
      final r = await NotificationPrimingController(client: client, store: store)
          .ensure(showRationale: dismiss);
      expect(r, NotificationGateResult.denied);
      expect(client.requestCount, 0);
    });

    test('이미 물음 + 미허용 → 사전질문·마킹 없이 denied (배경 경로 보호)', () async {
      final client = _FakeClient();
      final store = _FakeStore(true); // asked before
      var shown = 0;
      final r = await NotificationPrimingController(client: client, store: store)
          .ensure(showRationale: () async {
        shown++;
        return true;
      });
      expect(r, NotificationGateResult.denied);
      expect(shown, 0);
      expect(client.requestCount, 0);
      expect(store.markCount, 0); // 이미 물음 경로는 재마킹 안 함
    });

    test('영구 거부(기본): 자동 이동 없이 settingsRequired (배경 안전)', () async {
      final client = _FakeClient(permanentlyDenied: true);
      final store = _FakeStore();
      var shown = 0;
      final r = await NotificationPrimingController(client: client, store: store)
          .ensure(showRationale: () async {
        shown++;
        return true;
      });
      expect(r, NotificationGateResult.settingsRequired);
      expect(client.settingsCount, 0); // 기본은 이동 안 함
      expect(shown, 0);
      expect(store.markCount, 0);
    });

    test('영구 거부 + redirectToSettings:true → 설정 이동', () async {
      final client = _FakeClient(permanentlyDenied: true);
      final store = _FakeStore();
      final r = await NotificationPrimingController(client: client, store: store)
          .ensure(showRationale: accept, redirectToSettings: true);
      expect(r, NotificationGateResult.settingsRequired);
      expect(client.settingsCount, 1); // 사용자-개시 맥락에서만 이동
    });

    test('수락했지만 재확인 여전히 미허용 → denied', () async {
      final client = _FakeClient(grantedAfterRequest: false);
      final store = _FakeStore();
      final r = await NotificationPrimingController(client: client, store: store)
          .ensure(showRationale: accept);
      expect(r, NotificationGateResult.denied);
      expect(client.requestCount, 1);
    });

    test('재진입 가드: 동시 ensure()는 사전질문·프롬프트를 한 번만', () async {
      final client = _FakeClient(grantedAfterRequest: true);
      final store = _FakeStore();
      var shown = 0;
      final completer = Completer<bool?>();
      final ctrl = NotificationPrimingController(client: client, store: store);
      Future<bool?> slowRationale() async {
        shown++;
        return completer.future; // 첫 호출이 진행 중인 동안 두 번째가 들어옴
      }

      final f1 = ctrl.ensure(showRationale: slowRationale);
      final f2 = ctrl.ensure(showRationale: slowRationale);
      completer.complete(true);
      final r1 = await f1;
      final r2 = await f2;

      expect(shown, 1); // 사전질문 한 번만
      expect(client.requestCount, 1); // 프롬프트 한 번만
      expect(r1, NotificationGateResult.granted);
      expect(r2, NotificationGateResult.granted); // 두 호출 같은 결과 공유
    });
  });
}
