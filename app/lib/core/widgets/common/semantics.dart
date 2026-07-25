import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// import 'package:utils/utils.dart';

class SText extends StatelessWidget {
  final String data;
  final String semanticsLabel;
  final TextStyle? style;
  final TextAlign? textAlign;
  final ui.TextDirection? textDirection;
  final bool? softWrap;
  final TextOverflow? overflow;
  final double? textScaleFactor;
  final int? maxLines;
  final Locale? locale;
  final StrutStyle? strutStyle;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final List<String>? args;

  SText(
    this.data, {
    super.key,
    this.semanticsLabel = '',
    this.style,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.maxLines,
    this.locale,
    this.strutStyle,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.args,
  });

  @override
  Widget build(BuildContext context) {
    // Subscribe to the ambient locale so text rebuilds immediately on
    // context.setLocale(). Without this dependency, String.tr() reads
    // easy_localization's global instance and never re-runs when only the
    // locale changes — so a screen preserved by the router (its parent not
    // rebuilt) keeps the old language until navigation/restart.
    // maybeLocaleOf (not localeOf/context.locale) never throws when there is
    // no Localizations/EasyLocalization ancestor, preserving the
    // uninitialized→key fallback that bare-MaterialApp widget tests rely on.
    Localizations.maybeLocaleOf(context);
    final localizedText = data.tr(args: args);
    return Semantics(
      label: semanticsLabel.isNotEmpty ? semanticsLabel : localizedText,
      child: Text(
        localizedText,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaleFactor == null ? null : TextScaler.linear(textScaleFactor ?? 1),
        maxLines: maxLines,
        locale: locale,
        strutStyle: strutStyle,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
      ),
    );
  }
}

class SImage extends StatelessWidget {
  final ImageProvider image;
  final String semanticsLabel;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final bool matchTextDirection;
  final FilterQuality filterQuality;

  SImage({
    super.key,
    required this.image,
    this.semanticsLabel = '',
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.matchTextDirection = false,
    this.filterQuality = FilterQuality.low,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: Image(
        image: image,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        repeat: repeat,
        matchTextDirection: matchTextDirection,
        filterQuality: filterQuality,
      ),
    );
  }
}

class SElevatedButton extends StatelessWidget {
  final String semanticsLabel;
  final void Function()? onPressed;
  final Widget child;
  final ButtonStyle? style;

  SElevatedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.semanticsLabel = '',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
    );
  }
}

class SCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String semanticsLabel;
  final Color? checkColor;
  final bool tristate;
  final WidgetStateProperty<Color?>? fillColor;
  final WidgetStateProperty<Color?>? overlayColor;

  SCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticsLabel = '',
    this.checkColor,
    this.tristate = false,
    this.fillColor,
    this.overlayColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: Checkbox(
        value: value,
        onChanged: onChanged,
        checkColor: checkColor,
        tristate: tristate,
        fillColor: fillColor,
        overlayColor: overlayColor,
      ),
    );
  }
}

/// 단일 라디오 버튼 (Semantics 포함)
///
/// Note: Flutter 3.32.0+에서는 RadioGroup과 함께 사용하는 것을 권장합니다.
/// 단독 사용시 deprecated warning이 발생할 수 있습니다.
class SRadio<T> extends StatelessWidget {
  final T value;
  final String semanticsLabel;
  final WidgetStateProperty<Color?>? fillColor;
  final Color? focusColor;
  final Color? hoverColor;
  final WidgetStateProperty<Color?>? overlayColor;

  SRadio({
    super.key,
    required this.value,
    this.semanticsLabel = '',
    this.fillColor,
    this.focusColor,
    this.hoverColor,
    this.overlayColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: Radio<T>(
        value: value,
        fillColor: fillColor,
        focusColor: focusColor,
        hoverColor: hoverColor,
        overlayColor: overlayColor,
      ),
    );
  }
}

/// 라디오 그룹 (Semantics 포함, Flutter 3.32.0+ 지원)
/// groupValue와 onChanged를 관리하는 RadioGroup 래퍼
class SRadioGroup<T> extends StatelessWidget {
  final List<T> values;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final String semanticsLabel;
  final List<String>? labels;
  final WidgetStateProperty<Color?>? fillColor;
  final Axis direction;
  final double spacing;

  SRadioGroup({
    super.key,
    required this.values,
    required this.groupValue,
    required this.onChanged,
    this.semanticsLabel = '',
    this.labels,
    this.fillColor,
    this.direction = Axis.vertical,
    this.spacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final children = List.generate(values.length, (index) {
      final value = values[index];
      final label = labels != null && index < labels!.length ? labels![index] : null;

      final radio = SRadio<T>(
        value: value,
        semanticsLabel: label ?? '',
        fillColor: fillColor,
      );

      if (label != null) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            radio,
            SizedBox(width: 8),
            Text(label),
          ],
        );
      }
      return radio;
    });

    final content = direction == Axis.horizontal
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: children
                .map((child) => Padding(
                      padding: EdgeInsets.only(right: spacing),
                      child: child,
                    ))
                .toList(),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children
                .map((child) => Padding(
                      padding: EdgeInsets.only(bottom: spacing),
                      child: child,
                    ))
                .toList(),
          );

    return Semantics(
      label: semanticsLabel,
      child: RadioGroup<T>(
        groupValue: groupValue,
        onChanged: onChanged ?? (_) {},
        child: content,
      ),
    );
  }
}

class SListTile extends StatelessWidget {
  final String semanticsLabel;
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final bool isThreeLine;
  final bool? dense;
  final EdgeInsetsGeometry? contentPadding;
  final bool enabled;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final MouseCursor? mouseCursor;
  final bool selected;
  final Color? selectedTileColor;
  final Color? focusColor;
  final Color? hoverColor;
  final bool autofocus;
  final Color? tileColor;
  final ShapeBorder? shape;
  final VisualDensity? visualDensity;
  final FocusNode? focusNode;
  final bool? enableFeedback;

  SListTile({
    super.key,
    this.semanticsLabel = '',
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.isThreeLine = false,
    this.dense,
    this.contentPadding,
    this.enabled = true,
    this.onTap,
    this.onLongPress,
    this.mouseCursor,
    this.selected = false,
    this.selectedTileColor,
    this.focusColor,
    this.hoverColor,
    this.autofocus = false,
    this.tileColor,
    this.shape,
    this.visualDensity,
    this.focusNode,
    this.enableFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: ListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        isThreeLine: isThreeLine,
        dense: dense,
        contentPadding: contentPadding,
        enabled: enabled,
        onTap: onTap,
        onLongPress: onLongPress,
        mouseCursor: mouseCursor,
        selected: selected,
        selectedTileColor: selectedTileColor,
        focusColor: focusColor,
        hoverColor: hoverColor,
        autofocus: autofocus,
        tileColor: tileColor,
        shape: shape,
        visualDensity: visualDensity,
        focusNode: focusNode,
        enableFeedback: enableFeedback,
      ),
    );
  }
}
