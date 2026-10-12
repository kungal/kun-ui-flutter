import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../theme/theme.dart';
import 'pulse.dart';

/// Web `KunSkeleton` `variant`.
enum KunSkeletonVariant {
  /// A line of text: one line box of the ambient [DefaultTextStyle] tall,
  /// the height a line of words in that style takes, with a bar one em tall
  /// and [KunRounded.md] corners centred in it. With [KunSkeleton.height]
  /// the bar is that tall and there is no line box around it.
  text,

  /// A circle, as wide as it is tall.
  circle,

  /// A rectangle. Corners follow [KunSkeleton.rounded], then the theme.
  rect,
}

/// Web `KunSkeleton` `animation`.
enum KunSkeletonAnimation {
  /// No pulse.
  none,

  /// The web `animate-pulse` fade, only while motion is allowed.
  pulse,
}

/// A content-loading placeholder implementing the web `KunSkeleton` contract.
///
/// When [loaded] is true, [child] is built with no wrapper (and nothing is
/// built when [child] is null). Otherwise a single box is painted, excluded
/// from semantics. A skeleton whose width fills its parent in a [Row] needs
/// an [Expanded], as the web's `flex-1` wrapper does in the Shapes example.
///
/// A [KunSkeletonVariant.text] placeholder takes the line box of the text
/// style it inherits, so the content below does not move when the words
/// arrive. Give it the style of the content it stands in for, with a
/// [DefaultTextStyle.merge] (the web's `class-name="text-sm"`), and stack the
/// lines of one paragraph without a gap.
///
/// A load is announced once for the loading region, never once per
/// placeholder, and in the app's own words. kun-ui's docs put
/// `aria-live="polite"` and `aria-busy` on the region; `aria-live` is
/// Flutter's `Semantics(liveRegion: true)`, and Flutter has no `aria-busy`.
class KunSkeleton extends StatelessWidget {
  /// Creates a skeleton placeholder.
  const KunSkeleton({
    super.key,
    this.variant = KunSkeletonVariant.rect,
    this.width,
    this.widthFactor,
    this.height,
    this.rounded,
    this.loaded = false,
    this.animation = KunSkeletonAnimation.pulse,
    this.child,
  }) : assert(
          width == null || widthFactor == null,
          'KunSkeleton.width and KunSkeleton.widthFactor cannot both be set.',
        );

  /// Shape preset.
  final KunSkeletonVariant variant;

  /// Web `width` in logical pixels.
  final double? width;

  /// Web `width` as a percentage of the incoming maximum width: `0.6` is
  /// `"60%"`.
  final double? widthFactor;

  /// Web `height` in logical pixels.
  final double? height;

  /// Corner radius, [rect] only. Null follows [KunThemeData.rounded].
  final KunUIRounded? rounded;

  /// When true, show [child] instead of the placeholder.
  final bool loaded;

  /// Whether the placeholder pulses.
  final KunSkeletonAnimation animation;

  /// Web slot `default`.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (loaded) {
      return child ?? const SizedBox.shrink();
    }

    final KunThemeData theme = KunTheme.of(context);
    final Color fill = theme.brightness == Brightness.dark
        ? theme.colors.neutral.shade100.withValues(
            alpha: KunColors.globalOpacity,
          )
        : theme.colors.neutral.shade200;

    double? lineBox;
    final double resolvedHeight;
    if (height != null) {
      resolvedHeight = height!;
    } else {
      switch (variant) {
        case KunSkeletonVariant.text:
          final DefaultTextStyle text = DefaultTextStyle.of(context);
          final TextScaler scaler = MediaQuery.textScalerOf(context);
          resolvedHeight =
              scaler.scale(text.style.fontSize ?? kDefaultFontSize);
          final TextPainter line = TextPainter(
            text: TextSpan(style: text.style),
            textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
            textScaler: scaler,
            textHeightBehavior: text.textHeightBehavior ??
                DefaultTextHeightBehavior.maybeOf(context),
          );
          lineBox = math.max(line.preferredLineHeight, resolvedHeight);
          line.dispose();
        case KunSkeletonVariant.circle:
          resolvedHeight = KunSpacing.unit * 10;
        case KunSkeletonVariant.rect:
          resolvedHeight = KunSpacing.unit * 5;
      }
    }

    final BorderRadius? radius;
    final BoxShape shape;
    switch (variant) {
      case KunSkeletonVariant.circle:
        shape = BoxShape.circle;
        radius = null;
      case KunSkeletonVariant.text:
        shape = BoxShape.rectangle;
        radius = BorderRadius.circular(KunRounded.md);
      case KunSkeletonVariant.rect:
        shape = BoxShape.rectangle;
        radius = BorderRadius.circular((rounded ?? theme.rounded).radius);
    }

    final Widget paint = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        shape: shape,
        borderRadius: radius,
      ),
    );
    // Sized without a LayoutBuilder, which asserts when an IntrinsicHeight
    // row or an IntrinsicWidth dialog body asks the placeholder its size.
    Widget box;
    if (widthFactor != null) {
      box = FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(height: resolvedHeight, child: paint),
      );
    } else {
      box = SizedBox(
        width: width ??
            (variant == KunSkeletonVariant.circle
                ? resolvedHeight
                : double.infinity),
        height: resolvedHeight,
        child: paint,
      );
    }
    if (animation == KunSkeletonAnimation.pulse) {
      box = KunPulseLayer(child: box);
    }
    if (lineBox != null) {
      box = SizedBox(
        height: lineBox,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 1,
          child: box,
        ),
      );
    }
    return ExcludeSemantics(
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        heightFactor: 1,
        child: box,
      ),
    );
  }
}
