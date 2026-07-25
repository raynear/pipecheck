import 'dart:convert';
import 'dart:io';

import 'package:boilerplate_cli/commands/init/step_result.dart';
import 'package:boilerplate_cli/core/config_loader.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';
import 'package:boilerplate_cli/core/progress/progress_indicator.dart';

/// Required IAM roles for Firebase App Distribution deployment.
const _requiredRoles = [
  'roles/firebase.sdkAdminServiceAgent',
  'roles/firebaseappdistro.admin',
];

/// Sets up Google Cloud IAM roles for the Firebase service account.
///
/// Grants the service account the necessary roles to:
/// - Manage Firebase Admin SDK resources
/// - Upload and manage Firebase App Distribution builds
Future<StepResult> setupGcloudIamStep({
  required String projectRoot,
  required ConfigLoader config,
  required bool verbose,
}) async {
  final progress = ProgressIndicator(message: 'GCloud IAM 설정');
  progress.start();

  try {
    // 1. Check gcloud CLI availability
    final hasGcloud = await _isCommandAvailable('gcloud');
    if (!hasGcloud) {
      progress.complete('gcloud CLI 미설치 (건너뜀 - 수동 설정 필요)');
      _printManualGuide(config);
      return StepResult.skipped('gcloud CLI 미설치 (수동 설정 필요)');
    }

    // 2. Resolve Firebase project ID
    final projectId = _resolveProjectId(projectRoot, config);
    if (projectId.isEmpty) {
      progress.complete('Firebase 프로젝트 ID 없음 (건너뜀)');
      return StepResult.skipped('Firebase 프로젝트 ID 없음');
    }

    // 3. Resolve service account email
    final serviceAccountEmail = await _resolveServiceAccountEmail(
      config: config,
      verbose: verbose,
    );
    if (serviceAccountEmail.isEmpty) {
      progress.complete('서비스 계정 이메일 없음 (건너뜀 - 수동 설정 필요)');
      _printManualGuide(config);
      return StepResult.skipped('서비스 계정 이메일 없음 (수동 설정 필요)');
    }

    if (verbose) {
      CliLogger.debug('프로젝트: $projectId');
      CliLogger.debug('서비스 계정: $serviceAccountEmail');
    }

    // 4. Check current IAM bindings to avoid redundant calls
    final existingRoles = await _getExistingRoles(
      projectId: projectId,
      serviceAccountEmail: serviceAccountEmail,
      verbose: verbose,
    );

    // 5. Add missing roles
    final missingRoles = _requiredRoles
        .where((role) => !existingRoles.contains(role))
        .toList();

    if (missingRoles.isEmpty) {
      progress.complete('GCloud IAM 이미 설정됨 ($projectId)');
      return const StepResult.done();
    }

    var allSuccess = true;
    for (final role in missingRoles) {
      final success = await _addIamRole(
        projectId: projectId,
        serviceAccountEmail: serviceAccountEmail,
        role: role,
        verbose: verbose,
      );
      if (!success) allSuccess = false;
    }

    if (allSuccess) {
      progress.complete(
          'GCloud IAM 설정 완료 (${missingRoles.length}개 역할 추가)');
      return const StepResult.done();
    }
    progress.complete('GCloud IAM 일부 역할 설정 실패 (수동 확인 필요)');
    return StepResult.failed('일부 IAM 역할 설정 실패 (수동 확인 필요)');
  } catch (e) {
    CliLogger.error('GCloud IAM 설정 오류: $e');
    progress.complete('GCloud IAM 설정 실패 (건너뜀)');
    return StepResult.failed('GCloud IAM 설정 오류: $e');
  }
}

/// Check if a CLI command is available on PATH.
Future<bool> _isCommandAvailable(String command) async {
  final result = await Process.run('which', [command]);
  return result.exitCode == 0;
}

