import 'dart:io';

import 'package:boilerplate_cli/commands/setup_command.dart';

/// Setup 명령어 진입점.
///
/// ## 사용법
/// ```bash
/// dart run bin/setup.dart [options]
/// dart run bin/setup.dart --help
/// dart run bin/setup.dart --force --verbose
/// ```
Future<void> main(List<String> arguments) async {
  final command = SetupCommand();
  final exitCode = await command.run(arguments);
  exit(exitCode);
}
