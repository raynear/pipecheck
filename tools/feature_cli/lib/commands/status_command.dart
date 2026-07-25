import 'dart:io';
import 'package:args/command_runner.dart';
import '../feature_definitions.dart';
import '../utils.dart';

/// Status command - 현재 기능 상태 표시
class StatusCommand extends Command<void> {
  @override
  final name = 'status';

  @override
  final aliases = ['st'];

  @override
  final description = '현재 기능 상태 표시';

  @override
  Future<void> run() async {
    await showStatus();
  }
}

Future<void> showStatus() async {
  final configPath = getConfigFilePath();
  final configFile = File(configPath);

  if (!await configFile.exists()) {
    print('Error: AppFeatureConfig not found at $configPath');
    exit(1);
  }

  final content = await configFile.readAsString();

  print('Feature Status:\n');
  print('${'Feature'.padRight(20)} ${'Status'.padRight(10)} Flags');
  print('${'─' * 20} ${'─' * 10} ${'─' * 40}');

  for (final entry in featureDefinitions.entries) {
    final feature = entry.value;
    final allEnabled = feature.configFlags.every((flag) {
      final regex = RegExp(r'static\s+(?:const\s+)?bool\s+' + flag + r'\s*=\s*true');
      return regex.hasMatch(content);
    });
    final anyEnabled = feature.configFlags.any((flag) {
      final regex = RegExp(r'static\s+(?:const\s+)?bool\s+' + flag + r'\s*=\s*true');
      return regex.hasMatch(content);
    });

    String status;
    if (allEnabled) {
      status = '✓ ON';
    } else if (anyEnabled) {
      status = '◐ PARTIAL';
    } else {
      status = '✗ OFF';
    }

    print('${entry.key.padRight(20)} ${status.padRight(10)} ${feature.configFlags.join(', ')}');
  }

  print('\n${'─' * 70}');
  print('✓ ON = All flags enabled');
  print('◐ PARTIAL = Some flags enabled');
  print('✗ OFF = All flags disabled');
}
