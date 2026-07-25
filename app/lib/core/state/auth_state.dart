import 'package:authentication/authentication.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/services/authentication_service.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:pipecheck/data/generated/repositories/user.repository.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:utils/utils.dart';

part 'auth_state.freezed.dart';

/// 인증 방식 열거형
enum AuthMethod {
  /// 인증 없음
  none,

  /// 생체 인증 (Face ID, Touch ID)
  biometric,

  /// PIN 인증
  pin,

  /// 이메일/비밀번호 인증
  email,

  /// 소셜 로그인
  social,
}

/// 통합 인증 상태
///
/// 여러 인증 소스(로컬 인증, 서버 인증)의 상태를 통합하여 관리합니다.
/// 서버 인증(email)은 P1-16.5b에서 Firebase Auth로 재구현 예정 —
/// supabase 의존은 P1-16.5a에서 철거됨 (docs/MODULES.md §5).
@freezed
abstract class AuthState with _$AuthState {
  const factory AuthState({
    /// 인증 완료 여부
    required bool isAuthenticated,

    /// 현재 인증 방식
    required AuthMethod method,

    /// 마지막 인증 시간
    DateTime? lastAuthTime,

    /// 재인증 필요 여부 (세션 만료 등)
    @Default(false) bool requiresReauth,

    /// 인증 오류 메시지
    String? errorMessage,
  }) = _AuthState;

  const AuthState._();

  /// 인증되지 않은 초기 상태
  factory AuthState.initial() => const AuthState(
        isAuthenticated: false,
        method: AuthMethod.none,
      );

  /// 인증 완료 상태 생성
  factory AuthState.authenticated({
    required AuthMethod method,
  }) =>
      AuthState(
        isAuthenticated: true,
        method: method,
        lastAuthTime: DateTime.now(),
      );

  /// 세션이 유효한지 확인 (24시간 이내 인증)
  bool get isSessionValid {
    if (!isAuthenticated || lastAuthTime == null) return false;
    final elapsed = DateTime.now().difference(lastAuthTime!);
    return elapsed.inHours < 24;
  }
}

