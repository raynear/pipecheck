// 알림 호출을 'kind:message'로 log에 쌓는 가짜 SnackBarService.

import 'package:pipecheck/core/services/snackbar_service.dart';

class FakeSnack implements SnackBarService {
  final log = <String>[];
  @override
  void showSuccess(String message, {String? id, Duration? duration}) => log.add('success:$message');
  @override
  void showError(String message, {String? id, Duration? duration}) => log.add('error:$message');
  @override
  void showInfo(String message, {String? id, Duration? duration}) => log.add('info:$message');
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
