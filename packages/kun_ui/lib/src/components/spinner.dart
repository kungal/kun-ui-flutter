import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The KunUI loading spinner.
///
/// A hand-written port of the one web icon the tier-1 icon font cannot
/// carry: `svg-spinners:90-ring-with-bg` is an *animated* SVG, so
/// kun_ui_icons ships 29 of the web's 30 glyphs and this widget is the
/// 30th. Geometry matches the SVG exactly — a 24-unit viewBox with a
/// 3-unit ring stroke (radii 8–11) at 25% opacity, and a 90° arc making a
/// full turn every 750ms, linear.
class KunSpinner extends StatefulWidget {
  /// Creates a spinner.
  const KunSpinner({super.key, this.size = 24, this.color, this.semanticLabel});

  /// Width and height in logical pixels.
  final double size;

  /// Ring color. Defaults to the ambient [IconTheme] color — the analogue of
  /// the SVG's `currentColor`, which under a [KunTheme] resolves to the
  /// scheme foreground.
  final Color? color;

  /// Announced to assistive technology; nothing is announced when null.
  final String? semanticLabel;

  @override
  State<KunSpinner> createState() => _KunSpinnerState();
}

class _KunSpinnerState extends State<KunSpinner>
    with SingleTickerProviderStateMixin {
  // Keeps spinning under reduced motion, unlike KunPulseLayer, and the
  // duration is the SVG's rather than KunSpin's. Both follow the web: the
  // motion is SMIL (`<animateTransform dur="0.75s" repeatCount="indefinite">`)
  // inside the icon, which no CSS `prefers-reduced-motion` rule reaches and
  // Tailwind's `animate-spin` has nothing to do with. Measured on a Pixel 10
  // Pro with "remove animations" on: the skeleton pulse froze, this did not.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IconTheme.of fills a null color from IconThemeData.fallback, so this is
    // never null; the literal fallback that used to follow it was dead code.
    final color = widget.color ?? IconTheme.of(context).color!;
    final spinner = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _SpinnerPainter(color: color, turns: _controller.value),
      ),
    );
    if (widget.semanticLabel == null) return spinner;
    return Semantics(label: widget.semanticLabel, child: spinner);
  }
}

class _SpinnerPainter extends CustomPainter {
  const _SpinnerPainter({required this.color, required this.turns});

  final Color color;
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
  bool shouldRepaint(_SpinnerPainter oldDelegate) =>
      oldDelegate.turns != turns || oldDelegate.color != color;
}
