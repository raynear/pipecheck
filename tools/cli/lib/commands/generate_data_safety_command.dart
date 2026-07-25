import 'dart:io';

import 'package:args/args.dart';

import '../core/command.dart';
import '../core/config_loader.dart';
import '../core/logger/cli_logger.dart';
import 'datasafety/data_safety_generator.dart';

/// Data Safety 답안지 생성 명령어 (P1-13f).
///
/// 활성 기능 셋에서 Google Play Data Safety 폼 답안지와
/// App Store Privacy Nutrition 라벨 대응표를 생성합니다.
///
/// ## 사용법
/// ```bash
/// ./run generate-data-safety
/// ./run generate-data-safety --output metadata/data_safety
/// ```
class GenerateDataSafetyCommand extends Command {
  /// 생성자.
  GenerateDataSafetyCommand({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path;

  /// 프로젝트 루트 디렉토리.
  final String projectRoot;

  @override
  String get name => 'generate-data-safety';

  @override
  String get description =>
      'Data Safety 답안지를 생성합니다 (Play 폼 + Apple Nutrition 라벨).\n\n'
      '활성 기능 셋에서 결정적으로 생성 — 기능 구성 변경 시 재생성 후\n'
      '양 스토어 콘솔에 반영하세요.';

  @override
  ArgParser buildArgParser() {
    return ArgParser()
      ..addOption(
        'config',
        abbr: 'c',
        help: '설정 파일 경로',
        defaultsTo: 'app_config.yaml',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: '출력 디렉토리',
        defaultsTo: 'metadata/data_safety',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: '자세한 실행 로그를 출력합니다.',
      );
  }

  @override
  Future<int> execute(ArgResults args) async {
    final configPath = args['config'] as String;
    final outputDir = args['output'] as String;
    final isVerbose = args['verbose'] as bool;

    await CliLogger.init(verbose: isVerbose);

    final configFile = File('$projectRoot/$configPath');
    ConfigLoader? config;
    if (configFile.existsSync()) {
      config = ConfigLoader('$projectRoot/$configPath');
      await config.load();
    } else {
      CliLogger.warning('설정 파일 없음: $configPath — 기본값으로 생성합니다');
    }

    final inputs = buildDataSafetyInputs(config);
    final appName = config?.appName ?? 'My App';

    if (isVerbose) {
      CliLogger.debug('  Ads: ${inputs.adsEnabled}');
      CliLogger.debug('  Analytics/Crash: ${inputs.analyticsEnabled}');
      CliLogger.debug('  Email auth: ${inputs.emailAuthEnabled}');
      CliLogger.debug('  Subscription: ${inputs.subscriptionEnabled}');
    }

    final directory = Directory('$projectRoot/$outputDir');
    directory.createSync(recursive: true);

    final markdownPath = '${directory.path}/data_safety.md';
    final jsonPath = '${directory.path}/data_safety.json';
    final csvPath = '${directory.path}/data_safety.csv';
    File(markdownPath)
        .writeAsStringSync(renderMarkdown(inputs, appName: appName));
    File(jsonPath).writeAsStringSync(renderJson(inputs, appName: appName));
    // Play Data Safety 자동 업로드용 CSV — upload_data_safety(privacy.rb)가
    // androidpublisher dataSafety API에 그대로 올린다 (deploy Step 8d, Android).
    File(csvPath).writeAsStringSync(renderPlayCsv(inputs));

    // Apple App Privacy 업로드 파일 — fastlane upload_privacy_details(privacy.rb)가
    // project_path('metadata','app_privacy_details.json')에서 읽는다. 메타데이터
    // SSOT인 <root>/metadata/ 직하에 둔다(outputDir과 무관하게 고정 경로).
    final appPrivacyDir = Directory('$projectRoot/metadata')
      ..createSync(recursive: true);
    final appPrivacyPath = '${appPrivacyDir.path}/app_privacy_details.json';
    File(appPrivacyPath).writeAsStringSync(renderAppPrivacyJson(inputs));

    print('Data Safety 답안지 생성 완료:');
    print('  $outputDir/data_safety.md   (콘솔 입력용 답안지)');
    print('  $outputDir/data_safety.json (기계가독)');
    print('  $outputDir/data_safety.csv  (Play Data Safety 자동 업로드용)');
    print('  metadata/app_privacy_details.json (Apple App Privacy 업로드용)');
    return 0;
  }
}
