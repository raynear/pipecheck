import 'package:boilerplate/config/app_feature_config.dart';
import 'package:boilerplate/core/state/auth_state.dart';
import 'package:boilerplate/core/state/settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

/// 잠금 미설정(none) 자동 인증 회귀 테스트.
///
/// 버그: 모든 프로파일이 isAuthenticationEnabled를 강제 ON하는데,
/// AuthStateNotifier는 플래그 OFF일 때만 자동 인증했다. 그 결과 앱 잠금을
/// 설정한 적 없는(userAuthOption == none) 사용자가 영원히 비인증 상태로 남아
/// 라우터 redirect가 모든 보호 라우트(home 등)를 /auth로 튕겼다.
/// 계약: "잠글 것이 없으면(플래그 OFF 또는 잠금 none) 처음부터 인증됨".
class _FixedSettings extends SettingsNotifier {
  _FixedSettings(this._option);
  final UserAuthOption _option;

  @override
  Settings build() => Settings.initial().copyWith(userAuthOption: _option);
}

void main() {
  group('AuthStateNotifier 부팅 자동 인증', () {
    test('플래그 ON + 잠금 미설정(none) → 처음부터 인증됨 (버그 회귀)', () {
      AppFeatureConfig.isAuthenticationEnabled = true;
      final container = TestHelpers.createContainer([
        settingsProvider.overrideWith(() => _FixedSettings(UserAuthOption.none)),
      ]);
      addTearDown(container.dispose);

      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.method, AuthMethod.none);
    });

    test('플래그 ON + 잠금 설정(pin) → 비인증 유지 (잠금 화면 보장)', () {
      AppFeatureConfig.isAuthenticationEnabled = true;
      final container = TestHelpers.createContainer([
        settingsProvider.overrideWith(() => _FixedSettings(UserAuthOption.pin)),
      ]);
      addTearDown(container.dispose);

      expect(container.read(authStateProvider).isAuthenticated, isFalse);
    });

    test('플래그 ON + 잠금 설정(biometric) → 비인증 유지', () {
      AppFeatureConfig.isAuthenticationEnabled = true;
      final container = TestHelpers.createContainer([
        settingsProvider
            .overrideWith(() => _FixedSettings(UserAuthOption.biometric)),
      ]);
      addTearDown(container.dispose);

      expect(container.read(authStateProvider).isAuthenticated, isFalse);
    });

    test('signOut 후에도 잠금 미설정(none)이면 재유도로 인증 유지 (/auth 루프 방지)',
        () async {
      AppFeatureConfig.isAuthenticationEnabled = true;
      final container = TestHelpers.createContainer([
        settingsProvider.overrideWith(() => _FixedSettings(UserAuthOption.none)),
      ]);
      addTearDown(container.dispose);

      await container.read(authStateProvider.notifier).signOut();

      expect(container.read(authStateProvider).isAuthenticated, isTrue);
    });

    test('플래그 OFF → 잠금 설정과 무관하게 인증됨 (기존 동작 보존)', () {
      AppFeatureConfig.isAuthenticationEnabled = false;
      final container = TestHelpers.createContainer([
        settingsProvider.overrideWith(() => _FixedSettings(UserAuthOption.pin)),
      ]);
      addTearDown(container.dispose);

      expect(container.read(authStateProvider).isAuthenticated, isTrue);
    });
  });
}
