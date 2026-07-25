import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/services/icloud_service.dart';
import 'package:pipecheck/core/services/snackbar_service.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:utils/utils.dart';
import 'package:uuid/uuid.dart';

Future<String> saveFile(File file, String prefix) async {
  final uuid = const Uuid().v4();
  final docPath = await getApplicationDocumentsDirectory();
  final extension = file.path.split('.').last;
  final fileName = '$prefix-$uuid.$extension';
  final newPath = '${docPath.path}/$fileName';
  await file.copy(newPath);
  return fileName;
}

String trimSlashes(String input) {
  // Remove leading slashes
  String result = input.replaceFirst(RegExp(r'^/+'), '');

  // Remove trailing slashes
  result = result.replaceFirst(RegExp(r'/+$'), '');

  return result;
}

String sanitizeFileName(String input) {
  // 파일 이름에서 유효하지 않거나 위험한 문자를 제거
  final invalidCharsPattern = RegExp(r'[^a-zA-Z0-9_.-]');
  return input.replaceAll(invalidCharsPattern, '_');
}

Future<void> createPath(String path) async {
  var directoryPaths = path.split('/');
  if (directoryPaths.last.contains('.')) {
    directoryPaths.removeLast();
  }
  final Directory appDocDirFolder = Directory('${directoryPaths.join('/')}/');

  try {
    if (!appDocDirFolder.existsSync()) await appDocDirFolder.create(recursive: true);
  } catch (e) {
    logger.e('Error create path $path: $e');
  }
}

// except appDocDir
Future<File> localFile(String fileName) async {
  Directory appDocDir = await getApplicationDocumentsDirectory();

  final localPath = p.join(appDocDir.path, fileName);

  await createPath(localPath);
  return File(localPath);
}

Future<void> writeFile(String fileName, String content) async {
  try {
    final file = await localFile(fileName);
    logger.d('write ${file.path}');
    await file.writeAsString(content);
    return;
  } catch (e) {
    logger.e('Error writing file $fileName: $e');
    return;
  }
}

Future<String> readFile(String fileName) async {
  try {
    final file = await localFile(fileName);
    logger.d('read ${file.path}');
    String data = await file.readAsString();
    return data;
  } catch (e) {
    logger.e('Failed to read file $fileName: $e');
    throw FileSystemException('Failed to read file: $fileName', e.toString());
  }
}

Future<void> deleteFile(String? path) async {
  if (path == null) return;
  try {
    final file = path.contains('/') ? File(path) : await localFile(path);
    logger.d('delete ${file.path}');
    if (await file.exists()) {
      await file.delete();
    }
  } catch (e) {
    logger.e('Error deleting file $path: $e');
  }
}

Future<void> moveFile(String sourceFile, String destinationFile) async {
  final Directory appDocDir = await getApplicationDocumentsDirectory();
  final file = await localFile(sourceFile);
  try {
    logger.d('move file ${file.path} to $destinationFile');
    await createPath('${appDocDir.path}/$destinationFile');
    await file.rename('${appDocDir.path}/$destinationFile');
  } catch (e) {
    logger.e('Error on move file: $e');
  }
}

Future<void> deleteFolderAll(String pathName) async {
  try {
    final path = await localFile(pathName);
    logger.d('delete files under $path');
    path.delete(recursive: true);
    return;
  } catch (e) {
    logger.e('Error deleting folder $pathName: $e');
    return;
  }
}

Future<void> deleteEverythingInAppDocDir() async {
  try {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    await deleteDirectoryContents(appDocDir);
    logger.i('All files and folders in application documents directory deleted successfully.');
  } catch (e) {
    logger.e('Error deleting files and folders: $e');
  }
}

Future<void> clearTrash() async {
  try {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    await deleteDirectoryContents(Directory(p.join(appDocDir.path, 'trash')));
    logger.i('All files and folders in trash directory deleted successfully.');
  } catch (e) {
    logger.e('Error clearing trash: $e');
  }
}

