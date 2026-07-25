import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

/// 알림 이벤트를 처리하는 컨트롤러 (앱-무관).
///
/// Awesome Notifications의 이벤트 리스너에서 호출되는 정적 메서드들을 포함합니다.
/// 알림 생성, 표시, 액션 수신 등의 이벤트를 처리합니다.
///
/// 알림 탭 시 라우트 이동은 앱이 [onNavigate]로 주입한다 — 패키지는 앱 라우터에
/// 의존하지 않는다.
class NotificationController {
  /// 알림 탭으로 라우트 이동을 처리하는 앱 주입 콜백.
  ///
  /// 앱이 부팅 시점에 설정한다:
  /// `NotificationController.onNavigate = (route) => rootNavigatorKey.currentContext?.go(route);`
  static void Function(String route)? onNavigate;

  /// 새로운 알림이 생성되거나 스케줄링될 때 호출됩니다.
  ///
  /// @param receivedNotification 생성된 알림 정보
  @pragma('vm:entry-point')
  static Future<void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {
    // logger.d('onNotificationCreatedMethod $receivedNotification');
  }

  /// Use this method to detect every time that a new notification is displayed
  @pragma('vm:entry-point')
  static Future<void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {
    // Your code goes here
    // logger.d('onNotificationDisplayedMethod $receivedNotification');
  }

  /// Use this method to detect if the user dismissed a notification
  @pragma('vm:entry-point')
  static Future<void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {
    // Your code goes here
    // logger.d('onDismissActionReceivedMethod $receivedAction');
  }

  /// Use this method to detect when the user taps on a notification or action button
  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    // logger.d('onActionReceivedMethod $receivedAction');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // payload에서 route 정보 추출
      final String? data = receivedAction.payload?['data'];

      if (data != null && data.isNotEmpty) {
        try {
          // JSON 중첩 문제 처리
          Map<String, dynamic> decodedData;

          try {
            // 첫 번째 시도: 일반 JSON 형식 (정상적인 경우)
            decodedData = jsonDecode(data);
          } catch (e) {
            // JSON 문자열이 이스케이프된 경우 (중첩 JSON 문제)
            logger.w('첫 번째 JSON 디코딩 실패, 중첩 JSON 형식 시도: $e');

            // 중첩된 JSON에서 'data' 키를 다시 추출
            final match = RegExp(r'"data"\s*:\s*"(.+?)"').firstMatch(data);
            if (match != null && match.groupCount >= 1) {
              final innerData = match.group(1)?.replaceAll(r'\"', '"');
              if (innerData != null) {
                decodedData = jsonDecode(innerData);
              } else {
                throw Exception('내부 데이터 추출 실패');
              }
            } else {
              throw Exception('중첩된 데이터 형식 파싱 실패');
            }
          }

          final String? route = decodedData['route'];
          if (route != null && route.isNotEmpty) {
            // 앱이 주입한 네비게이션 핸들러로 라우트 이동
            onNavigate?.call(route);
          } else {
            logger.w('알림에 유효한 라우트 정보가 없습니다: $decodedData');
          }
        } catch (e) {
          logger.e('알림 페이로드 파싱 오류: $e\n원본 데이터: $data');
        }
      } else {
        logger.w('No valid data in the notification.');
      }
    });
  }
}
