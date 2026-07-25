import 'package:boilerplate/config/app_feature_config.dart';
import 'package:boilerplate/core/services/notification/notification.dart';
import 'package:boilerplate/core/services/snackbar_service.dart';
import 'package:boilerplate/data/definitions/badge.dart';
import 'package:boilerplate/data/generated/models/badge.model.dart';
import 'package:boilerplate/data/generated/models/user.model.dart';
import 'package:boilerplate/data/generated/repositories/badge.repository.dart';
import 'package:boilerplate/data/generated/repositories/user.repository.dart';
import 'package:boilerplate/domain/models/action_result.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// 인증 관련 액션들을 처리하는 도메인 클래스
///
/// 각 액션은 DB 작업, 알림 설정, UI 피드백 등을 한번에 처리합니다.
class AuthActions {
  final UserRepository _userRepository;
  final BadgeRepository _badgeRepository;
  final NotificationService _notificationService;
  final SnackBarService _snackbarService;

  AuthActions({
    required UserRepository userRepository,
    required BadgeRepository badgeRepository,
    required NotificationService notificationService,
    required SnackBarService snackbarService,
  })  : _userRepository = userRepository,
        _badgeRepository = badgeRepository,
        _notificationService = notificationService,
        _snackbarService = snackbarService;

  /// 회원가입 액션
  /// - 사용자 생성
  /// - 환영 알림 설정
  /// - 초기 배지 부여
  /// - 환영 메시지 표시
  Future<ActionResult<UserModel>> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // 1. 사용자 생성
      final newUser = UserModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        email: email,
        name: name,
        isEmailVerified: false,
        createdAt: DateTime.now(),
      );

      final createdUser = await _userRepository.create(newUser);

      // 2. 환영 알림 설정 (24시간 후)
      await _notificationService.createNotification(
        id: 1,
        groupKey: NotificationService.defaultGroupKey,
        channelKey: NotificationService.defaultChannelKey,
        title: 'authActions.welcomeNotificationTitle'.tr(),
        body: 'authActions.welcomeNotificationBody'.tr(args: [name]),
        scheduleDate: DateTime.now().add(const Duration(days: 1)),
        scheduleTime: const TimeOfDay(hour: 9, minute: 0),
      );

      // 3. 초기 배지 부여 - "신규 회원" 배지
      // 배지 title/description은 DB에 저장돼 화면에서 그대로 표시되는 데모 시드
      // 데이터다. 표시 계층 i18n(배지 모델/위젯 키 전환)은 PR2 범위 밖이라
      // i18n-ignore로 둔다 — 시드 시점 .tr()은 로케일을 고정시키고 키 전환은 raw
      // 키를 노출한다.
      final welcomeBadge = BadgeModel(
        id: DateTime.now().millisecondsSinceEpoch,
        badgeId: 'new_member',
        title: '신규 회원', // i18n-ignore
        description: '서비스에 가입한 신규 회원', // i18n-ignore
        iconPath: 'assets/badges/new_member.png',
        isAchieved: true,
        earnedDate: DateTime.now(),
        type: BadgeType.first,
        condition: 'sign_up',
        createdAt: DateTime.now(),
      );
      await _badgeRepository.create(welcomeBadge);

      // 4. 환영 메시지 표시
      _snackbarService.showSuccess('authActions.signUpSuccessSnack'.tr());

      return ActionResult.success(
        data: createdUser,
        message: 'authActions.signUpSuccessMessage'.tr(),
      );
    } catch (e) {
      _snackbarService.showError('authActions.signUpFailed'.tr(args: ['$e']));
      return ActionResult.error(
        message: 'authActions.signUpError'.tr(args: ['$e']),
      );
    }
  }

  /// 로그인 액션
  /// - 로그인 처리
  /// - 연속 로그인 체크 및 배지 부여
  /// - 알림 권한 요청
  /// - 환영 메시지 표시
  Future<ActionResult<UserModel>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // 1. 로그인 처리 (실제로는 API 호출)
      final users = await _userRepository.getAll();
      final user = users.firstWhere(
        (u) => u.email == email,
        orElse: () => throw Exception('User not found'),
      );

      // 2. 마지막 로그인 시간 업데이트
      final updatedUser = user.copyWith(
        lastLoginAt: DateTime.now(),
      );
      await _userRepository.update(updatedUser);

      // 3. 연속 로그인 체크
      if (user.lastLoginAt != null) {
        final daysSinceLastLogin = DateTime.now().difference(user.lastLoginAt!).inDays;
        if (daysSinceLastLogin == 1) {
          // 연속 로그인 배지 체크 및 부여
          await _checkAndAwardLoginStreakBadge(user.id);
        }
      }

      // 4. 알림 권한 요청 (첫 로그인인 경우 & 알림이 활성화된 경우)
      if (user.lastLoginAt == null && AppFeatureConfig.isNotificationEnabled) {
        await _notificationService.requestPermission();
      }

      // 5. 환영 메시지 표시
      final greeting = _getGreetingMessage(user.name ?? 'User');
      _snackbarService.showInfo(greeting);

      return ActionResult.success(
        data: updatedUser,
        message: 'authActions.signInSuccessMessage'.tr(),
      );
    } catch (e) {
      _snackbarService.showError('authActions.signInFailed'.tr());
      return ActionResult.error(
        message: 'authActions.signInError'.tr(args: ['$e']),
      );
    }
  }

  /// 로그아웃 액션
  /// - 로그아웃 처리
  /// - 알림 취소
  /// - 캐시 정리
  Future<ActionResult<void>> signOut() async {
    try {
      // 1. 예약된 알림 모두 취소
      // TODO: NotificationService에 cancelAllNotifications 메서드 구현 필요
      // await _notificationService.cancelAllNotifications();

      // 2. 캐시 정리 (필요한 경우)
      // await _cacheService.clear();

      // 3. 로그아웃 메시지
      _snackbarService.showInfo('authActions.signOutSnack'.tr());

      return ActionResult.success(
        message: 'authActions.signOutMessage'.tr(),
      );
    } catch (e) {
      return ActionResult.error(
        message: 'authActions.signOutError'.tr(args: ['$e']),
      );
    }
  }

  /// 이메일 인증 액션
  /// - 이메일 인증 상태 업데이트
  /// - 인증 완료 배지 부여
  /// - 축하 알림 설정
  Future<ActionResult<UserModel>> verifyEmail(String userId) async {
    try {
      // 1. 사용자 정보 업데이트
      final user = await _userRepository.getById(userId);
      if (user == null) {
        throw Exception('User not found');
      }

      final updatedUser = user.copyWith(isEmailVerified: true);
      await _userRepository.update(updatedUser);

      // 2. 이메일 인증 배지 부여
      final verificationBadge = BadgeModel(
        id: DateTime.now().millisecondsSinceEpoch,
        badgeId: 'email_verified',
        title: '인증 완료', // i18n-ignore (배지 데모 시드 — 위 주석 참조)
        description: '이메일 인증을 완료한 회원', // i18n-ignore
        iconPath: 'assets/badges/email_verified.png',
        isAchieved: true,
        earnedDate: DateTime.now(),
        type: BadgeType.achievementCount,
        condition: 'email_verification',
        createdAt: DateTime.now(),
      );
      await _badgeRepository.create(verificationBadge);

      // 3. 축하 알림
      await _notificationService.createNotificationNow(
        id: 100,
        title: 'authActions.verifyEmailNotificationTitle'.tr(),
        body: 'authActions.verifyEmailNotificationBody'.tr(),
      );

      // 4. 성공 메시지
      _snackbarService.showSuccess('authActions.verifyEmailSuccessSnack'.tr());

      return ActionResult.success(
        data: updatedUser,
        message: 'authActions.verifyEmailSuccessMessage'.tr(),
      );
    } catch (e) {
      _snackbarService.showError('authActions.verifyEmailFailed'.tr());
      return ActionResult.error(
        message: 'authActions.verifyEmailError'.tr(args: ['$e']),
      );
    }
  }

  // === Helper Methods ===

  String _getGreetingMessage(String name) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'authActions.greetingMorning'.tr(args: [name]);
    } else if (hour < 18) {
      return 'authActions.greetingAfternoon'.tr(args: [name]);
    } else {
      return 'authActions.greetingEvening'.tr(args: [name]);
    }
  }

  Future<void> _checkAndAwardLoginStreakBadge(String userId) async {
    // 연속 로그인 배지 로직
    // 실제로는 연속 로그인 일수를 DB에서 관리하고 체크해야 함
    final badges = await _badgeRepository.getAll();
    final hasStreakBadge = badges.any((b) => b.badgeId == 'login_streak_7');

    if (!hasStreakBadge) {
      final streakBadge = BadgeModel(
        id: DateTime.now().millisecondsSinceEpoch,
        badgeId: 'login_streak_7',
        title: '일주일 연속 로그인', // i18n-ignore (배지 데모 시드 — 위 주석 참조)
        description: '7일 연속으로 로그인한 성실한 회원', // i18n-ignore
        iconPath: 'assets/badges/login_streak_7.png',
        isAchieved: true,
        earnedDate: DateTime.now(),
        type: BadgeType.consecutive,
        condition: 'login_streak',
        createdAt: DateTime.now(),
      );
      await _badgeRepository.create(streakBadge);

      _snackbarService.showSuccess('authActions.loginStreakSnack'.tr());
    }
  }
}
