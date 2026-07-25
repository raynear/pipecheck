// PIN 분실 복구 테스트 (P2-23h ③).
//
// 생체 티어는 테스트 환경에서 local_auth가 없어 canUseBiometrics()가 false →
// 숨겨진다. 앱 데이터 초기화 티어는 항상 표시되며, 확인 시 DB wipe + PIN 제거 +
// 잠금 해제(userAuthOption=none) 후 홈으로 이동한다. DB는 가짜로 대체한다.

import 'package:boilerplate/core/services/pin_service.dart';
import 'package:boilerplate/core/services/secure_store.dart';
import 'package:boilerplate/core/state/settings.dart';
import 'package:boilerplate/data/core/repositories/repository_providers.dart';
import 'package:boilerplate/data/datasources/database_datasource.dart';
import 'package:boilerplate/features/auth/views/pin_recovery_view.dart';
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

class _FakeDb implements DatabaseDataSource {
  _FakeDb({this.throwOnClear = false});
  final bool throwOnClear;
  bool cleared = false;
  @override
  Future<void> clearAll() async {
    if (throwOnClear) throw StateError('wipe failed');
    cleared = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PinSettings extends SettingsNotifier {
  @override
  Settings build() =>
      Settings.initial().copyWith(userAuthOption: UserAuthOption.pin);
}

Future<void> _pump(WidgetTester tester, PinService svc, _FakeDb db) async {
  final router = GoRouter(
    initialLocation: '/pin-recovery',
    routes: [
      GoRoute(path: '/pin-recovery', builder: (_, _) => const PinRecoveryView()),
      GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('HOME'))),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      pinServiceProvider.overrideWithValue(svc),
      databaseProvider.overrideWithValue(db),
      settingsProvider.overrideWith(_PinSettings.new),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('PinRecoveryView', () {
    testWidgets('앱 데이터 초기화 티어는 항상, 생체 티어는 미가용 시 숨김', (tester) async {
      final svc = PinService(_FakeSecureStore());
      await svc.setPin('123456');
      await _pump(tester, svc, _FakeDb());

      expect(find.text('auth.pin.recoverReset'), findsOneWidget);
      expect(find.text('auth.pin.recoverBiometric'), findsNothing); // 테스트 환경
    });

    testWidgets('앱 데이터 초기화: 확인 → DB wipe + PIN 제거 + 홈 이동', (tester) async {
      final svc = PinService(_FakeSecureStore());
      await svc.setPin('123456');
      final db = _FakeDb();
      await _pump(tester, svc, db);

      await tester.tap(find.text('auth.pin.recoverReset'));
      await tester.pumpAndSettle();
      // 확인 다이얼로그
      expect(find.text('auth.pin.resetWarning'), findsOneWidget);

      await tester.tap(find.text('common.confirm'));
      await tester.pumpAndSettle();

      expect(db.cleared, true);
      expect(await svc.hasPin(), false);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('초기화 취소 시 아무 일도 일어나지 않는다', (tester) async {
      final svc = PinService(_FakeSecureStore());
      await svc.setPin('123456');
      final db = _FakeDb();
      await _pump(tester, svc, db);

      await tester.tap(find.text('auth.pin.recoverReset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('common.cancel'));
      await tester.pumpAndSettle();

      expect(db.cleared, false);
      expect(await svc.hasPin(), true);
      expect(find.text('HOME'), findsNothing);
    });

    testWidgets('데이터 wipe 실패 → 잠금 유지(fail-closed)', (tester) async {
      final svc = PinService(_FakeSecureStore());
      await svc.setPin('123456');
      await _pump(tester, svc, _FakeDb(throwOnClear: true));

      await tester.tap(find.text('auth.pin.recoverReset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('common.confirm'));
      await tester.pumpAndSettle();

      // wipe 실패 → PIN을 지우지 않고 홈으로도 가지 않는다.
      expect(await svc.hasPin(), true);
      expect(find.text('HOME'), findsNothing);
    });
  });
}
