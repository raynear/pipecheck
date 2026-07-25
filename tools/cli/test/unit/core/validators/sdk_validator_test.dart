import 'package:boilerplate_cli/core/error_handler.dart';
import 'package:boilerplate_cli/core/validators/sdk_validator.dart';
import 'package:test/test.dart';

void main() {
  group('SdkVersion', () {
    group('tryParse', () {
      test('parses valid version string', () {
        final version = SdkVersion.tryParse('3.8.0');

        expect(version, isNotNull);
        expect(version!.major, equals(3));
        expect(version.minor, equals(8));
        expect(version.patch, equals(0));
      });

      test('parses version with prerelease', () {
        final version = SdkVersion.tryParse('3.8.0-dev.1');

        expect(version, isNotNull);
        expect(version!.major, equals(3));
        expect(version.minor, equals(8));
        expect(version.patch, equals(0));
      });

      test('parses version with spaces', () {
        final version = SdkVersion.tryParse(' 3.8.0 ');

        expect(version, isNotNull);
        expect(version!.major, equals(3));
      });

      test('returns null for invalid version', () {
        expect(SdkVersion.tryParse('invalid'), isNull);
        expect(SdkVersion.tryParse('3.8'), isNull);
        expect(SdkVersion.tryParse('a.b.c'), isNull);
        expect(SdkVersion.tryParse(''), isNull);
      });

      test('handles different version numbers', () {
        final v1 = SdkVersion.tryParse('1.0.0');
        final v2 = SdkVersion.tryParse('10.20.30');

        expect(v1!.major, equals(1));
        expect(v2!.major, equals(10));
        expect(v2.minor, equals(20));
        expect(v2.patch, equals(30));
      });
    });

    group('isAtLeast', () {
      test('returns true for same version', () {
        final v1 = SdkVersion.tryParse('3.8.0')!;
        final v2 = SdkVersion.tryParse('3.8.0')!;

        expect(v1.isAtLeast(v2), isTrue);
      });

      test('returns true for higher major version', () {
        final current = SdkVersion.tryParse('4.0.0')!;
        final required = SdkVersion.tryParse('3.8.0')!;

        expect(current.isAtLeast(required), isTrue);
      });

      test('returns true for higher minor version', () {
        final current = SdkVersion.tryParse('3.10.0')!;
        final required = SdkVersion.tryParse('3.8.0')!;

        expect(current.isAtLeast(required), isTrue);
      });

      test('returns true for higher patch version', () {
        final current = SdkVersion.tryParse('3.8.5')!;
        final required = SdkVersion.tryParse('3.8.0')!;

        expect(current.isAtLeast(required), isTrue);
      });

      test('returns false for lower major version', () {
        final current = SdkVersion.tryParse('2.0.0')!;
        final required = SdkVersion.tryParse('3.8.0')!;

        expect(current.isAtLeast(required), isFalse);
      });

      test('returns false for lower minor version', () {
        final current = SdkVersion.tryParse('3.5.0')!;
        final required = SdkVersion.tryParse('3.8.0')!;

        expect(current.isAtLeast(required), isFalse);
      });

      test('returns false for lower patch version', () {
        final current = SdkVersion.tryParse('3.7.9')!;
        final required = SdkVersion.tryParse('3.8.0')!;

        expect(current.isAtLeast(required), isFalse);
      });
    });

    group('toString', () {
      test('returns version string', () {
        final version = SdkVersion.tryParse('3.8.0')!;
        expect(version.toString(), equals('3.8.0'));
      });
    });

    group('equality', () {
      test('equal versions are equal', () {
        final v1 = SdkVersion.tryParse('3.8.0')!;
        final v2 = SdkVersion.tryParse('3.8.0')!;

        expect(v1 == v2, isTrue);
        expect(v1.hashCode, equals(v2.hashCode));
      });

      test('different versions are not equal', () {
        final v1 = SdkVersion.tryParse('3.8.0')!;
        final v2 = SdkVersion.tryParse('3.9.0')!;

        expect(v1 == v2, isFalse);
      });
    });
  });

  group('CommandResult', () {
    test('creates with default values', () {
      const result = CommandResult(exitCode: 0);

      expect(result.exitCode, equals(0));
      expect(result.stdout, equals(''));
      expect(result.stderr, equals(''));
    });

    test('creates with all values', () {
      const result = CommandResult(
        exitCode: 1,
        stdout: 'output',
        stderr: 'error',
      );

      expect(result.exitCode, equals(1));
      expect(result.stdout, equals('output'));
      expect(result.stderr, equals('error'));
    });
  });

  group('SdkValidator', () {
    group('constants', () {
      test('has correct minimum Flutter version', () {
        expect(SdkValidator.minFlutterVersion, equals('3.8.0'));
      });

      test('has correct minimum Dart version', () {
        expect(SdkValidator.minDartVersion, equals('3.0.0'));
      });

      test('minFlutter returns correct SdkVersion', () {
        expect(SdkValidator.minFlutter.major, equals(3));
        expect(SdkValidator.minFlutter.minor, equals(8));
        expect(SdkValidator.minFlutter.patch, equals(0));
      });

      test('minDart returns correct SdkVersion', () {
        expect(SdkValidator.minDart.major, equals(3));
        expect(SdkValidator.minDart.minor, equals(0));
        expect(SdkValidator.minDart.patch, equals(0));
      });
    });

    group('validateFlutterVersion', () {
      test('succeeds with valid Flutter version', () async {
        final validator = SdkValidator(
          processRunner: _mockProcessRunner(
            stdout: 'Flutter 3.16.0 • channel stable • ...',
            exitCode: 0,
          ),
        );

        await expectLater(validator.validateFlutterVersion(), completes);
      });

      test('succeeds with exact minimum version', () async {
        final validator = SdkValidator(
          processRunner: _mockProcessRunner(
            stdout: 'Flutter 3.8.0 • channel stable • ...',
            exitCode: 0,
          ),
        );

        await expectLater(validator.validateFlutterVersion(), completes);
      });

      test('throws CliException when Flutter not found', () async {
        final validator = SdkValidator(
          processRunner: _mockProcessRunner(
            stdout: '',
            exitCode: 1,
          ),
        );

        await expectLater(
          validator.validateFlutterVersion(),
          throwsA(isA<CliException>().having(
            (e) => e.message,
            'message',
            contains('Flutter SDK를 찾을 수 없습니다'),
          )),
        );
      });

      test('throws CliException when version too low', () async {
        final validator = SdkValidator(
          processRunner: _mockProcessRunner(
            stdout: 'Flutter 3.5.0 • channel stable • ...',
            exitCode: 0,
          ),
        );

        await expectLater(
          validator.validateFlutterVersion(),
          throwsA(isA<CliException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('버전이 너무 낮습니다'),
              contains('3.5.0'),
              contains('3.8.0'),
            ),
          )),
        );
      });

      test('throws CliException when version cannot be parsed', () async {
        final validator = SdkValidator(
          processRunner: _mockProcessRunner(
            stdout: 'Some invalid output',
            exitCode: 0,
          ),
        );

        await expectLater(
          validator.validateFlutterVersion(),
          throwsA(isA<CliException>().having(
            (e) => e.message,
            'message',
            contains('버전을 확인할 수 없습니다'),
          )),
        );
      });

      test('error message includes solution', () async {
        final validator = SdkValidator(
          processRunner: _mockProcessRunner(
            stdout: 'Flutter 3.5.0 • channel stable • ...',
            exitCode: 0,
          ),
        );

        try {
          await validator.validateFlutterVersion();
          fail('Expected CliException');
        } on CliException catch (e) {
          expect(e.solution, contains('flutter upgrade'));
        }
      });

      test('error message includes docs URL', () async {
        final validator = SdkValidator(
          processRunner: _mockProcessRunner(
            stdout: 'Flutter 3.5.0 • channel stable • ...',
            exitCode: 0,
          ),
        );

        try {
          await validator.validateFlutterVersion();
          fail('Expected CliException');
        } on CliException catch (e) {
          expect(e.docsUrl, contains('troubleshooting'));
        }
      });
    });

    group('validateDartVersion', () {
      test('succeeds with valid Dart version', () async {
        final validator = SdkValidator(
          processRunner: _mockProcessRunner(
            stdout: 'Dart SDK version: 3.2.0 (stable) ...',
            exitCode: 0,
          ),
        );

        await expectLater(validator.validateDartVersion(), completes);
      });

      test('succeeds with exact minimum version', () async {
        final validator = SdkValidator(
          processRunner: _mockProcessRunner(
            stdout: 'Dart SDK version: 3.0.0 (stable) ...',
            exitCode: 0,
          ),
        );

        await expectLater(validator.validateDartVersion(), completes);
      });

      test('throws CliException when Dart not found', () async {
        final validator = SdkValidator(
          processRunner: _mockProcessRunner(
            stdout: '',
            exitCode: 1,
          ),
        );

        await expectLater(
          validator.validateDartVersion(),
          throwsA(isA<CliException>().having(
            (e) => e.message,
            'message',
            contains('Dart SDK를 찾을 수 없습니다'),
          )),
        );
      });

      test('throws CliException when version too low', () async {
        final validator = SdkValidator(
          processRunner: _mockProcessRunner(
            stdout: 'Dart SDK version: 2.19.0 (stable) ...',
            exitCode: 0,
          ),
        );

        await expectLater(
          validator.validateDartVersion(),
          throwsA(isA<CliException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('버전이 너무 낮습니다'),
              contains('2.19.0'),
              contains('3.0.0'),
            ),
          )),
        );
      });

      test('parses Dart version from stderr', () async {
        final validator = SdkValidator(
          processRunner: _mockProcessRunner(
            stdout: '',
            stderr: 'Dart SDK version: 3.2.0 (stable) ...',
            exitCode: 0,
          ),
        );

        await expectLater(validator.validateDartVersion(), completes);
      });

      test('handles alternative Dart version format', () async {
        final validator = SdkValidator(
          processRunner: _mockProcessRunner(
            stdout: 'Dart 3.2.0',
            exitCode: 0,
          ),
        );

        await expectLater(validator.validateDartVersion(), completes);
      });
    });

    group('validateAll', () {
      test('succeeds when both SDKs are valid', () async {
        var callCount = 0;
        final validator = SdkValidator(
          processRunner: (executable, args) async {
            callCount++;
            if (executable == 'flutter') {
              return const CommandResult(
                exitCode: 0,
                stdout: 'Flutter 3.16.0 • channel stable',
              );
            } else {
              return const CommandResult(
                exitCode: 0,
                stdout: 'Dart SDK version: 3.2.0 (stable)',
              );
            }
          },
        );

        await expectLater(validator.validateAll(), completes);
        expect(callCount, equals(2));
      });

      test('throws when Flutter validation fails', () async {
        final validator = SdkValidator(
          processRunner: (executable, args) async {
            if (executable == 'flutter') {
              return const CommandResult(
                exitCode: 0,
                stdout: 'Flutter 3.5.0 • channel stable',
              );
            } else {
              return const CommandResult(
                exitCode: 0,
                stdout: 'Dart SDK version: 3.2.0 (stable)',
              );
            }
          },
        );

        await expectLater(
          validator.validateAll(),
          throwsA(isA<CliException>().having(
            (e) => e.message,
            'message',
            contains('Flutter'),
          )),
        );
      });

      test('throws when Dart validation fails', () async {
        final validator = SdkValidator(
          processRunner: (executable, args) async {
            if (executable == 'flutter') {
              return const CommandResult(
                exitCode: 0,
                stdout: 'Flutter 3.16.0 • channel stable',
              );
            } else {
              return const CommandResult(
                exitCode: 0,
                stdout: 'Dart SDK version: 2.19.0 (stable)',
              );
            }
          },
        );

        await expectLater(
          validator.validateAll(),
          throwsA(isA<CliException>().having(
            (e) => e.message,
            'message',
            contains('Dart'),
          )),
        );
      });
    });
  });
}

/// 테스트용 ProcessRunner 함수를 생성합니다.
ProcessRunner _mockProcessRunner({
  String stdout = '',
  String stderr = '',
  int exitCode = 0,
}) {
  return (executable, args) async {
    return CommandResult(
      exitCode: exitCode,
      stdout: stdout,
      stderr: stderr,
    );
  };
}
