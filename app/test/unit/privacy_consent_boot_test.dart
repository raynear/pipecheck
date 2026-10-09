// 저장된 개인정보 동의가 부팅에서 실제로 SDK에 적용되는가.
//
// 실사고 구조: `_initializeNonCriticalServices`가 분석·ad_storage·Crashlytics를
// 하드코딩 `true`로 켜서, "모두 거부"한 사용자도 다음 실행부터 수집됐다.
// 저장된 동의를 SDK에 적용하는 `_applyConsent`는 `saveConsent`에서만 불렸다.
// 또 `PrivacyConsentNotifier.build()`가 기본값을 돌려준 뒤 비동기로 읽어서
// 동의한 사용자에게도 매번 동의 시트가 떴다.
//
// 여기서 재는 건 "SDK 적용 함수가 어떤 값으로 불렸는가"다(대역이 기록).

import 'dart:io';

import 'package:pipecheck/config/app_config.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/services/privacy_consent_service.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:pipecheck/core/widgets/dialogs/privacy_consent_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_services/firebase_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orange/orange.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late Map<String, bool> savedFlags;
  late List<PrivacyConsent> applied;
  late ProviderContainer container;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('privacy_consent_boot');
    PathProviderPlatform.instance = _TempPathProvider(temp.path);
    await Orange.init();
  });

  tearDownAll(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  PrivacyConsentService service() =>
      PrivacyConsentService(applier: (c) async => applied.add(c));

  setUp(() async {
    savedFlags = AppFeatureConfig.toMap();
    AppFeatureConfig.disableAllFeatures();
    AppFeatureConfig.isPrivacyConsentEnabled = true;
    for (final k in [
      'privacy_analytics_consent',
      'privacy_ad_consent',
      'privacy_crash_consent',
      'privacy_consent_version',
      'privacy_consent_date',
    ]) {
      Orange.remove(k);
    }
    applied = [];
    container = ProviderContainer(
      overrides: [privacyConsentServiceProvider.overrideWithValue(service())],
    );
  });

  tearDown(() {
    container.dispose();
    AppFeatureConfig.fromMap(savedFlags);
  });

  group('부팅 적용', () {
    test('아직 동의하지 않았으면 분석·광고·크래시 전부 거부로 적용한다', () async {
      await service().applyStoredConsent();

      expect(applied, hasLength(1));
      expect(applied.single.analyticsConsent, isFalse);
      expect(applied.single.adConsent, isFalse);
      expect(applied.single.crashReportingConsent, isFalse);
    });

    test('"모두 거부"를 저장한 뒤 재부팅해도 거부로 적용한다', () async {
      await service().saveConsent(const PrivacyConsent(consentVersion: 1));
      applied.clear();

      await service().applyStoredConsent();

      expect(applied.single.analyticsConsent, isFalse);
      expect(applied.single.crashReportingConsent, isFalse);
    });

    test('저장된 항목별 동의를 그대로 적용한다', () async {
      await service().saveConsent(
        const PrivacyConsent(
          analyticsConsent: true,
          crashReportingConsent: true,
          consentVersion: 1,
        ),
      );
      applied.clear();

      await service().applyStoredConsent();

      expect(applied.single.analyticsConsent, isTrue);
      expect(applied.single.adConsent, isFalse);
      expect(applied.single.crashReportingConsent, isTrue);
    });

    test('동의 기능이 꺼진 앱은 동의 UI가 없으므로 전부 허용한다', () async {
      AppFeatureConfig.isPrivacyConsentEnabled = false;

      await service().applyStoredConsent();

      expect(applied.single.analyticsConsent, isTrue);
      expect(applied.single.adConsent, isTrue);
      expect(applied.single.crashReportingConsent, isTrue);
    });
  });

  group('부팅 배선 (AppConfig.applyBootConsent)', () {
    test('미동의 저장 상태면 applier가 전부 false로 정확히 1회 불린다', () async {
      await AppConfig.applyBootConsent(service: service());

      expect(applied, hasLength(1));
      expect(applied.single.analyticsConsent, isFalse);
      expect(applied.single.adConsent, isFalse);
      expect(applied.single.crashReportingConsent, isFalse);
    });

    test('동의 기능이 꺼진 앱은 전부 true로 1회 적용한다', () async {
      AppFeatureConfig.isPrivacyConsentEnabled = false;

      await AppConfig.applyBootConsent(service: service());

      expect(applied, hasLength(1));
      expect(applied.single.analyticsConsent, isTrue);
      expect(applied.single.adConsent, isTrue);
      expect(applied.single.crashReportingConsent, isTrue);
    });

    test('부팅 코드는 SDK 수집을 true로 하드코딩하지 않고 applyBootConsent만 부른다', () {
      final code = File('lib/config/app_config.dart')
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      expect(code, contains('await applyBootConsent();'));
      expect(code, isNot(contains('setAnalyticsCollectionEnabled(true)')));
      expect(code, isNot(contains('CrashReporter.setCollectionEnabled(true)')));
      expect(code, isNot(contains('analyticsStorageConsentGranted: true')));
    });

    test('동의 적용 호출은 app_config.dart에 하나도 없다 (privacy_consent_service에만)', () {
      final code = File('lib/config/app_config.dart')
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      for (final call in [
        'setAnalyticsCollectionEnabled(',
        'CrashReporter.setCollectionEnabled(',
        'setConsent(',
      ]) {
        expect(call.allMatches(code), isEmpty, reason: call);
      }
    });

    test('저장값이 손상돼 읽기가 던지면 미동의 기본값으로 폴백한다', () async {
      // getInt가 문자열을 만나 던지는 손상 상태.
      Orange.setString('privacy_consent_version', 'corrupt');

      final loaded = service().loadConsentSync();
      expect(loaded.hasConsented, isFalse);
      expect(loaded.analyticsConsent, isFalse);

      await AppConfig.applyBootConsent(service: service());
      expect(applied.single.crashReportingConsent, isFalse);
    });
  });

  group('실제 SDK 적용 (PrivacyConsentService.applyToSdks)', () {
    late List<String> calls;
    ConsentSdk recorder() => ConsentSdk(
      setConsent:
          ({
            required bool analyticsStorageConsentGranted,
            required bool adStorageConsentGranted,
          }) async => calls.add(
            'consent:$analyticsStorageConsentGranted,$adStorageConsentGranted',
          ),
      setAnalyticsCollectionEnabled: (e) async => calls.add('analytics:$e'),
      setCrashCollectionEnabled: (e) async => calls.add('crash:$e'),
    );

    setUp(() => calls = []);

    test('동의값 그대로 setConsent·Analytics 수집·Crashlytics 3종을 부른다', () async {
      await PrivacyConsentService.applyToSdks(
        const PrivacyConsent(
          analyticsConsent: true,
          adConsent: false,
          crashReportingConsent: true,
        ),
        sdk: recorder(),
      );

      expect(calls, ['consent:true,false', 'analytics:true', 'crash:true']);
    });

    test('항목별로 값이 섞여도 각자 자기 값만 받는다', () async {
      await PrivacyConsentService.applyToSdks(
        const PrivacyConsent(adConsent: true),
        sdk: recorder(),
      );

      expect(calls, ['consent:false,true', 'analytics:false', 'crash:false']);
    });

    test('analytics만 켜고 crash는 꺼도 각자 자기 값만 받는다', () async {
      await PrivacyConsentService.applyToSdks(
        const PrivacyConsent(analyticsConsent: true),
        sdk: recorder(),
      );

      expect(calls, ['consent:true,false', 'analytics:true', 'crash:false']);
    });

    test('crash만 켜고 analytics는 꺼도 각자 자기 값만 받는다', () async {
      await PrivacyConsentService.applyToSdks(
        const PrivacyConsent(crashReportingConsent: true),
        sdk: recorder(),
      );

      expect(calls, ['consent:false,false', 'analytics:false', 'crash:true']);
    });

    test('기본 ConsentSdk는 실제 Firebase·Crashlytics 함수를 가리킨다', () {
      const sdk = ConsentSdk();

      expect(sdk.setConsent, FirebaseService.setConsent);
      expect(
        sdk.setAnalyticsCollectionEnabled,
        FirebaseService.setAnalyticsCollectionEnabled,
      );
      expect(sdk.setCrashCollectionEnabled, CrashReporter.setCollectionEnabled);
    });
  });

  group('동기 로드', () {
    test('저장된 동의가 있으면 첫 읽기부터 needsConsent가 false다', () async {
      await service().saveConsent(
        const PrivacyConsent(
          analyticsConsent: true,
          consentVersion: currentConsentVersion,
        ),
      );

      // 비동기 로드가 끝나기 전의 첫 동기 읽기 — 스플래시가 이렇게 읽는다.
      expect(container.read(needsConsentProvider), isFalse);
      expect(container.read(privacyConsentProvider).analyticsConsent, isTrue);
    });

    test('저장된 동의가 없으면 needsConsent가 true다', () {
      expect(container.read(needsConsentProvider), isTrue);
    });
  });

  testWidgets('동의 시트의 토글은 현재 동의값에서 시작한다', (tester) async {
    await service().saveConsent(
      const PrivacyConsent(
        analyticsConsent: true,
        crashReportingConsent: true,
        consentVersion: 1,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PrivacyConsentDialog()),
          ),
        ),
      ),
    );

    final values = tester
        .widgetList<Switch>(find.byType(Switch))
        .map((s) => s.value);
    expect(values, [true, false, true]);
  });

  group('저장·갱신', () {
    test('acceptAll/rejectAll은 세 항목을 함께 바꾸고 SDK에 적용한다', () async {
      final notifier = container.read(privacyConsentProvider.notifier);

      await notifier.acceptAll();
      expect(container.read(privacyConsentProvider).hasConsented, isTrue);
      expect(applied.last.crashReportingConsent, isTrue);
      expect(PrivacyConsentService.personalizedAdsAllowedSync(), isTrue);

      await notifier.rejectAll();
      expect(applied.last.analyticsConsent, isFalse);
      expect(applied.last.adConsent, isFalse);
      expect(applied.last.crashReportingConsent, isFalse);
      expect(PrivacyConsentService.personalizedAdsAllowedSync(), isFalse);
    });

    test('동의 버전이 낮으면 다시 받아야 한다', () {
      final s = service();
      expect(s.needsConsent(const PrivacyConsent()), isTrue);
      expect(
        s.needsConsent(
          const PrivacyConsent(consentVersion: currentConsentVersion),
        ),
        isFalse,
      );
      AppFeatureConfig.isPrivacyConsentEnabled = false;
      expect(s.needsConsent(const PrivacyConsent()), isFalse);
    });

    test('JSON 왕복과 copyWith가 값을 보존한다', () {
      final c = PrivacyConsent(
        analyticsConsent: true,
        crashReportingConsent: true,
        consentVersion: 2,
        consentDate: DateTime.utc(2026, 1, 2),
      );
      final back = PrivacyConsent.fromJson(c.toJson());
      expect(back.analyticsConsent, isTrue);
      expect(back.adConsent, isFalse);
      expect(back.consentDate, DateTime.utc(2026, 1, 2));
      expect(c.copyWith(adConsent: true).adConsent, isTrue);
    });

    test('saveConsent 뒤 동기 로드가 같은 값을 돌려준다', () async {
      await service().saveConsent(
        const PrivacyConsent(adConsent: true, consentVersion: 1),
      );
      final loaded = service().loadConsentSync();
      expect(loaded.adConsent, isTrue);
      expect(await service().requestTrackingAuthorization(), isTrue);
    });

    test('기본 적용기는 SDK 미초기화 상태에서 던지지 않는다', () async {
      await PrivacyConsentService().applyStoredConsent();
    });
  });

  group('앱 실행 횟수', () {
    test('주입한 notifier의 상태에 증가분이 반영된다', () async {
      AppFeatureConfig.isAppReviewPromptEnabled = false;
      final main = ProviderContainer();
      addTearDown(main.dispose);
      final before = main.read(settingsProvider).appLaunchCount;

      await AppConfig().incrementAppLaunchCountAndCheckForReview(
        settingsNotifier: main.read(settingsProvider.notifier),
      );

      expect(main.read(settingsProvider).appLaunchCount, before + 1);
    });
  });
}
