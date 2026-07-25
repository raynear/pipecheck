import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import '../utils.dart';
import '../templates/index_template.dart';
import '../templates/model_template.dart';
import '../templates/repository_template.dart';
import '../templates/test_template.dart';
import '../templates/view_model_template.dart';
import '../templates/view_template.dart';

/// Generate command - 새 feature 스캐폴딩 생성
class GenerateCommand extends Command<void> {
  @override
  final name = 'generate';

  @override
  final aliases = ['gen', 'g', 'create'];

  @override
  final description = '새 feature 스캐폴딩 생성';

  GenerateCommand() {
    argParser
      ..addOption(
        'name',
        abbr: 'n',
        help: 'Feature name (e.g., profile, checkout)',
      )
      ..addFlag(
        'with-model',
        defaultsTo: false,
        help: 'Generate @freezed model file',
      )
      ..addFlag(
        'with-viewmodel',
        defaultsTo: false,
        help: 'Generate ViewModel (Notifier) file',
      )
      ..addFlag(
        'with-widgets',
        defaultsTo: false,
        help: 'Create widgets folder',
      )
      ..addFlag(
        'with-repository',
        defaultsTo: false,
        help: 'Generate Repository interface and implementation',
      )
      ..addFlag(
        'with-test',
        defaultsTo: false,
        help: 'Generate matching test files (model/viewmodel/widget). --full implies on; use --no-test to opt out.',
      )
      ..addFlag(
        'full',
        abbr: 'f',
        defaultsTo: false,
        help: 'Generate full structure (model + viewmodel + widgets + repository)',
      )
      ..addFlag(
        'skip-build',
        defaultsTo: false,
        help: 'Skip auto-running ./build after generation',
      );
  }

  @override
  Future<void> run() async {
    // Support both -n option and positional argument
    String? featureName = argResults!['name'] as String?;

    // If -n not provided, check for positional argument
    if (featureName == null || featureName.isEmpty) {
      if (argResults!.rest.isNotEmpty) {
        featureName = argResults!.rest.first;
      } else {
        print('Error: Feature name is required');
        print('Usage: ./feature create <feature_name>');
        print('       ./feature generate -n <feature_name>');
        exit(1);
      }
    }

    final isFull = argResults!['full'] as bool;
    final skipBuild = argResults!['skip-build'] as bool;

    final withModel = isFull || (argResults!['with-model'] as bool);
    final withViewModel = isFull || (argResults!['with-viewmodel'] as bool);
    final withWidgets = isFull || (argResults!['with-widgets'] as bool);
    final withRepository = isFull || (argResults!['with-repository'] as bool);
    // --full이면 테스트 ON, 아니면 --with-test 따름(--no-test로 끔).
    final withTest = isFull || (argResults!['with-test'] as bool);

    await generateFeature(
      featureName: featureName,
      withModel: withModel,
      withViewModel: withViewModel,
      withWidgets: withWidgets,
      withRepository: withRepository,
      withTest: withTest,
      runBuild: !skipBuild && withModel,
    );
  }
}

Future<void> generateFeature({
  required String featureName,
  required bool withModel,
  required bool withViewModel,
  required bool withWidgets,
  required bool withRepository,
  required bool withTest,
  required bool runBuild,
}) async {
  // Convert case
  final snakeCase = toSnakeCase(featureName);
  final pascalCase = toPascalCase(featureName);
  final camelCase = toCamelCase(featureName);

  // Resolve base path
  final basePath = path.join(getFeaturesDir(), snakeCase);

  print('Creating feature: $pascalCase');
  print('Location: $basePath\n');

  // Create directories
  await _createDirectory(path.join(basePath, 'views'));
  if (withModel) await _createDirectory(path.join(basePath, 'models'));
  if (withRepository) await _createDirectory(path.join(basePath, 'repositories'));
  if (withViewModel) await _createDirectory(path.join(basePath, 'view_models'));
  if (withWidgets) await _createDirectory(path.join(basePath, 'widgets'));

  // Generate files
  final files = <String, String>{};

  // index.dart
  files['index.dart'] = generateIndexFile(
    featureName: featureName,
    pascalCase: pascalCase,
    snakeCase: snakeCase,
    withModel: withModel,
    withViewModel: withViewModel,
    withWidgets: withWidgets,
    withRepository: withRepository,
  );

  // View
  files['views/${snakeCase}_view.dart'] = generateViewFile(
    pascalCase: pascalCase,
    snakeCase: snakeCase,
    camelCase: camelCase,
    withViewModel: withViewModel,
    withModel: withModel,
  );

  // Model
  if (withModel) {
    files['models/${snakeCase}_model.dart'] = generateModelFile(
      pascalCase: pascalCase,
      snakeCase: snakeCase,
    );
  }

  // Repository
  if (withRepository) {
    files['repositories/${snakeCase}_repository.dart'] = generateRepositoryFile(
      pascalCase: pascalCase,
      snakeCase: snakeCase,
      withModel: withModel,
    );
  }

  // ViewModel
  if (withViewModel) {
    files['view_models/${snakeCase}_view_model.dart'] = generateViewModelFile(
      pascalCase: pascalCase,
      snakeCase: snakeCase,
      camelCase: camelCase,
      withModel: withModel,
    );
  }

  // Write files
  for (final entry in files.entries) {
    final filePath = path.join(basePath, entry.key);
    await _writeFile(filePath, entry.value);
    print('  Created: ${entry.key}');
  }

  // Test files — app/test/ 아래(평면 관례), basePath(lib/features) 밖.
  if (withTest) {
    await _generateTestFiles(
      pascalCase: pascalCase,
      snakeCase: snakeCase,
      camelCase: camelCase,
      withModel: withModel,
      withViewModel: withViewModel,
      withRepository: withRepository,
    );
  }

  print('\n✓ Feature "$pascalCase" created successfully!');

  // Auto-register route in router.dart
  final routeRegistered = await _registerRoute(
    snakeCase: snakeCase,
    pascalCase: pascalCase,
  );

  // Auto-run ./build if model was generated
  if (runBuild) {
    print('\n🔄 Running code generation (./build)...\n');
    await _runBuild();
  }

  print('\nNext steps:');
  if (!routeRegistered) {
    print('  1. Add route in router.dart');
  }
  if (!runBuild && withModel) {
    print('  ${routeRegistered ? 1 : 2}. Run: ./build');
    print('  ${routeRegistered ? 2 : 3}. Implement your feature logic');
  } else {
    print('  ${routeRegistered ? 1 : 2}. Implement your feature logic');
  }
}

