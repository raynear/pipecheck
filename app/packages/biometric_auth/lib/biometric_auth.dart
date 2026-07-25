/// 생체/기기 인증 패키지 (앱-무관, opt-in).
///
/// `local_auth` 래퍼 [Authentication](지문/FaceID/기기 인증)을 제공한다.
/// 생체 인증을 쓰지 않는 포크는 이 패키지 의존을 제거하면 `local_auth`
/// 네이티브가 바이너리에 링크되지 않는다 (dependency 경계로 opt-in).
///
/// 앱은 이 위에 자신의 바인딩(기능 플래그 게이트 등)을 둔다.
/// 서버 이메일 인증은 `package:authentication`, 소셜 인증도 동일 패키지.
library;

export 'src/biometric.dart';
