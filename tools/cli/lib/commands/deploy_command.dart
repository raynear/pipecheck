import 'dart:io';

import 'package:args/args.dart';

import '../core/command.dart';
import '../core/config_loader.dart';
import '../core/env_artifacts.dart';
import '../core/fastlane_output_parser.dart';
import '../core/logger/cli_logger.dart';
import '../core/path_utils.dart';
import '../core/progress/progress_indicator.dart';
import 'datasafety/data_safety_generator.dart';
import 'iap_register_command.dart';

/// One-button deploy command
///
/// Usage:
/// ```bash
/// ./deploy                           # Deploy to beta (both platforms)
/// ./deploy --target production       # Deploy to production
/// ./deploy --platform ios            # iOS only
/// ./deploy --skip-screenshots        # Skip screenshot generation
/// ```
class DeployCommand extends Command {
  DeployCommand({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path;

  final String projectRoot;
  String get appDir => '$projectRoot/app';
  String get fastlaneDir => '$projectRoot/fastlane';

  @override
  String get name => 'deploy';

  @override
  String get description => '원버튼 빌드 & 배포를 수행합니다.\n\n'
      '실행 단계:\n'
      '  1. Pre-flight 검증 (환경변수, 인증서, 에셋)\n'
      '  2. 코드 생성 + 린트\n'
      '  3. 테스트 실행\n'
      '  4. 버전 범프\n'
      '  5. 스크린샷 (선택)\n'
      '  6. 릴리스 노트 자동 생성 (git log 기반)\n'
      '  7. 빌드 & 업로드\n'
      '  8. 메타데이터 업로드 (production만)\n'
      '  9. iOS 심사 제출 (production + --submit-review)\n'
      ' 10. Git tag 생성';

  @override
  ArgParser buildArgParser() {
    return ArgParser()
      ..addOption('target',
          abbr: 't',
          help: '배포 대상',
          defaultsTo: 'beta',
          allowed: ['beta', 'production'])
      ..addOption('platform',
          abbr: 'p',
          help: '플랫폼',
          defaultsTo: 'all',
          allowed: ['ios', 'android', 'all'])
      ..addOption('bump',
          help: '버전 범프 타입',
          defaultsTo: 'patch',
          allowed: ['patch', 'minor', 'major', 'build'])
      ..addFlag('skip-tests', help: '테스트 건너뛰기', defaultsTo: false)
      ..addFlag('skip-screenshots', help: '스크린샷 건너뛰기', defaultsTo: true)
      ..addFlag('enhance-screenshots',
          help: '스크린샷 생성 후 adlab으로 마케팅 목업화 '
              '(--no-skip-screenshots와 함께 사용, adlab 서버 필요)',
          defaultsTo: false)
      ..addFlag('skip-lint', help: '린트 건너뛰기', defaultsTo: false)
      // 첫 제출은 스크린샷/연령등급 등 ASC 필수 항목 미비로 실패할 수
      // 있어 opt-in (P1-17c). 실앱 1회 검증 후 기본 true 승격 검토.
      ..addFlag('submit-review',
          help: 'iOS 심사 자동 제출 (production 전용 — 메타데이터 업로드 후 '
              'submit_ios_review 레인 호출)',
          defaultsTo: false)
      ..addFlag('dry-run', help: '실제 배포 없이 검증만', defaultsTo: false)
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
    final dryRun = args['dry-run'] as bool;
    final target = args['target'] as String;
    final platform = args['platform'] as String;
    final bump = args['bump'] as String;
    final submitReview = args['submit-review'] as bool;
    // 스크린샷을 이번 실행에서 생성하면, 업로드 단계에서도 deliver/supply가
    // 스크린샷을 올리도록 SKIP_SCREENSHOTS=false를 함께 주입한다 (생성↔업로드 일치).
    final generateScreenshots = !(args['skip-screenshots'] as bool);
    if ((args['enhance-screenshots'] as bool) && !generateScreenshots) {
      stderr.writeln('❌ --enhance-screenshots는 스크린샷 생성 단계가 있어야 '
          '동작합니다 — --no-skip-screenshots와 함께 사용하세요.');
      return 1;
    }

    await CliLogger.init(verbose: verbose);

    stdout.writeln('🚀 배포를 시작합니다...');
    stdout.writeln('  대상: $target | 플랫폼: $platform | 버전: $bump');
    if (dryRun) stdout.writeln('  [DRY RUN - 실제 배포 없음]');
    stdout.writeln('');

    try {
      // Step 1: Pre-flight checks
      final preflightProgress = ProgressIndicator(message: 'Pre-flight 검증');
      preflightProgress.start();
      final preflightOk = await _preflight(verbose, target, platform);
      if (!preflightOk) {
        preflightProgress.fail('검증 실패');
        return 1;
      }
      preflightProgress.complete('Pre-flight 검증 통과');

      // Step 2: Code generation + lint
      if (!(args['skip-lint'] as bool)) {
        final lintProgress = ProgressIndicator(message: '코드 생성 + 린트');
        lintProgress.start();

        final buildResult = await Process.run(
          'bash',
          ['build.sh'],
          workingDirectory: appDir,
        );
        if (buildResult.exitCode != 0) {
          CliLogger.debug(buildResult.stderr.toString());
        }

        final analyzeResult = await Process.run(
          'flutter',
          ['analyze', '--no-fatal-infos'],
          workingDirectory: appDir,
        );
        if (analyzeResult.exitCode != 0) {
          lintProgress.fail('린트 실패');
          CliLogger.error('린트 실패:\n${analyzeResult.stdout}');
          return 1;
        }
        lintProgress.complete('코드 생성 + 린트 통과');
      }

      // Step 3: Tests
      if (!(args['skip-tests'] as bool)) {
        final testProgress = ProgressIndicator(message: '테스트 실행');
        testProgress.start();

        final testResult = await Process.run(
          'flutter',
          ['test', '--no-pub'],
          workingDirectory: appDir,
        );
        if (testResult.exitCode != 0) {
          testProgress.fail('테스트 실패');
          CliLogger.error('테스트 실패:\n${testResult.stdout}');
          return 1;
        }
        testProgress.complete('테스트 통과');
      }

      if (dryRun) {
        stdout.writeln('\n✅ Dry run 완료 - 모든 검증 통과');
        return 0;
      }

      // Step 4: Version bump
      final bumpProgress = ProgressIndicator(message: '버전 범프 ($bump)');
      bumpProgress.start();
      final bumpResult = await _runFastlane('bump_version', ['type:$bump'], verbose);
      if (bumpResult != 0) {
        bumpProgress.fail('버전 범프 실패');
        return 1;
      }
      bumpProgress.complete('버전 범프 완료');

      // Step 5: Screenshots (optional)
      if (generateScreenshots) {
        final enhance = args['enhance-screenshots'] as bool;
        final screenshotProgress = ProgressIndicator(
            message: enhance ? '스크린샷 생성 + adlab 목업화' : '스크린샷 생성');
        screenshotProgress.start();
        // generate_screenshots 레인은 ./run screenshot 위임 shim —
        // ENHANCE_SCREENSHOTS=true면 shim이 --enhance를 덧붙인다.
        final ssResult = await _runFastlane('generate_screenshots', [], verbose,
            environment:
                enhance ? const {'ENHANCE_SCREENSHOTS': 'true'} : null);
        if (ssResult != 0) {
          screenshotProgress.fail('스크린샷 생성 실패');
          return 1;
        }
        screenshotProgress.complete('스크린샷 생성 완료');
      }

      // Step 6: Auto-generate release notes (Fastlane SSOT)
      final releaseNotesProgress =
          ProgressIndicator(message: '릴리스 노트 생성');
      releaseNotesProgress.start();
      final rnResult =
          await _runFastlane('generate_release_notes', [], verbose);
      if (rnResult != 0) {
        releaseNotesProgress.fail('릴리스 노트 생성 실패');
        return 1;
      }
      releaseNotesProgress.complete('릴리스 노트 생성 완료');

      // Step 7: Build & Upload (only build+push, other steps already done)
      final deployProgress = ProgressIndicator(message: '빌드 & 업로드');
      deployProgress.start();
      final deployArgs = <String>[
        'target:$target',
        'platform:$platform',
      ];
      final deployResult =
          await _runFastlane('build_and_upload', deployArgs, verbose);
      if (deployResult != 0) {
        deployProgress.fail('배포 실패');
        return 1;
      }
      deployProgress.complete('빌드 & 업로드 완료');

      // Step 8: Upload metadata (production only)
      if (target == 'production') {
        final metadataProgress =
            ProgressIndicator(message: '메타데이터 업로드');
        metadataProgress.start();
        await _uploadMetadata(platform, verbose,
            uploadScreenshots: generateScreenshots);
        metadataProgress.complete('메타데이터 업로드 완료');

        // Step 8b: App Privacy(iOS 영양표시) 업로드 — 기능 셋에서 생성 후 업로드.
        // ASC 최초 제출은 App Privacy가 채워져야 심사 제출이 가능하다.
        if (platform == 'ios' || platform == 'all') {
          final privacyProgress =
              ProgressIndicator(message: 'App Privacy 업로드');
          privacyProgress.start();
          await _uploadAppPrivacy(verbose);
          privacyProgress.complete('App Privacy 업로드 완료');
        }

        // Step 8c: IAP/구독 상품 등록 — 수익화 앱은 바이너리가 참조하는 상품이
        // ASC/Play에 실제로 등록돼 있어야 심사를 통과한다. project.yaml에 IAP가
        // 설정된 경우에만 (재)생성 후 upload_iap 레인으로 업로드한다.
        if (await _isIapConfigured()) {
          final iapProgress = ProgressIndicator(message: 'IAP/구독 상품 등록');
          iapProgress.start();
          await _uploadIap(platform, verbose);
          iapProgress.complete('IAP/구독 상품 등록 완료');
        }

        // Step 8d: Play Data Safety 업로드 — 기능 셋에서 CSV 생성 후 업로드.
        // Play Console Data Safety 폼 수동 입력을 파이프라인에서 제거한다.
        // App Privacy(8b)와 동일하게 **비치명적** — 실패해도 배포는 계속된다.
        if (platform == 'android' || platform == 'all') {
          final dataSafetyProgress =
              ProgressIndicator(message: 'Play Data Safety 업로드');
          dataSafetyProgress.start();
          await _uploadDataSafety(verbose);
          dataSafetyProgress.complete('Play Data Safety 업로드 완료');
        }
      }

      // Step 9: iOS 심사 제출 (P1-17c) — 반드시 메타데이터 업로드 이후.
      // (create_new_version_ios 안에서 제출하면 제출된 버전에 메타데이터를
      //  덮어쓰는 역순이 됨.) Android는 production 업로드 = 제출이라 별도
      // 단계 없음.
      if (target == 'production' &&
          submitReview &&
          (platform == 'ios' || platform == 'all')) {
        final submitProgress = ProgressIndicator(message: 'iOS 심사 제출');
        submitProgress.start();
        final submitResult =
            await _runFastlane('submit_ios_review', const [], verbose);
        if (submitResult != 0) {
          // 메타데이터 업로드와 달리 hard fail — 제출이 안 됐는데 성공
          // 요약을 내면 출시가 조용히 누락된다
          submitProgress.fail('iOS 심사 제출 실패');
          return 1;
        }
        submitProgress.complete('iOS 심사 제출 완료');
      }

      // Read version for summary (git tag already created by bump_version)
      final versionResult = await Process.run(
        'grep',
        ['-m1', 'version:', '$appDir/pubspec.yaml'],
      );
      final version =
          versionResult.stdout.toString().replaceAll('version:', '').trim();

      // Summary
      stdout.writeln('');
      stdout.writeln('========================================');
      stdout.writeln('  배포 완료!');
      stdout.writeln('========================================');
      stdout.writeln('  버전: v$version');
      stdout.writeln('  대상: $target');
      stdout.writeln('  플랫폼: $platform');
      stdout.writeln('========================================');

      return 0;
    } catch (e) {
      CliLogger.error('배포 실패: $e');
      return 1;
    }
  }

  Future<bool> _preflight(bool verbose, String target, String platform) async {
    var ok = true;

    // Check .env exists (project root)
    final envFile = File('$projectRoot/.env');
    if (!envFile.existsSync()) {
      CliLogger.error(
          '  ✗ .env 파일이 없습니다. ./init을 먼저 실행하세요.');
      ok = false;
    } else {
      stdout.writeln('  ✓ .env');
    }

    // Runtime env artifacts: exist + source-hash fresh.
    // stale/missing이면 자동 재생성 (결정적 산출물이므로 안전 — plan §2.3)
    final configFile = File('$projectRoot/app_config.yaml');
    if (!configFile.existsSync()) {
      CliLogger.warning(
          '  ⚠ app_config.yaml이 없어 런타임 env 산출물을 검증/생성할 수 '
          '없습니다.');
    } else {
      try {
        final config = ConfigLoader(configFile.path);
        await config.load();
        final hash = computeSourceHash(projectRoot);
        final allFresh = runtimeEnvModes.every((mode) =>
            isArtifactFresh(File('$appDir/config/env/.env.$mode'), hash));
        if (allFresh) {
          stdout.writeln('  ✓ 런타임 env 산출물 (.env.debug/profile/release)');
        } else {
          await writeRuntimeEnvArtifacts(
            projectRoot: projectRoot,
            appDir: appDir,
            config: config,
          );
          stdout.writeln(
              '  ♻ 런타임 env 산출물이 stale/누락 상태여서 자동 재생성했습니다.');
        }

        // release env 산출물 게이트 (preflight와 동일 — checkRuntimeEnvArtifacts
        // 재사용). production 배포면 광고 여부와 무관하게 전체 게이트를 건다:
        // ①존재 ②신선도 ③광고 ID(adsEnabled self-guard) ④시크릿 누출
        // ⑤법적 URL 템플릿 도메인. 무광고 앱도 ①②④⑤를 우회하지 못한다.
        if (target == 'production') {
          final envIssues = checkRuntimeEnvArtifacts(
            projectRoot: projectRoot,
            appDir: appDir,
            config: config,
          );
          for (final issue in envIssues) {
            if (issue.severity == ArtifactIssueSeverity.fail) {
              CliLogger.error('  ✗ ${issue.message}');
              ok = false;
            }
          }
          if (ok) {
            stdout.writeln('  ✓ release env 산출물 게이트');
          }
        }

        // 프로덕션 게이트 (B2): placeholder 번들 ID + Android release 서명.
        // 표준 ./preflight의 _checkPackageName/_checkSigning과 동일 취지를
        // deploy 경로에도 적용해 잘못된 서명/번들로 출시되는 것을 막는다.
        if (target == 'production') {
          if (config.packageName.startsWith('com.example.')) {
            CliLogger.error(
                '  ✗ package_name이 placeholder(com.example.*)입니다 — '
                'project.yaml에서 실제 값으로 변경하세요.');
            ok = false;
          } else {
            stdout.writeln('  ✓ 패키지명 (${config.packageName})');
          }

          if (platform == 'android' || platform == 'all') {
            final keystorePath = config.keystorePath;
            if (keystorePath.isEmpty) {
              CliLogger.error(
                  '  ✗ Android keystore 미설정 — release AAB가 디버그 서명되어 '
                  'Play가 거부합니다 '
                  '(app_config.yaml signing.android.keystore_path).');
              ok = false;
            } else if (!File(expandUserPath(keystorePath, projectRoot: projectRoot))
                .existsSync()) {
              CliLogger.error('  ✗ Android keystore 파일 없음: $keystorePath');
              ok = false;
            } else {
              stdout.writeln('  ✓ Android keystore');
            }
          }

          // 스토어/서명 자격증명 placeholder 가드 (B4): 미편집 placeholder나
          // 저자 기본값으로 App Store에 출시되는 것을 차단한다.
          if (platform == 'ios' || platform == 'all') {
            bool isPlaceholder(String v) =>
                v.isEmpty ||
                v.contains('XXXX') ||
                v.contains('xxxx') ||
                v.contains('your-org') ||
                v.contains('you@example.com');
            final bad = <String>[
              if (isPlaceholder(config.appleId)) 'store.apple.apple_id',
              if (isPlaceholder(config.iosTeamId)) 'platforms.ios.team_id',
              if (isPlaceholder(config.apiKeyId)) 'store.apple.api_key_id',
              if (isPlaceholder(config.matchGitUrl))
                'signing.ios.match_git_url',
            ];
            if (bad.isNotEmpty) {
              CliLogger.error(
                  '  ✗ iOS 스토어/서명 값이 placeholder입니다: ${bad.join(', ')} — '
                  'app_config.yaml을 실제 값으로 채우세요.');
              ok = false;
            } else {
              stdout.writeln('  ✓ iOS 스토어/서명 자격증명');
            }
          }

          // 개인정보처리방침 URL 게이트 (A1): production 제출은 호스팅된
          // 개인정보 URL이 필수다 (없으면 App Store/Play가 제출을 막는다).
          final privacyUrl = config.privacyPolicyUrl.isNotEmpty
              ? config.privacyPolicyUrl
              : deriveLegalUrl(config, projectRoot, 'privacy_policy.html');
          if (privacyUrl.isEmpty) {
            CliLogger.error(
                '  ✗ 개인정보처리방침 URL이 없습니다 — App Store/Play 제출이 '
                '차단됩니다.\n'
                '      해결: `./run generate-legal` 후 `./run deploy-legal '
                '[--target github]`로 호스팅하거나,\n'
                '            project.yaml listing.privacy_policy_url에 직접 '
                'URL을 지정하세요.');
            ok = false;
          } else {
            stdout.writeln('  ✓ 개인정보처리방침 URL ($privacyUrl)');
          }

          // 스토어 리스팅 카피 placeholder 가드: 보일러플레이트 기본 카피가
          // 그대로 deliver로 업로드되면 ASC가 거부하거나 창피한 메타데이터가
          // 출시된다 (OPENAI_API_KEY 없이 ./init 시 generate-desc가 스킵됨).
          final copyIssues = _placeholderListingIssues();
          if (copyIssues.isNotEmpty) {
            CliLogger.error(
                '  ✗ 스토어 리스팅에 placeholder 카피가 남아 있습니다:\n'
                '      ${copyIssues.join('\n      ')}\n'
                '      해결: `./run generate-description`으로 생성하거나 '
                'metadata/ios/<locale>/ 파일을 직접 채우고,\n'
                '            번역하지 않을 로케일 디렉토리는 삭제하세요.');
            ok = false;
          } else {
            stdout.writeln('  ✓ 스토어 리스팅 카피');
          }

          // iOS 마케팅 아이콘 알파 가드: 1024 아이콘에 알파 채널이 있으면
          // App Store가 거부한다 (flutter_launcher_icons remove_alpha_ios).
          final iconAlpha = _iosMarketingIconHasAlpha();
          if (iconAlpha == true) {
            CliLogger.error(
                '  ✗ iOS 1024 마케팅 아이콘에 알파 채널이 있습니다 — App Store가 '
                '거부합니다.\n'
                '      해결: 불투명(알파 없는) 소스로 교체 후 `cd app && dart run '
                'flutter_launcher_icons` 재실행 '
                '(flutter_launcher_icons.yaml remove_alpha_ios: true).');
            ok = false;
          } else if (iconAlpha == false) {
            stdout.writeln('  ✓ iOS 마케팅 아이콘 (알파 없음)');
          }
        }
      } catch (e) {
        CliLogger.error('  ✗ 런타임 env 산출물 생성 실패: $e');
        ok = false;
      }
    }

    // Check Fastlane
    final fastlaneCheck = await Process.run('which', ['fastlane']);
    if (fastlaneCheck.exitCode != 0) {
      CliLogger.error('  ✗ Fastlane이 설치되지 않았습니다.');
      ok = false;
    } else {
      stdout.writeln('  ✓ Fastlane');
    }

    // Check Flutter
    final flutterCheck = await Process.run('flutter', ['--version']);
    if (flutterCheck.exitCode != 0) {
      CliLogger.error('  ✗ Flutter SDK를 찾을 수 없습니다.');
      ok = false;
    } else {
      stdout.writeln('  ✓ Flutter SDK');
    }

    return ok;
  }

  /// metadata/ios/<locale>/ 리스팅 파일에서 보일러플레이트 placeholder 카피를
  /// 찾아 사람이 읽을 수 있는 이슈 목록을 반환한다 (deliver가 전 로케일 폴더를
  /// 업로드하므로 모든 로케일을 검사).
  List<String> _placeholderListingIssues() {
    final issues = <String>[];
    final metaDir = Directory('$projectRoot/metadata/ios');
    if (!metaDir.existsSync()) return issues;

    for (final entry in metaDir.listSync().whereType<Directory>()) {
      final locale = entry.path.split(Platform.pathSeparator).last;

      String read(String name) {
        final f = File('${entry.path}/$name');
        return f.existsSync() ? f.readAsStringSync().trim() : '';
      }

      final desc = read('description.txt');
      if (desc.contains('Replace this placeholder') ||
          desc.contains('boilerplate template')) {
        issues.add('$locale/description.txt (placeholder)');
      }
      final keywords = read('keywords.txt');
      if (keywords == 'app, productivity') {
        issues.add('$locale/keywords.txt (placeholder)');
      }
      if (read('marketing_url.txt').contains('example.com')) {
        issues.add('$locale/marketing_url.txt (example.com)');
      }
    }
    return issues;
  }

  /// 컴파일된 iOS 1024 마케팅 아이콘이 알파 채널을 갖는지 PNG IHDR에서 판정.
  /// true=알파 있음(거부 대상), false=불투명, null=파일 없음/판정 불가.
  bool? _iosMarketingIconHasAlpha() {
    final f = File('$appDir/ios/Runner/Assets.xcassets/AppIcon.appiconset/'
        'Icon-App-1024x1024@1x.png');
    if (!f.existsSync()) return null;
    try {
      final bytes = f.readAsBytesSync();
      // PNG 서명(8) + IHDR: width(4)@16, height(4)@20, bitDepth(1)@24,
      // colorType(1)@25. colorType 4(Gray+Alpha)/6(RGBA) → 알파 채널.
      if (bytes.length < 26) return null;
      final colorType = bytes[25];
      return colorType == 4 || colorType == 6;
    } catch (_) {
      return null;
    }
  }

  Future<int> _runFastlane(String lane, List<String> args, bool verbose,
      {Map<String, String>? environment}) async {
    return FastlaneOutputParser.runLane(
      lane: lane,
      args: args,
      workingDirectory: fastlaneDir,
      verbose: verbose,
      environment: environment,
    );
  }

  /// 메타데이터를 스토어에 업로드합니다.
  /// metadata.rb의 upload_metadata lane이 iOS/Android 병렬 업로드를 처리합니다.
  ///
  /// [uploadScreenshots]가 true면 deliver/supply의 스크린샷 업로드 게이트
  /// (`ENV['SKIP_SCREENSHOTS'] != 'false'`, ios.rb/android.rb)에 맞춰
  /// `SKIP_SCREENSHOTS=false`를 자식 fastlane 프로세스에 주입한다. 이렇게 해야
  /// `./deploy --no-skip-screenshots`가 스크린샷을 *생성*만 하고 끝나지 않고
  /// 실제로 업로드까지 한다 (첫 App Store 제출은 스크린샷이 필수).
  Future<void> _uploadMetadata(String platform, bool verbose,
      {bool uploadScreenshots = false}) async {
    final result = await _runFastlane(
      'upload_metadata',
      ['platform:$platform'],
      verbose,
      environment: uploadScreenshots ? const {'SKIP_SCREENSHOTS': 'false'} : null,
    );
    if (result != 0 && verbose) {
      CliLogger.warning('메타데이터 업로드 실패 (계속 진행)');
    }
  }

  /// Apple App Privacy(영양표시)를 기능 셋에서 생성 후 업로드합니다.
  ///
  /// app_config.yaml의 활성 기능에서 `metadata/app_privacy_details.json`을
  /// 결정적으로 생성하고(generate-data-safety와 동일 SSOT), privacy.rb의
  /// `upload_privacy_details` 레인으로 ASC에 업로드합니다. 메타데이터 업로드와
  /// 동일하게 **비치명적** — 실패해도 배포는 계속됩니다.
  Future<void> _uploadAppPrivacy(bool verbose) async {
    try {
      final configFile = File('$projectRoot/app_config.yaml');
      ConfigLoader? config;
      if (configFile.existsSync()) {
        config = ConfigLoader(configFile.path);
        await config.load();
      }
      final inputs = buildDataSafetyInputs(config);
      final dir = Directory('$projectRoot/metadata')
        ..createSync(recursive: true);
      File('${dir.path}/app_privacy_details.json')
          .writeAsStringSync(renderAppPrivacyJson(inputs));
    } catch (e) {
      if (verbose) {
        CliLogger.warning('App Privacy 파일 생성 실패 (계속 진행): $e');
      }
      return;
    }
    final result =
        await _runFastlane('upload_privacy_details', const [], verbose);
    if (result != 0 && verbose) {
      CliLogger.warning('App Privacy 업로드 실패 (계속 진행)');
    }
  }

  /// Google Play Data Safety를 기능 셋에서 CSV로 생성 후 업로드합니다.
  ///
  /// app_config.yaml의 활성 기능에서 `metadata/data_safety/data_safety.csv`를
  /// 결정적으로 생성하고(generate-data-safety와 동일 SSOT), privacy.rb의
  /// `upload_data_safety` 레인으로 androidpublisher dataSafety API에 올립니다.
  /// App Privacy 업로드와 동일하게 **비치명적** — 실패해도 배포는 계속됩니다.
  Future<void> _uploadDataSafety(bool verbose) async {
    try {
      final configFile = File('$projectRoot/app_config.yaml');
      ConfigLoader? config;
      if (configFile.existsSync()) {
        config = ConfigLoader(configFile.path);
        await config.load();
      }
      final inputs = buildDataSafetyInputs(config);
      // 레인 계약 경로: <root>/metadata/data_safety/data_safety.csv
      // (generate-data-safety의 기본 outputDir과 동일 — 고정 경로).
      final dir = Directory('$projectRoot/metadata/data_safety')
        ..createSync(recursive: true);
      File('${dir.path}/data_safety.csv')
          .writeAsStringSync(renderPlayCsv(inputs));
    } catch (e) {
      if (verbose) {
        CliLogger.warning('Data Safety CSV 생성 실패 (계속 진행): $e');
      }
      return;
    }
    final result =
        await _runFastlane('upload_data_safety', const [], verbose);
    if (result != 0 && verbose) {
      CliLogger.warning('Play Data Safety 업로드 실패 (계속 진행)');
    }
  }

  /// project.yaml에 IAP/구독 상품이 설정돼 있는지 확인합니다.
  ///
  /// monetization.subscription.enabled가 켜져 있거나 iap.products /
  /// iap.subscriptions가 비어 있지 않으면 true. 설정이 없으면 deploy의 IAP
  /// 업로드 단계를 건너뛴다 (무료 앱은 영향 없음).
  Future<bool> _isIapConfigured() async {
    final configFile = File('$projectRoot/app_config.yaml');
    if (!configFile.existsSync()) return false;
    try {
      final config = ConfigLoader(configFile.path);
      await config.load();
      return config.subscriptionEnabled ||
          config.iapProducts.isNotEmpty ||
          config.iapSubscriptions.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// IAP/구독 상품을 (재)생성 후 스토어에 등록합니다.
  ///
  /// 1. `iap-register`를 실행해 project.yaml에서 `metadata/in_app_purchases`의
  ///    JSON을 최신 상태로 (재)생성한다 (App Privacy와 동일한 생성→업로드 패턴).
  /// 2. `upload_iap` 레인으로 ASC/Play에 상품을 등록한다.
  ///
  /// 메타데이터/App Privacy 업로드와 동일하게 **비치명적** — 실패해도 배포는
  /// 계속되지만, 등록이 누락되면 심사에서 거부되므로 실패 시 경고를 남긴다.
  Future<void> _uploadIap(String platform, bool verbose) async {
    // Step 1: project.yaml → metadata/in_app_purchases JSON (재)생성.
    try {
      final genResult = await IapRegisterCommand(projectRoot: projectRoot)
          .run(['--platform', platform, if (verbose) '--verbose']);
      if (genResult != 0) {
        CliLogger.warning(
            'IAP 메타데이터 생성에 실패했습니다 — 기존 파일로 업로드를 시도합니다.');
      }
    } catch (e) {
      if (verbose) {
        CliLogger.warning('IAP 메타데이터 생성 실패 (계속 진행): $e');
      }
    }

    // Step 2: upload_iap 레인으로 등록 (platform 별 — metadata.rb).
    final result =
        await _runFastlane('upload_iap', ['platform:$platform'], verbose);
    if (result != 0) {
      CliLogger.warning(
          'IAP/구독 상품 등록에 실패했습니다 (계속 진행) — 등록이 누락되면 '
          '바이너리가 참조하는 상품이 없어 심사가 거부됩니다. '
          '`cd fastlane && bundle exec fastlane upload_iap`로 재시도하세요.');
    }
  }

  /// 사용법을 출력합니다.
  void printUsage() {
    print(usage);
  }
}