Future<void> _createDirectory(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}

Future<void> _writeFile(String filePath, String content) async {
  final file = File(filePath);
  await file.writeAsString(content);
}

/// 생성 기능과 짝이 되는 테스트를 app/test/ 평면 관례에 맞게 배출한다.
/// 위젯 테스트는 항상, 모델/뷰모델 테스트는 해당 플래그가 켜졌을 때만.
Future<void> _generateTestFiles({
  required String pascalCase,
  required String snakeCase,
  required String camelCase,
  required bool withModel,
  required bool withViewModel,
  required bool withRepository,
}) async {
  final projectRoot = getProjectRoot();
  // 패키지명은 동적으로 — rename된 fork에서 import가 깨지지 않도록.
  final packageName = _readAppPackageName(projectRoot) ?? 'boilerplate';
  final testBase = path.join(projectRoot, 'app', 'test');

  final testFiles = <String, String>{};

  testFiles[path.join(testBase, 'widget', '${snakeCase}_view_test.dart')] =
      generateViewTestFile(
    pascalCase: pascalCase,
    snakeCase: snakeCase,
    camelCase: camelCase,
    packageName: packageName,
    withViewModel: withViewModel,
    withModel: withModel,
  );

  if (withModel) {
    testFiles[path.join(
            testBase, 'unit', 'models', '${snakeCase}_model_test.dart')] =
        generateModelTestFile(
      pascalCase: pascalCase,
      snakeCase: snakeCase,
      packageName: packageName,
    );
  }

  if (withViewModel) {
    testFiles[path.join(testBase, 'unit', 'view_models',
            '${snakeCase}_view_model_test.dart')] =
        generateViewModelTestFile(
      pascalCase: pascalCase,
      snakeCase: snakeCase,
      camelCase: camelCase,
      packageName: packageName,
      withModel: withModel,
    );
  }

  // Repository 테스트는 Model 기반(--full)일 때만 — Impl 스텁의 기본 동작을 덮는다.
  if (withRepository && withModel) {
    testFiles[path.join(testBase, 'unit', 'repositories',
            '${snakeCase}_repository_test.dart')] =
        generateRepositoryTestFile(
      pascalCase: pascalCase,
      snakeCase: snakeCase,
      packageName: packageName,
    );
  }

  for (final entry in testFiles.entries) {
    await _createDirectory(path.dirname(entry.key));
    await _writeFile(entry.key, entry.value);
    print('  Created: ${path.relative(entry.key, from: projectRoot)}');
  }
}

Future<void> _runBuild() async {
  // Find project root
  final projectRoot = _findProjectRoot();
  if (projectRoot == null) {
    print('Warning: Could not find project root. Skipping build.');
    return;
  }

  final buildScript = File(path.join(projectRoot, 'build'));
  if (!await buildScript.exists()) {
    print('Warning: ./build script not found. Skipping build.');
    return;
  }

  final result = await Process.run(
    './build',
    [],
    workingDirectory: projectRoot,
  );

  if (result.exitCode == 0) {
    print('✓ Code generation completed successfully!');
  } else {
    print('Warning: Code generation had issues:');
    print(result.stderr);
  }
}

