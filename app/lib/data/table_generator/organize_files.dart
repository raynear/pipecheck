#!/usr/bin/env dart

import 'dart:io';

import 'package:path/path.dart' as p;

// CLI script - using stdout/stderr instead of print for linter compliance

/// 생성된 파일들을 원하는 폴더 구조로 정리하는 스크립트
///
/// build_runner의 제약으로 인해 파일들이 definitions 폴더에 생성되므로,
/// 이 스크립트로 파일들을 적절한 위치로 이동시킵니다.
///
/// 사용법:
/// ```bash
/// dart lib/data/table_generator/organize_files.dart
/// ```
///
/// 옵션:
/// ```bash
/// dart lib/data/table_generator/organize_files.dart --clean
/// ```
/// --clean 옵션: 기존 파일들을 삭제하고 새로 이동

void main(List<String> args) async {
  stdout.writeln('Table Generator File Organizer');
  stdout.writeln('==============================\n');

  final cleanMode = args.contains('--clean');
  if (cleanMode) {
    stdout.writeln('🧹 Clean mode enabled - 기존 파일들을 삭제합니다.\n');
  }

  final baseDir = Directory('lib/data');

  // 대상 디렉토리들
  final definitionsDir = Directory('${baseDir.path}/definitions');
  final generatedDir = Directory('${baseDir.path}/generated');

  // generated 디렉토리 생성
  if (!await generatedDir.exists()) {
    await generatedDir.create(recursive: true);
    stdout.writeln('📁 디렉토리 생성: ${generatedDir.path}');
  }

  if (!await definitionsDir.exists()) {
    stderr.writeln('❌ definitions 디렉토리를 찾을 수 없습니다.');
    return;
  }

  // 파일 이동
  final files = await definitionsDir.list().toList();
  var movedCount = 0;

  // 종류별 디렉토리 생성
  final modelsDir = Directory('${generatedDir.path}/models');
  final repositoriesDir = Directory('${generatedDir.path}/repositories');
  final driftDir = Directory('${generatedDir.path}/drift');

  for (final dir in [modelsDir, repositoriesDir, driftDir]) {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      stdout.writeln('📁 디렉토리 생성: ${p.relative(dir.path, from: 'lib/data')}');
    }
  }

  // 파일들을 종류별로 이동
  for (final file in files) {
    if (file is File) {
      final fileName = p.basename(file.path);

      String? targetPath;

      if (fileName.endsWith('.model.dart') ||
          fileName.endsWith('.model.freezed.dart') ||
          fileName.endsWith('.model.g.dart')) {
        // 모델 파일
        targetPath = '${modelsDir.path}/$fileName';
      } else if (fileName.endsWith('.repository.dart')) {
        // Repository 파일
        targetPath = '${repositoriesDir.path}/$fileName';
      } else if (fileName.endsWith('.drift.dart')) {
        // Drift 파일
        targetPath = '${driftDir.path}/$fileName';
      }

      if (targetPath != null) {
        await _moveFile(file, targetPath, cleanMode);
        movedCount++;
      }
    }
  }

  stdout.writeln('\n✨ 파일 정리 완료!');
  stdout.writeln('총 $movedCount개의 파일이 이동되었습니다.');

  // --clean 모드에서는 자동으로 빈 파일들도 정리
  if (cleanMode) {
    stdout.writeln('\n🧹 빈 파일들을 자동으로 정리합니다...');
    await _cleanupEmptyGeneratedFiles(definitionsDir);
  } else {
    // --clean 모드가 아닐 때만 사용자에게 묻기
    stdout.writeln('\n생성된 빈 파일들을 정리하시겠습니까? (y/n)');
    final response = stdin.readLineSync();
    if (response?.toLowerCase() == 'y') {
      await _cleanupEmptyGeneratedFiles(definitionsDir);
    }
  }
}

Future<void> _moveFile(File file, String targetPath, bool cleanMode) async {
  try {
    final targetFile = File(targetPath);

    // 대상 파일이 이미 존재하는 경우
    if (await targetFile.exists()) {
      if (!cleanMode) {
        stdout.writeln('⚠️  ${p.basename(targetPath)} 파일이 이미 존재합니다. 덮어쓰시겠습니까? (y/n)');
        final response = stdin.readLineSync();
        if (response?.toLowerCase() != 'y') {
          stdout.writeln('⏭️  건너뛰기: ${p.basename(file.path)}');
          return;
        }
      }
      await targetFile.delete();
    }

    // 파일 이동
    await file.copy(targetPath);
    await file.delete();
    stdout.writeln('✅ 이동 완료: ${p.basename(file.path)} → ${p.relative(targetPath, from: 'lib/data')}');
  } catch (e) {
    stderr.writeln('❌ 이동 실패: ${p.basename(file.path)} - $e');
  }
}

Future<void> _cleanupEmptyGeneratedFiles(Directory definitionsDir) async {
  final files = await definitionsDir.list().toList();
  var cleanedCount = 0;

  for (final file in files) {
    if (file is File) {
      final fileName = p.basename(file.path);

      // 생성된 파일들 중 빈 파일 삭제
      if ((fileName.endsWith('.model.dart') ||
              fileName.endsWith('.drift.dart') ||
              fileName.endsWith('.repository.dart')) &&
          !fileName.contains('example_product')) {
        final content = await file.readAsString();
        // 빈 파일이거나 기본 템플릿만 있는 경우
        if (content.length < 100) {
          await file.delete();
          cleanedCount++;
          stdout.writeln('🗑️  삭제: $fileName');
        }
      }
    }
  }

  stdout.writeln('총 $cleanedCount개의 빈 파일이 삭제되었습니다.');
}