Future<String> getRelativePath(String filePath) async {
  // final appDocDir = await getApplicationDocumentsDirectory();
  // return p.relative(filePath, from: appDocDir.path);

  // Application Document Directory의 경로를 얻습니다.
  final directory = await getApplicationDocumentsDirectory();
  final directoryPath = '${directory.path}/'; // 경로의 마지막에 슬래시(/) 추가

  // 파일 경로에서 Application Document Directory 부분을 제거합니다.
  final relativePath = filePath.replaceFirst(directoryPath, '');

  return relativePath;
}

Future<void> deleteDirectoryContents(Directory dir) async {
  // final Directory appDocDir = await getApplicationDocumentsDirectory();
  try {
    final List<FileSystemEntity> entities = await dir.list().toList();
    for (final FileSystemEntity entity in entities) {
      if (entity.statSync().type == FileSystemEntityType.directory) {
        await deleteDirectoryContents(Directory(entity.path));
      }
      await entity.delete(); // Delete the directory itself
      // deleteFileFromICloud(entity.path.replaceFirst('${appDocDir.path}/', ''));
    }
  } catch (e) {
    logger.e('Error deleting directory contents: $e');
  }
}

// Function to return file paths as List<String>
Future<List<String>> getFilePaths(String directoryPath) async {
  Directory appDocDir = await getApplicationDocumentsDirectory();
  Directory directory = Directory('${appDocDir.path}/$directoryPath');
  List<String> filePaths = [];

  if (!await directory.exists()) {
    logger.w('Directory does not exist: $directoryPath');
    return [];
  }

  // Recursively list all files in the directory and subdirectories
  await for (FileSystemEntity entity in directory.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      filePaths.add(entity.path);
    }
  }

  return filePaths;
}

// Function to return files as List<File>
Future<List<File>> getFiles(String directoryPath) async {
  Directory appDocDir = await getApplicationDocumentsDirectory();
  Directory directory = Directory('${appDocDir.path}/$directoryPath');
  await createPath(directory.path);
  List<File> files = [];

  if (!await directory.exists()) {
    logger.w('Directory does not exist: $directoryPath');
    return [];
  }

  // Recursively list all files in the directory and subdirectories
  await for (FileSystemEntity entity in directory.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      files.add(entity);
    }
  }

  return files;
}

Future<File> getFile(String subfolder, String filename) async {
  // 앱의 문서 디렉토리 경로를 가져옵니다.
  final Directory docDir = await getApplicationDocumentsDirectory();

  // 특정 하위 폴더와 파일명으로 전체 경로를 조합합니다.
  final String filePath = p.join(docDir.path, subfolder, filename);

  // 파일 객체를 생성합니다.
  return File(filePath);
}

Future<dynamic> getDirectoryTree(String directoryPath) async {
  Directory appDocDir = await getApplicationDocumentsDirectory();
  Directory directory = Directory('${appDocDir.path}/$directoryPath');

  if (!await directory.exists()) {
    logger.w('Directory does not exist: $directoryPath');
    return [];
  }

  return await _scanDirectory(directory, directory.path);
}

Future<dynamic> getRootDirectoryTree() async {
  Directory directory = await getApplicationDocumentsDirectory();

  logger.d('Root directory path: ${directory.path}');

  if (!await directory.exists()) {
    logger.w('Root directory does not exist');
    return [];
  }

  return await _scanDirectory(directory, directory.path);
}

Future<dynamic> _scanDirectory(Directory directory, String basePath) async {
  List<dynamic> directoryContents = [];

  await for (FileSystemEntity entity in directory.list(followLinks: false)) {
    String relativePath = p.relative(entity.path, from: basePath);
    logger.d('Scanning: $relativePath');

    if (entity is File) {
      // Add file's relative path to the list
      directoryContents.add(relativePath);
    } else if (entity is Directory) {
      // Recursively scan the subdirectory
      var subDirectoryContents = await _scanDirectory(entity, basePath);
      // Add the directory name (not full path) and its contents to the list
      directoryContents.add({p.basename(entity.path): subDirectoryContents});
    }
  }

  return directoryContents;
}

