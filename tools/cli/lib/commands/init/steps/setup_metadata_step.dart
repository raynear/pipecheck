import 'dart:io';

import 'package:boilerplate_cli/commands/init/step_result.dart';
import 'package:boilerplate_cli/commands/init/steps/generate_iap_metadata.dart';
import 'package:boilerplate_cli/core/config_loader.dart';

/// Creates the store metadata directory structure and writes title/URL files.
///
/// 경로 계약 (P0-8): 스토어 메타데이터 SSOT는 `<root>/metadata/{ios,android}`.
/// fastlane(deliver/supply)의 `project_path('metadata', ...)`와 동일 지점.
///
/// 로케일은 기존 `metadata/{android,ios}/*` 디렉토리를 스캔해서 발견한다
/// (하드코딩 금지 — 추적된 ko-KR/ja-JP/de-DE/fr-FR 등과 어긋나지 않도록).
/// 하나도 없으면 config.primaryLocale로 폴백한다.
///
/// SSOT 파생 파일(contact_email/contact_website/privacy_policy/category/
/// default_language)은 config 값이 있으면 existsSync 가드 없이 덮어쓴다.
/// title/short_description/full_description은 가드를 유지해 포커 커스터마이징을
/// 보존한다.
Future<StepResult> setupMetadataStep({
  required String projectRoot,
  required ConfigLoader config,
  required bool hasConfig,
  required String appName,
  required bool verbose,
}) async {
  if (!hasConfig) {
    print('    -- 설정 파일 없음, 메타데이터 설정 건너뛰기');
    return StepResult.skipped('설정 파일 없음');
  }

  final metadataRoot = '$projectRoot/metadata';
  final metadataDir = Directory(metadataRoot);
  if (!metadataDir.existsSync()) {
    metadataDir.createSync(recursive: true);
  }

  final locales = {
    'android': _discoverLocales(
      '$metadataRoot/android',
      config.primaryLocale,
    ),
    'ios': _discoverLocales('$metadataRoot/ios', config.primaryLocale),
  };

  // title/short_description/full_description: 없을 때만 작성 (가드 유지).
  final shortDescription = config.shortDescription;
  final fullDescription = config.description;
  for (final platform in locales.entries) {
    for (final locale in platform.value) {
      final localeDir = Directory('$metadataRoot/${platform.key}/$locale');
      if (!localeDir.existsSync()) {
        localeDir.createSync(recursive: true);
      }

      await _writeIfMissing('${localeDir.path}/title.txt', appName);
      if (shortDescription.isNotEmpty) {
        await _writeIfMissing(
          '${localeDir.path}/short_description.txt',
          shortDescription,
        );
      }
      if (fullDescription.isNotEmpty) {
        await _writeIfMissing(
          '${localeDir.path}/full_description.txt',
          fullDescription,
        );
      }
    }
  }

  // Android default 파일: SSOT 파생 — config 값이 있으면 덮어쓴다.
  await _writeFromConfig(
    '$metadataRoot/android/default/contact_email.txt',
    config.contactEmail,
  );
  await _writeFromConfig(
    '$metadataRoot/android/default/contact_website.txt',
    config.contactWebsite,
  );
  await _writeFromConfig(
    '$metadataRoot/android/default/privacy_policy.txt',
    config.privacyPolicyUrl,
  );
  await _writeFromConfig(
    '$metadataRoot/android/default/category.txt',
    config.category,
  );
  await _writeFromConfig(
    '$metadataRoot/android/default/default_language.txt',
    config.primaryLocale,
  );

  // iOS en-US URL/저작권 파일 (기존 동작 유지).
  await _writeFromConfig(
    '$metadataRoot/ios/en-US/privacy_url.txt',
    config.privacyPolicyUrl,
  );
  await _writeFromConfig(
    '$metadataRoot/ios/en-US/support_url.txt',
    config.supportUrl,
  );
  await _writeFromConfig(
    '$metadataRoot/ios/en-US/marketing_url.txt',
    config.marketingUrl,
  );
  await _writeFromConfig(
    '$metadataRoot/ios/en-US/copyright.txt',
    config.copyright,
  );

  print('    메타데이터 디렉토리 구조 생성 완료');

  // IAP 계약 파일 재생성 (SSOT → metadata/in_app_purchases/{ios,android}).
  await generateIapMetadataStep(
    projectRoot: projectRoot,
    config: config,
    verbose: verbose,
  );

  return const StepResult.done();
}

/// `<platformDir>` 아래의 1단계 하위 디렉토리명을 로케일로 수집한다.
/// `default`는 로케일 디렉토리가 아니므로 제외한다. 하나도 없으면
/// [fallbackLocale] 단일 원소 리스트를 돌려준다.
List<String> _discoverLocales(String platformDir, String fallbackLocale) {
  final dir = Directory(platformDir);
  if (dir.existsSync()) {
    final discovered = <String>[];
    for (final entity in dir.listSync()) {
      if (entity is! Directory) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name == 'default') continue;
      discovered.add(name);
    }
    if (discovered.isNotEmpty) {
      discovered.sort();
      return discovered;
    }
  }
  return [fallbackLocale];
}

/// 파일이 없을 때만 [content]를 쓴다 (포커 커스터마이징 보존).
Future<void> _writeIfMissing(String path, String content) async {
  final file = File(path);
  if (!file.existsSync()) {
    await file.create(recursive: true);
    await file.writeAsString(content);
  }
}

/// [value]가 비어 있지 않으면 SSOT 값으로 덮어쓴다. 비어 있으면 no-op
/// (중립 템플릿 placeholder를 그대로 둔다 — 작성자 데이터를 쓰지 않음).
Future<void> _writeFromConfig(String path, String value) async {
  if (value.isEmpty) return;
  final file = File(path);
  await file.create(recursive: true);
  await file.writeAsString(value);
}
