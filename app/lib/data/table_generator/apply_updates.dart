#!/usr/bin/env dart

import 'dart:io';

/// Table Generator가 생성한 업데이트를 실제 파일에 적용하는 스크립트
///
/// 사용법:
/// ```bash
/// dart lib/data/table_generator/apply_updates.dart
/// ```

void main() async {
  stdout.writeln('Table Generator Update Applier');
  stdout.writeln('==============================\n');

  // 업데이트 파일 경로
  final databaseUpdatesFile = File('lib/data/.database_updates.txt');
  final providerUpdatesFile = File('lib/data/.provider_updates.txt');

  // database.dart 업데이트 처리
  if (await databaseUpdatesFile.exists()) {
    stdout.writeln('Found database updates...');
    final updates = await databaseUpdatesFile.readAsString();

    if (updates.isNotEmpty) {
      stdout.writeln('\nDatabase updates to apply:');
      stdout.writeln(updates);

      stdout.writeln('\nWould you like to apply these updates to database.dart? (y/n)');
      final response = stdin.readLineSync();

      if (response?.toLowerCase() == 'y') {
        await _applyDatabaseUpdates(updates);

        // 업데이트 파일 비우기
        await databaseUpdatesFile.writeAsString('');
        stdout.writeln('✅ Database updates applied successfully');
      } else {
        stdout.writeln('⏭️  Skipped database updates');
      }
    }
  }

  // repository_providers.dart 업데이트 처리
  if (await providerUpdatesFile.exists()) {
    stdout.writeln('\nFound provider updates...');
    final updates = await providerUpdatesFile.readAsString();

    if (updates.isNotEmpty) {
      stdout.writeln('\nProvider updates to apply:');
      stdout.writeln(updates);

      stdout.writeln('\nWould you like to apply these updates to repository_providers.dart? (y/n)');
      final response = stdin.readLineSync();

      if (response?.toLowerCase() == 'y') {
        await _applyProviderUpdates(updates);

        // 업데이트 파일 비우기
        await providerUpdatesFile.writeAsString('');
        stdout.writeln('✅ Provider updates applied successfully');
      } else {
        stdout.writeln('⏭️  Skipped provider updates');
      }
    }
  }

  stdout.writeln('\n✨ Update process completed!');
}

Future<void> _applyDatabaseUpdates(String updates) async {
  final databaseFile = File('lib/data/datasources/local/database/database.dart');

  if (!await databaseFile.exists()) {
    stderr.writeln('❌ Error: database.dart not found');
    return;
  }

  var content = await databaseFile.readAsString();

  // 각 업데이트 항목 파싱
  final updateEntries = updates.split('---\n').where((e) => e.trim().isNotEmpty);

  for (final entry in updateEntries) {
    final lines = entry.trim().split('\n');
    String? tableName;
    String? importStatement;

    for (final line in lines) {
      if (line.startsWith('Table:')) {
        tableName = line.substring(7).trim();
      } else if (line.startsWith('Import:')) {
        importStatement = line.substring(8).trim();
      }
    }

    if (tableName != null && importStatement != null) {
      // 이미 존재하는지 확인
      if (content.contains(tableName)) {
        stdout.writeln('⚠️  Table $tableName already exists, skipping...');
        continue;
      }

      // import 추가
      if (!content.contains(importStatement)) {
        final importPattern = RegExp(r'(import .+;\n)+');
        final importMatch = importPattern.firstMatch(content);

        if (importMatch != null) {
          final lastImportEnd = importMatch.end;
          content = '${content.substring(0, lastImportEnd)}$importStatement\n${content.substring(lastImportEnd)}';
        }
      }

      // 테이블 추가
      final driftDbPattern = RegExp(r'(@DriftDatabase\s*\(\s*tables:\s*\[)([^\]]*)\]', multiLine: true, dotAll: true);
      final match = driftDbPattern.firstMatch(content);

      if (match != null) {
        final prefix = match.group(1)!;
        final existingTables = match.group(2)!;

        // 테이블 목록 정리 및 새 테이블 추가
        final tableList = existingTables.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

        tableList.add(tableName);

        final updatedTables = tableList.join(', ');

        content = content.replaceFirst(
          driftDbPattern,
          '$prefix$updatedTables]',
        );

        stdout.writeln('✅ Added table: $tableName');
      }
    }
  }

  // 파일 저장
  await databaseFile.writeAsString(content);
}

Future<void> _applyProviderUpdates(String updates) async {
  final providersFile = File('lib/data/core/repositories/repository_providers.dart');

  if (!await providersFile.exists()) {
    stderr.writeln('❌ Error: repository_providers.dart not found');
    return;
  }

  var content = await providersFile.readAsString();

  // 각 업데이트 항목 파싱
  final updateEntries = updates.split('---\n').where((e) => e.trim().isNotEmpty);

  for (final entry in updateEntries) {
    final lines = entry.trim().split('\n');
    String? providerName;
    String? importStatement;
    String? providerCode;

    bool inCode = false;
    final codeLines = <String>[];

    for (final line in lines) {
      if (line.startsWith('Provider:')) {
        providerName = line.substring(9).trim();
      } else if (line.startsWith('Import:')) {
        importStatement = line.substring(8).trim();
      } else if (line == 'Code:') {
        inCode = true;
      } else if (inCode && !line.startsWith('Generated at:')) {
        codeLines.add(line);
      }
    }

    if (providerName != null && importStatement != null && codeLines.isNotEmpty) {
      providerCode = codeLines.join('\n');

      // 이미 존재하는지 확인
      if (content.contains(providerName)) {
        stdout.writeln('⚠️  Provider $providerName already exists, skipping...');
        continue;
      }

      // import 추가
      if (!content.contains(importStatement)) {
        // repository import들 뒤에 추가
        final repositoryImportPattern = RegExp(r"(import .+repositories/.+\.dart';\n)+");
        final match = repositoryImportPattern.firstMatch(content);

        if (match != null) {
          final lastImportEnd = match.end;
          content = '${content.substring(0, lastImportEnd)}$importStatement\n${content.substring(lastImportEnd)}';
        } else {
          // repository import가 없으면 일반 import 뒤에 추가
          final importPattern = RegExp(r'(import .+;\n)+');
          final importMatch = importPattern.firstMatch(content);

          if (importMatch != null) {
            final lastImportEnd = importMatch.end;
            content = '${content.substring(0, lastImportEnd)}$importStatement\n${content.substring(lastImportEnd)}';
          }
        }
      }

      // Provider 코드 추가 (파일 끝 부분에)
      // dataSourceInitializerProvider 앞에 추가하는 것이 좋음
      final initProviderPattern = RegExp(r'(/// 초기화 Provider)');
      final match = initProviderPattern.firstMatch(content);

      if (match != null) {
        final insertPosition = match.start;
        content = '${content.substring(0, insertPosition)}$providerCode\n\n${content.substring(insertPosition)}';
      } else {
        // 찾을 수 없으면 파일 끝에 추가
        content = '${content.trimRight()}\n\n$providerCode\n';
      }

      stdout.writeln('✅ Added provider: $providerName');
    }
  }

  // 파일 저장
  await providersFile.writeAsString(content);
}
