// M1: 앱 잠금이 콜드 스타트에서만 걸리던 문제.
//
// 백그라운드에서 돌아와도 PIN 없이 열렸다(resumed 분기가 알림·뱃지만 처리하고
// 재잠금 API가 없었다). 이 파일은 그 API(`markBackgrounded` /
// `relockIfBackgroundedLongerThan`)의 계약을 잠근다. 생명주기 배선(main.dart)은
// 별도 레인이 소유한다.

import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/state/auth_state.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedSettings extends SettingsNotifier {
  _FixedSettings(this._option);
  final UserAuthOption _option;

  @override
  Settings build() => Settings.initial().copyWith(userAuthOption: _option);
}

void main() {
  late Map<String, bool> saved;
  final t0 = DateTime.utc(2026, 1, 1, 12);

  setUp(() {
    saved = AppFeatureConfig.toMap();
    AppFeatureConfig.isAuthenticationEnabled = true;
  });
  tearDown(() => AppFeatureConfig.fromMap(saved));

  ProviderContainer unlocked(UserAuthOption option) {
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(() => _FixedSettings(option))],
    );
    addTearDown(container.dispose);
    container
        .read(authStateProvider.notifier)
        .setAuthState(AuthState.authenticated(method: AuthMethod.pin));
    return container;
  }

  test('유예 시간을 넘겨 떠나 있었으면 다시 잠근다', () {
    final container = unlocked(UserAuthOption.pin);
    final auth = container.read(authStateProvider.notifier);

    auth.markBackgrounded(now: t0);
    final relocked = auth.relockIfBackgroundedLongerThan(
      grace: const Duration(seconds: 30),
      now: t0.add(const Duration(seconds: 31)),
    );

    expect(relocked, isTrue);
    expect(container.read(authStateProvider).isAuthenticated, isFalse);
  });

  test('시계를 과거로 돌렸으면(음수 경과) 유예 안이어도 잠근다', () {
    final container = unlocked(UserAuthOption.pin);
    final auth = container.read(authStateProvider.notifier);

    auth.markBackgrounded(now: t0);
    final relocked = auth.relockIfBackgroundedLongerThan(
      grace: const Duration(seconds: 30),
      now: t0.subtract(const Duration(hours: 1)),
    );

    expect(relocked, isTrue);
    expect(container.read(authStateProvider).isAuthenticated, isFalse);
  });

  test('유예 안에 돌아오면 잠그지 않는다 (생체 프롬프트 등 정상 흐름)', () {
    final container = unlocked(UserAuthOption.pin);
    final auth = container.read(authStateProvider.notifier);

    auth.markBackgrounded(now: t0);
    final relocked = auth.relockIfBackgroundedLongerThan(
      grace: const Duration(seconds: 30),
      now: t0.add(const Duration(seconds: 5)),
    );

    expect(relocked, isFalse);
    expect(container.read(authStateProvider).isAuthenticated, isTrue);
  });

  test('잠금 미설정(none)이면 오래 떠나 있어도 잠그지 않는다', () {
    final container = unlocked(UserAuthOption.none);
    final auth = container.read(authStateProvider.notifier);

    auth.markBackgrounded(now: t0);
    final relocked = auth.relockIfBackgroundedLongerThan(
      now: t0.add(const Duration(hours: 5)),
    );

    expect(relocked, isFalse);
    expect(
      container.read(authStateProvider).isAuthenticated,
      isTrue,
      reason: '잠글 것이 없는 사용자를 /auth 루프에 가두면 안 된다',
    );
  });

  test('떠난 기록이 없으면 아무것도 하지 않는다 (resumed만 단독 호출)', () {
    final container = unlocked(UserAuthOption.pin);
    final auth = container.read(authStateProvider.notifier);

    expect(auth.relockIfBackgroundedLongerThan(now: t0), isFalse);
    expect(container.read(authStateProvider).isAuthenticated, isTrue);
  });

  test('처음 떠난 시각이 기준이다 — 반복 pause가 시계를 되감지 않는다', () {
    final container = unlocked(UserAuthOption.pin);
    final auth = container.read(authStateProvider.notifier);

    auth.markBackgrounded(now: t0);
    auth.markBackgrounded(now: t0.add(const Duration(seconds: 50)));
    final relocked = auth.relockIfBackgroundedLongerThan(
      grace: const Duration(seconds: 30),
      now: t0.add(const Duration(seconds: 60)),
    );

    expect(relocked, isTrue);
  });

  test('한 번 판정하면 기록이 비워진다 — 같은 이탈로 두 번 잠기지 않는다', () {
    final container = unlocked(UserAuthOption.pin);
    final auth = container.read(authStateProvider.notifier);

    auth.markBackgrounded(now: t0);
    auth.relockIfBackgroundedLongerThan(
      now: t0.add(const Duration(minutes: 5)),
    );
    // 사용자가 PIN으로 다시 풀었다.
    auth.setAuthState(AuthState.authenticated(method: AuthMethod.pin));

    expect(
      auth.relockIfBackgroundedLongerThan(
        now: t0.add(const Duration(minutes: 6)),
      ),
      isFalse,
    );
    expect(container.read(authStateProvider).isAuthenticated, isTrue);
  });

  test('플래그가 꺼진 앱은 잠그지 않는다', () {
    final container = unlocked(UserAuthOption.pin);
    AppFeatureConfig.isAuthenticationEnabled = false;
    final auth = container.read(authStateProvider.notifier);

    auth.markBackgrounded(now: t0);

    expect(
      auth.relockIfBackgroundedLongerThan(
        now: t0.add(const Duration(hours: 1)),
      ),
      isFalse,
    );
  });
}
