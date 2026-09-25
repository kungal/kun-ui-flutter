import 'package:flutter/widgets.dart';

import '../foundation/spinner_painter.dart';

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
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kunSpinnerPeriod,
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
        painter: KunSpinnerPainter(color: color, turns: _controller.value),
      ),
    );
    if (widget.semanticLabel == null) return spinner;
    return Semantics(label: widget.semanticLabel, child: spinner);
  }
}
