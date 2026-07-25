import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'annotations.dart';
import 'generators/drift_table_generator.dart';
import 'generators/model_generator.dart';
import 'generators/repository_generator.dart';

/// 테이블 생성 빌더
class TableGeneratorBuilder extends Builder {
  final BuilderOptions options;

  // TypeChecker는 빌드 시점에 동적으로 생성됨
  TypeChecker? _generateTableChecker;

  TableGeneratorBuilder(this.options);

  TypeChecker _getGenerateTableChecker(String packageName) {
    _generateTableChecker ??= TypeChecker.fromUrl(
      'package:$packageName/data/table_generator/annotations.dart#GenerateTable',
    );
    return _generateTableChecker!;
  }

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    log.info('[Table Generator] Builder called for: ${buildStep.inputId.path}');

    // .dart 파일에서 GenerateTable 어노테이션이 있는 클래스 찾기
    if (!await buildStep.resolver.isLibrary(buildStep.inputId)) {
      log.fine('[Table Generator] Not a library: ${buildStep.inputId.path}');
      return;
    }

    log.info('[Table Generator] Processing file: ${buildStep.inputId.path}');

    // 패키지 이름 가져오기
    final packageName = buildStep.inputId.package;

    // 라이브러리 가져오기
    final library = await buildStep.inputLibrary;
    final libraryReader = LibraryReader(library);

    // GenerateTable 어노테이션이 있는 클래스들 찾기
    final annotatedElements = libraryReader.annotatedWith(_getGenerateTableChecker(packageName));

    log.info('[Table Generator] Found ${annotatedElements.length} annotated elements');

    final generatedTables = <String>[];
    final generatedRepositories = <String>[];

