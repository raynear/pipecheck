import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';

import '../core/command.dart';
import '../core/config_loader.dart';
import '../core/env_artifacts.dart';
import '../core/error_handler.dart';
import '../core/logger/cli_logger.dart';
import '../core/progress/progress_indicator.dart';

/// 코드 생성 명령어.
///
/// Freezed, JSON Serializable, Drift 등의 코드 생성을 실행합니다.
///
/// ## 사용법
/// ```bash
/// ./build [options]
/// ```
///
/// ## 옵션
/// - `--watch`, `-w`: 파일 변경 감지 모드
/// - `--clean`, `-c`: 이전 생성 파일 삭제 후 재생성
/// - `--skip-env`: 환경 파일 생성을 건너뜁니다
/// - `--verbose`, `-v`: 자세한 로그를 출력합니다
/// - `--help`, `-h`: 도움말을 표시합니다
///
/// ## 실행 단계
/// 1. 환경 파일 생성 (.env.{debug,profile,release} 재생성)
/// 2. 의존성 확인 (flutter pub get)
/// 3. 이전 생성 파일 삭제 (--clean 모드)
/// 4. build_runner 실행 (Freezed, JSON Serializable, Drift)
class BuildCommand extends Command {
  /// 생성자.
  BuildCommand({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path;

  /// 프로젝트 루트 디렉토리.
  final String projectRoot;

  /// 앱 디렉토리 경로.
  String get appDir => '$projectRoot/app';

  @override
  String get name => 'build';

  @override
  String get description => '코드 생성을 실행합니다.\n\n'
      '실행 단계:\n'
      '  1. 환경 파일 생성 (.env.debug/profile/release)\n'
      '  2. 의존성 확인 (flutter pub get)\n'
      '  3. 코드 생성 (Freezed, JSON Serializable, Drift)\n'
      '  4. Drift 데이터베이스 코드 생성';

  @override
  ArgParser buildArgParser() {
    return ArgParser()
      ..addFlag(
        'watch',
        abbr: 'w',
        negatable: false,
        help: '파일 변경 감지 모드로 실행합니다.',
      )
      ..addFlag(
        'clean',
        abbr: 'c',
        negatable: false,
        help: '이전 생성 파일을 삭제 후 재생성합니다.',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: '자세한 실행 로그를 출력합니다.',
      )
      ..addFlag(
        'skip-pub-get',
        negatable: false,
        help: 'flutter pub get을 건너뜁니다.',
      )
      ..addFlag(
        'skip-env',
        negatable: false,
        help: '환경 파일 생성(.env.debug/profile/release)을 건너뜁니다.',
      );
  }

  @override
  Future<int> execute(ArgResults args) async {
    final isWatch = args['watch'] as bool;
    final isClean = args['clean'] as bool;
    final isVerbose = args['verbose'] as bool;
    final skipPubGet = args['skip-pub-get'] as bool;
    final skipEnv = args['skip-env'] as bool;

    // 로거 초기화
    await CliLogger.init(verbose: isVerbose);

    if (isVerbose) {
      CliLogger.debug('Build 명령어를 시작합니다...');
      CliLogger.debug('  Project Root: $projectRoot');
      CliLogger.debug('  Watch 모드: ${isWatch ? "활성화" : "비활성화"}');
      CliLogger.debug('  Clean 모드: ${isClean ? "활성화" : "비활성화"}');
    }

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

    print('');
    print('🔧 코드 생성을 시작합니다...');
    print('');

    final stopwatch = Stopwatch()..start();

    // Watch 모드
    if (isWatch) {
      return _runWatchMode(isVerbose, skipPubGet, skipEnv);
    }

    // 단계 목록 구성
    final steps = <String>[
      if (!skipEnv) '환경 파일 생성',
      if (!skipPubGet) '의존성 확인',
      if (isClean) '이전 파일 삭제',
      '코드 생성 (1차)',
      '생성 파일 정리',
      'DB 테이블 동기화',
      '코드 생성 (2차)',
      '생성 파일 정리 (최종)',
    ];

    final progress = StepProgress(steps: steps);

    // Step 1: 환경 파일 생성 (.env.{debug,profile,release} — 항상 재생성)
    if (!skipEnv) {
      progress.nextStep();
      try {
        await _generateEnvArtifacts(isVerbose);
        progress.completeStep();
      } catch (e) {
        progress.failStep(e.toString());
        rethrow;
      }
    }

    // Step 2: 의존성 확인
    if (!skipPubGet) {
      progress.nextStep();
      try {
        await _runPubGet(isVerbose);
        progress.completeStep();
      } catch (e) {
        progress.failStep(e.toString());
        rethrow;
      }
    }

    // Step 3: Clean (선택적)
    if (isClean) {
      progress.nextStep();
      try {
        await _cleanGeneratedFiles(isVerbose);
        progress.completeStep();
      } catch (e) {
        progress.failStep(e.toString());
        rethrow;
      }
    }

    // Step 4: 코드 생성 (1차) — table_generator가 definitions 옆에 산출물 생성
    progress.nextStep();
    try {
      await _runBuildRunner(isVerbose);
      progress.completeStep();
    } catch (e) {
      progress.failStep(e.toString());
      rethrow;
    }

    // Step 5: 생성 파일을 generated/ 디렉토리로 이동
    progress.nextStep();
    try {
      await _runTableGeneratorScript(
          'organize_files.dart', ['--clean'], isVerbose);
      progress.completeStep();
    } catch (e) {
      progress.failStep(e.toString());
      rethrow;
    }

    // Step 6: database.dart 테이블 목록/import 동기화 (2차 생성 전에 실행해야
    // drift가 갱신된 database.dart 기준으로 database.g.dart를 만든다)
    progress.nextStep();
    try {
      await _runTableGeneratorScript('sync_database.dart', [], isVerbose);
      progress.completeStep();
    } catch (e) {
      progress.failStep(e.toString());
      rethrow;
    }

    // Step 7: 코드 생성 (2차) — 동기화된 database.dart로 drift 재생성
    progress.nextStep();
    try {
      await _runBuildRunner(isVerbose);
      progress.completeStep();
    } catch (e) {
      progress.failStep(e.toString());
      rethrow;
    }

    // Step 8: 2차 생성이 definitions/ 옆에 남긴 산출물을 generated/로 이동
    progress.nextStep();
    try {
      await _runTableGeneratorScript(
          'organize_files.dart', ['--clean'], isVerbose);
      progress.completeStep();
    } catch (e) {
      progress.failStep(e.toString());
      rethrow;
    }

    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds / 1000;

    // 성공 메시지
    _printSuccessMessage(elapsed);

    return 0;
  }

  /// 런타임 env 산출물(.env.{debug,profile,release})을 재생성합니다.
  ///
  /// `app_config.yaml`이 없으면 (fork 직후 등) 경고를 출력하고 건너뜁니다.
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
        print('    ✓ $path');
      }
    }
  }

  /// flutter pub get을 실행합니다.
  Future<void> _runPubGet(bool isVerbose) async {
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
        '의존성 확인에 실패했습니다',
        solution: '다음을 확인하세요:\n'
            '  1. 인터넷 연결 상태\n'
            '  2. pubspec.yaml 파일의 유효성\n'
            '  3. flutter doctor 실행하여 환경 확인\n\n'
            '오류 내용:\n${result.stderr}',
      );
    }

    if (isVerbose) {
      print('    ✓ 의존성 확인 완료');
    }
  }

  /// 이전 생성 파일을 삭제합니다.
  Future<void> _cleanGeneratedFiles(bool isVerbose) async {
    if (isVerbose) {
      print('    이전 생성 파일 삭제 중...');
    }

    final result = await Process.run(
      'dart',
      ['run', 'build_runner', 'clean'],
      workingDirectory: appDir,
    );

    if (result.exitCode != 0) {
      // clean 실패는 무시 (파일이 없을 수 있음)
      if (isVerbose) {
        print('    ⚠ clean 중 일부 오류 발생 (무시됨)');
      }
    } else if (isVerbose) {
      print('    ✓ 이전 파일 삭제 완료');
    }
  }

  /// table_generator 스크립트(organize_files/sync_database)를 실행합니다.
  ///
  /// 스크립트가 없는 앱(table_generator 미사용)에서는 조용히 건너뜁니다.
  Future<void> _runTableGeneratorScript(
      String script, List<String> args, bool isVerbose) async {
    final scriptPath = 'lib/data/table_generator/$script';
    if (!File('$appDir/$scriptPath').existsSync()) {
      if (isVerbose) {
        print('    ✓ $script 없음 — 건너뜀');
      }
      return;
    }

    final result = await Process.run(
      'dart',
      [scriptPath, ...args],
      workingDirectory: appDir,
    );

    if (result.exitCode != 0) {
      throw CliException(
        '$script 실행에 실패했습니다',
        solution: '오류 내용:\n${result.stderr}',
      );
    }

    if (isVerbose) {
      print('    ✓ $script 완료');
    }
  }

  /// build_runner를 실행합니다.
  Future<void> _runBuildRunner(bool isVerbose) async {
    if (isVerbose) {
      print('    build_runner 실행 중...');
    }

    final result = await Process.run(
      'dart',
      ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
      workingDirectory: appDir,
    );

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString();
      throw CliException(
        '코드 생성에 실패했습니다',
        solution: '다음을 확인하세요:\n'
            '  1. @freezed, @JsonSerializable 어노테이션 문법\n'
            '  2. part 지시문 (예: part \'file.g.dart\')\n'
            '  3. import 구문\n\n'
            '오류 내용:\n$stderr',
        docsUrl: 'docs/guides/TROUBLESHOOTING.md#code-generation',
      );
    }

    if (isVerbose) {
      final stdout = result.stdout.toString();
      // 생성된 파일 수 추출
      final generatedMatch = RegExp(r'Generated (\d+) outputs').firstMatch(stdout);
      if (generatedMatch != null) {
        print('    ✓ ${generatedMatch.group(1)}개의 파일 생성됨');
      } else {
        print('    ✓ 코드 생성 완료');
      }
    }
  }

  /// Watch 모드로 실행합니다.
  Future<int> _runWatchMode(
      bool isVerbose, bool skipPubGet, bool skipEnv) async {
    // 환경 파일 생성
    if (!skipEnv) {
      print('  [1/2] 환경 파일 생성 중...');
      await _generateEnvArtifacts(isVerbose);
      print('  [1/2] 환경 파일 생성... ✓');
    }

    // 의존성 확인
    if (!skipPubGet) {
      print('  [2/2] 의존성 확인 중...');
      await _runPubGet(isVerbose);
      print('  [2/2] 의존성 확인... ✓');
    }

    print('');
    print('📡 Watch 모드로 실행합니다...');
    print('   파일 변경 시 자동으로 코드가 생성됩니다.');
    print('   종료하려면 Ctrl+C를 누르세요.');
    print('');

    // build_runner watch 실행
    final process = await Process.start(
      'dart',
      ['run', 'build_runner', 'watch', '--delete-conflicting-outputs'],
      workingDirectory: appDir,
      mode: ProcessStartMode.inheritStdio,
    );

    // 시그널 처리
    ProcessSignal.sigint.watch().listen((_) {
      process.kill();
    });

    final exitCode = await process.exitCode;
    return exitCode;
  }

  /// 성공 메시지를 출력합니다.
  void _printSuccessMessage(double elapsed) {
    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('  ✅ 코드 생성이 완료되었습니다!');
    print('');
    print('     소요 시간: ${elapsed.toStringAsFixed(1)}초');
    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('  📌 생성된 파일 유형:');
    print('');
    print('  • *.freezed.dart - Freezed 모델');
    print('  • *.g.dart - JSON Serializable');
    print('  • database.g.dart - Drift 데이터베이스');
    print('');
    print('  💡 파일 변경 감지 모드: ./build --watch');
    print('');
  }
}
