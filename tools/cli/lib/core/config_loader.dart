import 'dart:io';

import 'package:yaml/yaml.dart';

/// Loads and merges app_config.yaml + project.yaml
class ConfigLoader {
  final String configPath;
  // late final 금지 — applyProfileStep writeback 후 load() 재호출이 필요 (P0-4)
  late Map<String, dynamic> _config;

  ConfigLoader(this.configPath);

  /// Load and parse both config files, merging into a single map.
  /// project.yaml is loaded from the same directory as configPath.
  Future<void> load() async {
    final configFile = File(configPath);
    if (!configFile.existsSync()) {
      throw Exception('Config file not found: $configPath');
    }

    final configDir = configFile.parent.path;
    final projectFile = File('$configDir/project.yaml');

    // Load app_config.yaml
    final configContent = await configFile.readAsString();
    final configYaml = loadYaml(configContent);
    _config = _yamlToMap(configYaml);

    // Load and merge project.yaml
    if (projectFile.existsSync()) {
      final projectContent = await projectFile.readAsString();
      final projectYaml = loadYaml(projectContent);
      final projectMap = _yamlToMap(projectYaml);
      _deepMerge(_config, projectMap);
    }
  }

  /// Deep merge source into target (source wins on conflicts)
  void _deepMerge(Map<String, dynamic> target, Map<String, dynamic> source) {
    for (final key in source.keys) {
      if (target.containsKey(key) &&
          target[key] is Map &&
          source[key] is Map) {
        _deepMerge(
          target[key] as Map<String, dynamic>,
          source[key] as Map<String, dynamic>,
        );
      } else {
        target[key] = source[key];
      }
    }
  }

  Map<String, dynamic> _yamlToMap(dynamic yaml) {
    if (yaml is YamlMap) {
      return yaml.map(
          (key, value) => MapEntry(key.toString(), _yamlToMap(value)));
    }
    if (yaml is YamlList) {
      return {'_list': yaml.map(_yamlToMap).toList()};
    }
    return {'_value': yaml};
  }

  // ── Project (from project.yaml) ──
  String get appName => _getString('project.name', 'My App');
  // company_name: app_config.yaml 우선, project.yaml 폴백
  String get companyName {
    final fromConfig = _getString('company_name', '');
    if (fromConfig.isNotEmpty) return fromConfig;
    return _getString('project.company_name', '');
  }

  String get packageName =>
      _getString('project.package_name', 'com.example.myapp');
  String get description => _getString('project.description', '');
  String get category => _getString('project.category', 'productivity');
  String get version => _getString('project.version', '1.0.0');
  String get githubRepository =>
      _getString('project.github_repository', '');

  // ── Platform (from app_config.yaml) ──
  String get profile => _getString('profile', 'standard');
  String get iosTeamId => _getString('platforms.ios.team_id', '');
  String get iosBundleId =>
      _getString('platforms.ios.bundle_id', packageName);
  String get androidPackage =>
      _getString('platforms.android.package', packageName);
  // keystore/keyAlias는 템플릿이 signing.android.* 아래에 두지만, 일부 설정은
  // platforms.android.* 를 쓴다. env_loader.rb가 두 경로를 모두 읽으므로 deploy/
  // preflight 게이트도 동일하게 폴백해, 올바르게 설정된 fork가 오탐 차단되지
  // 않도록 한다.
  String get keystorePath {
    final fromPlatforms = _getString('platforms.android.keystore_path', '');
    if (fromPlatforms.isNotEmpty) return fromPlatforms;
    return _getString('signing.android.keystore_path', '');
  }

  String get keyAlias {
    final fromPlatforms = _getString('platforms.android.key_alias', '');
    if (fromPlatforms.isNotEmpty) return fromPlatforms;
    return _getString('signing.android.key_alias', 'android_signing_key');
  }

