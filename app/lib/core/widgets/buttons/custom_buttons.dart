import 'package:pipecheck/core/design/design.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// 아이콘이 있는 커스텀 버튼
class IconTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;
  final bool isLoading;

  const IconTextButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.iconSize,
    this.padding,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: padding,
      ),
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(context.colors.white),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: iconSize ?? context.spacing.iconMd),
                SizedBox(width: context.spacing.sm),
                Text(label),
              ],
            ),
    );
  }
}

/// 그라데이션 버튼
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final List<Color>? colors;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Widget? child;

  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.colors,
    this.padding,
    this.width,
    this.height,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColors = colors ?? [context.colors.primary, context.colors.primaryDark];
    final disabledColors = [context.colors.gray300, context.colors.gray400];

    return Container(
      width: width,
      height: height ?? 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: onPressed != null ? effectiveColors : disabledColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: context.spacing.borderRadiusMd,
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: effectiveColors.first.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: context.spacing.borderRadiusMd,
          child: Padding(
            padding: padding ?? context.spacing.buttonPadding,
            child: Center(
              child: child ??
                  Text(
                    label,
                    style: context.typography.button.copyWith(
                      color: context.colors.white,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 소셜 로그인 버튼
class SocialLoginButton extends StatelessWidget {
  final String platform;
  final VoidCallback? onPressed;
  final String? label;
  final Widget? icon;

  const SocialLoginButton({
    super.key,
    required this.platform,
    this.onPressed,
    this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getSocialConfig(platform);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: config['backgroundColor'] as Color?,
        foregroundColor: config['foregroundColor'] as Color?,
        side: BorderSide(
          color: config['borderColor'] as Color? ?? context.colors.border,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.lg,
          vertical: context.spacing.md,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon ?? Icon(config['icon'] as IconData, size: context.spacing.iconMd),
          SizedBox(width: context.spacing.md),
          Text(label ?? 'inputs.socialButton.continueWith'.tr(args: [config['name'] as String])),
        ],
      ),
    );
  }

  Map<String, dynamic> _getSocialConfig(String platform) {
    switch (platform.toLowerCase()) {
      case 'google':
        return {
          'name': 'Google',
          'icon': Icons.g_mobiledata,
          'backgroundColor': Colors.white,
          'foregroundColor': Colors.grey[800],
          'borderColor': Colors.grey[300],
        };
      case 'apple':
        return {
          'name': 'Apple',
          'icon': Icons.apple,
          'backgroundColor': Colors.black,
          'foregroundColor': Colors.white,
          'borderColor': Colors.black,
        };
      case 'kakao':
        return {
          // 브랜드명(영문 표기) — Google/Apple과 동일. 카카오 로그인 기능은 스코프 외.
          'name': 'Kakao',
          'icon': Icons.chat_bubble,
          'backgroundColor': const Color(0xFFFEE500),
          'foregroundColor': Colors.black,
          'borderColor': const Color(0xFFFEE500),
        };
      default:
        return {
          'name': platform,
          'icon': Icons.login,
          'backgroundColor': Colors.grey[100],
          'foregroundColor': Colors.grey[800],
          'borderColor': Colors.grey[300],
        };
    }
  }
}

/// 플로팅 액션 버튼 with 라벨
class ExtendedFab extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isExtended;

  const ExtendedFab({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.isExtended = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        icon: Icon(icon),
        label: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: isExtended ? Text(label) : const SizedBox.shrink(),
        ),
        extendedPadding: isExtended ? null : EdgeInsets.all(context.spacing.lg),
      ),
    );
  }
}
