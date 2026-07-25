import 'dart:io';

import '../error_handler.dart';

/// 백업 관리자.
///
/// 위험한 작업(이름 변경, 클린업) 실행 전 자동 백업을 생성하고
/// 문제 발생 시 복구를 지원합니다.
class BackupManager {
  /// 생성자.
  BackupManager({
    required this.projectRoot,
    String? backupBaseDir,
  }) : backupBaseDir = backupBaseDir ?? '$projectRoot/.boilerplate/backups';

  /// 프로젝트 루트 디렉토리.
  final String projectRoot;

  /// 백업 기본 디렉토리.
  final String backupBaseDir;

  /// 기본 백업 보관 기간 (일).
  static const int defaultRetentionDays = 7;

  /// 백업 생성.
  ///
  /// [filePaths] 백업할 파일 경로 목록.
  /// [operationName] 작업 이름 (백업 디렉토리 이름에 포함).
  /// 반환: 백업 ID (타임스탬프).
  Future<BackupInfo> createBackup(
    List<String> filePaths, {
    String? operationName,
  }) async {
    // 백업 ID 생성 (타임스탬프)
    final now = DateTime.now();
    final backupId = _formatTimestamp(now);
    final opName = operationName ?? 'backup';

    // 백업 디렉토리 생성
    final backupDirPath = '$backupBaseDir/${backupId}_$opName';
    final backupDir = Directory(backupDirPath);
    await backupDir.create(recursive: true);

    // 파일 백업
    final backedUpFiles = <String>[];
    for (final filePath in filePaths) {
      final file = File(filePath);
      if (await file.exists()) {
        // 상대 경로 계산
        final relativePath = _getRelativePath(filePath, projectRoot);
        final backupFilePath = '$backupDirPath/$relativePath';

        // 백업 파일 디렉토리 생성
        final backupFileDir = Directory(File(backupFilePath).parent.path);
        if (!await backupFileDir.exists()) {
          await backupFileDir.create(recursive: true);
        }

        // 파일 복사
        await file.copy(backupFilePath);
        backedUpFiles.add(filePath);
      }
    }

    // 메타데이터 저장
    final metadataFile = File('$backupDirPath/.backup_meta');
    await metadataFile.writeAsString([
      'timestamp=${now.toIso8601String()}',
      'operation=$opName',
      'project_root=$projectRoot',
      'files=${backedUpFiles.length}',
      ...backedUpFiles.map((f) => 'file=$f'),
    ].join('\n'));

    return BackupInfo(
      id: '${backupId}_$opName',
      timestamp: now,
      operationName: opName,
      files: backedUpFiles,
      path: backupDirPath,
    );
  }

  /// 백업에서 복구.
  ///
  /// [backupId] 복구할 백업 ID.
  Future<void> restore(String backupId) async {
    final backupDir = Directory('$backupBaseDir/$backupId');

    if (!await backupDir.exists()) {
      throw CliException(
        '백업을 찾을 수 없습니다: $backupId',
        solution: '사용 가능한 백업 목록을 확인하세요.',
      );
    }

    // 메타데이터 읽기
    final metadataFile = File('${backupDir.path}/.backup_meta');
    if (!await metadataFile.exists()) {
      throw CliException(
        '백업 메타데이터를 찾을 수 없습니다',
        solution: '백업 디렉토리가 손상되었을 수 있습니다.',
      );
    }

    final metadata = await _parseMetadata(metadataFile);
    final originalFiles = metadata['files'] ?? [];

    // 파일 복구
    for (final originalPath in originalFiles) {
      final relativePath = _getRelativePath(originalPath, projectRoot);
      final backupFilePath = '${backupDir.path}/$relativePath';
      final backupFile = File(backupFilePath);

      if (await backupFile.exists()) {
        // 원본 파일 디렉토리 생성
        final originalDir = Directory(File(originalPath).parent.path);
        if (!await originalDir.exists()) {
          await originalDir.create(recursive: true);
        }

        // 파일 복구
        await backupFile.copy(originalPath);
      }
    }
  }

