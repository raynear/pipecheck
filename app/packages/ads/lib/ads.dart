/// AdMob 광고 엔진 (앱-무관).
///
/// 앱은 부팅 시점에 [AdsConfig]·[AdUnitIds]·개인화 동의 콜백을
/// `AdService.configure`로 주입한 뒤 `AdService().initialize()`를 호출한다.
/// UMP 동의 수집은 SDK 초기화·광고 로드 전에 수행된다.
///
/// 폴백 이미지(`assets/images/fallback_banner.jpg`, `fallback_fullscreen.jpg`)는
/// 소비 앱이 번들한다(`Image.asset`이 앱 번들에서 해석 — 포크별 커스텀 가능).
library;

export 'src/ad_consent_manager.dart';
export 'src/ad_service.dart';
export 'src/ads_config.dart';
export 'src/ads_constants.dart';
export 'src/app_open_ad_manager.dart';
export 'src/banner_ad_manager.dart';
export 'src/fullscreen_ad_manager.dart';
