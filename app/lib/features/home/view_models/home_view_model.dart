import 'package:boilerplate/domain/actions/auth_actions.dart';
import 'package:boilerplate/domain/providers/domain_providers.dart';
import 'package:boilerplate/features/auth/view_models/auth_view_model.dart';
import 'package:boilerplate/features/home/models/home_model.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 홈 화면의 뷰 모델
///
/// 홈 화면의 상태 관리와 비즈니스 로직을 담당합니다.
/// Domain Actions 패턴을 활용하여 복잡한 비즈니스 로직을 처리합니다.
///
/// 주요 기능:
/// - 이메일 인증 처리
/// - 로그아웃 처리
/// - 로딩 상태 및 에러 메시지 관리
///
/// 상태 관리:
/// - HomeModel을 통해 UI 상태를 관리
/// - Notifier를 사용하여 불변 상태 유지
/// - Riverpod을 통한 의존성 주입
class HomeViewModel extends Notifier<HomeModel> {
  @override
  HomeModel build() {
    return HomeModel(title: 'Home');
  }

  AuthActions get _authActions => ref.read(authActionsProvider);

  /// 도메인 액션을 사용한 예시: 이메일 인증
  ///
  /// AuthActions의 verifyEmail을 호출하면:
  /// 1. DB 업데이트
  /// 2. 배지 부여
  /// 3. 알림 발송
  /// 4. 스낵바 표시
  /// 모든 작업이 한번에 처리됩니다.
  Future<void> verifyUserEmail() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      // 현재 로그인한 사용자 정보 가져오기
      final authState = ref.read(authViewModelProvider);
      final userId = authState.maybeWhen(
        data: (auth) => auth.user?.id,
        orElse: () => null,
      );

      if (userId == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'home.loginRequired'.tr(),
        );
        return;
      }

      // 도메인 액션 호출 - 모든 관련 작업이 한번에 처리됨
      final result = await _authActions.verifyEmail(userId);

      if (result.success) {
        state = state.copyWith(
          isLoading: false,
          title: 'home.emailVerifiedTitle'.tr(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: result.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'home.errorWithDetail'.tr(args: ['$e']),
      );
    }
  }

  /// 다른 도메인 액션 사용 예시: 로그아웃
  Future<void> signOut() async {
    try {
      // 도메인 액션 호출 - 알림 취소, 캐시 정리 등이 모두 처리됨
      final result = await _authActions.signOut();

      if (result.success) {
        // 로그아웃 성공 - 이미 스낵바가 표시됨
        state = HomeModel(title: 'Logged Out');
      }
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }
}

/// HomeViewModel의 프로바이더
///
/// Riverpod을 통해 HomeViewModel의 인스턴스를 제공하고 관리합니다.
///
/// 의존성:
/// - authActionsProvider: 인증 관련 도메인 액션 제공
///
/// 사용 예시:
/// ```dart
/// // 상태 읽기
/// final homeState = ref.watch(homeViewModelProvider);
///
/// // 메서드 호출
/// ref.read(homeViewModelProvider.notifier).verifyUserEmail();
/// ```
final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeModel>(
  HomeViewModel.new,
);
