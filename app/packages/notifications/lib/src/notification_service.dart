import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:orange/orange.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:utils/utils.dart';

import 'notification_controller.dart';
import 'notifications_config.dart';

/// 로컬 알림을 관리하는 핵심 엔진 (앱-무관).
///
/// Awesome Notifications 기반으로 로컬 알림 생성/수정/삭제, 채널/그룹 관리,
/// 권한 관리, 스케줄링을 처리한다. FCM은 이 클래스에 없다 — 앱이 소유한다.
///
/// 앱은 부팅 시점에 [configure]로 기능 플래그를 주입한다. 앱 특화 정책
/// (재참여/리마인더 스케줄러 등)은 이 클래스를 상속/사용하는 앱 측에 둔다.
///
/// 싱글톤 패턴을 사용하여 앱 전체에서 하나의 인스턴스만 사용된다.
/// 앱 서브클래스는 `super.protected()`로 기반 생성자를 호출한다.
class NotificationService {
  static final NotificationService _instance = NotificationService.protected();
  factory NotificationService() => _instance;

  /// 서브클래스(앱의 fork 정체성 클래스)가 호출하는 기반 생성자.
  /// 과거 private `_internal()`이었으나 패키지 경계를 넘는 상속을 위해 공개.
  NotificationService.protected();

  static NotificationsConfig _config = const NotificationsConfig.disabled();

  /// 앱이 부팅 시점에 기능 플래그를 주입한다. 호출 전에는 모든 작업이 no-op.
  static void configure(NotificationsConfig config) {
    _config = config;
  }

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  static const String _channelsKey = 'notification_channels';
  static const String _groupsKey = 'notification_groups';
  static const String defaultGroupKey = 'default';
  static const String defaultChannelKey = 'default';
  List<NotificationChannelGroup> _groups = [
    NotificationChannelGroup(
      channelGroupKey: defaultGroupKey,
      channelGroupName: 'Default',
    )
  ];
  List<NotificationChannel> _channels = [
    NotificationChannel(
      channelGroupKey: defaultGroupKey,
      channelKey: defaultChannelKey,
      channelName: 'Default',
      channelDescription: 'Default',
      defaultColor: const Color(0xFF9D50DD),
      ledColor: Colors.white,
      importance: NotificationImportance.High,
    )
  ]; // 활성 채널 목록을 저장

  List<NotificationChannelGroup> get groups => _groups;
  List<NotificationChannel> get channels => _channels;

  // 받아와야 하는 것
  String? get defaultIcon => null;

  bool? get debugMode => false;

  /// 알림 서비스를 초기화합니다.
  ///
  /// 다음과 같은 초기화 작업을 수행합니다:
  /// 1. 타임존 설정 (Asia/Seoul)
  /// 2. Awesome Notifications 초기화
  /// 3. 알림 이벤트 리스너 설정
  ///
  /// 이 메서드는 앱 시작 시 한 번만 호출되어야 합니다.
  Future<void> initialize() async {
    // 알림이 비활성화되어 있으면 아무것도 초기화하지 않음
    if (!_config.notificationEnabled) {
      logger.d('Notification service is disabled by config - skipping all initialization');
      return;
    }

    // NOTE: 중복 초기화 가드를 두지 않는다 — createGroup/createChannel이
    // _addGroup/_deleteGroup에서 initialize()를 재호출해 갱신된 그룹/채널을
    // AwesomeNotifications에 재등록하기 때문(가드를 넣으면 신규 그룹 미등록).

    // Timezone 초기화
    tz.initializeTimeZones();
    final String timeZoneName = 'Asia/Seoul'; // 또는 사용자 설정에서 가져오기
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // Awesome Notifications 초기화
    await _restoreGroups();
    await _restoreChannels();

    await AwesomeNotifications().initialize(
      defaultIcon,
      _channels,
      channelGroups: _groups,
      debug: debugMode ?? false,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AwesomeNotifications().setListeners(
        onActionReceivedMethod: NotificationController.onActionReceivedMethod,
        onNotificationCreatedMethod: NotificationController.onNotificationCreatedMethod,
        onNotificationDisplayedMethod: NotificationController.onNotificationDisplayedMethod,
        onDismissActionReceivedMethod: NotificationController.onDismissActionReceivedMethod,
      );
    });