/// 통합 인증 서비스 Notifier
///
/// 여러 인증 방식을 통합하여 관리합니다:
/// - 생체 인증 (BiometricAuth)
/// - PIN 인증
/// - 서버 이메일 인증은 AuthViewModel(features/auth)이 소유 —
///   여기 중복 구현하지 말 것 (16.5a에서 이중 구현 1벌 삭제됨)
class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // 잠글 것이 없으면(플래그 OFF 또는 앱 잠금 미설정 none) 처음부터 인증 상태.
    // 그렇지 않으면 라우터 redirect가 보호 라우트(home 등)를 /auth로 튕겨,
    // 잠금을 설정한 적 없는 사용자까지 인증 화면에 갇힌다.
    //
    // - read(watch 아님): 부팅 시점 1회 판정 — 세션 중 잠금 설정 변경이
    //   현재 세션을 갑자기 잠그지 않게 한다(다음 부팅부터 적용).
    if (!AppFeatureConfig.isAuthenticationEnabled ||
        ref.read(settingsProvider).userAuthOption == UserAuthOption.none) {
      return AuthState.authenticated(method: AuthMethod.none);
    }
    return AuthState.initial();
  }

  /// 생체 인증 수행
  Future<bool> authenticateWithBiometrics() async {
    if (!AppFeatureConfig.isBiometricAuthEnabled) {
      state = AuthState.authenticated(method: AuthMethod.none);
      return true;
    }

    try {
      final authService = AuthenticationService();
      final success = await authService.authenticateWithBiometrics();

      if (success) {
        state = AuthState.authenticated(method: AuthMethod.biometric);
        logger.d('AuthState: Biometric authentication successful');
      } else {
        state = state.copyWith(
          isAuthenticated: false,
          errorMessage: 'auth.biometricFailed'.tr(),
        );

      }
      return success;
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        errorMessage: 'auth.biometricError'.tr(args: ['$e']),
      );

      logger.e('AuthState: Biometric auth error: $e');
      return false;
    }
  }

  /// PIN 인증 수행
  Future<bool> authenticateWithPin() async {
    try {
      final authService = AuthenticationService();
      final success = await authService.authenticate();

      if (success) {
        state = AuthState.authenticated(method: AuthMethod.pin);
        logger.d('AuthState: PIN authentication successful');
      } else {
        state = state.copyWith(
          isAuthenticated: false,
          errorMessage: 'auth.pinFailed'.tr(),
        );

      }
      return success;
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        errorMessage: 'auth.pinError'.tr(args: ['$e']),
      );

      logger.e('AuthState: PIN auth error: $e');
      return false;
    }
  }

  /// 서버 이메일 인증 메커니즘 (firebase_auth 래퍼 — package:authentication).
  static const _emailService = FirebaseEmailAuthService();

  /// Firebase Auth 사용 가능 여부 (서버 계정 경로 게이트)
  bool get _firebaseAuthReady =>
      AppFeatureConfig.isFirebaseEnabled && _emailService.isFirebaseReady;

  /// 로그아웃
  Future<void> signOut() async {
    try {
      // 서버 세션 종료 (email 인증으로 로그인한 경우)
      if (state.method == AuthMethod.email && _firebaseAuthReady) {
        await _emailService.signOut();
      }

      // initial() 하드코딩 금지 — build()가 재유도해야 잠금 미설정(none)
      // 사용자가 비인증으로 남아 /auth로 튕기는 루프를 만들지 않는다.
      ref.invalidateSelf();
      logger.d('AuthState: Signed out');
    } catch (e) {
      logger.e('AuthState: Sign out error: $e');
    }
  }

  /// 계정 영구 삭제 (스토어 컴플라이언스)
  ///
  /// 클라이언트 직접 삭제 (P1-16.5b, 서버 함수 불필요 — 무료/서버 0줄
  /// 원칙): 본인 로컬 데이터 삭제 후 `FirebaseAuth.currentUser.delete()`.
  /// 진입점(settings_view)/플래그(isAccountDeletionEnabled)는 13b 구조
  /// 그대로다.
  ///
  /// Firebase가 'requires-recent-login'을 던지면 실패를 반환한다 —
  /// 사용자는 재로그인 후 다시 시도해야 한다 (errorMessage에 안내).
  ///
  /// @return 삭제 성공 여부
  Future<bool> deleteAccount() async {
    if (!AppFeatureConfig.isAccountDeletionEnabled || !_firebaseAuthReady) {
      logger.w('AuthState: Account deletion unavailable '
          '(flag off or Firebase not initialized)');
      return false;
    }

    final authUser = _emailService.currentUser;
    if (authUser == null) {
      logger.w('AuthState: No server account to delete');
      return false;
    }

    try {
      // 본인 로컬 데이터 삭제 (best-effort — 서버 계정 삭제가 본체)
      try {
        await ref.read(userRepositoryProvider).delete(authUser.uid);
      } catch (e) {
        logger.w('AuthState: Local user data cleanup failed: $e');
      }

      await _emailService.deleteCurrentUser();
      // initial() 하드코딩 금지 — signOut과 동일하게 build() 재유도.
      ref.invalidateSelf();
      logger.d('AuthState: Account deleted');
      return true;
    } on AuthException catch (e) {
      final message = e.code == 'requires-recent-login'
          ? 'auth.reauthRequired'.tr()
          : 'auth.accountDeleteFailed'.tr(args: [e.code]);
      state = state.copyWith(errorMessage: message);
      logger.e('AuthState: Account deletion failed: ${e.code}');
      return false;
    } catch (e) {
      logger.e('AuthState: Account deletion error: $e');
      return false;
    }
  }

  /// 수동으로 인증 상태 설정 (테스트/개발용)
  void setAuthState(AuthState newState) {
    state = newState;
  }
}

/// 통합 인증 상태 Provider
final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);

/// 인증 여부만 확인하는 간단한 Provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isAuthenticated;
});

/// 현재 인증 방식 Provider
final currentAuthMethodProvider = Provider<AuthMethod>((ref) {
  return ref.watch(authStateProvider).method;
});
