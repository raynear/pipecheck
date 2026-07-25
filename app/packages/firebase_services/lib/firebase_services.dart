/// Firebase 엔진 모음 (앱-무관).
///
/// 앱은 부팅 시점에 자신의 기능 플래그를 [FirebaseServicesConfig]로 스냅샷해
/// [FirebaseService] · [CrashReporter]에 주입(`configure`)한다. 모든 엔진은
/// `Firebase.apps`(초기화 여부)와 주입된 플래그로 가드하며, Firebase가
/// 초기화되지 않았거나 비활성화된 경우 안전하게 no-op으로 동작한다.
///
/// `Firebase.initializeApp` 호출과 `firebase_options.dart`(포크별 자격증명)는
/// 앱에 남는다 — 이 패키지는 절대 초기화하지 않고 가드만 한다.
library;

export 'src/crash_reporter.dart';
export 'src/firebase_config.dart';
export 'src/firebase_service.dart';
export 'src/remote_config_service.dart';
