// PIN 설정/변경 플로우 테스트 (P2-23h ②).
//
// EasyLocalization 미초기화 → .tr()는 키를 그대로 반환. 검증은 PinService
// (인메모리 SecureStore)로 결정적으로 구성한다. PinSetupView는 라우터 없이
// 호스팅하므로 성공 시 pop은 생략되지만(canPop=false) setPin은 실행된다.

import 'package:pipecheck/core/services/pin_service.dart';
import 'package:pipecheck/core/services/secure_store.dart';
import 'package:pipecheck/features/auth/views/pin_setup_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeSecureStore implements SecureStore {
  final Map<String, String> map = {};
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String value) async => map[key] = value;
  @override
  Future<void> delete(String key) async => map.remove(key);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _pump(WidgetTester tester, PinService svc) async {
  // PinSetupView는 앱에서 항상 go_router 하위에서 열리므로 라우터로 호스팅한다
  // (context.canPop()은 GoRouter가 없으면 예외를 던진다). 단일 라우트라
  // canPop=false → 성공 시 pop은 생략되지만 setPin은 실행된다.
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const PinSetupView())],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [pinServiceProvider.overrideWithValue(svc)],
    child: MaterialApp.router(routerConfig: router),
  ));
  await _settle(tester);
}

Future<void> _enter(WidgetTester tester, String pin) async {
  await tester.enterText(find.byType(TextField).first, pin);
  await _settle(tester);
}

void main() {
  group('PIN 설정 (PIN 없음)', () {
    testWidgets('설정 제목 + 새 PIN 입력 단계로 시작', (tester) async {
      await _pump(tester, PinService(_FakeSecureStore()));
      expect(find.text('auth.pin.setupTitle'), findsOneWidget);
      expect(find.text('auth.pin.enterNew'), findsOneWidget);
    });

    testWidgets('새 PIN → 확인 일치 → 저장', (tester) async {
      final svc = PinService(_FakeSecureStore());
      await _pump(tester, svc);

      await _enter(tester, '111111'); // enterNew
      expect(find.text('auth.pin.confirmNew'), findsOneWidget);

      await _enter(tester, '111111'); // confirmNew (일치)
      expect(await svc.hasPin(), true);
      expect((await svc.verifyPin('111111')).isSuccess, true);
    });

    testWidgets('확인 불일치 → mismatch + 새 PIN 단계로 복귀', (tester) async {
      final svc = PinService(_FakeSecureStore());
      await _pump(tester, svc);

      await _enter(tester, '111111');
      await _enter(tester, '222222'); // 불일치

      expect(find.text('auth.pin.mismatch'), findsOneWidget);
      expect(find.text('auth.pin.enterNew'), findsOneWidget);
      expect(await svc.hasPin(), false);
    });
  });

  group('PIN 변경 (PIN 있음)', () {
    Future<PinService> withPin() async {
      final svc = PinService(_FakeSecureStore());
      await svc.setPin('123456');
      return svc;
    }

    testWidgets('변경 제목 + 현재 PIN 확인 단계로 시작', (tester) async {
      await _pump(tester, await withPin());
      expect(find.text('auth.pin.changeTitle'), findsOneWidget);
      expect(find.text('auth.pin.enterCurrent'), findsOneWidget);
    });

    testWidgets('현재 PIN 오입력 → 에러', (tester) async {
      await _pump(tester, await withPin());
      await _enter(tester, '000000');
      expect(find.text('auth.pin.incorrect'), findsOneWidget);
    });

    testWidgets('현재 PIN 정확 → 새 PIN → 확인 → 변경 저장', (tester) async {
      final svc = await withPin();
      await _pump(tester, svc);

      await _enter(tester, '123456'); // verifyCurrent
      expect(find.text('auth.pin.enterNew'), findsOneWidget);

      await _enter(tester, '654321'); // enterNew
      await _enter(tester, '654321'); // confirmNew

      expect((await svc.verifyPin('654321')).isSuccess, true);
    });
  });
}
