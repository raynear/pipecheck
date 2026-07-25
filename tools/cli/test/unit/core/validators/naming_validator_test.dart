import 'package:boilerplate_cli/boilerplate_cli.dart';
import 'package:test/test.dart';

void main() {
  group('NamingConventionValidator', () {
    group('validatePackageName', () {
      test('accepts valid snake_case package name', () {
        final result = NamingConventionValidator.validatePackageName('my_app');
        expect(result.isValid, isTrue);
      });

      test('accepts package name with numbers', () {
        final result = NamingConventionValidator.validatePackageName('my_app2');
        expect(result.isValid, isTrue);
      });

      test('accepts single word package name', () {
        final result = NamingConventionValidator.validatePackageName('myapp');
        expect(result.isValid, isTrue);
      });

      test('rejects empty package name', () {
        final result = NamingConventionValidator.validatePackageName('');
        expect(result.isValid, isFalse);
        expect(result.error, contains('비어있습니다'));
      });

      test('rejects package name starting with number', () {
        final result = NamingConventionValidator.validatePackageName('2myapp');
        expect(result.isValid, isFalse);
        expect(result.error, contains('소문자로 시작'));
      });

      test('rejects package name with uppercase', () {
        final result = NamingConventionValidator.validatePackageName('MyApp');
        expect(result.isValid, isFalse);
        expect(result.suggestion, isNotNull);
      });

      test('rejects package name with hyphens', () {
        final result = NamingConventionValidator.validatePackageName('my-app');
        expect(result.isValid, isFalse);
      });

      test('rejects package name with consecutive underscores', () {
        final result = NamingConventionValidator.validatePackageName('my__app');
        expect(result.isValid, isFalse);
        expect(result.error, contains('연속된 언더스코어'));
      });

      test('rejects package name ending with underscore', () {
        final result = NamingConventionValidator.validatePackageName('my_app_');
        expect(result.isValid, isFalse);
        expect(result.error, contains('끝날 수 없습니다'));
      });

      test('rejects Dart reserved words', () {
        final result = NamingConventionValidator.validatePackageName('class');
        expect(result.isValid, isFalse);
        expect(result.error, contains('예약어'));
      });
    });

    group('validateBundleId', () {
      test('accepts valid bundle ID', () {
        final result =
            NamingConventionValidator.validateBundleId('com.example.myapp');
        expect(result.isValid, isTrue);
      });

      test('accepts two segment bundle ID', () {
        final result =
            NamingConventionValidator.validateBundleId('com.myapp');
        expect(result.isValid, isTrue);
      });

      test('accepts bundle ID with numbers', () {
        final result =
            NamingConventionValidator.validateBundleId('com.example.app2');
        expect(result.isValid, isTrue);
      });

      test('rejects empty bundle ID', () {
        final result = NamingConventionValidator.validateBundleId('');
        expect(result.isValid, isFalse);
        expect(result.error, contains('비어있습니다'));
      });

      test('rejects single segment bundle ID', () {
        final result = NamingConventionValidator.validateBundleId('myapp');
        expect(result.isValid, isFalse);
        expect(result.error, contains('최소 2개'));
      });

      test('rejects bundle ID with empty segment', () {
        final result =
            NamingConventionValidator.validateBundleId('com..myapp');
        expect(result.isValid, isFalse);
        expect(result.error, contains('빈 세그먼트'));
      });

      test('rejects segment starting with number', () {
        final result =
            NamingConventionValidator.validateBundleId('com.2example.myapp');
        expect(result.isValid, isFalse);
      });

      test('rejects segment with uppercase', () {
        final result =
            NamingConventionValidator.validateBundleId('com.Example.myapp');
        expect(result.isValid, isFalse);
      });

      test('rejects Java reserved word segments', () {
        final result =
            NamingConventionValidator.validateBundleId('com.class.myapp');
        expect(result.isValid, isFalse);
        expect(result.error, contains('Java 예약어'));
      });
    });

    group('validateAppName', () {
      test('accepts English app name', () {
        final result = NamingConventionValidator.validateAppName('My App');
        expect(result.isValid, isTrue);
      });

      test('accepts Korean app name', () {
        final result = NamingConventionValidator.validateAppName('마이앱');
        expect(result.isValid, isTrue);
      });

      test('accepts mixed language app name', () {
        final result = NamingConventionValidator.validateAppName('My 앱');
        expect(result.isValid, isTrue);
      });

      test('accepts app name with numbers', () {
        final result = NamingConventionValidator.validateAppName('App 2.0');
        expect(result.isValid, isTrue);
      });

      test('accepts app name with hyphen', () {
        final result = NamingConventionValidator.validateAppName('My-App');
        expect(result.isValid, isTrue);
      });

      test('rejects empty app name', () {
        final result = NamingConventionValidator.validateAppName('');
        expect(result.isValid, isFalse);
        expect(result.error, contains('비어있습니다'));
      });

      test('rejects app name longer than 30 chars', () {
        final result = NamingConventionValidator.validateAppName(
            'This Is A Very Long App Name That Exceeds Limit');
        expect(result.isValid, isFalse);
        expect(result.error, contains('너무 깁니다'));
      });

      test('rejects app name starting with space', () {
        final result = NamingConventionValidator.validateAppName(' My App');
        expect(result.isValid, isFalse);
        expect(result.error, contains('공백으로 시작'));
      });

      test('rejects app name ending with space', () {
        final result = NamingConventionValidator.validateAppName('My App ');
        expect(result.isValid, isFalse);
        expect(result.error, contains('끝날 수 없습니다'));
      });
    });

    group('validateiOSBundleId', () {
      test('accepts valid iOS bundle ID', () {
        final result = NamingConventionValidator.validateiOSBundleId(
            'com.example.myapp');
        expect(result.isValid, isTrue);
      });

      test('provides suggestion for hyphen usage', () {
        final result = NamingConventionValidator.validateiOSBundleId(
            'com.example.my-app');
        // Hyphen is technically valid but has a suggestion
        expect(result.suggestion, isNotNull);
      });
    });

    group('validateAndroidApplicationId', () {
      test('accepts valid Android application ID', () {
        final result = NamingConventionValidator.validateAndroidApplicationId(
            'com.example.myapp');
        expect(result.isValid, isTrue);
      });

      test('accepts application ID with underscore', () {
        final result = NamingConventionValidator.validateAndroidApplicationId(
            'com.example.my_app');
        expect(result.isValid, isTrue);
      });

      test('rejects empty application ID', () {
        final result =
            NamingConventionValidator.validateAndroidApplicationId('');
        expect(result.isValid, isFalse);
      });

      test('rejects single segment', () {
        final result =
            NamingConventionValidator.validateAndroidApplicationId('myapp');
        expect(result.isValid, isFalse);
        expect(result.error, contains('최소 2개'));
      });

      test('rejects Java reserved word segment', () {
        final result = NamingConventionValidator.validateAndroidApplicationId(
            'com.int.myapp');
        expect(result.isValid, isFalse);
        expect(result.error, contains('Java 예약어'));
      });
    });

    group('toCamelCase', () {
      test('converts snake_case to camelCase', () {
        expect(NamingConventionValidator.toCamelCase('my_app_name'),
            equals('myAppName'));
      });

      test('converts PascalCase to camelCase', () {
        expect(NamingConventionValidator.toCamelCase('MyAppName'),
            equals('myAppName'));
      });

      test('converts kebab-case to camelCase', () {
        expect(NamingConventionValidator.toCamelCase('my-app-name'),
            equals('myAppName'));
      });

      test('handles single word', () {
        expect(NamingConventionValidator.toCamelCase('myapp'), equals('myapp'));
      });

      test('handles empty string', () {
        expect(NamingConventionValidator.toCamelCase(''), equals(''));
      });

      test('handles mixed case with underscores', () {
        expect(NamingConventionValidator.toCamelCase('My_App_Name'),
            equals('myAppName'));
      });
    });

    group('toPascalCase', () {
      test('converts snake_case to PascalCase', () {
        expect(NamingConventionValidator.toPascalCase('my_app_name'),
            equals('MyAppName'));
      });

      test('converts camelCase to PascalCase', () {
        expect(NamingConventionValidator.toPascalCase('myAppName'),
            equals('MyAppName'));
      });

      test('converts kebab-case to PascalCase', () {
        expect(NamingConventionValidator.toPascalCase('my-app-name'),
            equals('MyAppName'));
      });

      test('handles single word', () {
        expect(
            NamingConventionValidator.toPascalCase('myapp'), equals('Myapp'));
      });

      test('handles empty string', () {
        expect(NamingConventionValidator.toPascalCase(''), equals(''));
      });
    });

    group('toSnakeCase', () {
      test('converts PascalCase to snake_case', () {
        expect(NamingConventionValidator.toSnakeCase('MyAppName'),
            equals('my_app_name'));
      });

      test('converts camelCase to snake_case', () {
        expect(NamingConventionValidator.toSnakeCase('myAppName'),
            equals('my_app_name'));
      });

      test('converts kebab-case to snake_case', () {
        expect(NamingConventionValidator.toSnakeCase('my-app-name'),
            equals('my_app_name'));
      });

      test('handles already snake_case', () {
        expect(NamingConventionValidator.toSnakeCase('my_app_name'),
            equals('my_app_name'));
      });

      test('handles empty string', () {
        expect(NamingConventionValidator.toSnakeCase(''), equals(''));
      });
    });

    group('toKebabCase', () {
      test('converts PascalCase to kebab-case', () {
        expect(NamingConventionValidator.toKebabCase('MyAppName'),
            equals('my-app-name'));
      });

      test('converts camelCase to kebab-case', () {
        expect(NamingConventionValidator.toKebabCase('myAppName'),
            equals('my-app-name'));
      });

      test('converts snake_case to kebab-case', () {
        expect(NamingConventionValidator.toKebabCase('my_app_name'),
            equals('my-app-name'));
      });

      test('handles already kebab-case', () {
        expect(NamingConventionValidator.toKebabCase('my-app-name'),
            equals('my-app-name'));
      });

      test('handles empty string', () {
        expect(NamingConventionValidator.toKebabCase(''), equals(''));
      });
    });

    group('toConstantCase', () {
      test('converts PascalCase to CONSTANT_CASE', () {
        expect(NamingConventionValidator.toConstantCase('MyAppName'),
            equals('MY_APP_NAME'));
      });

      test('converts camelCase to CONSTANT_CASE', () {
        expect(NamingConventionValidator.toConstantCase('myAppName'),
            equals('MY_APP_NAME'));
      });

      test('converts snake_case to CONSTANT_CASE', () {
        expect(NamingConventionValidator.toConstantCase('my_app_name'),
            equals('MY_APP_NAME'));
      });

      test('handles empty string', () {
        expect(NamingConventionValidator.toConstantCase(''), equals(''));
      });
    });
  });

  group('ValidationResult', () {
    test('toString returns valid for valid result', () {
      const result = ValidationResult(isValid: true);
      expect(result.toString(), equals('ValidationResult(valid)'));
    });

    test('toString returns error info for invalid result', () {
      const result = ValidationResult(
        isValid: false,
        error: 'Test error',
        suggestion: 'Test suggestion',
      );
      expect(result.toString(), contains('invalid'));
      expect(result.toString(), contains('Test error'));
      expect(result.toString(), contains('Test suggestion'));
    });

    test('stores all properties correctly', () {
      const result = ValidationResult(
        isValid: false,
        error: 'Error message',
        suggestion: 'Suggestion text',
      );
      expect(result.isValid, isFalse);
      expect(result.error, equals('Error message'));
      expect(result.suggestion, equals('Suggestion text'));
    });
  });
}
