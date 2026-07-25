/// 위치(positioning) 엔진([LocationService]) 기능 게이트.
///
/// 패키지는 앱의 `AppFeatureConfig`에 의존하지 않는다 — 앱이 부팅 시점에
/// 플래그 값을 이 객체로 스냅샷해 `LocationService.configure`로 주입한다.
class LocationConfig {
  const LocationConfig({required this.locationEnabled});

  /// 위치 비활성. `configure` 전 기본값 — 위치 취득은 no-op(null/빈 스트림).
  const LocationConfig.disabled() : locationEnabled = false;

  /// 위치 기능 on/off. AppFeatureConfig.isLocationEnabled.
  final bool locationEnabled;
}
