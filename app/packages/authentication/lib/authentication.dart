/// 서버 인증 패키지 — 이메일/소셜 (앱-무관):
/// - 이메일 인증: [FirebaseEmailAuthService] (firebase_auth 래퍼)
/// - 소셜 인증: [SocialAuthService] (Google/Apple → Firebase signInWithCredential, P2-21.5b)
///
/// 생체/기기 인증은 `package:biometric_auth`로 분리됨 (P2-21.5a, opt-in dependency).
/// 앱은 각 메커니즘 위에 자신의 바인딩(플래그 게이트·UserModel 매핑·영속)을
/// 둔다. docs/MODULES.md §5 참조.
library;

export 'src/email_auth.dart';
export 'src/social_auth.dart';
