import 'dart:io';

import 'package:boilerplate_cli/commands/generate_deeplink_command.dart';

/// GenerateDeeplink 명령어 진입점.
///
/// ## 사용법
/// ```bash
/// dart run bin/generate_deeplink.dart [options]
/// dart run bin/generate_deeplink.dart --verbose
/// ```
Future<void> main(List<String> arguments) async {
  final command = GenerateDeeplinkCommand();
  final exitCode = await command.run(arguments);
  exit(exitCode);
}
