import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../theme/theme.dart';
import 'pulse.dart';

/// Web `KunSkeleton` `variant`.
enum KunSkeletonVariant {
  /// A line of text: one em tall, [KunRounded.md] corners.
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

    final double resolvedHeight = height ??
        switch (variant) {
          KunSkeletonVariant.text =>
            DefaultTextStyle.of(context).style.fontSize ?? kDefaultFontSize,
          KunSkeletonVariant.circle => KunSpacing.unit * 10,
          KunSkeletonVariant.rect => KunSpacing.unit * 5,
        };

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
