import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../foundation/motion.dart';
import '../theme/theme.dart';

/// How a [KunProgress] draws its fill.
///
/// The web's prop also accepts the rest of [KunUIVariant], and renders every
/// one of them as [solid] — it branches on these four alone, so these four
/// are what the port names.
enum KunProgressVariant {
  /// A flat bar in the semantic colour.
  solid,

  /// A bar shading from the colour's 400 step to its 600 step.
  gradient,

  /// A solid bar under moving diagonal-free stripes of white at 20%.
  striped,

  /// A ring instead of a bar.
  circle,
}

/// A progress bar or ring.
///
/// [value] is clamped into `0..max` and reported as a whole percentage, the
/// same rounding the web does, so a screen reader and the optional label
/// always agree.
class KunProgress extends StatefulWidget {
  /// Creates a progress indicator.
  const KunProgress({
    this.value = 0,
    this.max = 100,
    this.variant = KunProgressVariant.solid,
    this.color = KunUIColor.primary,
    this.size = KunUISize.md,
    this.rounded,
    this.showLabel = false,
    this.indeterminate = false,
    this.semanticLabel,
    super.key,
  });

  /// How far along, in `0..max`.
  final double value;

  /// What [value] counts up to. Zero falls back to 100, as on the web.
  final double max;

  /// How the fill is drawn.
  final KunProgressVariant variant;

  /// The fill's hue.
  final KunUIColor color;

  /// The bar's thickness. Ignored by [KunProgressVariant.circle], which has
  /// the web's single 96px size.
  final KunUISize size;

  /// Corner rounding of the bar; defaults to [KunThemeData.rounded].
  final KunUIRounded? rounded;

  /// Whether to draw the percentage — inside the bar, or in the middle of
  /// the ring.
  final bool showLabel;

  /// Whether progress is unknown: the bar sweeps, the ring spins, and no
  /// value is reported to assistive technology.
  final bool indeterminate;

  /// The accessible name, e.g. `Upload progress`.
  final String? semanticLabel;

  @override
  State<KunProgress> createState() => _KunProgressState();
}

/// The web's `h-24 w-24` ring.
const double _kCircleSize = KunSpacing.unit * 24;

/// The SVG's `stroke-width` against its 100-unit viewBox.
const double _kCircleStroke = 10;

/// The SVG's `r`.
const double _kCircleRadius = 45;

/// The stripe tile, the web's `bg-[length:1rem_1rem]`.
const double _kStripeTile = KunSpacing.unit * 4;

