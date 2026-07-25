import 'dart:io';

import 'package:boilerplate_cli/commands/preflight_command.dart';

/// Preflight 명령어 진입점.
Future<void> main(List<String> arguments) async {
  final command = PreflightCommand();
  final exitCode = await command.run(arguments);
  exit(exitCode);
}
