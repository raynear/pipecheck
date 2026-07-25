#!/usr/bin/env dart

import 'dart:io';

import 'table_name_util.dart';

/// 생성된 drift 파일들을 스캔하여 database.dart와 drift_database.dart를 자동 업데이트하는 스크립트
///
/// 사용법:
/// ```bash
/// dart lib/data/table_generator/sync_database.dart
/// ```
///
/// build.sh에서 자동 실행됨

void main() async {
  stdout.writeln('Database Table Sync');
  stdout.writeln('===================\n');

  // 패키지명은 pubspec.yaml에서 동적 로드 — 하드코딩 시 rename된 포크에서 sync가 조용히 no-op됨
  final packageName = _readPackageName();

  final driftDir = Directory('lib/data/generated/drift');
  final databaseFile = File('lib/data/datasources/local/database/database.dart');
  final driftDatabaseFile = File('lib/data/datasources/local/database/drift_database.dart');

  if (!await driftDir.exists()) {
    stdout.writeln('⚠️  No generated drift files found');
    return;
  }

  if (!await databaseFile.exists()) {
    stderr.writeln('❌ Error: database.dart not found');
    exit(1);
  }

  // 1. 생성된 drift 파일들 스캔
  final driftFiles = await driftDir
      .list()
      .where((e) => e is File && e.path.endsWith('.drift.dart'))
      .cast<File>()
      .toList();

  if (driftFiles.isEmpty) {
    stdout.writeln('⚠️  No drift files found in generated/drift/');
    return;
  }

  stdout.writeln('Found ${driftFiles.length} drift files:');

  // 테이블 정보 수집
  final tables = <TableInfo>[];

  for (final file in driftFiles) {
    final filename = file.path.split('/').last;

    // 실제 클래스 이름 확인 (파일 내용에서)
    // Table classes may have $ prefix (e.g., $Sessions)
    final content = await file.readAsString();
    final classMatch = RegExp(r'class (\$?\w+) extends Table').firstMatch(content);

    if (classMatch != null) {
      final actualClassName = classMatch.group(1)!;
      final importPath = 'package:$packageName/data/generated/drift/$filename';

      // 레지스트리 키 = drift 파일이 심은 `get tableName` 리터럴(소문자 정규화).
      // repository의 _tableName과 동일 문자열이고, _getTable이 tableName.toLowerCase()로
      // 조회하므로 이 키가 런타임 조회와 정확히 일치.
      final registryKey = registryKeyFromDriftSource(content);
      if (registryKey == null) {
        stderr.writeln(
            '  ⚠️  $actualClassName ($filename): tableName 리터럴을 찾지 못해 레지스트리 등록을 건너뜀');
        continue;
      }

      tables.add(TableInfo(
        fileName: filename,
        className: actualClassName,
        tableName: registryKey,
        importPath: importPath,
      ));

      stdout.writeln('  ✓ $actualClassName ($filename) → $registryKey');
    }
  }

  if (tables.isEmpty) {
    stdout.writeln('⚠️  No valid table classes found');
    return;
  }

  // 2. database.dart 업데이트 (추가 및 삭제)
  var content = await databaseFile.readAsString();
  var modified = false;

  // 현재 존재하는 테이블 클래스 이름 목록
  final validTableNames = tables.map((t) => t.className).toSet();
  final validImportPaths = tables.map((t) => t.importPath).toSet();

  // 2-1. 더 이상 존재하지 않는 import 제거
  final driftImportPattern = RegExp("import 'package:$packageName/data/generated/drift/([^']+\\.drift\\.dart)';\\n");
  final existingImports = driftImportPattern.allMatches(content).toList();

  for (final match in existingImports.reversed) {
    final importPath = 'package:$packageName/data/generated/drift/${match.group(1)}';
    if (!validImportPaths.contains(importPath)) {
      content = content.replaceFirst(match.group(0)!, '');
      modified = true;
      stdout.writeln('  ➖ Removed import: ${match.group(1)}');
    }
  }

  // 2-2. @DriftDatabase tables 목록 정리 (삭제된 테이블 제거 + 새 테이블 추가)
  final tablesPattern = RegExp(r'(@DriftDatabase\s*\(\s*tables:\s*\[)([^\]]*)\]', multiLine: true, dotAll: true);
  final tablesMatch = tablesPattern.firstMatch(content);

  if (tablesMatch != null) {
    final prefix = tablesMatch.group(1)!;
    final existingTables = tablesMatch.group(2)!.trim();

    // 기존 테이블 파싱
    final tableList = existingTables
        .split(',')
        .map((t) => t.replaceAll(RegExp(r'//.*'), '').trim()) // 주석 제거
        .where((t) => t.isNotEmpty && !t.startsWith('//'))
        .toList();

    // 삭제된 테이블 제거
    final removedTables = tableList.where((t) => !validTableNames.contains(t)).toList();
    for (final removed in removedTables) {
      stdout.writeln('  ➖ Removed table: $removed');
      modified = true;
    }

    // 유효한 테이블만 유지 + 새 테이블 추가
    final updatedList = tableList.where((t) => validTableNames.contains(t)).toList();
    for (final table in tables) {
      if (!updatedList.contains(table.className)) {
        updatedList.add(table.className);
        stdout.writeln('  ➕ Added table: ${table.className}');
        modified = true;
      }
    }

    // 정렬 및 업데이트
    updatedList.sort();
    final newTables = '\n    // Active tables with definitions in lib/data/definitions/\n    ${updatedList.join(',\n    ')},\n  ';
    content = content.replaceFirst(tablesPattern, '$prefix$newTables]');
  }

  // 2-3. 새 import 추가
  for (final table in tables) {
    if (!content.contains(table.importPath)) {
      // import 섹션 찾기 - drift import 뒤에 추가
      final importPattern = RegExp("(import 'package:$packageName/data/generated/drift/[^']+\\.dart';\\n)");
      final match = importPattern.firstMatch(content);

      if (match != null) {
        content = content.replaceFirst(match.group(0)!, "${match.group(0)}import '${table.importPath}';\n");
        modified = true;
        stdout.writeln('  ➕ Added import: ${table.className}');
      }
    }
  }

  if (modified) {
    await databaseFile.writeAsString(content);
    stdout.writeln('\n✅ database.dart updated successfully');
  } else {
    stdout.writeln('\n✓ database.dart is already up to date');
  }

  // 3. drift_database.dart의 _tableRegistry 업데이트
  await _syncDriftDatabase(driftDatabaseFile, tables);
}

