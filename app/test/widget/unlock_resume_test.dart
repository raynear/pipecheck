// N2: 잠금 해제 뒤 원래 목적지(딥링크·알림 탭)를 이어 연다. 보류가 없으면 /home.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pipecheck/core/services/deep_link_service.dart';
import 'package:pipecheck/core/services/pin_service.dart';
import 'package:pipecheck/core/services/secure_store.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:pipecheck/features/auth/views/authentication_view.dart';

class _MemStore implements SecureStore {
  final map = <String, String>{};
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String value) async => map[key] = value;
  @override
  Future<void> delete(String key) async => map.remove(key);
}

class _PinSettings extends SettingsNotifier {
  @override
  Settings build() =>
      Settings.initial().copyWith(userAuthOption: UserAuthOption.pin);
}

void main() {
  setUp(PendingDeepLink.reset);
  tearDown(PendingDeepLink.reset);

  Future<void> unlockWithPin(WidgetTester tester) async {
    final pin = PinService(_MemStore());
    await pin.setPin('123456');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_PinSettings.new),
          pinServiceProvider.overrideWithValue(pin),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/auth',
            routes: [
              GoRoute(path: '/auth', builder: (_, _) => const AuthenticationView()),
              GoRoute(path: '/home', builder: (_, _) => const Text('HOME')),
              GoRoute(path: '/settings', builder: (_, _) => const Text('SETTINGS')),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('보류된 목적지가 있으면 해제 뒤 그곳으로 간다', (tester) async {
    PendingDeepLink.holdForUnlock('/settings');
    await unlockWithPin(tester);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('보류가 없으면 /home 으로 간다', (tester) async {
    await unlockWithPin(tester);
    expect(find.text('HOME'), findsOneWidget);
  });
}
