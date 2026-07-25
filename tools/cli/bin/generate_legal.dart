import 'dart:io';

import 'package:boilerplate_cli/commands/generate_legal_command.dart';

/// GenerateLegal 명령어 진입점.
///
/// ## 사용법
/// ```bash
/// dart run bin/generate_legal.dart [options]
/// dart run bin/generate_legal.dart --app-name "MyApp" --contact-email "support@example.com"
/// dart run bin/generate_legal.dart --config custom_config.yaml --output app/assets/legal/ --verbose
/// ```
Future<void> main(List<String> arguments) async {
  final command = GenerateLegalCommand();
  final exitCode = await command.run(arguments);
  exit(exitCode);
}
