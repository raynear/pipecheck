import 'dart:io';

import 'package:boilerplate_cli/core/config_loader.dart';
import 'package:boilerplate_cli/core/env_artifacts.dart';
import 'package:test/test.dart';

const _defaultProjectYaml = '''
project:
  name: "Test App"
  package_name: com.example.testapp
  version: "1.0.0"

admob:
  ios_app_id: "ca-app-pub-1111~1111"
  android_app_id: "ca-app-pub-1111~2222"
  units:
    ios:
      banner: "ca-app-pub-1111/ios-banner"
      interstitial: "ca-app-pub-1111/ios-interstitial"
      rewarded: "ca-app-pub-1111/ios-rewarded"
      rewarded_interstitial: "ca-app-pub-1111/ios-rewarded-interstitial"
      native: "ca-app-pub-1111/ios-native"
      app_open: "ca-app-pub-1111/ios-app-open"
    android:
      banner: "ca-app-pub-1111/aos-banner"
      interstitial: "ca-app-pub-1111/aos-interstitial"
      rewarded: "ca-app-pub-1111/aos-rewarded"
      rewarded_interstitial: "ca-app-pub-1111/aos-rewarded-interstitial"
      native: "ca-app-pub-1111/aos-native"
      app_open: "ca-app-pub-1111/aos-app-open"
''';

const _defaultAppConfigYaml = '''
profile: standard

services:
  firebase:
    enabled: false

monetization:
  ads:
    enabled: true
  subscription:
    enabled: false
''';

const _projectYamlNoUnits = '''
project:
  name: "Test App"
  package_name: com.example.testapp

admob:
  ios_app_id: ""
  android_app_id: ""
''';

