import 'package:pipecheck/features/home/models/home_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('HomeModel', () {
    group('factory constructor', () {
      test('기본값으로 생성되어야 함', () {
        // Arrange & Act
        const model = HomeModel(title: 'Test Title');

        // Assert
        expect(model.title, equals('Test Title'));
        expect(model.isLoading, isFalse);
        expect(model.errorMessage, isNull);
      });

      test('모든 필드를 지정하여 생성할 수 있어야 함', () {
        // Arrange & Act
        const model = HomeModel(
          title: 'Custom Title',
          isLoading: true,
          errorMessage: 'Error occurred',
        );

        // Assert
        expect(model.title, equals('Custom Title'));
        expect(model.isLoading, isTrue);
        expect(model.errorMessage, equals('Error occurred'));
      });
    });

    group('copyWith', () {
      test('title만 변경할 수 있어야 함', () {
        // Arrange
        const original = HomeModel(
          title: 'Original',
          isLoading: true,
          errorMessage: 'Error',
        );

        // Act + Assert
        expectCopyWith<HomeModel>(
          original: original,
          copyAction: (m) => m.copyWith(title: 'New Title'),
          verifyChange: (m) => expect(m.title, equals('New Title')),
          verifyUnchanged: (m) {
            expect(m.isLoading, isTrue);
            expect(m.errorMessage, equals('Error'));
          },
        );
      });

      test('isLoading만 변경할 수 있어야 함', () {
        // Arrange
        const original = HomeModel(
          title: 'Title',
          isLoading: false,
        );

        // Act
        final copied = original.copyWith(isLoading: true);

        // Assert
        expect(copied.title, equals('Title'));
        expect(copied.isLoading, isTrue);
        expect(copied.errorMessage, isNull);
      });

      test('errorMessage를 null로 설정할 수 있어야 함', () {
        // Arrange
        const original = HomeModel(
          title: 'Title',
          errorMessage: 'Some error',
        );

        // Act
        final copied = original.copyWith(errorMessage: null);

        // Assert
        expect(copied.errorMessage, isNull);
      });
    });

    group('equality', () {
      test('같은 값을 가진 인스턴스는 동등해야 함', () {
        expectFreezedEquality<HomeModel>(
          original: const HomeModel(title: 'Same', isLoading: true),
          copy: const HomeModel(title: 'Same', isLoading: true),
          different: const HomeModel(title: 'Different', isLoading: true),
        );
      });

      test('isLoading 값이 다르면 동등하지 않아야 함', () {
        // Arrange
        const model1 = HomeModel(title: 'Same', isLoading: true);
        const model2 = HomeModel(title: 'Same', isLoading: false);

        // Assert
        expect(model1, isNot(equals(model2)));
      });

      test('errorMessage 값이 다르면 동등하지 않아야 함', () {
        // Arrange
        const model1 = HomeModel(title: 'Same', errorMessage: 'Error 1');
        const model2 = HomeModel(title: 'Same', errorMessage: 'Error 2');
        const model3 = HomeModel(title: 'Same');

        // Assert
        expect(model1, isNot(equals(model2)));
        expect(model1, isNot(equals(model3)));
      });
    });

    group('JSON serialization', () {
      test('toJson으로 직렬화할 수 있어야 함', () {
        // Arrange
        const model = HomeModel(
          title: 'Test',
          isLoading: true,
          errorMessage: 'Error',
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['title'], equals('Test'));
        expect(json['isLoading'], isTrue);
        expect(json['errorMessage'], equals('Error'));
      });

      test('fromJson으로 역직렬화할 수 있어야 함', () {
        // Arrange
        final json = {
          'title': 'Test',
          'isLoading': true,
          'errorMessage': 'Error',
        };

        // Act
        final model = HomeModel.fromJson(json);

        // Assert
        expect(model.title, equals('Test'));
        expect(model.isLoading, isTrue);
        expect(model.errorMessage, equals('Error'));
      });

      test('toJson과 fromJson의 왕복 변환이 동일해야 함', () {
        // Arrange
        const original = HomeModel(
          title: 'Roundtrip Test',
          isLoading: false,
          errorMessage: null,
        );

        // Act
        final json = original.toJson();
        final restored = HomeModel.fromJson(json);

        // Assert
        expect(restored, equals(original));
      });
    });

    group('toString', () {
      test('의미있는 문자열 표현을 반환해야 함', () {
        // Arrange
        const model = HomeModel(title: 'Debug Test');

        // Act
        final string = model.toString();

        // Assert
        expect(string, contains('HomeModel'));
        expect(string, contains('title'));
        expect(string, contains('Debug Test'));
      });
    });
  });
}
