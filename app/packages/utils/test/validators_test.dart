import 'package:flutter_test/flutter_test.dart';
import 'package:utils/utils.dart';

void main() {
  group('Validators', () {
    group('required', () {
      test('null 값은 에러 메시지를 반환해야 함', () {
        final result = Validators.required(null);
        expect(result, isNotNull);
        expect(result, contains('입력해'));
      });

      test('빈 문자열은 에러 메시지를 반환해야 함', () {
        final result = Validators.required('');
        expect(result, isNotNull);
      });

      test('공백만 있는 문자열은 에러 메시지를 반환해야 함', () {
        final result = Validators.required('   ');
        expect(result, isNotNull);
      });

      test('유효한 값은 null을 반환해야 함', () {
        final result = Validators.required('valid input');
        expect(result, isNull);
      });

      test('fieldName이 에러 메시지에 포함되어야 함', () {
        final result = Validators.required(null, fieldName: '이름');
        expect(result, contains('이름'));
      });
    });

    group('email', () {
      test('유효한 이메일은 null을 반환해야 함', () {
        final validEmails = [
          'test@example.com',
          'user.name@domain.co.kr',
          'user+tag@example.org',
          'test123@test.io',
        ];

        for (final email in validEmails) {
          expect(Validators.email(email), isNull, reason: '$email should be valid');
        }
      });

      test('잘못된 이메일은 에러 메시지를 반환해야 함', () {
        final invalidEmails = [
          'notanemail',
          'missing@domain',
          '@nodomain.com',
          'spaces in@email.com',
          'double@@at.com',
        ];

        for (final email in invalidEmails) {
          expect(Validators.email(email), isNotNull, reason: '$email should be invalid');
        }
      });

      test('null이나 빈 문자열은 null을 반환해야 함 (optional field)', () {
        expect(Validators.email(null), isNull);
        expect(Validators.email(''), isNull);
      });
    });

    group('minLength', () {
      test('최소 길이 이상이면 null을 반환해야 함', () {
        final validator = Validators.minLength(5);
        expect(validator('hello'), isNull);
        expect(validator('hello world'), isNull);
      });

      test('최소 길이 미만이면 에러 메시지를 반환해야 함', () {
        final validator = Validators.minLength(5);
        expect(validator('hi'), isNotNull);
        expect(validator('abcd'), isNotNull);
      });

      test('null이나 빈 문자열은 null을 반환해야 함 (optional field)', () {
        final validator = Validators.minLength(5);
        expect(validator(null), isNull);
        expect(validator(''), isNull);
      });

      test('fieldName이 에러 메시지에 포함되어야 함', () {
        final validator = Validators.minLength(5, fieldName: '비밀번호');
        final result = validator('ab');
        expect(result, contains('비밀번호'));
      });
    });

    group('maxLength', () {
      test('최대 길이 이하면 null을 반환해야 함', () {
        final validator = Validators.maxLength(10);
        expect(validator('hello'), isNull);
        expect(validator('1234567890'), isNull);
      });

      test('최대 길이 초과면 에러 메시지를 반환해야 함', () {
        final validator = Validators.maxLength(5);
        expect(validator('hello world'), isNotNull);
        expect(validator('123456'), isNotNull);
      });
    });

    group('lengthBetween', () {
      test('범위 내 길이는 null을 반환해야 함', () {
        final validator = Validators.lengthBetween(3, 10);
        expect(validator('hello'), isNull);
        expect(validator('abc'), isNull);
        expect(validator('1234567890'), isNull);
      });

      test('범위 외 길이는 에러 메시지를 반환해야 함', () {
        final validator = Validators.lengthBetween(3, 10);
        expect(validator('ab'), isNotNull);
        expect(validator('12345678901'), isNotNull);
      });
    });

    group('phone', () {
      test('유효한 전화번호는 null을 반환해야 함', () {
        final validPhones = [
          '010-1234-5678',
          '01012345678',
          '+82-10-1234-5678',
          '(02) 123-4567',
        ];

        for (final phone in validPhones) {
          expect(Validators.phone(phone), isNull, reason: '$phone should be valid');
        }
      });

      test('잘못된 전화번호는 에러 메시지를 반환해야 함', () {
        final invalidPhones = [
          '123',
          'abc-defg-hijk',
          '12-34',
        ];

        for (final phone in invalidPhones) {
          expect(Validators.phone(phone), isNotNull, reason: '$phone should be invalid');
        }
      });
    });

    group('password', () {
      test('모든 요구사항을 충족하면 null을 반환해야 함', () {
        final result = Validators.password('Password123');
        expect(result, isNull);
      });

      test('빈 비밀번호는 에러 메시지를 반환해야 함', () {
        expect(Validators.password(null), isNotNull);
        expect(Validators.password(''), isNotNull);
      });

      test('최소 길이 미만이면 에러 메시지를 반환해야 함', () {
        final result = Validators.password('Pass1');
        expect(result, isNotNull);
        expect(result, contains('8자'));
      });

      test('대문자 없이면 에러 메시지를 반환해야 함', () {
        final result = Validators.password('password123');
        expect(result, isNotNull);
        expect(result, contains('대문자'));
      });

      test('소문자 없이면 에러 메시지를 반환해야 함', () {
        final result = Validators.password('PASSWORD123');
        expect(result, isNotNull);
        expect(result, contains('소문자'));
      });

      test('숫자 없이면 에러 메시지를 반환해야 함', () {
        final result = Validators.password('PasswordABC');
        expect(result, isNotNull);
        expect(result, contains('숫자'));
      });

      test('특수문자 요구 시 없으면 에러 메시지를 반환해야 함', () {
        final result = Validators.password(
          'Password123',
          requireSpecialChar: true,
        );
        expect(result, isNotNull);
        expect(result, contains('특수문자'));
      });

      test('요구사항 비활성화 시 해당 검사를 건너뛰어야 함', () {
        final result = Validators.password(
          'simplepassword',
          minLength: 8,
          requireUppercase: false,
          requireNumber: false,
        );
        expect(result, isNull);
      });
    });

    group('confirmPassword', () {
      test('비밀번호가 일치하면 null을 반환해야 함', () {
        final validator = Validators.confirmPassword('mypassword');
        expect(validator('mypassword'), isNull);
      });

      test('비밀번호가 일치하지 않으면 에러 메시지를 반환해야 함', () {
        final validator = Validators.confirmPassword('mypassword');
        expect(validator('differentpassword'), isNotNull);
        expect(validator('differentpassword'), contains('일치하지'));
      });

      test('빈 확인 비밀번호는 에러 메시지를 반환해야 함', () {
        final validator = Validators.confirmPassword('mypassword');
        expect(validator(null), isNotNull);
        expect(validator(''), isNotNull);
      });
    });

    group('numeric', () {
      test('숫자만 있으면 null을 반환해야 함', () {
        expect(Validators.numeric('12345'), isNull);
        expect(Validators.numeric('0'), isNull);
      });

      test('숫자가 아닌 문자가 있으면 에러 메시지를 반환해야 함', () {
        expect(Validators.numeric('123a45'), isNotNull);
        expect(Validators.numeric('12.34'), isNotNull);
        expect(Validators.numeric('-123'), isNotNull);
      });
    });

    group('numberRange', () {
      test('범위 내 숫자는 null을 반환해야 함', () {
        final validator = Validators.numberRange(1, 100);
        expect(validator('1'), isNull);
        expect(validator('50'), isNull);
        expect(validator('100'), isNull);
      });

      test('범위 외 숫자는 에러 메시지를 반환해야 함', () {
        final validator = Validators.numberRange(1, 100);
        expect(validator('0'), isNotNull);
        expect(validator('101'), isNotNull);
        expect(validator('-5'), isNotNull);
      });

      test('숫자가 아닌 값은 에러 메시지를 반환해야 함', () {
        final validator = Validators.numberRange(1, 100);
        expect(validator('abc'), isNotNull);
      });
    });

    group('url', () {
      test('유효한 URL은 null을 반환해야 함', () {
        final validUrls = [
          'https://example.com',
          'http://test.org/path',
          'https://sub.domain.com/path?query=1',
        ];

        for (final url in validUrls) {
          expect(Validators.url(url), isNull, reason: '$url should be valid');
        }
      });

      test('잘못된 URL은 에러 메시지를 반환해야 함', () {
        final invalidUrls = [
          'not-a-url',
          'ftp://invalid-protocol.com',
          'http:/missing-slash.com',
        ];

        for (final url in invalidUrls) {
          expect(Validators.url(url), isNotNull, reason: '$url should be invalid');
        }
      });
    });

    group('pattern', () {
      test('패턴에 맞으면 null을 반환해야 함', () {
        final validator = Validators.pattern(
          RegExp(r'^[A-Z]{3}-\d{4}$'),
          message: '형식이 맞지 않습니다',
        );
        expect(validator('ABC-1234'), isNull);
      });

      test('패턴에 맞지 않으면 지정된 메시지를 반환해야 함', () {
        final validator = Validators.pattern(
          RegExp(r'^[A-Z]{3}-\d{4}$'),
          message: '형식이 맞지 않습니다',
        );
        expect(validator('invalid'), equals('형식이 맞지 않습니다'));
      });
    });

    group('combine', () {
      test('모든 validator를 통과하면 null을 반환해야 함', () {
        final result = Validators.combine(
          'test@example.com',
          [
            Validators.required,
            Validators.email,
          ],
        );
        expect(result, isNull);
      });

      test('첫 번째로 실패한 validator의 에러를 반환해야 함', () {
        final result = Validators.combine(
          '',
          [
            Validators.required,
            Validators.email,
          ],
        );
        expect(result, isNotNull);
        expect(result, contains('입력해'));
      });

      test('두 번째 validator에서 실패하면 해당 에러를 반환해야 함', () {
        final result = Validators.combine(
          'not-an-email',
          [
            Validators.required,
            Validators.email,
          ],
        );
        expect(result, isNotNull);
        expect(result, contains('이메일'));
      });
    });

    group('when', () {
      test('조건이 true이면 validator를 실행해야 함', () {
        final validator = Validators.when(true, Validators.required);
        expect(validator(null), isNotNull);
      });

      test('조건이 false이면 validator를 실행하지 않아야 함', () {
        final validator = Validators.when(false, Validators.required);
        expect(validator(null), isNull);
      });
    });
  });
}
