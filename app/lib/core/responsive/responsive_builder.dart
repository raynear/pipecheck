import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// 디바이스 유형에 따라 다른 위젯을 빌드하는 반응형 빌더
///
/// 사용 예시:
/// ```dart
/// ResponsiveBuilder(
///   mobile: MobileLayout(),
///   tablet: TabletLayout(),
///   builder: (context, deviceType) {
///     // mobile/tablet이 제공되지 않은 경우 폴백
///     return DefaultLayout();
///   },
/// )
/// ```
class ResponsiveBuilder extends StatelessWidget {
  /// 모든 케이스에 대한 빌더 함수 (폴백)
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  /// 모바일 전용 위젯 (제공시 builder 대신 사용)
  final Widget? mobile;

  /// 태블릿 전용 위젯 (제공시 builder 대신 사용)
  final Widget? tablet;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
    this.mobile,
    this.tablet,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = Breakpoints.getDeviceType(context);

    return switch (deviceType) {
      DeviceType.mobile => mobile ?? builder(context, deviceType),
      DeviceType.tablet => tablet ?? builder(context, deviceType),
    };
  }
}

/// 가로/세로 모드에 따라 다른 위젯을 빌드하는 빌더
///
/// 사용 예시:
/// ```dart
/// OrientationBuilder2(
///   portrait: PortraitLayout(),
///   landscape: LandscapeLayout(),
/// )
/// ```
class OrientationLayoutBuilder extends StatelessWidget {
  /// 세로 모드 위젯
  final Widget portrait;

  /// 가로 모드 위젯
  final Widget landscape;

  const OrientationLayoutBuilder({
    super.key,
    required this.portrait,
    required this.landscape,
  });

  @override
  Widget build(BuildContext context) {
    return Breakpoints.isPortrait(context) ? portrait : landscape;
  }
}

/// 화면 크기에 따라 값을 선택하는 유틸리티
///
/// 사용 예시:
/// ```dart
/// final columns = ResponsiveValue<int>(
///   context,
///   mobile: 1,
///   tablet: 2,
/// ).value;
/// ```
class ResponsiveValue<T> {
  final BuildContext context;
  final T mobile;
  final T? tablet;

  const ResponsiveValue(
    this.context, {
    required this.mobile,
    this.tablet,
  });

  /// 현재 디바이스에 맞는 값 반환
  T get value {
    final deviceType = Breakpoints.getDeviceType(context);
    return switch (deviceType) {
      DeviceType.mobile => mobile,
      DeviceType.tablet => tablet ?? mobile,
    };
  }
}
