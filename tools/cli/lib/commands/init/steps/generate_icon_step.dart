import 'dart:io';

import 'package:boilerplate_cli/commands/init/step_result.dart';
import 'package:boilerplate_cli/core/adlab_client.dart';
import 'package:boilerplate_cli/core/config_loader.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';

/// Generates an app icon via adlab (app_icon strategy) and runs
/// flutter_launcher_icons.
///
/// init의 다른 선택 스텝과 동일하게 soft-skip: adlab 서버가 없으면 안내만
/// 하고 건너뛴다 (아이콘은 나중에 ./scripts/generate-icon으로 재생성 가능).
Future<StepResult> generateIconStep({
  required String appDir,
  required ConfigLoader config,
  required bool hasConfig,
  required String appName,
  required bool verbose,
}) async {
  if (!hasConfig) {
    print('    -- 설정 파일 없음, 아이콘 생성 건너뛰기');
    return StepResult.skipped('설정 파일 없음');
  }

  final iconPrompt = config.iconPrompt;
  if (iconPrompt.isEmpty) {
    print('    -- icon.prompt 미설정, 아이콘 생성 건너뛰기');
    print('    -- project.yaml의 icon.prompt에 프롬프트를 입력하세요');
    return StepResult.skipped('project.yaml icon.prompt 미설정');
  }

  final client = AdlabClient();
  if (!await client.isUp()) {
    print('    -- adlab 서버 미실행 (${client.base}), 아이콘 생성 건너뛰기');
    print('    -- ${AdlabClient.startHint.split('\n').first}');
    return StepResult.skipped('adlab 서버 미실행 (${client.base})');
  }

  print('    adlab으로 아이콘 생성 중...');

  try {
    final imageBytes = await client.generateAppIcon(
      app: appName,
      prompt: iconPrompt,
      style: config.iconStyle,
    );

    final iconDir = Directory('$appDir/assets/launcher_icon');
    if (!iconDir.existsSync()) {
      iconDir.createSync(recursive: true);
    }
    // 아이콘 SSOT (P0-8): flutter_launcher_icons.yaml의 image_path와 동일,
    // 앱 이름 비종속 — rename 후에도 경로 불변
    final iconFile = File('$appDir/assets/launcher_icon/icon.png');
    await iconFile.writeAsBytes(imageBytes);
    print('    아이콘 저장: ${iconFile.path}');

    print('    flutter_launcher_icons 실행 중...');
    final launcherResult = await Process.run(
      'dart',
      ['run', 'flutter_launcher_icons'],
      workingDirectory: appDir,
    );
    if (launcherResult.exitCode == 0) {
      print('    플랫폼별 아이콘 생성 완료');
    } else {
      if (verbose) {
        CliLogger.warning(
            'flutter_launcher_icons 경고: ${launcherResult.stderr}');
      }
      print('    flutter_launcher_icons 실행 중 경고 발생');
    }
    return const StepResult.done();
  } catch (e) {
    print('    아이콘 생성 실패: $e');
    print('    수동으로 실행: ./scripts/generate-icon --prompt "$iconPrompt"');
    return StepResult.failed('아이콘 생성 실패: $e');
  }
}
