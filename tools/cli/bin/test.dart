#!/usr/bin/env dart
/// Flutter BoilerPlate 테스트 CLI.
///
/// 사용법:
/// ```bash
/// dart run tools/cli/bin/test.dart [options]
/// ./test [options]
/// ```
import 'dart:io';

import 'package:boilerplate_cli/commands/test_command.dart';

Future<void> main(List<String> arguments) async {
  final command = TestCommand();
  final exitCode = await command.run(arguments);
  exit(exitCode);
}
