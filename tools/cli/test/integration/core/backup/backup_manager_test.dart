import 'dart:io';

import 'package:test/test.dart';

/// 백업 관리 통합 테스트.
///
/// 실제 파일 시스템을 사용하여 BackupManager 동작을 테스트합니다.
void main() {
  final cliPath = Directory.current.path;

  group('Backup Manager Integration', () {
    group('BackupManager class', () {
      test('BackupManager class is exported', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  final manager = BackupManager(projectRoot: '/tmp/test');
  print('MANAGER_CREATED');
  print('PROJECT_ROOT: \${manager.projectRoot}');
  print('BACKUP_DIR: \${manager.backupBaseDir}');
}
''';
        final tempFile = File('$cliPath/test_backup_export_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('MANAGER_CREATED'));
          expect(result.stdout.toString(), contains('PROJECT_ROOT: /tmp/test'));
          expect(
              result.stdout.toString(),
              contains('BACKUP_DIR: /tmp/test/.boilerplate/backups'));
        } finally {
          tempFile.deleteSync();
        }
      });

      test('BackupInfo class is exported', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  final info = BackupInfo(
    id: 'test_id',
    timestamp: DateTime.now(),
    operationName: 'test_op',
    files: ['/path/to/file.dart'],
    path: '/path/to/backup',
  );
  print('INFO_CREATED');
  print('ID: \${info.id}');
  print('OPERATION: \${info.operationName}');
}
''';
        final tempFile = File('$cliPath/test_backup_info_export_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('INFO_CREATED'));
          expect(result.stdout.toString(), contains('ID: test_id'));
          expect(result.stdout.toString(), contains('OPERATION: test_op'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('backup and restore workflow', () {
      test('full backup and restore workflow works correctly', () async {
        final testScript = '''
import 'dart:io';
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  final tempDir = Directory.systemTemp.createTempSync('backup_integration_');

  try {
    final manager = BackupManager(projectRoot: tempDir.path);

    // 테스트 파일 생성
    final testFile = File('\${tempDir.path}/test.dart');
    testFile.writeAsStringSync('original content');
    print('ORIGINAL: \${testFile.readAsStringSync()}');

    // 백업 생성
    final backupInfo = await manager.createBackup(
      [testFile.path],
      operationName: 'integration_test',
    );
    print('BACKUP_CREATED: \${backupInfo.id}');
    print('BACKUP_FILES: \${backupInfo.files.length}');

    // 파일 수정
    testFile.writeAsStringSync('modified content');
    print('MODIFIED: \${testFile.readAsStringSync()}');

    // 복구
    await manager.restore(backupInfo.id);
    print('RESTORED: \${testFile.readAsStringSync()}');

    // 결과 확인
    if (testFile.readAsStringSync() == 'original content') {
      print('TEST_PASSED');
    } else {
      print('TEST_FAILED');
    }
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}
''';
        final tempFile = File('$cliPath/test_backup_workflow_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('ORIGINAL: original content'));
          expect(result.stdout.toString(), contains('BACKUP_CREATED:'));
          expect(result.stdout.toString(), contains('BACKUP_FILES: 1'));
          expect(result.stdout.toString(), contains('MODIFIED: modified content'));
          expect(result.stdout.toString(), contains('RESTORED: original content'));
          expect(result.stdout.toString(), contains('TEST_PASSED'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('listBackups', () {
      test('lists backups correctly', () async {
        final testScript = '''
import 'dart:io';
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  final tempDir = Directory.systemTemp.createTempSync('backup_list_test_');

  try {
    final manager = BackupManager(projectRoot: tempDir.path);

    // 파일 생성
    final file = File('\${tempDir.path}/test.dart');
    file.writeAsStringSync('content');

    // 여러 백업 생성
    await manager.createBackup([file.path], operationName: 'backup1');
    await Future.delayed(const Duration(milliseconds: 50));
    await manager.createBackup([file.path], operationName: 'backup2');

    // 목록 조회
    final backups = await manager.listBackups();
    print('BACKUP_COUNT: \${backups.length}');
    print('FIRST_OP: \${backups.first.operationName}');
    print('LAST_OP: \${backups.last.operationName}');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}
''';
        final tempFile = File('$cliPath/test_backup_list_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('BACKUP_COUNT: 2'));
          // 최신 순 정렬이므로 backup2가 먼저
          expect(result.stdout.toString(), contains('FIRST_OP: backup2'));
          expect(result.stdout.toString(), contains('LAST_OP: backup1'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('cleanOldBackups', () {
      test('cleans old backups correctly', () async {
        final testScript = '''
import 'dart:io';
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  final tempDir = Directory.systemTemp.createTempSync('backup_clean_test_');

  try {
    final manager = BackupManager(projectRoot: tempDir.path);

    // 파일 생성
    final file = File('\${tempDir.path}/test.dart');
    file.writeAsStringSync('content');

    // 백업 생성
    await manager.createBackup([file.path], operationName: 'to_clean');

    // 0일 보관으로 정리 (모두 삭제)
    final deletedCount = await manager.cleanOldBackups(retentionDays: 0);
    print('DELETED_COUNT: \$deletedCount');

    final remaining = await manager.listBackups();
    print('REMAINING_COUNT: \${remaining.length}');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}
''';
        final tempFile = File('$cliPath/test_backup_clean_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('DELETED_COUNT: 1'));
          expect(result.stdout.toString(), contains('REMAINING_COUNT: 0'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('error handling', () {
      test('throws CliException for non-existent backup restore', () async {
        final testScript = '''
import 'dart:io';
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() async {
  final tempDir = Directory.systemTemp.createTempSync('backup_error_test_');

  try {
    final manager = BackupManager(projectRoot: tempDir.path);

    await manager.restore('non_existent_backup');
    print('ERROR_NOT_THROWN');
  } on CliException catch (e) {
    print('CLI_EXCEPTION_THROWN');
    print('MESSAGE: \${e.message}');
    if (e.solution != null) {
      print('HAS_SOLUTION: true');
    }
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}
''';
        final tempFile = File('$cliPath/test_backup_error_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('CLI_EXCEPTION_THROWN'));
          expect(result.stdout.toString(), contains('백업을 찾을 수 없습니다'));
          expect(result.stdout.toString(), contains('HAS_SOLUTION: true'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });

    group('defaultRetentionDays', () {
      test('default retention is 7 days', () async {
        final testScript = '''
import 'package:boilerplate_cli/boilerplate_cli.dart';

void main() {
  print('DEFAULT_RETENTION: \${BackupManager.defaultRetentionDays}');
}
''';
        final tempFile = File('$cliPath/test_retention_temp.dart');
        tempFile.writeAsStringSync(testScript);

        try {
          final result = await Process.run(
            'dart',
            ['run', tempFile.path],
            workingDirectory: cliPath,
          );

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('DEFAULT_RETENTION: 7'));
        } finally {
          tempFile.deleteSync();
        }
      });
    });
  });
}
