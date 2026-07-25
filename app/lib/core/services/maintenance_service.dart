import 'package:boilerplate/config/app_feature_config.dart';
import 'package:boilerplate/core/services/remote_config_service.dart';
import 'package:boilerplate/core/widgets/common/semantics.dart';
import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

/// 점검 모드 서비스 (P2-23b).
///
/// Remote Config `maintenance_mode`(bool)를 소스로, 운영이 원격으로 앱 전체를
/// 점검 화면으로 차단할 수 있게 한다. 서버 코드 0줄(backend-direction) —
/// 콘솔에서 키만 켜면 다음 실행(또는 RC 캐시 만료 후)에 발동한다.
///
/// `force_update_service`와 같은 패턴: 플래그 게이트 + RC 백엔드 + fail-open.
/// `isMaintenanceModeEnabled`는 `isFirebaseRemoteConfigEnabled`에 의존하므로
/// firebase/RC 없는 포크에서는 자동 OFF = no-op이다.
class MaintenanceService {
  /// 점검 중인지 검사한다.
  ///
  /// 플래그가 꺼져 있으면(또는 RC 의존성으로 자동 OFF) 즉시 false.
  /// RC 미초기화/오류 시에도 false로 폴백한다(fail-open — 점검 모드 오류가
  /// 정상 사용자를 가두지 않도록).
  static bool isUnderMaintenance() {
    if (!AppFeatureConfig.isMaintenanceModeEnabled) return false;
    try {
      return RemoteConfigService.instance.maintenanceMode;
    } catch (e) {
      logger.w('Maintenance check failed (fail-open): $e');
      return false;
    }
  }

  /// 점검 화면을 전체 화면 비-해제 다이얼로그로 띄운다.
  ///
  /// force update 다이얼로그와 동일하게 뒤로가기/바깥 탭으로 닫을 수 없다 —
  /// 점검이 끝나면 운영이 RC 키를 끄고, 사용자는 앱을 재시작한다.
  static Future<void> showMaintenanceScreen(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => const MaintenanceView(),
    );
  }
}

/// 점검 중 전체 화면 (P2-23b).
///
/// i18n: 카피는 하드코딩 한국어 — `force_update_service`와 동일 패턴이며
/// P2-23d 하드코딩 i18n 스윕에서 함께 번역 키로 전환된다.
class MaintenanceView extends StatelessWidget {
  const MaintenanceView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  SText('maintenance.title',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SText('maintenance.message',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
