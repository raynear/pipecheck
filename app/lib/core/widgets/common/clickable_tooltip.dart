import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ClickableTooltip extends StatefulWidget {
  final Widget child;
  final String message;
  final Duration? duration;

  ClickableTooltip({
    super.key,
    required this.child,
    required this.message,
    this.duration,
  });

  @override
  State createState() => _ClickableTooltipState();
}

class _ClickableTooltipState extends State<ClickableTooltip> {
  OverlayEntry? _overlayEntry;

  void _showTooltip(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    final tooltipTheme = Theme.of(context).tooltipTheme;
    final textStyle = tooltipTheme.textStyle ??
        const TextStyle(
          color: Colors.white,
          fontSize: 14.0,
        );
    final decoration = tooltipTheme.decoration ??
        BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8.0),
        );
    final padding = tooltipTheme.padding ?? const EdgeInsets.all(12.0);

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: widget.message,
        style: textStyle,
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: 200.0);

    final tooltipWidth = textPainter.width + padding.horizontal + 8;
    final tooltipHeight = textPainter.height + padding.vertical + 8;

    final screenSize = MediaQuery.of(context).size;

    double top = offset.dy + size.height + 5.0;
    double left = offset.dx;

    // 오른쪽 화면을 넘어가는 경우
    if (left + tooltipWidth > screenSize.width) {
      left = screenSize.width - tooltipWidth - 10.0;
    }

    // 아래로 넘어가는 경우 위쪽에 표시
    if (top + tooltipHeight > screenSize.height) {
      top = offset.dy - tooltipHeight - 5.0;
    }

    // 추가적인 경계 검사 및 조정
    if (left < 0) {
      left = 10.0;
    }
    if (top < 0) {
      top = 10.0;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: top,
        left: left,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: tooltipWidth,
            height: tooltipHeight,
            padding: padding,
            decoration: decoration,
            child: Center(
              child: Text(
                widget.message,
                style: textStyle,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );

    if (_overlayEntry != null) {
      Overlay.of(context).insert(_overlayEntry!);
    }

    // 툴팁 자동 제거
    Future.delayed(widget.duration ?? const Duration(seconds: 6), () {
      _hideTooltip();
    });
  }

  void _hideTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_overlayEntry == null) {
          _showTooltip(context);
        } else {
          _hideTooltip();
        }
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _hideTooltip();
    super.dispose();
  }
}
