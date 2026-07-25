import 'dart:io';

import 'package:boilerplate_cli/commands/screenshot_command.dart';

/// Screenshot 명령어 진입점.
///
/// ## 사용법
/// ```bash
/// dart run bin/screenshot.dart [options]
/// dart run bin/screenshot.dart --devices "iPhone 15 Pro Max" --languages "ko,en"
/// dart run bin/screenshot.dart --platform ios --verbose
/// ```
Future<void> main(List<String> arguments) async {
  final command = ScreenshotCommand();
  final exitCode = await command.run(arguments);
  exit(exitCode);
}
