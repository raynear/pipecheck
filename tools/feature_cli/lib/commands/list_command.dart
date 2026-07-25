import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import '../feature_definitions.dart';
import '../utils.dart';

/// List command - 사용 가능한 기능 목록 및 생성된 feature 목록
class ListCommand extends Command<void> {
  @override
  final name = 'list';

  @override
  final aliases = ['ls'];

  @override
  final description = '기능 목록 표시';

  ListCommand() {
    argParser.addFlag(
      'features',
      abbr: 'f',
      negatable: false,
      help: '생성된 feature 목록 표시',
    );
  }

  @override
  Future<void> run() async {
    final showFeatures = argResults!['features'] as bool;

    if (showFeatures) {
      await _listGeneratedFeatures();
    } else {
      _listAvailableToggles();
    }
  }
}

void _listAvailableToggles() {
  print('Available Feature Toggles:\n');
  print('${'Name'.padRight(15)} ${'Display Name'.padRight(35)} Packages');
  print('${'─' * 15} ${'─' * 35} ${'─' * 30}');

  for (final entry in featureDefinitions.entries) {
    final feature = entry.value;
    final packages = feature.packages.isEmpty ? '-' : feature.packages.join(', ');
    print('${entry.key.padRight(15)} ${feature.displayName.padRight(35)} $packages');
  }

  print('\nUsage:');
  print('  feature enable <name>   - Enable a feature');
  print('  feature disable <name>  - Disable a feature');
  print('  feature status          - Show current status');
}

Future<void> _listGeneratedFeatures() async {
  final featuresDir = Directory(getFeaturesDir());

  if (!await featuresDir.exists()) {
    print('Features directory not found');
    exit(1);
  }

  print('Generated Features:\n');
  print('${'Name'.padRight(20)} ${'Structure'.padRight(40)}');
  print('${'─' * 20} ${'─' * 40}');

  final dirs = await featuresDir.list().where((e) => e is Directory).toList();

  for (final dir in dirs) {
    final name = path.basename(dir.path);
    final structure = await _getFeatureStructure(dir.path);
    print('${name.padRight(20)} $structure');
  }

  print('\nUsage:');
  print('  feature generate -n <name>       - Create basic feature');
  print('  feature generate -n <name> --full - Create full feature structure');
}

Future<String> _getFeatureStructure(String dirPath) async {
  final parts = <String>[];

  if (await Directory(path.join(dirPath, 'views')).exists()) parts.add('views');
  if (await Directory(path.join(dirPath, 'models')).exists()) parts.add('models');
  if (await Directory(path.join(dirPath, 'view_models')).exists()) parts.add('view_models');
  if (await Directory(path.join(dirPath, 'widgets')).exists()) parts.add('widgets');
  if (await Directory(path.join(dirPath, 'repositories')).exists()) parts.add('repositories');

  return parts.join(', ');
}
