import 'package:flutter/material.dart';

/// 상태에 따라 enable/disable되는 조건부 인터렉티브 위젯
///
/// enabled가 true일 때는 child의 원래 기능을 그대로 사용하고,
/// enabled가 false일 때는 터치하면 onDisabledTap 함수를 실행합니다.
/// 이 함수를 통해 bottomsheet를 띄우거나 Navigator.push를 할 수 있습니다.
class ConditionalInteractiveWidget extends StatelessWidget {
  /// 위젯이 활성화되어 있는지 여부
  final bool enabled;

  /// 실제 보여질 자식 위젯
  final Widget child;

  /// disabled 상태일 때 터치했을 때 실행될 함수
  /// bottomsheet를 띄우거나 Navigator.push 등을 수행할 수 있습니다.
  final VoidCallback? onDisabledTap;

  /// disabled 상태일 때 적용할 불투명도 (기본값: 0.5)
  final double disabledOpacity;

  /// disabled 상태일 때 보여줄 오버레이 색상
  final Color? disabledOverlayColor;

  const ConditionalInteractiveWidget({
    super.key,
    required this.enabled,
    required this.child,
    this.onDisabledTap,
    this.disabledOpacity = 0.5,
    this.disabledOverlayColor,
  });

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);

    // enabled가 true일 때는 child를 그대로 반환
    if (enabled) {
      return child;
    }

    // disabled 상태일 때의 처리
    Widget disabledChild = Stack(
      children: [
        // 원본 child를 불투명하게 표시
        Opacity(
          opacity: disabledOpacity,
          child: child,
        ),
        // disabled 상태임을 나타내는 오버레이
        if (disabledOverlayColor != null)
          Positioned.fill(
            child: Container(
              color: disabledOverlayColor,
            ),
          ),
      ],
    );

    // onDisabledTap이 있을 때는 GestureDetector로 감싸서 터치 이벤트 처리
    if (onDisabledTap != null) {
      return GestureDetector(
        onTap: onDisabledTap,
        child: AbsorbPointer(
          // child의 터치 이벤트를 차단
          absorbing: true,
          child: disabledChild,
        ),
      );
    }

    // onDisabledTap이 없을 때는 단순히 터치 이벤트만 차단
    return AbsorbPointer(
      absorbing: true,
      child: disabledChild,
    );
  }
}

/// 간편한 사용을 위한 확장 메서드
extension ConditionalInteractiveExtension on Widget {
  /// 이 위젯을 조건부 인터렉티브 위젯으로 감쌉니다.
  Widget conditionalInteractive({
    required bool enabled,
    VoidCallback? onDisabledTap,
    double disabledOpacity = 0.5,
    Color? disabledOverlayColor,
  }) {
    return ConditionalInteractiveWidget(
      enabled: enabled,
      onDisabledTap: onDisabledTap,
      disabledOpacity: disabledOpacity,
      disabledOverlayColor: disabledOverlayColor,
      child: this,
    );
  }
}

/// ButtonSegment를 위한 조건부 인터렉티브 확장 메서드
extension ConditionalButtonSegmentExtension<T> on ButtonSegment<T> {
  /// ButtonSegment의 enabled 상태를 조건부로 설정합니다.
  /// condition이 false일 때는 enabled를 false로 설정합니다.
  ButtonSegment<T> conditionalEnabled({
    required bool condition,
  }) {
    return ButtonSegment<T>(
      value: value,
      label: label,
      icon: icon,
      enabled: condition && enabled,
      tooltip: tooltip,
    );
  }

  /// ButtonSegment를 조건부 인터렉티브 ButtonSegment로 변환합니다.
  /// condition이 false일 때는 enabled를 false로 설정하고,
  /// onDisabledTap 콜백을 별도로 저장합니다.
  ConditionalButtonSegment<T> conditionalInteractive({
    required bool condition,
    VoidCallback? onDisabledTap,
  }) {
    return ConditionalButtonSegment<T>(
      originalSegment: this,
      condition: condition,
      onDisabledTap: onDisabledTap,
    );
  }
}

/// 조건부 ButtonSegment를 위한 래퍼 클래스
class ConditionalButtonSegment<T> {
  final ButtonSegment<T> originalSegment;
  final bool condition;
  final VoidCallback? onDisabledTap;

  const ConditionalButtonSegment({
    required this.originalSegment,
    required this.condition,
    this.onDisabledTap,
  });

  /// 실제 ButtonSegment를 반환합니다.
  ButtonSegment<T> build() {
    return ButtonSegment<T>(
      value: originalSegment.value,
      label: originalSegment.label,
      icon: originalSegment.icon,
      enabled: condition && originalSegment.enabled,
      tooltip: originalSegment.tooltip,
    );
  }
}

/// SegmentedButton을 위한 조건부 인터렉티브 헬퍼
class ConditionalSegmentedButton<T> extends StatelessWidget {
  final List<ConditionalButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>>? onSelectionChanged;
  final bool multiSelectionEnabled;
  final bool emptySelectionAllowed;
  final ButtonStyle? style;
  final bool showSelectedIcon;
  final Widget? selectedIcon;

  const ConditionalSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    this.onSelectionChanged,
    this.multiSelectionEnabled = false,
    this.emptySelectionAllowed = false,
    this.style,
    this.showSelectedIcon = true,
    this.selectedIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: segments.map((conditionalSegment) => conditionalSegment.build()).toList(),
      selected: selected,
      onSelectionChanged: (Set<T> newSelection) {
        // 선택된 세그먼트가 disabled 상태인지 확인하고 onDisabledTap 실행
        for (final value in newSelection) {
          final conditionalSegment = segments.firstWhere((seg) => seg.originalSegment.value == value);
          final actualSegment = conditionalSegment.build();

          if (!actualSegment.enabled) {
            // disabled 상태인 세그먼트가 선택되었을 때
            conditionalSegment.onDisabledTap?.call();
            return; // 실제 선택 변경은 하지 않음
          }
        }

        // 모든 선택된 세그먼트가 enabled 상태일 때만 실제 변경
        onSelectionChanged?.call(newSelection);
      },
      multiSelectionEnabled: multiSelectionEnabled,
      emptySelectionAllowed: emptySelectionAllowed,
      style: style,
      showSelectedIcon: showSelectedIcon,
      selectedIcon: selectedIcon,
    );
  }
}