/// All 12 runtime AD env keys (byte-exact contract with ad_service.dart).
const _adKeys = [
  'IOS_BANNER_AD_ID',
  'IOS_INTERSTITIAL_AD_ID',
  'IOS_REWARDED_AD_ID',
  'IOS_REWARDED_INTERSTITIAL_AD_ID',
  'IOS_NATIVE_AD_ID',
  'IOS_APP_OPEN_AD_ID',
  'AOS_BANNER_AD_ID',
  'AOS_INTERSTITIAL_AD_ID',
  'AOS_REWARDED_AD_ID',
  'AOS_REWARDED_INTERSTITIAL_AD_ID',
  'AOS_NATIVE_AD_ID',
  'AOS_APP_OPEN_AD_ID',
];

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('env_artifacts_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<ConfigLoader> setUpConfigs({
    String projectYaml = _defaultProjectYaml,
    String appConfigYaml = _defaultAppConfigYaml,
  }) async {
    File('${tempDir.path}/project.yaml').writeAsStringSync(projectYaml);
    File('${tempDir.path}/app_config.yaml').writeAsStringSync(appConfigYaml);
    final config = ConfigLoader('${tempDir.path}/app_config.yaml');
    await config.load();
    return config;
  }

  String readArtifact(String mode) =>
      File('${tempDir.path}/app/config/env/.env.$mode').readAsStringSync();

  Map<String, String> parseEnv(String content) {
    final map = <String, String>{};
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eqIndex = trimmed.indexOf('=');
      if (eqIndex > 0) {
        map[trimmed.substring(0, eqIndex)] = trimmed.substring(eqIndex + 1);
      }
    }
    return map;
  }

  group('writeRuntimeEnvArtifacts', () {
    test('writes all three artifacts including .env.profile', () async {
      final config = await setUpConfigs();

      final written = await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      expect(written, hasLength(3));
      for (final mode in ['debug', 'profile', 'release']) {
        final file = File('${tempDir.path}/app/config/env/.env.$mode');
        expect(file.existsSync(), isTrue, reason: '.env.$mode must exist');
        expect(
          readArtifact(mode),
          contains('# mode: $mode'),
          reason: '.env.$mode must declare its mode',
        );
        expect(readArtifact(mode), contains('# source-hash: '));
        expect(readArtifact(mode), contains('AUTO-GENERATED'));
      }
    });

    test('debug and profile contain all 12 AD keys with Google test IDs',
        () async {
      final config = await setUpConfigs();

      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      for (final mode in ['debug', 'profile']) {
        final env = parseEnv(readArtifact(mode));
        for (final key in _adKeys) {
          expect(env, contains(key), reason: '$key missing in .env.$mode');
          expect(
            env[key],
            startsWith('ca-app-pub-3940256099942544/'),
            reason: '$key in .env.$mode must be a Google test unit ID',
          );
        }
        // Spot-check exact values from the official table
        expect(env['IOS_BANNER_AD_ID'],
            equals('ca-app-pub-3940256099942544/2934735716'));
        expect(env['AOS_BANNER_AD_ID'],
            equals('ca-app-pub-3940256099942544/6300978111'));
        expect(env['IOS_APP_OPEN_AD_ID'],
            equals('ca-app-pub-3940256099942544/5575463023'));
        expect(env['AOS_APP_OPEN_AD_ID'],
            equals('ca-app-pub-3940256099942544/9257395921'));
      }
    });

    test('release contains admob.units values verbatim', () async {
      final config = await setUpConfigs();

      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      final env = parseEnv(readArtifact('release'));
      expect(env['IOS_BANNER_AD_ID'], equals('ca-app-pub-1111/ios-banner'));
      expect(env['IOS_INTERSTITIAL_AD_ID'],
          equals('ca-app-pub-1111/ios-interstitial'));
      expect(env['IOS_REWARDED_AD_ID'], equals('ca-app-pub-1111/ios-rewarded'));
      expect(env['IOS_REWARDED_INTERSTITIAL_AD_ID'],
          equals('ca-app-pub-1111/ios-rewarded-interstitial'));
      expect(env['IOS_NATIVE_AD_ID'], equals('ca-app-pub-1111/ios-native'));
      expect(env['IOS_APP_OPEN_AD_ID'], equals('ca-app-pub-1111/ios-app-open'));
      expect(env['AOS_BANNER_AD_ID'], equals('ca-app-pub-1111/aos-banner'));
      expect(env['AOS_INTERSTITIAL_AD_ID'],
          equals('ca-app-pub-1111/aos-interstitial'));
      expect(env['AOS_REWARDED_AD_ID'], equals('ca-app-pub-1111/aos-rewarded'));
      expect(env['AOS_REWARDED_INTERSTITIAL_AD_ID'],
          equals('ca-app-pub-1111/aos-rewarded-interstitial'));
      expect(env['AOS_NATIVE_AD_ID'], equals('ca-app-pub-1111/aos-native'));
      expect(env['AOS_APP_OPEN_AD_ID'], equals('ca-app-pub-1111/aos-app-open'));
    });

    test('release allows empty admob.units values (preflight gates later)',
        () async {
      const projectYamlNoUnits = '''
project:
  name: "Test App"
  package_name: com.example.testapp

admob:
  ios_app_id: ""
  android_app_id: ""
''';
      final config = await setUpConfigs(projectYaml: projectYamlNoUnits);

      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      final env = parseEnv(readArtifact('release'));
      for (final key in _adKeys) {
        expect(env, contains(key), reason: '$key must exist even when empty');
        expect(env[key], isEmpty);
      }
    });

    test('release content differs from debug content', () async {
      final config = await setUpConfigs();

      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      expect(readArtifact('release'), isNot(equals(readArtifact('debug'))));
    });

    test('CONTAINER_ID is always emitted with reversed package name',
        () async {
      final config = await setUpConfigs();

      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      for (final mode in ['debug', 'profile', 'release']) {
        final env = parseEnv(readArtifact(mode));
        expect(env['CONTAINER_ID'], equals('iCloud.com.testapp.example.com'));
      }
    });

    test('ads disabled emits zero AD keys', () async {
      const appConfigAdsOff = '''
profile: standard

monetization:
  ads:
    enabled: false
  subscription:
    enabled: false
''';
      final config = await setUpConfigs(appConfigYaml: appConfigAdsOff);

      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      for (final mode in ['debug', 'profile', 'release']) {
        final content = readArtifact(mode);
        expect(content, isNot(contains('_AD_ID')),
            reason: '.env.$mode must not contain AD keys when ads disabled');
      }
    });

    test('SUPABASE_* 키는 어떤 모드에서도 미emit (P1-16.5a 철거 회귀 가드)',
        () async {
      // 과거 services.supabase 스키마가 yaml에 남아 있어도 무시되고
      // SUPABASE_* 키가 emit되지 않아야 한다 (파생 앱 yaml 잔재 방어).
      const appConfigLegacySupabase = '''
profile: standard

services:
  supabase:
    enabled: true
    url: "https://release.supabase.co"
    anon_key: "release-anon-key"

monetization:
  ads:
    enabled: false
  subscription:
    enabled: false
''';
      final config =
          await setUpConfigs(appConfigYaml: appConfigLegacySupabase);

      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      for (final mode in ['debug', 'profile', 'release']) {
        final content = readArtifact(mode);
        expect(content, isNot(contains('SUPABASE_URL')));
        expect(content, isNot(contains('SUPABASE_ANON_KEY')));
      }
    });

    test('IAP subscription keys emitted as the current generator does',
        () async {
      const projectYamlWithIap = '''
project:
  name: "Test App"
  package_name: com.example.testapp

iap:
  subscriptions:
    - id: premium
      products:
        - id: premium_monthly
        - id: premium_yearly
''';
      const appConfigSubs = '''
profile: standard

monetization:
  ads:
    enabled: false
  subscription:
    enabled: true
''';
      final config = await setUpConfigs(
        projectYaml: projectYamlWithIap,
        appConfigYaml: appConfigSubs,
      );

      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      for (final mode in ['debug', 'profile', 'release']) {
        final env = parseEnv(readArtifact(mode));
        expect(env['PREMIUM_MONTHLY'], equals('premium_monthly'));
        expect(env['PREMIUM_YEARLY'], equals('premium_yearly'));
      }
    });

    test('deterministic output: two runs are byte-identical', () async {
      final config = await setUpConfigs();

      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );
      final first = {
        for (final mode in ['debug', 'profile', 'release'])
          mode: readArtifact(mode),
      };

      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );
      for (final mode in ['debug', 'profile', 'release']) {
        expect(readArtifact(mode), equals(first[mode]),
            reason: '.env.$mode must be byte-identical across runs');
      }
    });

    test('no timestamp in artifacts', () async {
      final config = await setUpConfigs();

      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      final datePattern = RegExp(r'\d{4}-\d{2}-\d{2}');
      for (final mode in ['debug', 'profile', 'release']) {
        expect(readArtifact(mode), isNot(matches(datePattern)),
            reason: '.env.$mode must not embed a timestamp');
      }
    });
  });

  group('secret-leak gate', () {
    test('throws when an artifact value equals a true-secret value in .env',
        () async {
      // release 모드가 emit하는 admob unit 값이 root .env의 진짜 시크릿
      // 값과 일치하면 게이트가 막아야 한다 (supabase 철거 후 누출 벡터를
      // admob unit으로 교체 — P1-16.5a).
      const appConfigAdsOn = '''
profile: standard

monetization:
  ads:
    enabled: true
  subscription:
    enabled: false
''';
      File('${tempDir.path}/.env')
          .writeAsStringSync('DEEPL_API_KEY="ca-app-pub-1111/ios-banner"\n');
      final config = await setUpConfigs(appConfigYaml: appConfigAdsOn);

      await expectLater(
        writeRuntimeEnvArtifacts(
          projectRoot: tempDir.path,
          config: config,
        ),
        throwsA(isA<SecretLeakException>()),
      );
    });

    test('key-name overlap with root .env warns but does not throw',
        () async {
      const appConfigAdsOn = '''
profile: standard

monetization:
  ads:
    enabled: true
  subscription:
    enabled: false
''';
      // Same key NAME as an emitted artifact key, different value +
      // a true secret whose value matches nothing emitted.
      File('${tempDir.path}/.env').writeAsStringSync(
        'IOS_BANNER_AD_ID="ca-app-pub-9999/other-banner"\n'
        'GITHUB_TOKEN="ghp_realsecret"\n',
      );
      final config = await setUpConfigs(appConfigYaml: appConfigAdsOn);

      final written = await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      expect(written, hasLength(3));
    });

    test('empty secret values never trigger the gate', () async {
      File('${tempDir.path}/.env').writeAsStringSync(
        'KEYSTORE_PASSWORD=""\nKEY_PASSWORD=""\nGITHUB_TOKEN=""\n',
      );
      final config = await setUpConfigs();

      final written = await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      expect(written, hasLength(3));
    });
  });

  group('admob units migration helper', () {
    Future<void> writeExistingRelease(String content) async {
      final envDir = Directory('${tempDir.path}/app/config/env');
      if (!envDir.existsSync()) {
        envDir.createSync(recursive: true);
      }
      File('${envDir.path}/.env.release').writeAsStringSync(content);
    }

    test(
        'prints paste-ready YAML block with existing real IDs '
        'when admob.units is all empty', () async {
      final config = await setUpConfigs(projectYaml: _projectYamlNoUnits);
      await writeExistingRelease('''
CONTAINER_ID=iCloud.com.testapp.example.com
IOS_BANNER_AD_ID=ca-app-pub-7777/real-ios-banner
IOS_INTERSTITIAL_AD_ID=ca-app-pub-7777/real-ios-interstitial
AOS_BANNER_AD_ID=ca-app-pub-7777/real-aos-banner
''');
      final sink = StringBuffer();

      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
        messageSink: sink,
      );

      final output = sink.toString();
      expect(output,
          contains('기존 .env.release에서 실제 광고 단위 ID를 발견했습니다'));
      expect(output, contains('project.yaml admob.units에 붙여넣으세요'));
      // Paste-ready YAML block with existing values mapped to yaml keys
      expect(output, contains('admob:'));
      expect(output, contains('  units:'));
      expect(output, contains('    ios:'));
      expect(output,
          contains('      banner: "ca-app-pub-7777/real-ios-banner"'));
      expect(
          output,
          contains(
              '      interstitial: "ca-app-pub-7777/real-ios-interstitial"'));
      expect(output, contains('    android:'));
      expect(output,
          contains('      banner: "ca-app-pub-7777/real-aos-banner"'));
      // Keys absent from the existing file are emitted empty
      expect(output, contains('      rewarded: ""'));
      // Normal progression: artifacts still (re)written afterwards
      final env = parseEnv(readArtifact('release'));
      expect(env['IOS_BANNER_AD_ID'], isEmpty,
          reason: 'release artifact must be regenerated from (empty) units');
      expect(readArtifact('release'), contains('AUTO-GENERATED'));
    });

    test('does not print when admob.units already has values', () async {
      final config = await setUpConfigs(); // default fixture: units populated
      await writeExistingRelease(
        'IOS_BANNER_AD_ID=ca-app-pub-7777/real-ios-banner\n',
      );
      final sink = StringBuffer();

      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
        messageSink: sink,
      );

      expect(sink.toString(), isEmpty);
    });

    test('does not print when existing release has only Google test IDs',
        () async {
      final config = await setUpConfigs(projectYaml: _projectYamlNoUnits);
      await writeExistingRelease(
        'IOS_BANNER_AD_ID=ca-app-pub-3940256099942544/2934735716\n'
        'AOS_BANNER_AD_ID=ca-app-pub-3940256099942544/6300978111\n',
      );
      final sink = StringBuffer();

      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
        messageSink: sink,
      );

      expect(sink.toString(), isEmpty);
    });
  });

  group('computeSourceHash / isArtifactFresh', () {
    test('hash is 12 lowercase hex chars and changes when sources change',
        () async {
      await setUpConfigs();
      final hash1 = computeSourceHash(tempDir.path);
      expect(hash1, matches(RegExp(r'^[0-9a-f]{12}$')));

      File('${tempDir.path}/project.yaml')
          .writeAsStringSync('$_defaultProjectYaml\n# changed\n');
      final hash2 = computeSourceHash(tempDir.path);
      expect(hash2, isNot(equals(hash1)));
    });

    test('isArtifactFresh matches the embedded source-hash', () async {
      final config = await setUpConfigs();
      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );
      final hash = computeSourceHash(tempDir.path);
      final artifact = File('${tempDir.path}/app/config/env/.env.debug');

      expect(isArtifactFresh(artifact, hash), isTrue);
      expect(isArtifactFresh(artifact, 'deadbeef0000'), isFalse);
      expect(
        isArtifactFresh(File('${tempDir.path}/missing'), hash),
        isFalse,
      );
    });
  });

  group('generateEnvProject merge-preserve', () {
    test('user-added keys in root .env survive regeneration', () async {
      final config = await setUpConfigs();
      const existingEnv = '''
KEYSTORE_PASSWORD="keep-me"
GITHUB_TOKEN="ghp_token"

# 사용자 메모: 커스텀 키
MY_CUSTOM_KEY=hello-world
GOOGLE_CLOUD_AUTH_TOKEN="ya29.machine-written"
''';

      final regenerated = config.generateEnvProject(existingEnv: existingEnv);

      // Managed keys re-emitted with preserved values
      expect(regenerated, contains('KEYSTORE_PASSWORD="keep-me"'));
      expect(regenerated, contains('GITHUB_TOKEN="ghp_token"'));
      // Unmanaged keys preserved verbatim
      expect(regenerated, contains('MY_CUSTOM_KEY=hello-world'));
      expect(regenerated,
          contains('GOOGLE_CLOUD_AUTH_TOKEN="ya29.machine-written"'));
      // Best-effort comment preservation for unmanaged keys
      expect(regenerated, contains('# 사용자 메모: 커스텀 키'));
    });

    test('regeneration is idempotent for preserved keys', () async {
      final config = await setUpConfigs();
      const existingEnv = 'MY_CUSTOM_KEY=hello-world\n';

      final once = config.generateEnvProject(existingEnv: existingEnv);
      final twice = config.generateEnvProject(existingEnv: once);

      expect(twice, equals(once));
    });
  });

  group('ConfigLoader getters', () {
    test('admobUnitId reads admob.units.<platform>.<type> with empty default',
        () async {
      final config = await setUpConfigs();

      expect(config.admobUnitId('ios', 'banner'),
          equals('ca-app-pub-1111/ios-banner'));
      expect(config.admobUnitId('android', 'app_open'),
          equals('ca-app-pub-1111/aos-app-open'));
      expect(config.admobUnitId('ios', 'nonexistent'), isEmpty);
    });
  });

  group('boot config keys (P0-4)', () {
    test('emits APP_PROFILE in all three modes', () async {
      final config = await setUpConfigs();

      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      for (final mode in ['debug', 'profile', 'release']) {
        final env = parseEnv(readArtifact(mode));
        expect(env['APP_PROFILE'], equals('standard'),
            reason: '.env.$mode must carry APP_PROFILE');
      }
    });

    test('emits FF_ overrides converted to AppFeatureConfig field names',
        () async {
      final config = await setUpConfigs(appConfigYaml: '''
profile: premium

features:
  force_update: true
  isAdsEnabled: false

services:
  firebase:
    enabled: false

monetization:
  ads:
    enabled: false
''');

      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      final env = parseEnv(readArtifact('release'));
      expect(env['APP_PROFILE'], equals('premium'));
      expect(env['FF_isForceUpdateEnabled'], equals('true'),
          reason: 'snake_case 키는 is<Pascal>Enabled로 변환');
      expect(env['FF_isAdsEnabled'], equals('false'),
          reason: 'is* 키는 그대로 사용');
    });

    test('featureFlagFieldName conversion rules', () {
      expect(featureFlagFieldName('force_update'),
          equals('isForceUpdateEnabled'));
      expect(featureFlagFieldName('privacy_consent'),
          equals('isPrivacyConsentEnabled'));
      expect(featureFlagFieldName('isAdsEnabled'), equals('isAdsEnabled'));
    });

    test('non-mechanical feature keys map to explicit field names (B3)', () {
      // 기계적 PascalCase로는 틀리는 4개 — 명시 매핑이 없으면 무음 no-op.
      expect(featureFlagFieldName('biometric'), 'isBiometricAuthEnabled');
      expect(featureFlagFieldName('abTesting'), 'isABTestingEnabled');
      expect(featureFlagFieldName('crashReporting'),
          'isFirebaseCrashlyticsEnabled');
      expect(featureFlagFieldName('splashAd'), 'isSplashInterstitialAdEnabled');
    });

    test('every CLI feature key maps to a real AppFeatureConfig field', () {
      // feature_cli/lib/feature_definitions.dart의 토글 가능 키 전수.
      // 새 feature 추가 시 이 목록도 갱신 — drift 시 이 테스트가 잡는다.
      const cliFeatureKeys = [
        'ads', 'subscription', 'firebase', 'notification', 'biometric',
        'location', 'onboarding', 'reEngagement', 'reminder',
        'backgroundNotification', 'darkMode', 'multiLanguage', 'abTesting',
        'crashReporting', 'splashAd',
      ];
      // app_feature_config.dart의 _fields 키 집합 추출 (SSOT).
      final cfg = File('../../app/lib/config/app_feature_config.dart');
      if (!cfg.existsSync()) {
        // tools/cli 외 컨텍스트에서 실행 시 skip (경로 의존 회피).
        return;
      }
      final body = cfg.readAsStringSync();
      final fieldKeys = RegExp(r"'(is[A-Za-z]+Enabled)':\s*_FieldAccessor")
          .allMatches(body)
          .map((m) => m.group(1)!)
          .toSet();
      expect(fieldKeys, isNotEmpty,
          reason: 'app_feature_config _fields 파싱 실패');
      for (final key in cliFeatureKeys) {
        final field = featureFlagFieldName(key);
        expect(fieldKeys, contains(field),
            reason: 'CLI feature "$key" → "$field" 가 _fields에 없음 '
                '(무음 no-op 위험)');
      }
    });
  });
}
