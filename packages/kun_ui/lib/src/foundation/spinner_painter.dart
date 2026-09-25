import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// One turn of the KunUI spinner.
///
/// Keeps spinning under reduced motion, unlike KunPulseLayer, and the
/// duration is the SVG's rather than KunSpin's. Both follow the web: the
/// motion is SMIL (`<animateTransform dur="0.75s" repeatCount="indefinite">`)
/// inside the icon, which no CSS `prefers-reduced-motion` rule reaches and
/// Tailwind's `animate-spin` has nothing to do with. Measured on a Pixel 10
/// Pro with "remove animations" on: the skeleton pulse froze, this did not.
const Duration kunSpinnerPeriod = Duration(milliseconds: 750);

/// Paints the KunUI spinner geometry: a 24-unit viewBox with a 3-unit ring
/// stroke (radii 8–11) at 25% opacity, and a 90° arc.
class KunSpinnerPainter extends CustomPainter {
  /// Creates a painter for one frame of the spinner.
  const KunSpinnerPainter({required this.color, required this.turns});

  /// Ring and arc color. The ring is drawn at 25% opacity.
  final Color color;

  /// Rotation in turns; `0` and `1` are the same pose, one full revolution.
  final double turns;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 24;
    final center = size.center(Offset.zero);
    final radius = 9.5 * unit; // midline of the SVG's 8–11 annulus
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * unit
      ..color = color.withValues(alpha: 0.25);
    canvas.drawCircle(center, radius, stroke);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * unit
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      turns * 2 * math.pi + math.pi, // the SVG arc starts at 9 o'clock
      math.pi / 2,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(KunSpinnerPainter oldDelegate) =>
      oldDelegate.turns != turns || oldDelegate.color != color;
}
