import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../theme/theme.dart';

/// Which way a [KunDivider] runs.
enum KunDividerOrientation {
  /// A line across the available width.
  horizontal,

  /// A line down the available height.
  vertical,
}

/// How a [KunDivider]'s line is drawn.
enum KunDividerBorderStyle {
  /// One unbroken line, the web's `border-solid`.
  solid,

  /// A broken line, the web's `border-dashed`.
  dashed,
}

/// A separator, with an optional label sitting in the middle of it.
///
/// The line is the semantic colour at 20%, or the shared border token for
/// [KunUIColor.neutral] — the web tints it down deliberately, because a
/// separator drawn at full strength competes with the content either side of
/// it.
class KunDivider extends StatelessWidget {
  /// Creates a divider.
  const KunDivider({
    this.orientation = KunDividerOrientation.horizontal,
    this.color = KunUIColor.neutral,
    this.borderStyle = KunDividerBorderStyle.solid,
    this.child,
    super.key,
  });

  /// Which way the line runs. A vertical divider needs a bounded height, as a
  /// horizontal one needs a bounded width.
  final KunDividerOrientation orientation;

  /// The line's hue.
  final KunUIColor color;

  /// Whether the line is solid or dashed.
  final KunDividerBorderStyle borderStyle;

  /// A label in the middle, with the line running either side of it.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final Color line = color == KunUIColor.neutral
        ? scheme.border
        : color.scaleOf(scheme).solid.withValues(alpha: 0.2);
    final bool horizontal = orientation == KunDividerOrientation.horizontal;

    Widget rule() => Expanded(
          child: CustomPaint(
            painter: _KunDividerLine(
              color: line,
              horizontal: horizontal,
              dashed: borderStyle == KunDividerBorderStyle.dashed,
            ),
            child: SizedBox(
              width: horizontal ? null : _kLineWidth,
              height: horizontal ? _kLineWidth : null,
            ),
          ),
        );

    final Widget? label = child == null
        ? null
        : Padding(
            padding: horizontal
                ? const EdgeInsets.symmetric(horizontal: KunSpacing.unit * 4)
                : const EdgeInsets.symmetric(vertical: KunSpacing.unit * 4),
            child: DefaultTextStyle.merge(
              style: KunText.sm.copyWith(color: scheme.neutral.shade500),
              softWrap: horizontal ? false : null,
              child: child!,
            ),
          );

    final List<Widget> children = <Widget>[
      rule(),
      if (label != null) ...<Widget>[label, rule()],
    ];

    return Semantics(
      container: true,
      child: horizontal
          ? Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children,
            )
          : Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children,
            ),
    );
  }
}

/// The web's `border-t` / `border-l` is one CSS pixel.
const double _kLineWidth = 1;

class _KunDividerLine extends CustomPainter {
  const _KunDividerLine({
    required this.color,
    required this.horizontal,
    required this.dashed,
  });

  final Color color;
  final bool horizontal;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = _kLineWidth;
    final double length = horizontal ? size.width : size.height;
    Offset at(double along) => horizontal
        ? Offset(along, _kLineWidth / 2)
        : Offset(_kLineWidth / 2, along);

    if (!dashed) {
      canvas.drawLine(at(0), at(length), paint);
      return;
    }
    // CSS leaves a dashed border's geometry to the browser, so this is
    // measured rather than derived: Chrome draws a dash of twice the line's
    // thickness, then stretches the gap so a whole number of dashes fills
    // the side. A 40px rule at 20x zoom came back as 14 dashes of 40 device
    // px with gaps of 18 and 19 — exactly this arithmetic.
    const double dash = _kLineWidth * 2;
    const double nominalGap = _kLineWidth;
    final int count = ((length + nominalGap) / (dash + nominalGap)).round();
    if (count <= 1) {
      canvas.drawLine(at(0), at(math.min(dash, length)), paint);
      return;
    }
    final double gap = (length - count * dash) / (count - 1);
    for (int i = 0; i < count; i++) {
      final double start = i * (dash + gap);
      canvas.drawLine(at(start), at(math.min(start + dash, length)), paint);
    }
  }

  @override
  bool shouldRepaint(_KunDividerLine oldDelegate) =>
      color != oldDelegate.color ||
      horizontal != oldDelegate.horizontal ||
      dashed != oldDelegate.dashed;
}
