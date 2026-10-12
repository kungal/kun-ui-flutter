import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../theme/theme.dart';
import 'motion.dart';

/// Web `Ripple.vue`'s `ripple-animation 0.6s`.
const Duration _kRippleDuration = Duration(milliseconds: 600);

/// The web `KunRipple`, which `KunButton` and a clickable `KunCard` draw on
/// every click and which is a phone's only sign that a transparent button
/// was pressed: there is no hover on touch.
///
/// A circle of `foreground` at 30%, as wide as the host's longer side and
/// centred on the pointer, grows to twice that while it fades out under
/// [KunEasing.enter] (web `--ease-kun-out`). It is clipped to the host's
/// padding box, inside a [borderWidth] border, as the web's
/// `overflow-hidden` clips it.
///
/// The host calls [KunRippleLayerState.spawn] from its tap. A key press
/// spawns none: the browser clicks a key-activated button at (0, 0), which
/// puts the web's ripple outside the host (measured in Chromium 151). Under
/// [kunReducedMotion] none is spawned either, because the base stylesheet
/// ends the keyframes at once, on their invisible last frame.
class KunRippleLayer extends StatefulWidget {
  /// Draws ripples over [child].
  const KunRippleLayer({
    required this.radius,
    required this.child,
    this.borderWidth = 0,
    super.key,
  });

  /// The host's outer corner radius.
  final double radius;

  /// The host's border, which the ripple stays inside.
  final double borderWidth;

  /// The host.
  final Widget child;

  @override
  State<KunRippleLayer> createState() => KunRippleLayerState();
}

/// Spawns the ripples of a [KunRippleLayer].
class KunRippleLayerState extends State<KunRippleLayer>
    with TickerProviderStateMixin {
  final List<_Ripple> _ripples = <_Ripple>[];

  /// Starts a ripple under the pointer at [globalPosition].
  void spawn(Offset globalPosition) {
    if (kunReducedMotion(context)) {
      return;
    }
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final double inset = widget.borderWidth;
    final _Ripple ripple = _Ripple(
      center: box.globalToLocal(globalPosition) - Offset(inset, inset),
      diameter: math.max(box.size.width, box.size.height) - 2 * inset,
      controller: AnimationController(vsync: this, duration: _kRippleDuration),
    );
    ripple.controller.forward().whenCompleteOrCancel(() {
      if (!mounted) {
        return;
      }
      setState(() => _ripples.remove(ripple));
      ripple.controller.dispose();
    });
    setState(() => _ripples.add(ripple));
  }

  @override
  void dispose() {
    for (final _Ripple ripple in _ripples) {
      ripple.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double inset = widget.borderWidth;
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child,
        if (_ripples.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.all(inset),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    math.max(0, widget.radius - inset),
                  ),
                  child: CustomPaint(
                    painter: _RipplePainter(
                      ripples: List<_Ripple>.of(_ripples),
                      color: KunTheme.of(context).colors.foreground,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Ripple {
  _Ripple({
    required this.center,
    required this.diameter,
    required this.controller,
  });

  final Offset center;
  final double diameter;
  final AnimationController controller;
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.ripples, required this.color})
      : super(
          repaint: Listenable.merge(<Listenable>[
            for (final _Ripple ripple in ripples) ripple.controller,
          ]),
        );

  final List<_Ripple> ripples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final _Ripple ripple in ripples) {
      final double progress =
          KunEasing.enter.transform(ripple.controller.value);
      canvas.drawCircle(
        ripple.center,
        ripple.diameter * progress,
        Paint()..color = color.withValues(alpha: 0.3 * (1 - progress)),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.color != color || !listEquals(oldDelegate.ripples, ripples);
}
