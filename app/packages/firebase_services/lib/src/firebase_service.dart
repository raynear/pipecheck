import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart' show NavigatorObserver;
import 'package:utils/utils.dart';

import 'firebase_config.dart';

/// Firebase Analytics를 안전하게 래핑하는 유틸리티 클래스.
///
/// Firebase가 초기화되지 않았거나 기능 플래그가 꺼진 경우에도 앱이 정상
/// 동작하도록 모든 Analytics 작업을 안전하게 가드한다. 앱은 부팅 시점에
/// [configure]로 자신의 기능 플래그를 주입한다.
///
/// 주요 기능:
/// - Firebase 초기화 상태 확인 (`Firebase.apps`, 초기화는 하지 않음)
/// - Analytics 이벤트 / 화면 뷰 안전 로깅
/// - 동의(consent) · 수집 토글 · 세션/사용자 프로퍼티 설정
/// - 네비게이션 옵저버 제공
///
/// 모든 메서드는 static으로 제공되며 인스턴스를 생성할 수 없다.
class FirebaseService {
  FirebaseService._();

  static FirebaseServicesConfig _config =
      const FirebaseServicesConfig.disabled();

  /// 앱이 부팅 시점에 기능 플래그를 주입한다. 호출 전에는 모든 작업이 no-op.
  static void configure(FirebaseServicesConfig config) {
    _config = config;
  }

  /// Firebase가 초기화되었는지 확인
  static bool get isInitialized {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      logger.e('Error checking Firebase initialization: $e');
      return false;
    }
  }

  /// Firebase Analytics가 사용 가능한지 확인
  static bool get isAnalyticsAvailable {
    try {
      if (!_config.firebaseEnabled || !_config.analyticsEnabled) {
        return false;
      }
      return isInitialized;
    } catch (e) {
      logger.e('Error checking Firebase Analytics availability: $e');
      return false;
    }
  }

  /// 안전하게 Analytics 이벤트를 로깅합니다.
  ///
  /// Firebase Analytics가 사용 가능한 경우에만 이벤트를 전송하며,
  /// 사용 불가능한 경우에는 경고 로그만 출력하고 앱은 정상적으로 계속 실행됩니다.
  ///
  /// @param name 이벤트 이름 (필수)
  /// @param parameters 이벤트와 함께 전송할 추가 매개변수
  /// @param callOptions Analytics 호출 옵션
  ///
  /// 사용 예시:
  /// ```dart
  /// FirebaseService.logEvent(
  ///   name: 'habit_created',
  ///   parameters: {'habit_name': 'Exercise', 'frequency': 'daily'},
  /// );
  /// ```
  static void logEvent({
    required String name,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) {
    if (!isAnalyticsAvailable) {
      logger.w('Firebase Analytics is not available, skipping event: $name');
      return;
    }

    try {
      FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
        callOptions: callOptions,
      );
      logger.d('Firebase Analytics event logged: $name');
    } catch (e) {
      logger.e('Failed to log Firebase Analytics event: $e');
    }
  }

  /// 화면 뷰 이벤트를 안전하게 로깅합니다.
  ///
  /// 사용자가 특정 화면을 볼 때 추적합니다.
  /// Firebase Analytics가 사용 가능한 경우에만 이벤트를 전송합니다.
  ///
  /// @param screenClass 화면 클래스 이름 (예: 'HomeView')
  /// @param screenName 화면 이름 (예: 'home_screen')
  /// @param parameters 추가 매개변수
  /// @param callOptions Analytics 호출 옵션
  ///
  /// 사용 예시:
  /// ```dart
  /// FirebaseService.logScreenView(
  ///   screenName: 'habit_detail',
  ///   screenClass: 'HabitDetailView',
  ///   parameters: {'habit_id': '123'},
  /// );
  /// ```
  static void logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) {
    if (!isAnalyticsAvailable) {
      logger.w(
          'Firebase Analytics is not available, skipping screen view: ${screenName ?? 'unknown'}');
      return;
    }

    try {
      FirebaseAnalytics.instance.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
        parameters: parameters,
        callOptions: callOptions,
      );
      logger.d(
          'Firebase Analytics screen view logged: ${screenName ?? 'auto-detected'}');
    } catch (e) {
      logger.e('Failed to log Firebase Analytics screen view: $e');
    }
  }

  /// 개인정보 동의 상태를 Analytics에 반영합니다 (GDPR consent mode).
  static Future<void> setConsent({
    required bool analyticsStorageConsentGranted,
    required bool adStorageConsentGranted,
  }) async {
    if (!isAnalyticsAvailable) return;
    try {
      await FirebaseAnalytics.instance.setConsent(
        analyticsStorageConsentGranted: analyticsStorageConsentGranted,
        adStorageConsentGranted: adStorageConsentGranted,
      );
    } catch (e) {
      logger.e('Failed to set Firebase Analytics consent: $e');
    }
  }

  /// Analytics 수집 on/off.
  static Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    if (!isAnalyticsAvailable) return;
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
    } catch (e) {
      logger.e('Failed to set Firebase Analytics collection: $e');
    }
  }

  /// 세션 타임아웃 설정.
  static Future<void> setSessionTimeoutDuration(Duration timeout) async {
    if (!isAnalyticsAvailable) return;
    try {
      await FirebaseAnalytics.instance.setSessionTimeoutDuration(timeout);
    } catch (e) {
      logger.e('Failed to set Firebase Analytics session timeout: $e');
    }
  }

  /// 사용자 프로퍼티 설정.
  static Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (!isAnalyticsAvailable) return;
    try {
      await FirebaseAnalytics.instance.setUserProperty(name: name, value: value);
    } catch (e) {
      logger.e('Failed to set Firebase Analytics user property: $e');
    }
  }

  /// GoRouter 등에 연결할 네비게이션 옵저버.
  ///
  /// Analytics가 사용 불가능하면 null을 반환한다 (옵저버 미연결).
  /// `FirebaseAnalyticsObserver`는 `NavigatorObserver`이므로 앱은
  /// firebase_analytics를 import하지 않고 이 값을 사용할 수 있다.
  static NavigatorObserver? _observer;
  static NavigatorObserver? get navigatorObserver {
    if (!_config.firebaseEnabled || !_config.analyticsEnabled) return null;
    try {
      return _observer ??=
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);
    } catch (e) {
      logger.e('Failed to create FirebaseAnalyticsObserver: $e');
      return null;
    }
  }
}
