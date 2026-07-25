import 'dart:io';

import 'package:args/args.dart';

import '../core/command.dart';
import '../core/config_loader.dart';
import '../core/logger/cli_logger.dart';
import 'deeplink/deeplink_native_generator.dart';

/// 딥링크 네이티브 매니페스트 생성 명령어 (P2-23a Stage 1b + Stage 2).
///
/// project.yaml `deep_link`에서 네이티브 딥링크 선언을 생성합니다:
/// - `deep_link.scheme` (커스텀 스킴):
///   - Android: `AndroidManifest.xml`에 VIEW intent-filter (멱등 주입)
///   - iOS: `Info.plist`에 CFBundleURLTypes (멱등 주입)
/// - `deep_link.universal_links` (유니버설/앱링크 도메인):
///   - Android: `AndroidManifest.xml`에 `autoVerify="true"` https intent-filter
///     (스킴 필터와 **분리된** intent-filter, 별도 마커)
///   - iOS: `Runner.entitlements`에 `com.apple.developer.associated-domains`
///   - 검증 파일: `docs/legal/.well-known/` 아래 AASA + assetlinks.json
///     (assetlinks SHA-256은 외부값이라 빈 placeholder — 포크가 채움)
///
/// scheme/universal_links 둘 다 비어 있으면 아무 것도 하지 않습니다(미설정 포크).
/// 둘은 독립적이라 한쪽만 설정해도 동작합니다.
///
/// rename(P0-5) 이후에 실행되어야 합니다 — 번들 ID가 확정된 뒤 CFBundleURLName/
/// appID를 채웁니다. init 파이프라인은 Privacy Manifest 단계 직후에 호출합니다.
///
/// ## 사용법
/// ```bash
/// ./run generate-deeplink
/// ./run generate-deeplink --verbose
/// ```
class GenerateDeeplinkCommand extends Command {
  /// 생성자.
  GenerateDeeplinkCommand({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path;

  /// 프로젝트 루트 디렉토리.
  final String projectRoot;

  @override
  String get name => 'generate-deeplink';

  @override
  String get description =>
      '딥링크 네이티브 선언을 생성합니다 (커스텀 스킴 + 유니버설/앱링크).\n\n'
      'project.yaml deep_link.scheme에서 Android intent-filter/iOS\n'
      'CFBundleURLTypes를, deep_link.universal_links에서 Android autoVerify\n'
      'intent-filter/iOS associated-domains/AASA+assetlinks를 멱등 주입합니다.\n'
      '둘 다 비면 건너뜁니다.';

  @override
  ArgParser buildArgParser() {
    return ArgParser()
      ..addOption(
        'config',
        abbr: 'c',
        help: '설정 파일 경로',
        defaultsTo: 'app_config.yaml',
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
    final isVerbose = args['verbose'] as bool;

    await CliLogger.init(verbose: isVerbose);

    final configFile = File('$projectRoot/$configPath');
    if (!configFile.existsSync()) {
      CliLogger.warning('설정 파일 없음: $configPath — 딥링크 생성 건너뜀');
      return 0;
    }
    final config = ConfigLoader('$projectRoot/$configPath');
    await config.load();

    final scheme = config.deepLinkScheme.trim();
    final universalLinks = config.deepLinkUniversalLinks
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toList();

    if (scheme.isEmpty && universalLinks.isEmpty) {
      print('딥링크 미설정 (deep_link.scheme / universal_links 비어 있음) — 건너뜀');
      return 0;
    }

    final bundleId = config.packageName;
    if (isVerbose) {
      CliLogger.debug('  Scheme: ${scheme.isEmpty ? '(없음)' : scheme}');
      CliLogger.debug('  Universal links: '
          '${universalLinks.isEmpty ? '(없음)' : universalLinks.join(', ')}');
      CliLogger.debug('  Bundle ID: $bundleId');
    }

    var ok = true;

    // ── 커스텀 스킴 (Stage 1b) ──
    if (scheme.isNotEmpty) {
      ok &= _injectFile(
        path: 'app/android/app/src/main/AndroidManifest.xml',
        label: 'Android intent-filter (scheme)',
        transform: (content) => injectAndroidScheme(content, scheme),
      );
      ok &= _injectFile(
        path: 'app/ios/Runner/Info.plist',
        label: 'iOS CFBundleURLTypes',
        transform: (content) => injectIosUrlTypes(content, scheme, bundleId),
      );
    }

    // ── 유니버설/앱링크 (Stage 2) ──
    if (universalLinks.isNotEmpty) {
      ok &= _injectFile(
        path: 'app/android/app/src/main/AndroidManifest.xml',
        label: 'Android autoVerify intent-filter (universal)',
        transform: (content) =>
            injectAndroidUniversal(content, universalLinks),
      );
      ok &= _injectFile(
        path: 'app/ios/Runner/Runner.entitlements',
        label: 'iOS associated-domains',
        transform: (content) =>
            injectIosAssociatedDomains(content, universalLinks),
      );
      ok &= _writeVerificationFiles(
        teamId: config.iosTeamId.trim(),
        iosBundleId: config.iosBundleId.trim(),
        androidPackage: bundleId,
      );
    }

    if (!ok) return 1;
    final parts = <String>[
      if (scheme.isNotEmpty) 'scheme: $scheme://',
      if (universalLinks.isNotEmpty) 'universal: ${universalLinks.join(', ')}',
    ];
    print('딥링크 네이티브 선언 생성 완료 (${parts.join(' | ')})');
    return 0;
  }

  /// 유니버설 링크 검증 파일을 `docs/legal/.well-known/` 아래에 쓴다.
  /// assetlinks.json은 항상 생성(SHA-256은 빈 placeholder), AASA는 team_id가
  /// 있을 때만 생성한다(없으면 잘못된 appID 방지).
  bool _writeVerificationFiles({
    required String teamId,
    required String iosBundleId,
    required String androidPackage,
  }) {
    try {
      _writeArtifact(
        'docs/legal/.well-known/assetlinks.json',
        assetLinksJson(androidPackage, const <String>[]),
        'assetlinks.json',
      );
      print('  ⚠️  assetlinks.json의 sha256_cert_fingerprints가 비어 있습니다 — '
          'Play Console → 앱 무결성 → 앱 서명의 SHA-256 인증서 지문'
          '(또는 ./gradlew signingReport)으로 채우세요.');

      if (teamId.isEmpty) {
        CliLogger.warning(
            'iOS team_id 미설정 (app_config.yaml platforms.ios.team_id) — '
            'AASA 생성 건너뜀');
      } else {
        _writeArtifact(
          'docs/legal/.well-known/apple-app-site-association',
          appleAppSiteAssociation(teamId, iosBundleId),
          'apple-app-site-association',
        );
      }
      return true;
    } catch (e) {
      CliLogger.error('검증 파일 생성 실패: $e');
      return false;
    }
  }

  void _writeArtifact(String path, String content, String label) {
    final file = File('$projectRoot/$path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    print('  $label 생성: $path');
  }

  bool _injectFile({
    required String path,
    required String label,
    required String Function(String content) transform,
  }) {
    final file = File('$projectRoot/$path');
    if (!file.existsSync()) {
      CliLogger.warning('$label 건너뜀 — 파일 없음: $path');
      return true; // 파일 부재는 비치명적 (예: 플랫폼 미구성 포크)
    }
    try {
      final original = file.readAsStringSync();
      final updated = transform(original);
      if (updated != original) {
        file.writeAsStringSync(updated);
        print('  $label 주입 완료: $path');
      } else {
        print('  $label 변경 없음 (멱등): $path');
      }
      return true;
    } catch (e) {
      CliLogger.error('$label 주입 실패: $e');
      return false;
    }
  }
}
