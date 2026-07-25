import 'package:easy_localization/easy_localization.dart';

/// 도메인 액션의 실행 결과를 나타내는 모델
class ActionResult<T> {
  final bool success;
  final T? data;
  final String? message;
  final ActionResultType type;
  
  const ActionResult({
    required this.success,
    this.data,
    this.message,
    this.type = ActionResultType.info,
  });
  
  factory ActionResult.success({
    T? data,
    String? message,
  }) {
    return ActionResult(
      success: true,
      data: data,
      message: message,
      type: ActionResultType.success,
    );
  }
  
  factory ActionResult.error({
    String? message,
  }) {
    return ActionResult(
      success: false,
      message: message ?? 'errors.generic'.tr(),
      type: ActionResultType.error,
    );
  }
  
  factory ActionResult.warning({
    T? data,
    String? message,
  }) {
    return ActionResult(
      success: true,
      data: data,
      message: message,
      type: ActionResultType.warning,
    );
  }
}

enum ActionResultType {
  success,
  error,
  warning,
  info,
}