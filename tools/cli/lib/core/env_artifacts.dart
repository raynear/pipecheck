import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'config_loader.dart';

/// Single writer for the runtime env artifacts:
/// `app/config/env/.env.{debug,profile,release}`.
///
/// 산출물은 순수 생성물입니다 — 손 편집 금지, gitignore, 매 빌드마다 재생성.
/// 키 계약은 앱 런타임이 읽는 키 이름과 byte-exact로 일치해야 합니다
/// (`ad_service.dart`의 `{IOS|AOS}_{TYPE}_AD_ID`, `CONTAINER_ID`, IAP 키).

/// Google 공식 공개 테스트 광고 유닛 ID, keyed [platform][type].
///
/// debug/profile 빌드는 항상 이 값을 사용합니다 (yaml에 적지 않음).
/// https://developers.google.com/admob/android/test-ads
/// https://developers.google.com/admob/ios/test-ads
const Map<String, Map<String, String>> admobTestUnitIds = {
  'ios': {
    'banner': 'ca-app-pub-3940256099942544/2934735716',
    'interstitial': 'ca-app-pub-3940256099942544/4411468910',
    'rewarded': 'ca-app-pub-3940256099942544/1712485313',
    'rewarded_interstitial': 'ca-app-pub-3940256099942544/6978759866',
    'native': 'ca-app-pub-3940256099942544/3986624511',
    'app_open': 'ca-app-pub-3940256099942544/5575463023',
  },
  'android': {
    'banner': 'ca-app-pub-3940256099942544/6300978111',
    'interstitial': 'ca-app-pub-3940256099942544/1033173712',
    'rewarded': 'ca-app-pub-3940256099942544/5224354917',
    'rewarded_interstitial': 'ca-app-pub-3940256099942544/5354046379',
    'native': 'ca-app-pub-3940256099942544/2247696110',
    'app_open': 'ca-app-pub-3940256099942544/9257395921',
  },
};

/// 생성 대상 모드 (파일명: `.env.<mode>`).
const List<String> runtimeEnvModes = ['debug', 'profile', 'release'];

/// Google 테스트 광고 퍼블리셔 ID prefix — release 산출물에 있으면 안 됨.
const String googleTestAdvertiserId = 'ca-app-pub-3940256099942544';

/// 템플릿 소유 Firebase 프로젝트 ID. 파생 앱의 release 산출물 법적 URL이
/// 이 도메인(`<id>.web.app`)을 가리키면 — 빈 privacy_policy_url이 stale한
/// google-services.json에서 도출됐거나 템플릿 URL을 그대로 복사한 것 —
/// 남의 도메인 개인정보 URL로 출시된다. release 게이트가 차단한다.
const String boilerplateFirebaseProjectId = 'boilerplate-2024';

/// 광고 유닛 타입 (emit 순서 고정 — 결정적 출력).
const List<String> _adTypes = [
  'banner',
  'interstitial',
  'rewarded',
  'rewarded_interstitial',
  'native',
  'app_open',
];

/// 런타임 키 prefix 매핑: ad_service.dart는 `IOS_`/`AOS_`를 읽음.
const Map<String, String> _adKeyPrefix = {'ios': 'IOS', 'android': 'AOS'};

/// 12개 런타임 AD 키 (`IOS_`/`AOS_` × 6종) — release 광고 게이트가 사용.
final List<String> runtimeAdEnvKeys = List.unmodifiable([
  for (final platform in ['ios', 'android'])
    for (final type in _adTypes)
      '${_adKeyPrefix[platform]}_${type.toUpperCase()}_AD_ID',
]);

/// root `.env`의 알려진 진짜 시크릿 키 — 산출물 값이 이 키들의 값과
/// 일치하면 시크릿 누출로 간주하고 FAIL.
const List<String> knownSecretEnvKeys = [
  'KEYSTORE_PASSWORD',
  'KEY_PASSWORD',
  'MATCH_PASSWORD',
  'GITHUB_TOKEN',
  'DEEPL_API_KEY',
  'OPENAI_API_KEY',
  'GOOGLE_CLOUD_AUTH_TOKEN',
];

