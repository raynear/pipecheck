import 'package:feature_cli/templates/test_template.dart';
import 'package:test/test.dart';

void main() {
  group('generateModelTestFile', () {
    final src = generateModelTestFile(
      pascalCase: 'UserProfile',
      snakeCase: 'user_profile',
      packageName: 'myapp',
    );

    test('동적 packageName으로 모델을 import한다', () {
      expect(
        src,
        contains(
            "package:myapp/features/user_profile/models/user_profile_model.dart"),
      );
    });

    test('실질 단언(equality/JSON 왕복)을 포함한다', () {
      expect(src, contains('expectFreezedEquality<UserProfileModel>'));
      expect(src, contains('UserProfileModel.fromJson(original.toJson())'));
    });
  });

  group('generateViewModelTestFile', () {
    test('withModel: build/initialize/clearError + 동적 provider명', () {
      final src = generateViewModelTestFile(
        pascalCase: 'UserProfile',
        snakeCase: 'user_profile',
        camelCase: 'userProfile',
        packageName: 'myapp',
        withModel: true,
      );
      expect(src, contains('userProfileViewModelProvider'));
      expect(src, contains("expect(state.id, equals(''));"));
      expect(src, contains('.initialize()'));
      expect(src, contains('.clearError()'));
      expect(src, contains('TestHelpers.createContainer()'));
    });

    test('withModel=false: State TODO 마커, state.id 없음', () {
      final src = generateViewModelTestFile(
        pascalCase: 'UserProfile',
        snakeCase: 'user_profile',
        camelCase: 'userProfile',
        packageName: 'myapp',
        withModel: false,
      );
      expect(src, contains('UserProfileState 초기 필드'));
      expect(src, isNot(contains('state.id')));
    });
  });

  group('generateViewTestFile', () {
    test('withViewModel: 정상/로딩/에러 분기를 모두 덮는다', () {
      final src = generateViewTestFile(
        pascalCase: 'UserProfile',
        snakeCase: 'user_profile',
        camelCase: 'userProfile',
        packageName: 'myapp',
        withViewModel: true,
        withModel: true,
      );
      // 동적 provider override + 로딩 분기 커버 — 두 개의 load-bearing 마커.
      expect(src, contains('userProfileViewModelProvider.overrideWith'));
      expect(src, contains('CircularProgressIndicator'));
    });

    test('withViewModel=false: 단순 뷰, override 없음', () {
      final src = generateViewTestFile(
        pascalCase: 'UserProfile',
        snakeCase: 'user_profile',
        camelCase: 'userProfile',
        packageName: 'myapp',
        withViewModel: false,
        withModel: false,
      );
      expect(src, contains("find.text('UserProfile')"));
      expect(src, isNot(contains('overrideWith')));
    });

    test('withViewModel + !withModel: State 기반(모델 import 없음)으로 컴파일 가능', () {
      final src = generateViewTestFile(
        pascalCase: 'UserProfile',
        snakeCase: 'user_profile',
        camelCase: 'userProfile',
        packageName: 'myapp',
        withViewModel: true,
        withModel: false,
      );
      // C1 회귀: 모델 파일을 import하면 안 되고, State 타입을 써야 함.
      expect(src, isNot(contains('models/user_profile_model.dart')));
      expect(src, isNot(contains('UserProfileModel')));
      expect(src, contains('UserProfileState build()'));
      expect(src, contains('const UserProfileState(isLoading: true)'));
      expect(src, contains('userProfileViewModelProvider.overrideWith'));
    });
  });

  group('generateRepositoryTestFile', () {
    final src = generateRepositoryTestFile(
      pascalCase: 'UserProfile',
      snakeCase: 'user_profile',
      packageName: 'myapp',
    );

    test('Impl 스텁 5개 메서드를 모두 호출한다', () {
      expect(src, contains('UserProfileRepositoryImpl()'));
      expect(src, contains('repo.getAll()'));
      expect(src, contains('repo.getById('));
      expect(src, contains('repo.create('));
      expect(src, contains('repo.update('));
      expect(src, contains('repo.delete('));
    });
  });

  group('생성된 테스트는 no-skip 게이트에 안전하다', () {
    final all = [
      generateModelTestFile(
          pascalCase: 'X', snakeCase: 'x', packageName: 'm'),
      generateViewModelTestFile(
          pascalCase: 'X',
          snakeCase: 'x',
          camelCase: 'x',
          packageName: 'm',
          withModel: true),
      generateViewTestFile(
          pascalCase: 'X',
          snakeCase: 'x',
          camelCase: 'x',
          packageName: 'm',
          withViewModel: true,
          withModel: true),
      generateRepositoryTestFile(
          pascalCase: 'X', snakeCase: 'x', packageName: 'm'),
    ];

    test('skip:/markTestSkipped/트리비얼 expect(true,...)를 쓰지 않는다', () {
      for (final src in all) {
        expect(src, isNot(matches(RegExp(r'\bskip\s*:'))));
        expect(src, isNot(contains('markTestSkipped')));
        expect(src,
            isNot(matches(RegExp(r'expect\(\s*true\s*,\s*(is)?[Tt]rue'))));
      }
    });
  });
}
