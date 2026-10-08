// 설정에 저장되는 구독 권리(평생·임시 창·만료일)의 저장/복원과 활성 판정.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orange/orange.dart';
import 'package:pipecheck/core/state/settings.dart';

void main() {
  late Directory dir;
  late ProviderContainer c;
  late SettingsNotifier n;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dir = await Directory.systemTemp.createTemp('settings_entitlement_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
    await Orange.init();
  });

  tearDownAll(() async {
    try {
      await dir.delete(recursive: true);
    } on FileSystemException catch (_) {}
  });

  setUp(() async {
    await Settings.initial().saveToOrange();
    c = ProviderContainer();
    addTearDown(c.dispose);
    n = c.read(settingsProvider.notifier);
  });

  final future = DateTime.now().add(const Duration(days: 3));

  test('평생 구매는 만료일 없이도 활성이고, 아무 권리도 없으면 비활성', () async {
    expect(c.read(settingsProvider).isSubscriptionActive, isFalse);
    await n.applyStoreEntitlement(hasLifetime: true, subscriptionExpiry: null);
    expect(c.read(settingsProvider).isSubscriptionActive, isTrue);
  });

  test('구독 만료일이 지났으면 비활성, 남았으면 활성', () async {
    await n.applyStoreEntitlement(
        hasLifetime: false, subscriptionExpiry: DateTime.now().subtract(const Duration(days: 1)));
    expect(c.read(settingsProvider).isSubscriptionActive, isFalse);
    await n.applyStoreEntitlement(hasLifetime: false, subscriptionExpiry: future);
    expect(c.read(settingsProvider).isSubscriptionActive, isTrue);
  });

  test('권리 값은 저장했다가 다시 읽어도 그대로(재시작 후 유지)', () async {
    await n.applyStoreEntitlement(
        hasLifetime: true, subscriptionExpiry: future, subscriptionOpenEnded: true);
    final loaded = Settings.fromOrange();
    expect(loaded.hasLifetime, isTrue);
    expect(loaded.subscriptionOpenEnded, isTrue);
    expect(loaded.subscriptionExpiryDate, future);
  });

  test('다른 설정을 바꿔도 권리 값은 지워지지 않는다', () async {
    await n.applyStoreEntitlement(hasLifetime: true, subscriptionExpiry: future);
    await n.updateSingleSetting(bold: true);
    final s = c.read(settingsProvider);
    expect(s.hasLifetime, isTrue);
    expect(s.subscriptionExpiryDate, future);
  });

  test('권리가 같으면 다시 쓰지 않는다', () async {
    await n.applyStoreEntitlement(hasLifetime: true, subscriptionExpiry: future);
    final before = c.read(settingsProvider);
    await n.applyStoreEntitlement(hasLifetime: true, subscriptionExpiry: future);
    expect(identical(c.read(settingsProvider), before), isTrue);
  });

  test('clearSingleSetting(subscriptionExpiryDate)는 평생·임시 창까지 비운다', () async {
    await n.applyStoreEntitlement(
        hasLifetime: true, subscriptionExpiry: future, subscriptionOpenEnded: true);
    await n.clearSingleSetting(subscriptionExpiryDate: true);
    final s = c.read(settingsProvider);
    expect(s.subscriptionExpiryDate, isNull);
    expect(s.hasLifetime, isFalse);
    expect(s.subscriptionOpenEnded, isFalse);
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
}
