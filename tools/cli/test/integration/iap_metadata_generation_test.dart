import 'dart:convert';
import 'dart:io';

import 'package:boilerplate_cli/commands/init/steps/generate_iap_metadata.dart';
import 'package:boilerplate_cli/core/config_loader.dart';
import 'package:test/test.dart';

/// Live regeneration proof for the IAP metadata generator (WS-B).
///
/// Loads the REAL repo project.yaml/app_config.yaml into a temp project root,
/// seeds a stale author-package contract, runs the step, and asserts the
/// generated contracts use the current package name with no author namespace.
void main() {
  group('generateIapMetadataStep (live SSOT regeneration)', () {
    // cwd during `dart test` is tools/cli → repo root is two levels up.
    final repoRoot = Directory.current.parent.parent.path;
    late Directory tempRoot;
    late ConfigLoader config;

    setUp(() async {
      tempRoot = Directory.systemTemp.createTempSync('iap_meta_test_');
      // ConfigLoader merges project.yaml from the same dir as configPath.
      File('$repoRoot/app_config.yaml')
          .copySync('${tempRoot.path}/app_config.yaml');
      File('$repoRoot/project.yaml')
          .copySync('${tempRoot.path}/project.yaml');
      config = ConfigLoader('${tempRoot.path}/app_config.yaml');
      await config.load();
    });

    tearDown(() {
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    });

    test('purges stale author-package files and regenerates from SSOT',
        () async {
      final iosDir =
          Directory('${tempRoot.path}/metadata/in_app_purchases/ios')
            ..createSync(recursive: true);
      // Seed a stale contract from a previous (author) package name.
      final stale =
          File('${iosDir.path}/premium_monthly.com.raynear.myapp.json')
            ..writeAsStringSync('{"stale": true}');

      await generateIapMetadataStep(
        projectRoot: tempRoot.path,
        config: config,
        verbose: false,
      );

      final pkg = config.packageName;
      expect(pkg, 'com.example.myapp',
          reason: 'template default package name');

      // Stale author-package file must be purged.
      expect(stale.existsSync(), isFalse,
          reason: 'stale com.raynear.myapp contract should be purged');

      // project.yaml defines: subscriptions premium_monthly + premium_yearly,
      // product premium_lifetime — across ios + android.
      const ids = ['premium_monthly', 'premium_yearly', 'premium_lifetime'];
      for (final platform in ['ios', 'android']) {
        for (final id in ids) {
          final f = File(
              '${tempRoot.path}/metadata/in_app_purchases/$platform/$id.$pkg.json');
          expect(f.existsSync(), isTrue, reason: '$platform/$id.$pkg.json');
          final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
          // iOS uses product_id, Android uses productId.
          final productId =
              (json['product_id'] ?? json['productId']).toString();
          expect(productId, contains(pkg));
          expect(productId, isNot(contains('raynear')));
        }
      }

      // No author namespace anywhere under the generated tree.
      final generated =
          Directory('${tempRoot.path}/metadata/in_app_purchases')
              .listSync(recursive: true)
              .whereType<File>();
      for (final f in generated) {
        expect(f.path, isNot(contains('raynear')),
            reason: 'filename leak: ${f.path}');
        expect(f.readAsStringSync(), isNot(contains('raynear')),
            reason: 'content leak: ${f.path}');
      }
    });
  });
}