/// 시크릿 값이 런타임 산출물(앱 번들 포함)로 누출될 때 발생.
class SecretLeakException implements Exception {
  SecretLeakException(this.message);

  final String message;

  @override
  String toString() => 'SecretLeakException: $message';
}

/// sha256(project.yaml bytes + app_config.yaml bytes)의 앞 12 hex.
///
/// 산출물 헤더의 `source-hash`와 비교해 staleness를 감지합니다
/// (타임스탬프 없이 결정적 출력 유지). 파일이 없으면 빈 바이트로 취급.
String computeSourceHash(String projectRoot) {
  final bytes = <int>[];
  final projectFile = File('$projectRoot/project.yaml');
  if (projectFile.existsSync()) {
    bytes.addAll(projectFile.readAsBytesSync());
  }
  final appConfigFile = File('$projectRoot/app_config.yaml');
  if (appConfigFile.existsSync()) {
    bytes.addAll(appConfigFile.readAsBytesSync());
  }
  return sha256.convert(bytes).toString().substring(0, 12);
}

/// [artifact]의 `# source-hash:` 헤더가 [hash]와 일치하면 true.
///
/// preflight/deploy가 재생성 필요 여부 판단에 사용합니다.
bool isArtifactFresh(File artifact, String hash) {
  if (!artifact.existsSync()) return false;
  for (final line in artifact.readAsLinesSync()) {
    final match = _sourceHashPattern.firstMatch(line);
    if (match != null) {
      return match.group(1) == hash;
    }
  }
  return false;
}

final RegExp _sourceHashPattern = RegExp(r'^# source-hash: ([0-9a-f]{12})$');

/// `app/config/env/.env.{debug,profile,release}` 3개를 모드별로 독립 생성.
///
/// - `CONTAINER_ID`: 항상 emit.
/// - 12개 AD 키: `monetization.ads.enabled`일 때만.
///   debug/profile → [admobTestUnitIds], release → `admob.units` 값 그대로
///   (빈 문자열 허용 — release 게이트는 preflight 담당).
/// - IAP 키: 기존 생성기와 동일하게 emit.
/// - `SUPABASE_*` 키는 P1-16.5a 철거 후 어떤 모드에서도 emit하지 않는다.
///
/// 시크릿 누출 게이트: 산출물 값이 root `.env`의 [knownSecretEnvKeys] 값과
/// 일치하면 [SecretLeakException]. 키 이름 중복은 stderr WARN만.
///
/// 일회성 마이그레이션 도우미 (plan §2.2): 덮어쓰기 **전에** 기존
/// `.env.release`에서 실값 광고 ID를 발견했고 `admob.units`가 전부 비어
/// 있으면, project.yaml에 붙여넣을 YAML 블록을 [messageSink](기본 stderr)에
/// 안내한 뒤 정상 진행합니다 — 파생 앱의 값 소실 창 제거.
///
/// Returns: 생성된 파일 경로 목록 (debug, profile, release 순).
Future<List<String>> writeRuntimeEnvArtifacts({
  required String projectRoot,
  required ConfigLoader config,
  String? appDir,
  StringSink? messageSink,
}) async {
  final resolvedAppDir = appDir ?? '$projectRoot/app';
  final hash = computeSourceHash(projectRoot);
  final rootEnv = parseEnvFile(File('$projectRoot/.env'));

  // 일회성 마이그레이션 도우미 — 반드시 덮어쓰기 전에 실행
  final migrationYaml = buildAdmobUnitsMigrationYaml(
    existingRelease: File('$resolvedAppDir/config/env/.env.release'),
    config: config,
  );
  if (migrationYaml != null) {
    final sink = messageSink ?? stderr;
    sink.writeln(
        '기존 .env.release에서 실제 광고 단위 ID를 발견했습니다. '
        '아래 블록을 project.yaml admob.units에 붙여넣으세요:');
    sink.write(migrationYaml);
  }

  // 모드별 엔트리를 먼저 전부 만든 뒤 게이트 → 파일 쓰기 (부분 쓰기 방지)
  final contents = <String, String>{};
  for (final mode in runtimeEnvModes) {
    final sections = _artifactSections(
        mode: mode, config: config, projectRoot: projectRoot);
    _checkSecretLeak(mode: mode, sections: sections, rootEnv: rootEnv);
    contents[mode] = _render(mode: mode, hash: hash, sections: sections);
  }

  final envDir = Directory('$resolvedAppDir/config/env');
  if (!envDir.existsSync()) {
    envDir.createSync(recursive: true);
  }

  final written = <String>[];
  for (final mode in runtimeEnvModes) {
    final path = '${envDir.path}/.env.$mode';
    await File(path).writeAsString(contents[mode]!);
    written.add(path);
  }
  return written;
}

