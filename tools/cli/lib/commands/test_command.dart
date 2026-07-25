/// 테스트 명령 구현.
///
/// `./test` 명령으로 Flutter 테스트를 실행하고 커버리지 리포트를 생성합니다.
///
/// ## 사용법
/// ```bash
/// ./test                    # 전체 테스트 실행
/// ./test --coverage         # 커버리지 리포트 생성
/// ./test --unit             # 단위 테스트만 실행
/// ./test --integration      # 통합 테스트만 실행
/// ./test --watch            # 파일 변경 감지 모드
/// ```
library test_command;

import 'dart:async';
import 'dart:io';

import '../core/logger/cli_logger.dart';
import '../core/error_handler.dart';
import '../core/progress/progress_indicator.dart';

/// 테스트 명령을 실행합니다.
class TestCommand {
  /// 프로젝트 루트 경로.
  final String projectRoot;

  /// app 디렉토리 경로.
  late final String appDir;

  /// 테스트 명령을 생성합니다.
  TestCommand({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path {
    appDir = '$projectRoot/app';
  }

  /// 명령을 실행합니다.
  Future<int> run(List<String> arguments) async {
    try {
      final args = _parseArguments(arguments);

      // app 디렉토리 확인
      if (!await Directory(appDir).exists()) {
        throw CliException(
          'app 디렉토리를 찾을 수 없습니다',
          solution: '프로젝트 루트 디렉토리에서 실행하세요',
        );
      }

      if (args['help'] == true) {
        _printHelp();
        return 0;
      }

      final isVerbose = args['verbose'] == true;
      final withCoverage = args['coverage'] == true;
      final unitOnly = args['unit'] == true;
      final integrationOnly = args['integration'] == true;
      final watchMode = args['watch'] == true;

      print('🧪 Flutter 테스트 실행');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('');

      if (watchMode) {
        return await _runWatchMode(isVerbose);
      }

      // 테스트 유형 결정
      String testType = '전체';
      if (unitOnly) testType = '단위';
      if (integrationOnly) testType = '통합';

      print('📋 테스트 유형: $testType 테스트');
      if (withCoverage) print('📊 커버리지 리포트: 활성화');
      print('');

      // 테스트 실행
      final testResult = await _runTests(
        unitOnly: unitOnly,
        integrationOnly: integrationOnly,
        withCoverage: withCoverage,
        isVerbose: isVerbose,
      );

      if (!testResult.success) {
        return 1;
      }

      // 커버리지 분석
      if (withCoverage) {
        await _analyzeCoverage();
      }

      print('');
      print('✅ 테스트가 완료되었습니다!');

      if (withCoverage) {
        print('');
        print('📊 커버리지 리포트: app/coverage/lcov.info');
        print('   HTML 리포트 생성: genhtml app/coverage/lcov.info -o app/coverage/html');
      }

      return 0;
    } on CliException catch (e) {
      CliLogger.error(e.message);
      if (e.solution != null) {
        print('');
        print('💡 해결 방법:');
        print('   ${e.solution}');
      }
      return 1;
    } catch (e) {
      CliLogger.error('예상치 못한 오류가 발생했습니다: $e');
      return 1;
    }
  }

  /// 인자를 파싱합니다.
  Map<String, dynamic> _parseArguments(List<String> arguments) {
    final args = <String, dynamic>{
      'help': false,
      'verbose': false,
      'coverage': false,
      'unit': false,
      'integration': false,
      'watch': false,
    };

    for (var i = 0; i < arguments.length; i++) {
      final arg = arguments[i];
      switch (arg) {
        case '-h':
        case '--help':
          args['help'] = true;
          break;
        case '-v':
        case '--verbose':
          args['verbose'] = true;
          break;
        case '-c':
        case '--coverage':
          args['coverage'] = true;
          break;
        case '-u':
        case '--unit':
          args['unit'] = true;
          break;
        case '-i':
        case '--integration':
          args['integration'] = true;
          break;
        case '-w':
        case '--watch':
          args['watch'] = true;
          break;
      }
    }

    return args;
  }

  /// 도움말을 출력합니다.
  void _printHelp() {
    print('''
Flutter BoilerPlate 테스트 명령

사용법: ./test [options]

옵션:
  -h, --help          도움말 표시
  -v, --verbose       상세 로그 출력
  -c, --coverage      커버리지 리포트 생성
  -u, --unit          단위 테스트만 실행
  -i, --integration   통합 테스트만 실행
  -w, --watch         파일 변경 감지 모드

예시:
  ./test                    전체 테스트 실행
  ./test --coverage         커버리지 리포트와 함께 실행
  ./test --unit             단위 테스트만 실행
  ./test --integration      통합 테스트만 실행
  ./test --watch            파일 변경 시 자동 재실행

커버리지 목표:
  - 단위 테스트: 80% 이상
  - 통합 테스트: 90% 이상
''');
  }

  /// 테스트를 실행합니다.
  Future<TestResult> _runTests({
    required bool unitOnly,
    required bool integrationOnly,
    required bool withCoverage,
    required bool isVerbose,
  }) async {
    final progress = ProgressIndicator(message: '테스트 실행');
    progress.start();

    final args = <String>['test'];

    // 테스트 경로 지정
    if (unitOnly) {
      args.add('test/unit');
    } else if (integrationOnly) {
      args.add('test/integration');
    }

    // 커버리지 옵션
    if (withCoverage) {
      args.add('--coverage');
    }

    // 상세 출력
    if (isVerbose) {
      args.add('--reporter=expanded');
    }

    final result = await Process.run(
      'flutter',
      args,
      workingDirectory: appDir,
      runInShell: true,
    );

    progress.complete();

    // 결과 출력
    final output = result.stdout.toString();
    final errorOutput = result.stderr.toString();

    if (isVerbose || result.exitCode != 0) {
      print('');
      print(output);
      if (errorOutput.isNotEmpty) {
        print(errorOutput);
      }
    }

    // 결과 파싱
    final testResult = _parseTestOutput(output);
    _printTestSummary(testResult);

    return testResult;
  }

  /// 테스트 출력을 파싱합니다.
  TestResult _parseTestOutput(String output) {
    var passed = 0;
    var failed = 0;
    var skipped = 0;

    // "00:XX +X: All tests passed!" 패턴 매칭
    final allPassedRegex = RegExp(r'\+(\d+):\s+All tests passed');
    final allPassedMatch = allPassedRegex.firstMatch(output);
    if (allPassedMatch != null) {
      passed = int.tryParse(allPassedMatch.group(1) ?? '0') ?? 0;
      return TestResult(passed: passed, failed: 0, skipped: 0, success: true);
    }

    // "00:XX +X -Y: Some tests failed" 패턴 매칭
    final someFailedRegex = RegExp(r'\+(\d+)\s*-(\d+)');
    final someFailedMatch = someFailedRegex.firstMatch(output);
    if (someFailedMatch != null) {
      passed = int.tryParse(someFailedMatch.group(1) ?? '0') ?? 0;
      failed = int.tryParse(someFailedMatch.group(2) ?? '0') ?? 0;
    }

    // "~X" 스킵 패턴
    final skippedRegex = RegExp(r'~(\d+)');
    final skippedMatch = skippedRegex.firstMatch(output);
    if (skippedMatch != null) {
      skipped = int.tryParse(skippedMatch.group(1) ?? '0') ?? 0;
    }

    return TestResult(
      passed: passed,
      failed: failed,
      skipped: skipped,
      success: failed == 0,
    );
  }

  /// 테스트 요약을 출력합니다.
  void _printTestSummary(TestResult result) {
    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('  📊 테스트 결과 요약');
    print('');
    print('  ✅ 통과: ${result.passed}');
    if (result.failed > 0) {
      print('  ❌ 실패: ${result.failed}');
    }
    if (result.skipped > 0) {
      print('  ⏭️  스킵: ${result.skipped}');
    }
    print('  📝 전체: ${result.total}');
    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (!result.success) {
      print('');
      print('❌ 일부 테스트가 실패했습니다.');
      print('');
      print('💡 실패한 테스트를 확인하려면:');
      print('   ./test --verbose');
    }
  }

  /// 커버리지를 분석합니다.
  Future<void> _analyzeCoverage() async {
    final coverageFile = File('$appDir/coverage/lcov.info');
    if (!await coverageFile.exists()) {
      print('');
      print('⚠️  커버리지 파일을 찾을 수 없습니다.');
      return;
    }

    final content = await coverageFile.readAsString();
    final coverage = _parseLcov(content);

    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('  📊 커버리지 분석');
    print('');
    print('  라인 커버리지: ${coverage.linePercentage.toStringAsFixed(1)}%');
    print('  함수 커버리지: ${coverage.functionPercentage.toStringAsFixed(1)}%');
    print('');

    // 목표 확인
    const unitTarget = 80.0;
    const integrationTarget = 90.0;

    if (coverage.linePercentage < unitTarget) {
      print('  ⚠️  단위 테스트 목표 미달 (목표: ${unitTarget}%)');
    } else {
      print('  ✅ 단위 테스트 목표 달성 (목표: ${unitTarget}%)');
    }

    if (coverage.linePercentage < integrationTarget) {
      print('  ⚠️  통합 테스트 목표 미달 (목표: ${integrationTarget}%)');
    } else {
      print('  ✅ 통합 테스트 목표 달성 (목표: ${integrationTarget}%)');
    }

    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  /// LCOV 파일을 파싱합니다.
  CoverageResult _parseLcov(String content) {
    var linesHit = 0;
    var linesFound = 0;
    var functionsHit = 0;
    var functionsFound = 0;

    for (final line in content.split('\n')) {
      if (line.startsWith('LH:')) {
        linesHit += int.tryParse(line.substring(3)) ?? 0;
      } else if (line.startsWith('LF:')) {
        linesFound += int.tryParse(line.substring(3)) ?? 0;
      } else if (line.startsWith('FNH:')) {
        functionsHit += int.tryParse(line.substring(4)) ?? 0;
      } else if (line.startsWith('FNF:')) {
        functionsFound += int.tryParse(line.substring(4)) ?? 0;
      }
    }

    return CoverageResult(
      linesHit: linesHit,
      linesFound: linesFound,
      functionsHit: functionsHit,
      functionsFound: functionsFound,
    );
  }

  /// Watch 모드를 실행합니다.
  Future<int> _runWatchMode(bool isVerbose) async {
    print('👀 파일 변경 감지 모드');
    print('   테스트 파일 변경 시 자동으로 테스트를 재실행합니다.');
    print('   종료하려면 Ctrl+C를 누르세요.');
    print('');

    // 초기 테스트 실행
    await _runTests(
      unitOnly: false,
      integrationOnly: false,
      withCoverage: false,
      isVerbose: isVerbose,
    );

    // 파일 감시 시작
    final testDir = Directory('$appDir/test');
    final libDir = Directory('$appDir/lib');

    final subscription = _watchDirectories([testDir, libDir]).listen((event) async {
      if (event.path.endsWith('.dart')) {
        print('');
        print('🔄 변경 감지: ${event.path}');
        print('');

        await _runTests(
          unitOnly: false,
          integrationOnly: false,
          withCoverage: false,
          isVerbose: isVerbose,
        );
      }
    });

    // Ctrl+C 시그널 대기
    await ProcessSignal.sigint.watch().first;
    await subscription.cancel();

    print('');
    print('👋 Watch 모드를 종료합니다.');
    return 0;
  }

  /// 여러 디렉토리를 감시합니다.
  Stream<FileSystemEvent> _watchDirectories(List<Directory> directories) {
    final controller = StreamController<FileSystemEvent>();

    for (final dir in directories) {
      if (dir.existsSync()) {
        dir.watch(recursive: true).listen((event) {
          controller.add(event);
        });
      }
    }

    return controller.stream;
  }
}

/// 테스트 결과.
class TestResult {
  /// 테스트 결과를 생성합니다.
  const TestResult({
    required this.passed,
    required this.failed,
    required this.skipped,
    required this.success,
  });

  /// 통과한 테스트 수.
  final int passed;

  /// 실패한 테스트 수.
  final int failed;

  /// 스킵된 테스트 수.
  final int skipped;

  /// 전체 성공 여부.
  final bool success;

  /// 전체 테스트 수.
  int get total => passed + failed + skipped;
}

/// 커버리지 결과.
class CoverageResult {
  /// 커버리지 결과를 생성합니다.
  const CoverageResult({
    required this.linesHit,
    required this.linesFound,
    required this.functionsHit,
    required this.functionsFound,
  });

  /// 실행된 라인 수.
  final int linesHit;

  /// 전체 라인 수.
  final int linesFound;

  /// 실행된 함수 수.
  final int functionsHit;

  /// 전체 함수 수.
  final int functionsFound;

  /// 라인 커버리지 퍼센트.
  double get linePercentage =>
      linesFound > 0 ? (linesHit / linesFound) * 100 : 0;

  /// 함수 커버리지 퍼센트.
  double get functionPercentage =>
      functionsFound > 0 ? (functionsHit / functionsFound) * 100 : 0;
}
