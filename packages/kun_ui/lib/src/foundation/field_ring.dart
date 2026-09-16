import 'package:flutter/widgets.dart';

/// The web's flush `ring-2` at 50% opacity, or a zero-alpha, zero-spread
/// counterpart when the ring is not shown.
///
/// A Tailwind ring is a zero-blur spread shadow, so it composes with the
/// field's card shadow the same way it does on the web.
BoxShadow kunFieldRing(Color color, {required bool visible}) => visible
    ? BoxShadow(
        color: color.withValues(alpha: 0.5),
        spreadRadius: 2,
      )
    : BoxShadow(
        color: color.withValues(alpha: 0),
        spreadRadius: 0,
      );

/// Interpolates a [BoxShadow] for the field focus ring.
///
/// The default [Tween.lerp] cannot interpolate a [BoxShadow].
class KunFieldRingTween extends Tween<BoxShadow> {
  /// Creates a ring tween.
  KunFieldRingTween({super.begin, super.end});

  @override
  BoxShadow lerp(double t) => BoxShadow.lerp(begin, end, t)!;
}
