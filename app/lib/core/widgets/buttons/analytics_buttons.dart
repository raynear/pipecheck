import 'package:firebase_services/firebase_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

// Firebase Analytics에서 사용 가능한 형태로 파라미터를 변환하는 유틸리티 함수
Map<String, Object>? _sanitizeParameters(Map<String, Object>? parameters) {
  if (parameters == null) return null;

  final sanitizedParams = <String, Object>{};

  parameters.forEach((key, value) {
    // Boolean 값을 문자열로 변환
    if (value is bool) {
      sanitizedParams[key] = value ? '1' : '0';
    }
    // List 값을 JSON 문자열로 변환
    else if (value is List) {
      sanitizedParams[key] = value.toString();
    }
    // Map 값을 JSON 문자열로 변환
    else if (value is Map) {
      sanitizedParams[key] = value.toString();
    }
    // String 또는 num 타입은 그대로 사용
    else if (value is String || value is num) {
      sanitizedParams[key] = value;
    }
    // 기타 타입은 문자열로 변환
    else {
      sanitizedParams[key] = value.toString();
    }
  });

  return sanitizedParams;
}

class AnalyticsElevatedButton extends StatelessWidget {
  final String eventName;
  final Map<String, Object>? parameters;
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  const AnalyticsElevatedButton({
    super.key,
    required this.eventName,
    required this.onPressed,
    required this.child,
    this.parameters,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed == null
          ? null
          : () {
              FirebaseService.logEvent(
                name: eventName,
                parameters: _sanitizeParameters(parameters),
              );
              onPressed?.call();
            },
      style: style,
      child: child,
    );
  }
}

class AnalyticsInkWell extends StatelessWidget {
  final String eventName;
  final Map<String, Object>? parameters;
  final VoidCallback? onTap;
  final Widget child;

  const AnalyticsInkWell({
    super.key,
    required this.eventName,
    required this.onTap,
    required this.child,
    this.parameters,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent, // 배경이 투명하게 설정
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                FirebaseService.logEvent(
                  name: eventName,
                  parameters: _sanitizeParameters(parameters),
                );
                onTap?.call();
              },
        child: child,
      ),
    );
  }
}

class AnalyticsGestureDetector extends StatelessWidget {
  final String eventName;
  final Map<String, Object>? parameters;
  final VoidCallback? onTap;
  final Widget child;

  const AnalyticsGestureDetector({
    super.key,
    required this.eventName,
    required this.onTap,
    required this.child,
    this.parameters,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              FirebaseService.logEvent(
                name: eventName,
                parameters: _sanitizeParameters(parameters),
              );
              onTap?.call();
            },
      child: child,
    );
  }
}

class AnalyticsModalBottomSheet {
  final String eventName;
  final Map<String, Object>? parameters;

  const AnalyticsModalBottomSheet({
    required this.eventName,
    this.parameters,
  });

  Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    Color? backgroundColor,
    double? elevation,
    bool isDismissible = true,
    bool enableDrag = true,
    BoxConstraints? constraints,
    Color? barrierColor,
    ShapeBorder? shape,
    Clip? clipBehavior,
    bool expand = false,
    AnimationController? secondAnimation,
    Curve? animationCurve,
    Curve? previousRouteAnimationCurve,
    bool useRootNavigator = false,
    bool bounce = true,
    Radius topRadius = const Radius.circular(16),
    Duration? duration,
    RouteSettings? settings,
    Color? transitionBackgroundColor,
    BoxShadow? shadow,
    SystemUiOverlayStyle? overlayStyle,
    double? closeProgressThreshold,
  }) {
    FirebaseService.logEvent(
      name: eventName,
      parameters: _sanitizeParameters(parameters),
    );

    return showCupertinoModalBottomSheet(
      context: context,
      builder: builder,
      backgroundColor: backgroundColor,
      elevation: elevation,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      barrierColor: barrierColor,
      shape: shape,
      clipBehavior: clipBehavior,
      expand: expand,
      secondAnimation: secondAnimation,
      animationCurve: animationCurve,
      previousRouteAnimationCurve: previousRouteAnimationCurve,
      useRootNavigator: useRootNavigator,
      bounce: bounce,
      topRadius: topRadius,
      duration: duration,
      settings: settings,
      transitionBackgroundColor: transitionBackgroundColor,
      shadow: shadow,
      overlayStyle: overlayStyle,
      closeProgressThreshold: closeProgressThreshold,
    );
  }
}
