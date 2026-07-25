import 'package:ads/ads.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/router.dart';
import 'package:pipecheck/core/services/privacy_consent_service.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:pipecheck/core/widgets/dialogs/privacy_consent_dialog.dart';
import 'package:collection/collection.dart';
import 'package:firebase_services/firebase_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> {
  late KeyboardVisibilityController _keyboardVisibilityController;

  @override
  void initState() {
    super.initState();
    FirebaseService.logScreenView(screenName: 'SplashView');
    _keyboardVisibilityController = KeyboardVisibilityController();
    if (_keyboardVisibilityController.isVisible) {
      // 키보드가 보이면 숨깁니다.
      FocusScope.of(context).unfocus();
    }
    asyncNavigationCallback();
  }

  @override
  void dispose() {
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
      // 1순위: 앱 오프닝 광고 (isAppOpenAdEnabled가 활성화된 경우)
      if (AppFeatureConfig.isAppOpenAdEnabled) {
        final adReady = await AdService().waitForAppOpenAd(
          timeout: const Duration(seconds: 5),
        );

        if (adReady && mounted) {
          await AdService().showAppOpenAd(
            onAdDismissed: () {
              if (mounted) {
                _navigateToNextScreen(settings);
              }
            },
            onAdFailed: () {
              if (mounted) {
                _navigateToNextScreen(settings);
              }
            },
          );
          return; // 콜백에서 네비게이션 처리
        }
      }
      // 2순위: 스플래시 전면광고 (isSplashInterstitialAdEnabled가 활성화된 경우)
      else if (AppFeatureConfig.isSplashInterstitialAdEnabled) {
        final adReady = await AdService().waitForInterstitialAd(
          timeout: const Duration(seconds: 5),
        );

        if (adReady && mounted) {
          await AdService().showInterstitialAdWithCallback(
            onAdDismissed: () {
              if (mounted) {
                _navigateToNextScreen(settings);
              }
            },
            onAdFailed: () {
              if (mounted) {
                _navigateToNextScreen(settings);
              }
            },
          );
          return; // 콜백에서 네비게이션 처리
        }
      }
    }

    // 광고를 표시하지 않거나 로드 실패 시 바로 네비게이션
    _navigateToNextScreen(settings);
  }

  void _navigateToNextScreen(Settings settings) {
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
