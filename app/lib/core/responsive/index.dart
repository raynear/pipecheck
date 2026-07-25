/// 반응형 디자인 유틸리티
///
/// 모바일과 태블릿 레이아웃을 쉽게 처리할 수 있는 도구 모음
///
/// 사용 예시:
/// ```dart
/// import 'package:boilerplate/core/responsive/index.dart';
///
/// // Extension 사용
/// if (context.isTablet) {
///   // 태블릿 전용 로직
/// }
///
/// // ResponsiveBuilder 사용
/// ResponsiveBuilder(
///   mobile: MobileLayout(),
///   tablet: TabletLayout(),
///   builder: (context, deviceType) => DefaultLayout(),
/// )
///
/// // ResponsiveValue 사용
/// final columns = ResponsiveValue<int>(
///   context,
///   mobile: 1,
///   tablet: 2,
/// ).value;
/// ```
library;

export 'breakpoints.dart';
export 'responsive_builder.dart';
export 'responsive_extensions.dart';