/// 일회성 마이그레이션 도우미 (plan §2.2).
///
/// 아래 조건이 **모두** 참이면 project.yaml에 붙여넣을 `admob.units` YAML
/// 블록을 반환, 아니면 null:
/// 1. [existingRelease] 파일 존재
/// 2. 12개 `{IOS|AOS}_*_AD_ID` 키 중 하나라도 비어 있지 않고
///    Google 테스트 ID([googleTestAdvertiserId])가 아닌 실값 보유
/// 3. [config]의 `admob.units`가 전부 빈 값 (아직 마이그레이션 안 됨)
///
/// 기존 값은 verbatim으로 매핑됩니다 (`IOS_BANNER_AD_ID` → `ios.banner` 등,
/// 기존 파일에 없는 키는 빈 문자열). 테스트 ID가 섞여 있어도 그대로
/// 출력합니다 — release 게이트([checkRuntimeEnvArtifacts] ③)가 차단합니다.
String? buildAdmobUnitsMigrationYaml({
  required File existingRelease,
  required ConfigLoader config,
}) {
  // 조건 1: 기존 release 산출물 존재
  if (!existingRelease.existsSync()) return null;

  // 조건 3: admob.units 전부 빈 값 (하나라도 있으면 이미 포팅됨)
  for (final platform in ['ios', 'android']) {
    for (final type in _adTypes) {
      if (config.admobUnitId(platform, type).isNotEmpty) return null;
    }
  }

  // 조건 2: 비어있지 않고 테스트 ID가 아닌 실값 하나 이상
  final existing = parseEnvFile(existingRelease);
  var hasRealValue = false;
  final units = <String, Map<String, String>>{};
  for (final platform in ['ios', 'android']) {
    final platformUnits = <String, String>{};
    for (final type in _adTypes) {
      final value =
          existing['${_adKeyPrefix[platform]}_${type.toUpperCase()}_AD_ID'] ??
              '';
      platformUnits[type] = value;
      if (value.isNotEmpty && !value.contains(googleTestAdvertiserId)) {
        hasRealValue = true;
      }
    }
    units[platform] = platformUnits;
  }
  if (!hasRealValue) return null;

  final buffer = StringBuffer();
  buffer.writeln('admob:');
  buffer.writeln('  units:');
  for (final platform in ['ios', 'android']) {
    buffer.writeln('    $platform:');
    for (final type in _adTypes) {
      buffer.writeln('      $type: "${units[platform]![type]}"');
    }
  }
  return buffer.toString();
}

