import 'dart:io';

import 'package:test/test.dart';

/// SDK 버전 검증 시스템 통합 테스트.
///
/// 실제 Flutter/Dart SDK를 사용하여 검증 동작을 테스트합니다.
void main() {
  final cliPath = Directory.current.path;

  group('SDK Validation Integration', () {
    group('SdkVersion parsing', () {
      test('parses real Flutter version output', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  // Flutter --version 출력 형식 파싱 테스트
  const flutterOutput = 'Flutter 3.16.0 • channel stable • https://github.com/flutter/flutter.git';

  final regex = RegExp(r'Flutter\\s+(\\d+\\.\\d+\\.\\d+)');
  final match = regex.firstMatch(flutterOutput);

  if (match != null) {
    final version = SdkVersion.tryParse(match.group(1)!);
    if (version != null && version.major == 3 && version.minor == 16 && version.patch == 0) {
      print('FLUTTER_PARSE_OK');
    }
  }
}
''';
        final tempFile = File('$cliPath/test_flutter_parse_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('FLUTTER_PARSE_OK'));
        } finally {
          tempFile.deleteSync();
        }
      });

      test('parses real Dart version output', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  // Dart --version 출력 형식 파싱 테스트
  const dartOutput = 'Dart SDK version: 3.2.0 (stable) (Mon Oct 16 17:51:49 2023 +0000) on "macos_arm64"';

  final regex = RegExp(r'Dart(?:\\s+SDK\\s+version:?)?\\s+(\\d+\\.\\d+\\.\\d+)');
  final match = regex.firstMatch(dartOutput);

  if (match != null) {
    final version = SdkVersion.tryParse(match.group(1)!);
    if (version != null && version.major == 3 && version.minor == 2 && version.patch == 0) {
      print('DART_PARSE_OK');
    }
  }
}
''';
        final tempFile = File('$cliPath/test_dart_parse_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('DART_PARSE_OK'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('real SDK validation', () {
      test('validates actual Flutter SDK', () async {
        // 실제 Flutter SDK 버전 확인
        final flutterResult = await Process.run('flutter', ['--version']);

        if (flutterResult.exitCode != 0) {
          // Flutter가 설치되어 있지 않으면 테스트 스킵
          markTestSkipped('Flutter SDK not installed');
          return;
        }

        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  final validator = SdkValidator();

  try {
    await validator.validateFlutterVersion();
    print('FLUTTER_VALID');
  } on CliException catch (e) {
    print('FLUTTER_INVALID: \${e.message}');
  }
}
''';
        final tempFile = File('$cliPath/test_flutter_valid_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          // Flutter 버전이 충분히 높으면 VALID, 낮으면 INVALID
          expect(
            result.stdout.toString().contains('FLUTTER_VALID') ||
                result.stdout.toString().contains('FLUTTER_INVALID'),
            isTrue,
          );
        } finally {
          tempFile.deleteSync();
        }
      });

      test('validates actual Dart SDK', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  final validator = SdkValidator();

  try {
    await validator.validateDartVersion();
    print('DART_VALID');
  } on CliException catch (e) {
    print('DART_INVALID: \${e.message}');
  }
}
''';
        final tempFile = File('$cliPath/test_dart_valid_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          // Dart 버전이 충분히 높으면 VALID, 낮으면 INVALID
          expect(
            result.stdout.toString().contains('DART_VALID') ||
                result.stdout.toString().contains('DART_INVALID'),
            isTrue,
          );
        } finally {
          tempFile.deleteSync();
        }
      });

      test('validates all SDKs', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  final validator = SdkValidator();

  try {
    await validator.validateAll();
    print('ALL_VALID');
  } on CliException catch (e) {
    print('VALIDATION_FAILED: \${e.message}');
  }
}
''';
        final tempFile = File('$cliPath/test_all_valid_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(
            result.stdout.toString().contains('ALL_VALID') ||
                result.stdout.toString().contains('VALIDATION_FAILED'),
            isTrue,
          );
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('version comparison', () {
      test('SdkVersion compares correctly', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  final v380 = SdkVersion.tryParse('3.8.0')!;
  final v3160 = SdkVersion.tryParse('3.16.0')!;
  final v300 = SdkVersion.tryParse('3.0.0')!;

  var checks = 0;

  // 3.16.0 >= 3.8.0
  if (v3160.isAtLeast(v380)) checks++;

  // 3.8.0 >= 3.8.0
  if (v380.isAtLeast(v380)) checks++;

  // 3.0.0 < 3.8.0
  if (!v300.isAtLeast(v380)) checks++;

  // 3.8.0 >= 3.0.0
  if (v380.isAtLeast(v300)) checks++;

  print('VERSION_CHECKS: \$checks/4');
}
''';
        final tempFile = File('$cliPath/test_version_compare_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('VERSION_CHECKS: 4/4'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('minimum version constants', () {
      test('exports correct minimum versions', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  var checks = 0;

  // Flutter 최소 버전 확인
  if (SdkValidator.minFlutterVersion == '3.8.0') checks++;
  if (SdkValidator.minFlutter.major == 3) checks++;
  if (SdkValidator.minFlutter.minor == 8) checks++;
  if (SdkValidator.minFlutter.patch == 0) checks++;

  // Dart 최소 버전 확인
  if (SdkValidator.minDartVersion == '3.0.0') checks++;
  if (SdkValidator.minDart.major == 3) checks++;
  if (SdkValidator.minDart.minor == 0) checks++;
  if (SdkValidator.minDart.patch == 0) checks++;

  print('CONSTANT_CHECKS: \$checks/8');
}
''';
        final tempFile = File('$cliPath/test_constants_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('CONSTANT_CHECKS: 8/8'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('error handling', () {
      test('CliException contains solution', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  // 버전이 낮은 경우를 시뮬레이션
  final validator = SdkValidator(
    processRunner: (executable, args) async {
      if (executable == 'flutter') {
        return const CommandResult(
          exitCode: 0,
          stdout: 'Flutter 3.5.0 • channel stable',
        );
      }
      return const CommandResult(exitCode: 0, stdout: '');
    },
  );

  try {
    await validator.validateFlutterVersion();
    print('NO_ERROR');
  } on CliException catch (e) {
    if (e.solution != null && e.solution!.contains('flutter upgrade')) {
      print('SOLUTION_OK');
    }
    if (e.docsUrl != null && e.docsUrl!.contains('troubleshooting')) {
      print('DOCS_URL_OK');
    }
  }
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
          expect(result.stdout.toString(), contains('SOLUTION_OK'));
          expect(result.stdout.toString(), contains('DOCS_URL_OK'));
        } finally {
          tempFile.deleteSync();
        }
      });

      test('throws when SDK not found', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  final validator = SdkValidator(
    processRunner: (executable, args) async {
      return const CommandResult(exitCode: 1, stdout: '');
    },
  );

  try {
    await validator.validateFlutterVersion();
    print('NO_ERROR');
  } on CliException catch (e) {
    if (e.message.contains('찾을 수 없습니다')) {
      print('NOT_FOUND_ERROR_OK');
    }
  }
}
''';
        final tempFile = File('$cliPath/test_not_found_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('NOT_FOUND_ERROR_OK'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('CommandResult', () {
      test('provides correct interface for mocking', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  const result = CommandResult(
    exitCode: 0,
    stdout: 'test output',
    stderr: 'test error',
  );

  var checks = 0;
  if (result.exitCode == 0) checks++;
  if (result.stdout == 'test output') checks++;
  if (result.stderr == 'test error') checks++;

  print('COMMAND_RESULT_CHECKS: \$checks/3');
}
''';
        final tempFile = File('$cliPath/test_command_result_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('COMMAND_RESULT_CHECKS: 3/3'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });
  });
}
