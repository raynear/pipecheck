import 'dart:io';

import 'package:boilerplate/config/app_config.dart';
import 'package:boilerplate/config/app_feature_config.dart';
import 'package:boilerplate/core/services/remote_config_service.dart';
import 'package:flutter/material.dart';
import 'package:boilerplate/core/widgets/common/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:utils/utils.dart';

/// Semantic version comparison utility
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
  });

  factory SemanticVersion.parse(String version) {
    // Strip 'v' prefix if present
    final cleaned = version.startsWith('v') ? version.substring(1) : version;
    final parts = cleaned.split('.');
    return SemanticVersion(
      major: parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      minor: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      patch: parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;
  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;

  @override
  String toString() => '$major.$minor.$patch';
}

/// Update check result
enum UpdateStatus {
  /// App is up to date
  upToDate,
  /// Update available but not required
  updateAvailable,
  /// Update is mandatory
  updateRequired,
}

/// Force update service that checks app version against Remote Config
class ForceUpdateService {
  /// Check if update is needed
  static Future<UpdateStatus> checkForUpdate() async {
    if (!AppFeatureConfig.isForceUpdateEnabled) {
      return UpdateStatus.upToDate;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = SemanticVersion.parse(packageInfo.version);

      final remoteConfig = RemoteConfigService.instance;
      final minVersionStr = remoteConfig.minAppVersion;
      final minVersion = SemanticVersion.parse(minVersionStr);

      logger.d('ForceUpdate: current=$currentVersion, min=$minVersion');

      if (currentVersion < minVersion) {
        return UpdateStatus.updateRequired;
      }

      return UpdateStatus.upToDate;
    } catch (e) {
      logger.e('ForceUpdate: check failed: $e');
      return UpdateStatus.upToDate; // Fail open
    }
  }

  /// Show force update dialog (non-dismissible)
  static Future<void> showForceUpdateDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: SText('force_update.title'),
          content: SText('force_update.message'),
          actions: [
            FilledButton(
              onPressed: () => _openStore(),
              child: SText('force_update.button'),
            ),
          ],
        ),
      ),
    );
  }

  /// Open the appropriate app store
  static Future<void> _openStore() async {
    final Uri storeUrl;
    if (Platform.isIOS) {
      // App Store ID는 project.yaml listing.apple_app_id → gen_env 주입 (P1-15)
      final appStoreId = AppConfig.appleAppStoreId;
      if (appStoreId.isEmpty) {
        logger.w('ForceUpdate: listing.apple_app_id 미설정 - App Store를 열 수 없음');
        return;
      }
      storeUrl = Uri.parse('https://apps.apple.com/app/id$appStoreId');
    } else {
      final packageInfo = await PackageInfo.fromPlatform();
      storeUrl = Uri.parse(
        'https://play.google.com/store/apps/details?id=${packageInfo.packageName}',
      );
    }

    if (await canLaunchUrl(storeUrl)) {
      await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
    }
  }
}

/// Provider for update status
final updateStatusProvider = FutureProvider<UpdateStatus>((ref) async {
  return ForceUpdateService.checkForUpdate();
});