/// 모드별 key=value 섹션 빌드 (섹션 사이는 빈 줄로 구분 — 결정적 순서).
List<List<MapEntry<String, String>>> _artifactSections({
  required String mode,
  required ConfigLoader config,
  required String projectRoot,
}) {
  final isRelease = mode == 'release';
  final sections = <List<MapEntry<String, String>>>[];

  // CONTAINER_ID — 항상 (기존 generateEnvDebug와 동일한 값 계산)
  sections.add([
    MapEntry(
      'CONTAINER_ID',
      'iCloud.com.${config.packageName.split('.').reversed.join('.')}',
    ),
  ]);

  // 부팅 설정 — app_config.yaml profile + features 오버라이드 (P0-4).
  // 앱은 서비스 초기화 전에 APP_PROFILE로 프로필을 적용하고 FF_* 키로
  // 개별 플래그를 덮어쓴다. 모드 무관 동일 값.
  final bootSection = <MapEntry<String, String>>[
    MapEntry('APP_PROFILE', config.profile),
    // crash 리포트 분류용 (P1-14c) — Crashlytics setCustomKey로 노출
    MapEntry('TEMPLATE_VERSION', config.templateVersion),
  ];
  for (final entry in config.featureOverrides.entries) {
    bootSection.add(MapEntry(
      'FF_${featureFlagFieldName(entry.key)}',
      entry.value.toString(),
    ));
  }
  sections.add(bootSection);

  // 앱 정체성/카피 (P1-15) — 앱 코드 하드코딩 제거. 모드 무관 동일 값.
  // privacy/terms URL은 비어 있으면 Firebase Hosting 컨벤션(P1-15.5b,
  // docs/legal/ → ./run deploy-legal)으로 프로젝트 ID에서 도출한다.
  sections.add(<MapEntry<String, String>>[
    MapEntry(
        'PRIVACY_POLICY_URL',
        config.privacyPolicyUrl.isNotEmpty
            ? config.privacyPolicyUrl
            : deriveLegalUrl(config, projectRoot, 'privacy_policy.html')),
    MapEntry(
        'TERMS_OF_SERVICE_URL',
        config.termsOfServiceUrl.isNotEmpty
            ? config.termsOfServiceUrl
            : deriveLegalUrl(config, projectRoot, 'terms_of_service.html')),
    MapEntry('APPLE_APP_STORE_ID', config.appleAppId),
    MapEntry('SUBSCRIPTION_HEADLINE', config.subscriptionHeadlineCopy),
    MapEntry('SUBSCRIPTION_BENEFITS', config.subscriptionBenefitsCopy),
  ]);

  // AD 키 12개 — ads enabled일 때만
  if (config.adsEnabled) {
    final adSection = <MapEntry<String, String>>[];
    for (final platform in ['ios', 'android']) {
      for (final type in _adTypes) {
        final value = isRelease
            ? config.admobUnitId(platform, type)
            : admobTestUnitIds[platform]![type]!;
        adSection.add(MapEntry(
          '${_adKeyPrefix[platform]}_${type.toUpperCase()}_AD_ID',
          value,
        ));
      }
    }
    sections.add(adSection);
  }

  // IAP — 기존 generateEnvDebug와 byte-exact 동일한 키/값 규칙
  if (config.subscriptionEnabled) {
    final iapSection = <MapEntry<String, String>>[];
    for (final sub in config.iapSubscriptions) {
      if (sub is Map) {
        final subProducts = sub['products'];
        if (subProducts is Map && subProducts.containsKey('_list')) {
          for (final p in subProducts['_list'] as List) {
            if (p is Map) {
              final id = p['id']?['_value'] ?? '';
              iapSection.add(MapEntry(
                id.toString().split('.').last.toUpperCase(),
                id.toString(),
              ));
            }
          }
        }
      }
    }
    if (iapSection.isNotEmpty) {
      sections.add(iapSection);
    }
  }

  return sections;
}

/// 헤더(plan §2.2: AUTO-GENERATED 블록 + mode + source-hash, 타임스탬프 없음)
/// + 섹션 렌더링.
String _render({
  required String mode,
  required String hash,
  required List<List<MapEntry<String, String>>> sections,
}) {
  final buffer = StringBuffer();
  buffer.writeln('# ============================================');
  buffer.writeln('# AUTO-GENERATED — DO NOT EDIT');
  buffer.writeln('# Source: project.yaml + app_config.yaml');
  buffer.writeln('# mode: $mode');
  buffer.writeln('# source-hash: $hash');
  buffer.writeln('# ============================================');
  for (final section in sections) {
    buffer.writeln();
    for (final entry in section) {
      buffer.writeln('${entry.key}=${entry.value}');
    }
  }
  return buffer.toString();
}

