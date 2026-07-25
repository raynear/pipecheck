import 'dart:io';

import 'package:boilerplate_cli/core/gen_env_runner.dart';

/// 런타임 env 산출물 생성 진입점 (CI/fastlane용).
///
/// ## 사용법
/// ```bash
/// dart run bin/gen_env.dart
/// dart run bin/gen_env.dart --project-root /path/to/project
/// ```
Future<void> main(List<String> arguments) async {
  exit(await runGenEnv(arguments));
}
