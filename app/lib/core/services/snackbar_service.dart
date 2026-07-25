import 'dart:async';

import 'package:pipecheck/core/router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:utils/utils.dart';

/// 스낵바 서비스 - 큐 기반으로 순차적으로 스낵바를 표시
///
/// 사용 예시:
/// ```dart
/// // 어디서든 스낵바 표시 가능
/// ref.read(snackBarServiceProvider).showSuccess('작업이 완료되었습니다');
/// ref.read(snackBarServiceProvider).showError('오류가 발생했습니다');
/// ref.read(snackBarServiceProvider).showInfo('정보를 확인하세요');
/// ref.read(snackBarServiceProvider).showWarning('주의하세요');
///
/// // 중복 방지를 위한 ID 설정
/// ref.read(snackBarServiceProvider).showSuccess('저장됨', id: 'save_success');
///
/// // 커스텀 표시 시간
/// ref.read(snackBarServiceProvider).showSuccess(
///   '완료',
///   duration: const Duration(seconds: 5)
/// );
/// ```

/// 스낵바 타입 정의
enum SnackBarType {
  success,
  error,
  info,
  warning,
}

/// 스낵바 정보를 담는 클래스
class SnackBarInfo {
  final String message;
  final SnackBarType type;
  final String? id; // 중복 방지를 위한 식별자 (선택사항)
  final Duration? duration; // 표시 시간 (선택사항)

  const SnackBarInfo({
    required this.message,
    required this.type,
    this.id,
    this.duration,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SnackBarInfo && other.message == message && other.type == type && other.id == id;
  }

  @override
  int get hashCode => Object.hash(message, type, id);
}

/// 스낵바 상태를 관리하는 Notifier
class SnackBarNotifier extends Notifier<List<SnackBarInfo>> {
  @override
  List<SnackBarInfo> build() {
    return [];
  }

  /// 스낵바 추가
  void addSnackBar(SnackBarInfo snackBarInfo) {
    // 중복 방지: 같은 메시지가 이미 큐에 있는지 확인
    if (state.contains(snackBarInfo)) {
      logger.d('중복된 스낵바 메시지: ${snackBarInfo.message}');
      return;
    }

    state = [...state, snackBarInfo];
    logger.d('스낵바 추가됨: ${snackBarInfo.message}, 큐 크기: ${state.length}');
  }

  /// 첫 번째 스낵바 제거 (표시 완료 후 호출)
  void removeFirst() {
    if (state.isNotEmpty) {
      final removed = state.first;
      state = state.sublist(1);
      logger.d('스낵바 제거됨: ${removed.message}, 남은 큐 크기: ${state.length}');
    }
  }

  /// 특정 스낵바 제거
  void removeSnackBar(SnackBarInfo snackBarInfo) {
    state = state.where((item) => item != snackBarInfo).toList();
    logger.d('특정 스낵바 제거됨: ${snackBarInfo.message}');
  }

  /// 모든 스낵바 제거
  void clearAll() {
    state = [];
    logger.d('모든 스낵바 제거됨');
  }

  /// 다음에 표시할 스낵바 가져오기
  SnackBarInfo? get nextSnackBar => state.isNotEmpty ? state.first : null;

  /// 큐가 비어있는지 확인
  bool get isEmpty => state.isEmpty;
}

/// 스낵바 서비스 클래스
class SnackBarService {
  final SnackBarNotifier _notifier;
  final Ref _ref;
  bool _isShowing = false;
  Timer? _delayTimer;

  SnackBarService(this._notifier, this._ref);

  /// 성공 스낵바 추가
  void showSuccess(String message, {String? id, Duration? duration}) {
    _notifier.addSnackBar(SnackBarInfo(
      message: message,
      type: SnackBarType.success,
      id: id,
      duration: duration,
    ));
  }

  /// 에러 스낵바 추가
  void showError(String message, {String? id, Duration? duration}) {
    _notifier.addSnackBar(SnackBarInfo(
      message: message,
      type: SnackBarType.error,
      id: id,
      duration: duration,
    ));
  }

  /// 정보 스낵바 추가
  void showInfo(String message, {String? id, Duration? duration}) {
    _notifier.addSnackBar(SnackBarInfo(
      message: message,
      type: SnackBarType.info,
      id: id,
      duration: duration,
    ));
  }

