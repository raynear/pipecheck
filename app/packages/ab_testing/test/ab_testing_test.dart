import 'package:ab_testing/ab_testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 테스트용 실험 레지스트리. 100% / 0% 트래픽으로 할당을 결정적으로 만든다.
enum _TestExp implements ExperimentSpec {
  always('always_enabled', 100),
  never('never_enabled', 0);

  const _TestExp(this.remoteKey, this.trafficPercent);

  @override
  final String remoteKey;
  @override
  final int trafficPercent;
}

/// Firebase 미사용 설정 — RC fetch·analytics·crashlytics 경로를 모두 끈다.
/// 이 설정에서 [ABTestService]는 SharedPreferences만 만지므로 Firebase 없이
/// 순수 할당/오버라이드 로직을 검증할 수 있다.
const _noFirebase = ABTestConfig(
  enabled: true,
  remoteConfigEnabled: false,
  analyticsEnabled: false,
  crashlyticsEnabled: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('100% traffic → treatment, 0% → control (결정적 할당)', () async {
    final svc = ABTestService(experiments: _TestExp.values, config: _noFirebase);
    await svc.initialize();

    expect(svc.isEnabled(_TestExp.always), isTrue);
    expect(svc.getVariant(_TestExp.always), 'treatment');
    expect(svc.isEnabled(_TestExp.never), isFalse);
    expect(svc.getVariant(_TestExp.never), 'control');
  });

  test('config.enabled=false → initialize no-op, 전 실험 control', () async {
    final svc = ABTestService(
      experiments: _TestExp.values,
      config: const ABTestConfig(
        enabled: false,
        remoteConfigEnabled: false,
        analyticsEnabled: false,
        crashlyticsEnabled: false,
      ),
    );
    await svc.initialize();

    // 할당이 로드되지 않았으므로 100% 실험도 control.
    expect(svc.isEnabled(_TestExp.always), isFalse);
  });

  test('오버라이드 우선순위 > 할당', () async {
    final svc = ABTestService(experiments: _TestExp.values, config: _noFirebase);
    await svc.initialize();
    expect(svc.isEnabled(_TestExp.never), isFalse);

    await svc.setOverride(_TestExp.never, true);
    expect(svc.hasOverride(_TestExp.never), isTrue);
    expect(svc.isEnabled(_TestExp.never), isTrue); // 오버라이드가 이긴다

    await svc.clearOverride(_TestExp.never);
    expect(svc.hasOverride(_TestExp.never), isFalse);
    expect(svc.isEnabled(_TestExp.never), isFalse);
  });

  test('할당은 prefs로 인스턴스 간 영속', () async {
    final first = ABTestService(experiments: _TestExp.values, config: _noFirebase);
    await first.initialize();

    final second = ABTestService(experiments: _TestExp.values, config: _noFirebase);
    await second.initialize();

    expect(second.isEnabled(_TestExp.always), isTrue);
  });
}
