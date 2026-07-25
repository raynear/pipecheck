import 'package:boilerplate/config/app_feature_config.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

import 'raynear_notification.dart';

/// 재참여 알림 설정
///
/// 사용자가 앱을 사용하지 않은 기간에 따라 재참여를 유도하는 알림을 보내는 설정입니다.
/// 각 항목은 알림 ID와 며칠 후에 알림을 보낼지를 정의합니다.
final reEngagements = [
  {'id': 9011, 'after': 3},
  {'id': 9012, 'after': 7},
  {'id': 9013, 'after': 14},
  {'id': 9014, 'after': 30},
  {'id': 9015, 'after': 60},
  {'id': 9016, 'after': 90},
  {'id': 9017, 'after': 120},
  {'id': 9018, 'after': 150},
  {'id': 9019, 'after': 180},
];

/// 재참여 알림 스케줄러
///
/// 사용자가 앱을 사용하지 않은 기간에 따라 단계별로 재참여를 유도하는 알림을 예약합니다.
class ReEngagementScheduler {
  final RaynearNotification _notificationService;

  ReEngagementScheduler(this._notificationService);

  /// 재참여 알림을 설정합니다.
  ///
  /// 사용자가 앱을 사용하지 않은 기간에 따라 단계별로 재참여를 유도하는 알림을 예약합니다.
  /// 3일, 7일, 14일, 30일 등 점진적으로 기간을 늘려가며 알림을 설정합니다.
  ///
  /// 모든 재참여 알림은 오전 9시 30분에 발송되도록 예약됩니다.
  Future<void> setReEngagementNotification() async {
    // AppFeatureConfig 설정 확인
    if (!AppFeatureConfig.isNotificationEnabled || !AppFeatureConfig.isReEngagementEnabled) {
      logger.d('Re-engagement notification is disabled by AppFeatureConfig');
      return;
    }

    logger.d('localization: setReEngagementNotification');
    for (int i = 0; i < reEngagements.length; i++) {
      final reEngagement = reEngagements[i];
      await _notificationService.createNotification(
        id: reEngagement['id'] as int, // 특별한 ID를 사용하여 이 알림을 식별
        groupKey: RaynearNotification.defaultGroupKey,
        channelKey: RaynearNotification.defaultChannelKey,
        title: 'service-notification.reEngagement.title$i'.tr(),
        body: 'service-notification.reEngagement.body$i'.tr(),
        scheduleDate: DateTime.now().add(Duration(days: reEngagement['after'] as int)),
        scheduleTime: TimeOfDay(hour: 9, minute: 30),
      );
    }
  }
}
