import 'dart:io';

import 'package:args/args.dart';

import '../core/command.dart';
import '../core/config_loader.dart';
import '../core/coverage.dart';
import '../core/env_artifacts.dart';
import '../core/logger/cli_logger.dart';
import '../core/path_utils.dart';
import '../core/test_quality.dart';

/// Check result status.
enum _CheckStatus {
  pass('PASS'),
  warn('WARN'),
  fail('FAIL');

  const _CheckStatus(this.label);
  final String label;
}

/// Single check result (immutable).
class _CheckResult {
  const _CheckResult({
    required this.name,
    required this.status,
    this.detail,
  });

  final String name;
  final _CheckStatus status;
  final String? detail;
}

/// Pre-deployment validation command.
///
/// Usage:
/// ```bash
/// ./preflight                     # Run all checks
/// ./preflight --fix               # Auto-fix fixable issues
/// ./preflight -c custom.yaml      # Use custom config
/// ./preflight --verbose           # Verbose output
/// ```
class PreflightCommand extends Command {
  PreflightCommand({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path;

  final String projectRoot;
  String get appDir => '$projectRoot/app';

  @override
  String get name => 'preflight';

  @override
  String get description => '배포 전 사전 검증을 수행합니다.\n\n'
      '검증 항목:\n'
      '  1. Config 파일 (app_config.yaml)\n'
      '  2. 환경 변수 (.env)\n'
      '  3. 런타임 env 산출물 (.env.debug/profile/release)\n'
      '  4. 도구 설치 (flutter, fastlane, dart, git)\n'
      '  5. 서명 설정 (iOS/Android)\n'
      '  6. 빌드 검증 (flutter analyze)\n'
      '  7. 에셋 검증 (런처 아이콘)\n'
      '  8. 스토어 인증 정보\n'
      '  9. Firebase 프로젝트\n'
      '  10. Google Play 앱 등록';

  @override
  ArgParser buildArgParser() {
    return ArgParser()
      ..addOption('config',
          abbr: 'c',
          help: '설정 파일 경로',
          defaultsTo: 'app_config.yaml')
      ..addOption('mode',
          abbr: 'm',
          help: '검증 모드: feature(분석+테스트+커버리지) | deploy(전체)',
          allowed: ['feature', 'deploy'],
          defaultsTo: 'deploy')
      ..addOption('coverage-threshold',
          help: '전역 커버리지 목표값(%, 정수) — 미달 시 정보성 WARN(차단 아님)',
          defaultsTo: '60')
      ..addOption('feature-threshold',
          help: '변경 기능 단위 커버리지 게이트(%, 정수) — feature 모드 하드 게이트',
          defaultsTo: '80')
      ..addMultiOption('feature',
          help: '커버리지 게이트를 적용할 기능명(미지정 시 git diff로 변경 기능 자동 감지)')
      ..addFlag('fix', help: '자동 수정 가능한 항목 수정', defaultsTo: false)
      ..addFlag('verbose', abbr: 'v', help: '상세 로그 출력', defaultsTo: false)
      ..addFlag('help', abbr: 'h', help: '도움말 표시', negatable: false);
  }

  @override
  Future<int> execute(ArgResults args) async {
    if (args['help'] as bool) {
      printUsage();
      return 0;
    }

    final verbose = args['verbose'] as bool;
    final fix = args['fix'] as bool;
    final configPath = args['config'] as String;
    final mode = args['mode'] as String;
    final coverageThreshold =
        int.tryParse(args['coverage-threshold'] as String) ?? 60;
    final featureThreshold =
        int.tryParse(args['feature-threshold'] as String) ?? 80;
    final explicitFeatures = args['feature'] as List<String>;

    await CliLogger.init(verbose: verbose);

    stdout.writeln('');
    stdout.writeln('Pre-flight Check Results  [mode: $mode]');
    stdout.writeln('========================================');

    final results = <_CheckResult>[];

    if (mode == 'feature') {
      // Feature mode: analyze + test + 중성화 차단 + 커버리지 (PR 게이트)
      results.add(await _checkBuild(verbose));
      results.add(await _checkTests(verbose));
      results.add(await _checkNoSkippedTests());
      results.add(await _checkCoverage(coverageThreshold));
      results.addAll(
          await _checkFeatureCoverage(featureThreshold, explicitFeatures));
    } else {
      // Deploy mode: full check
      // 1. Config check
      final configResult = await _checkConfig(configPath);
      results.add(configResult);

      ConfigLoader? config;
      if (configResult.status != _CheckStatus.fail) {
        try {
          config = ConfigLoader('$projectRoot/$configPath');
          await config.load();
        } catch (e) {
          CliLogger.debug('Config load failed for subsequent checks: $e');
        }
      }

      // 1.5. Package name placeholder guard — placeholder 번들 ID 출시 차단
      results.add(_checkPackageName(config));

      // 2. Environment check
      results.add(await _checkEnvironment(fix));

      // 3. Runtime env artifacts check (.env.{debug,profile,release})
      results.addAll(_checkRuntimeEnvArtifacts(config));

      // 4. Tool checks
      results.addAll(await _checkTools());

      // 4.5. fastlane 핀 대조 (P0-6) — 로컬 클론이 project.yaml 핀과 일치하는지
      results.add(await _checkFastlanePin(config));

      // 5. Signing checks
      results.addAll(await _checkSigning(config, verbose));

      // 6. Build check
      results.add(await _checkBuild(verbose));

      // 7. Test + 중성화 차단 + coverage
      results.add(await _checkTests(verbose));
      results.add(await _checkNoSkippedTests());
      results.add(await _checkCoverage(coverageThreshold));

      // 8. Asset check
      results.add(_checkAssets());

      // 9. Store checks
      results.addAll(_checkStore(config));

      // 10. Firebase project check
      results.add(await _checkFirebaseProject(config));

      // 11. Google Play app registration check
      results.add(_checkGooglePlayApp(config));
    }

    // Print results
    for (final result in results) {
      final statusTag = '[${result.status.label}]';
      final detail = result.detail != null ? ' - ${result.detail}' : '';
      stdout.writeln('  $statusTag ${result.name}$detail');
    }

    // Summary
    final passCount =
        results.where((r) => r.status == _CheckStatus.pass).length;
    final warnCount =
        results.where((r) => r.status == _CheckStatus.warn).length;
    final failCount =
        results.where((r) => r.status == _CheckStatus.fail).length;

    stdout.writeln('');
    stdout.writeln(
        'Result: $passCount passed, $warnCount warnings, $failCount failures');
    stdout.writeln('');

    return failCount > 0 ? 1 : 0;
  }

  /// Check config file exists and is valid YAML.
  Future<_CheckResult> _checkConfig(String configPath) async {
    final file = File('$projectRoot/$configPath');
    if (!file.existsSync()) {
      return _CheckResult(
        name: configPath,
        status: _CheckStatus.fail,
        detail: 'file not found',
      );
    }

    try {
      final loader = ConfigLoader(file.path);
      await loader.load();
      return _CheckResult(
        name: configPath,
        status: _CheckStatus.pass,
      );
    } catch (e) {
      return _CheckResult(
        name: configPath,
        status: _CheckStatus.fail,
        detail: 'invalid YAML: $e',
      );
    }
  }

  /// Check .env exists; warn when Android release signing secrets are empty.
  Future<_CheckResult> _checkEnvironment(bool fix) async {
    final envFile = File('$projectRoot/.env');
    if (!envFile.existsSync()) {
      if (fix) {
        CliLogger.debug('Running flutter pub get to fix dependencies...');
        await Process.run(
          'flutter',
          ['pub', 'get'],
          workingDirectory: appDir,
        );
      }
      return const _CheckResult(
        name: '.env',
        status: _CheckStatus.fail,
        detail: 'file not found (run ./init)',
      );
    }

    // Android release 서명에 필요한 시크릿이 비어있으면 경고
    final env = parseEnvFile(envFile);
    final emptySecrets = <String>[
      for (final key in ['KEYSTORE_PASSWORD', 'KEY_PASSWORD'])
        if ((env[key] ?? '').isEmpty) key,
    ];
    if (emptySecrets.isNotEmpty) {
      return _CheckResult(
        name: '.env',
        status: _CheckStatus.warn,
        detail: '${emptySecrets.join(', ')} 미설정 — Android release 서명에 필요',
      );
    }

    return const _CheckResult(
      name: '.env',
      status: _CheckStatus.pass,
    );
  }

  /// Check runtime env artifacts (.env.{debug,profile,release}) — plan §2.3.
  ///
  /// 존재 / source-hash 신선도 / release 광고 게이트 / 시크릿 누출을 검증.
  List<_CheckResult> _checkRuntimeEnvArtifacts(ConfigLoader? config) {
    const checkName = 'Runtime env artifacts';
    if (config == null) {
      return const [
        _CheckResult(
          name: checkName,
          status: _CheckStatus.warn,
          detail: 'config 로드 실패로 산출물 검증 건너뜀',
        ),
      ];
    }

    final issues = checkRuntimeEnvArtifacts(
      projectRoot: projectRoot,
      config: config,
    );
    if (issues.isEmpty) {
      return const [
        _CheckResult(name: checkName, status: _CheckStatus.pass),
      ];
    }

    return [
      for (final issue in issues)
        _CheckResult(
          name: checkName,
          status: issue.severity == ArtifactIssueSeverity.fail
              ? _CheckStatus.fail
              : _CheckStatus.warn,
          detail: issue.message,
        ),
    ];
  }

  /// Check required tools are installed.
  Future<List<_CheckResult>> _checkTools() async {
    final tools = <_ToolCheck>[
      _ToolCheck('Flutter SDK', 'flutter', ['--version']),
      _ToolCheck('Fastlane', 'fastlane', ['--version']),
      _ToolCheck('Dart SDK', 'dart', ['--version']),
      _ToolCheck('Git', 'git', ['--version']),
    ];

    final results = <_CheckResult>[];
    for (final tool in tools) {
      results.add(await _checkTool(tool));
    }
    return results;
  }

  /// Check a single tool is installed and get its version.
  Future<_CheckResult> _checkTool(_ToolCheck tool) async {
    try {
      final result = await Process.run(tool.command, tool.args);
      if (result.exitCode != 0) {
        return _CheckResult(
          name: tool.name,
          status: _CheckStatus.fail,
          detail: 'not installed',
        );
      }

      final output = result.stdout.toString().trim();
      final version = _extractVersion(output);
      return _CheckResult(
        name: tool.name,
        status: _CheckStatus.pass,
        detail: version,
      );
    } catch (e) {
      return _CheckResult(
        name: tool.name,
        status: _CheckStatus.fail,
        detail: 'not found in PATH',
      );
    }
  }

  /// Check iOS and Android signing configuration.
  Future<List<_CheckResult>> _checkSigning(
      ConfigLoader? config, bool verbose) async {
    final results = <_CheckResult>[];

    // iOS signing
    final matchGitUrl = config != null
        ? _getSigningValue(config, 'signing.ios.match_git_url')
        : '';
    if (matchGitUrl.isEmpty) {
      results.add(const _CheckResult(
        name: 'iOS Signing',
        status: _CheckStatus.warn,
        detail: 'match_git_url not configured',
      ));
    } else {
      // Check if provisioning profiles directory exists
      final profilesDir = Directory(
          '${Platform.environment['HOME']}/Library/MobileDevice/'
          'Provisioning Profiles');
      if (profilesDir.existsSync()) {
        final profiles = profilesDir
            .listSync()
            .where((e) => e.path.endsWith('.mobileprovision'));
        if (profiles.isEmpty) {
          results.add(const _CheckResult(
            name: 'iOS Signing',
            status: _CheckStatus.warn,
            detail: 'no provisioning profiles found',
          ));
        } else {
          results.add(_CheckResult(
            name: 'iOS Signing',
            status: _CheckStatus.pass,
            detail: '${profiles.length} profile(s)',
          ));
        }
      } else {
        results.add(const _CheckResult(
          name: 'iOS Signing',
          status: _CheckStatus.warn,
          detail: 'provisioning profiles directory not found',
        ));
      }
    }

    // Android signing
    final keystorePath = config?.keystorePath ?? '';
    if (keystorePath.isEmpty) {
      results.add(const _CheckResult(
        name: 'Android Keystore',
        status: _CheckStatus.warn,
        detail: 'keystore_path not configured',
      ));
    } else {
      final keystoreFile =
          File(expandUserPath(keystorePath, projectRoot: projectRoot));
      if (keystoreFile.existsSync()) {
        results.add(const _CheckResult(
          name: 'Android Keystore',
          status: _CheckStatus.pass,
        ));
      } else {
        results.add(_CheckResult(
          name: 'Android Keystore',
          status: _CheckStatus.fail,
          detail: 'file not found: $keystorePath',
        ));
      }
    }

    return results;
  }

  /// fastlane/ 로컬 클론이 project.yaml tooling.fastlane_ref 핀과 일치하는지.
  ///
  /// - fastlane/ 부재: pass (./run이 핀으로 자동 클론)
  /// - 핀이 태그(v*): 클론 HEAD가 정확히 그 태그여야 함 — 불일치는 FAIL
  /// - 핀이 브랜치: 태그 핀 전 과도기 — WARN으로 안내만
  Future<_CheckResult> _checkFastlanePin(ConfigLoader? config) async {
    const name = 'Fastlane 핀';
    final pin = config?.fastlaneRef ?? 'main';
    final fastlaneDir = Directory('$projectRoot/fastlane');

    if (!fastlaneDir.existsSync()) {
      return _CheckResult(
        name: name,
        status: _CheckStatus.pass,
        detail: '클론 없음 — 필요 시 핀($pin)으로 자동 클론됨',
      );
    }

    if (!pin.startsWith('v')) {
      return _CheckResult(
        name: name,
        status: _CheckStatus.warn,
        detail: '핀이 브랜치($pin) — 태그 핀(v*)으로 교체 권장 (P0-6)',
      );
    }

    final result = await Process.run(
      'git',
      ['-C', fastlaneDir.path, 'describe', '--tags', '--exact-match', 'HEAD'],
    );
    final currentTag = result.stdout.toString().trim();
    if (result.exitCode != 0 || currentTag != pin) {
      return _CheckResult(
        name: name,
        status: _CheckStatus.fail,
        detail: '로컬 클론(${currentTag.isEmpty ? 'untagged HEAD' : currentTag})이 '
            '핀($pin)과 불일치 — cd fastlane && git checkout $pin',
      );
    }

    return const _CheckResult(name: name, status: _CheckStatus.pass);
  }

  /// Run flutter analyze.
  Future<_CheckResult> _checkBuild(bool verbose) async {
    try {
      final result = await Process.run(
        'flutter',
        ['analyze', '--no-fatal-infos'],
        workingDirectory: appDir,
      );

      if (verbose) {
        CliLogger.debug(result.stdout.toString());
      }

      if (result.exitCode != 0) {
        final output = result.stdout.toString();
        final issueCount = _extractIssueCount(output);
        return _CheckResult(
          name: 'Build (flutter analyze)',
          status: _CheckStatus.fail,
          detail: issueCount ?? 'analysis errors found',
        );
      }

      return const _CheckResult(
        name: 'Build (flutter analyze)',
        status: _CheckStatus.pass,
      );
    } catch (e) {
      return _CheckResult(
        name: 'Build (flutter analyze)',
        status: _CheckStatus.fail,
        detail: 'failed to run: $e',
      );
    }
  }

  /// Check launcher icon exists.
  _CheckResult _checkAssets() {
    // 아이콘 SSOT (P0-8): flutter_launcher_icons.yaml image_path와 동일 경로
    final iconPath = '$appDir/assets/launcher_icon/icon.png';
    final iconFile = File(iconPath);

    if (iconFile.existsSync()) {
      return const _CheckResult(
        name: 'Launcher Icon',
        status: _CheckStatus.pass,
      );
    }

    return const _CheckResult(
      name: 'Launcher Icon',
      status: _CheckStatus.warn,
      detail: 'assets/launcher_icon/icon.png not found',
    );
  }

  /// Check store credentials are configured.
  List<_CheckResult> _checkStore(ConfigLoader? config) {
    final results = <_CheckResult>[];

    // Apple
    final appleId = config?.appleId ?? '';
    if (appleId.isEmpty) {
      results.add(const _CheckResult(
        name: 'Store - Apple ID',
        status: _CheckStatus.warn,
        detail: 'not set',
      ));
    } else {
      results.add(const _CheckResult(
        name: 'Store - Apple ID',
        status: _CheckStatus.pass,
      ));
    }

    // Google
    final googleJsonKey = config?.googleJsonKey ?? '';
    if (googleJsonKey.isEmpty) {
      results.add(const _CheckResult(
        name: 'Store - Google Play JSON key',
        status: _CheckStatus.warn,
        detail: 'not set',
      ));
    } else {
      final jsonFile =
          File(expandUserPath(googleJsonKey, projectRoot: projectRoot));
      if (jsonFile.existsSync()) {
        results.add(const _CheckResult(
          name: 'Store - Google Play JSON key',
          status: _CheckStatus.pass,
        ));
      } else {
        results.add(_CheckResult(
          name: 'Store - Google Play JSON key',
          status: _CheckStatus.fail,
          detail: 'file not found: $googleJsonKey',
        ));
      }
    }

    return results;
  }

  /// Extract version string from tool output.
  String? _extractVersion(String output) {
    final versionPattern = RegExp(r'(\d+\.\d+[\.\d]*)');
    final match = versionPattern.firstMatch(output);
    return match?.group(0);
  }

  /// Extract issue count from flutter analyze output.
  String? _extractIssueCount(String output) {
    final pattern = RegExp(r'(\d+)\s+issue');
    final match = pattern.firstMatch(output);
    if (match != null) {
      return '${match.group(1)} issue(s)';
    }
    return null;
  }

  /// Get signing value from config using the internal getter pattern.
  String _getSigningValue(ConfigLoader config, String path) {
    // ConfigLoader exposes specific getters but not a generic path accessor.
    // We use the available getters for known signing paths.
    if (path == 'signing.ios.match_git_url') {
      // Access via the config's internal mechanism by trying to load
      // the value through a fresh ConfigLoader approach.
      // The ConfigLoader doesn't expose match_git_url directly,
      // so we read the config file and check the signing section.
      try {
        final file = File(config.configPath);
        final content = file.readAsStringSync();
        final matchGitUrlPattern = RegExp(r'match_git_url:\s*"(.+)"');
        final match = matchGitUrlPattern.firstMatch(content);
        return match?.group(1) ?? '';
      } catch (e) {
        return '';
      }
    }
    return '';
  }

  /// Check if Firebase project is configured and accessible.
  Future<_CheckResult> _checkFirebaseProject(ConfigLoader? config) async {
    if (config == null || !config.firebaseEnabled) {
      return const _CheckResult(
        name: 'Firebase Project',
        status: _CheckStatus.pass,
        detail: 'disabled',
      );
    }

    final projectId = config.firebaseProjectId;
    if (projectId.isEmpty) {
      return const _CheckResult(
        name: 'Firebase Project',
        status: _CheckStatus.warn,
        detail: 'project_id 미설정 (./init 실행 시 자동 생성됨)',
      );
    }

    // Check if firebase CLI is available
    try {
      final result = await Process.run('which', ['firebase']);
      if (result.exitCode != 0) {
        return const _CheckResult(
          name: 'Firebase Project',
          status: _CheckStatus.warn,
          detail: 'Firebase CLI 미설치',
        );
      }
    } catch (e) {
      return const _CheckResult(
        name: 'Firebase Project',
        status: _CheckStatus.warn,
        detail: 'Firebase CLI 확인 실패',
      );
    }

    return _CheckResult(
      name: 'Firebase Project',
      status: _CheckStatus.pass,
      detail: projectId,
    );
  }

  /// Check package_name is not an unedited placeholder (com.example.*).
  ///
  /// 포크가 보일러플레이트 번들 ID로 출시되는 사고를 release 단계에서 차단.
  _CheckResult _checkPackageName(ConfigLoader? config) {
    const name = 'Package name';
    if (config == null) {
      return const _CheckResult(
        name: name,
        status: _CheckStatus.warn,
        detail: 'config 없음',
      );
    }

    final packageName = config.packageName;
    if (packageName.startsWith('com.example.')) {
      return const _CheckResult(
        name: name,
        status: _CheckStatus.fail,
        detail: 'package_name이 placeholder(com.example.*)입니다 — '
            'project.yaml package_name을 실제 값으로 변경하세요.',
      );
    }

    return _CheckResult(
      name: name,
      status: _CheckStatus.pass,
      detail: packageName,
    );
  }

  /// Check Google Play app registration status and provide guidance.
  _CheckResult _checkGooglePlayApp(ConfigLoader? config) {
    if (config == null) {
      return const _CheckResult(
        name: 'Google Play App',
        status: _CheckStatus.warn,
        detail: 'config 없음',
      );
    }

    final googleJsonKey = config.googleJsonKey;
    final packageName = config.packageName;

    if (googleJsonKey.isEmpty) {
      return _CheckResult(
        name: 'Google Play App',
        status: _CheckStatus.warn,
        detail: '수동 등록 필요: https://play.google.com/console '
            '(패키지: $packageName)',
      );
    }

    if (!File(expandUserPath(googleJsonKey, projectRoot: projectRoot))
        .existsSync()) {
      return _CheckResult(
        name: 'Google Play App',
        status: _CheckStatus.fail,
        detail: 'JSON 키 파일 없음: $googleJsonKey',
      );
    }

    return const _CheckResult(
      name: 'Google Play App',
      status: _CheckStatus.pass,
    );
  }

  /// Run flutter test --coverage and report pass/fail.
  Future<_CheckResult> _checkTests(bool verbose) async {
    try {
      final result = await Process.run(
        'flutter',
        ['test', '--coverage', '--no-pub'],
        workingDirectory: appDir,
      );

      if (verbose) {
        CliLogger.debug(result.stdout.toString());
      }

      if (result.exitCode != 0) {
        final output = result.stdout.toString();
        // Extract failure count from test output
        final failPattern = RegExp(r'(\d+) test[s]? failed');
        final match = failPattern.firstMatch(output);
        final detail = match != null
            ? '${match.group(1)} test(s) failed'
            : 'test failures detected';
        return _CheckResult(
          name: 'Tests (flutter test)',
          status: _CheckStatus.fail,
          detail: detail,
        );
      }

      // Extract pass count
      final passPattern = RegExp(r'(\d+) test[s]? passed');
      final match = passPattern.firstMatch(result.stdout.toString());
      final detail = match != null ? '${match.group(1)} passed' : 'all passed';

      return _CheckResult(
        name: 'Tests (flutter test)',
        status: _CheckStatus.pass,
        detail: detail,
      );
    } catch (e) {
      return _CheckResult(
        name: 'Tests (flutter test)',
        status: _CheckStatus.fail,
        detail: 'failed to run: $e',
      );
    }
  }

  /// 전역 커버리지(생성 코드 제외) — 정보성. 목표 미달은 WARN(차단 아님).
  /// 진짜 게이트는 [_checkFeatureCoverage]의 변경-기능 단위.
  Future<_CheckResult> _checkCoverage(int target) async {
    final lcovFile = File('$appDir/coverage/lcov.info');
    if (!lcovFile.existsSync()) {
      return const _CheckResult(
        name: 'Coverage 전역(정보)',
        status: _CheckStatus.warn,
        detail: 'coverage/lcov.info 없음 — 먼저 --coverage로 테스트 실행',
      );
    }
    try {
      final report = LcovReport.parse(await lcovFile.readAsString());
      final pct = report.globalCoverage();
      if (pct == null) {
        return const _CheckResult(
          name: 'Coverage 전역(정보)',
          status: _CheckStatus.warn,
          detail: '측정 대상(손작성) 라인 없음',
        );
      }
      final rounded = pct.round();
      // 전역은 차단하지 않는다(레포 베이스라인이 낮을 수 있음). 목표 미달은 WARN.
      return _CheckResult(
        name: 'Coverage 전역(정보)',
        status: rounded < target ? _CheckStatus.warn : _CheckStatus.pass,
        detail: rounded < target ? '$rounded% < $target% 목표' : '$rounded%',
      );
    } catch (e) {
      return _CheckResult(
        name: 'Coverage 전역(정보)',
        status: _CheckStatus.warn,
        detail: 'lcov.info 파싱 실패: $e',
      );
    }
  }

  /// 변경된 기능(lib/features/<name>/)별 손작성 커버리지 ≥ [threshold]% 하드 게이트.
  /// [explicit]가 있으면 그 기능만, 없으면 git diff로 변경 기능 자동 감지.
  Future<List<_CheckResult>> _checkFeatureCoverage(
      int threshold, List<String> explicit) async {
    final features =
        explicit.isNotEmpty ? explicit : await _detectChangedFeatures();
    if (features.isEmpty) {
      return const [
        _CheckResult(
          name: 'Coverage 변경 기능',
          status: _CheckStatus.pass,
          detail: '변경된 기능 없음',
        ),
      ];
    }
    final lcovFile = File('$appDir/coverage/lcov.info');
    if (!lcovFile.existsSync()) {
      return [
        _CheckResult(
          name: 'Coverage 변경 기능',
          status: _CheckStatus.fail,
          detail: 'lcov.info 없음 — ${features.join(", ")} 검증 불가',
        ),
      ];
    }
    final report = LcovReport.parse(await lcovFile.readAsString());
    final results = <_CheckResult>[];
    for (final f in features) {
      final pct = report.featureCoverage(f);
      if (pct == null) {
        results.add(_CheckResult(
          name: 'Coverage [$f]',
          status: _CheckStatus.fail,
          detail: '커버리지 데이터 없음 — 테스트 미작성?',
        ));
      } else if (pct < threshold) {
        // 절단 비교(pct < threshold) — CI awk의 정수 나눗셈과 동일 판정.
        // floor 표시도 CI(LH*100/LF)와 일치시킨다(round 시 80 미만이 80으로 보임).
        results.add(_CheckResult(
          name: 'Coverage [$f]',
          status: _CheckStatus.fail,
          detail: '${pct.floor()}% < $threshold% (변경 기능 게이트)',
        ));
      } else {
        results.add(_CheckResult(
          name: 'Coverage [$f]',
          status: _CheckStatus.pass,
          detail: '${pct.floor()}%',
        ));
      }
    }
    return results;
  }

  /// git diff(작업트리+스테이지)에서 변경된 app/lib/features/<name>/ 기능명 집합.
  Future<Set<String>> _detectChangedFeatures() async {
    final features = <String>{};
    final re = RegExp(r'app/lib/features/([^/]+)/');
    for (final args in [
      ['diff', '--name-only', 'HEAD'],
      ['diff', '--name-only', '--cached'],
    ]) {
      try {
        final r = await Process.run('git', args, workingDirectory: projectRoot);
        for (final m in re.allMatches(r.stdout.toString())) {
          features.add(m.group(1)!);
        }
      } catch (_) {
        // git 없거나 repo 아님 — 자동 감지 생략(명시 --feature로 게이트 가능).
      }
    }
    return features;
  }

  /// app/test/ 내 테스트 중성화(skip/markTestSkipped/트리비얼 단언) 차단.
  Future<_CheckResult> _checkNoSkippedTests() async {
    final testDir = Directory('$appDir/test');
    if (!testDir.existsSync()) {
      return const _CheckResult(
          name: '테스트 무결성(no-skip)', status: _CheckStatus.pass);
    }
    final findings = <String>[];
    for (final entity in testDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
      final issues = TestQualityScan.findIssues(entity.readAsStringSync());
      for (final issue in issues) {
        final rel = entity.path.replaceFirst('$projectRoot/', '');
        findings.add('$rel:${issue.line} ${issue.label}');
      }
    }
    if (findings.isEmpty) {
      return const _CheckResult(
          name: '테스트 무결성(no-skip)', status: _CheckStatus.pass);
    }
    return _CheckResult(
      name: '테스트 무결성(no-skip)',
      status: _CheckStatus.fail,
      detail: '${findings.length}건 — ${findings.take(3).join(" / ")}'
          '${findings.length > 3 ? " …" : ""}',
    );
  }

  /// Print usage information.
  void printUsage() {
    print(usage);
  }
}

/// Tool check definition (immutable).
class _ToolCheck {
  const _ToolCheck(this.name, this.command, this.args);

  final String name;
  final String command;
  final List<String> args;
}
