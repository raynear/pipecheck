import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:firebase_services/firebase_services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orange/orange.dart';
import 'package:utils/utils.dart';

/// User's privacy consent choices
class PrivacyConsent {
  final bool analyticsConsent;
  final bool adConsent;
  final bool crashReportingConsent;
  final int consentVersion;
  final DateTime? consentDate;

  const PrivacyConsent({
    this.analyticsConsent = false,
    this.adConsent = false,
    this.crashReportingConsent = false,
    this.consentVersion = 0,
    this.consentDate,
  });

  PrivacyConsent copyWith({
    bool? analyticsConsent,
    bool? adConsent,
    bool? crashReportingConsent,
    int? consentVersion,
    DateTime? consentDate,
  }) {
    return PrivacyConsent(
      analyticsConsent: analyticsConsent ?? this.analyticsConsent,
      adConsent: adConsent ?? this.adConsent,
      crashReportingConsent: crashReportingConsent ?? this.crashReportingConsent,
      consentVersion: consentVersion ?? this.consentVersion,
      consentDate: consentDate ?? this.consentDate,
    );
  }

  Map<String, dynamic> toJson() => {
    'analyticsConsent': analyticsConsent,
    'adConsent': adConsent,
    'crashReportingConsent': crashReportingConsent,
    'consentVersion': consentVersion,
    'consentDate': consentDate?.toIso8601String(),
  };

  factory PrivacyConsent.fromJson(Map<String, dynamic> json) => PrivacyConsent(
    analyticsConsent: json['analyticsConsent'] as bool? ?? false,
    adConsent: json['adConsent'] as bool? ?? false,
    crashReportingConsent: json['crashReportingConsent'] as bool? ?? false,
    consentVersion: json['consentVersion'] as int? ?? 0,
    consentDate: json['consentDate'] != null
      ? DateTime.tryParse(json['consentDate'] as String)
      : null,
  );

  bool get hasConsented => consentVersion > 0;
}

/// Current consent version - increment when terms change
const int currentConsentVersion = 1;

/// 저장된 동의를 SDK(분석·ad_storage·Crashlytics)에 적용하는 함수. 테스트에서 대체한다.
typedef ConsentApplier = Future<void> Function(PrivacyConsent consent);

/// 동의를 넘겨받는 SDK 3종 호출. 기본값은 실제 Firebase 호출이다.
class ConsentSdk {
  const ConsentSdk({
    this.setConsent = FirebaseService.setConsent,
    this.setAnalyticsCollectionEnabled =
        FirebaseService.setAnalyticsCollectionEnabled,
    this.setCrashCollectionEnabled = CrashReporter.setCollectionEnabled,
  });

  final Future<void> Function({
    required bool analyticsStorageConsentGranted,
    required bool adStorageConsentGranted,
  })
  setConsent;
  final Future<void> Function(bool enabled) setAnalyticsCollectionEnabled;
  final Future<void> Function(bool enabled) setCrashCollectionEnabled;
}

/// Service to manage user privacy consent
class PrivacyConsentService {
  PrivacyConsentService({ConsentApplier? applier})
    : _apply = applier ?? applyToSdks;

  final ConsentApplier _apply;

  static const String _keyAnalytics = 'privacy_analytics_consent';
  static const String _keyAd = 'privacy_ad_consent';
  static const String _keyCrash = 'privacy_crash_consent';
  static const String _keyVersion = 'privacy_consent_version';
  static const String _keyDate = 'privacy_consent_date';

  /// 저장된 동의를 동기로 읽는다 (Orange는 메모리 캐시를 동기로 읽는다).
  /// Notifier.build()가 첫 읽기부터 실제 값을 돌려주려면 동기여야 한다.
  PrivacyConsent loadConsentSync() {
    try {
      final version = Orange.getInt(_keyVersion);
      if (version != null) {
        final dateString = Orange.getString(_keyDate);
        return PrivacyConsent(
          analyticsConsent: Orange.getBool(_keyAnalytics) ?? false,
          adConsent: Orange.getBool(_keyAd) ?? false,
          crashReportingConsent: Orange.getBool(_keyCrash) ?? false,
          consentVersion: version,
          consentDate: dateString != null ? DateTime.tryParse(dateString) : null,
        );
      }
    } catch (e) {
      logger.e('PrivacyConsent: failed to load: $e');
    }
    return const PrivacyConsent();
  }

  /// Save consent to storage
  Future<void> saveConsent(PrivacyConsent consent) async {
    try {
      Orange.setBool(_keyAnalytics, consent.analyticsConsent);
      Orange.setBool(_keyAd, consent.adConsent);
      Orange.setBool(_keyCrash, consent.crashReportingConsent);
      Orange.setInt(_keyVersion, consent.consentVersion);
      if (consent.consentDate != null) {
        Orange.setString(_keyDate, consent.consentDate!.toIso8601String());
      }
      await _apply(consent);
      logger.d('PrivacyConsent: saved and applied');
    } catch (e) {
      logger.e('PrivacyConsent: failed to save: $e');
    }
  }