  // ── Services (from app_config.yaml) ──
  bool get firebaseEnabled => _getBool('services.firebase.enabled', true);
  String get firebaseProjectId =>
      _getString('services.firebase.project_id', '');
  String get firebaseServiceAccountFile =>
      _getString('services.firebase.service_account_file', '');
  String get firebaseServiceAccountEmail =>
      _getString('services.firebase.service_account_email', '');
  String get firebaseTesterGroups =>
      _getString('services.firebase.tester_groups', 'qa-testers');
  String get firebaseTesters =>
      _getString('services.firebase.testers', '');
  // (services.supabase 스키마는 P1-16.5a에서 철거됨 — docs/MODULES.md §5)

  // ── Monetization (from app_config.yaml) ──
  bool get adsEnabled => _getBool('monetization.ads.enabled', false);
  bool get subscriptionEnabled =>
      _getBool('monetization.subscription.enabled', false);

  // ── AdMob (from project.yaml) ──
  /// 광고 유닛 ID — admob.units.<platform>.<type> (release 빌드용 실제 값).
  ///
  /// [platform]: 'ios' | 'android'
  /// [type]: 'banner' | 'interstitial' | 'rewarded' |
  ///         'rewarded_interstitial' | 'native' | 'app_open'
  String admobUnitId(String platform, String type) =>
      _getString('admob.units.$platform.$type', '');

  // ── 구독 화면 카피 (from project.yaml, P1-15) ──
  String get subscriptionHeadlineCopy =>
      _getString('iap.headline_copy', '');
  String get subscriptionBenefitsCopy =>
      _getString('iap.benefits_copy', '');

  // ── Privacy (from project.yaml) ──
  /// 앱 고유 트래킹 도메인 — PrivacyInfo.xcprivacy NSPrivacyTrackingDomains.
  /// SDK 자체 도메인은 각 SDK의 매니페스트가 선언하므로 여기 넣지 않는다.
  List<String> get trackingDomains =>
      _getStringList('privacy.tracking_domains', []);

  // ── Deep Link (from project.yaml, P2-23a) ──
  /// 커스텀 URL 스킴 (예: 'myapp' → myapp://open/settings). 비면 생성 스킵.
  /// generate-deeplink가 Android intent-filter + iOS CFBundleURLTypes에 주입.
  String get deepLinkScheme => _getString('deep_link.scheme', '');

  /// 유니버설/앱링크 도메인 (Stage 2, 예: ['myapp.web.app']).
  List<String> get deepLinkUniversalLinks =>
      _getStringList('deep_link.universal_links', []);

  // ── Store credentials (from app_config.yaml) ──
  String get appleId => _getString('store.apple.apple_id', '');
  String get apiKeyId => _getString('store.apple.api_key_id', '');
  String get apiIssuerId => _getString('store.apple.api_issuer_id', '');
  String get apiKeyFile => _getString('store.apple.api_key_file', '');
  String get googleJsonKey =>
      _getString('store.google.json_key_file', '');

  // ── Store listing (from project.yaml) ──
  String get shortDescription =>
      _getString('listing.short_description', '');
  List<String> get keywords => _getStringList('listing.keywords', []);
  String get primaryLocale =>
      _getString('listing.primary_locale', 'en-US');
  String get privacyPolicyUrl =>
      _getString('listing.privacy_policy_url', '');
  String get termsOfServiceUrl =>
      _getString('listing.terms_of_service_url', '');

  /// 법적 문서 호스팅 방식: `firebase`(기본) | `github`.
  /// `github`이면 gen_env가 `<owner>.github.io/<repo>` URL을 도출한다 (A1).
  String get legalHosting =>
      _getString('listing.legal_hosting', 'firebase').toLowerCase();
  String get appleAppId => _getString('listing.apple_app_id', '');
  String get supportUrl => _getString('listing.support_url', '');
  String get marketingUrl => _getString('listing.marketing_url', '');
  String get contactEmail => _getString('listing.contact_email', '');
  String get contactWebsite => _getString('listing.contact_website', '');
  String get copyright => _getString('listing.copyright', '');

