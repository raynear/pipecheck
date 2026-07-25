/// 생성 기능과 짝이 되는 테스트 스캐폴드.
///
/// "초록이되 실질적" — 생성된 스켈레톤의 실제 동작(기본값/copyWith/equality/JSON,
/// build() 초기상태, 액션 전이, 첫 렌더)을 검증해 실커버리지를 올린다. 트리비얼
/// `expect(true, isTrue)`나 `skip:`은 쓰지 않는다(preflight no-skip 게이트에 걸림).
/// 확장 지점은 `// ponytail: TODO`로 표시한다.
///
/// packageName은 동적으로 받는다 — fork 후 ./init이 'boilerplate'를 바꾸므로
/// 하드코딩하면 rename된 프로젝트에서 import가 깨진다.

/// app/test/unit/models/<snake>_model_test.dart
String generateModelTestFile({
  required String pascalCase,
  required String snakeCase,
  required String packageName,
}) {
  return '''import 'package:$packageName/features/$snakeCase/models/${snakeCase}_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('${pascalCase}Model', () {
    group('factory constructor', () {
      test('기본값으로 생성되어야 함', () {
        const model = ${pascalCase}Model(id: 'test-id');

        expect(model.id, equals('test-id'));
        expect(model.isLoading, isFalse);
        expect(model.errorMessage, isNull);
      });

      test('모든 필드를 지정하여 생성할 수 있어야 함', () {
        const model = ${pascalCase}Model(
          id: 'custom-id',
          isLoading: true,
          errorMessage: 'oops',
        );

        expect(model.isLoading, isTrue);
        expect(model.errorMessage, equals('oops'));
      });
    });

    group('copyWith', () {
      test('isLoading만 변경하고 나머지는 유지', () {
        expectCopyWith<${pascalCase}Model>(
          original: const ${pascalCase}Model(id: 'id'),
          copyAction: (m) => m.copyWith(isLoading: true),
          verifyChange: (m) => expect(m.isLoading, isTrue),
          verifyUnchanged: (m) => expect(m.id, equals('id')),
        );
      });
    });

    group('equality', () {
      test('같은 값은 동등, 다른 값은 비동등', () {
        expectFreezedEquality<${pascalCase}Model>(
          original: const ${pascalCase}Model(id: 'same'),
          copy: const ${pascalCase}Model(id: 'same'),
          different: const ${pascalCase}Model(id: 'other'),
        );
      });
    });

    group('JSON', () {
      test('toJson↔fromJson 왕복이 동일', () {
        const original = ${pascalCase}Model(id: 'roundtrip');

        expect(${pascalCase}Model.fromJson(original.toJson()), equals(original));
      });
    });

    // ponytail: TODO 도메인 필드를 추가하면 여기에 검증을 확장하세요
    // (home_model_test.dart 참고).
  });
}
''';
}

/// app/test/unit/view_models/<snake>_view_model_test.dart
String generateViewModelTestFile({
  required String pascalCase,
  required String snakeCase,
  required String camelCase,
  required String packageName,
  required bool withModel,
}) {
  final initialAssert = withModel
      ? "expect(state.id, equals(''));"
      : '// ponytail: TODO ${pascalCase}State 초기 필드를 검증하세요';
  return '''import 'package:$packageName/features/$snakeCase/view_models/${snakeCase}_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('${pascalCase}ViewModel', () {
    test('build — 초기 상태를 반환', () {
      final container = TestHelpers.createContainer();
      addTearDown(container.dispose);

      final state = container.read(${camelCase}ViewModelProvider);

      $initialAssert
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('initialize — 완료 후 isLoading=false', () async {
      final container = TestHelpers.createContainer();
      addTearDown(container.dispose);

      await container.read(${camelCase}ViewModelProvider.notifier).initialize();

      expect(container.read(${camelCase}ViewModelProvider).isLoading, isFalse);
      // ponytail: TODO initialize()에 실제 로직을 추가하면 로딩 중·결과 상태를 함께 검증
    });

    test('clearError — errorMessage를 null로', () {
      final container = TestHelpers.createContainer();
      addTearDown(container.dispose);

      container.read(${camelCase}ViewModelProvider.notifier).clearError();

      expect(container.read(${camelCase}ViewModelProvider).errorMessage, isNull);
    });
  });
}
''';
}

