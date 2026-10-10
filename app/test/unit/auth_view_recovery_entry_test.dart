// M6: 생체 전용 잠금(PIN 기능 OFF 포크 또는 레거시)에서 기기의 생체 정보를 지우면
// 복구 링크가 `if (showPin)` 뒤에 있어 영구 잠금이 되던 문제.
// 복구 진입점은 잠금 방식과 무관하게 항상 보여야 한다.

import 'package:pipecheck/core/services/pin_service.dart';
import 'package:pipecheck/core/services/secure_store.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:pipecheck/features/auth/views/authentication_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _MemStore implements SecureStore {
  final map = <String, String>{};
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String value) async => map[key] = value;
  @override
  Future<void> delete(String key) async => map.remove(key);
}

class _FixedSettings extends SettingsNotifier {
  _FixedSettings(this._option);
  final UserAuthOption _option;

  @override
  Settings build() => Settings.initial().copyWith(userAuthOption: _option);
}

const _forgot = 'auth.pin.forgotPin';

void main() {
  Future<void> pumpLock(
    WidgetTester tester, {
    required UserAuthOption option,
    required bool hasPin,
  }) async {
    final store = _MemStore();
    final pin = PinService(store);
    if (hasPin) await pin.setPin('123456');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => _FixedSettings(option)),
          pinServiceProvider.overrideWithValue(pin),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const AuthenticationView()),
              GoRoute(
                path: '/pin-recovery',
                builder: (_, _) => const Text('recovery-screen'),
              ),
            ],
          ),
        ),
      ),
    );
    // PinEntry의 반복 애니메이션 때문에 pumpAndSettle은 정착하지 못한다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('생체 전용 잠금(PIN 없음)에서도 복구 진입점이 보이고 열린다', (tester) async {
    await pumpLock(tester, option: UserAuthOption.biometric, hasPin: false);

    expect(find.text(_forgot), findsOneWidget);

    await tester.tap(find.text(_forgot));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('recovery-screen'), findsOneWidget);
  });

  testWidgets('PIN 잠금에서는 기존대로 복구 진입점이 하나만 보인다', (tester) async {
    await pumpLock(tester, option: UserAuthOption.pin, hasPin: true);

    expect(find.text(_forgot), findsOneWidget);
  });

  testWidgets('생체+PIN 잠금에서도 복구 진입점이 하나만 보인다', (tester) async {
    await pumpLock(tester, option: UserAuthOption.biometric, hasPin: true);

    expect(find.text(_forgot), findsOneWidget);
  });
}