Future<void> backup(BuildContext context) async {
  // 파일 저장 기능이 비활성화된 경우 조기 종료
  if (!AppFeatureConfig.isFileStorageEnabled) {
    logger.d('File storage feature is disabled by feature flag');
    return;
  }

  try {
    // AppDocDir 경로를 가져옵니다.
    final appDocDir = await getApplicationDocumentsDirectory();
    final files = appDocDir.listSync(recursive: true);

    final backupDirPath = p.join(appDocDir.path, 'backup');
    final tmpDirPath = p.join(appDocDir.path, 'tmp');

    // 압축 파일을 생성합니다.
    final archive = Archive();
    for (var file in files) {
      if (file.path.startsWith(backupDirPath)) continue;
      if (file.path.startsWith(tmpDirPath)) continue;
      if (file is File) {
        final fileName = file.path.substring(appDocDir.path.length);
        final fileBytes = file.readAsBytesSync();
        archive.addFile(ArchiveFile(fileName, fileBytes.length, fileBytes));
      }
    }

    final DateTime now = DateTime.now();
    final DateFormat formatter = DateFormat('yyyy_MM_dd_HH_mm_ss');

    // 선택한 위치에 ZIP 파일로 저장합니다.
    final zipFilePath = p.join(backupDirPath, 'backup_${formatter.format(now)}.zip');
    final zipFile = File(zipFilePath)..createSync(recursive: true);
    zipFile.writeAsBytesSync(ZipEncoder().encode(archive));

    await SharePlus.instance.share(ShareParams(files: [XFile(zipFile.path)])).then((_) => zipFile.delete());

    // 성공 메시지를 표시합니다.
    if (!context.mounted) return;
    ProviderContainer().read(snackBarServiceProvider).showSuccess('ZIP file saved at {}'.tr(args: [zipFilePath]));
  } catch (e) {
    logger.e('Error creating backup: $e');
    if (!context.mounted) return;
    ProviderContainer().read(snackBarServiceProvider).showError('Error creating ZIP file: {}'.tr(args: [e.toString()]));
  }
}

Future<void> restore(BuildContext context) async {
  // 파일 저장 기능이 비활성화된 경우 조기 종료
  if (!AppFeatureConfig.isFileStorageEnabled) {
    logger.d('File storage feature is disabled by feature flag');
    return;
  }

  try {
    // 파일 피커로 ZIP 파일 선택
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);

      // AppDocDir 경로를 가져옵니다.
      final appDocDir = await getApplicationDocumentsDirectory();

      // 선택한 ZIP 파일 압축 해제
      final bytes = file.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (var file in archive) {
        final fileName = file.name;
        final filePath = p.join(appDocDir.path, trimSlashes(fileName));
        if (file.isFile) {
          final data = file.content as List<int>;
          final aFile = File(filePath);
          if (await aFile.exists()) {
          } else {
            File(filePath)
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          }
        } else {
          Directory(filePath).createSync(recursive: true);
        }
      }

      final container = ProviderContainer();
      final settings = container.read(settingsProvider);
      if (settings.useICloud) {
        await syncFilesWithICloud();
      }

      // 복원 성공 메시지
      if (!context.mounted) return;
      ProviderContainer().read(snackBarServiceProvider).showSuccess('Restoration completed');
    } else {
      // 파일 선택 취소
      if (!context.mounted) return;
      ProviderContainer().read(snackBarServiceProvider).showSuccess('No file selected'.tr());
    }
  } catch (e) {
    logger.e('Error during restoration: $e');
    ProviderContainer()
        .read(snackBarServiceProvider)
        .showError('Error during restoration: {}'.tr(args: [e.toString()]));
  }
}
