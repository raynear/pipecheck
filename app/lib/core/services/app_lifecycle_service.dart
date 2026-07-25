import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/services/badge_service.dart';
import 'package:pipecheck/core/services/notification/notification.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utils/utils.dart';

/// Centralized app lifecycle management
///
/// Consolidates lifecycle handling from main.dart into a single service.
/// Usage: Initialize in MainApp's initState, call lifecycle methods from
/// didChangeAppLifecycleState.
class AppLifecycleService {
  final Ref _ref;
  RaynearNotification? _notification;

  AppLifecycleService(this._ref) {
    if (AppFeatureConfig.isNotificationEnabled) {
      _notification = RaynearNotification();
    }
  }

  /// Called when app starts
  Future<void> onAppStart() async {
    logger.d('AppLifecycle: app started');

    if (AppFeatureConfig.isNotificationEnabled) {
      if (AppFeatureConfig.isReEngagementEnabled) {
        _notification?.setReEngagementNotification();
      }
      if (AppFeatureConfig.isReminderEnabled) {
        _notification?.setReminderNotification();
      }
    }
  }

  /// Called when app resumes from background
  Future<void> onResumed() async {
    logger.d('AppLifecycle: resumed');

    // Remove background notifications
    if (AppFeatureConfig.isNotificationEnabled) {
      await _notification?.removeBackgroundNotification();
    }

    // Check badges — main.dart가 배지 시스템을 무조건 배선하므로 여기도
    // 무조건 검사 (죽은 isBadgeSystemEnabled 게이트는 P1-16에서 삭제)
    final badgeService = _ref.read(badgeServiceProvider);
    await badgeService.checkAndUpdateBadges();
  }

  /// Called when app goes to background
  void onPaused() {
    logger.d('AppLifecycle: paused');
  }

  /// Called when app becomes inactive
  void onInactive() {
    logger.d('AppLifecycle: inactive');
  }

  /// Called when app is detached
  void onDetached() {
    logger.d('AppLifecycle: detached');
  }

  /// Handle all lifecycle state changes
  Future<void> handleLifecycleChange(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await onResumed();
      case AppLifecycleState.paused:
        onPaused();
      case AppLifecycleState.inactive:
        onInactive();
      case AppLifecycleState.detached:
        onDetached();
      case AppLifecycleState.hidden:
        break;
    }
  }
}

/// Provider for AppLifecycleService
final appLifecycleServiceProvider = Provider<AppLifecycleService>((ref) {
  return AppLifecycleService(ref);
});
