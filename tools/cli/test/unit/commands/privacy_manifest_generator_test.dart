// Privacy Manifest 생성기 테스트 (P1-13d)

import 'package:boilerplate_cli/commands/privacy/privacy_manifest_generator.dart';
import 'package:test/test.dart';

void main() {
  group('generatePrivacyManifest', () {
    test('광고 앱: tracking true + 광고 데이터 타입 선언', () {
      final xml = generatePrivacyManifest(
        tracking: true,
        trackingDomains: ['track.example.com'],
        adsEnabled: true,
        analyticsEnabled: true,
        crashReportingEnabled: true,
      );

      expect(xml, contains('<key>NSPrivacyTracking</key>\n\t<true/>'));
      expect(xml, contains('<string>track.example.com</string>'));
      expect(xml, contains('NSPrivacyCollectedDataTypeDeviceID'));
      expect(xml, contains('NSPrivacyCollectedDataTypeAdvertisingData'));
      expect(xml,
          contains('NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising'));
      expect(xml, contains('NSPrivacyCollectedDataTypeProductInteraction'));
      expect(xml, contains('NSPrivacyCollectedDataTypeCrashData'));
    });

    test('광고 없는 앱: tracking false + 광고 데이터 타입 미선언', () {
      final xml = generatePrivacyManifest(
        tracking: false,
        trackingDomains: [],
        adsEnabled: false,
        analyticsEnabled: true,
        crashReportingEnabled: true,
      );

      expect(xml, contains('<key>NSPrivacyTracking</key>\n\t<false/>'));
      expect(xml, contains('<key>NSPrivacyTrackingDomains</key>\n\t<array/>'));
      expect(xml, isNot(contains('NSPrivacyCollectedDataTypeDeviceID')));
      expect(xml, isNot(contains('ThirdPartyAdvertising')));
      expect(xml, contains('NSPrivacyCollectedDataTypeProductInteraction'));
    });

    test('전부 꺼진 앱: 수집 타입 빈 배열 + UserDefaults 사유는 항상 선언', () {
      final xml = generatePrivacyManifest(
        tracking: false,
        trackingDomains: [],
        adsEnabled: false,
        analyticsEnabled: false,
        crashReportingEnabled: false,
      );

      expect(xml, contains('<key>NSPrivacyCollectedDataTypes</key>\n\t<array/>'));
      // shared_preferences(Orange) 경유 UserDefaults — 앱 수준 필수 사유 API
      expect(xml, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
      expect(xml, contains('<string>CA92.1</string>'));
    });

    test('도메인 XML 이스케이프', () {
      final xml = generatePrivacyManifest(
        tracking: true,
        trackingDomains: ['a&b.com'],
        adsEnabled: true,
        analyticsEnabled: false,
        crashReportingEnabled: false,
      );
      expect(xml, contains('<string>a&amp;b.com</string>'));
    });

    test('유효한 plist 구조 (선언/루트 태그)', () {
      final xml = generatePrivacyManifest(
        tracking: false,
        trackingDomains: [],
        adsEnabled: false,
        analyticsEnabled: false,
        crashReportingEnabled: false,
      );
      expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(xml, contains('<plist version="1.0">'));
      expect(xml.trim(), endsWith('</plist>'));
    });
  });

  group('collectedDataTypesFor', () {
    test('광고만: 트래킹 타입 2종', () {
      final types = collectedDataTypesFor(
          adsEnabled: true, analyticsEnabled: false, crashReportingEnabled: false);
      expect(types.length, 2);
      expect(types.every((t) => t.tracking), true);
    });

    test('crashlytics: 크래시+성능, 트래킹 아님', () {
      final types = collectedDataTypesFor(
          adsEnabled: false, analyticsEnabled: false, crashReportingEnabled: true);
      expect(types.length, 2);
      expect(types.every((t) => !t.tracking), true);
    });
  });
}
