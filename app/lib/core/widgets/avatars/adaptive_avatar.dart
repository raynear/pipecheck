import 'package:boilerplate/core/design/design.dart';
import 'package:flutter/material.dart';

/// 적응형 아바타 (6:3:1 비율 준수)
/// 배경(60%) - 콘텐츠(30%) - 장식(10%)
class AdaptiveAvatar extends StatelessWidget {
  final String? name;
  final String? imageUrl;
  final IconData? icon;
  final AvatarSize size;
  final AvatarShape shape;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback? onTap;
  final Widget? badge;
  final bool showInitials;

  const AdaptiveAvatar({
    super.key,
    this.name,
    this.imageUrl,
    this.icon,
    this.size = AvatarSize.medium,
    this.shape = AvatarShape.circle,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
    this.badge,
    this.showInitials = true,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    // Size configurations
    double avatarSize;
    double iconSize;
    TextStyle textStyle;
    double borderRadius;

    switch (size) {
      case AvatarSize.small:
        avatarSize = 32;
        iconSize = spacing.iconSm;
        textStyle = typography.labelSmall;
        borderRadius = spacing.radiusSm;
        break;
      case AvatarSize.medium:
        avatarSize = 48;
        iconSize = spacing.iconMd;
        textStyle = typography.labelMedium;
        borderRadius = spacing.radiusMd;
        break;
      case AvatarSize.large:
        avatarSize = 64;
        iconSize = spacing.iconLg;
        textStyle = typography.labelLarge;
        borderRadius = spacing.radiusLg;
        break;
      case AvatarSize.xlarge:
        avatarSize = 96;
        iconSize = spacing.iconXl;
        textStyle = typography.titleMedium;
        borderRadius = spacing.radiusXl;
        break;
    }

    // Shape configurations
    BorderRadius? borderRadiusValue;
    BoxShape boxShape;

    switch (shape) {
      case AvatarShape.circle:
        boxShape = BoxShape.circle;
        borderRadiusValue = null;
        break;
      case AvatarShape.square:
        boxShape = BoxShape.rectangle;
        borderRadiusValue = BorderRadius.circular(
          isBoldMinimalism ? 0 : borderRadius,
        );
        break;
    }

    // Content
    Widget content;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      content = _buildImageAvatar(
        imageUrl!,
        avatarSize,
        boxShape,
        borderRadiusValue,
      );
    } else if (icon != null) {
      content = _buildIconAvatar(
        icon!,
        iconSize,
        backgroundColor ?? colors.gray200,
        foregroundColor ?? colors.textSecondary,
      );
    } else if (name != null && showInitials) {
      content = _buildInitialsAvatar(
        name!,
        textStyle,
        backgroundColor ?? colors.primary,
        foregroundColor ?? colors.textOnPrimary,
      );
    } else {
      content = _buildDefaultAvatar(
        iconSize,
        backgroundColor ?? colors.gray200,
        foregroundColor ?? colors.textSecondary,
      );
    }

    Widget avatar = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: boxShape,
        borderRadius: boxShape == BoxShape.rectangle ? borderRadiusValue : null,
        color: imageUrl == null ? backgroundColor ?? colors.gray200 : null,
      ),
      child: ClipRRect(
        borderRadius: boxShape == BoxShape.rectangle
            ? borderRadiusValue ?? BorderRadius.zero
            : BorderRadius.circular(avatarSize / 2),
        child: content,
      ),
    );

    if (badge != null) {
      avatar = Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: badge!,
          ),
        ],
      );
    }

    if (onTap != null) {
      avatar = InkWell(
        onTap: onTap,
        borderRadius: boxShape == BoxShape.rectangle ? borderRadiusValue : BorderRadius.circular(avatarSize / 2),
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildImageAvatar(
    String imageUrl,
    double size,
    BoxShape shape,
    BorderRadius? borderRadius,
  ) {
    return Image.network(
      imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _buildDefaultAvatar(
          size * 0.5,
          context.colors.gray200,
          context.colors.textSecondary,
        );
      },
    );
  }

  Widget _buildIconAvatar(
    IconData icon,
    double iconSize,
    Color backgroundColor,
    Color foregroundColor,
  ) {
    return Container(
      color: backgroundColor,
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: foregroundColor,
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(
    String name,
    TextStyle textStyle,
    Color backgroundColor,
    Color foregroundColor,
  ) {
    final initials = _getInitials(name);
    return Container(
      color: backgroundColor,
      child: Center(
        child: Text(
          initials,
          style: textStyle.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(
    double iconSize,
    Color backgroundColor,
    Color foregroundColor,
  ) {
    return Container(
      color: backgroundColor,
      child: Center(
        child: Icon(
          Icons.person,
          size: iconSize,
          color: foregroundColor,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.isEmpty) return '';

    if (words.length == 1) {
      return words[0].substring(0, 1).toUpperCase();
    } else {
      return '${words[0].substring(0, 1)}${words[1].substring(0, 1)}'.toUpperCase();
    }
  }
}

/// 아바타 그룹
class AdaptiveAvatarGroup extends StatelessWidget {
  final List<AdaptiveAvatar> avatars;
  final int maxAvatars;
  final AvatarSize size;
  final double overlap;

  const AdaptiveAvatarGroup({
    super.key,
    required this.avatars,
    this.maxAvatars = 4,
    this.size = AvatarSize.small,
    this.overlap = 0.3,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final displayAvatars = avatars.take(maxAvatars).toList();
    final remainingCount = avatars.length - displayAvatars.length;

    double avatarSize;
    switch (size) {
      case AvatarSize.small:
        avatarSize = 32;
        break;
      case AvatarSize.medium:
        avatarSize = 48;
        break;
      case AvatarSize.large:
        avatarSize = 64;
        break;
      case AvatarSize.xlarge:
        avatarSize = 96;
        break;
    }

    return SizedBox(
      height: avatarSize,
      child: Stack(
        children: [
          ...displayAvatars.asMap().entries.map((entry) {
            final index = entry.key;
            final avatar = entry.value;

            return Positioned(
              left: index * avatarSize * (1 - overlap),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.backgroundPrimary,
                    width: 2,
                  ),
                ),
                child: avatar,
              ),
            );
          }),
          if (remainingCount > 0)
            Positioned(
              left: displayAvatars.length * avatarSize * (1 - overlap),
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.gray300,
                  border: Border.all(
                    color: colors.backgroundPrimary,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$remainingCount',
                    style: typography.labelMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 상태 표시 아바타
class AdaptiveStatusAvatar extends StatelessWidget {
  final AdaptiveAvatar avatar;
  final StatusIndicator status;

  const AdaptiveStatusAvatar({
    super.key,
    required this.avatar,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Color statusColor;
    switch (status) {
      case StatusIndicator.online:
        statusColor = colors.success;
        break;
      case StatusIndicator.offline:
        statusColor = colors.gray400;
        break;
      case StatusIndicator.busy:
        statusColor = colors.warning;
        break;
      case StatusIndicator.away:
        statusColor = colors.warningLight;
        break;
    }

    return Stack(
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              border: Border.all(
                color: colors.backgroundPrimary,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum AvatarSize { small, medium, large, xlarge }

enum AvatarShape { circle, square }

enum StatusIndicator { online, offline, busy, away }
