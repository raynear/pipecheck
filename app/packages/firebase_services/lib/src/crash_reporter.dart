import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show FlutterErrorDetails;
import 'package:utils/utils.dart';

import 'firebase_config.dart';

/// Firebase Crashlytics를 안전하게 래핑하는 에러 리포트 seam.
///
/// 앱의 에러 핸들러가 Crashlytics를 직접 import하지 않도록 인버전한다.
/// Firebase가 초기화되지 않았거나 기능 플래그가 꺼진 경우 모든 작업은
/// 안전하게 no-op이며, 리포트 실패가 앱을 절대 크래시시키지 않는다.
///
/// `kDebugMode`에서 리포트를 건너뛰는 결정은 호출자(앱)에 남긴다 — 이 seam은
/// 플래그·초기화 가드만 담당한다.
class CrashReporter {
  CrashReporter._();

  static FirebaseServicesConfig _config =
      const FirebaseServicesConfig.disabled();

  /// 앱이 부팅 시점에 기능 플래그를 주입한다. 호출 전에는 모든 작업이 no-op.
  static void configure(FirebaseServicesConfig config) {
    _config = config;
  }

  static bool get _available {
    try {
      return _config.firebaseEnabled &&
          _config.crashlyticsEnabled &&
          Firebase.apps.isNotEmpty;
    } catch (e) {
      logger.e('Error checking Crashlytics availability: $e');
      return false;
    }
  }

  /// 캐치된/치명적 에러를 Crashlytics에 기록.
  static Future<void> recordError(
    dynamic error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!_available) return;
    try {
      await FirebaseCrashlytics.instance
          .recordError(error, stack, reason: reason, fatal: fatal);
    } catch (_) {
      // Crashlytics 리포트는 절대 앱을 크래시시키면 안 된다.
    }
  }

  /// Flutter 프레임워크 에러를 Crashlytics에 기록.
  static void recordFlutterError(FlutterErrorDetails details) {
    if (!_available) return;
    try {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    } catch (_) {
      // 동일 — 리포트 실패가 앱을 크래시시키면 안 된다.
    }
  }

  /// Crashlytics 수집 on/off (초기화 가드만, custom key는 별도).
  static Future<void> setCollectionEnabled(bool enabled) async {
    if (!_config.firebaseEnabled || !_config.crashlyticsEnabled) return;
    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(enabled);
    } catch (e) {
      logger.w('Failed to set Crashlytics collection: $e');
    }
  }

  /// 크래시 분류용 커스텀 키 설정.
  static Future<void> setCustomKey(String key, Object value) async {
    if (!_available) return;
    try {
      await FirebaseCrashlytics.instance.setCustomKey(key, value);
    } catch (e) {
      logger.w('Failed to set Crashlytics custom key "$key": $e');
    }
  }
}
