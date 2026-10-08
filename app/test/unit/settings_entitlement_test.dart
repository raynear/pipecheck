// 설정에 저장되는 구독 권리(평생·임시 창·만료일)의 저장/복원과 활성 판정.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipecheck/core/state/settings.dart';

import '../support/orange_harness.dart';

void main() {
  late ProviderContainer c;
  late SettingsNotifier n;

  setUpOrange('settings_entitlement_test');

  setUp(() async {
    await Settings.initial().saveToOrange();
    c = ProviderContainer();
    addTearDown(c.dispose);
    n = c.read(settingsProvider.notifier);
  });

  final future = DateTime.now().add(const Duration(days: 3));

  test('평생 구매는 만료일 없이도 활성이고, 아무 권리도 없으면 비활성', () async {
    expect(c.read(settingsProvider).isSubscriptionActive, isFalse);
    await n.applyStoreEntitlement(PremiumEntitlement(hasLifetime: true, subscriptionExpiry: null));
    expect(c.read(settingsProvider).isSubscriptionActive, isTrue);
  });

  test('구독 만료일이 지났으면 비활성, 남았으면 활성', () async {
    await n.applyStoreEntitlement(PremiumEntitlement(hasLifetime: false, subscriptionExpiry: DateTime.now().subtract(const Duration(days: 1))));
    expect(c.read(settingsProvider).isSubscriptionActive, isFalse);
    await n.applyStoreEntitlement(PremiumEntitlement(hasLifetime: false, subscriptionExpiry: future));
    expect(c.read(settingsProvider).isSubscriptionActive, isTrue);
  });

  test('열린 구독은 날짜 없이, 성공한 조회가 부정하기 전까지 활성', () async {
    await n.applyStoreEntitlement(PremiumEntitlement(hasLifetime: false, subscriptionExpiry: null, subscriptionOpenEnded: true));
    expect(c.read(settingsProvider).isSubscriptionActive, isTrue);
    expect(c.read(settingsProvider).subscriptionExpiryDate, isNull);
    await n.applyStoreEntitlement(PremiumEntitlement(hasLifetime: false, subscriptionExpiry: null));
    expect(c.read(settingsProvider).isSubscriptionActive, isFalse);
  });

  test('권리 값은 저장했다가 다시 읽어도 그대로(재시작 후 유지)', () async {
    await n.applyStoreEntitlement(PremiumEntitlement(hasLifetime: true, subscriptionExpiry: future, subscriptionOpenEnded: true));
    await n.setDevPremium(true);
    final loaded = Settings.fromOrange();
    expect(loaded.hasLifetime, isTrue);
    expect(loaded.subscriptionOpenEnded, isTrue);
    expect(loaded.subscriptionExpiryDate, future);
    expect(loaded.devPremium, isTrue);
  });

  test('다른 설정을 바꿔도 권리 값은 지워지지 않는다', () async {
    await n.applyStoreEntitlement(PremiumEntitlement(hasLifetime: true, subscriptionExpiry: future));
    await n.updateSingleSetting(bold: true);
    final s = c.read(settingsProvider);
    expect(s.hasLifetime, isTrue);
    expect(s.subscriptionExpiryDate, future);
  });

  test('권리가 같으면 다시 쓰지 않는다', () async {
    await n.applyStoreEntitlement(PremiumEntitlement(hasLifetime: true, subscriptionExpiry: future));
    final before = c.read(settingsProvider);
    await n.applyStoreEntitlement(PremiumEntitlement(hasLifetime: true, subscriptionExpiry: future));
    expect(identical(c.read(settingsProvider), before), isTrue);
  });

  group('개발 프리미엄 덮어쓰기(devPremium)', () {
    tearDown(() => devOverrideAllowed = kDebugMode);

    test('실제 권리와 별개: 켜고 꺼도 평생·구독 값을 건드리지 않는다', () async {
      await n.applyStoreEntitlement(PremiumEntitlement(hasLifetime: true, subscriptionExpiry: future, subscriptionOpenEnded: true));
      await n.setDevPremium(true);
      await n.setDevPremium(false);
      final s = c.read(settingsProvider);
      expect(s.hasLifetime, isTrue);
      expect(s.subscriptionExpiryDate, future);
      expect(s.subscriptionOpenEnded, isTrue);
      expect(s.isSubscriptionActive, isTrue);
    });

    test('스토어 재조회가 지우지 않는다', () async {
      await n.setDevPremium(true);
      await n.applyStoreEntitlement(PremiumEntitlement(hasLifetime: false, subscriptionExpiry: null));
      expect(c.read(settingsProvider).devPremium, isTrue);
    });

    test('허용된 빌드에서만 효력이 있다', () async {
      await n.setDevPremium(true);
      devOverrideAllowed = true;
      expect(c.read(settingsProvider).isSubscriptionActive, isTrue);
      devOverrideAllowed = false;
      expect(c.read(settingsProvider).isSubscriptionActive, isFalse);
    });

    test('다른 설정을 바꿔도 유지된다', () async {
      await n.setDevPremium(true);
      await n.updateSingleSetting(bold: true);
      expect(c.read(settingsProvider).devPremium, isTrue);
    });
  });

  test('앱 실행 횟수를 올리고, 컨버터는 값을 왕복시킨다', () async {
    await n.incrementAppLaunchCount();
    expect(c.read(settingsProvider).appLaunchCount, 1);
    expect(const LocaleConverter().fromJson(const LocaleConverter().toJson(const Locale('ko', 'KR'))),
        const Locale('ko', 'KR'));
    expect(const TimeOfDayConverter().fromJson(const TimeOfDayConverter().toJson(const TimeOfDay(hour: 9, minute: 30))),
        const TimeOfDay(hour: 9, minute: 30));
  });

  test('displayProvider는 화면 설정만 뽑고, 폰트 목록·지원 언어를 갱신한다', () async {
    await n.updateSingleSetting(themeColor: 'red', fontSize: 18);
    final d = c.read(displayProvider);
    expect(d.themeColor, 'red');
    expect(d.fontSize, 18);

    Settings.updateLanguageFontList('en-US', {'Body': 'Lato'});
    expect(languageFontList['en']!['body'], 'Lato');
    expect(languageFontList['en']!['title'], 'Roboto');

    final locales = await Settings.updateSupportedLocale();
    expect(locales, isNotEmpty);
    expect(supportedLocales, locales);
  });

  test('유예 플래그가 켜진 만료일은 3일까지, 꺼져 있으면 만료 즉시 비활성이며 재시작 뒤에도 유지된다', () async {
    final past = DateTime.now().subtract(const Duration(days: 2));
    await n.applyStoreEntitlement(PremiumEntitlement(hasLifetime: false, subscriptionExpiry: past, subscriptionGrace: true));
    expect(c.read(settingsProvider).isSubscriptionActive, isTrue);
    expect(Settings.fromOrange().subscriptionGrace, isTrue);

    await n.applyStoreEntitlement(PremiumEntitlement(hasLifetime: false, subscriptionExpiry: past));
    expect(c.read(settingsProvider).isSubscriptionActive, isFalse);

    await n.applyStoreEntitlement(PremiumEntitlement(
        hasLifetime: false, subscriptionExpiry: DateTime.now().subtract(const Duration(days: 4)), subscriptionGrace: true));
    expect(c.read(settingsProvider).isSubscriptionActive, isFalse);
  });
}
