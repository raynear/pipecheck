import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// Reusable cached network image widget with built-in loading and error states.
class CachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final double? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  /// Creates a circular avatar image with a given [radius].
  factory CachedImage.avatar({
    Key? key,
    required String imageUrl,
    double radius = 24,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return _CachedAvatarImage(
      key: key,
      imageUrl: imageUrl,
      radius: radius,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      placeholder: (context, url) =>
          placeholder ?? _buildDefaultPlaceholder(colorScheme),
      errorWidget: (context, url, error) =>
          errorWidget ?? _buildDefaultError(colorScheme),
    );

    if (borderRadius != null && borderRadius! > 0) {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius!),
        child: image,
      );
    }

    return image;
  }

  Widget _buildDefaultPlaceholder(ColorScheme colorScheme) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: SpinKitPulse(
          color: colorScheme.primary,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildDefaultError(ColorScheme colorScheme) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: colorScheme.onSurfaceVariant,
          size: 28,
        ),
      ),
    );
  }
}

/// Internal widget for the avatar variant.
class _CachedAvatarImage extends CachedImage {
  final double radius;

  const _CachedAvatarImage({
    super.key,
    required super.imageUrl,
    required this.radius,
    super.placeholder,
    super.errorWidget,
  }) : super(
          width: radius * 2,
          height: radius * 2,
        );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final diameter = radius * 2;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            placeholder ??
            SizedBox(
              width: diameter,
              height: diameter,
              child: Center(
                child: SpinKitPulse(
                  color: colorScheme.primary,
                  size: radius,
                ),
              ),
            ),
        errorWidget: (context, url, error) =>
            errorWidget ??
            Container(
              width: diameter,
              height: diameter,
              color: colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.person,
                color: colorScheme.onSurfaceVariant,
                size: radius,
              ),
            ),
      ),
    );
  }
}
