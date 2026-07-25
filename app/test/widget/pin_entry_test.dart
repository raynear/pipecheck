// PIN 오입력 피드백/잠금 UI 테스트 (P2-23h PR2 ①).
//
// EasyLocalization 미초기화 → .tr()는 키를 그대로 반환하므로 키로 assert한다.
// 검증 결과는 PinService(인메모리 SecureStore)로 결정적으로 구성한다.

import 'package:boilerplate/config/app_feature_config.dart';
import 'package:boilerplate/core/services/pin_service.dart';
import 'package:boilerplate/core/services/secure_store.dart';
import 'package:boilerplate/core/state/settings.dart';
import 'package:boilerplate/core/widgets/inputs/pin_entry.dart';
import 'package:boilerplate/features/auth/views/authentication_view.dart';
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

class _AuthSettings extends SettingsNotifier {
  _AuthSettings(this.option);
  final UserAuthOption option;
  @override
  Settings build() => Settings.initial().copyWith(userAuthOption: option);
}

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );

// pin_code_fields의 커서 blink는 끝없이 반복돼 pumpAndSettle이 타임아웃하고,
// 입력 시 blinkWhenObscuring의 ~500ms "표시 후 가림" 타이머가 생긴다. 고정
// duration pump로 마이크로태스크(검증 Future)와 그 타이머를 모두 흘려보낸다.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<PinService> _serviceWithPin(String pin) async {
  final svc = PinService(_FakeSecureStore());
  await svc.setPin(pin);
  return svc;
}

Future<void> _pumpView(
  WidgetTester tester,
  PinService svc, {
  UserAuthOption option = UserAuthOption.pin,
}) async {
  final router = GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(path: '/auth', builder: (_, _) => const AuthenticationView()),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      pinServiceProvider.overrideWithValue(svc),
      settingsProvider.overrideWith(() => _AuthSettings(option)),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await _settle(tester);
}

void main() {
  group('PinEntry 위젯', () {
    testWidgets('입력 완료 시 onCompleted(value)', (tester) async {
      String? done;
      await tester.pumpWidget(_host(PinEntry(
        controller: PinEntryController(),
        onCompleted: (v) => done = v,
      )));
      await tester.enterText(find.byType(TextField).first, '123456');
      await _settle(tester);
      expect(done, '123456');
    });

    testWidgets('errorText가 있으면 렌더', (tester) async {
      await tester.pumpWidget(_host(PinEntry(
        controller: PinEntryController(),
        onCompleted: (_) {},
        errorText: 'auth.pin.incorrect',
      )));
      expect(find.text('auth.pin.incorrect'), findsOneWidget);
    });

    testWidgets('enabled=false면 입력 비활성화', (tester) async {
      await tester.pumpWidget(_host(PinEntry(
        controller: PinEntryController(),
        onCompleted: (_) {},
        enabled: false,
      )));
      final tf = tester.widget<TextField>(find.byType(TextField).first);
      expect(tf.enabled, false);
    });

    testWidgets('controller.shake()는 예외 없이 동작', (tester) async {
      final controller = PinEntryController();
      await tester.pumpWidget(_host(PinEntry(
        controller: controller,
        onCompleted: (_) {},
      )));
      controller.shake();
      await _settle(tester);
      // shake 후 필드가 비워진다.
      final tf = tester.widget<TextField>(find.byType(TextField).first);
      expect(tf.controller!.text, '');
    });
  });

  group('AuthenticationView PIN 피드백 (회귀 가드)', () {
    testWidgets('오입력 시 에러 메시지 표시 (이전: 무피드백 버그)', (tester) async {
      final svc = await _serviceWithPin('123456');
      await _pumpView(tester, svc);

      await tester.enterText(find.byType(TextField).first, '000000');
      await _settle(tester);

      expect(find.text('auth.pin.incorrect'), findsOneWidget);
    });

    testWidgets('정확한 PIN은 에러 없이 홈으로 이동', (tester) async {
      final svc = await _serviceWithPin('123456');
      await _pumpView(tester, svc);

      await tester.enterText(find.byType(TextField).first, '123456');
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('auth.pin.incorrect'), findsNothing);
      // 성공 시 PIN 화면을 벗어난다(pop 또는 /home 이동).
      expect(find.byType(PinEntry), findsNothing);
    });

    testWidgets('5회 오입력 → 잠금 메시지 + 입력 비활성화', (tester) async {
      final svc = await _serviceWithPin('123456');
      await _pumpView(tester, svc);

      for (var i = 0; i < 5; i++) {
        await tester.enterText(find.byType(TextField).first, '000000');
        await _settle(tester);
      }

      expect(find.text('auth.pin.lockedFor'), findsOneWidget);
      final tf = tester.widget<TextField>(find.byType(TextField).first);
      expect(tf.enabled, false);
    });
  });

  group('생체+PIN 통합 모델 (④)', () {
    setUp(() {
      // 생체 자동 프롬프트가 no-op(success) 대신 실제 local_auth(테스트에선 실패)
      // 를 타게 해 네비게이션을 막는다. 통합 화면 레이아웃만 검증한다.
      AppFeatureConfig.isAuthenticationEnabled = true;
      AppFeatureConfig.isBiometricAuthEnabled = true;
      AppFeatureConfig.isPinAuthEnabled = true;
    });

    testWidgets('생체 모드 + PIN 설정됨 → PIN 입력 + 생체 버튼 동시 표시', (tester) async {
      final svc = await _serviceWithPin('123456');
      await _pumpView(tester, svc, option: UserAuthOption.biometric);

      expect(find.byType(PinEntry), findsOneWidget);
      expect(find.text('auth.pin.useBiometric'), findsOneWidget);
    });

    testWidgets('생체 모드 + PIN 없음 → 레거시 생체 아이콘 전용', (tester) async {
      final svc = PinService(_FakeSecureStore()); // PIN 미설정
      await _pumpView(tester, svc, option: UserAuthOption.biometric);

      expect(find.byType(PinEntry), findsNothing);
      expect(find.byIcon(Icons.face_unlock_outlined), findsOneWidget);
    });
  });
}
