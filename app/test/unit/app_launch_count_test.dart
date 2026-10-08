// 실행 횟수 증가가 메인 컨테이너의 상태에 반영되는지(주입) / 임시 컨테이너를 누수하지 않는지.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipecheck/config/app_config.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/state/settings.dart';

import '../support/orange_harness.dart';

void main() {
  setUpOrange('app_launch_count_test');
  late Map<String, bool> saved;
  setUp(() {
    saved = AppFeatureConfig.toMap();
    AppFeatureConfig.isAppReviewPromptEnabled = false;
  });
  tearDown(() => AppFeatureConfig.fromMap(saved));

  test('notifier를 주입하면 메인 컨테이너의 상태가 증가한다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final before = container.read(settingsProvider).appLaunchCount;

    await AppConfig().incrementAppLaunchCountAndCheckForReview(
      settingsNotifier: container.read(settingsProvider.notifier),
    );

    expect(container.read(settingsProvider).appLaunchCount, before + 1);
  });

  test('주입하지 않아도 던지지 않는다 (임시 컨테이너는 dispose된다)', () async {
    await AppConfig().incrementAppLaunchCountAndCheckForReview();
  });
}
