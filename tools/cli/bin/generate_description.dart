import 'dart:io';

import 'package:boilerplate_cli/commands/generate_description_command.dart';

/// GenerateDescription 명령어 진입점.
///
/// ## 사용법
/// ```bash
/// dart run bin/generate_description.dart [options]
/// dart run bin/generate_description.dart --app-name "MyApp" --features "calendar,todo,reminder"
/// dart run bin/generate_description.dart --app-name "MyApp" --features "chat,video" --languages "ko,en" --verbose
/// ```
Future<void> main(List<String> arguments) async {
  final command = GenerateDescriptionCommand();
  final exitCode = await command.run(arguments);
  exit(exitCode);
}
