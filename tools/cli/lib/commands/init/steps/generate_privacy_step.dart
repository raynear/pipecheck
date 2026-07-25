import 'dart:io';

import 'package:boilerplate_cli/commands/init/step_result.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';

/// Apple Privacy Manifest(PrivacyInfo.xcprivacy)를 생성한다 (P1-13d).
///
/// 활성 기능 셋에서 생성하므로 입력이 없고 실패해도 init을 막지 않는다
/// (스토어 제출 전 preflight/배포 단계에서 다시 잡힌다).
Future<StepResult> generatePrivacyStep({
  required String projectRoot,
  required bool verbose,
}) async {
  final result = await Process.run(
    'dart',
    [
      'run',
      'tools/cli/bin/generate_privacy.dart',
      if (verbose) '--verbose',
    ],
    workingDirectory: projectRoot,
  );

  if (result.exitCode == 0) {
    print('    Privacy Manifest 생성 완료');
    return const StepResult.done();
  }
  if (verbose) {
    CliLogger.warning('Privacy Manifest 생성 경고: ${result.stderr}');
  }
  print('    Privacy Manifest 생성 건너뛰기 (generate-privacy 실패)');
  return StepResult.skipped('generate-privacy 실패 (exit ${result.exitCode})');
}
