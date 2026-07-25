import 'dart:async';

import 'package:authentication/authentication.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/error_handler.dart';
import 'package:pipecheck/data/generated/models/user.model.dart';
import 'package:pipecheck/data/generated/repositories/user.repository.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utils/utils.dart';

/// 인증 상태를 관리하는 ViewModel (서버 이메일 인증 바인딩).
///
/// 서버 이메일 인증 메커니즘은 `package:authentication`의
/// [FirebaseEmailAuthService](firebase_auth 래퍼)가 소유한다. 이 클래스는
/// 그 위에 앱 바인딩을 둔다 — 기능 플래그 게이트, [AuthUser]→[UserModel] 매핑,
/// 로컬 영속, 에러 처리. 서버 인증 구현은 여기서만 — AuthStateNotifier
/// (core/state)에 이중 구현하지 말 것 (docs/MODULES.md §5).
/// 단, 계정 삭제(클라이언트 직접)는 AuthStateNotifier.deleteAccount 소유.
class AuthViewModel extends Notifier<AsyncValue<AuthState>> {
  static const _emailService = FirebaseEmailAuthService();
  static const _socialService = SocialAuthService();
  StreamSubscription<AuthUser?>? _authSub;

  @override
  AsyncValue<AuthState> build() {
    if (_emailAuthReady) {
      _checkInitialAuthState();

      // 세션 만료/원격 로그아웃 시 로컬 상태 정리 (P1-14c 행동 계약 보존 —
      // 구 supabase auth 스트림의 'AuthException 시 로컬 정리' 대응)
      _authSub?.cancel();
      _authSub = _emailService.userChanges().listen(
        (user) {
          if (user == null) {
            state = const AsyncValue.data(AuthState.unauthenticated());
          }
        },
        onError: (Object e) {
          logger.e('AuthViewModel: userChanges error: $e');
          state = const AsyncValue.data(AuthState.unauthenticated());
        },
      );
      ref.onDispose(() => _authSub?.cancel());
    }
    return const AsyncValue.data(AuthState.initial());
  }

  /// email auth 동작 조건 — 플래그 + Firebase 초기화 완료.
  /// isEmailAuthEnabled만 보던 과거 게이트 비대칭 풋건 방지:
  /// 모든 서버 인증 경로가 이 단일 게이트를 공유한다.
  bool get _emailAuthReady =>
      AppFeatureConfig.isEmailAuthEnabled &&
      AppFeatureConfig.isFirebaseEnabled &&
      _emailService.isFirebaseReady;

  /// social auth 동작 조건 — 플래그 + Firebase 초기화 (email과 동일 게이트 패턴).
  /// 모든 소셜 인증 경로가 이 단일 게이트를 공유한다.
  bool get _socialAuthReady =>
      AppFeatureConfig.isSocialAuthEnabled &&
      AppFeatureConfig.isFirebaseEnabled &&
      _socialService.isFirebaseReady;

  UserRepository get _userRepository => ref.read(userRepositoryProvider);
  ErrorHandler get _errorHandler => ref.read(errorHandlerProvider);

  // i18n 키. AuthResult.message로 흘러가 login_view 스낵바가 .tr() 해석한다.
  static const _disabledMessage = 'auth.emailAuthDisabled';
  static const _socialDisabledMessage = 'auth.socialAuthDisabled';

