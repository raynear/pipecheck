import 'dart:io';

import 'package:boilerplate_cli/core/config_loader.dart';
import 'package:boilerplate_cli/core/env_artifacts.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';
import 'package:boilerplate_cli/core/progress/progress_indicator.dart';

/// Configures Firebase via flutterfire CLI if enabled.
/// Auto-creates the Firebase project if it does not exist.
///
/// 반환값 `true` = 재설정이 실제로 반영됨(google-services.json의 project_id가
/// 목표 프로젝트로 교체됨). `false` = 실패/미반영 — init은 이를 hard-fail로
/// 처리해야 한다 (B1: 커밋된 boilerplate-2024가 그대로 출시되는 사고 방지).
/// 과거에는 void 반환 + 전 실패분기 무음 skip이라 firebase login이 안 된
/// 포크가 저자 프로젝트로 출시될 수 있었다.
Future<bool> setupFirebaseStep({
  required String appDir,
  required ConfigLoader config,
  required bool verbose,
}) async {
  final firebaseProgress = ProgressIndicator(message: 'Firebase 설정');
  firebaseProgress.start();

  try {
    // 1. Ensure Firebase CLI is installed
    final hasFirebase = await _isCommandAvailable('firebase');
    if (!hasFirebase) {
      CliLogger.info('Firebase CLI 설치 중...');
      final installResult = await Process.run(
        'bash',
        ['-c', 'curl -sL https://firebase.tools | bash'],
      );
      if (installResult.exitCode != 0) {
        firebaseProgress.fail('CLI 설치 실패');
        return false;
      }
    }

    // 2. Ensure FlutterFire CLI is installed
    final hasFlutterFire = await _isCommandAvailable('flutterfire');
    if (!hasFlutterFire) {
      CliLogger.info('FlutterFire CLI 설치 중...');
      await Process.run(
        'dart',
        ['pub', 'global', 'activate', 'flutterfire_cli'],
      );
    }

    // 3. Determine project ID
    var projectId = config.firebaseProjectId;
    final projectName = config.appName;

    if (projectId.isEmpty) {
      // Auto-generate project ID from app name
      projectId = _generateProjectId(projectName);
      CliLogger.info('Firebase 프로젝트 ID 자동 생성: $projectId');
    }

    // 4. Check if project exists, create if not
    final projectExists = await _checkFirebaseProjectExists(projectId);

    if (!projectExists) {
      CliLogger.info('Firebase 프로젝트 "$projectId" 생성 중...');
      final created = await _createFirebaseProject(
        projectId: projectId,
        displayName: projectName,
        verbose: verbose,
      );
      if (!created) {
        firebaseProgress.fail('프로젝트 생성 실패');
        return false;
      }
      // Wait for project to become available
      await Future<void>.delayed(const Duration(seconds: 3));
    } else {
      CliLogger.info('Firebase 프로젝트 "$projectId" 확인됨');
    }

    // 5. Configure Flutter app with Firebase
    final configureResult = await Process.run(
      'bash',
      [
        '-c',
        'flutterfire configure '
            '--project=$projectId '
            '--platforms=android,ios '
            '--yes'
      ],
      workingDirectory: appDir,
    );

    if (verbose) {
      CliLogger.debug(configureResult.stdout.toString());
    }

    if (configureResult.exitCode != 0) {
      final stderr = configureResult.stderr.toString();
      if (verbose) CliLogger.debug('flutterfire stderr: $stderr');
      firebaseProgress.fail('flutterfire configure 실패 (수동 설정 필요)');
      return false;
    }

    // 6. Update .env with project ID
    await _updateEnvFirebaseProjectId(appDir, projectId);

    // 7. Write project ID back to app_config.yaml (SSOT)
    await _updateConfigProjectId(appDir, projectId);

    // 8. 재설정 검증 (B1): configure가 실제로 google-services.json을 목표
    //    프로젝트로 교체했는지 확인. 여전히 템플릿 기본(또는 다른 값)이면
    //    실효 없던 것 → 실패로 보고해 init이 hard-fail하게 한다.
    final writtenId =
        readFirebaseProjectId(Directory(appDir).parent.path);
    if (writtenId != projectId) {
      firebaseProgress.fail(
          '재설정 미반영 (기대 "$projectId", 실제 "$writtenId")');
      return false;
    }

    firebaseProgress.complete('Firebase 설정 완료 ($projectId)');
    return true;
  } catch (e) {
    CliLogger.error('Firebase 설정 오류: $e');
    firebaseProgress.fail('예외 발생 ($e)');
    return false;
  }
}

