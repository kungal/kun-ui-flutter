import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether [key] is Shift, Control, Alt or Meta, including left, right and
/// generic variants.
bool kunIsModifierKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.shift ||
      key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight ||
      key == LogicalKeyboardKey.control ||
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.alt ||
      key == LogicalKeyboardKey.altLeft ||
      key == LogicalKeyboardKey.altRight ||
      key == LogicalKeyboardKey.meta ||
      key == LogicalKeyboardKey.metaLeft ||
      key == LogicalKeyboardKey.metaRight;
}

/// The 2px CSS `:focus-visible` outline: a filled band 2px outside (or
/// inside, when [offset] is negative) the child, in [color].
///
/// Layout and hit testing follow [child] alone. The band may paint outside
/// the child's bounds. It appears and disappears at once: CSS does not
/// transition `outline-style`.
class KunFocusOutline extends StatelessWidget {
  /// Creates the outline around [child].
  const KunFocusOutline({
    super.key,
    required this.visible,
    required this.color,
    required this.child,
    this.offset = 2,
    this.borderRadius = BorderRadius.zero,
    this.circle = false,
  });

  /// When false, nothing is painted.
  final bool visible;

  /// Fill colour of the 2px band.
  final Color color;

  /// Distance from the child's edge to the inner edge of the band. Positive
  /// sits outside; negative insets. CSS `outline-offset`.
  final double offset;

  /// The child's corner radii. Ignored when [circle] is true.
  final BorderRadius borderRadius;

  /// Draw both edges as circles (CSS `border-radius: 9999px` on a square).
  final bool circle;

  /// The outlined widget.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: KunFocusOutlinePainter(
        visible: visible,
        color: color,
        offset: offset,
        borderRadius: borderRadius,
        circle: circle,
      ),
      child: child,
    );
  }
}

/// Paints the 2px outline band for [KunFocusOutline].
class KunFocusOutlinePainter extends CustomPainter {
  /// Creates the painter.
  const KunFocusOutlinePainter({
    required this.visible,
    required this.color,
    required this.offset,
    required this.borderRadius,
    required this.circle,
  });

  /// When false, [paint] draws nothing.
  final bool visible;

  /// Fill colour of the 2px band.
  final Color color;

  /// Distance from the child's edge to the inner edge of the band.
  final double offset;

  /// The child's corner radii. Ignored when [circle] is true.
  final BorderRadius borderRadius;

  /// Draw both edges as circles.
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) {
      return;
    }
    final Rect inner = (Offset.zero & size).inflate(offset);
    final Rect outer = inner.inflate(2);
    final RRect innerRRect;
    final RRect outerRRect;
    if (circle) {
      innerRRect = _circleOf(inner);
      outerRRect = _circleOf(outer);
    } else {
      final BorderRadius innerRadius = _inflateBorderRadius(
        borderRadius,
        offset,
      );
      innerRRect = innerRadius.toRRect(inner);
      outerRRect = _inflateBorderRadius(innerRadius, 2).toRRect(outer);
    }
    canvas.drawDRRect(
      outerRRect,
      innerRRect,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant KunFocusOutlinePainter oldDelegate) {
    return visible != oldDelegate.visible ||
        color != oldDelegate.color ||
        offset != oldDelegate.offset ||
        borderRadius != oldDelegate.borderRadius ||
        circle != oldDelegate.circle;
  }
}

RRect _circleOf(Rect rect) {
  final double radius = math.min(rect.width, rect.height) / 2;
  return RRect.fromRectAndRadius(rect, Radius.circular(radius));
}

Radius _inflateRadius(Radius radius, double delta) {
  return Radius.elliptical(
    math.max(0, radius.x + delta),
    math.max(0, radius.y + delta),
  );
}

BorderRadius _inflateBorderRadius(BorderRadius radius, double delta) {
  return BorderRadius.only(
    topLeft: _inflateRadius(radius.topLeft, delta),
    topRight: _inflateRadius(radius.topRight, delta),
    bottomLeft: _inflateRadius(radius.bottomLeft, delta),
    bottomRight: _inflateRadius(radius.bottomRight, delta),
  );
}