Future<bool> _registerRoute({
  required String snakeCase,
  required String pascalCase,
}) async {
  final projectRoot = _findProjectRoot();
  if (projectRoot == null) {
    print('  Warning: Could not find project root. Skipping route registration.');
    return false;
  }

  final routerPath = path.join(projectRoot, 'app', 'lib', 'core', 'router.dart');
  final routerFile = File(routerPath);

  if (!await routerFile.exists()) {
    print('  Warning: router.dart not found. Skipping route registration.');
    return false;
  }

  var content = await routerFile.readAsString();

  // Check if route already exists
  if (content.contains("static const String $snakeCase = '/$snakeCase'")) {
    print('  Route /$snakeCase already exists in router.dart');
    return true;
  }

  // 1. Add import
  // 패키지명은 fork 후 ./init이 'boilerplate'에서 바꾸므로 하드코딩하면
  // rename된 프로젝트에서 앵커가 안 맞아 import가 누락된다 — app/pubspec.yaml의
  // name:을 동적으로 읽는다.
  final packageName = _readAppPackageName(projectRoot) ?? 'boilerplate';
  final importLine =
      "import 'package:$packageName/features/$snakeCase/index.dart';";

  // 앵커 폴백 체인: ① 같은 패키지의 features import → ② 임의 패키지의 features
  // import → ③ 임의 package: import. 마지막 import 뒤에 새 import를 삽입한다.
  final anchor = RegExp("import 'package:$packageName/features/[^']+';")
          .allMatches(content)
          .lastOrNull ??
      RegExp(r"import 'package:[a-zA-Z0-9_]+/features/[^']+';")
          .allMatches(content)
          .lastOrNull ??
      RegExp(r"import 'package:[^']+';").allMatches(content).lastOrNull;

  var importInserted = false;
  if (anchor != null) {
    final insertPos = anchor.end;
    content = '${content.substring(0, insertPos)}\n'
        '$importLine'
        '${content.substring(insertPos)}';
    importInserted = true;
  }

  // 2. Add Routes constant (before closing brace of Routes class)
  final routesClassEnd = RegExp(
    r"(static const String \w+ = '/\w+';\n)(})",
    multiLine: true,
  ).allMatches(content).lastOrNull;

  if (routesClassEnd != null) {
    final insertPos = routesClassEnd.start + routesClassEnd.group(0)!.indexOf('}');
    content = '${content.substring(0, insertPos)}'
        "  static const String $snakeCase = '/$snakeCase';\n"
        '${content.substring(insertPos)}';
  }

  // 3. Add RouteNames constant (before closing brace of RouteNames class)
  final routeNamesClassEnd = RegExp(
    r"(static const String \w+ = '\w+';\n)(})",
    multiLine: true,
  ).allMatches(content).lastOrNull;

  if (routeNamesClassEnd != null) {
    final insertPos = routeNamesClassEnd.start + routeNamesClassEnd.group(0)!.indexOf('}');
    content = '${content.substring(0, insertPos)}'
        "  static const String $snakeCase = '$pascalCase';\n"
        '${content.substring(insertPos)}';
  }

  // 4. Add GoRoute entry (before ShellRoute / main app shell)
  final shellRouteMatch = RegExp(
    r'(\n\s*// 메인 앱 Shell)',
  ).firstMatch(content);

  if (shellRouteMatch != null) {
    final insertPos = shellRouteMatch.start;
    final routeEntry = '''

      // $pascalCase 라우트
      GoRoute(
        name: RouteNames.$snakeCase,
        path: Routes.$snakeCase,
        pageBuilder: (context, state) => _logAndBuildPage(
          child: const ${pascalCase}View(),
          state: state,
        ),
      ),
''';
    content = '${content.substring(0, insertPos)}$routeEntry${content.substring(insertPos)}';
  }

  await routerFile.writeAsString(content);
  if (importInserted) {
    print('  ✓ Route /$snakeCase registered in router.dart');
  } else {
    // import 앵커를 못 찾았으면 라우트는 추가됐지만 View import가 빠져
    // 컴파일이 실패한다 — 거짓 성공을 내지 말고 수동 조치를 안내한다.
    print('  ⚠ Route /$snakeCase added, but the import could not be '
        'auto-inserted.');
    print('     Add this line to app/lib/core/router.dart manually:');
    print('       $importLine');
  }
  return importInserted;
}

/// app/lib의 패키지명을 app/pubspec.yaml의 `name:`에서 읽는다.
/// rename 후에도 라우트 import가 올바른 패키지를 가리키도록 하기 위함.
String? _readAppPackageName(String projectRoot) {
  final pubspec = File(path.join(projectRoot, 'app', 'pubspec.yaml'));
  if (!pubspec.existsSync()) return null;
  for (final line in pubspec.readAsLinesSync()) {
    final match = RegExp(r'^name:\s*(\S+)').firstMatch(line);
    if (match != null) return match.group(1);
  }
  return null;
}

String? _findProjectRoot() {
  var dir = Directory.current;

  while (dir.path != dir.parent.path) {
    final pubspec = File(path.join(dir.path, 'pubspec.yaml'));
    final buildScript = File(path.join(dir.path, 'build'));

    if (pubspec.existsSync() || buildScript.existsSync()) {
      // Check if this is the main project (has tools/ directory)
      final toolsDir = Directory(path.join(dir.path, 'tools'));
      if (toolsDir.existsSync()) {
        return dir.path;
      }
    }

    dir = dir.parent;
  }

  return null;
}