/// Check if a CLI command is available on PATH.
Future<bool> _isCommandAvailable(String command) async {
  final result = await Process.run(
    'which',
    [command],
  );
  return result.exitCode == 0;
}

/// Generate a Firebase-compatible project ID from app name.
String _generateProjectId(String appName) {
  final now = DateTime.now();
  final dateSuffix = '${now.year}${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';
  final base = appName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9-]'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return '$base-$dateSuffix';
}

/// Check if a Firebase project exists.
Future<bool> _checkFirebaseProjectExists(String projectId) async {
  try {
    final result = await Process.run(
      'firebase',
      ['projects:list'],
    );
    final output = result.stdout.toString();
    return output.contains(projectId);
  } catch (e) {
    return false;
  }
}

/// Create a new Firebase project.
Future<bool> _createFirebaseProject({
  required String projectId,
  required String displayName,
  required bool verbose,
}) async {
  try {
    final result = await Process.run(
      'firebase',
      ['projects:create', projectId, '--display-name', displayName],
    );

    if (verbose) {
      CliLogger.debug(result.stdout.toString());
    }

    if (result.exitCode == 0) {
      CliLogger.info('Firebase 프로젝트 "$projectId" 생성 완료');
      return true;
    }

    final stderr = result.stderr.toString();

    // Project ID already taken - try with suffix
    if (stderr.contains('already taken') ||
        stderr.contains('already a project with ID')) {
      final altId = '$projectId-${DateTime.now().year}';
      CliLogger.info('프로젝트 ID "$projectId" 이미 사용 중. '
          '"$altId"로 재시도...');
      return _createFirebaseProject(
        projectId: altId,
        displayName: displayName,
        verbose: verbose,
      );
    }

    CliLogger.error('Firebase 프로젝트 생성 실패: $stderr');
    return false;
  } catch (e) {
    CliLogger.error('Firebase 프로젝트 생성 오류: $e');
    return false;
  }
}

/// Update .env file with Firebase project ID.
Future<void> _updateEnvFirebaseProjectId(
    String appDir, String projectId) async {
  // The .env is at the project root (parent of appDir)
  final projectRoot = Directory(appDir).parent.path;
  final envFile = File('$projectRoot/.env');
  if (!envFile.existsSync()) return;

  var content = await envFile.readAsString();

  // Update or add GOOGLE_PROJECT_ID
  if (content.contains(RegExp(r'^#?\s*GOOGLE_PROJECT_ID=', multiLine: true))) {
    content = content.replaceAll(
      RegExp(r'^#?\s*GOOGLE_PROJECT_ID=.*$', multiLine: true),
      'GOOGLE_PROJECT_ID="$projectId"',
    );
  } else {
    content += '\nGOOGLE_PROJECT_ID="$projectId"\n';
  }

  // Update or add FIREBASE_PROJECT_ID
  if (content.contains(
      RegExp(r'^#?\s*FIREBASE_PROJECT_ID=', multiLine: true))) {
    content = content.replaceAll(
      RegExp(r'^#?\s*FIREBASE_PROJECT_ID=.*$', multiLine: true),
      'FIREBASE_PROJECT_ID="$projectId"',
    );
  }

  await envFile.writeAsString(content);
}

/// Write Firebase project ID back to app_config.yaml (SSOT).
Future<void> _updateConfigProjectId(String appDir, String projectId) async {
  final projectRoot = Directory(appDir).parent.path;
  final configFile = File('$projectRoot/app_config.yaml');
  if (!configFile.existsSync()) return;

  var content = await configFile.readAsString();

  // Replace empty or existing project_id value
  if (content.contains(RegExp(r'project_id:\s*"[^"]*"'))) {
    content = content.replaceFirst(
      RegExp(r'project_id:\s*"[^"]*"'),
      'project_id: "$projectId"',
    );
  } else if (content.contains(RegExp(r'project_id:\s*$', multiLine: true))) {
    content = content.replaceFirst(
      RegExp(r'project_id:\s*$', multiLine: true),
      'project_id: "$projectId"',
    );
  }

  await configFile.writeAsString(content);
  CliLogger.debug('app_config.yaml에 project_id 기록: $projectId');
}