  /// 경고 스낵바 추가
  void showWarning(String message, {String? id, Duration? duration}) {
    _notifier.addSnackBar(SnackBarInfo(
      message: message,
      type: SnackBarType.warning,
      id: id,
      duration: duration,
    ));
  }

  /// 스낵바 표시 처리 (context를 내부에서 GoRouter로 얻음)
  void processSnackBarQueue() async {
    // 이미 표시 중이거나 큐가 비어있으면 리턴
    if (_isShowing || _notifier.isEmpty) return;

    // MaterialApp이 완전히 초기화될 때까지 기다림 (BadgeService와 동일한 방식)
    await Future.delayed(const Duration(milliseconds: 100));

    // 지연 후 다시 확인
    if (_isShowing || _notifier.isEmpty) return;

    final nextSnackBar = _notifier.nextSnackBar;
    if (nextSnackBar == null) return;

    // GoRouter의 navigatorKey로 context 가져오기 (BadgeService와 동일한 방식)
    final router = _ref.read(goRouterProvider);
    final navigatorKey = router.routerDelegate.navigatorKey;
    final context = navigatorKey.currentContext;

    if (context == null || !context.mounted) {
      logger.e('스낵바를 표시할 수 없습니다: context가 null입니다');
      return;
    }

    _showSnackBar(context, nextSnackBar);
  }

  /// 실제 스낵바 표시
  void _showSnackBar(BuildContext context, SnackBarInfo snackBarInfo) {
    _isShowing = true;

    CustomSnackBar snackBar;
    switch (snackBarInfo.type) {
      case SnackBarType.success:
        snackBar = CustomSnackBar.success(message: snackBarInfo.message.tr());
        break;
      case SnackBarType.error:
        snackBar = CustomSnackBar.error(message: snackBarInfo.message.tr());
        break;
      case SnackBarType.info:
        snackBar = CustomSnackBar.info(message: snackBarInfo.message.tr());
        break;
      case SnackBarType.warning:
        // top_snackbar_flutter에 warning이 없으므로 info로 대체하거나 커스텀 구현
        snackBar = CustomSnackBar.info(
          message: snackBarInfo.message.tr(),
          backgroundColor: Colors.orange,
        );
        break;
    }

    // rootNavigatorKey 사용하여 올바른 Overlay context 찾기
    final rootNavigatorKey = _ref.read(goRouterProvider).routerDelegate.navigatorKey;
    final overlayState = rootNavigatorKey.currentState?.overlay;

    if (overlayState == null) {
      logger.e('Overlay를 찾을 수 없습니다');
      _isShowing = false;
      return;
    }

    showTopSnackBar(
      overlayState,
      snackBar,
      displayDuration: snackBarInfo.duration ?? const Duration(seconds: 3),
      onTap: () {
        // 탭하면 즉시 닫기
        _onSnackBarComplete(snackBarInfo);
      },
    );

    // 스낵바 표시 완료 후 처리
    _scheduleSnackBarComplete(snackBarInfo);
  }

  /// 스낵바 표시 완료 스케줄링
  void _scheduleSnackBarComplete(SnackBarInfo snackBarInfo) {
    final duration = snackBarInfo.duration ?? const Duration(seconds: 3);

    Timer(duration + const Duration(milliseconds: 100), () {
      _onSnackBarComplete(snackBarInfo);
    });
  }

  /// 스낵바 표시 완료 처리
  void _onSnackBarComplete(SnackBarInfo snackBarInfo) {
    _isShowing = false;
    _notifier.removeFirst();

    // 다음 스낵바가 있으면 잠시 후 표시
    if (!_notifier.isEmpty) {
      _delayTimer?.cancel();
      _delayTimer = Timer(const Duration(milliseconds: 500), () {
        // 다음 스낵바 처리는 MainApp에서 listen하여 자동으로 처리됨
      });
    }
  }

  /// 모든 스낵바 취소
  void cancelAll() {
    _delayTimer?.cancel();
    _notifier.clearAll();
    _isShowing = false;
  }

  /// 리소스 정리
  void dispose() {
    _delayTimer?.cancel();
  }
}

/// 스낵바 상태 프로바이더
final snackBarProvider = NotifierProvider<SnackBarNotifier, List<SnackBarInfo>>(
  SnackBarNotifier.new,
);

/// 스낵바 서비스 프로바이더
final snackBarServiceProvider = Provider<SnackBarService>((ref) {
  final notifier = ref.read(snackBarProvider.notifier);
  final service = SnackBarService(notifier, ref);

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});
