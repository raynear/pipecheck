import 'dart:io';

import 'package:boilerplate_cli/core/logger/cli_logger.dart';

/// Runs `flutter pub get` to install dependencies.
///
/// Returns `true` on success, `false` on failure.
Future<bool> installDependenciesStep({
  required String appDir,
}) async {
  final pubResult = await Process.run(
    'flutter',
    ['pub', 'get'],
    workingDirectory: appDir,
  );
  if (pubResult.exitCode != 0) {
    CliLogger.error('flutter pub get 실패: ${pubResult.stderr}');
    return false;
  }
  return true;
}
