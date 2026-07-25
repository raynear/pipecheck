import 'dart:io';

import 'package:boilerplate_cli/commands/generate_icon_command.dart';

/// GenerateIcon 명령어 진입점.
///
/// ## 사용법
/// ```bash
/// dart run bin/generate_icon.dart [options]
/// dart run bin/generate_icon.dart --prompt "minimalist calendar app icon"
/// dart run bin/generate_icon.dart --prompt "modern chat app icon" --style gradient --verbose
/// ```
Future<void> main(List<String> arguments) async {
  final command = GenerateIconCommand();
  final exitCode = await command.run(arguments);
  exit(exitCode);
}
