import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:yaml/yaml.dart';

import 'package:boilerplate_cli/commands/iap/iap.dart';
import 'package:boilerplate_cli/core/command.dart';
import 'package:boilerplate_cli/core/error_handler.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';
import 'package:boilerplate_cli/core/progress/progress_indicator.dart';

/// IAP/구독 상품 자동 등록 명령어.
///
/// YAML 설정 파일을 기반으로 App Store Connect 및 Google Play용
/// 인앱 구매 상품 메타데이터를 자동 생성합니다.
///
/// ## 사용법
/// ```bash
/// ./iap-register [options]
/// ```
///
/// ## 옵션
/// - `--config`, `-c`: IAP 설정 파일 경로 (기본: "project.yaml")
/// - `--platform`, `-p`: 플랫폼 (기본: "all", 허용: ios, android, all)
/// - `--dry-run`: 실제 파일 생성 없이 결과만 표시
/// - `--verbose`, `-v`: 자세한 로그를 출력합니다
/// - `--help`, `-h`: 도움말을 표시합니다
///
/// ## 실행 단계
/// 1. YAML 설정 파일 파싱 및 검증
/// 2. iOS 메타데이터 파일 생성 (Fastlane deliver 형식)
/// 3. Android 상품 JSON 파일 생성 (Google Play Developer API 형식)
/// 4. Dart 상수 파일 생성 (IapProductIds 클래스)
class IapRegisterCommand extends Command {
  /// 생성자.
  IapRegisterCommand({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path;

  /// 프로젝트 루트 디렉토리.
  final String projectRoot;

  @override
  String get name => 'iap-register';

  @override
  String get description => 'IAP/구독 상품을 자동 등록합니다.\n\n'
      '실행 단계:\n'
      '  1. YAML 설정 파일 파싱 및 검증\n'
      '  2. iOS 메타데이터 파일 생성 (Fastlane deliver 형식)\n'
      '  3. Android 상품 JSON 파일 생성 (Google Play Developer API 형식)\n'
      '  4. Dart 상수 파일 생성 (IapProductIds 클래스)';

  @override
  ArgParser buildArgParser() {
    return ArgParser()
      ..addOption(
        'config',
        abbr: 'c',
        defaultsTo: 'project.yaml',
        help: 'IAP 설정 파일 경로를 지정합니다.',
      )
      ..addOption(
        'platform',
        abbr: 'p',
        defaultsTo: 'all',
        allowed: ['ios', 'android', 'all'],
        help: '대상 플랫폼을 지정합니다.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: '실제 파일 생성 없이 결과만 표시합니다.',
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
    final platform = args['platform'] as String;
    final isDryRun = args['dry-run'] as bool;
    final isVerbose = args['verbose'] as bool;

    // 로거 초기화
    await CliLogger.init(verbose: isVerbose);

    if (isVerbose) {
      CliLogger.debug('IAP 등록 명령어를 시작합니다...');
      CliLogger.debug('  Config: $configPath');
      CliLogger.debug('  Platform: $platform');
      CliLogger.debug('  Dry Run: $isDryRun');
    }

    print('');
    print('🛒 IAP 상품 등록을 시작합니다...');
    print('');

    final stopwatch = Stopwatch()..start();

    // 단계 목록 구성
    final steps = <String>[
      '설정 파일 파싱',
      '상품 정의 검증',
      if (platform == 'all' || platform == 'ios') 'iOS 메타데이터 생성',
      if (platform == 'all' || platform == 'android') 'Android 상품 JSON 생성',
      'Dart 상수 파일 생성',
    ];

    final progress = StepProgress(steps: steps);

    // Step 1: 설정 파일 파싱
    progress.nextStep();
    final config = _loadConfig(configPath);
    progress.completeStep();

    // Step 2: 상품 정의 검증
    progress.nextStep();
    // 상품 ID는 스토어 등록 최종형 <id>.<packageName>으로 통일 (P1-17a) —
    // setupStoreInfoStep(./init)과 같은 규칙. 앱이 조회하는
    // IapProductIds 상수도 같은 최종 ID로 생성된다.
    final packageName = _loadPackageName();
    final products = parseProducts(config)
        .map((p) => IapProduct(
              id: '${p.id}.$packageName',
              type: p.type,
              names: p.names,
              descriptions: p.descriptions,
              priceTier: p.priceTier,
            ))
        .toList();
    final subscriptionGroups = parseSubscriptions(config)
        .map((g) => SubscriptionGroup(
              groupId: g.groupId,
              groupNames: g.groupNames,
              products: g.products
                  .map((p) => SubscriptionProduct(
                        id: '${p.id}.$packageName',
                        duration: p.duration,
                        names: p.names,
                        descriptions: p.descriptions,
                        priceTier: p.priceTier,
                      ))
                  .toList(),
            ))
        .toList();
    final allSubscriptionProducts = subscriptionGroups
        .expand((group) => group.products)
        .toList();

    if (products.isEmpty && allSubscriptionProducts.isEmpty) {
      progress.failStep('상품이 정의되지 않았습니다');
      throw CliException(
        '등록할 상품이 없습니다',
        solution: '설정 파일에 products 또는 subscriptions 항목을 추가하세요.',
      );
    }

    validateProducts(products);
    validateSubscriptionGroups(subscriptionGroups);

    if (isVerbose) {
      CliLogger.debug('  일반 상품: ${products.length}개');
      CliLogger.debug('  구독 그룹: ${subscriptionGroups.length}개');
      CliLogger.debug('  구독 상품: ${allSubscriptionProducts.length}개');
    }
    progress.completeStep();

    // Dry-run 모드: 요약만 출력
    if (isDryRun) {
      printDryRunSummary(
        products: products,
        subscriptionGroups: subscriptionGroups,
        platform: platform,
      );
      return 0;
    }

    // Step 3: iOS 메타데이터 생성
    if (platform == 'all' || platform == 'ios') {
      progress.nextStep();
      try {
        await generateIosMetadata(
          projectRoot: projectRoot,
          products: products,
          subscriptionGroups: subscriptionGroups,
          isVerbose: isVerbose,
        );
        progress.completeStep();
      } catch (e) {
        progress.failStep(e.toString());
        rethrow;
      }
    }

    // Step 4: Android 상품 JSON 생성
    if (platform == 'all' || platform == 'android') {
      progress.nextStep();
      try {
        await generateAndroidMetadata(
          projectRoot: projectRoot,
          products: products,
          subscriptionGroups: subscriptionGroups,
          isVerbose: isVerbose,
        );
        progress.completeStep();
      } catch (e) {
        progress.failStep(e.toString());
        rethrow;
      }
    }

    // Step 5: Dart 상수 파일 생성
    progress.nextStep();
    try {
      await generateDartConstants(
        projectRoot: projectRoot,
        products: products,
        subscriptionProducts: allSubscriptionProducts,
        isVerbose: isVerbose,
      );
      progress.completeStep();
    } catch (e) {
      progress.failStep(e.toString());
      rethrow;
    }

    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds / 1000;

    // 성공 메시지
    printSuccessMessage(
      elapsed: elapsed,
      products: products,
      subscriptionGroups: subscriptionGroups,
      platform: platform,
    );

    return 0;
  }

  /// project.yaml에서 package_name을 읽습니다 (상품 ID 최종형 규칙용).
  String _loadPackageName() {
    final projectFile = File('$projectRoot/project.yaml');
    if (!projectFile.existsSync()) {
      throw CliException(
        'project.yaml을 찾을 수 없습니다 (상품 ID 규칙에 package_name 필요)',
        solution: '프로젝트 루트에서 실행하거나 project.yaml을 생성하세요.',
      );
    }
    final yaml = loadYaml(projectFile.readAsStringSync());
    final packageName =
        (yaml as YamlMap)['project']?['package_name']?.toString() ?? '';
    if (packageName.isEmpty) {
      throw CliException(
        'project.yaml에 project.package_name이 없습니다',
        solution: 'project.package_name을 설정하세요 (예: com.example.app).',
      );
    }
    return packageName;
  }

  /// 설정 파일을 로드하고 YAML로 파싱합니다.
  /// project.yaml인 경우 iap 섹션을 반환합니다.
  YamlMap _loadConfig(String configPath) {
    final configFile = File('$projectRoot/$configPath');
    if (!configFile.existsSync()) {
      throw CliException(
        '설정 파일을 찾을 수 없습니다: $configPath',
        solution: '다음을 확인하세요:\n'
            '  1. 설정 파일이 존재하는지 확인\n'
            '  2. --config 옵션으로 올바른 경로를 지정\n'
            '  3. project.yaml의 iap 섹션을 참고하여 생성',
      );
    }

    final yamlContent = configFile.readAsStringSync();
    try {
      final yaml = loadYaml(yamlContent) as YamlMap;

      // project.yaml: iap 섹션 추출
      if (yaml.containsKey('iap')) {
        return yaml['iap'] as YamlMap;
      }

      return yaml;
    } catch (e) {
      throw CliException(
        'YAML 파일 파싱에 실패했습니다: $e',
        solution: 'YAML 문법을 확인하세요.\n'
            '들여쓰기에 탭 대신 스페이스를 사용하세요.',
      );
    }
  }
}
