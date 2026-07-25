import 'dart:io';

import 'package:boilerplate_cli/core/error_handler.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';

/// 허용되는 profile preset (앱의 AppProfile enum과 1:1).
const List<String> allowedProfiles = [
  'minimal',
  'standard',
  'premium',
  'enterprise',
];

/// Applies the selected feature profile (minimal/standard/premium/enterprise).
///
/// 1. profile 값 검증 — 잘못된 값은 hard fail (조용히 계속하지 않음)
/// 2. app_config.yaml의 `profile:` 값을 갱신
///
/// 이후의 env 산출물 생성이 APP_PROFILE 키로 앱 런타임에 전달하므로
/// 이 step은 환경 파일 생성 **전에** 실행되어야 한다 (P0-4).
Future<void> applyProfileStep({
  required String profile,
  required String projectRoot,
  required bool verbose,
}) async {
  if (!allowedProfiles.contains(profile)) {
    throw CliException(
      '알 수 없는 profile "$profile"',
      solution: '--profile 값은 다음 중 하나여야 합니다: '
          '${allowedProfiles.join(', ')}',
    );
  }

  final configFile = File('$projectRoot/app_config.yaml');
  if (configFile.existsSync()) {
    final content = configFile.readAsStringSync();
    final pattern = RegExp(r'^(profile:\s*)"?[A-Za-z]+"?', multiLine: true);
    if (pattern.hasMatch(content)) {
      final updated = content.replaceFirstMapped(
        pattern,
        (m) => '${m.group(1)}"$profile"',
      );
      if (updated != content) {
        configFile.writeAsStringSync(updated);
        CliLogger.info('app_config.yaml profile → "$profile"');
      }
    } else {
      CliLogger.warning(
          'app_config.yaml에서 profile 키를 찾지 못했습니다 — 수동 확인 필요');
    }
  }

  if (verbose) {
    CliLogger.debug('Active profile: $profile');
  }
  CliLogger.info('Profile 적용: $profile');
}
