import 'dart:io';

import 'package:boilerplate_cli/commands/init/step_result.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';

/// 딥링크 네이티브 선언을 생성한다 (P2-23a Stage 1b).
///
/// project.yaml deep_link.scheme가 비어 있으면 generate-deeplink가 알아서
/// 건너뛴다. rename(번들 ID 확정) 이후에 실행되도록 init 파이프라인의
/// Privacy Manifest 단계 직후에 호출된다. 실패해도 init을 막지 않는다.
Future<StepResult> generateDeeplinkStep({
  required String projectRoot,
  required bool verbose,
}) async {
  final result = await Process.run(
    'dart',
    [
      'run',
      'tools/cli/bin/generate_deeplink.dart',
      if (verbose) '--verbose',
    ],
    workingDirectory: projectRoot,
  );

  if (result.exitCode == 0) {
    print('    딥링크 네이티브 선언 처리 완료');
    return const StepResult.done();
  }
  if (verbose) {
    CliLogger.warning('딥링크 생성 경고: ${result.stderr}');
  }
  print('    딥링크 생성 건너뛰기 (generate-deeplink 실패)');
  return StepResult.skipped('generate-deeplink 실패 (exit ${result.exitCode})');
}
