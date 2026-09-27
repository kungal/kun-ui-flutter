import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../chat/constants.dart';
import '../chat/support.dart';
import '../chat/types.dart';
import '../foundation/motion.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'chat_shared.dart';

/// Web `ChatTyping.vue:46` `1.2s`.
const Duration _kDotDuration = Duration(milliseconds: 1200);

/// Web `cubic-bezier(0.45, 0, 0.55, 1)`.
const Cubic _kDotCurve = Cubic(0.45, 0, 0.55, 1);

/// Web second-dot `animation-delay: 0.15s`.
const Duration _kDotDelay2 = Duration(milliseconds: 150);

/// Web third-dot `animation-delay: 0.3s`.
const Duration _kDotDelay3 = Duration(milliseconds: 300);

/// Web dot `width` / `height` `5px`.
const double _kDotSize = 5;

/// Web `.kun-chat-typing-dots { gap: 3px }`.
const double _kDotGap = 3;

/// Web keyframe `translateY(-2.5px)`.
const double _kDotHop = 2.5;

/// Web rest `scale(0.75)`.
const double _kDotScaleRest = 0.75;

/// Web rest `opacity: 0.45`.
const double _kDotOpacityRest = 0.45;

/// Web reduced-motion `opacity: 0.7`.
const double _kDotOpacityReduced = 0.7;

/// Web peak keyframe at `25%` of the cycle.
const double _kDotPeakAt = 0.25;

/// Web rest keyframe at `55%` of the cycle.
const double _kDotRestAt = 0.55;

/// "… is typing" with three bouncing dots.
///
/// Renders nothing while nobody is typing. Each notification lapses
/// [kunChatTypingTimeout] after it arrived.
class KunChatTyping extends StatefulWidget {
  /// Creates a typing indicator.
  const KunChatTyping({
    super.key,
    this.events = const <KunChatTypingEvent>[],
    this.kind = KunChatKind.direct,
    this.showText = true,
    this.users = const <KunChatUser>[],
  });

  /// Typing notifications as received, each stamped with the receiving
  /// client's clock.
  final List<KunChatTypingEvent> events;

  /// A direct chat says "typing…" without a name; a group names who is
  /// typing.
  final KunChatKind kind;

  /// Show the sentence beside the dots. When false the sentence is
  /// semantics-only.
  final bool showText;

  /// Users, to name who is typing in a group.
  final List<KunChatUser> users;

  @override
  State<KunChatTyping> createState() => _KunChatTypingState();
}

