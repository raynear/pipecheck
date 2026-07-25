import 'dart:io';

import 'package:boilerplate_cli/commands/generate_privacy_command.dart';

/// GeneratePrivacy 명령어 진입점.
///
/// ## 사용법
/// ```bash
/// dart run bin/generate_privacy.dart [options]
/// dart run bin/generate_privacy.dart --verbose
/// ```
Future<void> main(List<String> arguments) async {
  final command = GeneratePrivacyCommand();
  final exitCode = await command.run(arguments);
  exit(exitCode);
}