  /// 부팅 시 저장된 동의를 SDK에 적용한다.
  ///
  /// 동의 기능이 꺼진 앱은 동의 UI가 없으므로 전부 허용(기존 동작).
  /// 켜져 있으면 저장값을 따르고, 아직 동의하지 않았다면 전부 거부 상태다.
  Future<void> applyStoredConsent() async {
    final consent = AppFeatureConfig.isPrivacyConsentEnabled
        ? loadConsentSync()
        : const PrivacyConsent(
            analyticsConsent: true,
            adConsent: true,
            crashReportingConsent: true,
          );
    await _apply(consent);
  }

  /// Apply consent settings to Firebase and other services.
  ///
  /// 네이티브 수집 기본은 OFF라 이 함수가 Analytics·Crashlytics를 켜는 유일한 경로다.
  /// [sdk]는 테스트가 SDK 호출을 기록하려고 갈아끼우는 자리다.
  static Future<void> applyToSdks(
    PrivacyConsent consent, {
    ConsentSdk sdk = const ConsentSdk(),
  }) async {
    // 플래그·초기화 가드는 FirebaseService가 담당한다 (firebase_services 패키지).
    await sdk.setConsent(
      analyticsStorageConsentGranted: consent.analyticsConsent,
      adStorageConsentGranted: consent.adConsent,
    );
    await sdk.setAnalyticsCollectionEnabled(consent.analyticsConsent);
    await sdk.setCrashCollectionEnabled(consent.crashReportingConsent);
  }

  /// Request ATT permission (iOS only)
  Future<bool> requestTrackingAuthorization() async {
    if (!Platform.isIOS) return true;

    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        final result = await AppTrackingTransparency.requestTrackingAuthorization();
        return result == TrackingStatus.authorized;
      }
      return status == TrackingStatus.authorized;
    } catch (e) {
      logger.e('PrivacyConsent: ATT request failed: $e');
      return false;
    }
  }

  /// Check if consent needs to be (re)collected
  bool needsConsent(PrivacyConsent current) {
    if (!AppFeatureConfig.isPrivacyConsentEnabled) return false;
    return !current.hasConsented || current.consentVersion < currentConsentVersion;
  }

  /// 광고 개인화 허용 여부 (동기 — 광고 로드 경로가 매 요청 시 호출).
  ///
  /// 동의 미수집 상태는 보수적으로 false를 돌린다 (NPA 폴백).
  /// 부팅 직후 프리로드는 NPA로 나가고, 사용자가 동의 다이얼로그에서
  /// 허용하면 이후 로드부터 개인화 광고가 나간다.
  static bool personalizedAdsAllowedSync() {
    try {
      final version = Orange.getInt(_keyVersion);
      if (version == null || version < 1) return false;
      return Orange.getBool(_keyAd) ?? false;
    } catch (e) {
      logger.w('PrivacyConsent: sync ad consent read failed: $e');
      return false;
    }
  }
}

/// Privacy consent service provider
final privacyConsentServiceProvider = Provider<PrivacyConsentService>((ref) {
  return PrivacyConsentService();
});

/// Privacy consent state provider
class PrivacyConsentNotifier extends Notifier<PrivacyConsent> {
  @override
  PrivacyConsent build() =>
      ref.read(privacyConsentServiceProvider).loadConsentSync();

  Future<void> updateConsent({
    bool? analyticsConsent,
    bool? adConsent,
    bool? crashReportingConsent,
  }) async {
    final updated = state.copyWith(
      analyticsConsent: analyticsConsent ?? state.analyticsConsent,
      adConsent: adConsent ?? state.adConsent,
      crashReportingConsent: crashReportingConsent ?? state.crashReportingConsent,
      consentVersion: currentConsentVersion,
      consentDate: DateTime.now(),
    );
    state = updated;
    await ref.read(privacyConsentServiceProvider).saveConsent(updated);
  }

  Future<void> acceptAll() async {
    await updateConsent(
      analyticsConsent: true,
      adConsent: true,
      crashReportingConsent: true,
    );
  }

  Future<void> rejectAll() async {
    await updateConsent(
      analyticsConsent: false,
      adConsent: false,
      crashReportingConsent: false,
    );
  }
}

final privacyConsentProvider = NotifierProvider<PrivacyConsentNotifier, PrivacyConsent>(
  PrivacyConsentNotifier.new,
);

/// Whether consent dialog needs to be shown
final needsConsentProvider = Provider<bool>((ref) {
  final consent = ref.watch(privacyConsentProvider);
  final service = ref.read(privacyConsentServiceProvider);
  return service.needsConsent(consent);
});