  /// 초기 인증 상태 확인 (기존 세션 복원)
  Future<void> _checkInitialAuthState() async {
    try {
      final authUser = _emailService.currentUser;
      if (authUser != null) {
        state = AsyncValue.data(
            AuthState.authenticated(_mapAuthUserToModel(authUser)));
      } else {
        state = const AsyncValue.data(AuthState.unauthenticated());
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// [AuthUser](패키지 중립 타입)를 앱 UserModel로 변환
  UserModel _mapAuthUserToModel(AuthUser authUser) {
    return UserModel(
      id: authUser.uid,
      email: authUser.email,
      name: authUser.displayName ??
          (authUser.email.isNotEmpty
              ? authUser.email.split('@').first
              : 'User'),
      isEmailVerified: authUser.isEmailVerified,
      createdAt: authUser.creationTime ?? DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
  }

  /// 로컬 DB에 사용자 저장 (존재하면 업데이트, 없으면 생성)
  Future<void> _saveUserToLocalDb(UserModel user) async {
    try {
      final existingUser = await _userRepository.getById(user.id);
      if (existingUser != null) {
        await _userRepository.update(user);
      } else {
        await _userRepository.create(user);
      }
    } catch (_) {
      // 로컬 DB 저장 실패는 무시 (인증에 영향 없음)
    }
  }

  /// 이메일로 로그인
  ///
  /// 과거의 "아무 이메일/비밀번호나 통과" 데모 우회는 포크가 플래그
  /// 구성을 실수하면 그대로 출시되는 풋건이라 제거됐다 (P1-14b).
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_emailAuthReady) {
      state = const AsyncValue.data(AuthState.unauthenticated());
      return AuthResult.failure(message: _disabledMessage);
    }

    state = const AsyncValue.loading();

    try {
      final authUser =
          await _emailService.signIn(email: email, password: password);

      final user = _mapAuthUserToModel(authUser);
      await _saveUserToLocalDb(user);

      state = AsyncValue.data(AuthState.authenticated(user));
      return AuthResult.success(user: user);
    } on AuthException catch (e) {
      state = const AsyncValue.data(AuthState.unauthenticated());
      return AuthResult.failure(message: _getAuthErrorMessage(e));
    } catch (e, stackTrace) {
      final error = AppError(
        // 진단용(로그/Crashlytics). 사용자 메시지는 error_handler가 type→키로 표시.
        message: 'Email sign-in failed',
        type: ErrorType.authentication,
        originalError: e,
        stackTrace: stackTrace,
      );

      await _errorHandler.handleError(error);
      state = AsyncValue.error(e, stackTrace);
      return AuthResult.failure(message: e.toString());
    }
  }

  /// Google 로그인 → Firebase. 성공 시 UserModel 매핑 + 로컬 영속.
  ///
  /// OAuth 자격증명(클라이언트 ID)은 부팅 시 SocialAuthService.configureGoogle로
  /// 주입된다 — 포크가 구성하지 않으면 google_sign_in이 실패를 던진다.
  Future<AuthResult> signInWithGoogle() async {
    if (!_socialAuthReady) {
      state = const AsyncValue.data(AuthState.unauthenticated());
      return AuthResult.failure(message: _socialDisabledMessage);
    }

    state = const AsyncValue.loading();

    try {
      final authUser = await _socialService.signInWithGoogle();
      final user = _mapAuthUserToModel(authUser);
      await _saveUserToLocalDb(user);

      state = AsyncValue.data(AuthState.authenticated(user));
      return AuthResult.success(user: user);
    } on AuthException catch (e) {
      state = const AsyncValue.data(AuthState.unauthenticated());
      return AuthResult.failure(message: _getAuthErrorMessage(e));
    } catch (e, stackTrace) {
      final error = AppError(
        message: 'Google sign-in failed',
        type: ErrorType.authentication,
        originalError: e,
        stackTrace: stackTrace,
      );

      await _errorHandler.handleError(error);
      state = AsyncValue.error(e, stackTrace);
      return AuthResult.failure(message: e.toString());
    }
  }

  /// Apple 로그인 → Firebase. 성공 시 UserModel 매핑 + 로컬 영속.
  Future<AuthResult> signInWithApple() async {
    if (!_socialAuthReady) {
      state = const AsyncValue.data(AuthState.unauthenticated());
      return AuthResult.failure(message: _socialDisabledMessage);
    }

    state = const AsyncValue.loading();

    try {
      final authUser = await _socialService.signInWithApple();
      final user = _mapAuthUserToModel(authUser);
      await _saveUserToLocalDb(user);

      state = AsyncValue.data(AuthState.authenticated(user));
      return AuthResult.success(user: user);
    } on AuthException catch (e) {
      state = const AsyncValue.data(AuthState.unauthenticated());
      return AuthResult.failure(message: _getAuthErrorMessage(e));
    } catch (e, stackTrace) {
      final error = AppError(
        message: 'Apple sign-in failed',
        type: ErrorType.authentication,
        originalError: e,
        stackTrace: stackTrace,
      );

      await _errorHandler.handleError(error);
      state = AsyncValue.error(e, stackTrace);
      return AuthResult.failure(message: e.toString());
    }
  }

  /// 이메일로 회원가입
  ///
  /// 가입 성공 시 인증 메일을 발송하고 로그인 상태를 유지한다
  /// (Firebase Auth는 가입 즉시 세션 생성 — emailVerified는 정보 값).
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    if (!_emailAuthReady) {
      state = const AsyncValue.data(AuthState.unauthenticated());
      return AuthResult.failure(message: _disabledMessage);
    }

    state = const AsyncValue.loading();

    try {
      final result = await _emailService.signUp(
        email: email,
        password: password,
        displayName: name,
      );

      final user = _mapAuthUserToModel(result.user);
      await _saveUserToLocalDb(user);

      state = AsyncValue.data(AuthState.authenticated(user));
      return AuthResult.success(
        user: user,
        message: result.verificationSent
            ? 'auth.signUpSuccessVerify'
            : 'auth.signUpSuccess',
        requiresEmailVerification: !user.isEmailVerified,
      );
    } on AuthException catch (e) {
      state = const AsyncValue.data(AuthState.unauthenticated());
      return AuthResult.failure(message: _getAuthErrorMessage(e));
    } catch (e, stackTrace) {
      final error = AppError(
        message: 'Email sign-up failed',
        type: ErrorType.authentication,
        originalError: e,
        stackTrace: stackTrace,
      );

      await _errorHandler.handleError(error);
      state = AsyncValue.error(e, stackTrace);
      return AuthResult.failure(message: e.toString());
    }
  }

  /// 비밀번호 재설정 이메일 전송
  Future<AuthResult> sendPasswordResetEmail({required String email}) async {
    if (!_emailAuthReady) {
      return AuthResult.failure(message: _disabledMessage);
    }

    try {
      await _emailService.sendPasswordResetEmail(email: email);
      return AuthResult.success(message: 'auth.passwordResetSent');
    } on AuthException catch (e) {
      return AuthResult.failure(message: _getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure(message: 'auth.emailSendFailed');
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    state = const AsyncValue.loading();

    try {
      if (_emailAuthReady) {
        await _emailService.signOut();
      }
      // 소셜 세션 정리 (Google 로컬 세션 + Firebase). 미사용 시 best-effort no-op.
      if (_socialAuthReady) {
        await _socialService.signOut();
      }

      state = const AsyncValue.data(AuthState.unauthenticated());
    } catch (e, stackTrace) {
      final error = AppError(
        message: 'Sign-out failed',
        type: ErrorType.unknown,
        originalError: e,
        stackTrace: stackTrace,
      );

      await _errorHandler.handleError(error);
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// 현재 사용자 정보 새로고침
  Future<void> refreshCurrentUser() async {
    try {
      if (_emailAuthReady) {
        final authUser = _emailService.currentUser;
        if (authUser != null) {
          state = AsyncValue.data(
              AuthState.authenticated(_mapAuthUserToModel(authUser)));
          return;
        }
      }

      // 로컬 DB에서 사용자 정보 조회 시도
      final user = await _userRepository.getById('1');
      if (user != null) {
        state = AsyncValue.data(AuthState.authenticated(user));
      } else {
        state = const AsyncValue.data(AuthState.unauthenticated());
      }
    } catch (e, stackTrace) {
      final error = AppError(
        message: 'Failed to load user info',
        type: ErrorType.unknown,
        originalError: e,
        stackTrace: stackTrace,
      );

      await _errorHandler.handleError(error);
      // 에러가 발생해도 현재 상태는 유지
    }
  }

  /// 인증 에러 코드를 사용자 메시지로 변환 (로컬라이즈는 앱 책임 —
  /// 패키지는 [AuthException.code]만 제공)
  String _getAuthErrorMessage(AuthException e) {
    // 반환값은 i18n 키(snackbar가 .tr() 해석). default만 코드 부착이 필요해 직접
    // 해석 후 Dart로 합성한다(placeholder 키 없이 — snackbar의 .tr()은 인자 미지원).
    switch (e.code) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'auth.errorInvalidCredentials';
      case 'invalid-email':
        return 'auth.errorInvalidEmail';
      case 'email-already-in-use':
        return 'auth.errorEmailInUse';
      case 'weak-password':
        return 'auth.errorWeakPassword';
      case 'user-disabled':
        return 'auth.errorUserDisabled';
      case 'too-many-requests':
        return 'auth.errorTooManyRequests';
      case 'network-request-failed':
        return 'errors.network';
      case 'requires-recent-login':
        return 'auth.errorRequiresRecentLogin';
      default:
        return e.message ?? '${'auth.errorGeneric'.tr()} (${e.code})';
    }
  }
}

/// 인증 상태
class AuthState {
  final UserModel? user;
  final AuthStatus status;

  const AuthState({
    this.user,
    required this.status,
  });

  const AuthState.initial() : this(status: AuthStatus.loading);

  const AuthState.authenticated(UserModel user)
      : this(user: user, status: AuthStatus.authenticated);

  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
}

/// 인증 상태 열거형
enum AuthStatus {
  loading,
  authenticated,
  unauthenticated,
}

/// 인증 결과
class AuthResult {
  final bool isSuccess;
  final UserModel? user;
  final String? message;
  final bool requiresEmailVerification;

  const AuthResult._({
    required this.isSuccess,
    this.user,
    this.message,
    this.requiresEmailVerification = false,
  });

  factory AuthResult.success({
    UserModel? user,
    String? message,
    bool requiresEmailVerification = false,
  }) {
    return AuthResult._(
      isSuccess: true,
      user: user,
      message: message,
      requiresEmailVerification: requiresEmailVerification,
    );
  }

  factory AuthResult.failure({required String message}) {
    return AuthResult._(
      isSuccess: false,
      message: message,
    );
  }
}

/// AuthViewModel Provider
final authViewModelProvider =
    NotifierProvider<AuthViewModel, AsyncValue<AuthState>>(
  AuthViewModel.new,
);

/// 현재 인증된 사용자 Provider
final currentAuthUserProvider = Provider<UserModel?>((ref) {
  final authState = ref.watch(authViewModelProvider);

  return authState.maybeWhen(
    data: (state) => state.user,
    orElse: () => null,
  );
});

/// 인증 상태 Provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authViewModelProvider);

  return authState.maybeWhen(
    data: (state) => state.isAuthenticated,
    orElse: () => false,
  );
});
