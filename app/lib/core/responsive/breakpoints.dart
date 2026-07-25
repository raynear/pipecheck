import 'package:flutter/material.dart';

/// 디바이스 유형 enum
enum DeviceType {
  /// 스마트폰 (< 600dp)
  mobile,

  /// 태블릿 (>= 600dp)
  tablet,
}

/// 반응형 브레이크포인트 유틸리티
///
/// Material Design 3 가이드라인 기반:
/// - Compact (mobile): 0-599dp
/// - Medium (tablet): 600-839dp
/// - Expanded (desktop): 840dp+
///
/// 이 BoilerPlate는 모바일 + 태블릿만 지원하므로 600dp를 기준으로 함
class Breakpoints {
  Breakpoints._();

  /// 태블릿 최소 너비 (dp)
  static const double tabletMinWidth = 600;

  /// 태블릿 최소 높이 - 가로 모드 감지용 (dp)
  static const double tabletMinHeight = 480;

  /// 현재 화면의 디바이스 유형 반환
  static DeviceType getDeviceType(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width < tabletMinWidth ? DeviceType.mobile : DeviceType.tablet;
  }

  /// 모바일인지 확인
  static bool isMobile(BuildContext context) => getDeviceType(context) == DeviceType.mobile;

  /// 태블릿인지 확인
  static bool isTablet(BuildContext context) => getDeviceType(context) == DeviceType.tablet;

  /// 가로 모드인지 확인
  static bool isLandscape(BuildContext context) => MediaQuery.orientationOf(context) == Orientation.landscape;

  /// 세로 모드인지 확인
  static bool isPortrait(BuildContext context) => MediaQuery.orientationOf(context) == Orientation.portrait;

  /// 현재 화면 너비 반환
  static double screenWidth(BuildContext context) => MediaQuery.sizeOf(context).width;

  /// 현재 화면 높이 반환
  static double screenHeight(BuildContext context) => MediaQuery.sizeOf(context).height;
}
