// DeepLinkService(fake AppLinks) + PendingDeepLink 보류 슬롯.
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipecheck/core/services/deep_link_service.dart';

class _FakeAppLinks implements AppLinks {
  _FakeAppLinks({this.initial, this.initialError});
  final Uri? initial;
  final Object? initialError;
  final controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async {
    if (initialError != null) throw initialError!;
    return initial;
  }

  @override
  Stream<Uri> get uriLinkStream => controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DeepLinkService', () {
    test('콜드 링크를 먼저 전달하고 이어서 웜 링크 스트림을 구독한다', () async {
      final links = _FakeAppLinks(initial: Uri.parse('myapp://open/settings'));
      final got = <Uri>[];
      final svc = DeepLinkService(onUri: got.add, appLinks: links);
      await svc.start();
      expect(got.map((u) => u.path), ['/settings']);

      links.controller.add(Uri.parse('myapp://open/stats'));
      await Future<void>.delayed(Duration.zero);
      expect(got.map((u) => u.path), ['/settings', '/stats']);
      svc.dispose();
    });

    test('콜드 링크가 없거나 조회가 던져도 웜 링크는 계속 받는다', () async {
      final links = _FakeAppLinks(initialError: StateError('boom'));
      final got = <Uri>[];
      final svc = DeepLinkService(onUri: got.add, appLinks: links);
      await svc.start();
      links.controller.add(Uri.parse('myapp://open/stats'));
      await Future<void>.delayed(Duration.zero);
      expect(got, hasLength(1));
      svc.dispose();
    });

    test('start 재진입은 중복 구독하지 않고, dispose 뒤엔 전달이 멈춘다', () async {
      final links = _FakeAppLinks();
      final got = <Uri>[];
      final svc = DeepLinkService(onUri: got.add, appLinks: links);
      await svc.start();
      await svc.start();
      links.controller.add(Uri.parse('myapp://open/stats'));
      await Future<void>.delayed(Duration.zero);
      expect(got, hasLength(1));

      svc.dispose();
      links.controller.add(Uri.parse('myapp://open/stats'));
      await Future<void>.delayed(Duration.zero);
      expect(got, hasLength(1));
    });
  });

  group('PendingDeepLink', () {
    setUp(PendingDeepLink.reset);
    tearDown(PendingDeepLink.reset);

    test('준비 전엔 보관하고 마지막 것만 남긴다 / 준비 뒤엔 즉시 통과', () {
      expect(PendingDeepLink.offer('/a'), isNull);
      expect(PendingDeepLink.offer('/b'), isNull);
      expect(PendingDeepLink.markReady(), '/b');
      expect(PendingDeepLink.markReady(), isNull, reason: '한 번 꺼내면 비워진다');
      expect(PendingDeepLink.offer('/c'), '/c');
    });

    test('잠금 해제 보류: 있으면 그곳, 없으면 fallback, 한 번만', () {
      expect(PendingDeepLink.takeAfterUnlock('/home'), '/home');
      PendingDeepLink.holdForUnlock('/settings');
      expect(PendingDeepLink.takeAfterUnlock('/home'), '/settings');
      expect(PendingDeepLink.takeAfterUnlock('/home'), '/home');
    });

    test('peekAfterUnlock은 꺼내지 않고 본다', () {
      expect(PendingDeepLink.peekAfterUnlock(), isNull);
      PendingDeepLink.holdForUnlock('/settings');
      expect(PendingDeepLink.peekAfterUnlock(), '/settings');
      expect(PendingDeepLink.takeAfterUnlock('/home'), '/settings');
    });
  });
}
