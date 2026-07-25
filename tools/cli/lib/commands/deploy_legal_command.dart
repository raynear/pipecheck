import 'dart:io';

import 'package:args/args.dart';

import '../core/command.dart';
import '../core/config_loader.dart';
import '../core/env_artifacts.dart';
import '../core/logger/cli_logger.dart';

/// 법적 문서 Firebase Hosting 배포 명령어 (P1-15.5b).
///
/// `generate-legal` 산출물(`docs/legal/` — privacy/terms/index)을
/// Firebase Hosting에 배포합니다. 프로젝트 ID는 google-services.json이
/// SSOT (`readFirebaseProjectId`), 호스팅 설정은 루트 `firebase.json`.
///
/// 배포 URL (gen_env의 deriveLegalHostingUrl 컨벤션과 동일):
///   https://<projectId>.web.app/privacy_policy.html
///   https://<projectId>.web.app/terms_of_service.html
///
/// `generate-deeplink`(universal_links 설정 시)이 만든
/// `docs/legal/.well-known/` 검증 파일도 같은 배포로 서빙됩니다 (P2-23a Stage 2b):
///   https://<projectId>.web.app/.well-known/apple-app-site-association
///   https://<projectId>.web.app/.well-known/assetlinks.json
/// (firebase.json: ignore에서 dotdir 제외 해제 + AASA Content-Type 헤더 룰)
///
/// 선행 조건 (1회):
/// - `npm install -g firebase-tools` + `firebase login`
/// - Firebase 프로젝트 (init의 setup-firebase가 google-services.json 배치)
///
/// ## 사용법
/// ```bash
/// ./run deploy-legal
/// ./run deploy-legal --dry-run   # 배포 명령만 출력
/// ```
class DeployLegalCommand extends Command {
  /// 생성자.
  DeployLegalCommand({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path;

  /// 프로젝트 루트 디렉토리.
  final String projectRoot;

  @override
  String get name => 'deploy-legal';

  @override
  String get description =>
      '법적 문서(docs/legal)를 호스팅합니다 (--target firebase|github).\n\n'
      'firebase(기본): firebase-tools 설치 + firebase login\n'
      'github: gh CLI + github_repository 설정 (legal-pages.yml 워크플로)\n'
      '선행: generate-legal 실행';

  @override
  ArgParser buildArgParser() {
    return ArgParser()
      ..addOption('target',
          abbr: 't',
          help: '호스팅 대상',
          defaultsTo: 'firebase',
          allowed: ['firebase', 'github'])
      ..addFlag('dry-run',
          negatable: false, help: '실제 배포 없이 실행할 명령만 출력합니다.')
      ..addFlag('verbose',
          abbr: 'v', negatable: false, help: '자세한 실행 로그를 출력합니다.');
  }

  @override
  Future<int> execute(ArgResults args) async {
    final isDryRun = args['dry-run'] as bool;
    final isVerbose = args['verbose'] as bool;
    final target = args['target'] as String;

    await CliLogger.init(verbose: isVerbose);

    // 산출물 존재 확인
    final legalDir = Directory('$projectRoot/docs/legal');
    final privacyFile = File('${legalDir.path}/privacy_policy.html');
    if (!privacyFile.existsSync()) {
      CliLogger.error('docs/legal 산출물이 없습니다 — 먼저 generate-legal을 실행하세요');
      print('  해결: ./run generate-legal');
      return 1;
    }

    if (target == 'github') {
      return _deployGithub(isDryRun: isDryRun, isVerbose: isVerbose);
    }

    // 프로젝트 ID (google-services.json SSOT)
    final projectId = readFirebaseProjectId(projectRoot);
    if (projectId.isEmpty) {
      CliLogger.error(
          'Firebase 프로젝트 ID를 찾을 수 없습니다 (app/android/app/google-services.json)');
      print('  해결: ./run init의 setup-firebase 단계 또는 Firebase 콘솔에서');
      print('        google-services.json을 받아 배치하세요.');
      return 1;
    }

    final command = [
      'firebase',
      'deploy',
      '--only',
      'hosting',
      '--project',
      projectId,
    ];

    print('');
    print('🌐 법적 문서를 Firebase Hosting에 배포합니다');
    print('  프로젝트: $projectId');
    print('  산출물: docs/legal (firebase.json hosting.public)');
    print('  URL: ${deriveLegalHostingUrl(projectId, 'privacy_policy.html')}');
    print('');

    if (isDryRun) {
      print('  [DRY RUN] ${command.join(' ')}');
      return 0;
    }

    final result = await Process.run(
      command.first,
      command.sublist(1),
      workingDirectory: projectRoot,
    );

    if (isVerbose) {
      print(result.stdout);
    }

    if (result.exitCode != 0) {
      // firebase CLI는 에러를 stdout에 찍는 경우가 있다 — 둘 다 본다
      final output = '${result.stdout}\n${result.stderr}';
      CliLogger.error('Firebase Hosting 배포 실패 (exit ${result.exitCode})');
      if (output.contains('command not found') ||
          result.exitCode == 127 ||
          output.contains('No such file')) {
        print('  firebase-tools가 없습니다: npm install -g firebase-tools');
      } else if (output.contains('Not logged in') ||
          output.contains('authenticat')) {
        print('  로그인이 필요합니다: firebase login');
      } else if (output.contains('Failed to get Firebase project')) {
        print('  Firebase 프로젝트 "$projectId"가 계정에 없습니다.');
        print('  템플릿 기본값은 placeholder입니다 — 실제 프로젝트의');
        print('  google-services.json을 배치하세요 (./run init의');
        print('  setup-firebase 단계 또는 Firebase 콘솔에서 다운로드).');
      } else {
        final errorLines = output
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        print('  ${errorLines.reversed.take(5).toList().reversed.join('\n  ')}');
      }
      return 1;
    }

    print('✅ 배포 완료: ${deriveLegalHostingUrl(projectId, '')}');
    print('   project.yaml listing.privacy_policy_url은 비워두면');
    print('   gen_env가 위 컨벤션 URL을 자동 도출합니다.');
    return 0;
  }

  /// docs/legal를 GitHub Pages로 배포한다 (legal-pages.yml 워크플로 트리거).
  Future<int> _deployGithub({
    required bool isDryRun,
    required bool isVerbose,
  }) async {
    final config = ConfigLoader('$projectRoot/app_config.yaml');
    try {
      await config.load();
    } catch (_) {}
    final repo = config.githubRepository;
    final url = deriveGithubPagesUrl(repo, 'privacy_policy.html');
    if (url.isEmpty) {
      CliLogger.error('github_repository가 미설정/placeholder입니다 ($repo)');
      print('  해결: project.yaml project.github_repository를 "owner/repo"로 '
          '설정하세요.');
      return 1;
    }

    print('');
    print('🌐 법적 문서를 GitHub Pages에 배포합니다');
    print('  저장소: $repo');
    print('  산출물: docs/legal (.github/workflows/legal-pages.yml)');
    print('  URL: $url');
    print('');

    final command = ['gh', 'workflow', 'run', 'legal-pages.yml'];
    if (isDryRun) {
      print('  [DRY RUN] ${command.join(' ')}');
      print('  (또는 docs/legal 변경을 main에 push하면 자동 배포)');
      return 0;
    }

    final result = await Process.run(
      command.first,
      command.sublist(1),
      workingDirectory: projectRoot,
    );
    if (isVerbose) print(result.stdout);

    if (result.exitCode != 0) {
      final output = '${result.stdout}\n${result.stderr}';
      CliLogger.error('워크플로 트리거 실패 (exit ${result.exitCode})');
      if (output.contains('command not found') || result.exitCode == 127) {
        print('  gh CLI가 없습니다: https://cli.github.com/ 설치 후 '
            '`gh auth login`');
      } else if (output.contains('could not find') ||
          output.contains('HTTP 404')) {
        print('  legal-pages.yml이 아직 기본 브랜치에 없습니다 — 이 변경을');
        print('  push/merge한 뒤 다시 실행하거나, docs/legal 변경을 push하세요.');
      } else {
        print('  ${output.trim()}');
      }
      return 1;
    }

    print('✅ 배포 트리거 완료 (진행: gh run watch)');
    print('   첫 배포는 Pages 활성화로 1~2분 더 걸릴 수 있습니다.');
    print('   project.yaml listing.legal_hosting을 "github"로 두면 gen_env가');
    print('   위 URL을 앱/스토어 메타데이터에 자동 주입합니다.');
    return 0;
  }
}
