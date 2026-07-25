import 'dart:io';
import 'package:args/command_runner.dart';
import '../feature_definitions.dart';
import '../utils.dart';

/// Enable command - 기능 활성화
class EnableCommand extends Command<void> {
  @override
  final name = 'enable';

  @override
  final aliases = ['add', 'on'];

  @override
  final description = '기능 플래그 활성화';

  EnableCommand() {
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: '변경 사항 미리보기 (실제 변경 없음)',
    );
  }

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      print('Error: Feature name required');
      _printFeatures();
      exit(1);
    }

    final featureName = argResults!.rest.first;
    final dryRun = argResults!['dry-run'] as bool;

    await enableFeature(featureName, dryRun: dryRun);
  }
}

Future<void> enableFeature(String featureName, {bool dryRun = false}) async {
  final feature = featureDefinitions[featureName.toLowerCase()];
  if (feature == null) {
    print('Error: Unknown feature "$featureName"');
    _printFeatures();
    exit(1);
  }

  print('${dryRun ? '[DRY RUN] ' : ''}Enabling feature: ${feature.displayName}\n');

  // Check dependencies
  for (final dep in feature.dependencies) {
    final depFeature = featureDefinitions[dep];
    if (depFeature != null) {
      print('Note: This feature depends on "$dep"');
    }
  }

  // Update AppFeatureConfig
  print('Updating AppFeatureConfig...');
  for (final flag in feature.configFlags) {
    print('  Setting $flag = true');
    if (!dryRun) {
      await updateConfigFlag(flag, true);
    }
  }

  // Update app_config.yaml — 부팅 후까지 살아남는 유일한 런타임 입력.
  // featureName(소문자 CLI 인자)을 features: 블록에 기록 → gen_env가 FF_* 키로
  // 방출 → 앱이 부팅 시 적용.
  print('Updating app_config.yaml features block...');
  if (dryRun) {
    print('  Would set ${feature.name}: true in features: block');
  } else {
    await updateAppConfigFeature(feature.name, true);
    print('  Set ${feature.name}: true');
    await regenerateEnv();
  }

  // Note about packages
  if (feature.packages.isNotEmpty) {
    print('\nPackages to ensure are in pubspec.yaml:');
    for (final pkg in feature.packages) {
      print('  - $pkg');
    }
    print('\nRun "flutter pub get" if packages were added.');
  }

  print('\n${dryRun ? '[DRY RUN] ' : ''}✓ Feature "${feature.displayName}" enabled!');

  if (!dryRun) {
    print('\nNext steps:');
    print('  - env was auto-regenerated; the flag takes effect on next '
        'app build/run.');
    if (feature.packages.isNotEmpty) {
      print('  - If packages were added to pubspec.yaml, run: flutter pub get');
    }
    print('  - Configure required credentials in .env (real secrets only).');
    print('  - See docs/EXTERNAL_SETUP_CHECKLIST.md for setup details.');
  }
}

void _printFeatures() {
  print('\nAvailable Features:');
  for (final entry in featureDefinitions.entries) {
    print('  ${entry.key.padRight(15)} - ${entry.value.displayName}');
  }
  print('');
}
