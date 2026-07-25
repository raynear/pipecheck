import 'dart:io';

import 'package:boilerplate_cli/commands/generate_data_safety_command.dart';

/// GenerateDataSafety 명령어 진입점.
///
/// ## 사용법
/// ```bash
/// dart run bin/generate_data_safety.dart [options]
/// ```
Future<void> main(List<String> arguments) async {
  final command = GenerateDataSafetyCommand();
  final exitCode = await command.run(arguments);
  exit(exitCode);
}