/// 시크릿 누출 게이트.
///
/// - 산출물 **값**이 root `.env`의 [knownSecretEnvKeys] 중 비어있지 않은 값과
///   일치 → [SecretLeakException] (앱 번들에 시크릿이 들어가는 사고 차단).
/// - 키 **이름**이 root `.env`의 키와 중복 → stderr WARN만
///   (이름 교집합 FAIL은 오탐 제조기 — plan §2.2).
void _checkSecretLeak({
  required String mode,
  required List<List<MapEntry<String, String>>> sections,
  required Map<String, String> rootEnv,
}) {
  final secretValues = <String, String>{};
  for (final key in knownSecretEnvKeys) {
    final value = rootEnv[key];
    if (value != null && value.isNotEmpty) {
      secretValues[key] = value;
    }
  }

  for (final section in sections) {
    for (final entry in section) {
      for (final secret in secretValues.entries) {
        if (entry.value == secret.value) {
          throw SecretLeakException(
            '.env.$mode 산출물의 ${entry.key} 값이 root .env의 시크릿 '
            '${secret.key} 값과 동일합니다. 시크릿은 절대 런타임 산출물'
            '(앱 번들 asset)에 들어가면 안 됩니다. project.yaml/'
            'app_config.yaml에서 해당 값을 제거하세요.',
          );
        }
      }
      if (rootEnv.containsKey(entry.key)) {
        stderr.writeln(
          'WARN: .env.$mode 키 ${entry.key}가 root .env에도 존재합니다 '
          '(이름 중복). 런타임은 산출물 값을 사용합니다.',
        );
      }
    }
  }
}

/// `.env` 형식 파일 파싱 (key=value, 따옴표 제거). 없으면 빈 맵.
///
/// 작성기(시크릿 게이트)와 preflight/deploy 가드가 공유합니다.
Map<String, String> parseEnvFile(File file) {
  final values = <String, String>{};
  if (!file.existsSync()) return values;
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final eqIndex = trimmed.indexOf('=');
    if (eqIndex > 0) {
      final key = trimmed.substring(0, eqIndex);
      var value = trimmed.substring(eqIndex + 1);
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.length >= 2 ? value.substring(1, value.length - 1) : '';
      }
      values[key] = value;
    }
  }
  return values;
}

/// 산출물 검증 이슈 심각도.
enum ArtifactIssueSeverity { warn, fail }

/// 단일 산출물 검증 이슈 (immutable).
class RuntimeEnvArtifactIssue {
  const RuntimeEnvArtifactIssue({
    required this.severity,
    required this.message,
  });

  final ArtifactIssueSeverity severity;
  final String message;
}

