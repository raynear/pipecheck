import '../commands/build_command.dart';
import '../commands/deploy_command.dart';
import '../commands/deploy_legal_command.dart';
import '../commands/generate_description_command.dart';
import '../commands/generate_icon_command.dart';
import '../commands/generate_data_safety_command.dart';
import '../commands/generate_deeplink_command.dart';
import '../commands/generate_legal_command.dart';
import '../commands/generate_privacy_command.dart';
import '../commands/iap_register_command.dart';
import '../commands/init_command.dart';
import '../commands/preflight_command.dart';
import '../commands/rename_command.dart';
import '../commands/screenshot_command.dart';
import '../commands/setup_command.dart';
import '../commands/test_command.dart';
import 'gen_env_runner.dart';

/// CLI 디스패치 레지스트리 (P1-10) — bp.dart 디스패처와 테스트가 공유.
///
/// projectRoot는 bp.dart가 상향 탐색으로 결정해 주입한다 — 글로벌 `bp`를
/// 서브디렉토리에서 실행해도 모든 커맨드가 루트 기준으로 동작.
/// 'feature'는 별도 패키지(tools/feature_cli) 위임이라 여기 없음
/// (bootstrap.runFeatureCli가 처리).
final Map<String, Future<int> Function(String projectRoot, List<String> args)>
    commandRunners = {
  'init': (root, args) => InitCommand(projectRoot: root).run(args),
  'build': (root, args) => BuildCommand(projectRoot: root).run(args),
  'gen-env': (root, args) => runGenEnv(
      args.contains('--project-root') ? args : ['--project-root', root, ...args]),
  'deploy': (root, args) => DeployCommand(projectRoot: root).run(args),
  'deploy-legal': (root, args) =>
      DeployLegalCommand(projectRoot: root).run(args),
  'test': (root, args) => TestCommand(projectRoot: root).run(args),
  'preflight': (root, args) => PreflightCommand(projectRoot: root).run(args),
  'rename': (root, args) => RenameCommand(projectRoot: root).run(args),
  'setup': (root, args) => SetupCommand(projectRoot: root).run(args),
  'screenshot': (root, args) => ScreenshotCommand(projectRoot: root).run(args),
  'generate-icon': (root, args) =>
      GenerateIconCommand(projectRoot: root).run(args),
  'generate-legal': (root, args) =>
      GenerateLegalCommand(projectRoot: root).run(args),
  'generate-privacy': (root, args) =>
      GeneratePrivacyCommand(projectRoot: root).run(args),
  'generate-deeplink': (root, args) =>
      GenerateDeeplinkCommand(projectRoot: root).run(args),
  'generate-data-safety': (root, args) =>
      GenerateDataSafetyCommand(projectRoot: root).run(args),
  'generate-desc': (root, args) =>
      GenerateDescriptionCommand(projectRoot: root).run(args),
  'iap-register': (root, args) =>
      IapRegisterCommand(projectRoot: root).run(args),
};

/// 실행 전 fastlane/ 클론이 필요한 커맨드 (구 셸 ./run의 ensure_fastlane 케이스).
const Set<String> fastlaneRequiringCommands = {
  'deploy',
  'setup',
  'screenshot',
  'generate-desc',
  'iap-register',
};

/// ./run --help 출력 (구 셸 show_help 이전).
const String cliUsage = '''
Flutter BoilerPlate CLI

Usage: ./run <command> [options]

Commands:
  init                프로젝트 초기화 (최초 1회)
  build               코드 생성 (Freezed, Drift, Riverpod)
  gen-env             런타임 env 산출물 생성 (.env.debug/profile/release)
  deploy              원버튼 배포
  deploy-legal        법적 문서 Firebase Hosting 배포
  test                테스트 실행
  feature             Feature CLI (generate, enable, disable, list, status)
  preflight           배포 전 검증
  rename              프로젝트 이름 변경
  setup               프로젝트 설정
  screenshot          스크린샷 생성
  generate-icon       앱 아이콘 생성
  generate-legal      법적 문서 생성
  generate-privacy    Apple Privacy Manifest 생성 (PrivacyInfo.xcprivacy)
  generate-deeplink   딥링크 네이티브 선언 생성 (커스텀 스킴)
  generate-data-safety  Data Safety 답안지 생성 (Play 폼 + Apple 라벨)
  generate-desc       스토어 설명 생성
  iap-register        IAP 상품 등록

Options:
  -h, --help          이 도움말 표시

Examples:
  ./run init
  ./run build
  ./run deploy --verbose
  ./run test --unit
  ./run feature generate -n my_feature
''';
