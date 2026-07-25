import 'dart:io';

import 'package:boilerplate_cli/commands/init_command.dart';

/// Init 명령어 진입점.
///
/// ## 사용법
/// ```bash
/// ./setup init
/// ./setup init --config app_config.yaml
/// ./setup init --name "My App" --package com.example.myapp --profile standard
/// ```
Future<void> main(List<String> arguments) async {
  final command = InitCommand();
  final exitCode = await command.run(arguments);
  exit(exitCode);
}
