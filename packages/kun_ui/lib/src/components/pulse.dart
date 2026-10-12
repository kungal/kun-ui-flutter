import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/motion.dart';

/// The web `animate-pulse` fade, shared by [KunSkeleton] and [KunAvatar].
///
/// One cycle is [KunPulse.duration]: opacity eases from 1 to
/// [KunPulse.midOpacity] under [KunPulse.curve] and back under the same
/// curve. Easing the whole cycle once is the wrong recipe. Under
/// [kunReducedMotion] the ticker is stopped and opacity stays 1 — the web's
/// `motion-safe:` removes the animation, it does not shorten it. A change of
/// the setting while mounted starts or stops the ticker.
///
/// Every layer reads its phase from the frame timestamp rather than from
/// when it mounted, so all placeholders on screen pulse in step: six list
/// rows built over several frames, or an avatar beside a skeleton, rise and
/// fall together.
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
  late final Ticker _ticker = createTicker((_) => _syncPhase());
  final _PulseOpacity _opacity = _PulseOpacity();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _syncMotion() {
    if (kunReducedMotion(context)) {
      if (_ticker.isActive) {
        _ticker.stop();
      }
      _opacity.value = 1;
    } else if (!_ticker.isActive) {
      _syncPhase();
      _ticker.start();
    }
  }

  void _syncPhase() {
    final SchedulerBinding scheduler = SchedulerBinding.instance;
    // A tree attached before the first frame has no timestamp yet; the
    // first tick catches up.
    if (scheduler.schedulerPhase == SchedulerPhase.idle) {
      return;
    }
    _opacity.value = _pulseOpacityAt(scheduler.currentFrameTimeStamp);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

double _pulseOpacityAt(Duration timeStamp) {
  final int period = KunPulse.duration.inMicroseconds;
  final double cycle = (timeStamp.inMicroseconds % period) / period;
  final double t = cycle < 0.5 ? cycle * 2 : 2 - cycle * 2;
  return 1 - (1 - KunPulse.midOpacity) * KunPulse.curve.transform(t);
}

class _PulseOpacity extends Animation<double>
    with
        AnimationEagerListenerMixin,
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin {
  double _value = 1;

  @override
  double get value => _value;

  set value(double next) {
    if (next == _value) {
      return;
    }
    _value = next;
    notifyListeners();
  }

  @override
  AnimationStatus get status => AnimationStatus.forward;
}