/// drift_database.dart의 _tableRegistry를 업데이트 (추가 및 삭제)
Future<void> _syncDriftDatabase(File driftDatabaseFile, List<TableInfo> tables) async {
  if (!await driftDatabaseFile.exists()) {
    stderr.writeln('⚠️  drift_database.dart not found, skipping registry sync');
    return;
  }

  stdout.writeln('\nSyncing drift_database.dart registry...');

  var content = await driftDatabaseFile.readAsString();
  var modified = false;

  // _tableRegistry 패턴 찾기
  final registryPattern = RegExp(
    r'(_tableRegistry\s*=\s*\{)([^}]*)\}',
    multiLine: true,
    dotAll: true,
  );
  final registryMatch = registryPattern.firstMatch(content);

  if (registryMatch == null) {
    stderr.writeln('⚠️  Could not find _tableRegistry in drift_database.dart');
    return;
  }

  final prefix = registryMatch.group(1)!;
  final existingContent = registryMatch.group(2)!;

  // 현재 등록된 테이블 추출 (주석 제외)
  final existingEntries = <String, String>{};
  final entryPattern = RegExp(r"'(\w+)':\s*_db\.(\w+)");
  for (final match in entryPattern.allMatches(existingContent)) {
    existingEntries[match.group(1)!] = match.group(2)!;
  }

  // 유효한 테이블 이름 목록 생성 (권위 있는 리터럴 사용)
  final validTableNames = tables.map((t) => t.tableName).toSet();

  // 삭제된 테이블 제거
  final removedEntries = existingEntries.keys.where((k) => !validTableNames.contains(k)).toList();
  for (final removed in removedEntries) {
    existingEntries.remove(removed);
    stdout.writeln('  ➖ Removed registry: $removed');
    modified = true;
  }

  // 새 테이블 엔트리 추가
  for (final table in tables) {
    final tableName = table.tableName;
    // Use the actual class name (with $ prefix) as the accessor
    final accessorName = table.className;

    if (!existingEntries.containsKey(tableName)) {
      existingEntries[tableName] = accessorName;
      stdout.writeln('  ➕ Added registry: $tableName');
      modified = true;
    }
  }

  if (modified) {
    // 엔트리 목록 생성 및 정렬
    final allEntries = existingEntries.entries
        .map((e) => "'${e.key}': _db.${e.value}")
        .toList()
      ..sort();

    final newRegistry = '\n      ${allEntries.join(',\n      ')},\n    ';
    content = content.replaceFirst(registryPattern, '$prefix$newRegistry}');

    await driftDatabaseFile.writeAsString(content);
    stdout.writeln('✅ drift_database.dart registry updated');
  } else {
    stdout.writeln('✓ drift_database.dart registry is already up to date');
  }
}

/// pubspec.yaml에서 패키지명 읽기 (cwd = app/)
String _readPackageName() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('⚠️  pubspec.yaml not found — package name fallback: boilerplate');
    return 'boilerplate';
  }
  final match = RegExp(r'^name:\s*(\S+)', multiLine: true)
      .firstMatch(pubspec.readAsStringSync());
  return match?.group(1) ?? 'boilerplate';
}

class TableInfo {
  final String fileName;
  final String className;

  /// 레지스트리 조회 키 = drift `get tableName` 리터럴을 소문자화한 값
  /// (= repository `_tableName`을 통한 `_getTable`의 `toLowerCase()` 조회와 일치).
  final String tableName;
  final String importPath;

  TableInfo({
    required this.fileName,
    required this.className,
    required this.tableName,
    required this.importPath,
  });
}