/// preflight/deploy 가드 (plan §2.3): 3개 산출물 검증. 빈 목록 = 통과.
///
/// - ① 존재: 3개 산출물(.env.{debug,profile,release}) 중 하나라도 없으면 FAIL.
/// - ② 신선도: `# source-hash` 헤더가 [computeSourceHash]와 불일치하면 FAIL.
/// - ③ release 광고 게이트: `monetization.ads.enabled`인데 release 산출물의
///   12개 AD 키([runtimeAdEnvKeys])가 비었거나 Google 테스트 ID
///   ([googleTestAdvertiserId])를 포함하면 해당 키를 나열하며 FAIL.
/// - ④ 시크릿 누출: 산출물 값이 root `.env`의 [knownSecretEnvKeys] 값과
///   일치하면 FAIL (작성기 게이트와 동일 규칙을 on-disk 산출물에 적용).
List<RuntimeEnvArtifactIssue> checkRuntimeEnvArtifacts({
  required String projectRoot,
  required ConfigLoader config,
  String? appDir,
}) {
  final resolvedAppDir = appDir ?? '$projectRoot/app';
  final hash = computeSourceHash(projectRoot);
  final issues = <RuntimeEnvArtifactIssue>[];

  final artifacts = <String, File>{
    for (final mode in runtimeEnvModes)
      mode: File('$resolvedAppDir/config/env/.env.$mode'),
  };

  // ① 존재 + ② source-hash 신선도
  for (final entry in artifacts.entries) {
    if (!entry.value.existsSync()) {
      issues.add(RuntimeEnvArtifactIssue(
        severity: ArtifactIssueSeverity.fail,
        message: '.env.${entry.key} 산출물이 없습니다 (./run gen-env로 생성)',
      ));
    } else if (!isArtifactFresh(entry.value, hash)) {
      issues.add(RuntimeEnvArtifactIssue(
        severity: ArtifactIssueSeverity.fail,
        message: '.env.${entry.key} 산출물이 stale입니다 — source-hash 불일치 '
            '(./run gen-env로 재생성)',
      ));
    }
  }

  // ③ release 광고 게이트
  final releaseArtifact = artifacts['release']!;
  if (config.adsEnabled && releaseArtifact.existsSync()) {
    final releaseEnv = parseEnvFile(releaseArtifact);
    final badKeys = <String>[
      for (final key in runtimeAdEnvKeys)
        if ((releaseEnv[key] ?? '').isEmpty ||
            releaseEnv[key]!.contains(googleTestAdvertiserId))
          key,
    ];
    if (badKeys.isNotEmpty) {
      issues.add(RuntimeEnvArtifactIssue(
        severity: ArtifactIssueSeverity.fail,
        message: 'release 산출물에 비어있거나 Google 테스트 ID인 광고 키: '
            '${badKeys.join(', ')} (project.yaml admob.units에 실제 값 설정)',
      ));
    }
  }

  // ⑤ 법적 URL 도메인 게이트: release 산출물의 privacy/terms URL이 템플릿
  //    소유 도메인(boilerplate-2024.web.app)을 가리키면 FAIL — 파생 앱이
  //    남의 개인정보/약관 URL로 출시되는 사고 차단(빈 URL→stale project id
  //    도출 또는 템플릿 URL 복사). placeholder 카피 게이트와 동일 취급.
  if (releaseArtifact.existsSync()) {
    final releaseEnv = parseEnvFile(releaseArtifact);
    final stolenDomain = '$boilerplateFirebaseProjectId.web.app';
    const legalUrlKeys = {
      'PRIVACY_POLICY_URL': 'privacy_policy_url',
      'TERMS_OF_SERVICE_URL': 'terms_of_service_url',
    };
    for (final entry in legalUrlKeys.entries) {
      if ((releaseEnv[entry.key] ?? '').contains(stolenDomain)) {
        issues.add(RuntimeEnvArtifactIssue(
          severity: ArtifactIssueSeverity.fail,
          message: 'release 산출물의 ${entry.key}이 템플릿 기본 도메인'
              '($stolenDomain)을 가리킵니다 — 파생 앱이 남의 도메인 법적 URL로 '
              '출시됩니다. project.yaml listing.${entry.value}에 실제 URL을 '
              '지정하거나 `./run generate-legal && ./run deploy-legal`로 '
              '자체 호스팅하세요.',
        ));
      }
    }
  }

  // ④ 시크릿 값 누출 (작성기의 시크릿 게이트와 동일 규칙)
  final rootEnv = parseEnvFile(File('$projectRoot/.env'));
  final secretValues = <String, String>{
    for (final key in knownSecretEnvKeys)
      if ((rootEnv[key] ?? '').isNotEmpty) key: rootEnv[key]!,
  };
  if (secretValues.isNotEmpty) {
    for (final entry in artifacts.entries) {
      if (!entry.value.existsSync()) continue;
      for (final kv in parseEnvFile(entry.value).entries) {
        for (final secret in secretValues.entries) {
          if (kv.value == secret.value) {
            issues.add(RuntimeEnvArtifactIssue(
              severity: ArtifactIssueSeverity.fail,
              message: '.env.${entry.key}의 ${kv.key} 값이 root .env 시크릿 '
                  '${secret.key} 값과 동일합니다 (시크릿 누출)',
            ));
          }
        }
      }
    }
  }

  return issues;
}

