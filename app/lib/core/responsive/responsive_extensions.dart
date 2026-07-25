import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// BuildContext에 반응형 유틸리티를 추가하는 확장
extension ResponsiveContext on BuildContext {
  /// 현재 디바이스 유형
  DeviceType get deviceType => Breakpoints.getDeviceType(this);

  /// 모바일인지 확인
  bool get isMobile => Breakpoints.isMobile(this);

  /// 태블릿인지 확인
  bool get isTablet => Breakpoints.isTablet(this);

  /// 가로 모드인지 확인
  bool get isLandscape => Breakpoints.isLandscape(this);

  /// 세로 모드인지 확인
  bool get isPortrait => Breakpoints.isPortrait(this);

  /// 화면 너비
  double get screenWidth => Breakpoints.screenWidth(this);

  /// 화면 높이
  double get screenHeight => Breakpoints.screenHeight(this);

  /// 반응형 그리드 열 수 (태블릿: 2열, 모바일: 1열)
  int get gridColumns => isTablet ? 2 : 1;

  /// 상세 화면에서의 그리드 열 수 (태블릿 가로: 3열, 태블릿 세로: 2열, 모바일: 1열)
  int get detailGridColumns {
    if (isMobile) return 1;
    return isLandscape ? 3 : 2;
  }

  /// 반응형 수평 패딩
  double get horizontalPadding => isTablet ? 24.0 : 16.0;

  /// 반응형 패딩 EdgeInsets
  EdgeInsets get responsivePadding => EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 16.0,
      );

  /// 반응형 카드 패딩
  EdgeInsets get cardPadding => EdgeInsets.all(isTablet ? 20.0 : 16.0);

  /// 반응형 리스트 아이템 간격
  double get listItemSpacing => isTablet ? 12.0 : 8.0;

  /// 반응형 섹션 간격
  double get sectionSpacing => isTablet ? 32.0 : 24.0;

  /// 반응형 아이콘 크기
  double get iconSize => isTablet ? 28.0 : 24.0;

  /// 반응형 폰트 스케일 (태블릿에서 약간 더 큼)
  double get fontScale => isTablet ? 1.1 : 1.0;

  /// 반응형 최대 컨텐츠 너비 (태블릿에서 컨텐츠 중앙 정렬용)
  double get maxContentWidth => isTablet ? 720.0 : double.infinity;

  /// 모달/다이얼로그 너비
  double get dialogWidth {
    if (isMobile) return screenWidth * 0.9;
    return 400.0; // 태블릿에서는 고정 너비
  }

  /// 디바이스에 따른 값 선택
  T responsive<T>({required T mobile, T? tablet}) {
    return isTablet ? (tablet ?? mobile) : mobile;
  }
}

/// double 값에 반응형 스케일링을 적용하는 확장
extension ResponsiveDouble on double {
  /// 태블릿에서 1.25배로 스케일링
  double scaledFor(BuildContext context) {
    return context.isTablet ? this * 1.25 : this;
  }

  /// 커스텀 비율로 스케일링
  double scaledBy(BuildContext context, {double tabletScale = 1.25}) {
    return context.isTablet ? this * tabletScale : this;
  }
}

/// int 값에 반응형 스케일링을 적용하는 확장
extension ResponsiveInt on int {
  /// 태블릿에서 2배로 스케일링 (그리드 열 등)
  int scaledFor(BuildContext context) {
    return context.isTablet ? this * 2 : this;
  }
}
