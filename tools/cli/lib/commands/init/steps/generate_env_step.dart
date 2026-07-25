import 'dart:io';

import 'package:boilerplate_cli/core/config_loader.dart';
import 'package:boilerplate_cli/core/env_artifacts.dart';

/// Generates environment files (.env + .env.{debug,profile,release}).
///
/// - `.env` (project root): 시크릿 포함 프로젝트 설정 (Fastlane/CLI용, .gitignore)
/// - `.env.{debug,profile,release}` (app/config/env/): Flutter 런타임
///   환경변수 산출물 (앱 assets) — env_artifacts.dart가 단일 작성기
Future<void> generateEnvStep({
  required String projectRoot,
  required String appDir,
  required ConfigLoader config,
  required bool hasConfig,
}) async {
  if (!hasConfig) {
    return;
  }

  // .env → 프로젝트 루트 (설정 + 시크릿, Fastlane/CLI에서 사용)
  // 기존 .env가 있으면 시크릿 값을 보존
  final envFile = File('$projectRoot/.env');
  String? existingEnv;
  if (envFile.existsSync()) {
    existingEnv = await envFile.readAsString();
  }
  final envContent = config.generateEnvProject(existingEnv: existingEnv);
  await envFile.writeAsString(envContent);

  // .env.debug / .env.profile / .env.release → app/config/env/ (앱 assets)
  await writeRuntimeEnvArtifacts(
    projectRoot: projectRoot,
    appDir: appDir,
    config: config,
  );
}