/// app/test/widget/<snake>_view_test.dart
String generateViewTestFile({
  required String pascalCase,
  required String snakeCase,
  required String camelCase,
  required String packageName,
  required bool withViewModel,
  required bool withModel,
}) {
  if (!withViewModel) {
    // ViewModel 없는 단순 뷰 — 분기 없음.
    return '''import 'package:$packageName/features/$snakeCase/views/${snakeCase}_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('${pascalCase}View', () {
    testWidgets('제목이 렌더된다', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ${pascalCase}View()));
      await tester.pump();

      expect(find.text('$pascalCase'), findsOneWidget);
    });
  });
}
''';
  }
  // 상태 타입은 withModel에 따라 Model 또는 (모델 없는) 손작성 State.
  // withModel=false면 모델 파일이 없으므로 import/타입을 State로 맞춘다(C1 회귀).
  final stateType = withModel ? '${pascalCase}Model' : '${pascalCase}State';
  final modelImport = withModel
      ? "import 'package:$packageName/features/$snakeCase/models/${snakeCase}_model.dart';\n"
      : '';
  final base = withModel ? "id: 'x'" : '';
  final sep = withModel ? ', ' : '';
  return '''${modelImport}import 'package:$packageName/features/$snakeCase/view_models/${snakeCase}_view_model.dart';
import 'package:$packageName/features/$snakeCase/views/${snakeCase}_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 고정 상태를 주입하는 fake — build()가 주어진 상태를 반환.
class _Fixed${pascalCase}VM extends ${pascalCase}ViewModel {
  _Fixed${pascalCase}VM(this._state);
  final $stateType _state;
  @override
  $stateType build() => _state;
}

Widget _host($stateType state) => ProviderScope(
      overrides: [
        ${camelCase}ViewModelProvider.overrideWith(() => _Fixed${pascalCase}VM(state)),
      ],
      child: const MaterialApp(home: ${pascalCase}View()),
    );

void main() {
  group('${pascalCase}View', () {
    testWidgets('정상 상태 — 제목이 렌더된다', (tester) async {
      await tester.pumpWidget(_host(const $stateType($base)));
      await tester.pump();

      expect(find.text('$pascalCase'), findsOneWidget);
    });

    testWidgets('로딩 상태 — 인디케이터를 표시한다', (tester) async {
      await tester.pumpWidget(
        _host(const $stateType(${base}${sep}isLoading: true)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('에러 상태 — 메시지와 다시 시도를 표시한다', (tester) async {
      await tester.pumpWidget(
        _host(const $stateType(${base}${sep}errorMessage: 'boom')),
      );
      await tester.pump();

      expect(find.text('boom'), findsOneWidget);
      // ponytail: TODO '다시 시도' 탭 → clearError 동작을 검증하세요
    });
  });
}
''';
}

/// app/test/unit/repositories/<snake>_repository_test.dart (withModel 전제)
String generateRepositoryTestFile({
  required String pascalCase,
  required String snakeCase,
  required String packageName,
}) {
  return '''import 'package:$packageName/features/$snakeCase/models/${snakeCase}_model.dart';
import 'package:$packageName/features/$snakeCase/repositories/${snakeCase}_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('${pascalCase}RepositoryImpl 기본 동작', () {
    final repo = ${pascalCase}RepositoryImpl();

    test('getAll은 빈 리스트를 반환', () async {
      expect(await repo.getAll(), isEmpty);
    });

    test('getById는 null을 반환', () async {
      expect(await repo.getById('x'), isNull);
    });

    test('create/update/delete는 예외 없이 완료', () async {
      // ponytail: TODO 실제 CRUD를 구현하면 영속화 동작 검증으로 교체하세요
      await repo.create(const ${pascalCase}Model(id: 'x'));
      await repo.update(const ${pascalCase}Model(id: 'x'));
      await repo.delete('x');
    });
  });
}
''';
}
