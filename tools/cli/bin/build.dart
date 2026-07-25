import 'dart:io';

import 'package:boilerplate_cli/commands/build_command.dart';

/// Build 명령어 진입점.
///
/// ## 사용법
/// ```bash
/// dart run bin/build.dart [options]
/// dart run bin/build.dart --watch
/// dart run bin/build.dart --clean --verbose
/// ```
Future<void> main(List<String> arguments) async {
  final command = BuildCommand();
  final exitCode = await command.run(arguments);
  exit(exitCode);
}
