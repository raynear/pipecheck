import 'dart:io';

import 'package:boilerplate_cli/commands/rename_command.dart';

/// Rename 명령어 진입점.
///
/// ## 사용법
/// ```bash
/// dart run bin/rename.dart <새_프로젝트_이름> [options]
/// dart run bin/rename.dart my_awesome_app
/// dart run bin/rename.dart my_awesome_app --dry-run
/// dart run bin/rename.dart my_awesome_app --force --verbose
/// ```
Future<void> main(List<String> arguments) async {
  final command = RenameCommand();
  final exitCode = await command.run(arguments);
  exit(exitCode);
}