  // ── Age rating (from project.yaml) ──
  Map<String, int> get ageRating {
    final map = _getMap('age_rating');
    return map.map((k, v) {
      if (v is Map && v.containsKey('_value')) {
        return MapEntry(k, (v['_value'] as num?)?.toInt() ?? 0);
      }
      if (v is int) return MapEntry(k, v);
      if (v is num) return MapEntry(k, v.toInt());
      return MapEntry(k, 0);
    });
  }

  // ── IAP (from project.yaml) ──
  List<dynamic> get iapProducts => _getList('iap.products');
  List<dynamic> get iapSubscriptions => _getList('iap.subscriptions');

  // ── Icon generation (from project.yaml) ──
  String get iconPrompt => _getString('icon.prompt', '');
  String get iconStyle => _getString('icon.style', 'modern');
  String get iconBackgroundColor =>
      _getString('icon.background_color', '#FFFFFF');

  // ── Signing (from app_config.yaml) ──
  String get matchGitUrl => _getString('signing.ios.match_git_url', '');
  String get matchType => _getString('signing.ios.match_type', 'appstore');

  // ── Notifications (from app_config.yaml) ──
  String get discordWebhookUrl =>
      _getString('notifications.discord.webhook_url', '');

  // ── Defaults (from app_config.yaml) ──
  bool get skipScreenshots => _getBool('defaults.skip_screenshots', true);
  bool get enforceCoverage =>
      _getBool('defaults.ci.enforce_coverage', false);
  bool get autoCommitChangelog =>
      _getBool('defaults.ci.auto_commit_changelog', false);
  bool get runAndroidEmulatorTests =>
      _getBool('defaults.testing.run_android_emulator_tests', false);
  bool get setupAdhocCerts =>
      _getBool('defaults.testing.setup_adhoc_certs', false);

  // ── Tooling pins (from project.yaml) ──
  String get fastlaneRef => _getString('tooling.fastlane_ref', 'main');
  String get templateVersion =>
      _getString('tooling.template_version', 'unknown');

  // ── Feature overrides (from app_config.yaml) ──
  Map<String, bool> get featureOverrides {
    final features = _getMap('features');
    final result = <String, bool>{};
    for (final entry in features.entries) {
      // _yamlToMap은 스칼라를 {'_value': v}로 감싼다 — 여기서 unwrap
      final raw = entry.value;
      final value = raw is Map ? raw['_value'] : raw;
      if (value is bool) {
        result[entry.key] = value;
      }
    }
    return result;
  }

  /// generateEnvProject가 직접 관리(재발행)하는 키.
  /// 이 목록에 없는 기존 키=값 줄은 merge-preserve로 그대로 보존됩니다.
  static const Set<String> _managedEnvKeys = {
    'KEYSTORE_PASSWORD',
    'KEY_PASSWORD',
    'MATCH_PASSWORD',
    'GITHUB_TOKEN',
    'DEEPL_API_KEY',
    'OPENAI_API_KEY',
  };

  /// 보존 섹션 헤더 (재생성 시 중복 방지를 위해 파싱에서 제외).
  static const String _preservedSectionHeader =
      '# ── 보존된 키 (generator가 관리하지 않음) ──';

