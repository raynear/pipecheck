import 'package:boilerplate_cli/commands/rename_command.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';

/// Renames the package/bundle ID across the project.
///
/// 실패 시 false를 반환합니다 — init은 이를 hard-fail로 처리해야 합니다
/// (P0-5: 포크가 보일러플레이트 번들 ID로 출시되는 사고의 뿌리가
/// rename 실패 묵살이었음).
Future<bool> renamePackageStep({
  required String projectRoot,
  required String packageName,
  required String appName,
  required bool verbose,
}) async {
  try {
    // 서브프로세스 대신 직접 호출 — exit code/예외가 그대로 전파되고
    // CI(stdin 없음)에서도 --force로 프롬프트 없이 동작
    final command = RenameCommand(projectRoot: projectRoot);
    final exitCode = await command.run([
      packageName,
      '--name',
      appName,
      '--force',
      if (verbose) '--verbose',
    ]);
    if (exitCode != 0) {
      CliLogger.error('패키지명 변경 실패 (exit $exitCode)');
      return false;
    }
    return true;
  } catch (e) {
    CliLogger.error('패키지명 변경 실패: $e');
    return false;
  }
}
