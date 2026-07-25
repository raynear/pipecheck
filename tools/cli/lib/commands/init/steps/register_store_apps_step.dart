import 'dart:io';

import 'package:boilerplate_cli/commands/init/step_result.dart';
import 'package:boilerplate_cli/core/config_loader.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';
import 'package:boilerplate_cli/core/path_utils.dart';
import 'package:boilerplate_cli/core/progress/progress_indicator.dart';

/// Registers the app on App Store Connect (via Fastlane produce) and
/// provides guidance for Google Play Console (API limitation).
///
/// 요약 판정: iOS 실패/오류 → failed, iOS 건너뜀 또는 Android 수동 등록
/// 필요 → skipped(수동 잔여를 요약에 노출), 둘 다 해소된 경우만 done.
Future<StepResult> registerStoreAppsStep({
  required String projectRoot,
  required String fastlaneDir,
  required ConfigLoader config,
  required bool verbose,
}) async {
  final progress = ProgressIndicator(message: '스토어 앱 등록');
  progress.start();

  final results = <String>[];

  // iOS: Auto-register via Fastlane produce
  final iosResult = await _registerIosApp(
    fastlaneDir: fastlaneDir,
    config: config,
    verbose: verbose,
  );
  results.add(iosResult);

  // Android: Guidance only (Google Play API does not support app creation)
  final androidResult = _checkAndroidApp(
    config: config,
    verbose: verbose,
  );
  results.add(androidResult);

  progress.complete('스토어 앱 등록: ${results.join(', ')}');

  if (iosResult.contains('실패') || iosResult.contains('오류')) {
    return StepResult.failed('iOS 등록 실패 ($androidResult)');
  }
  if (iosResult.contains('건너뜀')) {
    return StepResult.skipped('$iosResult / $androidResult');
  }
  if (androidResult.contains('수동')) {
    return StepResult.skipped('Play Console 앱 수동 생성 필요 ($iosResult)');
  }
  return const StepResult.done();
}

/// Register iOS app on App Store Connect using Fastlane produce.
Future<String> _registerIosApp({
  required String fastlaneDir,
  required ConfigLoader config,
  required bool verbose,
}) async {
  // Check required credentials
  final appleId = config.appleId;
  final teamId = config.iosTeamId;
  final packageName = config.packageName;
  final appName = config.appName;

  if (appleId.isEmpty || teamId.isEmpty) {
    CliLogger.info('iOS: Apple ID 또는 Team ID 미설정 (건너뜀)');
    return 'iOS 건너뜀';
  }

  // Check if App Store Connect API key is available (preferred auth)
  final apiKeyId = config.apiKeyId;
  final apiIssuerId = config.apiIssuerId;
  final apiKeyFile = config.apiKeyFile;
  final hasApiKey = apiKeyId.isNotEmpty &&
      apiIssuerId.isNotEmpty &&
      apiKeyFile.isNotEmpty;

  if (!hasApiKey) {
    CliLogger.info('iOS: App Store Connect API 키 미설정 (건너뜀)');
    return 'iOS 건너뜀 (API 키 필요)';
  }

  // Check if Fastlane is available
  final hasFastlane = await _isCommandAvailable('fastlane');
  if (!hasFastlane) {
    CliLogger.info('iOS: Fastlane 미설치 (건너뜀)');
    return 'iOS 건너뜀 (Fastlane 필요)';
  }

  try {
    CliLogger.info('iOS: App Store Connect에 앱 등록 중...');

    // Use Fastlane produce via bundle exec
    final result = await Process.run(
      'bash',
      [
        '-c',
        'cd "$fastlaneDir" && bundle exec fastlane produce '
            '--username "$appleId" '
            '--app_identifier "$packageName" '
            '--app_name "$appName" '
            '--language "English" '
            '--sku "$packageName" '
            '--team_id "$teamId" '
            '--skip_itc false '
            '--skip_devcenter false '
            '2>&1'
      ],
      environment: {
        ...Platform.environment,
        'APP_STORE_CONNECT_API_KEY_ID': apiKeyId,
        'APP_STORE_CONNECT_API_ISSUER_ID': apiIssuerId,
        'APP_STORE_CONNECT_API_KEY_FILE': apiKeyFile,
      },
    );

    if (verbose) {
      CliLogger.debug(result.stdout.toString());
    }

    final output = result.stdout.toString();

    // Already exists is also a success
    if (result.exitCode == 0 || output.contains('already exists')) {
      CliLogger.info('iOS: App Store Connect 등록 완료');
      return 'iOS 완료';
    }

    CliLogger.info('iOS: App Store Connect 등록 실패 (수동 등록 필요)');
    if (verbose) {
      CliLogger.debug('produce stderr: ${result.stderr}');
    }
    return 'iOS 실패';
  } catch (e) {
    CliLogger.error('iOS 앱 등록 오류: $e');
    return 'iOS 오류';
  }
}

/// Check Android app status and provide guidance.
/// Google Play Developer API does not support programmatic app creation.
String _checkAndroidApp({
  required ConfigLoader config,
  required bool verbose,
}) {
  final packageName = config.packageName;
  final googleJsonKey = config.googleJsonKey;

  if (googleJsonKey.isEmpty ||
      !File(expandUserPath(googleJsonKey)).existsSync()) {
    CliLogger.info(
      'Android: Google Play 앱은 수동 생성이 필요합니다.\n'
      '  1. https://play.google.com/console 에서 앱 생성\n'
      '  2. 패키지명: $packageName\n'
      '  3. 서비스 계정 JSON 키를 app_config.yaml에 설정',
    );
    return 'Android 수동 필요';
  }

  CliLogger.info('Android: Google Play JSON 키 확인됨');
  return 'Android 키 확인됨';
}

/// Check if a CLI command is available on PATH.
Future<bool> _isCommandAvailable(String command) async {
  final result = await Process.run('which', [command]);
  return result.exitCode == 0;
}
