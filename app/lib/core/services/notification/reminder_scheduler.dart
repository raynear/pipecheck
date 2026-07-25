import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utils/utils.dart';

import 'raynear_notification.dart';

/// 일일 리마인더 알림 설정
///
/// 매일 설정된 시간에 사용자에게 습관 실행을 상기시키는 알림을 보내는 설정입니다.
/// 각 항목은 알림 ID와 며칠 동안 연속으로 알림을 보낼지를 정의합니다.
final reminders = [
  {'id': 9022, 'after': 1},
  {'id': 9023, 'after': 2},
  {'id': 9024, 'after': 3},
  {'id': 9025, 'after': 4},
  {'id': 9026, 'after': 5},
  {'id': 9027, 'after': 6}
];

/// 리마인더 알림 스케줄러
///
/// 매일 설정된 시간에 사용자에게 습관 실행을 상기시키는 알림을 관리합니다.
class ReminderScheduler {
  final RaynearNotification _notificationService;

  ReminderScheduler(this._notificationService);

  /// 일일 리마인더 알림을 설정합니다.
  ///
  /// 사용자가 설정한 시간에 매일 습관 실행을 상기시키는 알림을 예약합니다.
  /// 오늘부터 시작하여 6일 동안 연속으로 알림을 설정합니다.
  ///
  /// @param ref Riverpod의 WidgetRef로 설정 정보를 읽어오는데 사용됩니다.
  ///           설정에서 지정한 알림 시간을 사용하며, 없으면 기본값으로 오후 8시를 사용합니다.
  Future<void> setReminderNotification({WidgetRef? ref}) async {
    // AppFeatureConfig 설정 확인
    if (!AppFeatureConfig.isNotificationEnabled || !AppFeatureConfig.isReminderEnabled) {
      logger.d('Reminder notification is disabled by AppFeatureConfig');
      return;
    }

    final settings = ref?.read(settingsProvider);

    await _notificationService.createNotification(
      id: 9021,
      groupKey: RaynearNotification.defaultGroupKey,
      channelKey: RaynearNotification.defaultChannelKey,
      title: 'service-notification.reminders.title0'.tr(),
      body: 'service-notification.noIdentity'.tr(),
      scheduleDate: DateTime.now(),
      scheduleTime: TimeOfDay(hour: settings?.reminderTime.hour ?? 20, minute: settings?.reminderTime.minute ?? 0),
    );

    for (int i = 0; i < reminders.length; i++) {
      final reminder = reminders[i];
      await _notificationService.createNotification(
        id: reminder['id'] as int,
        groupKey: RaynearNotification.defaultGroupKey,
        channelKey: RaynearNotification.defaultChannelKey,
        title: 'service-notification.reminders.title${i + 1}'.tr(),
        body: 'service-notification.noIdentity'.tr(),
        scheduleDate: DateTime.now().add(Duration(days: reminder['after'] as int)),
        scheduleTime: TimeOfDay(hour: settings?.reminderTime.hour ?? 20, minute: settings?.reminderTime.minute ?? 0),
      );
    }
  }

  Future<void> deleteReminderNotification() async {
    // AppFeatureConfig 설정 확인
    if (!AppFeatureConfig.isNotificationEnabled || !AppFeatureConfig.isReminderEnabled) {
      return;
    }

    await _notificationService.deleteChannelNotifications('9021');
    await _notificationService.deleteChannelNotifications('9022');
    await _notificationService.deleteChannelNotifications('9023');
    await _notificationService.deleteChannelNotifications('9024');
    await _notificationService.deleteChannelNotifications('9025');
    await _notificationService.deleteChannelNotifications('9026');
    await _notificationService.deleteChannelNotifications('9027');
  }

  /// 백그라운드 알림 등록
  Future<void> registerBackgroundNotification() async {
    // AppFeatureConfig 설정 확인
    if (!AppFeatureConfig.isNotificationEnabled || !AppFeatureConfig.isBackgroundNotificationEnabled) {
      logger.d('Background notification is disabled by AppFeatureConfig');
      return;
    }

    await _notificationService.createNotificationNow(
      id: 9001, // 특별한 ID를 사용하여 이 알림을 식별
      title: 'service-notification.backgroundNotification.title0'.tr(),
      body: 'service-notification.backgroundNotification.body0'.tr(args: ['']),
    );

    // 10분 후 알림
    final after10Minutes = DateTime.now().add(const Duration(minutes: 10));
    await _notificationService.createNotification(
      id: 9002, // 특별한 ID를 사용하여 이 알림을 식별
      groupKey: RaynearNotification.defaultGroupKey,
      channelKey: RaynearNotification.defaultChannelKey,
      title: 'service-notification.backgroundNotification.title1'.tr(),
      body: 'service-notification.backgroundNotification.body1'.tr(args: ['']),
      scheduleDate: after10Minutes,
      scheduleTime: TimeOfDay(hour: after10Minutes.hour, minute: after10Minutes.minute),
    );

    // 30분 후 알림
    final after30Minutes = DateTime.now().add(const Duration(minutes: 30));
    await _notificationService.createNotification(
      id: 9003, // 특별한 ID를 사용하여 이 알림을 식별
      groupKey: RaynearNotification.defaultGroupKey,
      channelKey: RaynearNotification.defaultChannelKey,
      title: 'service-notification.backgroundNotification.title2'.tr(),
      body: 'service-notification.backgroundNotification.body2'.tr(args: ['']),
      scheduleDate: after30Minutes,
      scheduleTime: TimeOfDay(hour: after30Minutes.hour, minute: after30Minutes.minute),
    );
  }

  /// 백그라운드 알림 제거
  Future<void> removeBackgroundNotification() async {
    // AppFeatureConfig 설정 확인
    if (!AppFeatureConfig.isNotificationEnabled || !AppFeatureConfig.isBackgroundNotificationEnabled) {
      return;
    }

    await _notificationService.deleteNotification(9001);
    await _notificationService.deleteNotification(9002);
    await _notificationService.deleteNotification(9003);
  }
}
