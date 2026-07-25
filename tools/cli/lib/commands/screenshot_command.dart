import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../core/adlab_client.dart';
import '../core/command.dart';
import '../core/error_handler.dart';
import '../core/logger/cli_logger.dart';
import '../core/progress/progress_indicator.dart';
import 'screenshot/screenshot.dart';
import 'screenshot/screenshot_enhance.dart';
import 'screenshot/screenshot_smoke.dart';

/// 스크린샷 자동화 명령어.
///
/// App Store / Google Play용 앱 스크린샷 캡처를 자동화합니다.
///
/// ## 사용법
/// ```bash
/// ./screenshot [options]
/// ```
///
/// ## 옵션
/// - `--devices`, `-d`: 쉼표로 구분된 디바이스 목록
/// - `--languages`, `-l`: 쉼표로 구분된 언어 목록
/// - `--output`, `-o`: 출력 디렉토리
/// - `--platform`, `-p`: 플랫폼 (ios, android, all)
/// - `--test-file`: 통합 테스트 파일 경로
/// - `--verbose`, `-v`: 자세한 로그 출력
/// - `--help`, `-h`: 도움말 표시
///
/// ## 실행 단계
/// 1. 통합 테스트 파일 존재 확인
/// 2. 디바이스/언어별 출력 디렉토리 생성
/// 3. 디바이스별 flutter drive 실행
/// 4. Fastlane 구조로 스크린샷 정리
/// 5. 요약 출력
class ScreenshotCommand extends Command {
  /// 생성자.
  ScreenshotCommand({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path;

  /// 프로젝트 루트 디렉토리.
  final String projectRoot;

  /// 앱 디렉토리 경로.
  String get appDir => '$projectRoot/app';

  @override
  String get name => 'screenshot';

  @override
  String get description => '앱 스크린샷 캡처를 자동화합니다.\n\n'
      '실행 단계:\n'
      '  1. 통합 테스트 파일 존재 확인\n'
      '  2. 디바이스/언어별 출력 디렉토리 생성\n'
      '  3. 디바이스별 flutter drive 실행\n'
      '  4. Fastlane 구조로 스크린샷 정리\n'
      '  5. 결과 요약 출력';

  @override
  ArgParser buildArgParser() {
    return ArgParser()
      ..addOption(
        'devices',
        abbr: 'd',
        help: '쉼표로 구분된 디바이스 목록.',
        defaultsTo: ScreenshotConstants.defaultDevices,
      )
      ..addOption(
        'languages',
        abbr: 'l',
        help: '쉼표로 구분된 언어 목록.',
        defaultsTo: ScreenshotConstants.defaultLanguages,
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: '스크린샷 출력 디렉토리.',
        defaultsTo: ScreenshotConstants.defaultOutput,
      )
      ..addOption(
        'platform',
        abbr: 'p',
        help: '대상 플랫폼.',
        defaultsTo: 'all',
        allowed: ['ios', 'android', 'all'],
      )
      ..addOption(
        'test-file',
        help: '통합 테스트 파일 경로.',
        defaultsTo: ScreenshotConstants.defaultTestFile,
      )
      ..addFlag(
        'allow-missing-devices',
        negatable: false,
        help: '요청한 시뮬레이터가 없어도 실패하지 않고 부분 캡처합니다 '
            '(기본: 누락 시 hard-fail — ASC 사이즈 슬롯 누락 방지).',
      )
      ..addFlag(
        'enhance',
        negatable: false,
        help: '캡처 후 adlab(store_screenshot batch)으로 마케팅 목업화합니다. '
            '원본은 <output>/originals/에 백업, 파일은 제자리 덮어쓰기. '
            'adlab 서버 필요 (ADLAB_URL, 기본 http://127.0.0.1:8791).',
      )
      ..addFlag(
        'enhance-smoke',
        negatable: false,
        help: 'adlab store_screenshot 라이브 경로(Gemini 실호출)를 더미 1장으로 '
            '검증합니다. 캡처 없이 즉시 실행, 결과물은 임시 디렉토리에만 씁니다 '
            '(비용: Gemini 생성 1건). adlab 서버 필요.',
      )
      ..addOption(
        'seed',
        help: 'adlab enhance 배경/무드 시드 (예: "wood desk"). --enhance 전용.',
        defaultsTo: '',
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
    final devices = (args['devices'] as String)
        .split(',')
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toList();
    final languages = (args['languages'] as String)
        .split(',')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final outputDir = args['output'] as String;
    final platform = args['platform'] as String;
    final testFile = args['test-file'] as String;
    final allowMissing = args['allow-missing-devices'] as bool;
    final isVerbose = args['verbose'] as bool;

    // 로거 초기화
    await CliLogger.init(verbose: isVerbose);

    // 라이브 스모크: 캡처 파이프라인 없이 adlab 라이브 경로만 태운다.
    if (args['enhance-smoke'] as bool) {
      return ScreenshotSmoke.run(
        client: AdlabClient(),
        app: p.basename(projectRoot),
        isVerbose: isVerbose,
      );
    }

    if (isVerbose) {
      CliLogger.debug('Screenshot 명령어를 시작합니다...');
      CliLogger.debug('  Project Root: $projectRoot');
      CliLogger.debug('  디바이스: $devices');
      CliLogger.debug('  언어: $languages');
      CliLogger.debug('  출력 경로: $outputDir');
      CliLogger.debug('  플랫폼: $platform');
      CliLogger.debug('  테스트 파일: $testFile');
    }

    // app 디렉토리 확인
    final appDirectory = Directory(appDir);
    if (!appDirectory.existsSync()) {
      throw CliException(
        'app 디렉토리를 찾을 수 없습니다',
        solution: '프로젝트 루트 디렉토리에서 실행하세요.\n'
            '현재 디렉토리: $projectRoot',
      );
    }

    print('');
    print('📸 스크린샷 자동화를 시작합니다...');
    print('');

    final stopwatch = Stopwatch()..start();

    // 단계 목록 구성
    final steps = <String>[
      '테스트 파일 확인',
      '출력 디렉토리 생성',
      '사용 가능한 디바이스 조회',
      '스크린샷 캡처',
    ];

    final progress = StepProgress(steps: steps);

    // Step 1: 테스트 파일 확인
    progress.nextStep();
    try {
      ScreenshotOutput.validateTestFile(appDir, testFile, isVerbose);
      progress.completeStep();
    } catch (e) {
      progress.failStep(e.toString());
      rethrow;
    }

    // Step 2: 출력 디렉토리 생성
    progress.nextStep();
    try {
      await ScreenshotOutput.createOutputDirectories(
        projectRoot: projectRoot,
        outputDir: outputDir,
        platforms: platform == 'all' ? ['ios', 'android'] : [platform],
        languages: languages,
        isVerbose: isVerbose,
      );
      progress.completeStep();
    } catch (e) {
      progress.failStep(e.toString());
      rethrow;
    }

    // Step 3: 사용 가능한 디바이스 조회
    progress.nextStep();
    List<DeviceInfo> availableDevices;
    try {
      availableDevices = await DeviceDiscovery.getAvailableDevices(
        platform: platform,
        requestedDevices: devices,
        isVerbose: isVerbose,
        allowMissing: allowMissing,
      );
      progress.completeStep();
    } catch (e) {
      progress.failStep(e.toString());
      rethrow;
    }

    // Step 4: 스크린샷 캡처
    progress.nextStep();
    try {
      await ScreenshotCapture.captureScreenshots(
        appDir: appDir,
        projectRoot: projectRoot,
        availableDevices: availableDevices,
        languages: languages,
        outputDir: outputDir,
        testFile: testFile,
        isVerbose: isVerbose,
      );
      progress.completeStep();
    } catch (e) {
      progress.failStep(e.toString());
      rethrow;
    }

    // 캡처 후 크기 검증 (B5): 잘못된 시뮬레이터/손상 캡처 감지.
    ScreenshotOutput.validateCapturedDimensions(
      projectRoot: projectRoot,
      outputDir: outputDir,
      isVerbose: isVerbose,
    );

    // adlab 마케팅 목업화 (opt-in). 사용자가 명시 요청한 단계이므로
    // 서버 부재는 soft-skip이 아니라 hard-fail.
    if (args['enhance'] as bool) {
      await _enhance(
        outputDir: outputDir,
        seed: args['seed'] as String,
        isVerbose: isVerbose,
      );
    }

    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds / 1000;

    // 성공 메시지
    ScreenshotOutput.printSuccessMessage(
      elapsed: elapsed,
      outputDir: outputDir,
      devices: availableDevices,
      languages: languages,
    );

    return 0;
  }

  /// 캡처 산출물을 adlab으로 마케팅 목업화하고 크기를 재검증한다.
  Future<void> _enhance({
    required String outputDir,
    required String seed,
    required bool isVerbose,
  }) async {
    final client = AdlabClient();
    if (!await client.isUp()) {
      throw CliException(
        'adlab 서버에 연결할 수 없습니다 (${client.base})',
        solution: AdlabClient.startHint,
      );
    }

    print('');
    print('🎨 adlab 스크린샷 목업화 중... (원본 → $outputDir/originals/)');
    final report = await ScreenshotEnhancer.enhance(
      client: client,
      // adlab 앱 프로파일 조회용 키 — 프로파일 파일명이 프로젝트 디렉토리
      // 슬러그와 일치하는 관례라 디렉토리명을 쓴다.
      app: p.basename(projectRoot),
      projectRoot: projectRoot,
      outputDir: outputDir,
      seed: seed,
      isVerbose: isVerbose,
    );

    print('  ✓ 목업화 완료: ${report.enhanced}개');
    for (final f in report.failed) {
      print('  ⚠️  생성 실패(원본 유지): $f');
    }
    for (final f in report.flagged) {
      print('  ⚠️  저지 미통과 — 목업을 $outputDir/flagged/로 격리, '
          '원본 유지: $f');
    }
    if (report.enhanced == 0 && report.failed.isNotEmpty) {
      throw CliException(
        'adlab 목업화가 전부 실패했습니다 (${report.failed.length}개)',
        solution: 'adlab 서버 로그를 확인하세요 '
            '(provider 키 GEMINI_API_KEY/OPENAI_API_KEY 설정 여부 포함).',
      );
    }
  }
}
