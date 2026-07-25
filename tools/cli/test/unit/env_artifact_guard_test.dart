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

/// ios.banner = Google 테스트 ID, android.banner = 빈 값 — 게이트 대상 2개.
const _badUnitsProjectYaml = '''
project:
  name: "Test App"
  package_name: com.example.testapp
  version: "1.0.0"

admob:
  ios_app_id: "ca-app-pub-1111~1111"
  android_app_id: "ca-app-pub-1111~2222"
  units:
    ios:
      banner: "ca-app-pub-3940256099942544/2934735716"
      interstitial: "ca-app-pub-1111/ios-interstitial"
      rewarded: "ca-app-pub-1111/ios-rewarded"
      rewarded_interstitial: "ca-app-pub-1111/ios-rewarded-interstitial"
      native: "ca-app-pub-1111/ios-native"
      app_open: "ca-app-pub-1111/ios-app-open"
    android:
      banner: ""
      interstitial: "ca-app-pub-1111/aos-interstitial"
      rewarded: "ca-app-pub-1111/aos-rewarded"
      rewarded_interstitial: "ca-app-pub-1111/aos-rewarded-interstitial"
      native: "ca-app-pub-1111/aos-native"
      app_open: "ca-app-pub-1111/aos-app-open"
''';

/// 파생 앱이 템플릿의 boilerplate-2024 privacy URL을 그대로 복사한 경우.
const _stolenPrivacyUrlProjectYaml = '''
project:
  name: "Test App"
  package_name: com.example.testapp
  version: "1.0.0"

listing:
  privacy_policy_url: "https://boilerplate-2024.web.app/privacy_policy.html"
''';

const _adsEnabledAppConfigYaml = '''
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

const _adsDisabledAppConfigYaml = '''
profile: standard

services:
  firebase:
    enabled: false

monetization:
  ads:
    enabled: false
  subscription:
    enabled: false
''';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('env_artifact_guard_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<ConfigLoader> setUpConfigs({
    String projectYaml = _defaultProjectYaml,
    String appConfigYaml = _adsEnabledAppConfigYaml,
  }) async {
    File('${tempDir.path}/project.yaml').writeAsStringSync(projectYaml);
    File('${tempDir.path}/app_config.yaml').writeAsStringSync(appConfigYaml);
    final config = ConfigLoader('${tempDir.path}/app_config.yaml');
    await config.load();
    return config;
  }

  List<RuntimeEnvArtifactIssue> runGuard(ConfigLoader config) =>
      checkRuntimeEnvArtifacts(projectRoot: tempDir.path, config: config);

  List<RuntimeEnvArtifactIssue> failuresOf(
          List<RuntimeEnvArtifactIssue> issues) =>
      issues
          .where((i) => i.severity == ArtifactIssueSeverity.fail)
          .toList();

  group('checkRuntimeEnvArtifacts', () {
    test('fails for each of the 3 missing artifacts', () async {
      final config = await setUpConfigs();

      final failures = failuresOf(runGuard(config));

      expect(failures, hasLength(3));
      final messages = failures.map((i) => i.message).join('\n');
      expect(messages, contains('.env.debug'));
      expect(messages, contains('.env.profile'));
      expect(messages, contains('.env.release'));
      expect(messages, contains('없습니다'));
    });

    test('passes with fresh artifacts and real release ad IDs', () async {
      final config = await setUpConfigs();
      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      expect(runGuard(config), isEmpty);
    });

    test('fails as stale when sources change after generation', () async {
      final config = await setUpConfigs();
      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      // 소스 변경 → source-hash 불일치
      File('${tempDir.path}/app_config.yaml')
          .writeAsStringSync('$_adsEnabledAppConfigYaml\n# changed\n');
      final changedConfig = ConfigLoader('${tempDir.path}/app_config.yaml');
      await changedConfig.load();

      final failures = failuresOf(runGuard(changedConfig));

      expect(failures, hasLength(3));
      for (final issue in failures) {
        expect(issue.message, contains('stale'));
      }
    });

    test(
        'fails listing exact keys when release has empty or Google test IDs '
        'and ads are enabled', () async {
      final config = await setUpConfigs(projectYaml: _badUnitsProjectYaml);
      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      final failures = failuresOf(runGuard(config));

      expect(failures, hasLength(1));
      final message = failures.single.message;
      expect(message, contains('IOS_BANNER_AD_ID'));
      expect(message, contains('AOS_BANNER_AD_ID'));
      expect(message, isNot(contains('IOS_INTERSTITIAL_AD_ID')));
      expect(message, isNot(contains('AOS_NATIVE_AD_ID')));
    });

    test('does not gate ad keys when ads are disabled', () async {
      final config = await setUpConfigs(
        projectYaml: _badUnitsProjectYaml,
        appConfigYaml: _adsDisabledAppConfigYaml,
      );
      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      expect(runGuard(config), isEmpty);
    });

    test(
        'fails when release privacy URL points to the boilerplate template '
        'domain', () async {
      final config = await setUpConfigs(
        projectYaml: _stolenPrivacyUrlProjectYaml,
        appConfigYaml: _adsDisabledAppConfigYaml,
      );
      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      final failures = failuresOf(runGuard(config));

      expect(failures, hasLength(1));
      final message = failures.single.message;
      expect(message, contains('PRIVACY_POLICY_URL'));
      expect(message, contains('boilerplate-2024.web.app'));
      expect(message, contains('deploy-legal'));
    });

    test(
        'fails when empty privacy_policy_url derives the template domain '
        'from a stale google-services.json (E2E headline path)', () async {
      // 실사고 경로: 파생 앱이 privacy_policy_url을 비워둔 채 커밋된
      // boilerplate-2024 google-services.json이 남아 있으면 deriveLegalUrl이
      // 템플릿 도메인을 도출해 release 산출물에 주입된다.
      final config = await setUpConfigs(
        appConfigYaml: _adsDisabledAppConfigYaml,
      );
      File('${tempDir.path}/app/android/app/google-services.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(
            '{"project_info": {"project_id": "boilerplate-2024"}}');
      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      final failures = failuresOf(runGuard(config));

      expect(failures, hasLength(2)); // PRIVACY + TERMS 둘 다 도출됨
      final messages = failures.map((i) => i.message).join('\n');
      expect(messages, contains('PRIVACY_POLICY_URL'));
      expect(messages, contains('TERMS_OF_SERVICE_URL'));
      expect(messages, contains('boilerplate-2024.web.app'));
    });

    test('fails when an artifact value matches a root .env secret', () async {
      final config = await setUpConfigs();
      await writeRuntimeEnvArtifacts(
        projectRoot: tempDir.path,
        config: config,
      );

      // 생성 후 root .env에 산출물 값과 동일한 시크릿 추가 (작성기 게이트 우회)
      File('${tempDir.path}/.env')
          .writeAsStringSync('KEYSTORE_PASSWORD=ca-app-pub-1111/ios-banner\n');

      final failures = failuresOf(runGuard(config));

      expect(failures, hasLength(1));
      expect(failures.single.message, contains('KEYSTORE_PASSWORD'));
      expect(failures.single.message, contains('IOS_BANNER_AD_ID'));
    });
  });

  group('runtimeAdEnvKeys', () {
    test('contains the 12 runtime AD keys', () {
      expect(runtimeAdEnvKeys, hasLength(12));
      expect(runtimeAdEnvKeys, contains('IOS_BANNER_AD_ID'));
      expect(runtimeAdEnvKeys, contains('AOS_APP_OPEN_AD_ID'));
    });
  });
}
