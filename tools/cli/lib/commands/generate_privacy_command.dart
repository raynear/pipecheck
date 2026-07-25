import 'dart:io';

import 'package:args/args.dart';

import '../core/command.dart';
import '../core/config_loader.dart';
import '../core/logger/cli_logger.dart';
import 'privacy/privacy_manifest_generator.dart';

/// Apple Privacy Manifest 생성 명령어 (P1-13d).
///
/// 활성 기능 셋(광고/Firebase)과 project.yaml의 트래킹 도메인에서
/// `app/ios/Runner/PrivacyInfo.xcprivacy`를 생성합니다.
/// 파일의 Xcode 등록(pbxproj)은 템플릿에 커밋되어 있어 내용만 갱신합니다.
///
/// ## 사용법
/// ```bash
/// ./run generate-privacy
/// ./run generate-privacy --verbose
/// ```
class GeneratePrivacyCommand extends Command {
  /// 생성자.
  GeneratePrivacyCommand({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path;

  /// 프로젝트 루트 디렉토리.
  final String projectRoot;

  @override
  String get name => 'generate-privacy';

  @override
  String get description =>
      'Apple Privacy Manifest(PrivacyInfo.xcprivacy)를 생성합니다.\n\n'
      '활성 기능 셋(광고/Firebase)과 project.yaml privacy.tracking_domains에서\n'
      '앱 바이너리 수준 선언을 생성합니다 (SDK 매니페스트는 각 SDK가 배포).';

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
        help: '출력 파일 경로',
        defaultsTo: 'app/ios/Runner/PrivacyInfo.xcprivacy',
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
    final outputPath = args['output'] as String;
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

    final adsEnabled = config?.adsEnabled ?? false;
    final firebaseEnabled = config?.firebaseEnabled ?? true;
    final trackingDomains = config?.trackingDomains ?? const <String>[];
    // 광고가 켜진 앱은 ATT/광고 ID 트래킹을 전제 (UMP/ATT 플로우 — P1-13a/c)
    final tracking = adsEnabled;

    if (isVerbose) {
      CliLogger.debug('  Ads: $adsEnabled');
      CliLogger.debug('  Firebase: $firebaseEnabled');
      CliLogger.debug('  Tracking: $tracking');
      CliLogger.debug('  Tracking domains: $trackingDomains');
    }

    final manifest = generatePrivacyManifest(
      tracking: tracking,
      trackingDomains: trackingDomains,
      adsEnabled: adsEnabled,
      analyticsEnabled: firebaseEnabled,
      crashReportingEnabled: firebaseEnabled,
    );

    final outputFile = File('$projectRoot/$outputPath');
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync(manifest);

    print('Privacy Manifest 생성 완료: $outputPath');
    return 0;
  }
}