  /// Generate .env file content from config
  ///
  /// Non-secret values are populated from app_config.yaml + project.yaml.
  /// Secret placeholders are left empty for the user to fill in.
  /// Existing secret values in .env are preserved if [existingEnv] is provided.
  ///
  /// Merge-preserve: 관리 키([_managedEnvKeys])는 config 기준으로 재발행하고,
  /// 그 외 기존 키=값 줄(사용자/머신 기록)은 그대로 보존합니다.
  /// 보존 키 바로 위의 주석 줄도 best-effort로 함께 보존됩니다.
  String generateEnvProject({String? existingEnv}) {
    // Parse existing .env: managed key 값 보존 + unmanaged 줄 verbatim 보존
    final existingValues = <String, String>{};
    final preservedLines = <String>[];
    if (existingEnv != null) {
      var commentBuffer = <String>[];
      for (final line in existingEnv.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          commentBuffer = [];
          continue;
        }
        if (trimmed.startsWith('#')) {
          if (trimmed != _preservedSectionHeader) {
            commentBuffer.add(line);
          }
          continue;
        }
        final eqIndex = trimmed.indexOf('=');
        if (eqIndex > 0) {
          final key = trimmed.substring(0, eqIndex);
          var value = trimmed.substring(eqIndex + 1);
          // Strip surrounding quotes
          if ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'"))) {
            value = value.substring(1, value.length - 1);
          }
          existingValues[key] = value;
          if (!_managedEnvKeys.contains(key)) {
            preservedLines
              ..addAll(commentBuffer)
              ..add(line);
          }
        }
        commentBuffer = [];
      }
    }

    String existing(String key) => existingValues[key] ?? '';

    final buffer = StringBuffer();
    buffer.writeln(
        '# 시크릿만 이 파일에서 관리합니다.');
    buffer.writeln(
        '# 프로젝트별 설정 → project.yaml');
    buffer.writeln(
        '# 공통 설정 → app_config.yaml');
    buffer.writeln();

    buffer.writeln(
        '# ============================================');
    buffer.writeln(
        '# 시크릿 (git 미추적)');
    buffer.writeln(
        '# ============================================');
    buffer.writeln();

    buffer.writeln('# Android 서명');
    buffer.writeln(
        'KEYSTORE_PASSWORD="${existing('KEYSTORE_PASSWORD')}"');
    buffer.writeln(
        'KEY_PASSWORD="${existing('KEY_PASSWORD')}"');
    buffer.writeln();

    if (matchGitUrl.isNotEmpty) {
      buffer.writeln('# iOS 서명 (Match)');
      buffer.writeln(
          'MATCH_PASSWORD="${existing('MATCH_PASSWORD')}"');
      buffer.writeln();
    }

    buffer.writeln('# GitHub');
    buffer.writeln(
        'GITHUB_TOKEN="${existing('GITHUB_TOKEN')}"');
    buffer.writeln();

    buffer.writeln('# 외부 서비스 API');
    buffer.writeln(
        'DEEPL_API_KEY="${existing('DEEPL_API_KEY')}"');
    buffer.writeln(
        '# OPENAI_API_KEY="${existing('OPENAI_API_KEY')}"');

    // Merge-preserve: 관리 대상이 아닌 기존 키=값 줄을 그대로 보존
    if (preservedLines.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(_preservedSectionHeader);
      for (final line in preservedLines) {
        buffer.writeln(line);
      }
    }

    return buffer.toString();
  }

  // Helper methods
  String _getString(String path, String defaultValue) {
    final value = _getNestedValue(path);
    return value?.toString() ?? defaultValue;
  }

  bool _getBool(String path, bool defaultValue) {
    final value = _getNestedValue(path);
    if (value is bool) return value;
    return defaultValue;
  }

  Map<String, dynamic> _getMap(String path) {
    final value = _getNestedValue(path);
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  List<String> _getStringList(String path, List<String> defaultValue) {
    final list = _getList(path);
    if (list.isEmpty) return defaultValue;
    // _yamlToMap이 스칼라를 {'_value': x}로 감싸므로 리스트 원소도 언래핑한다
    // (스칼라 경로는 _getNestedValue가 풀지만 리스트 원소는 풀리지 않음).
    return list.map((e) {
      if (e is Map && e.containsKey('_value')) return e['_value'].toString();
      return e.toString();
    }).toList();
  }

  List<dynamic> _getList(String path) {
    final value = _getNestedValue(path);
    if (value is List) return value;
    final mapValue = _getNestedValue('$path._list');
    if (mapValue is List) return mapValue;
    return [];
  }

  dynamic _getNestedValue(String path) {
    final keys = path.split('.');
    dynamic current = _config;
    for (final key in keys) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }
    if (current is Map && current.containsKey('_value')) {
      return current['_value'];
    }
    return current;
  }
}
