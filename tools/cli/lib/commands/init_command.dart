import 'dart:io';

import 'package:args/args.dart';

import '../core/command.dart';
import '../core/logger/cli_logger.dart';
import '../core/progress/progress_indicator.dart';
import 'init/init.dart';

/// Full project initialization from app_config.yaml
///
/// Usage:
/// ```bash
/// ./setup init                    # Interactive mode
/// ./setup init --config app_config.yaml  # From config file
/// ./setup init --skip-icon --skip-description  # Skip AI generation
/// ```
class InitCommand extends Command {
  InitCommand({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path;

  final String projectRoot;
  String get appDir => '$projectRoot/app';
  String get fastlaneDir => '$projectRoot/fastlane';

  @override
  String get name => 'init';

  @override
  String get description => '프로젝트 전체 초기화를 수행합니다.\n\n'
      '실행 단계:\n'
      '  1. app_config.yaml 로드\n'
      '  2. 패키지명/번들ID 설정\n'
      '  3. 환경 파일 생성\n'
      '  3.5. Privacy Manifest 생성 (PrivacyInfo.xcprivacy)\n'
      '  3.6. 딥링크 네이티브 선언 생성 (커스텀 스킴)\n'
      '  4. Profile 기반 Feature Flag 설정\n'
      '  5. 코드 서명 설정 (iOS Match / Android Keystore)\n'
      '  6. 의존성 설치 + 코드 생성\n'
      '  7. 앱 아이콘 생성 (DALL-E, 선택)\n'
      '  8. 스토어 설명 생성 (GPT-4o, 선택)\n'
      '  9. Fastlane 메타데이터 설정\n'
      '  10. 법적 문서 생성\n'
      '  11. Firebase 연동 (자동 생성, 선택)\n'
      '  12. GCloud IAM 설정 (서비스 계정 역할 부여)\n'
      '  13. 스토어 앱 등록 (iOS 자동, Android 가이드)\n'
      '  14. 빌드 검증';

  @override
  ArgParser buildArgParser() {
    return ArgParser()
      ..addOption('config',
          abbr: 'c',
          help: 'app_config.yaml 경로',
          defaultsTo: 'app_config.yaml')
      ..addOption('name', abbr: 'n', help: '앱 이름')
      ..addOption('package', abbr: 'p', help: '패키지명 (com.example.myapp)')
      ..addOption('profile',
          help: 'App profile (minimal/standard/premium/enterprise)',
          defaultsTo: 'standard')
      ..addFlag('skip-firebase',
          help: 'Firebase 설정 건너뛰기', negatable: false)
      ..addFlag('skip-codegen',
          help: '코드 생성 건너뛰기', negatable: false)
      ..addFlag('skip-icon',
          help: '아이콘 생성 건너뛰기', negatable: false)
      ..addFlag('skip-description',
          help: '스토어 설명 생성 건너뛰기', negatable: false)
      ..addFlag('skip-signing',
          help: '코드 서명 설정 건너뛰기', negatable: false)
      ..addFlag('skip-legal',
          help: '법적 문서 생성 건너뛰기', negatable: false)
      ..addFlag('skip-metadata',
          help: '메타데이터 설정 건너뛰기', negatable: false)
      ..addFlag('skip-store',
          help: '스토어 앱 등록 건너뛰기', negatable: false)
      ..addFlag('verbose',
          abbr: 'v', help: '상세 로그 출력', negatable: false);
  }

  @override
  Future<int> execute(ArgResults args) async {
    final verbose = args['verbose'] as bool;
    await CliLogger.init(verbose: verbose);

    print('');
    print('=== 프로젝트 초기화를 시작합니다 ===');
    print('');

    final skipCodegen = args['skip-codegen'] as bool;
    final skipFirebase = args['skip-firebase'] as bool;
    final skipIcon = args['skip-icon'] as bool;
    final skipDescription = args['skip-description'] as bool;
    final skipSigning = args['skip-signing'] as bool;
    final skipLegal = args['skip-legal'] as bool;
    final skipMetadata = args['skip-metadata'] as bool;
    final skipStore = args['skip-store'] as bool;

    // Build step list dynamically
    final steps = <String>[
      'app_config.yaml 로드',
      '패키지명 설정',
      'Profile 적용',
      '환경 파일 생성',
      'Privacy Manifest 생성',
      '딥링크 선언 생성',
      if (!skipSigning) '코드 서명 설정',
      '의존성 설치',
      if (!skipCodegen) '코드 생성',
      if (!skipIcon) '앱 아이콘 생성',
      if (!skipDescription) '스토어 설명 생성',
      if (!skipMetadata) '메타데이터 설정',
      if (!skipLegal) '법적 문서 생성',
      if (!skipFirebase) 'Firebase 설정',
      if (!skipFirebase) 'GCloud IAM 설정',
      if (!skipStore) '스토어 정보 설정',
      if (!skipStore) '스토어 앱 등록',
      '빌드 검증',
    ];

    final progress = StepProgress(steps: steps);
    final summary = InitSummary();

    // soft 스텝 결과를 요약에 기록하고 상태별 진행 라인을 찍는다.
    void record(StepResult r) {
      summary.add(progress.currentStepName, r);
      if (r.ok) {
        progress.completeStep();
      } else if (r.status == StepStatus.skipped) {
        progress.skipStep(r.reason ?? '');
      } else {
        progress.failStep(r.reason ?? '');
      }
    }

    try {
      // Step 1: Load config
      progress.nextStep();
      final configResult = await loadConfigStep(
        projectRoot: projectRoot,
        argName: args['name'] as String?,
        argPackage: args['package'] as String?,
        argProfile: args['profile'] as String?,
        configFileName: args['config'] as String,
        verbose: verbose,
      );
      progress.completeStep();

      final appName = configResult.appName;
      final packageName = configResult.packageName;
      final profile = configResult.profile;
      final config = configResult.config;
      final hasConfig = configResult.hasConfig;

      // hard-fail 스텝(rename/deps/codegen/Firebase)이 필수 실패로 중단될 때도
      // 그때까지의 요약을 반드시 남긴다 — 실패 스텝을 요약에 기록 후 렌더.
      int hardFail(String reason) {
        final step = progress.currentStepName;
        summary.add(step, StepResult.failed(reason));
        print(renderInitOutcome(
          summary: summary,
          appName: appName,
          packageName: packageName,
          profile: profile,
          hardFailStep: step,
        ));
        return 1;
      }

      // Step 2: Rename package — 실패는 hard-fail (P0-5: 묵살 금지)
      progress.nextStep();
      final renameOk = await renamePackageStep(
        projectRoot: projectRoot,
        packageName: packageName,
        appName: appName,
        verbose: verbose,
      );
      if (!renameOk) {
        const reason = '패키지명 변경 실패';
        progress.failStep(reason);
        return hardFail(reason);
      }
      progress.completeStep();

      // Step 3: Apply profile — env 생성보다 먼저 (산출물이 APP_PROFILE을 운반)
      progress.nextStep();
      await applyProfileStep(
        profile: profile,
        projectRoot: projectRoot,
        verbose: verbose,
      );
      progress.completeStep();

      // Step 4: Generate environment files
      // applyProfileStep의 yaml writeback이 반영되도록 config 재로드
      if (hasConfig) {
        await config.load();
      }
      progress.nextStep();
      await generateEnvStep(
        projectRoot: projectRoot,
        appDir: appDir,
        config: config,
        hasConfig: hasConfig,
      );
      progress.completeStep();

      // Step 4.5: Privacy Manifest (활성 기능 셋 → PrivacyInfo.xcprivacy)
      progress.nextStep();
      record(await generatePrivacyStep(
        projectRoot: projectRoot,
        verbose: verbose,
      ));

      // Step 4.6: 딥링크 네이티브 선언 (project.yaml deep_link.scheme →
      // Android intent-filter + iOS CFBundleURLTypes). rename 이후라 번들 ID 확정.
      progress.nextStep();
      record(await generateDeeplinkStep(
        projectRoot: projectRoot,
        verbose: verbose,
      ));

      // Step 5: Signing setup
      if (!skipSigning) {
        progress.nextStep();
        record(await setupSigningStep(
          projectRoot: projectRoot,
          appDir: appDir,
          fastlaneDir: fastlaneDir,
          config: config,
          hasConfig: hasConfig,
          verbose: verbose,
        ));
      }

      // Step 6: Install dependencies
      progress.nextStep();
      final depsOk = await installDependenciesStep(appDir: appDir);
      if (!depsOk) {
        const reason = 'flutter pub get 실패';
        progress.failStep(reason);
        return hardFail(reason);
      }
      progress.completeStep();

      // Step 7: Code generation — 실패는 hard-fail (깨진 트리로 계속 진행 금지)
      if (!skipCodegen) {
        progress.nextStep();
        final codegenOk = await runCodegenStep(appDir: appDir, verbose: verbose);
        if (!codegenOk) {
          const reason = '코드 생성 실패';
          progress.failStep(reason);
          return hardFail(reason);
        }
        progress.completeStep();
      }

      // Step 8: Icon generation
      if (!skipIcon) {
        progress.nextStep();
        record(await generateIconStep(
          appDir: appDir,
          config: config,
          hasConfig: hasConfig,
          appName: appName,
          verbose: verbose,
        ));
      }

      // Step 9: Store description generation
      if (!skipDescription) {
        progress.nextStep();
        record(await generateDescriptionStep(
          projectRoot: projectRoot,
          config: config,
          hasConfig: hasConfig,
          appName: appName,
          verbose: verbose,
        ));
      }

      // Step 10: Metadata setup
      if (!skipMetadata) {
        progress.nextStep();
        record(await setupMetadataStep(
          projectRoot: projectRoot,
          config: config,
          hasConfig: hasConfig,
          appName: appName,
          verbose: verbose,
        ));
      }

      // Step 11: Legal documents
      if (!skipLegal) {
        progress.nextStep();
        record(await generateLegalStep(
          projectRoot: projectRoot,
          config: config,
          hasConfig: hasConfig,
          appName: appName,
          verbose: verbose,
        ));
      }

      // Firebase setup (conditional) — 실패는 hard-fail (B1: 묵살 금지).
      // 커밋된 boilerplate-2024 설정이 그대로 남아 잘못된 프로젝트로 출시되는
      // 사고를 막는다. 우회: `firebase login` 후 재실행 또는 `--skip-firebase`.
      if (!skipFirebase) {
        progress.nextStep();
        if (hasConfig && config.firebaseEnabled) {
          final firebaseOk = await setupFirebaseStep(
            appDir: appDir,
            config: config,
            verbose: verbose,
          );
          if (!firebaseOk) {
            const reason = 'Firebase 설정 실패';
            progress.failStep(reason);
            CliLogger.error(
                'Firebase가 활성화돼 있으나 재설정이 반영되지 않았습니다 — '
                '커밋된 boilerplate-2024 설정이 그대로 남아 잘못된 Firebase '
                '프로젝트로 출시될 위험이 있습니다.');
            print('  해결: `firebase login` 확인 후 재실행하거나, Firebase 없이');
            print('        진행하려면 `--skip-firebase`로 다시 실행하세요.');
            return hardFail(reason);
          }
        }
        progress.completeStep();
      }

      // GCloud IAM setup (after Firebase, needs project ID)
      if (!skipFirebase) {
        progress.nextStep();
        if (hasConfig && config.firebaseEnabled) {
          record(await setupGcloudIamStep(
            projectRoot: projectRoot,
            config: config,
            verbose: verbose,
          ));
        } else {
          progress.completeStep();
        }
      }

      // Store info setup (category, age rating, IAP files)
      if (!skipStore) {
        progress.nextStep();
        if (hasConfig) {
          record(await setupStoreInfoStep(
            projectRoot: projectRoot,
            config: config,
            verbose: verbose,
          ));
        } else {
          progress.completeStep();
        }
      }

      // Store app registration
      if (!skipStore) {
        progress.nextStep();
        if (hasConfig) {
          record(await registerStoreAppsStep(
            projectRoot: projectRoot,
            fastlaneDir: fastlaneDir,
            config: config,
            verbose: verbose,
          ));
        } else {
          progress.completeStep();
        }
      }

      // Build verification
      progress.nextStep();
      record(await verifyBuildStep(appDir: appDir, verbose: verbose));

      print(renderInitOutcome(
        summary: summary,
        appName: appName,
        packageName: packageName,
        profile: profile,
      ));
      return 0;
    } catch (e) {
      CliLogger.error('초기화 실패: $e');
      return 1;
    }
  }
}
