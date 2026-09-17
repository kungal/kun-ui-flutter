import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/motion.dart';

/// The web `animate-pulse` fade, shared by [KunSkeleton] and [KunAvatar].
///
/// An [AnimationController] of [KunPulse.duration] `/ 2` runs
/// `repeat(reverse: true)` under a [CurvedAnimation] of [KunPulse.curve],
/// mapping opacity from 1 to [KunPulse.midOpacity]. Easing the whole cycle
/// once is the wrong recipe. Under [kunReducedMotion] the controller is
/// stopped and opacity stays 1 — the web's `motion-safe:` removes the
/// animation, it does not shorten it. A change of the setting while mounted
/// starts or stops the ticker.
class KunPulseLayer extends StatefulWidget {
  /// Fades [child] with the pulse, or leaves it at opacity 1 when motion
  /// is reduced.
  const KunPulseLayer({required this.child, super.key});

  /// The placeholder being pulsed.
  final Widget child;

  @override
  State<KunPulseLayer> createState() => _KunPulseLayerState();
}

class _KunPulseLayerState extends State<KunPulseLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: KunPulse.duration ~/ 2,
    );
    _opacity = Tween<double>(begin: 1, end: KunPulse.midOpacity).animate(
      CurvedAnimation(parent: _controller, curve: KunPulse.curve),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _syncMotion() {
    if (kunReducedMotion(context)) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
