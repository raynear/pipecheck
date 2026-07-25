import 'dart:io';

import 'package:boilerplate_cli/core/logger/cli_logger.dart';

/// Runs `build.sh` for code generation (Freezed, Drift, Riverpod, etc.).
///
/// 실패 시 false를 반환합니다 — init은 이를 hard-fail로 처리해야 합니다
/// (코드 생성이 깨진 트리에서 init이 계속 진행되면 안 됨).
Future<bool> runCodegenStep({
  required String appDir,
  required bool verbose,
}) async {
  final buildResult = await Process.run(
    'bash',
    ['build.sh'],
    workingDirectory: appDir,
  );
  if (buildResult.exitCode != 0) {
    if (verbose) {
      CliLogger.warning('코드 생성 중 경고: ${buildResult.stderr}');
    }
    print('    -- 코드 생성 중 일부 오류 발생 (계속 진행)');
    return false;
  }
  return true;
}
