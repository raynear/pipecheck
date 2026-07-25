import 'dart:io';

import 'package:boilerplate_cli/boilerplate_cli.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late BackupManager backupManager;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('backup_test_');
    backupManager = BackupManager(projectRoot: tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('BackupManager', () {
    group('constructor', () {
      test('creates with default backup directory', () {
        final manager = BackupManager(projectRoot: '/tmp/test');

        expect(manager.projectRoot, equals('/tmp/test'));
        expect(manager.backupBaseDir, equals('/tmp/test/.boilerplate/backups'));
      });

      test('creates with custom backup directory', () {
        final manager = BackupManager(
          projectRoot: '/tmp/test',
          backupBaseDir: '/tmp/custom_backups',
        );

        expect(manager.backupBaseDir, equals('/tmp/custom_backups'));
      });
    });

    group('createBackup', () {
      test('creates backup of single file', () async {
        // 테스트 파일 생성
        final testFile = File('${tempDir.path}/test.dart');
        testFile.writeAsStringSync('void main() {}');

        final backupInfo = await backupManager.createBackup(
          [testFile.path],
          operationName: 'test_operation',
        );

        expect(backupInfo.operationName, equals('test_operation'));
        expect(backupInfo.files, hasLength(1));
        expect(backupInfo.files.first, equals(testFile.path));
        expect(Directory(backupInfo.path).existsSync(), isTrue);
      });

      test('creates backup of multiple files', () async {
        // 테스트 파일들 생성
        final file1 = File('${tempDir.path}/file1.dart')
          ..writeAsStringSync('// file1');
        final file2 = File('${tempDir.path}/file2.dart')
          ..writeAsStringSync('// file2');

        final backupInfo = await backupManager.createBackup(
          [file1.path, file2.path],
          operationName: 'multi_backup',
        );

        expect(backupInfo.files, hasLength(2));
        expect(Directory(backupInfo.path).existsSync(), isTrue);

        // 백업된 파일 확인
        final backupFile1 = File('${backupInfo.path}/file1.dart');
        final backupFile2 = File('${backupInfo.path}/file2.dart');
        expect(backupFile1.existsSync(), isTrue);
        expect(backupFile2.existsSync(), isTrue);
      });

      test('creates backup with nested directory structure', () async {
        // 중첩 디렉토리 구조 생성
        final nestedDir = Directory('${tempDir.path}/src/lib');
        nestedDir.createSync(recursive: true);
        final nestedFile = File('${nestedDir.path}/nested.dart')
          ..writeAsStringSync('// nested');

        final backupInfo = await backupManager.createBackup(
          [nestedFile.path],
          operationName: 'nested_backup',
        );

        expect(backupInfo.files, hasLength(1));
        final backupFile = File('${backupInfo.path}/src/lib/nested.dart');
        expect(backupFile.existsSync(), isTrue);
      });

      test('skips non-existent files', () async {
        final existingFile = File('${tempDir.path}/exists.dart')
          ..writeAsStringSync('// exists');
        final nonExistentPath = '${tempDir.path}/not_exists.dart';

        final backupInfo = await backupManager.createBackup(
          [existingFile.path, nonExistentPath],
          operationName: 'partial_backup',
        );

        expect(backupInfo.files, hasLength(1));
        expect(backupInfo.files.first, equals(existingFile.path));
      });

      test('uses default operation name when not specified', () async {
        final testFile = File('${tempDir.path}/test.dart')
          ..writeAsStringSync('// test');

        final backupInfo = await backupManager.createBackup([testFile.path]);

        expect(backupInfo.operationName, equals('backup'));
      });

      test('creates metadata file', () async {
        final testFile = File('${tempDir.path}/test.dart')
          ..writeAsStringSync('// test');

        final backupInfo = await backupManager.createBackup(
          [testFile.path],
          operationName: 'meta_test',
        );

        final metaFile = File('${backupInfo.path}/.backup_meta');
        expect(metaFile.existsSync(), isTrue);

        final metaContent = metaFile.readAsStringSync();
        expect(metaContent, contains('operation=meta_test'));
        expect(metaContent, contains('file='));
      });
    });

    group('restore', () {
      test('restores single file from backup', () async {
        // 원본 파일 생성 및 백업
        final testFile = File('${tempDir.path}/restore_test.dart')
          ..writeAsStringSync('original content');

        final backupInfo = await backupManager.createBackup(
          [testFile.path],
          operationName: 'restore_test',
        );

        // 원본 파일 수정
        testFile.writeAsStringSync('modified content');
        expect(testFile.readAsStringSync(), equals('modified content'));

        // 복구
        await backupManager.restore(backupInfo.id);

        // 복구 확인
        expect(testFile.readAsStringSync(), equals('original content'));
      });

      test('restores multiple files from backup', () async {
        final file1 = File('${tempDir.path}/file1.dart')
          ..writeAsStringSync('content1');
        final file2 = File('${tempDir.path}/file2.dart')
          ..writeAsStringSync('content2');

        final backupInfo = await backupManager.createBackup(
          [file1.path, file2.path],
          operationName: 'multi_restore',
        );

        // 파일들 수정
        file1.writeAsStringSync('modified1');
        file2.writeAsStringSync('modified2');

        // 복구
        await backupManager.restore(backupInfo.id);

        // 확인
        expect(file1.readAsStringSync(), equals('content1'));
        expect(file2.readAsStringSync(), equals('content2'));
      });

      test('creates parent directories if needed during restore', () async {
        final nestedDir = Directory('${tempDir.path}/deep/nested');
        nestedDir.createSync(recursive: true);
        final nestedFile = File('${nestedDir.path}/file.dart')
          ..writeAsStringSync('nested content');

        final backupInfo = await backupManager.createBackup(
          [nestedFile.path],
          operationName: 'nested_restore',
        );

        // 원본 디렉토리 삭제
        Directory('${tempDir.path}/deep').deleteSync(recursive: true);
        expect(nestedFile.existsSync(), isFalse);

        // 복구
        await backupManager.restore(backupInfo.id);

        // 확인
        expect(nestedFile.existsSync(), isTrue);
        expect(nestedFile.readAsStringSync(), equals('nested content'));
      });

      test('throws CliException for non-existent backup', () async {
        expect(
          () => backupManager.restore('non_existent_backup'),
          throwsA(isA<CliException>()),
        );
      });
    });

    group('listBackups', () {
      test('returns empty list when no backups exist', () async {
        final backups = await backupManager.listBackups();
        expect(backups, isEmpty);
      });

      test('returns list of backups sorted by timestamp (newest first)', () async {
        final file = File('${tempDir.path}/test.dart')
          ..writeAsStringSync('test');

        await backupManager.createBackup([file.path], operationName: 'first');
        await Future.delayed(const Duration(milliseconds: 100));
        await backupManager.createBackup([file.path], operationName: 'second');
        await Future.delayed(const Duration(milliseconds: 100));
        await backupManager.createBackup([file.path], operationName: 'third');

        final backups = await backupManager.listBackups();

        expect(backups, hasLength(3));
        expect(backups[0].operationName, equals('third'));
        expect(backups[1].operationName, equals('second'));
        expect(backups[2].operationName, equals('first'));
      });
    });

    group('backupExists', () {
      test('returns true for existing backup', () async {
        final file = File('${tempDir.path}/test.dart')
          ..writeAsStringSync('test');

        final backupInfo = await backupManager.createBackup([file.path]);

        expect(await backupManager.backupExists(backupInfo.id), isTrue);
      });

      test('returns false for non-existent backup', () async {
        expect(await backupManager.backupExists('fake_backup'), isFalse);
      });
    });

    group('deleteBackup', () {
      test('deletes existing backup', () async {
        final file = File('${tempDir.path}/test.dart')
          ..writeAsStringSync('test');

        final backupInfo = await backupManager.createBackup([file.path]);
        expect(await backupManager.backupExists(backupInfo.id), isTrue);

        await backupManager.deleteBackup(backupInfo.id);
        expect(await backupManager.backupExists(backupInfo.id), isFalse);
      });

      test('does nothing for non-existent backup', () async {
        // Should not throw
        await backupManager.deleteBackup('non_existent');
      });
    });

    group('cleanOldBackups', () {
      test('returns 0 when no backups directory exists', () async {
        final deletedCount = await backupManager.cleanOldBackups();
        expect(deletedCount, equals(0));
      });

      test('deletes backups older than retention period', () async {
        final file = File('${tempDir.path}/test.dart')
          ..writeAsStringSync('test');

        // 백업 생성
        await backupManager.createBackup([file.path], operationName: 'old');

        // 0일 보관 기간으로 정리 (모든 백업 삭제)
        final deletedCount = await backupManager.cleanOldBackups(retentionDays: 0);

        expect(deletedCount, equals(1));
        final backups = await backupManager.listBackups();
        expect(backups, isEmpty);
      });

      test('keeps backups within retention period', () async {
        final file = File('${tempDir.path}/test.dart')
          ..writeAsStringSync('test');

        await backupManager.createBackup([file.path], operationName: 'recent');

        // 7일 보관 기간으로 정리
        final deletedCount = await backupManager.cleanOldBackups(retentionDays: 7);

        expect(deletedCount, equals(0));
        final backups = await backupManager.listBackups();
        expect(backups, hasLength(1));
      });
    });

    group('defaultRetentionDays', () {
      test('is 7 days', () {
        expect(BackupManager.defaultRetentionDays, equals(7));
      });
    });
  });

  group('BackupInfo', () {
    test('toString returns readable format', () {
      final info = BackupInfo(
        id: 'test_id',
        timestamp: DateTime(2026, 1, 6, 12, 0, 0),
        operationName: 'test_op',
        files: ['/path/to/file1.dart', '/path/to/file2.dart'],
        path: '/path/to/backup',
      );

      final str = info.toString();
      expect(str, contains('id: test_id'));
      expect(str, contains('operation: test_op'));
      expect(str, contains('files: 2'));
    });

    test('stores all properties correctly', () {
      final timestamp = DateTime.now();
      final info = BackupInfo(
        id: 'backup_123',
        timestamp: timestamp,
        operationName: 'rename',
        files: ['/a.dart', '/b.dart'],
        path: '/backups/backup_123',
      );

      expect(info.id, equals('backup_123'));
      expect(info.timestamp, equals(timestamp));
      expect(info.operationName, equals('rename'));
      expect(info.files, hasLength(2));
      expect(info.path, equals('/backups/backup_123'));
    });
  });
}
