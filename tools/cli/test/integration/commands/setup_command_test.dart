import 'dart:io';

import 'package:test/test.dart';

/// SetupCommand 통합 테스트.
///
/// 실제 프로세스를 실행하여 CLI 동작을 검증합니다.
void main() {
  final cliPath = Directory.current.path;
  final setupScript = '$cliPath/bin/setup.dart';

  group('SetupCommand Integration', () {
    group('--check-env flag (SDK validation only)', () {
      test('validates SDK successfully with --check-env', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--check-env'],
          workingDirectory: cliPath,
        );

        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('환경 검증이 완료되었습니다'));
      });

      test('shows step progress during SDK validation', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--check-env'],
          workingDirectory: cliPath,
        );

        expect(result.stdout.toString(), contains('SDK 버전 검증'));
      });
    });

    group('basic execution (requires app directory)', () {
      test('fails gracefully when app directory does not exist', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript],
          workingDirectory: cliPath,
        );

        // 앱 디렉토리가 없으면 실패해야 함
        expect(result.exitCode, equals(1));
        expect(result.stdout.toString(), contains('app 디렉토리를 찾을 수 없습니다'));
      });
    });

    group('--force flag', () {
      test('accepts --force flag with --check-env', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--force', '--check-env'],
          workingDirectory: cliPath,
        );

        expect(result.exitCode, equals(0));
      });

      test('accepts -f short flag with --check-env', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '-f', '--check-env'],
          workingDirectory: cliPath,
        );

        expect(result.exitCode, equals(0));
      });
    });

    group('--verbose flag', () {
      test('accepts --verbose flag with --check-env', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--verbose', '--check-env'],
          workingDirectory: cliPath,
        );

        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('Setup 명령어를 시작합니다'));
      });

      test('accepts -v short flag with --check-env', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '-v', '--check-env'],
          workingDirectory: cliPath,
        );

        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('Verbose 모드: 활성화'));
      });

      test('shows force status in verbose mode', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '-v', '--check-env'],
          workingDirectory: cliPath,
        );

        expect(result.stdout.toString(), contains('Force 모드: 비활성화'));
      });
    });

    group('multiple flags', () {
      test('accepts --force and --verbose together with --check-env', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--force', '--verbose', '--check-env'],
          workingDirectory: cliPath,
        );

        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('Force 모드: 활성화'));
        expect(result.stdout.toString(), contains('Verbose 모드: 활성화'));
      });

      test('accepts -f and -v short flags together with --check-env', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '-f', '-v', '--check-env'],
          workingDirectory: cliPath,
        );

        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('Force 모드: 활성화'));
      });

      test('accepts combined short flags -fv with --check-env', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '-fv', '--check-env'],
          workingDirectory: cliPath,
        );

        expect(result.exitCode, equals(0));
      });

      test('flag order does not matter', () async {
        final result1 = await Process.run(
          'dart',
          ['run', setupScript, '--verbose', '--force', '--check-env'],
          workingDirectory: cliPath,
        );

        final result2 = await Process.run(
          'dart',
          ['run', setupScript, '--force', '--verbose', '--check-env'],
          workingDirectory: cliPath,
        );

        expect(result1.exitCode, equals(result2.exitCode));
      });
    });

    group('--skip-codegen flag', () {
      test('accepts --skip-codegen flag', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--skip-codegen', '--check-env'],
          workingDirectory: cliPath,
        );

        // --check-env는 --skip-codegen과 무관하게 동작
        expect(result.exitCode, equals(0));
      });
    });

    group('--help flag', () {
      test('shows help with --help', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--help'],
          workingDirectory: cliPath,
        );

        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('프로젝트 초기 설정을 수행합니다.'));
        expect(result.stdout.toString(), contains('Usage:'));
        expect(result.stdout.toString(), contains('Options:'));
      });

      test('shows help with -h', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '-h'],
          workingDirectory: cliPath,
        );

        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('--force'));
        expect(result.stdout.toString(), contains('--verbose'));
        expect(result.stdout.toString(), contains('--check-env'));
        expect(result.stdout.toString(), contains('--skip-codegen'));
      });
    });

    group('error handling', () {
      test('returns error for invalid option', () async {
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--invalid-option'],
          workingDirectory: cliPath,
        );

        expect(result.exitCode, equals(1));
        expect(result.stdout.toString(), contains('[ERROR]'));
      });
    });
  });
}
