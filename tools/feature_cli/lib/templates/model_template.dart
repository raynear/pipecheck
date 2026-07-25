String generateModelFile({
  required String pascalCase,
  required String snakeCase,
}) {
  return '''import 'package:freezed_annotation/freezed_annotation.dart';

part '${snakeCase}_model.freezed.dart';
part '${snakeCase}_model.g.dart';

@freezed
abstract class ${pascalCase}Model with _\$${pascalCase}Model {
  const factory ${pascalCase}Model({
    required String id,
    @Default(false) bool isLoading,
    String? errorMessage,
  }) = _${pascalCase}Model;

  factory ${pascalCase}Model.fromJson(Map<String, dynamic> json) =>
      _\$${pascalCase}ModelFromJson(json);
}
''';
}