class _KunProgressState extends State<KunProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: Duration.zero);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  @override
  void didUpdateWidget(KunProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLoop();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  /// The looping animations — the sweeping indeterminate bar, the spinning
  /// ring and the moving stripes — run off one controller, at the period the
  /// web gives each. Under reduced motion it never starts, as the base
  /// stylesheet's blanket transition collapse does on the web.
  void _syncLoop() {
    final Duration period = switch (widget) {
      KunProgress(indeterminate: true, variant: KunProgressVariant.circle) =>
        KunSpin.duration,
      KunProgress(indeterminate: true) => const Duration(milliseconds: 1500),
      KunProgress(variant: KunProgressVariant.striped) =>
        const Duration(seconds: 1),
      _ => Duration.zero,
    };
    if (period == Duration.zero || kunReducedMotion(context)) {
      if (_loop.isAnimating) {
        _loop.stop();
      }
      _loop.value = 0;
      return;
    }
    if (_loop.duration != period) {
      _loop.duration = period;
      _loop.value = 0;
      _loop.repeat();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  double get _percentage {
    final double max = widget.max == 0 ? 100 : widget.max;
    final double value = widget.value.clamp(0, max);
    return (value / max * 100).roundToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final KunColorScale scale = widget.color.scaleOf(scheme);
    final double percentage = _percentage;

    final Widget indicator = widget.variant == KunProgressVariant.circle
        ? _buildCircle(scheme, scale, percentage)
        : _buildBar(theme, scheme, scale, percentage);

    return Semantics(
      container: true,
      // Flutter asserts that a progressBar carries a value, a minValue and a
      // maxValue, all of them parseable numbers between the bounds, so an
      // indeterminate bar cannot take the role at all — ARIA allows
      // `role=progressbar` with no `aria-valuenow`, and Flutter does not.
      //
      // The range is 0..100 against the percentage, not 0..max: the web
      // reports `aria-valuenow` as a percentage beside an `aria-valuemax` of
      // `max`, so a bar of 60/60 announces 100 out of 60. That is an upstream
      // bug, and copying it here would trip the assertion.
      role: widget.indeterminate ? null : SemanticsRole.progressBar,
      label: widget.semanticLabel,
      value: widget.indeterminate ? null : '${percentage.toInt()}',
      minValue: widget.indeterminate ? null : '0',
      maxValue: widget.indeterminate ? null : '100',
      child: ExcludeSemantics(child: indicator),
    );
  }

  Widget _buildCircle(
    KunColorScheme scheme,
    KunColorScale scale,
    double percentage,
  ) {
    // The web's ring container is `inline-flex`, so it shrink-wraps rather
    // than filling its parent -- the same Align the badge needs, for the same
    // reason (a bare Container.alignment once produced an 800px badge).
    return Align(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox(
        width: _kCircleSize,
        height: _kCircleSize,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            AnimatedBuilder(
              animation: _loop,
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  size: const Size.square(_kCircleSize),
                  painter: _KunProgressRing(
                    track: scheme.neutral.shade300,
                    fill: scale.solid,
                    percentage: percentage,
                    indeterminate: widget.indeterminate,
                    turns: _loop.value,
                  ),
                );
              },
            ),
            if (widget.showLabel && !widget.indeterminate)
              Text(
                '${percentage.toInt()}%',
                style: KunText.sm.copyWith(
                  color: scheme.foreground,
                  fontWeight: KunFontWeights.medium,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(
    KunThemeData theme,
    KunColorScheme scheme,
    KunColorScale scale,
    double percentage,
  ) {
    final KunUIRounded rounded = widget.rounded ?? theme.rounded;
    final double height = switch (widget.size) {
      KunUISize.xs => KunSpacing.unit,
      KunUISize.sm => KunSpacing.unit * 2,
      KunUISize.md => KunSpacing.unit * 3,
      KunUISize.lg => KunSpacing.unit * 4,
      KunUISize.xl => KunSpacing.unit * 5,
    };
    final BorderRadius radius = BorderRadius.circular(
      rounded == KunUIRounded.full ? height / 2 : rounded.radius,
    );

    Widget fill = switch (widget.variant) {
      KunProgressVariant.gradient => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[scale.shade400, scale.shade600],
            ),
          ),
        ),
      KunProgressVariant.striped => AnimatedBuilder(
          animation: _loop,
          builder: (BuildContext context, Widget? child) => CustomPaint(
            painter: _KunProgressStripes(
              base: scale.solid,
              // The web slides `background-position` from one tile to zero, so
              // the stripes travel backwards over the period.
              shift: (1 - _loop.value) * _kStripeTile,
            ),
          ),
        ),
      _ => ColoredBox(color: scale.solid),
    };

    if (widget.showLabel && !widget.indeterminate) {
      fill = Stack(
        fit: StackFit.expand,
        children: <Widget>[
          fill,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KunSpacing.unit * 2,
              ),
              child: Text(
                '${percentage.toInt()}%',
                maxLines: 1,
                style: KunText.xs.copyWith(
                  color: scale.onSolid,
                  fontWeight: KunFontWeights.medium,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: scheme.neutral.shade300,
          child: widget.indeterminate
              ? AnimatedBuilder(
                  animation: _loop,
                  builder: (BuildContext context, Widget? child) {
                    return FractionallySizedBox(
                      widthFactor: 0.4,
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionalTranslation(
                        // The web sweeps the fill from -150% to 350% of its
                        // own width.
                        translation: Offset(
                          -1.5 + 5 * Curves.easeInOut.transform(_loop.value),
                          0,
                        ),
                        child: ClipRRect(
                          borderRadius: radius,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: fill,
                )
              : AnimatedFractionallySizedBox(
                  duration: kunMotion(context, KunDurations.slow),
                  curve: KunEasing.enter,
                  widthFactor: percentage / 100,
                  alignment: AlignmentDirectional.centerStart,
                  child: fill,
                ),
        ),
      ),
    );
  }
}

class _KunProgressRing extends CustomPainter {
  const _KunProgressRing({
    required this.track,
    required this.fill,
    required this.percentage,
    required this.indeterminate,
    required this.turns,
  });

  final Color track;
  final Color fill;
  final double percentage;
  final bool indeterminate;
  final double turns;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 100;
    final double radius = _kCircleRadius * scale;
    final double stroke = _kCircleStroke * scale;
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final Rect box = Rect.fromCircle(center: centre, radius: radius);

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    // The SVG is rotated -90deg, so the arc starts at twelve o'clock; an
    // indeterminate ring shows the web's fixed 30% and spins.
    final double sweep = (indeterminate ? 0.3 : percentage / 100) * 2 * math.pi;
    if (sweep <= 0) {
      return;
    }
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(turns * 2 * math.pi);
    canvas.translate(-centre.dx, -centre.dy);
    canvas.drawArc(
      box,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KunProgressRing oldDelegate) =>
      track != oldDelegate.track ||
      fill != oldDelegate.fill ||
      percentage != oldDelegate.percentage ||
      indeterminate != oldDelegate.indeterminate ||
      turns != oldDelegate.turns;
}

class _KunProgressStripes extends CustomPainter {
  const _KunProgressStripes({required this.base, required this.shift});

  final Color base;
  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect box = Offset.zero & size;
    canvas.drawRect(box, Paint()..color = base);
    canvas.drawRect(
      box,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(shift, 0),
          Offset(shift + _kStripeTile, 0),
          <Color>[
            const Color(0xFFFFFFFF).withValues(alpha: 0.2),
            const Color(0x00FFFFFF),
          ],
          null,
          TileMode.repeated,
        ),
    );
  }

  @override
  bool shouldRepaint(_KunProgressStripes oldDelegate) =>
      base != oldDelegate.base || shift != oldDelegate.shift;
}