class _KunChatTypingState extends State<KunChatTyping>
    with SingleTickerProviderStateMixin {
  DateTime _now = DateTime.now();
  Timer? _timer;
  AnimationController? _dots;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncDots();
  }

  @override
  void didUpdateWidget(KunChatTyping oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.events, widget.events)) {
      _now = DateTime.now();
      _schedule();
    }
    _syncDots();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dots?.dispose();
    super.dispose();
  }

  Map<String, DateTime> _latest() {
    final Map<String, DateTime> latest = <String, DateTime>{};
    for (final KunChatTypingEvent event in widget.events) {
      if (_now.difference(event.at) < kunChatTypingTimeout) {
        final DateTime? previous = latest[event.userId];
        if (previous == null || event.at.isAfter(previous)) {
          latest[event.userId] = event.at;
        }
      }
    }
    return latest;
  }

  bool get _active => _latest().isNotEmpty;

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final Map<String, DateTime> typing = _latest();
    if (typing.isEmpty) {
      return;
    }
    DateTime soonest = typing.values.first;
    for (final DateTime at in typing.values) {
      if (at.isBefore(soonest)) {
        soonest = at;
      }
    }
    final DateTime fireAt = soonest.add(kunChatTypingTimeout);
    final int waitMs =
        fireAt.millisecondsSinceEpoch - _now.millisecondsSinceEpoch + 16;
    _timer = Timer(
      Duration(milliseconds: waitMs < 16 ? 16 : waitMs),
      () {
        if (!mounted) {
          return;
        }
        final DateTime wall = DateTime.now();
        setState(() {
          _now = wall.isAfter(fireAt) ? wall : fireAt;
        });
        _schedule();
        _syncDots();
      },
    );
  }

  void _syncDots() {
    final bool run = _active && !kunReducedMotion(context);
    if (!run) {
      _dots?.stop();
      return;
    }
    _dots ??= AnimationController(vsync: this, duration: _kDotDuration);
    if (!_dots!.isAnimating) {
      _dots!.repeat();
    }
  }

  String _label(KunMessages messages) {
    final List<String> ids = _latest().keys.toList();
    if (ids.isEmpty) {
      return '';
    }
    if (widget.kind != KunChatKind.group) {
      return messages.chatTyping.typing;
    }
    final Map<String, KunChatUser> users = kunChatUserMap(widget.users);
    final List<String> names = <String>[
      for (final String id in ids) resolveKunChatUser(users, id, messages).name,
    ];
    if (names.length == 1) {
      return messages.chatTyping.one(name: names.first);
    }
    if (names.length <= 3) {
      return messages.chatTyping.several(
        names: kunChatListJoin(names, messages.code),
      );
    }
    return messages.chatTyping.many(
      name: names.first,
      count: names.length - 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) {
      return const SizedBox.shrink();
    }
    final KunMessages messages = KunMessagesScope.of(context);
    final String label = _label(messages);
    final Color color = DefaultTextStyle.of(context).style.color ??
        KunTheme.of(context).colors.foreground;
    final bool reduced = kunReducedMotion(context);
    final Widget dots = ExcludeSemantics(
      child: _dots == null || reduced
          ? CustomPaint(
              size: const Size(
                _kDotSize * 3 + _kDotGap * 2,
                _kDotSize + _kDotHop,
              ),
              painter: _TypingDotsPainter(
                color: color,
                t: 0,
                reduced: true,
              ),
            )
          : AnimatedBuilder(
              animation: _dots!,
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  size: const Size(
                    _kDotSize * 3 + _kDotGap * 2,
                    _kDotSize + _kDotHop,
                  ),
                  painter: _TypingDotsPainter(
                    color: color,
                    t: _dots!.value,
                    reduced: false,
                  ),
                );
              },
            ),
    );

    if (!widget.showText) {
      return Semantics(
        label: label,
        child: dots,
      );
    }

    return Row(
      children: <Widget>[
        dots,
        const SizedBox(width: KunSpacing.unit * 1.5),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TypingDotsPainter extends CustomPainter {
  const _TypingDotsPainter({
    required this.color,
    required this.t,
    required this.reduced,
  });

  final Color color;
  final double t;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    const List<Duration> delays = <Duration>[
      Duration.zero,
      _kDotDelay2,
      _kDotDelay3,
    ];
    final double yRest = _kDotHop + _kDotSize / 2;
    for (int i = 0; i < 3; i++) {
      final double p = reduced
          ? 0
          : _dotProgress(
              t,
              delays[i].inMilliseconds / _kDotDuration.inMilliseconds,
            );
      final double hop = _kDotHop * p;
      final double scale = _kDotScaleRest + (1 - _kDotScaleRest) * p;
      final double opacity = reduced
          ? _kDotOpacityReduced
          : _kDotOpacityRest + (1 - _kDotOpacityRest) * p;
      final double cx = _kDotSize / 2 + i * (_kDotSize + _kDotGap);
      final double cy = yRest - hop;
      final Paint paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), (_kDotSize / 2) * scale, paint);
    }
  }

  double _dotProgress(double cycle, double delayFrac) {
    double local = (cycle - delayFrac) % 1.0;
    if (local < 0) {
      local += 1.0;
    }
    if (local <= _kDotPeakAt) {
      return _kDotCurve.transform(local / _kDotPeakAt);
    }
    if (local <= _kDotRestAt) {
      return 1 -
          _kDotCurve.transform(
            (local - _kDotPeakAt) / (_kDotRestAt - _kDotPeakAt),
          );
    }
    return 0;
  }

  @override
  bool shouldRepaint(covariant _TypingDotsPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.color != color ||
        oldDelegate.reduced != reduced;
  }
}
