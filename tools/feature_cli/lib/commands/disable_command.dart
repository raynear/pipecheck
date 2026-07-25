import 'dart:io';
import 'package:args/command_runner.dart';
import '../feature_definitions.dart';
import '../utils.dart';

/// Disable command - 기능 비활성화
class DisableCommand extends Command<void> {
  @override
  final name = 'disable';

  @override
  final aliases = ['remove', 'off'];

  @override
  final description = '기능 플래그 비활성화';

  DisableCommand() {
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

    await disableFeature(featureName, dryRun: dryRun);
  }
}

Future<void> disableFeature(String featureName, {bool dryRun = false}) async {
  final feature = featureDefinitions[featureName.toLowerCase()];
  if (feature == null) {
    print('Error: Unknown feature "$featureName"');
    _printFeatures();
    exit(1);
  }

  print('${dryRun ? '[DRY RUN] ' : ''}Disabling feature: ${feature.displayName}\n');

  // Check for dependents
  for (final entry in featureDefinitions.entries) {
    if (entry.value.dependencies.contains(featureName)) {
      print('Warning: "${entry.value.displayName}" depends on this feature and may not work correctly.');
    }
  }

  // Update AppFeatureConfig
  print('Updating AppFeatureConfig...');
  for (final flag in feature.configFlags) {
    print('  Setting $flag = false');
    if (!dryRun) {
      await updateConfigFlag(flag, false);
    }
  }

  // Update app_config.yaml — 부팅 후까지 살아남는 유일한 런타임 입력.
  // features: 블록에 false를 기록 → gen_env가 FF_* 키로 방출 → 앱이 부팅 시 적용.
  print('Updating app_config.yaml features block...');
  if (dryRun) {
    print('  Would set ${feature.name}: false in features: block');
  } else {
    await updateAppConfigFeature(feature.name, false);
    print('  Set ${feature.name}: false');
    await regenerateEnv();
  }

  // Note about packages
  if (feature.packages.isNotEmpty) {
    print('\nPackages that can optionally be removed from pubspec.yaml:');
    for (final pkg in feature.packages) {
      print('  - $pkg');
    }
    print('\nNote: Only remove packages if not used by other features.');
  }

  // Note about files
  if (feature.filesToBackup.isNotEmpty) {
    print('\nRelated files (kept for reference):');
    for (final file in feature.filesToBackup) {
      print('  - $file');
    }
  }

  print('\n${dryRun ? '[DRY RUN] ' : ''}✓ Feature "${feature.displayName}" disabled!');

  if (!dryRun) {
    print('\nNote: env was auto-regenerated; the flag takes effect on next '
        'app build/run.');
    print('The code remains. To fully remove:');
    print('  - Remove unused packages from pubspec.yaml '
        '(then run: flutter pub get)');
    print('  - Delete related files if not needed');
  }
}

void _printFeatures() {
  print('\nAvailable Features:');
  for (final entry in featureDefinitions.entries) {
    print('  ${entry.key.padRight(15)} - ${entry.value.displayName}');
  }
  print('');
}
