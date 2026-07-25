import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boilerplate/config/app_feature_config.dart';
import 'package:boilerplate/core/services/file_service.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:icloud_storage/icloud_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:utils/utils.dart';

Future<void> uploadFileToICloud(String filePath, String relativePath) async {
  // iCloud가 비활성화된 경우 조기 종료
  if (!AppFeatureConfig.isICloudEnabled) {
    logger.d('iCloud sync is disabled by feature flag');
    return;
  }

  try {
    final containerId = dotenv.env['CONTAINER_ID'] as String;
    await ICloudStorage.upload(
      containerId: containerId,
      filePath: filePath,
      destinationRelativePath: relativePath,
    );
    logger.i('Uploaded $filePath to iCloud');
  } catch (e) {
    logger.e('Error uploading $filePath to iCloud: $e');
  }
}

Future<void> downloadFileFromICloud(String destinationFilePath, String relativePath) async {
  // iCloud가 비활성화된 경우 조기 종료
  if (!AppFeatureConfig.isICloudEnabled) {
    logger.d('iCloud sync is disabled by feature flag');
    return;
  }

  try {
    final containerId = dotenv.env['CONTAINER_ID'] as String;
    await ICloudStorage.download(
      containerId: containerId,
      destinationFilePath: destinationFilePath,
      relativePath: relativePath,
    );
    logger.i('Downloaded $destinationFilePath from iCloud');
  } catch (e) {
    logger.e('Error downloading $destinationFilePath from iCloud: $e');
  }
}

Future<void> deleteFileFromICloud(String relativePath) async {
  // iCloud가 비활성화된 경우 조기 종료
  if (!AppFeatureConfig.isICloudEnabled) {
    logger.d('iCloud sync is disabled by feature flag');
    return;
  }

  try {
    logger.i('ICloud Delete: $relativePath');
    final containerId = dotenv.env['CONTAINER_ID'] as String;
    await ICloudStorage.delete(containerId: containerId, relativePath: relativePath);
    await _updateDeletedFilesList(relativePath);
  } catch (e) {
    logger.e('Error deleting $relativePath in iCloud: $e');
  }
}

Future<void> syncFilesWithICloud() async {
  // iCloud가 비활성화된 경우 조기 종료
  if (!AppFeatureConfig.isICloudEnabled) {
    logger.d('iCloud sync is disabled by feature flag');
    return;
  }

  try {
    final appDocDir = await getApplicationDocumentsDirectory();
    final List<FileSystemEntity> localFiles = [];
    await for (final file in appDocDir.list(recursive: true)) {
      if (file is File) {
        localFiles.add(file);
      }
    }
    final containerId = dotenv.env['CONTAINER_ID'] as String;

    final icloudFiles = await ICloudStorage.gather(containerId: containerId);
    final deletedFiles = await _getDeletedFilesList();

    final uploadTasks = <Future>[];
    final downloadTasks = <Future>[];

    for (var localFile in localFiles) {
      if (localFile is File) {
        final fileName = localFile.uri.pathSegments.last;
        final relativePath = await getRelativePath(localFile.path);
        final icloudFile = icloudFiles.firstWhereOrNull((f) => f.relativePath == relativePath);

        if (icloudFile != null) {
          final localFileDate = await localFile.lastModified();
          final icloudFileDate = icloudFile.contentChangeDate;

          if (localFileDate.isAfter(icloudFileDate)) {
            uploadTasks.add(uploadFileToICloud(localFile.path, relativePath));
          } else if (localFileDate.isBefore(icloudFileDate)) {
            final downloadPath = '${appDocDir.path}/$fileName';
            await createPath(downloadPath);
            downloadTasks.add(downloadFileFromICloud(downloadPath, relativePath));
          }
        } else if (!deletedFiles.contains(relativePath)) {
          uploadTasks.add(uploadFileToICloud(localFile.path, relativePath));
        }
      }
    }

    for (var icloudFile in icloudFiles) {
      final fileName = icloudFile.relativePath;
      final localFileExists = localFiles.any((file) => file.path.endsWith(fileName));

      if (!localFileExists && !deletedFiles.contains(fileName)) {
        final downloadPath = '${appDocDir.path}/$fileName';
        await createPath(downloadPath);
        downloadTasks.add(downloadFileFromICloud(downloadPath, fileName));
      }
    }

    await Future.wait([...uploadTasks, ...downloadTasks]);
  } catch (e) {
    logger.e('Error syncing with ICloud: $e');
  }
}

Future<void> moveToTrashFile(String sourceFile, String destinationFile) async {
  try {
    // 파일을 새 위치로 이동
    await moveFile(sourceFile, destinationFile);
    await _updateDeletedFilesList(sourceFile);
  } catch (e) {
    // 이동 중 에러가 발생한 경우
    logger.e('Error on move file: $e');
  }
}

Future<void> restoreFromTrashFile(String from, String to) async {
  // final relativePath = await getRelativePath(from);
  try {
    await moveFile(from, to);
    await _removeFromDeletedFilesList(from);
    // 파일 복원 로직 추가 (클라우드에서 로컬로 다운로드 등)
  } catch (e) {
    logger.e('Error restoring file: $e');
  }
}

Future<void> delete(String filePath) async {
  final relativePath = await getRelativePath(filePath);
  try {
    await deleteFile(filePath);
    await deleteFileFromICloud(relativePath);
  } catch (e) {
    logger.e('File Delete Error: $e');
  }
}

Future<List<String>> _getDeletedFilesList() async {
  try {
    final containerId = dotenv.env['CONTAINER_ID'] as String;
    final tempPath = '${Directory.systemTemp.path}/deleted_files.json';
    await ICloudStorage.download(
      containerId: containerId,
      destinationFilePath: tempPath,
      relativePath: 'deleted_files.json',
    );
    final file = File(tempPath);
    final content = await file.readAsString();
    return (json.decode(content) as List<dynamic>).cast<String>();
  } catch (e) {
    if (e is PlatformException && e.code == 'E_NAT') {
      logger.i('deleted_files.json does not exist. Returning empty list.');
      return [];
    } else {
      logger.e('Error fetching deleted files list: $e');
      return [];
    }
  }
}

Future<void> _updateDeletedFilesList(String deletedFileName) async {
  final deletedFiles = await _getDeletedFilesList();
  if (!deletedFiles.contains(deletedFileName)) {
    deletedFiles.add(deletedFileName);
    final file = File('${Directory.systemTemp.path}/deleted_files.json');
    await file.writeAsString(json.encode(deletedFiles));
    final containerId = dotenv.env['CONTAINER_ID'] as String;
    await ICloudStorage.upload(
      containerId: containerId,
      filePath: file.path,
      destinationRelativePath: 'deleted_files.json',
    );
  }
}

Future<void> _removeFromDeletedFilesList(String fileName) async {
  final deletedFiles = await _getDeletedFilesList();
  if (deletedFiles.contains(fileName)) {
    deletedFiles.remove(fileName);
    final file = File('${Directory.systemTemp.path}/deleted_files.json');
    await file.writeAsString(json.encode(deletedFiles));
    final containerId = dotenv.env['CONTAINER_ID'] as String;
    await ICloudStorage.upload(
      containerId: containerId,
      filePath: file.path,
      destinationRelativePath: 'deleted_files.json',
    );
  }
}
