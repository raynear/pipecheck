String generateViewModelFile({
  required String pascalCase,
  required String snakeCase,
  required String camelCase,
  required bool withModel,
}) {
  if (withModel) {
    return '''import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/${snakeCase}_model.dart';

final ${camelCase}ViewModelProvider =
    NotifierProvider<${pascalCase}ViewModel, ${pascalCase}Model>(
  ${pascalCase}ViewModel.new,
);

class ${pascalCase}ViewModel extends Notifier<${pascalCase}Model> {
  @override
  ${pascalCase}Model build() {
    return const ${pascalCase}Model(id: '');
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      // TODO: 초기화 로직 구현
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
''';
  } else {
    // Without model - simple state
    return '''import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ${pascalCase} 화면의 상태
class ${pascalCase}State {
  final bool isLoading;
  final String? errorMessage;

  const ${pascalCase}State({
    this.isLoading = false,
    this.errorMessage,
  });

  ${pascalCase}State copyWith({
    bool? isLoading,
    String? errorMessage,
  }) {
    return ${pascalCase}State(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final ${camelCase}ViewModelProvider =
    NotifierProvider<${pascalCase}ViewModel, ${pascalCase}State>(
  ${pascalCase}ViewModel.new,
);

class ${pascalCase}ViewModel extends Notifier<${pascalCase}State> {
  @override
  ${pascalCase}State build() {
    return const ${pascalCase}State();
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      // TODO: 초기화 로직 구현
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
''';
  }
}
