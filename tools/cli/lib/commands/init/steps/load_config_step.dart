import 'dart:io';

import 'package:boilerplate_cli/core/config_loader.dart';
import 'package:boilerplate_cli/core/logger/cli_logger.dart';

/// Result of loading configuration.
class LoadConfigResult {
  const LoadConfigResult({
    required this.appName,
    required this.packageName,
    required this.profile,
    required this.config,
    required this.hasConfig,
  });

  final String appName;
  final String packageName;
  final String profile;
  final ConfigLoader config;
  final bool hasConfig;
}

/// Loads app_config.yaml or prompts for interactive input.
Future<LoadConfigResult> loadConfigStep({
  required String projectRoot,
  required String? argName,
  required String? argPackage,
  required String? argProfile,
  required String configFileName,
  required bool verbose,
}) async {
  final configPath = '$projectRoot/$configFileName';
  final config = ConfigLoader(configPath);

  String appName;
  String packageName;
  String profile;
  bool hasConfig = false;

  if (File(configPath).existsSync()) {
    await config.load();
    hasConfig = true;
    appName = argName ?? config.appName;
    packageName = argPackage ?? config.packageName;
    profile = argProfile ?? config.profile;
  } else {
    appName = argName ?? '';
    packageName = argPackage ?? '';
    profile = argProfile ?? 'standard';

    if (appName.isEmpty || packageName.isEmpty) {
      appName = appName.isEmpty ? _prompt('앱 이름', 'My App') : appName;
      packageName = packageName.isEmpty
          ? _prompt('패키지명', 'com.example.myapp')
          : packageName;
      profile =
          _prompt('Profile (minimal/standard/premium/enterprise)', profile);
    }
  }

  if (verbose) {
    CliLogger.debug('앱 이름: $appName');
    CliLogger.debug('패키지명: $packageName');
    CliLogger.debug('Profile: $profile');
  }

  print('  앱 이름: $appName');
  print('  패키지명: $packageName');
  print('  Profile: $profile');
  print('');

  return LoadConfigResult(
    appName: appName,
    packageName: packageName,
    profile: profile,
    config: config,
    hasConfig: hasConfig,
  );
}

String _prompt(String label, String defaultValue) {
  stdout.write('  $label [$defaultValue]: ');
  final input = stdin.readLineSync()?.trim();
  return (input != null && input.isNotEmpty) ? input : defaultValue;
}
