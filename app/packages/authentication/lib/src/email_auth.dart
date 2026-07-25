import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:utils/utils.dart';

/// Firebase 이메일 인증으로 식별된 사용자 (앱-무관 값 객체).
///
/// 패키지는 앱의 `UserModel`(Drift 생성 타입)을 알 수 없으므로 이 중립 타입을
/// 반환한다. 앱은 이를 자신의 UserModel로 매핑한다.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    required this.isEmailVerified,
    this.creationTime,
  });

  final String uid;
  final String email;
  final String? displayName;
  final bool isEmailVerified;
  final DateTime? creationTime;
}

/// 이메일 인증 실패. Firebase의 `FirebaseAuthException`을 감싸 앱이
/// firebase_auth를 직접 import하지 않아도 되게 한다.
///
/// [code]는 Firebase 에러 코드(예: `wrong-password`) — 앱이 코드별 로컬라이즈된
/// 메시지로 매핑한다. [message]는 Firebase 원본 메시지(폴백용).
class AuthException implements Exception {
  const AuthException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => 'AuthException($code): ${message ?? ''}';
}

/// 회원가입 결과 — 가입된 사용자 + 인증 메일 발송 여부(best-effort).
typedef EmailSignUpResult = ({AuthUser user, bool verificationSent});

/// Firebase 이메일 인증 엔진 (앱-무관).
///
/// firebase_auth/firebase_core만 의존한다. 앱은 반환된 [AuthUser]를 자신의
/// UserModel로 매핑하고, 영속·에러 처리·기능 플래그 게이트를 바인딩한다
/// (app: AuthViewModel). 모든 Firebase 예외는 [AuthException]으로 변환되어
/// 던져지므로 앱은 firebase_auth를 import할 필요가 없다.
///
/// 게이트 책임 분담: 이 서비스는 [isFirebaseReady]만 제공한다. 기능 플래그
/// (isEmailAuthEnabled 등)와의 AND 게이트는 앱 바인딩이 소유한다 — 서비스
/// 메서드는 Firebase가 준비됐다는 전제에서만 호출돼야 한다.
class FirebaseEmailAuthService {
  const FirebaseEmailAuthService();

  /// Firebase 앱이 초기화됐는지 여부. 앱이 기능 플래그와 AND해서 게이트한다.
  bool get isFirebaseReady => Firebase.apps.isNotEmpty;

  /// 현재 로그인된 사용자 (없으면 null).
  AuthUser? get currentUser {
    final u = fb.FirebaseAuth.instance.currentUser;
    return u == null ? null : _map(u);
  }

  /// 인증 상태 변경 스트림 (로그아웃/세션 만료 시 null 방출).
  Stream<AuthUser?> userChanges() => fb.FirebaseAuth.instance
      .authStateChanges()
      .map((u) => u == null ? null : _map(u));

  /// 이메일/비밀번호 로그인.
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await fb.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user == null) {
        throw const AuthException('null-user', 'sign-in returned no user');
      }
      return _map(user);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(e.code, e.message);
    }
  }

  /// 이메일/비밀번호 회원가입. 가입 후 표시 이름 설정(선택) + 인증 메일 발송
  /// (best-effort)을 수행하고 가입 사용자와 발송 여부를 반환한다.
  Future<EmailSignUpResult> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await fb.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      var user = credential.user;
      if (user == null) {
        throw const AuthException('null-user', 'sign-up returned no user');
      }

      if (displayName != null && displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
        user = fb.FirebaseAuth.instance.currentUser ?? user;
      }

      // 인증 메일은 best-effort — 실패해도 가입 자체는 성공
      var verificationSent = false;
      try {
        await user.sendEmailVerification();
        verificationSent = true;
      } catch (e) {
        logger.w('FirebaseEmailAuthService: verification email failed: $e');
      }

      return (user: _map(user), verificationSent: verificationSent);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(e.code, e.message);
    }
  }

  /// 비밀번호 재설정 이메일 전송.
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await fb.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(e.code, e.message);
    }
  }

  /// 로그아웃 (서버 세션 종료).
  Future<void> signOut() => fb.FirebaseAuth.instance.signOut();

  /// 현재 사용자 영구 삭제 (클라이언트 직접 삭제 — 서버 함수 불필요).
  ///
  /// Firebase가 `requires-recent-login`을 던지면 [AuthException]으로 전파된다.
  Future<void> deleteCurrentUser() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AuthException('no-current-user', 'no server account');
    }
    try {
      await user.delete();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(e.code, e.message);
    }
  }

  AuthUser _map(fb.User u) => AuthUser(
        uid: u.uid,
        email: u.email ?? '',
        displayName: u.displayName,
        isEmailVerified: u.emailVerified,
        creationTime: u.metadata.creationTime,
      );
}