    for (final annotatedElement in annotatedElements) {
      final element = annotatedElement.element;
      if (element is! ClassElement) continue;

      final annotation = annotatedElement.annotation;
      final className = element.name;
      if (className == null) continue;

      log.info('[Table Generator] Found @GenerateTable on class: $className');

      final tableName = _getTableName(element, annotation);
      generatedTables.add(tableName);
      generatedRepositories.add(className);

      // 경로 설정 가져오기
      final paths = _getOutputPaths(annotation);

      // 자동 업데이트 설정 (어노테이션 > build.yaml > 기본값)
      final autoUpdateConfig = options.config['auto_update'];
      final updateDatabase = annotation.peek('updateDatabase')?.boolValue ??
          (autoUpdateConfig != null ? autoUpdateConfig['database'] == true : true);
      // Note: updateProviders is available for future use
      // final updateProviders = annotation.peek('updateProviders')?.boolValue ??
      //                       (autoUpdateConfig != null ? autoUpdateConfig['providers'] == true : true);

      // 각 생성기 실행 (SQL/RLS 생성은 supabase 철거와 함께 제거 — P1-16.5a)
      await _generateDriftTable(buildStep, element, annotation, tableName, paths.driftPath);
      await _generateModel(buildStep, element, annotation, tableName, paths.modelPath);
      await _generateRepository(buildStep, element, tableName, paths.repositoryPath);

      // 자동 업데이트 처리
      if (updateDatabase) {
        await _updateDatabaseFile(buildStep, tableName, className);
      }
    }
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        '.dart': [
          '.drift.dart',
          '.model.dart',
          '.repository.dart',
        ],
      };

  String _getTableName(ClassElement element, ConstantReader annotation) {
    final tableName = annotation.peek('tableName')?.stringValue;
    final className = element.name ?? 'Unknown';
    return tableName ?? _toSnakeCase(className.replaceAll('Model', ''));
  }

  String _toSnakeCase(String text) {
    final result = text.replaceAllMapped(
      RegExp('([A-Z])'),
      (match) => '_${match.group(1)!.toLowerCase()}',
    );

    // 첫 글자가 '_'로 시작하면 제거
    return result.startsWith('_') ? result.substring(1) : result;
  }

  OutputPaths _getOutputPaths(ConstantReader annotation) {
    final pathsObj = annotation.peek('paths')?.objectValue;

    // 어노테이션에 경로가 설정되어 있으면 사용
    if (pathsObj != null) {
      final driftPath = pathsObj.getField('driftPath')?.toStringValue();
      final modelPath = pathsObj.getField('modelPath')?.toStringValue();
      final repositoryPath = pathsObj.getField('repositoryPath')?.toStringValue();

      if (driftPath != null || modelPath != null || repositoryPath != null) {
        return OutputPaths(
          driftPath: driftPath,
          modelPath: modelPath,
          repositoryPath: repositoryPath,
        );
      }
    }

    // build.yaml의 기본 경로 사용
    final defaultPaths = options.config['default_paths'];
    if (defaultPaths != null) {
      return OutputPaths(
        driftPath: defaultPaths['drift_path']?.toString(),
        modelPath: defaultPaths['model_path']?.toString(),
        repositoryPath: defaultPaths['repository_path']?.toString(),
      );
    }

    // 모두 없으면 기본값
    return const OutputPaths();
  }

  AssetId _getOutputId(BuildStep buildStep, String extension, String? customPath) {
    final inputId = buildStep.inputId;

    // build_runner의 제약으로 인해 현재는 같은 폴더에만 생성 가능
    // 파일 이동은 organize_files.dart 스크립트로 처리
    return inputId.changeExtension(extension);
  }

  Future<void> _generateDriftTable(
    BuildStep buildStep,
    ClassElement element,
    ConstantReader annotation,
    String tableName,
    String? customPath,
  ) async {
    final packageName = buildStep.inputId.package;
    final generator = DriftTableGenerator();
    final content = generator.generate(element, annotation, tableName, packageName: packageName);

    final outputId = _getOutputId(buildStep, '.drift.dart', customPath);
    await buildStep.writeAsString(outputId, content);
  }

  Future<void> _generateModel(
    BuildStep buildStep,
    ClassElement element,
    ConstantReader annotation,
    String tableName,
    String? customPath,
  ) async {
    final packageName = buildStep.inputId.package;
    final generator = ModelGenerator();
    final originalFileName = buildStep.inputId.pathSegments.last;
    final content = generator.generate(
      element,
      annotation,
      tableName,
      originalFileName: originalFileName,
      packageName: packageName,
    );

    final outputId = _getOutputId(buildStep, '.model.dart', customPath);
    await buildStep.writeAsString(outputId, content);
  }

  Future<void> _generateRepository(
    BuildStep buildStep,
    ClassElement element,
    String tableName,
    String? customPath,
  ) async {
    final packageName = buildStep.inputId.package;
    final generator = RepositoryGenerator();
    final content = generator.generate(element, tableName, packageName: packageName);

    final outputId = _getOutputId(buildStep, '.repository.dart', customPath);
    await buildStep.writeAsString(outputId, content);
  }

  Future<void> _updateDatabaseFile(
    BuildStep buildStep,
    String tableName,
    String className,
  ) async {
    // database.dart 파일 경로 찾기
    final databaseId = AssetId(
      buildStep.inputId.package,
      'lib/data/datasources/local/database/database.dart',
    );

    try {
      if (!await buildStep.canRead(databaseId)) {
        log.fine('[Table Generator] Cannot read database.dart, skipping auto-update');
        return;
      }

      final content = await buildStep.readAsString(databaseId);

      // 이미 추가되어 있는지 확인
      final tableClassName = '${className}s';
      if (content.contains(tableClassName)) {
        log.fine('[Table Generator] Table $tableClassName already exists in database.dart');
        return;
      }

      // @DriftDatabase 어노테이션 찾기
      final driftDbPattern = RegExp(r'@DriftDatabase\s*\(\s*tables:\s*\[([^\]]*)\]', multiLine: true, dotAll: true);
      final match = driftDbPattern.firstMatch(content);

      if (match != null) {
        final existingTables = match.group(1)!;

        // 새 테이블 추가
        final updatedTables = '${existingTables.trimRight()}, $tableClassName';

        // 파일 업데이트 기록
        log.info('[Table Generator] Updated database.dart with table: $tableClassName (tables: [$updatedTables])');
        log.info('[Table Generator] Note: This is a generated update. Please run build_runner to apply changes.');

        // 업데이트 정보를 별도 파일에 저장 (실제 파일 수정은 수동으로)
        final packageName = buildStep.inputId.package;
        final updateInfoId = AssetId(
          packageName,
          'lib/data/generators/.database_updates.txt',
        );

        final updateInfo = '''
Table: $tableClassName
Import: import 'package:$packageName/data/models/$tableName.drift.dart';
Add to @DriftDatabase tables array
Generated at: ${DateTime.now()}
---
''';

        if (await buildStep.canRead(updateInfoId)) {
          final existing = await buildStep.readAsString(updateInfoId);
          await buildStep.writeAsString(updateInfoId, existing + updateInfo);
        } else {
          await buildStep.writeAsString(updateInfoId, updateInfo);
        }
      }
    } catch (e) {
      log.warning('[Table Generator] Error updating database.dart: $e');
    }
  }
}

/// Builder 팩토리 함수
Builder tableGeneratorBuilder(BuilderOptions options) => TableGeneratorBuilder(options);
