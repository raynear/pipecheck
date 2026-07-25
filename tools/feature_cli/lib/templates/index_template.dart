String generateIndexFile({
  required String featureName,
  required String pascalCase,
  required String snakeCase,
  required bool withModel,
  required bool withViewModel,
  required bool withWidgets,
  required bool withRepository,
}) {
  final exports = <String>[];

  exports.add("export 'views/${snakeCase}_view.dart';");

  if (withViewModel) {
    exports.add("export 'view_models/${snakeCase}_view_model.dart';");
  }

  if (withModel) {
    exports.add("export 'models/${snakeCase}_model.dart';");
  }

  if (withRepository) {
    exports.add("export 'repositories/${snakeCase}_repository.dart';");
  }

  return '''/// $pascalCase feature module
${exports.join('\n')}
''';
}
