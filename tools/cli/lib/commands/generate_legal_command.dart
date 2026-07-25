import 'dart:io';

import 'package:args/args.dart';

import '../core/command.dart';
import '../core/logger/cli_logger.dart';
import '../core/progress/progress_indicator.dart';
import 'legal/legal_generator.dart' as generator;
import 'legal/legal_templates.dart' as templates;

/// 법적 문서 생성 명령어.
///
/// 개인정보처리방침(Privacy Policy)과 이용약관(Terms of Service)
/// HTML 템플릿을 생성합니다. app_config.yaml에서 앱 이름, 연락처 등을
/// 읽어와 자동으로 채워넣습니다.
///
/// 기본 출력(`docs/legal/`)은 Firebase Hosting 배포 디렉토리입니다
/// (P1-15.5b — 루트 firebase.json의 hosting.public). 산출물 생성 후
/// `./run deploy-legal`로 배포하면
/// `https://<firebase프로젝트ID>.web.app/privacy_policy.html`로
/// 호스팅됩니다 — gen_env의 deriveLegalHostingUrl 컨벤션과 동일.
/// (GitHub Pages 방식은 private repo가 Free 플랜에서 Pages 미지원이라 폐기)
///
/// ## 사용법
/// ```bash
/// ./scripts/generate-legal
/// ./scripts/generate-legal --app-name "MyApp" --contact-email "support@example.com"
/// ./scripts/generate-legal --config custom_config.yaml --output docs/legal/
/// ```
///
/// ## 옵션
/// - `--config`, `-c`: 설정 파일 경로 (기본값: app_config.yaml)
/// - `--output`, `-o`: 출력 디렉토리 (기본값: docs/legal/)
/// - `--app-name`: 앱 이름 (설정 파일 값 오버라이드)
/// - `--contact-email`: 연락처 이메일 (설정 파일 값 오버라이드)
/// - `--effective-date`: 시행일 (기본값: 오늘)
/// - `--verbose`, `-v`: 자세한 로그 출력
///
/// ## 실행 단계
/// 1. 설정 파일 로드
/// 2. 개인정보처리방침 생성
/// 3. 이용약관 생성
/// 4. 파일 저장 (index.html 포함)
class GenerateLegalCommand extends Command {
  /// 생성자.
  GenerateLegalCommand({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path;

  /// 프로젝트 루트 디렉토리.
  final String projectRoot;

  @override
  String get name => 'generate-legal';

  @override
  String get description => '법적 문서를 생성합니다 (개인정보처리방침, 이용약관).\n\n'
      '실행 단계:\n'
      '  1. 설정 파일 로드\n'
      '  2. 개인정보처리방침 (Privacy Policy) HTML 생성\n'
      '  3. 이용약관 (Terms of Service) HTML 생성\n'
      '  4. 파일 저장';

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
        help: '출력 디렉토리 (Pages branch 서빙 경로)',
        defaultsTo: 'docs/legal/',
      )
      ..addOption(
        'app-name',
        help: '앱 이름 (설정 파일 값 오버라이드)',
      )
      ..addOption(
        'contact-email',
        help: '연락처 이메일 (설정 파일 값 오버라이드)',
      )
      ..addOption(
        'effective-date',
        help: '시행일 (기본값: 오늘, 형식: YYYY-MM-DD)',
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
    final appNameOverride = args['app-name'] as String?;
    final contactEmailOverride = args['contact-email'] as String?;
    final effectiveDateArg = args['effective-date'] as String?;
    final isVerbose = args['verbose'] as bool;

    await CliLogger.init(verbose: isVerbose);

    if (isVerbose) {
      CliLogger.debug('GenerateLegal 명령어를 시작합니다...');
      CliLogger.debug('  Project Root: $projectRoot');
      CliLogger.debug('  Config: $configPath');
      CliLogger.debug('  Output: $outputDir');
    }

    final effectiveDate = generator.resolveEffectiveDate(effectiveDateArg);

    print('');
    print('법적 문서 생성을 시작합니다...');
    print('');

    final stopwatch = Stopwatch()..start();

    final steps = <String>[
      '설정 파일 로드',
      '개인정보처리방침 생성',
      '이용약관 생성',
      '파일 저장',
    ];

    final progress = StepProgress(steps: steps);

    // Step 1: 설정 파일 로드
    progress.nextStep();
    final config = await generator.loadConfig(
      projectRoot: projectRoot,
      configPath: configPath,
      isVerbose: isVerbose,
    );
    final appName = appNameOverride ?? config?.appName ?? 'My App';
    final contactEmail =
        contactEmailOverride ?? config?.contactEmail ?? 'support@example.com';
    final privacyPolicyUrl = config?.privacyPolicyUrl ?? '';
    final termsOfServiceUrl = config?.termsOfServiceUrl ?? '';

    // ConfigLoader에서 기능 플래그 읽기
    final firebaseEnabled = config?.firebaseEnabled ?? true;
    final adsEnabled = config?.adsEnabled ?? false;
    final subscriptionEnabled = config?.subscriptionEnabled ?? false;
    final authEnabled =
        config?.featureOverrides['isAuthenticationEnabled'] ?? true;

    if (isVerbose) {
      CliLogger.debug('  App Name: $appName');
      CliLogger.debug('  Contact Email: $contactEmail');
      CliLogger.debug('  Effective Date: $effectiveDate');
      CliLogger.debug('  Firebase: $firebaseEnabled');
      CliLogger.debug('  Ads: $adsEnabled');
      CliLogger.debug('  Subscription: $subscriptionEnabled');
      CliLogger.debug('  Auth: $authEnabled');
    }
    progress.completeStep();

    // Step 2: 개인정보처리방침 생성
    progress.nextStep();
    final privacyPolicyHtml = templates.generatePrivacyPolicy(
      appName: appName,
      contactEmail: contactEmail,
      effectiveDate: effectiveDate,
      privacyPolicyUrl: privacyPolicyUrl,
      firebaseEnabled: firebaseEnabled,
      adsEnabled: adsEnabled,
      subscriptionEnabled: subscriptionEnabled,
    );
    progress.completeStep();

    // Step 3: 이용약관 생성
    progress.nextStep();
    final termsOfServiceHtml = templates.generateTermsOfService(
      appName: appName,
      contactEmail: contactEmail,
      effectiveDate: effectiveDate,
      termsOfServiceUrl: termsOfServiceUrl,
      authEnabled: authEnabled,
      subscriptionEnabled: subscriptionEnabled,
    );
    progress.completeStep();

    // Step 4: 파일 저장 (Pages 디렉토리 진입점 index.html 포함)
    progress.nextStep();
    final legalIndexHtml = templates.generateLegalIndex(appName: appName);
    final savedFiles = await generator.saveFiles(
      projectRoot: projectRoot,
      outputDir: outputDir,
      privacyPolicyHtml: privacyPolicyHtml,
      termsOfServiceHtml: termsOfServiceHtml,
      legalIndexHtml: legalIndexHtml,
      isVerbose: isVerbose,
    );
    progress.completeStep();

    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds / 1000;

    generator.printSuccessMessage(elapsed, savedFiles);

    return 0;
  }
}
