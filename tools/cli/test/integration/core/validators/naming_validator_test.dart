import 'dart:io';

import 'package:test/test.dart';

/// 네이밍 컨벤션 검증 통합 테스트.
///
/// 실제 파일 시스템을 사용하여 NamingConventionValidator 동작을 테스트합니다.
void main() {
  final cliPath = Directory.current.path;

  group('Naming Validator Integration', () {
    group('NamingConventionValidator class', () {
      test('NamingConventionValidator class is exported', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  final result = NamingConventionValidator.validatePackageName('my_app');
  print('VALIDATOR_EXISTS');
  print('RESULT_VALID: \${result.isValid}');
}
''';
        final tempFile = File('$cliPath/test_naming_export_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('VALIDATOR_EXISTS'));
          expect(result.stdout.toString(), contains('RESULT_VALID: true'));
        } finally {
          tempFile.deleteSync();
        }
      });

      test('ValidationResult class is exported', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  const result = ValidationResult(
    isValid: true,
    error: null,
    suggestion: null,
  );
  print('RESULT_CREATED');
  print('IS_VALID: \${result.isValid}');
}
''';
        final tempFile = File('$cliPath/test_validation_result_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('RESULT_CREATED'));
          expect(result.stdout.toString(), contains('IS_VALID: true'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('package name validation', () {
      test('validates package names correctly', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  // Valid names
  final valid1 = NamingConventionValidator.validatePackageName('my_app');
  final valid2 = NamingConventionValidator.validatePackageName('flutter_boilerplate');

  // Invalid names
  final invalid1 = NamingConventionValidator.validatePackageName('MyApp');
  final invalid2 = NamingConventionValidator.validatePackageName('my-app');
  final invalid3 = NamingConventionValidator.validatePackageName('');

  print('VALID_1: \${valid1.isValid}');
  print('VALID_2: \${valid2.isValid}');
  print('INVALID_1: \${invalid1.isValid}');
  print('INVALID_2: \${invalid2.isValid}');
  print('INVALID_3: \${invalid3.isValid}');
  print('HAS_SUGGESTION: \${invalid1.suggestion != null}');
}
''';
        final tempFile = File('$cliPath/test_package_validation_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('VALID_1: true'));
          expect(result.stdout.toString(), contains('VALID_2: true'));
          expect(result.stdout.toString(), contains('INVALID_1: false'));
          expect(result.stdout.toString(), contains('INVALID_2: false'));
          expect(result.stdout.toString(), contains('INVALID_3: false'));
          expect(result.stdout.toString(), contains('HAS_SUGGESTION: true'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('bundle ID validation', () {
      test('validates bundle IDs correctly', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  // Valid bundle IDs
  final valid1 = NamingConventionValidator.validateBundleId('com.example.myapp');
  final valid2 = NamingConventionValidator.validateBundleId('io.flutter.app');

  // Invalid bundle IDs
  final invalid1 = NamingConventionValidator.validateBundleId('myapp');
  final invalid2 = NamingConventionValidator.validateBundleId('com.Example.app');
  final invalid3 = NamingConventionValidator.validateBundleId('');

  print('VALID_1: \${valid1.isValid}');
  print('VALID_2: \${valid2.isValid}');
  print('INVALID_1: \${invalid1.isValid}');
  print('INVALID_2: \${invalid2.isValid}');
  print('INVALID_3: \${invalid3.isValid}');
}
''';
        final tempFile = File('$cliPath/test_bundle_validation_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('VALID_1: true'));
          expect(result.stdout.toString(), contains('VALID_2: true'));
          expect(result.stdout.toString(), contains('INVALID_1: false'));
          expect(result.stdout.toString(), contains('INVALID_2: false'));
          expect(result.stdout.toString(), contains('INVALID_3: false'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('app name validation', () {
      test('validates app names correctly', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  // Valid app names
  final valid1 = NamingConventionValidator.validateAppName('My App');
  final valid2 = NamingConventionValidator.validateAppName('마이앱');
  final valid3 = NamingConventionValidator.validateAppName('App 2.0');

  // Invalid app names
  final invalid1 = NamingConventionValidator.validateAppName('');
  final invalid2 = NamingConventionValidator.validateAppName(' Leading Space');

  print('VALID_1: \${valid1.isValid}');
  print('VALID_2: \${valid2.isValid}');
  print('VALID_3: \${valid3.isValid}');
  print('INVALID_1: \${invalid1.isValid}');
  print('INVALID_2: \${invalid2.isValid}');
}
''';
        final tempFile = File('$cliPath/test_appname_validation_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('VALID_1: true'));
          expect(result.stdout.toString(), contains('VALID_2: true'));
          expect(result.stdout.toString(), contains('VALID_3: true'));
          expect(result.stdout.toString(), contains('INVALID_1: false'));
          expect(result.stdout.toString(), contains('INVALID_2: false'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('case conversion utilities', () {
      test('case conversion works correctly', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  final input = 'my_app_name';

  print('TO_CAMEL: \${NamingConventionValidator.toCamelCase(input)}');
  print('TO_PASCAL: \${NamingConventionValidator.toPascalCase(input)}');
  print('TO_SNAKE: \${NamingConventionValidator.toSnakeCase("MyAppName")}');
  print('TO_KEBAB: \${NamingConventionValidator.toKebabCase("MyAppName")}');
  print('TO_CONSTANT: \${NamingConventionValidator.toConstantCase(input)}');
}
''';
        final tempFile = File('$cliPath/test_case_conversion_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('TO_CAMEL: myAppName'));
          expect(result.stdout.toString(), contains('TO_PASCAL: MyAppName'));
          expect(result.stdout.toString(), contains('TO_SNAKE: my_app_name'));
          expect(result.stdout.toString(), contains('TO_KEBAB: my-app-name'));
          expect(
              result.stdout.toString(), contains('TO_CONSTANT: MY_APP_NAME'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('platform-specific validation', () {
      test('iOS bundle ID validation works', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  final valid = NamingConventionValidator.validateiOSBundleId('com.example.myapp');
  final withHyphen = NamingConventionValidator.validateiOSBundleId('com.example.my-app');

  print('VALID: \${valid.isValid}');
  print('WITH_HYPHEN_VALID: \${withHyphen.isValid}');
  print('HAS_SUGGESTION: \${withHyphen.suggestion != null}');
}
''';
        final tempFile = File('$cliPath/test_ios_validation_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('VALID: true'));
          expect(result.stdout.toString(), contains('WITH_HYPHEN_VALID: true'));
          expect(result.stdout.toString(), contains('HAS_SUGGESTION: true'));
        } finally {
          tempFile.deleteSync();
        }
      });

      test('Android application ID validation works', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  final valid = NamingConventionValidator.validateAndroidApplicationId('com.example.myapp');
  final withUnderscore = NamingConventionValidator.validateAndroidApplicationId('com.example.my_app');
  final invalid = NamingConventionValidator.validateAndroidApplicationId('com.int.myapp');

  print('VALID: \${valid.isValid}');
  print('WITH_UNDERSCORE: \${withUnderscore.isValid}');
  print('INVALID_RESERVED: \${invalid.isValid}');
}
''';
        final tempFile = File('$cliPath/test_android_validation_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('VALID: true'));
          expect(result.stdout.toString(), contains('WITH_UNDERSCORE: true'));
          expect(result.stdout.toString(), contains('INVALID_RESERVED: false'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });
  });
}
