# Code Style and Conventions

## Naming Conventions (analysis_options.yaml 기반)
- **Types (Classes, Enums, Typedefs)**: UpperCamelCase (예: `MyClass`, `HomeView`)
- **Extensions**: UpperCamelCase (예: `StringExtension`)
- **Files**: lowercase_with_underscores (예: `my_feature_view.dart`)
- **Packages**: lowercase_with_underscores
- **Variables, Functions, Parameters**: lowerCamelCase (예: `myVariable`, `fetchData()`)
- **Constants**: lowerCamelCase (예: `const defaultPadding = 16.0`)
- **Import Prefixes**: lowercase_with_underscores

## File Organization
- Feature 디렉토리 구조:
  ```
  features/[feature_name]/
  ├── models/[feature_name]_model.dart
  ├── view_models/[feature_name]_view_model.dart
  ├── views/[feature_name]_view.dart
  ├── widgets/                              # 선택
  ├── repositories/                         # 선택
  └── index.dart                            # barrel export
  ```

## Code Generation Files
- `*.g.dart`: JSON Serializable, Riverpod Generator
- `*.freezed.dart`: Freezed models
- `*.drift.dart`: Drift database
- 위 파일들은 lint에서 제외됨

## Import Style
- 패키지명으로 import (예: `package:boilerplate/...`)
- 상대 경로 import 지양

## Linting Rules
- `prefer_single_quotes: true` - 작은따옴표 사용
- `camel_case_types: true`
- `file_names: true`
- `curly_braces_in_flow_control_structures: true`
- `no_adjacent_strings_in_list: true`
- `lines_longer_than_80_chars: false` (비활성화됨)

## Documentation
- 공개 API에 JSDoc 스타일 주석 권장
- 한글 주석 사용 가능 (한국어 프로젝트)

## Riverpod Patterns
```dart
// ViewModel (Riverpod Generator 사용)
import 'package:riverpod_annotation/riverpod_annotation.dart';

part '[name]_view_model.g.dart';

@riverpod
class [Name]ViewModel extends _$[Name]ViewModel {
  @override
  [StateType] build() {
    return [initialState];
  }

  Future<void> someAction() async {
    state = state.copyWith(isLoading: true);
    // 로직
    state = state.copyWith(isLoading: false);
  }
}
```

## Freezed Model Patterns
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part '[name]_model.freezed.dart';
part '[name]_model.g.dart';

@freezed
class [Name]Model with _$[Name]Model {
  const factory [Name]Model({
    required String id,
    required String name,
    @Default(false) bool isActive,
  }) = _[Name]Model;

  factory [Name]Model.fromJson(Map<String, dynamic> json) =>
      _$[Name]ModelFromJson(json);
}
```

## View Patterns
```dart
class [Name]View extends ConsumerWidget {
  const [Name]View({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch([name]ViewModelProvider);
    final vm = ref.read([name]ViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('[Name]')),
      body: // UI
    );
  }
}
```

## Riverpod Usage
- `ref.watch`: build() 메서드 내에서 사용 (상태 구독)
- `ref.read`: 콜백, 이벤트 핸들러에서 사용 (일회성 읽기)
- `ref.listen`: 부수 효과 처리 (예: 에러 스낵바)