/// app_config.yaml `features:` 키를 AppFeatureConfig 필드명으로 변환.
///
/// - `force_update` → `isForceUpdateEnabled`
/// - 이미 `is...` 형태(예: `isAdsEnabled`)면 그대로 사용
///
/// 앱 쪽은 FF_<필드명> 키를 AppFeatureConfig.fromMap으로 그대로 적용하므로
/// 변환은 생성 시점 한 곳에서만 일어난다.
/// 법적 문서 호스팅 URL 도출 — 호스팅 방식(`listing.legal_hosting`)에 따라
/// Firebase Hosting 또는 GitHub Pages URL을 돌려준다 (A1).
///
/// generate-legal 산출물(`docs/legal/`)을 `./run deploy-legal`이 배포한다:
/// - firebase(기본): `https://<projectId>.web.app/<file>`
/// - github: `https://<owner>.github.io/<repo>/<file>` (legal-pages.yml 워크플로)
/// 도출 불가(식별자 부재)면 빈 문자열 → 앱이 해당 버튼을 숨긴다.
String deriveLegalUrl(ConfigLoader config, String projectRoot, String file) {
  if (config.legalHosting == 'github') {
    return deriveGithubPagesUrl(config.githubRepository, file);
  }
  return deriveLegalHostingUrl(readFirebaseProjectId(projectRoot), file);
}

/// Firebase Hosting 컨벤션 URL (`https://<projectId>.web.app/<file>`).
/// [projectId]가 비면 빈 문자열.
String deriveLegalHostingUrl(String projectId, String file) {
  if (projectId.isEmpty) return '';
  return 'https://$projectId.web.app/$file';
}

/// GitHub Pages 프로젝트 사이트 URL (`https://<owner>.github.io/<repo>/<file>`).
///
/// [githubRepository]는 `owner/repo` 형식. 비었거나 형식이 안 맞으면 빈 문자열.
/// 주의: private repo의 Pages는 GitHub 유료 플랜에서만 동작한다(public이면 무료).
String deriveGithubPagesUrl(String githubRepository, String file) {
  final parts = githubRepository.split('/');
  if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) return '';
  if (githubRepository.contains('your-org') ||
      githubRepository.contains('owner/')) {
    return ''; // 미편집 placeholder
  }
  return 'https://${parts[0]}.github.io/${parts[1]}/$file';
}

/// Firebase 프로젝트 ID — `app/android/app/google-services.json`의
/// `project_info.project_id`가 SSOT (init의 setup-firebase가 교체하는
/// 파일이라 파생 앱에서 자동 정합). 없거나 파싱 실패면 빈 문자열.
String readFirebaseProjectId(String projectRoot) {
  final file = File('$projectRoot/app/android/app/google-services.json');
  if (!file.existsSync()) return '';
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final projectInfo = json['project_info'];
    if (projectInfo is! Map) return '';
    return projectInfo['project_id']?.toString() ?? '';
  } catch (_) {
    return '';
  }
}

/// 기계적 PascalCase 재구성으로는 맞출 수 없는 feature 키 → AppFeatureConfig
/// 필드명 명시 매핑. 이 4개를 누락하면 `FF_isBiometricEnabled` 같은 유령 키가
/// 방출되어 `AppFeatureConfig._fields`에 매칭되지 않고 토글이 무음 no-op가 된다
/// (`./feature enable/disable`가 초록 성공을 찍지만 런타임 플래그는 불변).
const _featureFieldOverrides = <String, String>{
  'biometric': 'isBiometricAuthEnabled',
  'abTesting': 'isABTestingEnabled',
  'crashReporting': 'isFirebaseCrashlyticsEnabled',
  'splashAd': 'isSplashInterstitialAdEnabled',
};

String featureFlagFieldName(String key) {
  if (key.startsWith('is')) return key;
  final override = _featureFieldOverrides[key];
  if (override != null) return override;
  final pascal = key
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join();
  return 'is${pascal}Enabled';
}
