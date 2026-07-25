// Data Safety 생성기 테스트 (P1-13f)

import 'dart:convert';

import 'package:boilerplate_cli/commands/datasafety/data_safety_generator.dart';
import 'package:test/test.dart';

DataSafetyInputs inputs({
  bool ads = false,
  bool analytics = false,
  bool crash = false,
  bool emailAuth = false,
  bool subscription = false,
  bool notifications = false,
  bool location = false,
  bool accountDeletion = false,
}) {
  return DataSafetyInputs(
    adsEnabled: ads,
    analyticsEnabled: analytics,
    crashReportingEnabled: crash,
    emailAuthEnabled: emailAuth,
    subscriptionEnabled: subscription,
    notificationsEnabled: notifications,
    locationEnabled: location,
    accountDeletionEnabled: accountDeletion,
  );
}

void main() {
  group('entriesFor (활성 기능 셋 → 항목 매핑)', () {
    test('전부 꺼짐 → 수집 항목 없음', () {
      expect(entriesFor(inputs()), isEmpty);
    });

    test('광고 → 광고 ID 수집 + 제3자 공유', () {
      final entries = entriesFor(inputs(ads: true));
      expect(entries.length, 1);
      expect(entries.single.shared, true);
      expect(entries.single.purposes, contains('Advertising or marketing'));
    });

    test('email auth → Email/User ID 수집 선언 (Firebase Auth — P1-16.5b)',
        () {
      expect(entriesFor(inputs()), isEmpty);
      final entries = entriesFor(inputs(emailAuth: true));
      expect(entries.map((e) => e.dataType), contains('Email address'));
      expect(entries.map((e) => e.dataType), contains('User IDs'));
      expect(entries.every((e) => e.source.contains('Firebase Auth')), true);
    });

    test('crashlytics → 크래시/진단 2종, 공유 없음', () {
      final entries = entriesFor(inputs(crash: true));
      expect(entries.length, 2);
      expect(entries.every((e) => !e.shared), true);
    });
  });

  group('renderMarkdown', () {
    test('수집 없음 → No data collected 안내', () {
      final md = renderMarkdown(inputs(), appName: 'TestApp');
      expect(md, contains('No data collected'));
      expect(md, contains('Data Not Collected'));
    });

    test('계정 삭제 켜짐 → 삭제 요청 경로 "예"', () {
      final md = renderMarkdown(
          inputs(emailAuth: true, accountDeletion: true),
          appName: 'TestApp');
      expect(md, contains('Delete Account'));
      expect(md, contains('삭제 요청 경로: **예**'));
    });

    test('광고 켜짐 → ATT/Used to Track You 안내 포함', () {
      final md = renderMarkdown(inputs(ads: true), appName: 'TestApp');
      expect(md, contains('Used to Track You'));
      expect(md, contains('ATT'));
    });
  });

  group('renderJson', () {
    test('유효한 JSON + 항목 수 일치', () {
      final json = renderJson(
          inputs(ads: true, analytics: true, crash: true),
          appName: 'TestApp');
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['app'], 'TestApp');
      expect((decoded['entries'] as List).length,
          entriesFor(inputs(ads: true, analytics: true, crash: true)).length);
    });
  });

  group('renderAppPrivacyJson (Apple App Privacy 업로드 스키마)', () {
    // fastlane 2.233.0 upload_app_privacy_details_to_app_store가 받는
    // App Store Connect ID 화이트리스트 (spaceship AppDataUsage*).
    const validCategories = {
      'DEVICE_ID', 'PRODUCT_INTERACTION', 'CRASH_DATA', 'PERFORMANCE_DATA',
      'EMAIL_ADDRESS', 'USER_ID', 'PURCHASE_HISTORY', 'COARSE_LOCATION',
    };
    const validPurposes = {
      'THIRD_PARTY_ADVERTISING', 'DEVELOPERS_ADVERTISING', 'ANALYTICS',
      'PRODUCT_PERSONALIZATION', 'APP_FUNCTIONALITY', 'OTHER_PURPOSES',
    };
    const validProtections = {
      'DATA_USED_TO_TRACK_YOU', 'DATA_LINKED_TO_YOU',
      'DATA_NOT_LINKED_TO_YOU', 'DATA_NOT_COLLECTED',
    };

    test('수집 없음 → [{data_protections: [DATA_NOT_COLLECTED]}]', () {
      final decoded = jsonDecode(renderAppPrivacyJson(inputs())) as List;
      expect(decoded.length, 1);
      expect((decoded.single as Map)['data_protections'],
          ['DATA_NOT_COLLECTED']);
    });

    test('광고 → DEVICE_ID + 추적 선언', () {
      final decoded =
          jsonDecode(renderAppPrivacyJson(inputs(ads: true))) as List;
      final device = decoded
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['category'] == 'DEVICE_ID');
      expect(device['purposes'], contains('THIRD_PARTY_ADVERTISING'));
      expect(device['data_protections'], contains('DATA_USED_TO_TRACK_YOU'));
    });

    test('email auth → EMAIL_ADDRESS/USER_ID는 linked', () {
      final decoded =
          jsonDecode(renderAppPrivacyJson(inputs(emailAuth: true))) as List;
      final email = decoded
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['category'] == 'EMAIL_ADDRESS');
      expect(email['data_protections'], contains('DATA_LINKED_TO_YOU'));
      expect(email['data_protections'],
          isNot(contains('DATA_USED_TO_TRACK_YOU')));
    });

    test('같은 카테고리(DEVICE_ID)는 병합 — 광고+분석+알림 → 1개 항목', () {
      final decoded = jsonDecode(renderAppPrivacyJson(
              inputs(ads: true, analytics: true, notifications: true)))
          as List;
      final devices = decoded
          .cast<Map<String, dynamic>>()
          .where((e) => e['category'] == 'DEVICE_ID')
          .toList();
      expect(devices.length, 1, reason: 'DEVICE_ID는 단일 항목으로 병합되어야 함');
      final purposes = (devices.single['purposes'] as List).cast<String>();
      expect(purposes, containsAll(['THIRD_PARTY_ADVERTISING', 'ANALYTICS',
          'APP_FUNCTIONALITY']));
      // 추적(광고) OR 비추적(분석/알림) → 추적 우선
      expect(devices.single['data_protections'],
          contains('DATA_USED_TO_TRACK_YOU'));
    });

    test('모든 category/purpose/protection이 ASC 유효 ID', () {
      final decoded = jsonDecode(renderAppPrivacyJson(inputs(
        ads: true, analytics: true, crash: true, emailAuth: true,
        subscription: true, notifications: true, location: true,
      ))) as List;
      for (final entry in decoded.cast<Map<String, dynamic>>()) {
        expect(validCategories, contains(entry['category']));
        for (final p in (entry['purposes'] as List).cast<String>()) {
          expect(validPurposes, contains(p));
        }
        for (final d in (entry['data_protections'] as List).cast<String>()) {
          expect(validProtections, contains(d));
        }
        // 정확히 하나의 linkage 선언 (+ 선택적 추적)
        final prot = (entry['data_protections'] as List).cast<String>();
        final linkage = prot
            .where((d) =>
                d == 'DATA_LINKED_TO_YOU' || d == 'DATA_NOT_LINKED_TO_YOU')
            .length;
        expect(linkage, 1);
      }
    });
  });
}
