import 'dart:async';

import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/router.dart';
import 'package:pipecheck/core/services/deep_link_service.dart';
import 'package:pipecheck/core/services/force_update_service.dart';
import 'package:pipecheck/core/services/maintenance_service.dart';
import 'package:pipecheck/core/services/privacy_consent_service.dart';
import 'package:pipecheck/core/services/startup_ad.dart';
import 'package:pipecheck/core/services/whats_new_service.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:pipecheck/core/widgets/dialogs/privacy_consent_dialog.dart';
import 'package:pipecheck/core/widgets/dialogs/whats_new_dialog.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class SplashView extends ConsumerStatefulWidget {
  const SplashView({
    super.key,
    this.isUnderMaintenance = MaintenanceService.isUnderMaintenance,
    this.checkForUpdate = ForceUpdateService.checkForUpdate,
    this.showStartupAd = showSplashAd,
  });

  /// 점검 모드 판정 (테스트에서 대체).
  final bool Function() isUnderMaintenance;

  /// 강제 업데이트 판정 (테스트에서 대체).
  final Future<UpdateStatus> Function() checkForUpdate;

  /// 시작 광고 표시 (테스트에서 대체). 광고를 보여 줬으면 true — 이동은 [onDone]이 맡는다.
  final Future<bool> Function({required VoidCallback onDone}) showStartupAd;

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> {
  late KeyboardVisibilityController _keyboardVisibilityController;

  @override
  void initState() {
    super.initState();
    _keyboardVisibilityController = KeyboardVisibilityController();
    if (_keyboardVisibilityController.isVisible) {
      // 키보드가 보이면 숨깁니다.
      FocusScope.of(context).unfocus();
    }
    asyncNavigationCallback();
  }

  @override
  void dispose() {
    // 스플래시가 이동 없이 사라졌다 — 이후 웜 링크가 영원히 보류되지 않게.
    PendingDeepLink.markReady();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardDismissOnTap(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade700,
                Colors.purple.shade700,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/icon.png',
                        width: MediaQuery.of(context).size.width * 0.30,
                        height: MediaQuery.of(context).size.width * 0.30)
                    .animate()
                    .rotate(
                      begin: 0,
                      end: 0.12,
                      duration: const Duration(milliseconds: 1),
                    )
                    .moveY(
                      begin: -300,
                      end: 0,
                      curve: Curves.bounceOut,
                      duration: const Duration(milliseconds: 700),
                    )
                    .then()
                    .rotate(
                        begin: 0,
                        end: -0.12,
                        curve: Curves.easeInOut,
                        duration: const Duration(milliseconds: 200),
                        delay: const Duration(milliseconds: 300)),
                Image.asset(
                  'assets/images/BoilerPlate_font_logo.png',
                  width: MediaQuery.of(context).size.width * 0.5,
                  fit: BoxFit.contain,
                ),
                // Container(
                //   alignment: Alignment.center,
                //   color: Theme.of(context).colorScheme.surfaceBright,
                //   child: Lottie.asset('assets/lottie/splash.lottie',
                //       repeat: false,
                //       decoder: customDecoder,
                //       width: MediaQuery.of(context).size.width * 0.8,
                //       animate: !const bool.fromEnvironment('INTEGRATION_TEST', defaultValue: false)),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<LottieComposition?> customDecoder(List<int> bytes) {
    return LottieComposition.decodeZip(bytes, filePicker: (files) {
      return files.firstWhereOrNull((f) => f.name.startsWith('animations/') && f.name.endsWith('.json'));
    });
  }

  Future<void> asyncNavigationCallback() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // 점검 모드·강제 업데이트는 이동 **전에** 검사한다. 스플래시 위에 pageless 다이얼로그를
    // 띄워 두면 아래 context.replace가 그 다이얼로그까지 제거해 킬스위치가 무력화된다.
    // 차단되면 이동하지 않는다(다이얼로그는 닫히지 않는다).
    if (await _blockedByRemoteGate()) return;
    if (!mounted) return;

    // ATT 요청 (iOS only, 광고 또는 분석 기능 사용 시)
    if (AppFeatureConfig.isPrivacyConsentEnabled) {
      final consentService = ref.read(privacyConsentServiceProvider);
      await consentService.requestTrackingAuthorization();
      if (!mounted) return;

      // Privacy Consent 다이얼로그 표시 (미동의 시)
      final needsConsent = ref.read(needsConsentProvider);
      if (needsConsent) {
        await PrivacyConsentDialog.show(context);
        if (!mounted) return;
      }
    }

    final settings = ref.read(settingsProvider);

    // 프리미엄 사용자가 아닌 경우에만 광고 표시
    final shouldShowAd = AppFeatureConfig.isAdsEnabled &&
        !settings.isSubscriptionActive;

    if (shouldShowAd) {
      final shown = await widget.showStartupAd(onDone: () {
        if (mounted) _navigateToNextScreen(settings);
      });
      if (shown) return; // 콜백에서 네비게이션 처리
    }

    // 광고를 표시하지 않거나 로드 실패 시 바로 네비게이션
    _navigateToNextScreen(settings);
  }

  /// 점검 중이거나 강제 업데이트가 필요하면 차단 화면을 띄우고 true.
  /// RC 미초기화/네트워크 실패는 서비스가 fail-open이다.
  Future<bool> _blockedByRemoteGate() async {
    if (widget.isUnderMaintenance()) {
      await MaintenanceService.showMaintenanceScreen(context);
      return true;
    }
    if (AppFeatureConfig.isForceUpdateEnabled) {
      final status = await widget.checkForUpdate();
      if (!mounted) return true;
      if (status == UpdateStatus.updateRequired) {
        await ForceUpdateService.showForceUpdateDialog(context);
        return true;
      }
    }
    return false;
  }

  /// What's-new 다이얼로그 (P2-24) — 마이너 이상 버전 업 후 첫 실행에 1회.
  Future<void> _showWhatsNew(WhatsNewService whatsNew) async {
    final show = await whatsNew.shouldShow();
    await whatsNew.markSeen();
    if (!show) return;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) await WhatsNewDialog.show(ctx);
  }

  void _navigateToNextScreen(Settings settings) {
    final whatsNew = AppFeatureConfig.isWhatsNewEnabled
        ? ref.read(whatsNewServiceProvider)
        : null;
    _replaceWithNextScreen(settings);

    // 스플래시 이동이 끝났다 — 그 전에 도착한 딥링크(콜드 스타트 포함)를 이제 소비한다.
    // 온보딩 전이거나 잠금 화면이면 라우터 redirect가 목적지를 보관한 채 그쪽으로 튕기고,
    // 온보딩 완료·잠금 해제 뒤에 이어 연다.
    final pending = PendingDeepLink.markReady();
    if (pending != null) context.go(pending);

    // What's-new는 이동 뒤에 띄운다(스플래시 위에 띄우면 replace 때 사라진다).
    if (whatsNew != null) unawaited(_showWhatsNew(whatsNew));
  }

  void _replaceWithNextScreen(Settings settings) {
    // Check if onboarding feature is enabled and user hasn't completed onboarding
    if (AppFeatureConfig.isOnboardingEnabled && !settings.onBoard) {
      context.replace(Routes.onboarding);
    } else if (AppFeatureConfig.isAuthenticationEnabled &&
        settings.userAuthOption != UserAuthOption.none) {
      // 기존 '/authentication'은 등록되지 않은 죽은 경로였다 (실제 라우트는 /auth)
      context.replace(Routes.auth);
    } else {
      context.replace(Routes.home);
    }
  }
}