  /// 오래된 백업 정리.
  ///
  /// [retentionDays] 보관 기간 (일). 기본값: 7일.
  /// 반환: 삭제된 백업 수.
  Future<int> cleanOldBackups({int retentionDays = defaultRetentionDays}) async {
    final backupBaseDirectory = Directory(backupBaseDir);
    if (!await backupBaseDirectory.exists()) {
      return 0;
    }

    final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
    var deletedCount = 0;

    await for (final entity in backupBaseDirectory.list()) {
      if (entity is Directory) {
        final backupInfo = await _getBackupInfo(entity);
        if (backupInfo != null && backupInfo.timestamp.isBefore(cutoffDate)) {
          await entity.delete(recursive: true);
          deletedCount++;
        }
      }
    }

    return deletedCount;
  }

  /// 사용 가능한 백업 목록 반환.
  Future<List<BackupInfo>> listBackups() async {
    final backupBaseDirectory = Directory(backupBaseDir);
    if (!await backupBaseDirectory.exists()) {
      return [];
    }

    final backups = <BackupInfo>[];

    await for (final entity in backupBaseDirectory.list()) {
      if (entity is Directory) {
        final backupInfo = await _getBackupInfo(entity);
        if (backupInfo != null) {
          backups.add(backupInfo);
        }
      }
    }

    // 최신 순 정렬
    backups.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return backups;
  }

  /// 특정 백업 존재 여부 확인.
  Future<bool> backupExists(String backupId) async {
    final backupDir = Directory('$backupBaseDir/$backupId');
    return backupDir.exists();
  }

  /// 특정 백업 삭제.
  Future<void> deleteBackup(String backupId) async {
    final backupDir = Directory('$backupBaseDir/$backupId');
    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
    }
  }

  /// 백업 정보 가져오기.
  Future<BackupInfo?> _getBackupInfo(Directory backupDir) async {
    final metadataFile = File('${backupDir.path}/.backup_meta');
    if (!await metadataFile.exists()) {
      return null;
    }

    try {
      final metadata = await _parseMetadata(metadataFile);
      final timestampStr = metadata['timestamp'];
      final timestamp =
          timestampStr != null ? DateTime.parse(timestampStr) : DateTime.now();

      return BackupInfo(
        id: backupDir.path.split('/').last,
        timestamp: timestamp,
        operationName: metadata['operation'] ?? 'unknown',
        files: metadata['files'] ?? [],
        path: backupDir.path,
      );
    } catch (_) {
      return null;
    }
  }

  /// 메타데이터 파싱.
  Future<Map<String, dynamic>> _parseMetadata(File metadataFile) async {
    final content = await metadataFile.readAsString();
    final lines = content.split('\n');

    final result = <String, dynamic>{
      'files': <String>[],
    };

    for (final line in lines) {
      if (line.startsWith('timestamp=')) {
        result['timestamp'] = line.substring('timestamp='.length);
      } else if (line.startsWith('operation=')) {
        result['operation'] = line.substring('operation='.length);
      } else if (line.startsWith('project_root=')) {
        result['project_root'] = line.substring('project_root='.length);
      } else if (line.startsWith('file=')) {
        (result['files'] as List<String>).add(line.substring('file='.length));
      }
    }

    return result;
  }

  /// 상대 경로 계산.
  String _getRelativePath(String filePath, String basePath) {
    if (filePath.startsWith(basePath)) {
      var relative = filePath.substring(basePath.length);
      if (relative.startsWith('/')) {
        relative = relative.substring(1);
      }
      return relative;
    }
    return filePath;
  }

  /// 타임스탬프 포맷팅.
  String _formatTimestamp(DateTime dt) {
    return '${dt.year}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}'
        '_'
        '${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}

/// 백업 정보.
class BackupInfo {
  /// 생성자.
  BackupInfo({
    required this.id,
    required this.timestamp,
    required this.operationName,
    required this.files,
    required this.path,
  });

  /// 백업 ID.
  final String id;

  /// 백업 시간.
  final DateTime timestamp;

  /// 작업 이름.
  final String operationName;

  /// 백업된 파일 목록.
  final List<String> files;

  /// 백업 디렉토리 경로.
  final String path;

  @override
  String toString() {
    return 'BackupInfo(id: $id, timestamp: $timestamp, '
        'operation: $operationName, files: ${files.length})';
  }
}
