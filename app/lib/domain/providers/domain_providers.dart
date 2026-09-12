import 'package:pipecheck/core/services/notification/notification.dart';
import 'package:pipecheck/core/services/snackbar_service.dart';
import 'package:pipecheck/data/generated/repositories/badge.repository.dart';
import 'package:pipecheck/data/generated/repositories/user.repository.dart';
import 'package:pipecheck/domain/actions/auth_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// notificationServiceProvider는 알림 배럴이 준다 (#232) — 여기 재선언 금지.

/// AuthActions Provider
final authActionsProvider = Provider<AuthActions>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  final badgeRepository = ref.watch(badgeRepositoryProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  final snackbarService = ref.watch(snackBarServiceProvider);

  return AuthActions(
    userRepository: userRepository,
    badgeRepository: badgeRepository,
    notificationService: notificationService,
    snackbarService: snackbarService,
  );
});