/// Resolve the Firebase/GCP project ID from config or .env.
String _resolveProjectId(String projectRoot, ConfigLoader config) {
  // 1. From config
  final configId = config.firebaseProjectId;
  if (configId.isNotEmpty) return configId;

  // 2. From .env
  final envFile = File('$projectRoot/.env');
  if (envFile.existsSync()) {
    final content = envFile.readAsStringSync();
    final match = RegExp(r'(?:FIREBASE|GOOGLE)_PROJECT_ID=["'
            "'"
            r']?([^"'
            "'"
            r'\s]+)')
        .firstMatch(content);
    if (match != null) return match.group(1) ?? '';
  }

  return '';
}

/// Resolve the service account email.
///
/// Priority:
/// 1. Config field (services.firebase.service_account_email)
/// 2. Extract from service account JSON file (client_email field)
Future<String> _resolveServiceAccountEmail({
  required ConfigLoader config,
  required bool verbose,
}) async {
  // 1. From config
  final configEmail = config.firebaseServiceAccountEmail;
  if (configEmail.isNotEmpty) return configEmail;

  // 2. From service account JSON
  final saFile = config.firebaseServiceAccountFile;
  if (saFile.isNotEmpty) {
    final resolvedPath = saFile.replaceFirst('~', Platform.environment['HOME'] ?? '');
    final file = File(resolvedPath);
    if (file.existsSync()) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final email = json['client_email'] as String?;
        if (email != null && email.isNotEmpty) {
          if (verbose) {
            CliLogger.debug('서비스 계정 JSON에서 이메일 추출: $email');
          }
          return email;
        }
      } catch (e) {
        if (verbose) {
          CliLogger.debug('서비스 계정 JSON 파싱 실패: $e');
        }
      }
    } else if (verbose) {
      CliLogger.debug('서비스 계정 파일 없음: $resolvedPath');
    }
  }

  return '';
}

/// Get existing IAM roles for the service account on the project.
Future<Set<String>> _getExistingRoles({
  required String projectId,
  required String serviceAccountEmail,
  required bool verbose,
}) async {
  try {
    final result = await Process.run(
      'gcloud',
      [
        'projects',
        'get-iam-policy',
        projectId,
        '--flatten=bindings[].members',
        '--filter=bindings.members:serviceAccount:$serviceAccountEmail',
        '--format=value(bindings.role)',
      ],
    );

    if (result.exitCode != 0) {
      if (verbose) {
        CliLogger.debug('IAM 정책 조회 실패: ${result.stderr}');
      }
      return {};
    }

    final roles = result.stdout
        .toString()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet();

    if (verbose) {
      CliLogger.debug('기존 역할: $roles');
    }

    return roles;
  } catch (e) {
    if (verbose) CliLogger.debug('IAM 정책 조회 오류: $e');
    return {};
  }
}

/// Add an IAM role binding.
Future<bool> _addIamRole({
  required String projectId,
  required String serviceAccountEmail,
  required String role,
  required bool verbose,
}) async {
  CliLogger.info('  역할 추가: $role');

  final result = await Process.run(
    'gcloud',
    [
      'projects',
      'add-iam-policy-binding',
      projectId,
      '--member=serviceAccount:$serviceAccountEmail',
      '--role=$role',
      '--quiet',
    ],
  );

  if (verbose) {
    CliLogger.debug(result.stdout.toString());
  }

  if (result.exitCode != 0) {
    final stderr = result.stderr.toString();
    CliLogger.error('  역할 추가 실패 ($role): $stderr');
    return false;
  }

  return true;
}

/// Print manual setup guide when automation is not possible.
void _printManualGuide(ConfigLoader config) {
  print('');
  print('  [수동 설정 가이드]');
  print('  다음 gcloud 명령어를 실행하세요:');
  print('');
  for (final role in _requiredRoles) {
    print('  gcloud projects add-iam-policy-binding <PROJECT_ID> \\');
    print('    --member="serviceAccount:<SERVICE_ACCOUNT_EMAIL>" \\');
    print('    --role="$role"');
    print('');
  }
  print('  자세한 내용: docs/guides/EXTERNAL_SETUP.md → GCloud IAM 섹션');
}
