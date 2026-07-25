import 'dart:io';

import 'package:test/test.dart';

/// 로깅 시스템 통합 테스트.
///
/// 실제 파일 시스템과 프로세스를 사용하여 로깅 동작을 검증합니다.
void main() {
  final cliPath = Directory.current.path;
  final testLogDir = Directory('$cliPath/.boilerplate/logs');

  setUp(() async {
    // 테스트용 로그 디렉토리 정리
    if (testLogDir.existsSync()) {
      // 오늘 날짜의 로그 파일만 삭제
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final testLogFile = File('${testLogDir.path}/cli-$dateStr.log');
      if (testLogFile.existsSync()) {
        testLogFile.deleteSync();
      }
    }
  });

  tearDown(() async {
    // 테스트 후 정리
    if (testLogDir.existsSync()) {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final testLogFile = File('${testLogDir.path}/cli-$dateStr.log');
      if (testLogFile.existsSync()) {
        testLogFile.deleteSync();
      }
    }
  });

  group('Logging Integration', () {
    group('log directory creation', () {
      test('creates .boilerplate/logs directory', () async {
        // 로그 디렉토리 생성 테스트
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  await CliLogger.init();
  print('INIT_OK');
}
''';
        final tempFile = File('$cliPath/test_dir_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('INIT_OK'));
          expect(testLogDir.existsSync(), isTrue);
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('log file creation', () {
      test('creates date-based log file', () async {
        // 로깅 테스트를 위한 인라인 스크립트 실행
        final testScript = '''
import 'dart:io';
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  await CliLogger.init();
  CliLogger.info('테스트 로그 메시지');
  print('LOG_FILE: \${CliLogger.logFile?.path}');
}
''';
        final tempFile = File('$cliPath/test_logging_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('LOG_FILE:'));
          expect(result.stdout.toString(), contains('.boilerplate/logs/cli-'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('log content format', () {
      test('logs follow correct format', () async {
        final testScript = '''
import 'dart:io';
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  await CliLogger.init();
  CliLogger.info('포맷 테스트 메시지');

  final content = CliLogger.logFile?.readAsStringSync() ?? '';
  if (content.contains('[INFO] 포맷 테스트 메시지')) {
    print('FORMAT_OK');
  }

  // 타임스탬프 형식 확인
  if (RegExp(r'\\[\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}\\]').hasMatch(content)) {
    print('TIMESTAMP_OK');
  }
}
''';
        final tempFile = File('$cliPath/test_format_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('FORMAT_OK'));
          expect(result.stdout.toString(), contains('TIMESTAMP_OK'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('verbose mode', () {
      test('DEBUG logs print to console in verbose mode', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  await CliLogger.init(verbose: true);
  CliLogger.debug('디버그 verbose 테스트');
}
''';
        final tempFile = File('$cliPath/test_verbose_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('[DEBUG]'));
          expect(result.stdout.toString(), contains('디버그 verbose 테스트'));
        } finally {
          tempFile.deleteSync();
        }
      });

      test('DEBUG logs do not print to console in normal mode', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  await CliLogger.init(verbose: false);
  CliLogger.debug('디버그 normal 테스트');
  print('DONE');
}
''';
        final tempFile = File('$cliPath/test_normal_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          // DEBUG 로그가 콘솔에 출력되지 않아야 함
          expect(
            result.stdout.toString().contains('[DEBUG] 디버그 normal 테스트'),
            isFalse,
          );
          expect(result.stdout.toString(), contains('DONE'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('error logging', () {
      test('ERROR logs always print to console', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  await CliLogger.init(verbose: false);
  CliLogger.error('에러 메시지 테스트');
}
''';
        final tempFile = File('$cliPath/test_error_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('[ERROR]'));
          expect(result.stdout.toString(), contains('에러 메시지 테스트'));
        } finally {
          tempFile.deleteSync();
        }
      });

      test('ERROR logs include stack trace when provided', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  await CliLogger.init(verbose: false);
  try {
    throw Exception('테스트 예외');
  } catch (e, stackTrace) {
    CliLogger.error('예외 발생: \$e', stackTrace);
  }
}
''';
        final tempFile = File('$cliPath/test_stacktrace_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('[ERROR]'));
          expect(result.stdout.toString(), contains('테스트 예외'));
          // 스택 트레이스 포함 확인
          expect(result.stdout.toString(), contains('test_stacktrace_temp.dart'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('file persistence', () {
      test('logs are appended to file', () async {
        final testScript = '''
import 'dart:io';
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  await CliLogger.init();

  CliLogger.info('첫 번째 로그');
  CliLogger.info('두 번째 로그');
  CliLogger.info('세 번째 로그');

  final content = CliLogger.logFile?.readAsStringSync() ?? '';

  if (content.contains('첫 번째 로그') &&
      content.contains('두 번째 로그') &&
      content.contains('세 번째 로그')) {
    print('APPEND_OK');
  }
}
''';
        final tempFile = File('$cliPath/test_append_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('APPEND_OK'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('all log levels', () {
      test('all levels write to file', () async {
        final testScript = '''
import 'dart:io';
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  await CliLogger.init();

  CliLogger.debug('DEBUG 레벨');
  CliLogger.info('INFO 레벨');
  CliLogger.warning('WARNING 레벨');
  CliLogger.error('ERROR 레벨');

  final content = CliLogger.logFile?.readAsStringSync() ?? '';

  var checks = 0;
  if (content.contains('[DEBUG] DEBUG 레벨')) checks++;
  if (content.contains('[INFO] INFO 레벨')) checks++;
  if (content.contains('[WARNING] WARNING 레벨')) checks++;
  if (content.contains('[ERROR] ERROR 레벨')) checks++;

  print('LEVELS_CHECK: \$checks/4');
}
''';
        final tempFile = File('$cliPath/test_levels_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('LEVELS_CHECK: 4/4'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });
  });
}
