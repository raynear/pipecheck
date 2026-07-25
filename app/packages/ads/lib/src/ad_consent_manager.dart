import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:utils/utils.dart';

import 'ads_config.dart';

/// AdMob UMP/EEA 동의 + NPA 폴백 + COPPA 노브 (P1-13c)
///
/// 광고 스택 단일 지점(core/services/ad/)에 구현한다 —
/// 패키지 추출은 P2-20에서 디렉토리째 이동.
///
/// 책임:
/// - UMP 동의 수집 (EEA 등 규제 지역에서 네이티브 동의 폼 자동 표시)
/// - canRequestAds 게이트: 동의 없으면 SDK 초기화/광고 로드 전부 차단
/// - NPA 폴백: 인하우스 프라이버시 동의(adConsent) 미수집/거부 시 npa=1
/// - COPPA/TFUA 노브 → RequestConfiguration 매핑
class AdConsentManager {
  /// UMP gather 결과 — AdService.initialize()가 설정한다.
  /// false면 광고 요청 금지 (EEA 동의 거부/미수집/미초기화).
  static bool canRequestAdsNow = false;

  static AdsConfig _config = const AdsConfig.disabled();
  static bool Function() _personalizedAdsResolver = () => true;

  /// 앱이 부팅 시점에 플래그 + 개인화 동의 판정 콜백을 주입한다.
  static void configure({
    required AdsConfig config,
    required bool Function() personalizedAds,
  }) {
    _config = config;
    _personalizedAdsResolver = personalizedAds;
  }

  /// 모든 광고 로드가 사용해야 하는 AdRequest 팩토리.
  ///
  /// 요청 시점마다 동의 상태를 다시 읽는다 — 부팅 시 프리로드는 NPA로
  /// 나가더라도, 사용자가 동의한 뒤의 로드는 개인화로 나간다.
  static AdRequest currentAdRequest() {
    return buildAdRequest(personalizedAdsAllowed: personalizedAdsAllowed());
  }

  /// 개인화 광고 허용 여부.
  ///
  /// 인하우스 동의 플로우(isPrivacyConsentEnabled)가 꺼진 구성에서는
  /// UMP 동의 문자열(TC string)이 단독으로 통제하므로 true를 돌려
  /// SDK 기본 동작에 맡긴다.
  static bool personalizedAdsAllowed() {
    return _personalizedAdsResolver();
  }

  // ---------- 순수 빌더 (단위 테스트 대상) ----------

  /// NPA 폴백 매핑: 개인화 불허 → npa=1 extra (nonPersonalizedAds: true).
  /// 허용 시에는 null로 두어 UMP TC string이 통제하게 한다.
  static AdRequest buildAdRequest({required bool personalizedAdsAllowed}) {
    return AdRequest(nonPersonalizedAds: personalizedAdsAllowed ? null : true);
  }

  /// COPPA/TFUA 노브 → RequestConfiguration.
  ///
  /// 둘 다 켜진 경우 childDirected(COPPA)가 우선한다 — GMA 정책상
  /// 두 태그를 동시에 yes로 보내면 안 된다. 어느 쪽이든 켜지면
  /// maxAdContentRating은 G로 강제.
  static RequestConfiguration buildRequestConfiguration({
    required bool childDirected,
    required bool underAgeOfConsent,
  }) {
    if (childDirected && underAgeOfConsent) {
      logger.w('COPPA(childDirected)와 TFUA(underAgeOfConsent) 동시 설정 — '
          'COPPA 우선 적용');
    }
    final effectiveUnderAge = underAgeOfConsent && !childDirected;
    return RequestConfiguration(
      tagForChildDirectedTreatment: childDirected
          ? TagForChildDirectedTreatment.yes
          : TagForChildDirectedTreatment.unspecified,
      tagForUnderAgeOfConsent: effectiveUnderAge
          ? TagForUnderAgeOfConsent.yes
          : TagForUnderAgeOfConsent.unspecified,
      maxAdContentRating:
          (childDirected || underAgeOfConsent) ? MaxAdContentRating.g : null,
    );
  }

  // ---------- UMP 플랫폼 호출 ----------

  /// UMP 동의 수집. 앱 런치마다 호출해야 한다 (Google 권장).
  ///
  /// EEA 등 규제 지역에서는 네이티브 동의 폼이 뜨고, 그 외 지역에서는
  /// 즉시 통과한다. 실패해도 부팅을 막지 않는다 — canRequestAds 결과만
  /// 게이트에 반영.
  Future<bool> gatherConsent() async {
    try {
      final updateCompleter = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(
          tagForUnderAgeOfConsent:
              _config.underAgeOfConsentEnabled ? true : null,
        ),
        () {
          if (!updateCompleter.isCompleted) updateCompleter.complete();
        },
        (FormError error) {
          if (!updateCompleter.isCompleted) {
            updateCompleter.completeError(
                StateError('UMP update failed: ${error.errorCode} ${error.message}'));
          }
        },
      );
      await updateCompleter.future;

      // 동의 폼이 필요하면 표시하고 닫힐 때까지 대기
      final formCompleter = Completer<void>();
      await ConsentForm.loadAndShowConsentFormIfRequired((FormError? formError) {
        if (formError != null) {
          logger.w('UMP consent form error: '
              '${formError.errorCode} ${formError.message}');
        }
        if (!formCompleter.isCompleted) formCompleter.complete();
      });
      await formCompleter.future;
    } catch (e) {
      // 네트워크 실패 등 — 이전 세션에서 동의가 수집됐다면
      // canRequestAds가 여전히 true일 수 있으므로 게이트 판정은 계속한다.
      logger.w('UMP consent gathering failed: $e');
    }

    try {
      canRequestAdsNow = await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      logger.e('UMP canRequestAds check failed: $e');
      canRequestAdsNow = false;
    }
    logger.d('UMP consent gathered: canRequestAds=$canRequestAdsNow');
    return canRequestAdsNow;
  }

  /// 프라이버시 옵션 진입점 노출 필요 여부 (UMP 정책: required면
  /// 설정 화면에 재동의 진입점을 제공해야 한다).
  Future<bool> isPrivacyOptionsRequired() async {
    try {
      final status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      logger.w('UMP privacy options status check failed: $e');
      return false;
    }
  }

  /// 프라이버시 옵션 폼 표시 (설정 화면 진입점에서 호출).
  Future<void> showPrivacyOptionsForm() async {
    final completer = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((FormError? formError) {
      if (formError != null) {
        logger.w('UMP privacy options form error: '
            '${formError.errorCode} ${formError.message}');
      }
      if (!completer.isCompleted) completer.complete();
    });
    await completer.future;
  }
}
