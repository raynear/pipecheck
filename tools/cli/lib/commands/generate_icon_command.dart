import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../core/adlab_client.dart';
import '../core/command.dart';
import '../core/error_handler.dart';
import '../core/logger/cli_logger.dart';
import '../core/progress/progress_indicator.dart';

/// 앱 아이콘 생성 명령어.
///
/// adlab(app_icon 전략)으로 앱 아이콘을 생성합니다.
///
/// ## 사용법
/// ```bash
/// ./scripts/generate-icon --prompt "minimalist calendar app icon"
/// ```
///
/// ## 옵션
/// - `--prompt`, `-p`: 아이콘 설명 프롬프트 (필수)
/// - `--style`: 아이콘 스타일 (기본값: modern)
/// - `--seed`: 변형 시드 (재생성 시 다른 결과를 얻고 싶을 때)
/// - `--output`, `-o`: 출력 디렉토리 (기본값: app/assets/launcher_icon/ — P0-8 SSOT)
/// - `--platforms`: 생성 대상 플랫폼 (기본값: all)
/// - `--verbose`, `-v`: 자세한 로그를 출력합니다
/// - `--help`, `-h`: 도움말을 표시합니다
///
/// ## 실행 단계
/// 1. adlab 서버 확인
/// 2. adlab app_icon 잡으로 아이콘 이미지 생성 (1024×1024)
/// 3. 이미지 저장
/// 4. flutter_launcher_icons 실행
class GenerateIconCommand extends Command {
  /// 생성자.
  GenerateIconCommand({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path;

  /// 프로젝트 루트 디렉토리.
  final String projectRoot;

  @override
  String get name => 'generate-icon';

  @override
  String get description => '앱 아이콘을 생성합니다.\n\n'
      '실행 단계:\n'
      '  1. adlab 서버 확인\n'
      '  2. adlab app_icon 잡으로 아이콘 이미지 생성\n'
      '  3. 이미지 파일 저장\n'
      '  4. flutter_launcher_icons 실행';

  @override
  ArgParser buildArgParser() {
    return ArgParser()
      ..addOption(
        'prompt',
        abbr: 'p',
        help: '아이콘 설명 프롬프트 (필수)',
      )
      ..addOption(
        'seed',
        help: '변형 시드 — 같은 프롬프트로 다른 결과를 원할 때 바꿔서 재실행',
        defaultsTo: 'v1',
      )
      ..addOption(
        'style',
        // 자유 문자열 — 프롬프트에 그대로 삽입된다. project.yaml의 icon.style
        // (modern/minimal/playful/professional 등)과 값 집합을 강제로 묶지
        // 않도록 allowed 제약을 두지 않는다 (init 경로와 일관).
        help: '아이콘 스타일 (예: modern, minimal, flat, playful, professional)',
        defaultsTo: 'modern',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: '출력 디렉토리',
        defaultsTo: 'app/assets/launcher_icon/',
      )
      ..addOption(
        'platforms',
        help: '생성 대상 플랫폼',
        defaultsTo: 'all',
        allowed: ['ios', 'android', 'all'],
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: '자세한 실행 로그를 출력합니다.',
      );
  }

  @override
  Future<int> execute(ArgResults args) async {
    final prompt = args['prompt'] as String?;
    final style = args['style'] as String;
    final seed = args['seed'] as String;
    final outputDir = args['output'] as String;
    final platforms = args['platforms'] as String;
    final isVerbose = args['verbose'] as bool;

    // 로거 초기화
    await CliLogger.init(verbose: isVerbose);

    if (isVerbose) {
      CliLogger.debug('GenerateIcon 명령어를 시작합니다...');
      CliLogger.debug('  Project Root: $projectRoot');
      CliLogger.debug('  Style: $style');
      CliLogger.debug('  Seed: $seed');
      CliLogger.debug('  Output: $outputDir');
      CliLogger.debug('  Platforms: $platforms');
    }

    // 프롬프트 검증
    if (prompt == null || prompt.isEmpty) {
      throw CliException(
        '아이콘 설명 프롬프트가 필요합니다',
        solution: '--prompt 옵션으로 아이콘 설명을 입력하세요\n'
            '예: --prompt "minimalist calendar app icon"',
      );
    }

    // adlab 서버 검증
    final client = AdlabClient();
    if (!await client.isUp()) {
      throw CliException(
        'adlab 서버에 연결할 수 없습니다 (${client.base})',
        solution: AdlabClient.startHint,
      );
    }

    print('');
    print('🎨 앱 아이콘 생성을 시작합니다...');
    print('');

    final stopwatch = Stopwatch()..start();

    // 단계 목록 구성
    final steps = <String>[
      'adlab app_icon 잡 실행',
      '이미지 저장',
      'flutter_launcher_icons 실행',
    ];

    final progress = StepProgress(steps: steps);

    // Step 1: adlab app_icon 잡 실행
    progress.nextStep();
    final imageBytes = await client.generateAppIcon(
      app: _appName(),
      prompt: prompt,
      style: style,
      seed: seed,
    );
    if (isVerbose) {
      CliLogger.debug('아이콘 생성 완료 (${imageBytes.length} bytes)');
    }
    progress.completeStep();

    // Step 2: 이미지 저장
    progress.nextStep();
    final outputPath = await _saveImage(
      imageBytes: imageBytes,
      outputDir: outputDir,
      isVerbose: isVerbose,
    );
    progress.completeStep();

    // Step 3: flutter_launcher_icons 실행
    progress.nextStep();
    await _runFlutterLauncherIcons(isVerbose);
    progress.completeStep();

    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds / 1000;

    // 성공 메시지
    _printSuccessMessage(elapsed, outputPath);

    return 0;
  }

  /// adlab 프로파일 조회용 앱 이름 — pubspec 대신 디렉토리명으로 충분.
  String _appName() => p.basename(projectRoot);

  /// 이미지를 파일로 저장합니다.
  Future<String> _saveImage({
    required List<int> imageBytes,
    required String outputDir,
    required bool isVerbose,
  }) async {
    final directory = Directory('$projectRoot/$outputDir');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
      if (isVerbose) {
        print('    디렉토리 생성: $outputDir');
      }
    }

    // 아이콘 SSOT (P0-8): flutter_launcher_icons.yaml image_path와 동일 파일명
    final outputPath = '${directory.path}/icon.png';
    final file = File(outputPath);
    await file.writeAsBytes(imageBytes);

    if (isVerbose) {
      print('    ✓ 이미지 저장 완료: $outputPath');
    }

    return outputPath;
  }

  /// flutter_launcher_icons 패키지를 실행하여 플랫폼별 아이콘을 생성합니다.
  Future<void> _runFlutterLauncherIcons(bool isVerbose) async {
    final appDir = '$projectRoot/app';
    final appDirectory = Directory(appDir);

    if (!appDirectory.existsSync()) {
      if (isVerbose) {
        print('    app 디렉토리가 없습니다. flutter_launcher_icons 건너뜀.');
      }
      return;
    }

    if (isVerbose) {
      print('    flutter_launcher_icons 실행 중...');
    }

    final result = await Process.run(
      'flutter',
      ['pub', 'run', 'flutter_launcher_icons'],
      workingDirectory: appDir,
    );

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString();
      if (isVerbose) {
        print('    flutter_launcher_icons 실행 실패: $stderr');
      }
      print('');
      print('  flutter_launcher_icons 자동 실행에 실패했습니다.');
      print('  수동 실행: cd app && flutter pub run flutter_launcher_icons');
    } else {
      if (isVerbose) {
        print('    flutter_launcher_icons 실행 완료');
      }
    }
  }

  /// 성공 메시지를 출력합니다.
  void _printSuccessMessage(double elapsed, String outputPath) {
    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('  ✅ 앱 아이콘 생성이 완료되었습니다!');
    print('');
    print('     소요 시간: ${elapsed.toStringAsFixed(1)}초');
    print('     저장 위치: $outputPath');
    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('  flutter_launcher_icons로 플랫폼별 아이콘이 생성되었습니다.');
    print('  설정 변경 시: app/flutter_launcher_icons.yaml 수정 (단일 SSOT)');
    print('');
  }
}
