import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:utils/utils.dart';

import 'email_auth.dart' show AuthUser, AuthException;

/// 소셜 인증 엔진 (Google/Apple → Firebase `signInWithCredential`). 앱-무관.
///
/// firebase_auth + google_sign_in + sign_in_with_apple만 의존한다. 반환된
/// [AuthUser](email_auth와 공유하는 중립 타입)를 앱이 UserModel로 매핑한다.
/// 모든 예외는 [AuthException]으로 변환된다.
///
/// OAuth 자격증명(Google clientId/serverClientId)은 포크별이므로 앱이
/// [configureGoogle]로 주입한다(firebase_options 패턴). 기능 플래그 게이트는
/// 앱 바인딩(AuthViewModel)이 소유한다.
class SocialAuthService {
  const SocialAuthService();

  /// Firebase 앱 초기화 여부. 앱이 기능 플래그와 AND 게이트.
  bool get isFirebaseReady => Firebase.apps.isNotEmpty;

  // ── Google OAuth 자격증명 (포크별 주입) ──
  static String? _googleClientId;
  static String? _googleServerClientId;
  static bool _googleInitialized = false;

  /// 앱이 부팅 시점에 Google OAuth 클라이언트 ID를 주입한다.
  /// [clientId]=iOS 클라이언트 ID, [serverClientId]=Firebase idToken audience(Web 클라 ID).
  static void configureGoogle({String? clientId, String? serverClientId}) {
    _googleClientId = clientId;
    _googleServerClientId = serverClientId;
    _googleInitialized = false;
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: _googleClientId,
      serverClientId: _googleServerClientId,
    );
    _googleInitialized = true;
  }

  /// Google 로그인 → Firebase 자격증명 교환. [AuthUser] 반환.
  Future<AuthUser> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const AuthException(
            'google-unsupported', 'Google authenticate not supported on this platform');
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthException('google-no-id-token', 'Google idToken is null');
      }
      final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
      final result =
          await fb.FirebaseAuth.instance.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw const AuthException('null-user', 'Google sign-in returned no user');
      }
      return _map(user);
    } on GoogleSignInException catch (e) {
      logger.w('Google sign-in failed: ${e.code} ${e.description}');
      throw AuthException('google-${e.code.name}', e.description);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(e.code, e.message);
    }
  }

  /// Apple 로그인 → Firebase 자격증명 교환. [AuthUser] 반환.
  ///
  /// Apple은 최초 로그인에만 이름을 제공하므로, 받은 경우 displayName을
  /// best-effort로 보강한다.
  Future<AuthUser> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauthCredential = fb.OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      final result =
          await fb.FirebaseAuth.instance.signInWithCredential(oauthCredential);
      var user = result.user;
      if (user == null) {
        throw const AuthException('null-user', 'Apple sign-in returned no user');
      }

      // Apple 최초 로그인 이름 보강 (best-effort)
      if ((user.displayName == null || user.displayName!.isEmpty) &&
          (appleCredential.givenName != null || appleCredential.familyName != null)) {
        final name = [appleCredential.givenName, appleCredential.familyName]
            .where((s) => s != null && s.isNotEmpty)
            .join(' ');
        if (name.isNotEmpty) {
          try {
            await user.updateDisplayName(name);
            user = fb.FirebaseAuth.instance.currentUser ?? user;
          } catch (e) {
            logger.w('Apple displayName update failed: $e');
          }
        }
      }
      return _map(user!);
    } on SignInWithAppleException catch (e) {
      logger.w('Apple sign-in failed: $e');
      throw AuthException('apple-error', e.toString());
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(e.code, e.message);
    }
  }

  /// 로그아웃 (Firebase 세션 종료 + Google 세션 정리 best-effort).
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      logger.w('Google signOut failed: $e');
    }
    await fb.FirebaseAuth.instance.signOut();
  }

  AuthUser _map(fb.User u) => AuthUser(
        uid: u.uid,
        email: u.email ?? '',
        displayName: u.displayName,
        isEmailVerified: u.emailVerified,
        creationTime: u.metadata.creationTime,
      );
}
