import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit 테스트를 위한 공통 헬퍼 클래스
class TestHelpers {
  TestHelpers._();

  /// ProviderContainer 생성 (테스트용)
  ///
  /// ```dart
  /// final container = TestHelpers.createContainer(
  ///   overrides: [myProvider.overrideWithValue(mockValue)],
  /// );
  /// addTearDown(container.dispose);
  /// ```
  static ProviderContainer createContainer([
    List<dynamic> overrides = const [],
  ]) {
    return ProviderContainer(overrides: overrides.cast());
  }

  /// Riverpod Provider 테스트 래퍼
  ///
  /// ```dart
  /// await TestHelpers.runProviderTest(
  ///   overrides: [myProvider.overrideWithValue(mockValue)],
  ///   test: (container) async {
  ///     final result = container.read(myProvider);
  ///     expect(result, expectedValue);
  ///   },
  /// );
  /// ```
  static Future<void> runProviderTest({
    required Future<void> Function(ProviderContainer) test,
    List<dynamic> overrides = const [],
  }) async {
    final container = createContainer(overrides);
    try {
      await test(container);
    } finally {
      container.dispose();
    }
  }

  /// 비동기 작업 대기 헬퍼
  ///
  /// ```dart
  /// await TestHelpers.pumpAndSettle(tester);
  /// ```
  static Future<void> pumpAndSettle(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  /// 테스트용 날짜 생성 (고정된 날짜)
  static DateTime get fixedDate => DateTime(2024, 1, 1, 12, 0, 0);

  /// 테스트용 TimeOfDay 생성
  static TimeOfDay get fixedTimeOfDay => const TimeOfDay(hour: 9, minute: 0);
}

/// 테스트용 Mock 생성 확장
extension TestMockExtensions on Object {
  /// 타입 캐스팅 헬퍼
  T as<T>() => this as T;
}

/// 매쳐 확장
extension TestMatcherExtensions on Matcher {
  /// null 또는 특정 조건 매칭
  Matcher get orNull => anyOf([isNull, this]);
}

/// 테스트 그룹 설정 헬퍼
///
/// ```dart
/// void main() {
///   setUpTestGroup(
///     setUp: () { /* 테스트 전 실행 */ },
///     tearDown: () { /* 테스트 후 실행 */ },
///   );
///
///   test('my test', () { ... });
/// }
/// ```
void setUpTestGroup({
  void Function()? setUp,
  void Function()? tearDown,
  void Function()? setUpAll,
  void Function()? tearDownAll,
}) {
  if (setUpAll != null) {
    setUpAll(); // This registers the callback
  }
  if (tearDownAll != null) {
    tearDownAll(); // This registers the callback
  }
  if (setUp != null) {
    setUp(); // This registers the callback
  }
  if (tearDown != null) {
    tearDown(); // This registers the callback
  }
}

/// 예외 테스트 헬퍼
///
/// ```dart
/// expectException<FormatException>(
///   () => int.parse('not a number'),
///   'FormatException should be thrown',
/// );
/// ```
void expectException<T extends Exception>(
  void Function() action,
  String reason,
) {
  expect(
    action,
    throwsA(isA<T>()),
    reason: reason,
  );
}

/// 비동기 예외 테스트 헬퍼
Future<void> expectAsyncException<T extends Exception>(
  Future<void> Function() action,
  String reason,
) async {
  try {
    await action();
    fail(reason);
  } catch (e) {
    expect(e, isA<T>(), reason: reason);
  }
}

/// Freezed 모델 equality 테스트 헬퍼
///
/// ```dart
/// expectFreezedEquality(
///   original: HomeModel(title: 'A'),
///   copy: HomeModel(title: 'A'),
///   different: HomeModel(title: 'B'),
/// );
/// ```
void expectFreezedEquality<T>({
  required T original,
  required T copy,
  required T different,
}) {
  // 같은 값은 동등해야 함
  expect(original, equals(copy), reason: 'Same values should be equal');
  expect(original.hashCode, equals(copy.hashCode),
      reason: 'Same values should have same hashCode');

  // 다른 값은 동등하지 않아야 함
  expect(original, isNot(equals(different)),
      reason: 'Different values should not be equal');
}

/// copyWith 테스트 헬퍼
///
/// ```dart
/// expectCopyWith<HomeModel>(
///   original: HomeModel(title: 'A', isLoading: false),
///   copyAction: (m) => m.copyWith(title: 'B'),
///   verifyChange: (m) => expect(m.title, 'B'),
///   verifyUnchanged: (m) => expect(m.isLoading, false),
/// );
/// ```
void expectCopyWith<T>({
  required T original,
  required T Function(T) copyAction,
  required void Function(T) verifyChange,
  required void Function(T) verifyUnchanged,
}) {
  final copied = copyAction(original);

  // 원본과 복사본이 다른 인스턴스여야 함
  expect(identical(original, copied), isFalse,
      reason: 'Copy should be a different instance');

  // 변경된 값 확인
  verifyChange(copied);

  // 변경되지 않은 값 확인
  verifyUnchanged(copied);
}
