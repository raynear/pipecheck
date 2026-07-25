import 'package:boilerplate/core/services/notification/notification.dart';
import 'package:boilerplate/core/services/snackbar_service.dart';
import 'package:boilerplate/data/generated/repositories/badge.repository.dart';
import 'package:boilerplate/data/generated/repositories/user.repository.dart';
import 'package:boilerplate/domain/actions/auth_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// NotificationService Provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

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
