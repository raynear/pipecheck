import 'dart:async';
import 'dart:io';

import 'package:pipecheck/core/services/snackbar_service.dart';
import 'package:firebase_services/firebase_services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utils/utils.dart';

/// Error type classification
enum ErrorType {
  network,
  database,
  authentication,
  permission,
  validation,
  server,
  unknown,
}

/// Structured app error with type classification
class AppError {
  final String message;
  final ErrorType type;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppError({
    required this.message,
    required this.type,
    this.originalError,
    this.stackTrace,
  });

  /// Auto-classify error type from exception
  factory AppError.from(Object error, [StackTrace? stackTrace]) {
    final type = _classifyError(error);
    return AppError(
      message: error.toString(),
      type: type,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  static ErrorType _classifyError(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return ErrorType.network;
    }
    final msg = error.toString().toLowerCase();
    if (msg.contains('socket') || msg.contains('connection') || msg.contains('timeout')) {
      return ErrorType.network;
    }
    if (msg.contains('database') || msg.contains('sql') || msg.contains('drift')) {
      return ErrorType.database;
    }
    if (msg.contains('auth') || msg.contains('unauthorized') || msg.contains('401')) {
      return ErrorType.authentication;
    }
    if (msg.contains('permission') || msg.contains('denied') || msg.contains('403')) {
      return ErrorType.permission;
    }
    if (msg.contains('500') || msg.contains('502') || msg.contains('503')) {
      return ErrorType.server;
    }
    return ErrorType.unknown;
  }
}

/// Provider for error handler
final errorHandlerProvider = Provider<ErrorHandler>((ref) {
  return ErrorHandler(ref);
});

/// Centralized error handler with Crashlytics integration
class ErrorHandler {
  final Ref ref;

  ErrorHandler(this.ref);

  /// Handle error: log, report to Crashlytics, show user message
  Future<void> handleError(AppError error) async {
    _logError(error);
    await _reportToCrashlytics(error);

    final userMessage = _getUserMessage(error);
    ref.read(snackBarServiceProvider).showError(userMessage);
  }

  void _logError(AppError error) {
    logger.e(
      error.message,
      error: error.originalError,
      stackTrace: error.stackTrace,
    );
  }

  Future<void> _reportToCrashlytics(AppError error) async {
    // kDebugMode 스킵 결정은 앱에 남긴다 — 플래그·초기화 가드는 CrashReporter가 한다.
    if (kDebugMode) return;

    await CrashReporter.recordError(
      error.originalError ?? error.message,
      error.stackTrace,
      reason: '${error.type.name}: ${error.message}',
    );
  }

  /// 사용자에게 보여줄 메시지를 돌려준다.
  ///
  /// SnackBarService가 표시 시 `.tr()`로 키를 해석하므로 여기서는 번역 키만
  /// 반환한다(검증 메시지는 이미 사람이 읽는 텍스트이므로 그대로 전달).
  String _getUserMessage(AppError error) {
    switch (error.type) {
      case ErrorType.network:
        return 'errors.network';
      case ErrorType.database:
        return 'errors.database';
      case ErrorType.authentication:
        return 'errors.authentication';
      case ErrorType.permission:
        return 'errors.permission';
      case ErrorType.validation:
        return error.message;
      case ErrorType.server:
        return 'errors.server';
      case ErrorType.unknown:
        return 'errors.unknown';
    }
  }

  /// Async try-catch helper with auto error classification
  Future<T?> tryAsync<T>({
    required Future<T> Function() action,
    ErrorType? errorType,
    String? customMessage,
  }) async {
    try {
      return await action();
    } catch (e, stackTrace) {
      final error = errorType != null
          ? AppError(
              message: customMessage ?? e.toString(),
              type: errorType,
              originalError: e,
              stackTrace: stackTrace,
            )
          : AppError.from(e, stackTrace);
      await handleError(error);
      return null;
    }
  }

  /// Sync try-catch helper with auto error classification
  T? trySync<T>({
    required T Function() action,
    ErrorType? errorType,
    String? customMessage,
  }) {
    try {
      return action();
    } catch (e, stackTrace) {
      final error = errorType != null
          ? AppError(
              message: customMessage ?? e.toString(),
              type: errorType,
              originalError: e,
              stackTrace: stackTrace,
            )
          : AppError.from(e, stackTrace);
      handleError(error);
      return null;
    }
  }

  /// Set up global error handling (call once in main.dart)
  static void setupGlobalErrorHandling() {
    FlutterError.onError = (details) {
      logger.e('FlutterError: ${details.exceptionAsString()}', stackTrace: details.stack);
      if (!kDebugMode) {
        CrashReporter.recordFlutterError(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      logger.e('PlatformError: $error', stackTrace: stack);
      if (!kDebugMode) {
        CrashReporter.recordError(error, stack, fatal: true);
      }
      return true;
    };
  }
}

/// Extension for easy error handling from widgets
extension ErrorHandlerExtension on WidgetRef {
  ErrorHandler get errorHandler => read(errorHandlerProvider);
}
