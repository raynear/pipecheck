/// 광고 로드 재시도 상한. 매니저(banner/app_open/fullscreen)가 공유한다.
/// 과거 ad_service.dart 최상위 const였으나, 매니저→facade 역참조를 끊기 위해
/// 별도 파일로 분리 (P2-20c).
const int maxFailedLoadAttempts = 3;
