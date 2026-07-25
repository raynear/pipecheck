String generateRepositoryFile({
  required String pascalCase,
  required String snakeCase,
  required bool withModel,
}) {
  if (withModel) {
    return '''import '../models/${snakeCase}_model.dart';

/// ${pascalCase} Repository 인터페이스
abstract class ${pascalCase}Repository {
  Future<List<${pascalCase}Model>> getAll();
  Future<${pascalCase}Model?> getById(String id);
  Future<void> create(${pascalCase}Model item);
  Future<void> update(${pascalCase}Model item);
  Future<void> delete(String id);
}

/// ${pascalCase} Repository 구현체
class ${pascalCase}RepositoryImpl implements ${pascalCase}Repository {
  @override
  Future<List<${pascalCase}Model>> getAll() async {
    // TODO: 구현
    return [];
  }

  @override
  Future<${pascalCase}Model?> getById(String id) async {
    // TODO: 구현
    return null;
  }

  @override
  Future<void> create(${pascalCase}Model item) async {
    // TODO: 구현
  }

  @override
  Future<void> update(${pascalCase}Model item) async {
    // TODO: 구현
  }

  @override
  Future<void> delete(String id) async {
    // TODO: 구현
  }
}
''';
  } else {
    return '''/// ${pascalCase} Repository 인터페이스
abstract class ${pascalCase}Repository {
  Future<List<Map<String, dynamic>>> getAll();
  Future<Map<String, dynamic>?> getById(String id);
  Future<void> create(Map<String, dynamic> item);
  Future<void> update(Map<String, dynamic> item);
  Future<void> delete(String id);
}

/// ${pascalCase} Repository 구현체
class ${pascalCase}RepositoryImpl implements ${pascalCase}Repository {
  @override
  Future<List<Map<String, dynamic>>> getAll() async {
    // TODO: 구현
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getById(String id) async {
    // TODO: 구현
    return null;
  }

  @override
  Future<void> create(Map<String, dynamic> item) async {
    // TODO: 구현
  }

  @override
  Future<void> update(Map<String, dynamic> item) async {
    // TODO: 구현
  }

  @override
  Future<void> delete(String id) async {
    // TODO: 구현
  }
}
''';
  }
}
