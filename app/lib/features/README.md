# Feature 구조 가이드

이 문서는 Flutter boilerplate 프로젝트에서 새로운 feature를 생성할 때 따라야 할 표준 구조를 설명합니다.

## 표준 Feature 구조

```
features/{feature_name}/
├── index.dart              # Barrel export (필수)
├── models/                 # Feature 전용 데이터 모델 (선택)
│   └── {feature}_model.dart
├── view_models/            # Riverpod Notifier (선택)
│   └── {feature}_view_model.dart
├── views/                  # UI 화면 (필수)
│   └── {feature}_view.dart
└── widgets/                # Feature 전용 위젯 (선택)
    └── {feature}_widget.dart
```

## Feature 유형

### 1. 단순 뷰 (Simple View)
비즈니스 로직이 없는 정적 화면. `views/` 폴더만 필요.

**예시**: `splash`, `permission`, `onboarding`

```
splash/
├── index.dart
└── views/
    └── splash_view.dart
```

### 2. 상태 관리 Feature (Stateful Feature)
비즈니스 로직과 상태 관리가 필요한 화면.

**예시**: `home`, `auth`, `settings`, `subscription`

```
home/
├── index.dart
├── models/
│   └── home_model.dart       # @freezed 사용
├── view_models/
│   └── home_view_model.dart  # Notifier<HomeModel>
└── views/
    └── home_view.dart
```

## 파일 작성 가이드

### index.dart (Barrel Export)
```dart
// Public API만 export
export 'views/home_view.dart';
export 'view_models/home_view_model.dart';
// models는 필요시에만 export
```

### Model (@freezed 사용)
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part '{feature}_model.freezed.dart';
part '{feature}_model.g.dart';

@freezed
abstract class {Feature}Model with _${Feature}Model {
  const factory {Feature}Model({
    required String id,
    @Default(false) bool isLoading,
    String? errorMessage,
  }) = _{Feature}Model;

  factory {Feature}Model.fromJson(Map<String, dynamic> json) =>
      _${Feature}ModelFromJson(json);
}
```

### ViewModel (Riverpod Notifier)
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/{feature}_model.dart';

final {feature}ViewModelProvider =
    NotifierProvider<{Feature}ViewModel, {Feature}Model>(
  {Feature}ViewModel.new,
);

class {Feature}ViewModel extends Notifier<{Feature}Model> {
  @override
  {Feature}Model build() {
    return const {Feature}Model(id: '');
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      // 초기화 로직
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}
```

### View
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../view_models/{feature}_view_model.dart';

class {Feature}View extends ConsumerWidget {
  const {Feature}View({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch({feature}ViewModelProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('{Feature}')),
      body: // UI 구현
    );
  }
}
```

## 현재 Feature 현황

| Feature | 유형 | models | view_models | views | 상태 |
|---------|------|--------|-------------|-------|------|
| auth | Stateful | - | ✅ | ✅ | OK |
| home | Stateful | ✅ | ✅ | ✅ | 표준 |
| onboarding | Simple | - | - | ✅ | OK |
| permission | Simple | - | - | ✅ | OK |
| settings | Stateful | - | - | ✅ | Core에 통합 |
| splash | Simple | - | - | ✅ | OK |
| subscription | Stateful | - | - | ✅ | 확장 예정 |

## CLI 도구

새 Feature 생성을 위한 CLI 도구 사용법:

```bash
# 기본 (view만)
./feature generate -n profile

# 전체 구조
./feature generate -n checkout --with-model --with-viewmodel

# 위젯 폴더 포함
./feature generate -n dashboard --with-model --with-viewmodel --with-widgets
```

## 베스트 프랙티스

1. **모델은 항상 @freezed 사용**: 불변성 보장, copyWith/toJson 자동 생성
2. **ViewModel은 도메인 로직만**: UI 로직은 View에서 처리
3. **core/widgets 활용**: 공통 위젯은 feature에 중복 작성하지 않음
4. **index.dart로 캡슐화**: 내부 구현은 숨기고 public API만 export
5. **라우트 등록**: 새 View 추가 시 `router.dart`에 등록 필요
