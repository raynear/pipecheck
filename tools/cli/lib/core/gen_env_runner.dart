import 'dart:io';

import 'config_loader.dart';
import 'env_artifacts.dart';

/// 런타임 env 산출물 생성 (P1-10: bin/gen_env.dart와 bp.dart 디스패처 공용).
Future<int> runGenEnv(List<String> arguments) async {
  var projectRoot = Directory.current.path;
  final flagIndex = arguments.indexOf('--project-root');
  if (flagIndex != -1 && flagIndex + 1 < arguments.length) {
    projectRoot = arguments[flagIndex + 1];
  }

  try {
    final config = ConfigLoader('$projectRoot/app_config.yaml');
    await config.load();
    final written = await writeRuntimeEnvArtifacts(
      projectRoot: projectRoot,
      config: config,
    );
    for (final path in written) {
      stdout.writeln('Generated: $path');
    }
    return 0;
  } catch (e) {
    stderr.writeln('gen_env failed: $e');
    return 1;
  }
}
