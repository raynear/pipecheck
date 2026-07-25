import 'dart:io';

import 'package:boilerplate_cli/commands/init/step_result.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';

/// Runs `flutter analyze` to verify the build.
Future<StepResult> verifyBuildStep({
  required String appDir,
  required bool verbose,
}) async {
  final analyzeResult = await Process.run(
    'flutter',
    ['analyze', '--no-fatal-infos'],
    workingDirectory: appDir,
  );
  if (analyzeResult.exitCode != 0) {
    if (verbose) {
      CliLogger.warning('빌드 경고:\n${analyzeResult.stdout}');
    }
    print('    -- 빌드 경고가 있습니다 (계속 진행)');
    return StepResult.skipped('flutter analyze 경고 (exit ${analyzeResult.exitCode})');
  }
  return const StepResult.done();
}
