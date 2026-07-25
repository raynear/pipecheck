import 'dart:io';

import 'package:args/args.dart';

import '../core/backup/backup_manager.dart';
import '../core/command.dart';
import '../core/error_handler.dart';
import '../core/logger/cli_logger.dart';
import '../core/progress/progress_indicator.dart';
import '../core/validators/naming_validator.dart';

/// 프로젝트 이름 변경 명령어.
///
/// 현재 식별자를 **실제 트리에서 읽어** (build.gradle/pbxproj/pubspec)
/// 새 식별자로 치환합니다 — com.example.* 같은 가정 없음 (P0-5).
///
/// ## 사용법
/// ```bash
/// ./run rename <새.번들.아이디> [options]
/// ./run rename com.acme.myapp --name "My App"
/// ```
///
/// ## 옵션
/// - `--name`: 앱 표시 이름 (strings.xml, Info.plist CFBundle*)
/// - `--dart-name`: Dart 패키지명 (기본: 번들 ID 마지막 세그먼트)
/// - `--force`, `-f`: 확인 없이 변경 (CI 필수)
/// - `--dry-run`: 시뮬레이션
///
/// ## 변경 대상
/// - pubspec.yaml name + lib/·test/·examples/ import + build.yaml 빌더 참조
/// - Android: build.gradle namespace/applicationId, Kotlin package 선언 +
///   디렉토리 재배치, AndroidManifest 리터럴
/// - iOS: project.pbxproj PRODUCT_BUNDLE_IDENTIFIER(.dev/.RunnerTests 포함),
///   Info.plist/entitlements의 번들 파생 값
/// - project.yaml package_name (+ --name 시 project.name) writeback
class RenameCommand extends Command {
  RenameCommand({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path;

  final String projectRoot;

  String get appDir => '$projectRoot/app';

  @override
  String get name => 'rename';

  @override
  String get description => '프로젝트 식별자(번들 ID/패키지명/표시 이름)를 변경합니다.\n\n'
      '현재 값은 build.gradle/pbxproj/pubspec에서 읽습니다 (가정 없음).\n'
      '사용법: ./run rename <새.번들.아이디> [--name "표시 이름"]';

  @override
  ArgParser buildArgParser() {
    return ArgParser()
      ..addOption('name', help: '앱 표시 이름 (예: "My App")')
      ..addOption('dart-name',
          help: 'Dart 패키지명 (기본: 번들 ID 마지막 세그먼트)')
      ..addFlag('force',
          abbr: 'f', negatable: false, help: '확인 없이 변경합니다.')
      ..addFlag('verbose',
          abbr: 'v', negatable: false, help: '자세한 실행 로그를 출력합니다.')
      ..addFlag('dry-run',
          negatable: false, help: '실제 변경 없이 시뮬레이션합니다.');
  }

  // ── 식별자 검증/유도 (테스트 가능하도록 static) ──

  /// 점 구분 번들 ID 검증 — 세그먼트 2개 이상, 각각 [a-z][a-z0-9_]*.
  static bool isValidBundleId(String id) {
    return RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$').hasMatch(id);
  }

  /// 번들 ID에서 기본 Dart 패키지명 유도 (마지막 세그먼트).
  static String defaultDartNameFor(String bundleId) {
    return bundleId.split('.').last;
  }

  /// build.gradle 내용에서 applicationId를 추출 (없으면 namespace 폴백).
  static String? extractAndroidApplicationId(String content) {
    final appId = RegExp(r'''applicationId\s*=?\s*["']([\w.]+)["']''')
        .firstMatch(content)
        ?.group(1);
    if (appId != null) return appId;
    return RegExp(r'''namespace\s*=?\s*["']([\w.]+)["']''')
        .firstMatch(content)
        ?.group(1);
  }

  /// pbxproj 내용에서 베이스 번들 ID 추출.
  ///
  /// PRODUCT_BUNDLE_IDENTIFIER 값들 중 다른 값들의 접두사가 되는
  /// 가장 짧은 값 (.dev/.RunnerTests 변형의 공통 베이스).
  static String? extractIosBaseBundleId(String content) {
    final ids = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*"?([\w.]+)"?;')
        .allMatches(content)
        .map((m) => m.group(1)!)
        .toSet()
        .toList()
      ..sort((a, b) => a.length.compareTo(b.length));
    if (ids.isEmpty) return null;
    return ids.first;
  }

  @override
  Future<int> execute(ArgResults args) async {
    final isForce = args['force'] as bool;
    final isVerbose = args['verbose'] as bool;
    final isDryRun = args['dry-run'] as bool;
    final displayName = args['name'] as String?;

    await CliLogger.init(verbose: isVerbose);

    if (args.rest.isEmpty) {
      throw CliException(
        '새 번들 ID를 입력하세요',
        solution: '사용법: ./run rename <새.번들.아이디> [--name "표시 이름"]\n'
            '예시: ./run rename com.acme.myapp --name "My App"',
      );
    }

    final newBundleId = args.rest.first;
    if (!isValidBundleId(newBundleId)) {
      throw CliException(
        '잘못된 번들 ID: $newBundleId',
        solution: '점으로 구분된 2개 이상의 세그먼트가 필요합니다 '
            '(각 세그먼트는 소문자로 시작, 소문자/숫자/_만). '
            '예: com.acme.myapp',
      );
    }

    final newDartName =
        (args['dart-name'] as String?) ?? defaultDartNameFor(newBundleId);
    final dartNameResult =
        NamingConventionValidator.validatePackageName(newDartName);
    if (!dartNameResult.isValid) {
      throw CliException(
        '잘못된 Dart 패키지명: $newDartName\n${dartNameResult.error}',
        solution: dartNameResult.suggestion ?? '--dart-name으로 직접 지정하세요.',
      );
    }

    // ── 현재 식별자를 트리에서 읽기 ──
    final currentDartName = await _readCurrentDartName();
    final currentAndroidId = await _readCurrentAndroidId();
    final currentIosId = await _readCurrentIosId() ?? currentAndroidId;

    if (isVerbose) {
      CliLogger.debug('현재: dart=$currentDartName android=$currentAndroidId '
          'ios=$currentIosId');
      CliLogger.debug('변경: dart=$newDartName bundle=$newBundleId');
    }

    final bundleChanged =
        currentAndroidId != newBundleId || currentIosId != newBundleId;
    final dartChanged = currentDartName != newDartName;

    if (!bundleChanged && !dartChanged && displayName == null) {
      print('');
      print('ℹ️  이미 적용된 식별자입니다: $newBundleId ($newDartName)');
      return 0;
    }

    print('');
    print('🔄 프로젝트 이름 변경');
    print('');
    print('   Dart 패키지: $currentDartName → $newDartName');
    print('   Android ID:  $currentAndroidId → $newBundleId');
    print('   iOS ID:      $currentIosId → $newBundleId');
    if (displayName != null) {
      print('   표시 이름:    $displayName');
    }
    print('');

    if (isDryRun) {
      print('ℹ️  --dry-run 모드입니다. 실제 변경은 수행되지 않았습니다.');
      return 0;
    }

    if (!isForce) {
      print('계속하시겠습니까? (y/N): ');
      final response = stdin.readLineSync()?.toLowerCase();
      if (response != 'y' && response != 'yes') {
        print('');
        print('취소되었습니다.');
        return 0;
      }
    }

    // ── 백업 ──
    final filesToBackup = await _collectFilesToBackup(currentDartName);
    final backupManager = BackupManager(projectRoot: projectRoot);
    final backupInfo = await backupManager.createBackup(
      filesToBackup,
      operationName: 'rename',
    );

    final steps = <String>[
      'pubspec.yaml 수정',
      'Dart 패키지 참조 수정',
      'Android 설정 수정',
      'iOS 설정 수정',
      if (displayName != null) '표시 이름 적용',
      'project.yaml writeback',
      'README.md 수정',
    ];
    final progress = StepProgress(steps: steps);

    try {
      progress.nextStep();
      await _updatePubspec(currentDartName, newDartName);
      progress.completeStep();

      progress.nextStep();
      final refCount = await _updateDartReferences(
          currentDartName, newDartName, isVerbose);
      progress.completeStep();
      if (isVerbose) {
        print('    ✓ $refCount개 파일의 패키지 참조 수정됨');
      }

      progress.nextStep();
      await _updateAndroid(currentAndroidId, newBundleId, isVerbose);
      progress.completeStep();

      progress.nextStep();
      await _updateIos(currentIosId, newBundleId, isVerbose);
      progress.completeStep();

      if (displayName != null) {
        progress.nextStep();
        await _updateDisplayName(displayName, isVerbose);
        progress.completeStep();
      }

      progress.nextStep();
      await _writebackProjectYaml(newBundleId, displayName, isVerbose);
      progress.completeStep();

      progress.nextStep();
      await _updateReadme(currentDartName, newDartName, isVerbose);
      progress.completeStep();

      _printSuccessMessage(
          currentDartName, newDartName, newBundleId, backupInfo.path);
      return 0;
    } catch (e) {
      print('');
      print('❌ 오류 발생. 백업에서 복원 중...');
      try {
        await backupManager.restore(backupInfo.id);
        print('✅ 복원 완료');
      } catch (restoreError) {
        print('⚠️  복원 실패: $restoreError');
        print('    수동 복원: ${backupInfo.path}');
      }
      rethrow;
    }
  }

  // ── 현재 값 읽기 ──

  Future<String> _readCurrentDartName() async {
    final pubspecFile = File('$appDir/pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      throw CliException(
        'pubspec.yaml을 찾을 수 없습니다',
        solution: '프로젝트 루트 디렉토리에서 실행하세요.',
      );
    }
    final match = RegExp(r'^name:\s*(\S+)', multiLine: true)
        .firstMatch(await pubspecFile.readAsString());
    if (match == null) {
      throw CliException(
        'pubspec.yaml에서 name 필드를 찾을 수 없습니다',
        solution: 'pubspec.yaml 파일 형식을 확인하세요.',
      );
    }
    return match.group(1)!;
  }

  Future<String> _readCurrentAndroidId() async {
    final file = File('$appDir/android/app/build.gradle');
    if (!file.existsSync()) {
      throw CliException(
        'android/app/build.gradle을 찾을 수 없습니다',
        solution: 'Android 플랫폼 디렉토리를 확인하세요.',
      );
    }
    final id = extractAndroidApplicationId(await file.readAsString());
    if (id == null) {
      throw CliException(
        'build.gradle에서 applicationId/namespace를 찾을 수 없습니다',
        solution: 'android/app/build.gradle의 defaultConfig를 확인하세요.',
      );
    }
    return id;
  }

  Future<String?> _readCurrentIosId() async {
    final file = File('$appDir/ios/Runner.xcodeproj/project.pbxproj');
    if (!file.existsSync()) return null;
    return extractIosBaseBundleId(await file.readAsString());
  }

  // ── 백업 대상 ──

  Future<List<String>> _collectFilesToBackup(String currentDartName) async {
    final files = <String>[
      '$appDir/pubspec.yaml',
      '$projectRoot/project.yaml',
    ];

    for (final file in await _findDartEcosystemFiles()) {
      final content = await file.readAsString();
      if (content.contains('package:$currentDartName/') ||
          content.contains('$currentDartName:table_generator')) {
        files.add(file.path);
      }
    }

    for (final path in [
      '$appDir/android/app/build.gradle',
      '$appDir/android/app/src/main/AndroidManifest.xml',
      '$appDir/ios/Runner.xcodeproj/project.pbxproj',
      '$appDir/ios/Runner/Info.plist',
      '$appDir/ios/Runner/Runner.entitlements',
      '$appDir/ios/widgetExtension.entitlements',
      '$appDir/lib/core/services/widget/home_widget_service.dart',
      '$projectRoot/README.md',
    ]) {
      if (File(path).existsSync()) files.add(path);
    }

    for (final file in await _findKotlinFiles()) {
      files.add(file.path);
    }

    for (final file in await _findStringsXmlFiles()) {
      files.add(file.path);
    }

    return files;
  }

  // ── 단계 구현 ──

  Future<void> _updatePubspec(String oldName, String newName) async {
    if (oldName == newName) return;
    final file = File('$appDir/pubspec.yaml');
    var content = await file.readAsString();
    content = content.replaceFirst(
      RegExp(r'^name:\s*' + RegExp.escape(oldName), multiLine: true),
      'name: $newName',
    );
    await file.writeAsString(content);
  }

  /// lib/·test/·examples/의 import와 build.yaml의 빌더 참조를 치환합니다.
  Future<int> _updateDartReferences(
      String oldName, String newName, bool isVerbose) async {
    if (oldName == newName) return 0;
    var count = 0;
    for (final file in await _findDartEcosystemFiles()) {
      var content = await file.readAsString();
      final original = content;
      content = content
          .replaceAll('package:$oldName/', 'package:$newName/')
          .replaceAll(
              '$oldName:table_generator', '$newName:table_generator');
      if (content != original) {
        await file.writeAsString(content);
        count++;
        if (isVerbose) {
          CliLogger.debug('  수정됨: ${file.path.replaceFirst('$appDir/', '')}');
        }
      }
    }
    return count;
  }

  Future<void> _updateAndroid(
      String oldId, String newId, bool isVerbose) async {
    if (oldId != newId) {
      // build.gradle — namespace/applicationId/suffix 베이스 전부 문자열 치환
      final buildGradle = File('$appDir/android/app/build.gradle');
      await _replaceInFile(buildGradle, oldId, newId);

      // AndroidManifest의 리터럴 참조 (있다면)
      final manifest =
          File('$appDir/android/app/src/main/AndroidManifest.xml');
      if (manifest.existsSync()) {
        await _replaceInFile(manifest, oldId, newId);
      }
    }

    // Kotlin: package 선언 기준으로 치환 + 디렉토리 재배치
    // (기존 트리는 디렉토리 경로와 package 선언이 불일치할 수 있음)
    final kotlinRoot = Directory('$appDir/android/app/src/main/kotlin');
    if (!kotlinRoot.existsSync()) return;

    for (final file in await _findKotlinFiles()) {
      var content = await file.readAsString();
      final pkgMatch =
          RegExp(r'^package\s+([\w.]+)', multiLine: true).firstMatch(content);
      if (pkgMatch == null) continue;

      final oldPkg = pkgMatch.group(1)!;
      final newPkg = oldPkg == oldId || oldPkg.startsWith('$oldId.')
          ? oldPkg.replaceFirst(oldId, newId)
          : oldPkg;

      content = content.replaceAll(oldId, newId);

      final targetDir = '${kotlinRoot.path}/${newPkg.replaceAll('.', '/')}';
      final targetPath = '$targetDir/${file.uri.pathSegments.last}';

      if (file.path == targetPath) {
        await file.writeAsString(content);
        continue;
      }

      Directory(targetDir).createSync(recursive: true);
      await File(targetPath).writeAsString(content);
      await file.delete();
      if (isVerbose) {
        CliLogger.debug('  이동: ${file.path} → $targetPath');
      }
    }

    _removeEmptyDirs(kotlinRoot);
    if (isVerbose) {
      print('    ✓ Android: $oldId → $newId');
    }
  }

  Future<void> _updateIos(String oldId, String newId, bool isVerbose) async {
    if (oldId == newId) return;
    for (final path in [
      '$appDir/ios/Runner.xcodeproj/project.pbxproj',
      '$appDir/ios/Runner/Info.plist',
      '$appDir/ios/Runner/Runner.entitlements',
      // App Group(`group.<번들ID>`) 3자 일치 유지 (INV-H1): 위젯 확장
      // entitlement + Dart 상수도 번들 ID를 함께 치환해야 rename 후
      // home_widget_app_group_contract_test가 초록으로 남는다.
      '$appDir/ios/widgetExtension.entitlements',
      '$appDir/lib/core/services/widget/home_widget_service.dart',
    ]) {
      final file = File(path);
      if (file.existsSync()) {
        await _replaceInFile(file, oldId, newId);
      }
    }
    if (isVerbose) {
      print('    ✓ iOS: $oldId → $newId');
    }
  }

  /// 표시 이름 적용 — strings.xml app_name + Info.plist CFBundle*.
  Future<void> _updateDisplayName(String displayName, bool isVerbose) async {
    // Android: 존재하는 strings.xml의 app_name 갱신, main에 없으면 생성
    // (Manifest android:label="@string/app_name"이 main 리소스를 요구)
    final mainStrings =
        File('$appDir/android/app/src/main/res/values/strings.xml');
    final stringsFiles = await _findStringsXmlFiles();
    final escaped = _escapeXml(displayName);

    var mainCovered = false;
    for (final file in stringsFiles) {
      var content = await file.readAsString();
      final pattern =
          RegExp(r'<string name="app_name">[^<]*</string>');
      if (pattern.hasMatch(content)) {
        content = content.replaceAll(
            pattern, '<string name="app_name">$escaped</string>');
        await file.writeAsString(content);
        if (file.path == mainStrings.path) mainCovered = true;
      }
    }
    if (!mainCovered) {
      mainStrings.createSync(recursive: true);
      await mainStrings.writeAsString('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$escaped</string>
</resources>
''');
    }

    // iOS: CFBundleDisplayName / CFBundleName
    final infoPlist = File('$appDir/ios/Runner/Info.plist');
    if (infoPlist.existsSync()) {
      var content = await infoPlist.readAsString();
      for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
        content = content.replaceFirst(
          RegExp('<key>$key</key>\\s*<string>[^<]*</string>'),
          '<key>$key</key>\n\t<string>$escaped</string>',
        );
      }
      await infoPlist.writeAsString(content);
    }

    if (isVerbose) {
      print('    ✓ 표시 이름: $displayName');
    }
  }

  /// project.yaml의 package_name(+name)을 트리와 일치시킵니다.
  Future<void> _writebackProjectYaml(
      String newBundleId, String? displayName, bool isVerbose) async {
    final file = File('$projectRoot/project.yaml');
    if (!file.existsSync()) return;

    var content = await file.readAsString();
    content = content.replaceFirstMapped(
      RegExp(r'^(\s*package_name:\s*)"?[\w.]+"?', multiLine: true),
      (m) => '${m.group(1)}"$newBundleId"',
    );
    if (displayName != null) {
      content = content.replaceFirstMapped(
        RegExp(r'^(\s*name:\s*).*$', multiLine: true),
        (m) => '${m.group(1)}"$displayName"',
      );
    }
    await file.writeAsString(content);

    if (isVerbose) {
      print('    ✓ project.yaml writeback');
    }
  }

  Future<void> _updateReadme(
      String oldName, String newName, bool isVerbose) async {
    if (oldName == newName) return;
    final readmeFile = File('$projectRoot/README.md');
    if (!readmeFile.existsSync()) return;

    var content = await readmeFile.readAsString();
    final original = content;
    content = content.replaceAll(oldName, newName);
    content =
        content.replaceAll(_toPascalCase(oldName), _toPascalCase(newName));
    if (content != original) {
      await readmeFile.writeAsString(content);
    }
  }

  // ── 파일 탐색/유틸 ──

  /// 패키지 참조를 담는 Dart 생태계 파일: lib/·test/·examples/의 .dart +
  /// build.yaml들. examples/는 복사용 레퍼런스 코드라 컴파일되진 않지만
  /// `package:<앱이름>/` import를 담으므로 rename에 동행해야
  /// 포크에서 복사-사용 가능하다 (P1-16c, 'boilerplate' 비의존화).
  Future<List<File>> _findDartEcosystemFiles() async {
    final files = <File>[];
    for (final dirPath in [
      '$appDir/lib',
      '$appDir/test',
      '$projectRoot/examples',
    ]) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File &&
            (entity.path.endsWith('.dart') ||
                entity.path.endsWith('build.yaml'))) {
          files.add(entity);
        }
      }
    }
    final rootBuildYaml = File('$appDir/build.yaml');
    if (rootBuildYaml.existsSync()) files.add(rootBuildYaml);
    return files;
  }

  Future<List<File>> _findKotlinFiles() async {
    final dir = Directory('$appDir/android/app/src/main/kotlin');
    if (!dir.existsSync()) return [];
    final files = <File>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.kt')) {
        files.add(entity);
      }
    }
    return files;
  }

  Future<List<File>> _findStringsXmlFiles() async {
    final dir = Directory('$appDir/android/app/src');
    if (!dir.existsSync()) return [];
    final files = <File>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('res/values/strings.xml')) {
        files.add(entity);
      }
    }
    return files;
  }

  Future<void> _replaceInFile(File file, String from, String to) async {
    final content = await file.readAsString();
    final updated = content.replaceAll(from, to);
    if (updated != content) {
      await file.writeAsString(updated);
    }
  }

  void _removeEmptyDirs(Directory root) {
    final dirs = root
        .listSync(recursive: true)
        .whereType<Directory>()
        .toList()
      ..sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final dir in dirs) {
      if (dir.existsSync() && dir.listSync().isEmpty) {
        dir.deleteSync();
      }
    }
  }

  String _escapeXml(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll("'", r"\'");

  String _toPascalCase(String input) {
    return input
        .split('_')
        .map((word) =>
            word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join();
  }

  void _printSuccessMessage(String oldDartName, String newDartName,
      String newBundleId, String backupPath) {
    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('  ✅ 프로젝트 이름이 변경되었습니다!');
    print('');
    print('     Dart:   $oldDartName → $newDartName');
    print('     Bundle: $newBundleId');
    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('  📌 다음 단계:');
    print('');
    print('  1. 변경 사항 확인: git diff');
    print('  2. 코드 재생성:   ./build');
    print('');
    print('  📁 백업 위치: $backupPath');
    print('');
  }
}
