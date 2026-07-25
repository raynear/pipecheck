import 'dart:io';

import 'package:boilerplate_cli/core/logger/cli_logger.dart';
import 'package:test/test.dart';

void main() {
  group('CliLogger', () {
    late Directory testLogDir;
    late List<String> consoleLogs;

    setUp(() async {
      // 테스트용 로그 디렉토리 설정
      testLogDir = Directory('.boilerplate/logs');
      consoleLogs = [];

      // 로거 리셋
      CliLogger.reset();

      // 테스트용 콘솔 출력 함수 설정
      CliLogger.setTestPrintFunction((msg) => consoleLogs.add(msg));

      // 고정된 시간 설정
      CliLogger.setTestNowFunction(
        () => DateTime(2026, 1, 6, 14, 30, 45),
      );
    });

    tearDown(() async {
      // 테스트 로그 파일 정리
      if (testLogDir.existsSync()) {
        final testLogFile = File('.boilerplate/logs/cli-2026-01-06.log');
        if (testLogFile.existsSync()) {
          testLogFile.deleteSync();
        }
      }
      CliLogger.reset();
    });

    group('LogLevel', () {
      test('has correct labels', () {
        expect(LogLevel.debug.label, equals('DEBUG'));
        expect(LogLevel.info.label, equals('INFO'));
        expect(LogLevel.warning.label, equals('WARNING'));
        expect(LogLevel.error.label, equals('ERROR'));
      });

      test('has all four levels', () {
        expect(LogLevel.values.length, equals(4));
      });
    });

    group('init', () {
      test('initializes logger successfully', () async {
        await CliLogger.init();

        expect(CliLogger.isInitialized, isTrue);
        expect(CliLogger.isVerbose, isFalse);
      });

      test('creates log directory if not exists', () async {
        // 디렉토리가 없으면 삭제
        if (testLogDir.existsSync()) {
          testLogDir.deleteSync(recursive: true);
        }

        await CliLogger.init();

        expect(testLogDir.existsSync(), isTrue);
      });

      test('sets verbose mode when specified', () async {
        await CliLogger.init(verbose: true);

        expect(CliLogger.isVerbose, isTrue);
      });

      test('creates log file with correct name', () async {
        await CliLogger.init();

        expect(CliLogger.logFile, isNotNull);
        expect(CliLogger.logFile!.path, contains('cli-2026-01-06.log'));
      });

      test('logs initialization message', () async {
        await CliLogger.init(verbose: true);

        expect(consoleLogs.any((log) => log.contains('CliLogger 초기화 완료')), isTrue);
      });
    });

    group('debug', () {
      test('writes to file', () async {
        await CliLogger.init();
        consoleLogs.clear(); // init 로그 제거

        CliLogger.debug('테스트 디버그 메시지');

        final content = CliLogger.logFile!.readAsStringSync();
        expect(content, contains('[DEBUG] 테스트 디버그 메시지'));
      });

      test('does not print to console in normal mode', () async {
        await CliLogger.init(verbose: false);
        consoleLogs.clear();

        CliLogger.debug('테스트 디버그 메시지');

        expect(consoleLogs, isEmpty);
      });

      test('prints to console in verbose mode', () async {
        await CliLogger.init(verbose: true);
        consoleLogs.clear();

        CliLogger.debug('테스트 디버그 메시지');

        expect(consoleLogs.any((log) => log.contains('[DEBUG]')), isTrue);
        expect(consoleLogs.any((log) => log.contains('테스트 디버그 메시지')), isTrue);
      });

      test('includes timestamp in log', () async {
        await CliLogger.init();

        CliLogger.debug('테스트');

        final content = CliLogger.logFile!.readAsStringSync();
        expect(content, contains('[2026-01-06 14:30:45]'));
      });
    });

    group('info', () {
      test('writes to file', () async {
        await CliLogger.init();
        consoleLogs.clear();

        CliLogger.info('테스트 정보 메시지');

        final content = CliLogger.logFile!.readAsStringSync();
        expect(content, contains('[INFO] 테스트 정보 메시지'));
      });

      test('does not print to console in normal mode', () async {
        await CliLogger.init(verbose: false);
        consoleLogs.clear();

        CliLogger.info('테스트 정보 메시지');

        expect(consoleLogs, isEmpty);
      });

      test('does not print to console even in verbose mode', () async {
        await CliLogger.init(verbose: true);
        consoleLogs.clear();

        CliLogger.info('테스트 정보 메시지');

        expect(consoleLogs.where((log) => log.contains('[INFO]')), isEmpty);
      });
    });

    group('warning', () {
      test('writes to file', () async {
        await CliLogger.init();
        consoleLogs.clear();

        CliLogger.warning('테스트 경고 메시지');

        final content = CliLogger.logFile!.readAsStringSync();
        expect(content, contains('[WARNING] 테스트 경고 메시지'));
      });

      test('does not print to console in normal mode', () async {
        await CliLogger.init(verbose: false);
        consoleLogs.clear();

        CliLogger.warning('테스트 경고 메시지');

        expect(consoleLogs, isEmpty);
      });

      test('prints to console in verbose mode', () async {
        await CliLogger.init(verbose: true);
        consoleLogs.clear();

        CliLogger.warning('테스트 경고 메시지');

        expect(consoleLogs.any((log) => log.contains('[WARNING]')), isTrue);
        expect(consoleLogs.any((log) => log.contains('테스트 경고 메시지')), isTrue);
      });
    });

    group('error', () {
      test('writes to file', () async {
        await CliLogger.init();
        consoleLogs.clear();

        CliLogger.error('테스트 에러 메시지');

        final content = CliLogger.logFile!.readAsStringSync();
        expect(content, contains('[ERROR] 테스트 에러 메시지'));
      });

      test('always prints to console in normal mode', () async {
        await CliLogger.init(verbose: false);
        consoleLogs.clear();

        CliLogger.error('테스트 에러 메시지');

        expect(consoleLogs.any((log) => log.contains('[ERROR]')), isTrue);
        expect(consoleLogs.any((log) => log.contains('테스트 에러 메시지')), isTrue);
      });

      test('always prints to console in verbose mode', () async {
        await CliLogger.init(verbose: true);
        consoleLogs.clear();

        CliLogger.error('테스트 에러 메시지');

        expect(consoleLogs.any((log) => log.contains('[ERROR]')), isTrue);
      });

      test('includes stack trace when provided', () async {
        await CliLogger.init();
        final stackTrace = StackTrace.current;

        CliLogger.error('테스트 에러', stackTrace);

        final content = CliLogger.logFile!.readAsStringSync();
        expect(content, contains('[ERROR] 테스트 에러'));
        expect(content, contains('cli_logger_test.dart'));
      });

      test('prints stack trace to console', () async {
        await CliLogger.init(verbose: false);
        consoleLogs.clear();
        final stackTrace = StackTrace.current;

        CliLogger.error('테스트 에러', stackTrace);

        expect(consoleLogs.length, greaterThan(1));
        expect(consoleLogs.any((log) => log.contains('cli_logger_test.dart')), isTrue);
      });
    });

    group('log format', () {
      test('follows format: [timestamp] [level] message', () async {
        await CliLogger.init();
        consoleLogs.clear();

        CliLogger.error('포맷 테스트');

        final log = consoleLogs.first;
        // [2026-01-06 14:30:45] [ERROR] 포맷 테스트
        expect(log, matches(r'\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[ERROR\] 포맷 테스트'));
      });

      test('timestamp is correctly formatted', () async {
        await CliLogger.init();

        CliLogger.info('타임스탬프 테스트');

        final content = CliLogger.logFile!.readAsStringSync();
        expect(content, contains('[2026-01-06 14:30:45]'));
      });
    });

    group('file logging', () {
      test('appends to existing log file', () async {
        await CliLogger.init();
        consoleLogs.clear();

        CliLogger.info('첫 번째 메시지');
        CliLogger.info('두 번째 메시지');
        CliLogger.info('세 번째 메시지');

        final content = CliLogger.logFile!.readAsStringSync();
        expect(content, contains('첫 번째 메시지'));
        expect(content, contains('두 번째 메시지'));
        expect(content, contains('세 번째 메시지'));
      });

      test('handles file write without initialization gracefully', () async {
        // 초기화하지 않고 로그 작성 시도
        // 파일에 쓰지 않지만 에러 발생하지 않음
        expect(() => CliLogger.debug('테스트'), returnsNormally);
      });

      test('creates log file in correct directory', () async {
        await CliLogger.init();

        CliLogger.info('테스트');

        expect(CliLogger.logFile!.path, startsWith('.boilerplate/logs/'));
      });

      test('uses date-based file name', () async {
        // 다른 날짜로 테스트
        CliLogger.setTestNowFunction(() => DateTime(2025, 12, 25, 10, 0, 0));
        await CliLogger.init();

        expect(CliLogger.logFile!.path, contains('cli-2025-12-25.log'));

        // 테스트 파일 정리
        if (CliLogger.logFile!.existsSync()) {
          CliLogger.logFile!.deleteSync();
        }
      });
    });

    group('reset', () {
      test('clears all state', () async {
        await CliLogger.init(verbose: true);

        CliLogger.reset();

        expect(CliLogger.isInitialized, isFalse);
        expect(CliLogger.isVerbose, isFalse);
        expect(CliLogger.logFile, isNull);
      });
    });

    group('console output rules', () {
      test('DEBUG: verbose only', () async {
        await CliLogger.init(verbose: false);
        consoleLogs.clear();
        CliLogger.debug('테스트');
        expect(consoleLogs, isEmpty);

        CliLogger.reset();
        consoleLogs.clear();
        CliLogger.setTestPrintFunction((msg) => consoleLogs.add(msg));
        CliLogger.setTestNowFunction(() => DateTime(2026, 1, 6, 14, 30, 45));

        await CliLogger.init(verbose: true);
        consoleLogs.clear();
        CliLogger.debug('테스트');
        expect(consoleLogs.any((log) => log.contains('[DEBUG]')), isTrue);
      });

      test('INFO: never to console', () async {
        await CliLogger.init(verbose: false);
        consoleLogs.clear();
        CliLogger.info('테스트');
        expect(consoleLogs, isEmpty);

        CliLogger.reset();
        consoleLogs.clear();
        CliLogger.setTestPrintFunction((msg) => consoleLogs.add(msg));
        CliLogger.setTestNowFunction(() => DateTime(2026, 1, 6, 14, 30, 45));

        await CliLogger.init(verbose: true);
        consoleLogs.clear();
        CliLogger.info('테스트');
        expect(consoleLogs.where((log) => log.contains('[INFO]')), isEmpty);
      });

      test('WARNING: verbose only', () async {
        await CliLogger.init(verbose: false);
        consoleLogs.clear();
        CliLogger.warning('테스트');
        expect(consoleLogs, isEmpty);

        CliLogger.reset();
        consoleLogs.clear();
        CliLogger.setTestPrintFunction((msg) => consoleLogs.add(msg));
        CliLogger.setTestNowFunction(() => DateTime(2026, 1, 6, 14, 30, 45));

        await CliLogger.init(verbose: true);
        consoleLogs.clear();
        CliLogger.warning('테스트');
        expect(consoleLogs.any((log) => log.contains('[WARNING]')), isTrue);
      });

      test('ERROR: always', () async {
        await CliLogger.init(verbose: false);
        consoleLogs.clear();
        CliLogger.error('테스트');
        expect(consoleLogs.any((log) => log.contains('[ERROR]')), isTrue);

        CliLogger.reset();
        consoleLogs.clear();
        CliLogger.setTestPrintFunction((msg) => consoleLogs.add(msg));
        CliLogger.setTestNowFunction(() => DateTime(2026, 1, 6, 14, 30, 45));

        await CliLogger.init(verbose: true);
        consoleLogs.clear();
        CliLogger.error('테스트');
        expect(consoleLogs.any((log) => log.contains('[ERROR]')), isTrue);
      });
    });
  });
}
