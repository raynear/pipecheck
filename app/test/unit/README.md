# Unit Tests

이 폴더는 프로젝트의 Unit 테스트를 포함합니다.

## 구조

```
test/unit/
├── helpers/           # 테스트 헬퍼 및 유틸리티
│   └── test_helpers.dart
├── models/            # 모델 테스트
│   └── home_model_test.dart
└── README.md          # 이 문서
```

> `Validators` 등 공용 유틸리티 테스트는 `packages/utils/test/`로 이동했습니다
> (P2-19a — utils SSOT 통합). `cd app/packages/utils && flutter test`로 실행.

## 테스트 실행

```bash
# 모든 unit 테스트 실행
flutter test test/unit/

# 특정 파일 테스트
flutter test test/unit/models/home_model_test.dart

# 커버리지 포함 테스트
flutter test --coverage test/unit/
```

## 테스트 작성 가이드라인

### 1. 파일 명명 규칙
- 테스트 대상 파일: `{name}.dart`
- 테스트 파일: `{name}_test.dart`

### 2. 테스트 구조 (AAA 패턴)
```dart
test('설명', () {
  // Arrange - 테스트 준비
  final input = 'test@example.com';

  // Act - 실행
  final result = Validators.email(input);

  // Assert - 검증
  expect(result, isNull);
});
```

### 3. 그룹화
```dart
group('Validators', () {
  group('email', () {
    test('유효한 이메일을 허용해야 함', () { ... });
    test('잘못된 이메일을 거부해야 함', () { ... });
  });
});
```

### 4. Matcher 사용
```dart
// 기본 matchers
expect(result, isNull);
expect(result, isNotNull);
expect(result, equals('예상값'));

// Freezed 모델 비교
expect(model, isA<HomeModel>());
expect(model.title, equals('Test'));

// 컬렉션 matchers
expect(list, hasLength(3));
expect(list, contains('item'));
```

## 새 테스트 추가하기

1. 적절한 폴더에 `_test.dart` 파일 생성
2. `test_helpers.dart`에서 필요한 헬퍼 임포트
3. 테스트 작성 및 실행

```dart
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('YourClass', () {
    test('기능 설명', () {
      // 테스트 코드
    });
  });
}
```

## 통합 테스트와의 차이

| 구분 | Unit 테스트 | Integration 테스트 |
|------|-------------|-------------------|
| 위치 | `test/unit/` | `test/integration/` |
| 범위 | 단일 함수/클래스 | 여러 컴포넌트 통합 |
| 속도 | 빠름 (밀리초) | 느림 (초) |
| 의존성 | Mock 사용 | 실제 또는 Mock |
| 목적 | 로직 검증 | 흐름 검증 |
