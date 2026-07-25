import 'package:boilerplate_cli/core/error_handler.dart';
import 'package:test/test.dart';

void main() {
  group('CliException', () {
    group('constructor', () {
      test('creates exception with message only', () {
        final exception = CliException('테스트 에러');

        expect(exception.message, equals('테스트 에러'));
        expect(exception.solution, isNull);
        expect(exception.docsUrl, isNull);
        expect(exception.stackTrace, isNull);
      });

      test('creates exception with all properties', () {
        final stackTrace = StackTrace.current;
        final exception = CliException(
          '테스트 에러',
          solution: '해결 방법',
          docsUrl: 'docs/test.md',
          stackTrace: stackTrace,
        );

        expect(exception.message, equals('테스트 에러'));
        expect(exception.solution, equals('해결 방법'));
        expect(exception.docsUrl, equals('docs/test.md'));
        expect(exception.stackTrace, equals(stackTrace));
      });

      test('creates exception with solution only', () {
        final exception = CliException(
          '테스트 에러',
          solution: '해결 방법',
        );

        expect(exception.message, equals('테스트 에러'));
        expect(exception.solution, equals('해결 방법'));
        expect(exception.docsUrl, isNull);
      });

      test('creates exception with docsUrl only', () {
        final exception = CliException(
          '테스트 에러',
          docsUrl: 'docs/test.md',
        );

        expect(exception.message, equals('테스트 에러'));
        expect(exception.solution, isNull);
        expect(exception.docsUrl, equals('docs/test.md'));
      });
    });

    group('formatError', () {
      test('formats error with message only', () {
        final exception = CliException('테스트 에러');
        final formatted = exception.formatError();

        expect(formatted, contains('[ERROR] 테스트 에러'));
        expect(formatted, isNot(contains('💡 해결 방법:')));
        expect(formatted, isNot(contains('📚 관련 문서:')));
      });

      test('formats error with solution', () {
        final exception = CliException(
          '테스트 에러',
          solution: '첫 번째 단계\n두 번째 단계',
        );
        final formatted = exception.formatError();

        expect(formatted, contains('[ERROR] 테스트 에러'));
        expect(formatted, contains('💡 해결 방법:'));
        expect(formatted, contains('1. 첫 번째 단계'));
        expect(formatted, contains('2. 두 번째 단계'));
      });

      test('formats error with single solution step', () {
        final exception = CliException(
          '테스트 에러',
          solution: '단일 해결 방법',
        );
        final formatted = exception.formatError();

        expect(formatted, contains('💡 해결 방법:'));
        expect(formatted, contains('1. 단일 해결 방법'));
      });

      test('formats error with docsUrl', () {
        final exception = CliException(
          '테스트 에러',
          docsUrl: 'docs/troubleshooting.md',
        );
        final formatted = exception.formatError();

        expect(formatted, contains('[ERROR] 테스트 에러'));
        expect(formatted, contains('📚 관련 문서: docs/troubleshooting.md'));
      });

      test('formats error with all properties', () {
        final exception = CliException(
          '테스트 에러',
          solution: '해결 단계 1\n해결 단계 2',
          docsUrl: 'docs/test.md',
        );
        final formatted = exception.formatError();

        expect(formatted, contains('[ERROR] 테스트 에러'));
        expect(formatted, contains('💡 해결 방법:'));
        expect(formatted, contains('1. 해결 단계 1'));
        expect(formatted, contains('2. 해결 단계 2'));
        expect(formatted, contains('📚 관련 문서: docs/test.md'));
      });

      test('formats error with stack trace when requested', () {
        final stackTrace = StackTrace.current;
        final exception = CliException(
          '테스트 에러',
          stackTrace: stackTrace,
        );
        final formatted = exception.formatError(includeStackTrace: true);

        expect(formatted, contains('[ERROR] 테스트 에러'));
        expect(formatted, contains('📋 스택 트레이스:'));
      });

      test('does not include stack trace by default', () {
        final stackTrace = StackTrace.current;
        final exception = CliException(
          '테스트 에러',
          stackTrace: stackTrace,
        );
        final formatted = exception.formatError();

        expect(formatted, isNot(contains('📋 스택 트레이스:')));
      });

      test('handles empty solution gracefully', () {
        final exception = CliException(
          '테스트 에러',
          solution: '',
        );
        final formatted = exception.formatError();

        expect(formatted, contains('[ERROR] 테스트 에러'));
        expect(formatted, isNot(contains('💡 해결 방법:')));
      });

      test('handles empty docsUrl gracefully', () {
        final exception = CliException(
          '테스트 에러',
          docsUrl: '',
        );
        final formatted = exception.formatError();

        expect(formatted, contains('[ERROR] 테스트 에러'));
        expect(formatted, isNot(contains('📚 관련 문서:')));
      });

      test('trims solution steps', () {
        final exception = CliException(
          '테스트 에러',
          solution: '  단계 1  \n  단계 2  ',
        );
        final formatted = exception.formatError();

        expect(formatted, contains('1. 단계 1'));
        expect(formatted, contains('2. 단계 2'));
      });

      test('skips empty solution lines', () {
        final exception = CliException(
          '테스트 에러',
          solution: '단계 1\n\n단계 2',
        );
        final formatted = exception.formatError();

        expect(formatted, contains('1. 단계 1'));
        // Empty line should be skipped, but numbering continues
        expect(formatted, contains('단계 2'));
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final exception = CliException('테스트 에러');
        expect(exception.toString(), equals('CliException: 테스트 에러'));
      });
    });
  });

  group('wrapException', () {
    test('returns same exception if already CliException', () {
      final original = CliException('원본 에러');
      final wrapped = wrapException(original);

      expect(wrapped, same(original));
    });

    test('wraps generic exception', () {
      final original = Exception('일반 예외');
      final wrapped = wrapException(original);

      expect(wrapped, isA<CliException>());
      expect(wrapped.message, contains('예상치 못한 오류'));
      expect(wrapped.message, contains('일반 예외'));
      expect(wrapped.solution, isNotNull);
    });

    test('wraps string error', () {
      final wrapped = wrapException('문자열 에러');

      expect(wrapped, isA<CliException>());
      expect(wrapped.message, contains('예상치 못한 오류'));
      expect(wrapped.message, contains('문자열 에러'));
    });

    test('preserves stack trace', () {
      final stackTrace = StackTrace.current;
      final wrapped = wrapException(Exception('테스트'), stackTrace);

      expect(wrapped.stackTrace, equals(stackTrace));
    });

    test('provides default solution', () {
      final wrapped = wrapException(Exception('테스트'));

      expect(wrapped.solution, contains('문제가 지속되면'));
      expect(wrapped.solution, contains('로그 파일'));
    });
  });
}
