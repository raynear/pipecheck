import 'dart:io';

import 'package:boilerplate_cli/commands/init/step_result.dart';
import 'package:boilerplate_cli/core/config_loader.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';

/// Generates legal documents (privacy policy, terms of service).
Future<StepResult> generateLegalStep({
  required String projectRoot,
  required ConfigLoader config,
  required bool hasConfig,
  required String appName,
  required bool verbose,
}) async {
  final result = await Process.run(
    'dart',
    [
      'run',
      'tools/cli/bin/generate_legal.dart',
      '--app-name', appName,
      if (hasConfig && config.contactEmail.isNotEmpty)
        ...['--contact-email', config.contactEmail],
      if (verbose) '--verbose',
    ],
    workingDirectory: projectRoot,
  );

  if (result.exitCode == 0) {
    print('    법적 문서 생성 완료');
    return const StepResult.done();
  }
  if (verbose) {
    CliLogger.warning('법적 문서 생성 경고: ${result.stderr}');
  }
  print('    법적 문서 생성 건너뛰기 (generate-legal 명령어 미설치)');
  return StepResult.skipped('generate-legal 실패 (exit ${result.exitCode})');
}
