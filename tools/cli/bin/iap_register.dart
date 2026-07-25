import 'dart:io';

import 'package:boilerplate_cli/commands/iap_register_command.dart';

/// IAP 상품 등록 명령어 진입점.
///
/// ## 사용법
/// ```bash
/// dart run bin/iap_register.dart [options]
/// dart run bin/iap_register.dart --dry-run
/// dart run bin/iap_register.dart --platform ios --verbose
/// ```
Future<void> main(List<String> arguments) async {
  final command = IapRegisterCommand();
  final exitCode = await command.run(arguments);
  exit(exitCode);
}
