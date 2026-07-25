// 점검 모드 플래그 배선 + MaintenanceService 게이트 테스트 (P2-23b).
//
// MaintenanceService는 RC `maintenance_mode`를 소스로 하지만, Firebase 없는
// 테스트 환경에서도 두 no-op 경로(플래그 OFF / RC 미초기화 fail-open)가
// 정상 사용자를 가두지 않음을 고정한다.

import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/services/maintenance_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('점검 모드 플래그 배선', () {
    test('minimal 프로파일(RC 없음) → 점검 모드 OFF', () {
      AppFeatureConfig.applyBootConfig(profileName: 'minimal');
      expect(AppFeatureConfig.isFirebaseRemoteConfigEnabled, false);
      expect(AppFeatureConfig.isMaintenanceModeEnabled, false);
    });

    test('standard 프로파일(RC 있음) → 점검 모드 안전망 ON', () {
      AppFeatureConfig.applyBootConfig(profileName: 'standard');
      expect(AppFeatureConfig.isFirebaseRemoteConfigEnabled, true);
      expect(AppFeatureConfig.isMaintenanceModeEnabled, true);
    });

    test('RC를 끄면 점검 모드도 의존성으로 함께 꺼진다', () {
      AppFeatureConfig.applyBootConfig(
        profileName: 'standard',
        overrides: {'isFirebaseRemoteConfigEnabled': false},
      );
      expect(AppFeatureConfig.isMaintenanceModeEnabled, false);
    });
  });

  group('MaintenanceService.isUnderMaintenance (fail-safe)', () {
    test('플래그 OFF면 RC를 보지 않고 즉시 false', () {
      AppFeatureConfig.applyBootConfig(profileName: 'minimal');
      expect(MaintenanceService.isUnderMaintenance(), false);
    });

    test('플래그 ON이라도 RC 미초기화면 false(fail-open)', () {
      // standard = 점검 플래그 ON. 테스트 환경엔 Firebase가 없어 RC 미초기화 →
      // maintenanceMode getter가 throw → catch → false.
      AppFeatureConfig.applyBootConfig(profileName: 'standard');
      expect(AppFeatureConfig.isMaintenanceModeEnabled, true);
      expect(MaintenanceService.isUnderMaintenance(), false);
    });
  });

  group('MaintenanceView', () {
    testWidgets('점검 카피와 아이콘을 렌더한다', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MaintenanceView()));
      // EasyLocalization 미초기화 테스트 환경 → .tr()는 키를 그대로 반환한다.
      expect(find.text('maintenance.title'), findsOneWidget);
      expect(find.byIcon(Icons.build_circle_outlined), findsOneWidget);
    });
  });
}