    _isInitialized = true;
  }

  Future<void> _restoreGroups() async {
    final String? groupsJson = Orange.getString(_groupsKey);
    if (groupsJson != null) {
      logger.d(groupsJson);
      final List<dynamic> groupsList = jsonDecode(groupsJson);
      final restoredGroups = groupsList.map((groupMap) {
        return NotificationChannelGroup(
          channelGroupKey: groupMap['channelGroupKey'],
          channelGroupName: groupMap['channelGroupName'],
        );
      }).toList();

      // default 그룹이 복원된 데이터에 없으면 기존 default 유지
      final hasDefaultGroup = restoredGroups.any((group) => group.channelGroupKey == defaultGroupKey);
      if (!hasDefaultGroup) {
        // 기존 default 그룹을 맨 앞에 유지하고 복원된 그룹들 추가
        _groups = [
          NotificationChannelGroup(
            channelGroupKey: defaultGroupKey,
            channelGroupName: 'Default',
          ),
          ...restoredGroups,
        ];
      } else {
        // default 그룹이 복원된 데이터에 있으면 복원된 데이터 사용
        _groups = restoredGroups;
      }
    }
    // groupsJson이 null이면 기존 default 그룹 유지
  }

  Future<void> _saveGroups() async {
    final String groupsJson = jsonEncode(_groups.map((group) => group.toMap()).toList());
    Orange.setString(_groupsKey, groupsJson);
  }

  Future<void> _addGroup(NotificationChannelGroup group) async {
    _groups.add(group);
    await _saveGroups();

    await initialize();
  }

  Future<void> _deleteGroup(String groupKey) async {
    // 1. 해당 그룹에 속한 채널들을 먼저 찾아서 별도 리스트에 저장
    final channelsToDelete = _channels.where((channel) => channel.channelGroupKey == groupKey).toList();

    // 2. 각 채널의 모든 알림들을 삭제하고 채널도 삭제
    for (var channel in channelsToDelete) {
      final channelKey = channel.channelKey ?? '';

      // 채널의 모든 알림 삭제
      await deleteChannelNotifications(channelKey);

      // 채널 삭제 (AwesomeNotifications에서 먼저 삭제)
      await AwesomeNotifications().cancelNotificationsByChannelKey(channelKey);
      await AwesomeNotifications().removeChannel(channelKey);
    }

    // 3. 로컬 _channels 리스트에서 해당 채널들 제거
    _channels.removeWhere((channel) => channel.channelGroupKey == groupKey);
    await _saveChannels();

    // 4. 그룹의 모든 알림 삭제 (그룹 레벨에서도 삭제)
    await AwesomeNotifications().cancelNotificationsByGroupKey(groupKey);

    // 5. 로컬 _groups 리스트에서 그룹 제거
    _groups.removeWhere((group) => group.channelGroupKey == groupKey);
    await _saveGroups();

    // 6. 마지막에 초기화
    await initialize();
  }

  Future<void> _restoreChannels() async {
    final String? channelsJson = Orange.getString(_channelsKey);
    if (channelsJson != null) {
      final List<dynamic> channelsList = jsonDecode(channelsJson);
      final restoredChannels = channelsList.map((channelMap) {
        return NotificationChannel(
          channelGroupKey: channelMap['groupKey'],
          channelKey: channelMap['channelKey'],
          channelName: channelMap['channelName'],
          channelDescription: channelMap['channelDescription'],
          defaultColor: Color(channelMap['defaultColor'] ?? 0xFF9D50DD),
          ledColor: Color(channelMap['ledColor'] ?? 0xFFFFFFFF),
          importance: NotificationImportance.values.firstWhere(
            (e) => e.toString() == 'NotificationImportance.${channelMap['importance']}',
            orElse: () => NotificationImportance.Default,
          ),
        );
      }).toList();

      // default 채널이 복원된 데이터에 없으면 기존 default 유지
      final hasDefaultChannel = restoredChannels.any((channel) => channel.channelKey == defaultChannelKey);
      if (!hasDefaultChannel) {
        // 기존 default 채널을 맨 앞에 유지하고 복원된 채널들 추가
        _channels = [
          NotificationChannel(
            channelGroupKey: defaultGroupKey,
            channelKey: defaultChannelKey,
            channelName: 'Default',
            channelDescription: 'Default',
            defaultColor: const Color(0xFF9D50DD),
            ledColor: Colors.white,
            importance: NotificationImportance.High,
          ),
          ...restoredChannels,
        ];
      } else {
        // default 채널이 복원된 데이터에 있으면 복원된 데이터 사용
        _channels = restoredChannels;
      }
    }
    // channelsJson이 null이면 기존 default 채널 유지
  }

  Future<void> _saveChannels() async {
    final String channelsJson = jsonEncode(_channels.map((channel) => channel.toMap()).toList());
    Orange.setString(_channelsKey, channelsJson);
  }

  Future<void> _addChannel(NotificationChannel channel) async {
    await AwesomeNotifications().setChannel(channel);
    _channels.add(channel);
    await _saveChannels();
  }

  Future<void> _deleteChannel(String channelKey) async {
    _channels.removeWhere((channel) => channel.channelKey == channelKey);
    await _saveChannels();
    await AwesomeNotifications().cancelNotificationsByChannelKey(channelKey);
    await AwesomeNotifications().removeChannel(channelKey);
  }

  // 앱 전체 알림 관리
  Future<List<NotificationModel>> getAppNotifications() async {
    if (!_config.notificationEnabled) {
      return [];
    }

    // 초기화 확인
    if (!isInitialized) {
      return [];
    }

    final scheduledNotifications = await AwesomeNotifications().listScheduledNotifications();
    return scheduledNotifications;
  }

  Future<void> pauseAppNotification() async {
    if (!_config.notificationEnabled) {
      return;
    }

    // 초기화 확인
    if (!isInitialized) {
      return;
    }

    for (var channel in _channels) {
      await AwesomeNotifications().setChannel(
        NotificationChannel(
          channelGroupKey: channel.channelGroupKey,
          channelKey: channel.channelKey,
          channelName: channel.channelName,
          channelDescription: channel.channelDescription,
          defaultColor: channel.defaultColor,
          ledColor: channel.ledColor,
          importance: NotificationImportance.None,
        ),
      );
    }
  }

  Future<void> resumeAppNotification() async {
    if (!_config.notificationEnabled) {
      return;
    }

    // 초기화 확인
    if (!isInitialized) {
      return;
    }

    for (var channel in _channels) {
      await AwesomeNotifications().setChannel(
        NotificationChannel(
          channelGroupKey: channel.channelGroupKey,
          channelKey: channel.channelKey,
          channelName: channel.channelName,
          channelDescription: channel.channelDescription,
          defaultColor: channel.defaultColor,
          ledColor: channel.ledColor,
          importance: NotificationImportance.High,
        ),
      );
    }
  }

  Future<void> deleteAppNotification() async {
    if (!_config.notificationEnabled) {
      return;
    }

    // 초기화 확인
    if (!isInitialized) {
      return;
    }

    await AwesomeNotifications().cancelAll();

    _groups.clear();
    _channels.clear();

    await _saveGroups();
    await _saveChannels();

    logger.d('모든 앱 알림과 그룹 및 채널이 삭제되었습니다.');
  }

  // group 관리
  Future<void> createGroup(String groupKey, String groupName) async {
    if (!_config.notificationEnabled) {
      return;
    }

    await _addGroup(NotificationChannelGroup(
      channelGroupKey: groupKey,
      channelGroupName: groupName,
    ));
  }

  Future<void> deleteGroup(String groupKey) async {
    if (!_config.notificationEnabled) {
      return;
    }

    await _deleteGroup(groupKey);
  }

  Future<void> pauseGroupNotifications(String groupKey) async {
    for (var channel in _channels) {
      if (channel.channelGroupKey == groupKey) {
        pauseChannelNotifications(channel.channelKey ?? '');
      }
    }
  }

  Future<void> resumeGroupNotifications(String groupKey) async {
    for (var channel in _channels) {
      if (channel.channelGroupKey == groupKey) {
        resumeChannelNotifications(channel.channelKey ?? '');
      }
    }
  }

  Future<void> deleteGroupNotifications(String groupKey) async {
    await AwesomeNotifications().cancelNotificationsByGroupKey(groupKey);
  }

  Future<List<NotificationModel>> getGroupNotifications(String groupKey) async {
    final notifications = await getAppNotifications();

    // where를 사용하여 새 리스트 생성 (Concurrent modification 에러 방지)
    return notifications.where((notification) => notification.content?.groupKey == groupKey).toList();
  }

  // channel 관리
  Future<void> createChannel(String groupKey, String channelKey) async {
    if (!_config.notificationEnabled) {
      return;
    }

    final channel = NotificationChannel(
      channelGroupKey: groupKey,
      channelKey: channelKey,
      channelName: '$channelKey Notification',
      channelDescription: 'Notification channel for $channelKey',
      defaultColor: const Color(0xFF9D50DD),
      ledColor: Colors.white,
      importance: NotificationImportance.High,
    );

    await _addChannel(channel);
  }

  Future<void> deleteChannel(String channelKey) async {
    if (!_config.notificationEnabled) {
      return;
    }

    _deleteChannel(channelKey);
  }

  Future<void> pauseChannelNotifications(String channelKey) async {
    try {
      final channel = _channels.firstWhere((channel) => channel.channelKey == channelKey);

      channel.importance = NotificationImportance.None;

      await AwesomeNotifications().setChannel(channel);
    } catch (e) {
      logger.e('pauseChannelNotifications $e');
    }
  }

  Future<void> resumeChannelNotifications(String channelKey) async {
    try {
      final channel = _channels.firstWhere((channel) => channel.channelKey == channelKey);

      channel.importance = NotificationImportance.High;

      await AwesomeNotifications().setChannel(channel);
    } catch (e) {
      logger.e('pauseChannelNotifications $e');
    }
  }

  Future<void> deleteChannelNotifications(String channelKey) async {
    await AwesomeNotifications().cancelNotificationsByChannelKey(channelKey);
  }

  Future<List<NotificationModel>> getChannelNotifications(String channelKey) async {
    final notifications = await getAppNotifications();

    // where를 사용하여 새 리스트 생성 (Concurrent modification 에러 방지)
    return notifications.where((notification) => notification.content?.channelKey == channelKey).toList();
  }

  /// 새로운 알림을 생성합니다.
  ///
  /// 단일 알림, 예약 알림, 반복 알림을 생성할 수 있습니다.
  ///
  /// @param id 알림의 고유 ID
  /// @param groupKey 알림이 속할 그룹 키
  /// @param channelKey 알림이 속할 채널 키
  /// @param title 알림 제목
  /// @param body 알림 본문
  /// @param scheduleDate 알림을 보낼 날짜 (null이면 오늘)
  /// @param scheduleTime 알림을 보낼 시간
  /// @param repeats 반복 여부
  /// @param weekdays 요일별 반복 설정 (월요일부터 일요일까지 7개의 bool 배열)
  /// @param payload 알림과 함께 전달할 추가 데이터
  ///
  /// @return 생성된 알림의 ID
  Future<int> createNotification({
    required int id,
    required String groupKey,
    required String channelKey,
    required String title,
    required String body,
    DateTime? scheduleDate,
    required TimeOfDay scheduleTime,
    bool repeats = false,
    List<bool>? weekdays,
    String? payload,
  }) async {
    if (!_config.notificationEnabled) {
      logger.d('Notification is disabled by config - cannot create notification');
      return 0;
    }

    // initialize 호출안하고 실행되었으면 호출
    if (isInitialized == false) {
      await initialize();
    }

    await requestPermissionIfNeeded();

    // 채널이 이미 존재하는지 확인
    if (!_channels.any((channel) => channel.channelKey == channelKey)) {
      await createChannel(groupKey, channelKey);
    }

    // 그룹이 이미 존재하는지 확인
    if (!_groups.any((group) => group.channelGroupKey == groupKey)) {
      await createGroup(groupKey, groupKey);
    }

    // payload 처리 개선
    Map<String, String>? finalPayload;
    if (payload != null) {
      // 이미 JSON 형식인 경우 중복 인코딩 방지
      finalPayload = {'data': payload};
    }

    if (scheduleDate != null) {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: channelKey,
          groupKey: groupKey,
          title: title,
          body: body,
          payload: finalPayload,
        ),
        schedule: NotificationCalendar(
          year: scheduleDate.year,
          month: scheduleDate.month,
          day: scheduleDate.day,
          hour: scheduleTime.hour,
          minute: scheduleTime.minute,
          second: 0,
          repeats: repeats,
        ),
      );
    } else if (weekdays != null) {
      // 시간 유효성 검증
      final validHour = scheduleTime.hour.clamp(0, 23);
      final validMinute = scheduleTime.minute.clamp(0, 59);

      for (int index = 0; index < weekdays.length; index++) {
        var weekday = weekdays[index];
        if (weekday) {
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: int.parse('${index + 1}${id.toString().padLeft(3, '0')}'),
              channelKey: channelKey,
              groupKey: groupKey,
              title: title,
              body: body,
              payload: finalPayload,
            ),
            schedule: NotificationCalendar(
              weekday: index,
              hour: validHour,
              minute: validMinute,
              repeats: repeats,
            ),
          );
        }
      }
    } else {
      // 시간 유효성 검증
      final validHour = scheduleTime.hour.clamp(0, 23);
      final validMinute = scheduleTime.minute.clamp(0, 59);

      // 과거 시간으로 스케줄링 방지
      DateTime finalScheduleDate = scheduleDate ?? DateTime.now();
      final scheduledDateTime = DateTime(
        finalScheduleDate.year,
        finalScheduleDate.month,
        finalScheduleDate.day,
        validHour,
        validMinute,
      );

      // 만약 과거 시간이면 다음 날로 설정
      if (scheduledDateTime.isBefore(DateTime.now())) {
        finalScheduleDate = finalScheduleDate.add(const Duration(days: 1));
      }

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: int.parse('8${id.toString().padLeft(3, '0')}'),
          channelKey: channelKey,
          groupKey: groupKey,
          title: title,
          body: body,
          payload: finalPayload,
        ),
        schedule: NotificationCalendar(
          year: finalScheduleDate.year,
          month: finalScheduleDate.month,
          day: finalScheduleDate.day,
          hour: validHour,
          minute: validMinute,
          repeats: repeats,
        ),
      );
    }

    return id;
  }

  Future<int> updateNotification({
    required int notificationId,
    String? title,
    String? body,
    TimeOfDay? scheduleTime,
    bool? repeats = true,
    List<bool>? weekdays,
    String? payload,
  }) async {
    if (!_config.notificationEnabled) {
      logger.d('Notification is disabled by config');
      return 0;
    }

    final notification = await getNotification(notificationId);

    if (notification == null) {
      return 0;
    }

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: notificationId,
        channelKey: notification.content?.channelKey ?? '',
        title: title ?? notification.content?.title ?? '',
        body: body ?? notification.content?.body ?? '',
        payload: payload != null ? {'data': payload} : notification.content?.payload,
      ),
      schedule: NotificationCalendar(
        weekday: notification.schedule?.toMap()['weekday'] ?? 0,
        hour: scheduleTime?.hour ?? notification.schedule?.toMap()['hour'] ?? 0,
        minute: scheduleTime?.minute ?? notification.schedule?.toMap()['minute'] ?? 0,
        repeats: repeats ?? notification.schedule?.toMap()['repeats'] ?? true,
      ),
    );

    return notificationId;
  }

  Future<void> createNotificationNow({
    int? id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_config.notificationEnabled) {
      logger.d('Notification is disabled by config');
      return;
    }

    // 초기화 확인
    if (!isInitialized) {
      logger.d('Notification service not initialized');
      return;
    }

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        groupKey: defaultGroupKey,
        channelKey: defaultChannelKey,
        id: id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        payload: payload != null ? {'data': payload} : null,
      ),
    );
  }

  Future<NotificationModel?> getNotification(int id) async {
    if (!_config.notificationEnabled) {
      return null;
    }

    // 초기화 확인
    if (!isInitialized) {
      return null;
    }

    final notifications = await getAppNotifications();
    return notifications.firstWhere((notification) => notification.content?.id == id);
  }

  Future<void> deleteNotification(int id) async {
    if (!_config.notificationEnabled) {
      return;
    }

    // 초기화 확인
    if (!isInitialized) {
      return;
    }

    await AwesomeNotifications().cancel(id);
  }

  Future<void> requestPermissionIfNeeded() async {
    if (!_config.notificationEnabled) {
      return;
    }

    // 초기화 확인
    if (!isInitialized) {
      return;
    }

    final isAllowed = await isNotificationAllowed();
    if (!isAllowed) {
      final wasGranted = await requestPermission();
      if (!wasGranted) {
        throw PlatformException(
          code: 'PERMISSION_DENIED',
          message: 'Notification permission denied',
        );
      }
    }
  }

  Future<bool> requestPermission() async {
    if (!_config.notificationEnabled) {
      return false;
    }

    // 초기화 확인
    if (!isInitialized) {
      return false;
    }

    final result = await AwesomeNotifications().requestPermissionToSendNotifications();
    return result;
  }

  Future<bool> isNotificationAllowed() async {
    if (!_config.notificationEnabled) {
      return false;
    }

    // 초기화 확인
    if (!isInitialized) {
      return false;
    }

    return await AwesomeNotifications().isNotificationAllowed();
  }

  /// OS 알림 권한 상태를 직접 조회한다 (초기화/플래그 무가드 — 권한 UI 전용).
  ///
  /// 권한 요청 화면이 서비스 초기화 전에도 OS 권한 상태를 확인할 수 있도록
  /// [isNotificationAllowed]의 `_isInitialized` 게이트 없이 통과시킨다.
  Future<bool> isNotificationAllowedRaw() =>
      AwesomeNotifications().isNotificationAllowed();

  /// OS 알림 권한을 직접 요청한다 (초기화/플래그 무가드 — 권한 UI 전용).
  Future<bool> requestPermissionRaw() =>
      AwesomeNotifications().requestPermissionToSendNotifications();
}
