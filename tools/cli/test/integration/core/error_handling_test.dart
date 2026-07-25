import 'dart:io';

import 'package:test/test.dart';

/// 에러 처리 통합 테스트.
///
/// Command 클래스에서 에러가 올바르게 처리되는지 검증합니다.
void main() {
  final cliPath = Directory.current.path;
  final setupScript = '$cliPath/bin/setup.dart';

  group('Error Handling Integration', () {
    group('invalid arguments', () {
      test('returns exit code 1 for unknown option', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--unknown-option'],
          workingDirectory: cliPath,
        );

        expect(result.exitCode, equals(1));
      });

      test('shows error message for unknown option', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--unknown-option'],
          workingDirectory: cliPath,
        );

        final output = result.stdout.toString();
        expect(output, contains('[ERROR]'));
        expect(output, contains('잘못된 명령어 인자'));
      });

      test('shows solution for invalid argument error', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--invalid'],
          workingDirectory: cliPath,
        );

        final output = result.stdout.toString();
        expect(output, contains('💡 해결 방법:'));
        expect(output, contains('--help'));
      });

      test('shows usage after invalid argument error', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--invalid'],
          workingDirectory: cliPath,
        );

        final output = result.stdout.toString();
        expect(output, contains('Usage:'));
        expect(output, contains('Options:'));
      });
    });

    group('check-env command', () {
      test('succeeds when Flutter is installed', () async {
        // Flutter가 설치되어 있다고 가정
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--check-env'],
          workingDirectory: cliPath,
        );

        // Flutter가 설치되어 있으면 성공, 없으면 실패
        // 이 테스트는 환경에 따라 결과가 달라질 수 있음
        if (result.exitCode == 0) {
          expect(result.stdout.toString(), contains('환경 검증이 완료되었습니다'));
        } else {
          // Flutter가 없는 경우 CliException 형식의 에러 메시지 확인
          final output = result.stdout.toString();
          expect(output, contains('[ERROR]'));
          expect(output, contains('💡 해결 방법:'));
        }
      });

      test('shows verbose output with -v flag', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--check-env', '-v'],
          workingDirectory: cliPath,
        );

        final output = result.stdout.toString();
        // verbose 모드에서는 Setup 명령어 시작 메시지가 출력됨
        expect(output, contains('Setup 명령어를 시작합니다'));
      });
    });

    group('error message format', () {
      test('error messages are in Korean', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--unknown'],
          workingDirectory: cliPath,
        );

        final output = result.stdout.toString();
        // 한글 메시지 확인
        expect(output, contains('잘못된'));
      });

      test('error output includes emoji markers', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--unknown'],
          workingDirectory: cliPath,
        );

        final output = result.stdout.toString();
        expect(output, contains('💡'));
      });
    });

    group('exit codes', () {
      test('returns 0 for successful execution', () async {
        // --check-env 플래그 사용 (app 디렉토리 없이도 성공)
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--check-env'],
          workingDirectory: cliPath,
        );

        expect(result.exitCode, equals(0));
      });

      test('returns 0 for --help', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--help'],
          workingDirectory: cliPath,
        );

        expect(result.exitCode, equals(0));
      });

      test('returns 1 for error', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--invalid-flag'],
          workingDirectory: cliPath,
        );

        expect(result.exitCode, equals(1));
      });
    });
  });
}
