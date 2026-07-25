import 'dart:io';

import 'package:args/args.dart';

import '../core/command.dart';
import '../core/config_loader.dart';
import '../core/env_artifacts.dart';
import '../core/error_handler.dart';
import '../core/logger/cli_logger.dart';
import '../core/progress/progress_indicator.dart';
import '../core/validators/sdk_validator.dart';

/// 프로젝트 초기 설정을 수행하는 명령어.
///
/// 새 프로젝트를 설정하거나 기존 설정을 업데이트합니다.
///
/// ## 사용법
/// ```bash
/// ./setup [options]
/// ```
///
/// ## 옵션
/// - `--force`, `-f`: 기존 설정을 덮어씁니다
/// - `--verbose`, `-v`: 자세한 로그를 출력합니다
/// - `--check-env`: 환경 설정 검증만 수행합니다
/// - `--skip-codegen`: 코드 생성을 건너뜁니다
/// - `--help`, `-h`: 도움말을 표시합니다
///
/// ## 실행 단계
/// 1. Flutter SDK 버전 검증 (>=3.8.0)
/// 2. Dart SDK 버전 검증 (>=3.0.0)
/// 3. 의존성 설치 (flutter pub get)
/// 4. 코드 생성 (build_runner)
/// 5. 환경 파일 생성 (.env.{debug,profile,release} — env_artifacts.dart)
class SetupCommand extends Command {
  /// 생성자.
  SetupCommand({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path;

  /// 프로젝트 루트 디렉토리.
  final String projectRoot;

  /// 앱 디렉토리 경로.
  String get appDir => '$projectRoot/app';

  @override
  String get name => 'setup';

  @override
  String get description => '프로젝트 초기 설정을 수행합니다.\n\n'
      '실행 단계:\n'
      '  1. SDK 버전 검증 (Flutter >=3.8.0, Dart >=3.0.0)\n'
      '  2. 의존성 설치 (flutter pub get)\n'
      '  3. 코드 생성 (Freezed, Drift, Riverpod)\n'
      '  4. 환경 파일 생성 (.env.debug/profile/release)';

  @override
  ArgParser buildArgParser() {
    return ArgParser()
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: '기존 설정을 강제로 덮어씁니다.',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: '자세한 실행 로그를 출력합니다.',
      )
      ..addFlag(
        'check-env',
        negatable: false,
        help: '환경 설정 검증만 수행합니다.',
      )
      ..addFlag(
        'skip-codegen',
        negatable: false,
        help: '코드 생성을 건너뜁니다.',
      );
  }

  @override
  Future<int> execute(ArgResults args) async {
    final isForce = args['force'] as bool;
    final isVerbose = args['verbose'] as bool;
    final isCheckEnv = args['check-env'] as bool;
    final skipCodegen = args['skip-codegen'] as bool;

    // 로거 초기화
    await CliLogger.init(verbose: isVerbose);

    if (isVerbose) {
      CliLogger.debug('Setup 명령어를 시작합니다...');
      CliLogger.debug('  Project Root: $projectRoot');
      CliLogger.debug('  Force 모드: ${isForce ? "활성화" : "비활성화"}');
      CliLogger.debug('  Verbose 모드: 활성화');
      CliLogger.debug('  Skip Codegen: ${skipCodegen ? "활성화" : "비활성화"}');
    }

    print('');
    print('🚀 Flutter BoilerPlate 프로젝트 설정을 시작합니다...');
    print('');

    // 환경 검증 모드
    if (isCheckEnv) {
      final progress = StepProgress(steps: ['SDK 버전 검증']);
      progress.nextStep();
      try {
        await _validateSdk(isVerbose);
        progress.completeStep();
      } catch (e) {
        progress.failStep(e.toString());
        rethrow;
      }
      print('');
      print('✅ 환경 검증이 완료되었습니다.');
      return 0;
    }

    // 단계 목록 구성
    final steps = <String>[
      'SDK 버전 검증',
      '의존성 설치',
      if (!skipCodegen) '코드 생성',
      '환경 파일 설정',
    ];

    final progress = StepProgress(steps: steps);

    // Step 1: SDK 검증
    progress.nextStep();
    try {
      await _validateSdk(isVerbose);
      progress.completeStep();
    } catch (e) {
      progress.failStep(e.toString());
      rethrow;
    }

    // Step 2: 의존성 설치
    progress.nextStep();
    try {
      await _installDependencies(isVerbose);
      progress.completeStep();
    } catch (e) {
      progress.failStep(e.toString());
      rethrow;
    }

    // Step 3: 코드 생성 (선택적)
    if (!skipCodegen) {
      progress.nextStep();
      try {
        await _runCodeGeneration(isVerbose);
        progress.completeStep();
      } catch (e) {
        progress.failStep(e.toString());
        // 코드 생성 실패는 경고로 처리
        print('    ⚠️  코드 생성 중 일부 오류 발생 (계속 진행)');
      }
    }

    // Step 4: 환경 파일 생성 (.env.{debug,profile,release})
    progress.nextStep();
    try {
      await _generateEnvArtifacts(isVerbose);
      progress.completeStep();
    } catch (e) {
      progress.failStep(e.toString());
      rethrow;
    }

    // 완료 메시지
    _printSuccessMessage();

    return 0;
  }

  /// SDK 버전을 검증합니다.
  Future<void> _validateSdk(bool isVerbose) async {
    final validator = SdkValidator();

    if (isVerbose) {
      print('    Flutter SDK 버전 확인 중...');
    }

    // Flutter SDK 검증
    await validator.validateFlutterVersion();

    if (isVerbose) {
      print('    ✓ Flutter SDK 검증 완료');
      print('    Dart SDK 버전 확인 중...');
    }

    // Dart SDK 검증
    await validator.validateDartVersion();

    if (isVerbose) {
      print('    ✓ Dart SDK 검증 완료');
    }
  }

  /// 의존성을 설치합니다.
  Future<void> _installDependencies(bool isVerbose) async {
    // app 디렉토리 확인
    final appDirectory = Directory(appDir);
    if (!appDirectory.existsSync()) {
      throw CliException(
        'app 디렉토리를 찾을 수 없습니다',
        solution: '프로젝트 루트 디렉토리에서 실행하세요.\n'
            '현재 디렉토리: $projectRoot',
        docsUrl: 'docs/01-GETTING_STARTED.md',
      );
    }

    if (isVerbose) {
      print('    flutter pub get 실행 중...');
    }

    final result = await Process.run(
      'flutter',
      ['pub', 'get'],
      workingDirectory: appDir,
    );

    if (result.exitCode != 0) {
      throw CliException(
        '의존성 설치에 실패했습니다',
        solution: '다음을 확인하세요:\n'
            '  1. 인터넷 연결 상태\n'
            '  2. pubspec.yaml 파일의 유효성\n'
            '  3. flutter doctor 실행하여 환경 확인\n\n'
            '오류 내용:\n${result.stderr}',
        docsUrl: 'docs/01-GETTING_STARTED.md#troubleshooting',
      );
    }

    if (isVerbose) {
      print('    ✓ 의존성 설치 완료');
    }
  }

  /// 코드 생성을 실행합니다.
  Future<void> _runCodeGeneration(bool isVerbose) async {
    if (isVerbose) {
      print('    build_runner 실행 중...');
    }

    final result = await Process.run(
      'dart',
      ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
      workingDirectory: appDir,
    );

    if (result.exitCode != 0) {
      // 코드 생성 실패는 경고로 처리 (의존성 문제일 수 있음)
      if (isVerbose) {
        print('    ⚠ 코드 생성 중 일부 오류 발생');
        print('    ${result.stderr.toString().split('\n').first}');
      }
      // 오류가 있어도 계속 진행 (사용자가 나중에 수동으로 실행 가능)
    } else if (isVerbose) {
      print('    ✓ 코드 생성 완료');
    }
  }

  /// 런타임 env 산출물(.env.{debug,profile,release})을 생성합니다.
  ///
  /// env_artifacts.dart가 단일 작성기 — 산출물은 항상 재생성됩니다.
  /// `app_config.yaml`이 없으면 안내 메시지를 출력하고 건너뜁니다.
  Future<void> _generateEnvArtifacts(bool isVerbose) async {
    final configFile = File('$projectRoot/app_config.yaml');
    if (!configFile.existsSync()) {
      print('    ⚠ app_config.yaml이 없어 환경 파일 생성을 건너뜁니다.');
      print('      ./init 실행 후 ./run gen-env로 생성할 수 있습니다.');
      return;
    }

    final config = ConfigLoader(configFile.path);
    await config.load();
    final written = await writeRuntimeEnvArtifacts(
      projectRoot: projectRoot,
      appDir: appDir,
      config: config,
    );

    if (isVerbose) {
      for (final path in written) {
        print('    - $path 생성됨');
      }
      print('    ✓ 환경 파일 설정 완료');
    }
  }

  /// 성공 메시지를 출력합니다.
  void _printSuccessMessage() {
    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('  ✅ 프로젝트 설정이 완료되었습니다!');
    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('  📌 다음 단계:');
    print('');
    print('  ⚠️  1. 프로젝트 이름 변경 (필수!):');
    print('        ./rename my_awesome_app');
    print('');
    print('        ※ 기능 개발 전에 반드시 먼저 수행하세요!');
    print('');
    print('  2. 앱 실행:');
    print('     cd app && flutter run');
    print('');
    print('  3. 기능 플래그 관리:');
    print('     ./feature status');
    print('');
    print('  📖 문서: docs/01-GETTING_STARTED.md');
    print('');
  }
}
