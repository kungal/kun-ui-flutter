part of 'message.dart';

const double _kSwipeDismissPx = 80;
const double _kSwipeOpacityPx = 200;
const double _kEnterOffset = 30;
const double _kEnterScale = 0.8;

class _KunMessageToast extends StatefulWidget {
  const _KunMessageToast({
    required this.id,
    required this.message,
    required this.type,
    required this.duration,
    required this.position,
    required this.count,
    required this.leaving,
    required this.throwLeaving,
    required this.onRequestDismiss,
  });

  final String id;
  final String message;
  final KunMessageType type;
  final Duration duration;
  final KunMessagePosition position;
  final int count;
  final bool leaving;
  final bool throwLeaving;
  final void Function({required bool thrown}) onRequestDismiss;

  @override
  State<_KunMessageToast> createState() => _KunMessageToastState();
}

class _KunMessageToastState extends State<_KunMessageToast>
    with TickerProviderStateMixin {
  late final AnimationController _appear;
  late final AnimationController _timer;
  late final AnimationController _throw;
  late final AnimationController _snap;
  late final ValueNotifier<double> _dragDx;

  final GlobalKey _boxKey = GlobalKey();
  final GlobalKey _closeKey = GlobalKey();

  bool _started = false;
  bool _hovered = false;
  bool _closeHovered = false;
  bool _closeFocused = false;
  bool _dragging = false;
  bool _throwing = false;
  bool _snapping = false;
  Timer? _dismissTimer;
  int? _pointer;
  double _startX = 0;
  double _throwFromDx = 0;
  double _throwToDx = 0;
  double _throwFromOpacity = 1;
  double _snapFromDx = 0;
  double _snapFromOpacity = 1;
  bool get _isTop => widget.position._isTop;

  bool get _urgent =>
      widget.type == KunMessageType.error || widget.type == KunMessageType.warn;

  @override
  void initState() {
    super.initState();
    _appear = AnimationController(vsync: this);
    _timer = AnimationController(vsync: this);
    _throw = AnimationController(vsync: this);
    _snap = AnimationController(vsync: this);
    _dragDx = ValueNotifier<double>(0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    unawaited(
      _appear.animateTo(
        1,
        duration: kunMotion(context, KunDurations.slow),
        curve: KunEasing.enter,
      ),
    );
    _armTimer();
    _announce();
  }

  @override
  void didUpdateWidget(_KunMessageToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count ||
        oldWidget.duration != widget.duration) {
      _dismissTimer?.cancel();
      _dismissTimer = null;
      _timer.stop();
      if (widget.duration > Duration.zero) {
        _timer.duration = widget.duration;
      }
      _timer.value = 0;
      _syncTimer();
    }
    if (oldWidget.count != widget.count) {
      _announce();
    }
    if (widget.leaving &&
        !oldWidget.leaving &&
        !widget.throwLeaving &&
        !_throwing) {
      unawaited(
        _appear.animateTo(
          0,
          duration: kunMotion(context, KunDurations.base),
          curve: KunEasing.exit,
        ),
      );
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _appear.dispose();
    _timer.dispose();
    _throw.dispose();
    _snap.dispose();
    _dragDx.dispose();
    super.dispose();
  }

  void _armTimer() {
    if (widget.duration <= Duration.zero) {
      return;
    }
    _timer.duration = widget.duration;
    _timer.value = 0;
    _syncTimer();
  }

  void _announce() {
    if (!mounted) {
      return;
    }
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        widget.message,
        Directionality.of(context),
        assertiveness: _urgent ? Assertiveness.assertive : Assertiveness.polite,
      ),
    );
  }

  // pauseTimer / resumeTimer are idempotent: syncTimer runs on enter, leave,
  // press and release, so one gesture reaches pause or resume more than once.
  // A second pause used to debit remaining time twice (web 2.40.2).
  void _pauseTimer() {
    if (widget.duration <= Duration.zero || _dismissTimer == null) {
      return;
    }
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _timer.stop();
  }

  void _resumeTimer() {
    if (widget.duration <= Duration.zero || _dismissTimer != null) {
      return;
    }
    final Duration? total = _timer.duration;
    if (total == null || total <= Duration.zero) {
      return;
    }
    final Duration remaining = total * (1 - _timer.value);
    if (remaining <= Duration.zero) {
      widget.onRequestDismiss(thrown: false);
      return;
    }
    _dismissTimer = Timer(remaining, () {
      _dismissTimer = null;
      if (mounted && !widget.leaving && !_throwing) {
        widget.onRequestDismiss(thrown: false);
      }
    });
    unawaited(_timer.forward());
  }

  void _syncTimer() {
    if (_hovered || _dragging || _throwing) {
      _pauseTimer();
    } else {
      _resumeTimer();
    }
  }

  void _onHoverEnter() {
    _hovered = true;
    _syncTimer();
    setState(() {});
  }

  void _onHoverExit() {
    _hovered = false;
    _syncTimer();
    setState(() {});
  }

  bool _hitClose(Offset global) {
    final BuildContext? ctx = _closeKey.currentContext;
    if (ctx == null) {
      return false;
    }
    final RenderObject? object = ctx.findRenderObject();
    if (object is! RenderBox || !object.hasSize) {
      return false;
    }
    final Offset local = object.globalToLocal(global);
    return (Offset.zero & object.size).contains(local);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) {
      return;
    }
    if (_hitClose(event.position)) {
      return;
    }
    _pointer = event.pointer;
    _dragging = true;
    _snapping = false;
    _snap.stop();
    _startX = event.position.dx;
    _dragDx.value = 0;
    _syncTimer();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer || !_dragging) {
      return;
    }
    _dragDx.value = event.position.dx - _startX;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _finishDrag();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _finishDrag();
  }

  void _finishDrag() {
    if (!_dragging) {
      return;
    }
    final double dx = _dragDx.value;
    _dragging = false;
    _pointer = null;
    if (dx.abs() > _kSwipeDismissPx) {
      _startThrow(dx);
    } else {
      _startSnap(dx);
      _syncTimer();
    }
  }

  void _startThrow(double dx) {
    _throwing = true;
    _snapping = false;
    _syncTimer();
    final RenderBox? box =
        _boxKey.currentContext?.findRenderObject() as RenderBox?;
    final double width = box?.size.width ?? 0;
    _throwFromDx = dx;
    _throwToDx = dx + dx.sign * width;
    _throwFromOpacity = math.max(0.0, 1 - dx.abs() / _kSwipeOpacityPx);
    widget.onRequestDismiss(thrown: true);
    unawaited(
      _throw.animateTo(
        1,
        duration: kunMotion(context, KunDurations.exit),
        curve: KunEasing.exit,
      ),
    );
  }

  void _startSnap(double dx) {
    if (dx == 0) {
      _dragDx.value = 0;
      return;
    }
    _snapping = true;
    _snapFromDx = dx;
    _snapFromOpacity = math.max(0.0, 1 - dx.abs() / _kSwipeOpacityPx);
    _dragDx.value = 0;
    _snap.value = 0;
    unawaited(
      _snap
          .animateTo(
        1,
        duration: kunMotion(context, KunDurations.slow),
        curve: KunDefaultTransition.curve,
      )
          .whenComplete(() {
        if (mounted) {
          _snapping = false;
          _dragDx.value = 0;
        }
      }),
    );
  }

  void _dismissFromClose() {
    widget.onRequestDismiss(thrown: false);
  }

  KunColorScale _scaleOf(KunColorScheme scheme) {
    return switch (widget.type) {
      KunMessageType.success => scheme.success,
      KunMessageType.error => scheme.danger,
      KunMessageType.warn => scheme.warning,
      KunMessageType.info => scheme.primary,
    };
  }

  IconData get _icon {
    return switch (widget.type) {
      KunMessageType.success => KunIcons.circleCheck,
      KunMessageType.error => KunIcons.circleX,
      KunMessageType.warn => KunIcons.triangleAlert,
      KunMessageType.info => KunIcons.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final KunColorScale scale = _scaleOf(scheme);
    final bool dark = theme.brightness == Brightness.dark;
    final Color fill =
        dark ? scale.shade50.withValues(alpha: 0.9) : scale.shade50;
    final Color textColor = scale.shade800;
    final Listenable motion = Listenable.merge(<Listenable>[
      _appear,
      _throw,
      _snap,
      _dragDx,
    ]);

    final Widget box = _buildBox(
      context,
      scale: scale,
      fill: fill,
      textColor: textColor,
      dark: dark,
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: _urgent ? SemanticsRole.alert : SemanticsRole.status,
      label: widget.message,
      child: MouseRegion(
        onEnter: (_) => _onHoverEnter(),
        onExit: (_) => _onHoverExit(),
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: AnimatedBuilder(
            animation: motion,
            builder: (BuildContext context, Widget? child) {
              return _paintMotion(child!);
            },
            child: box,
          ),
        ),
      ),
    );
  }

  Widget _paintMotion(Widget child) {
    final double appear = _appear.value;
    double dx = 0;
    double opacity = appear;
    double scale = _kEnterScale + (1 - _kEnterScale) * appear;
    double dy = (1 - appear) * (_isTop ? -_kEnterOffset : _kEnterOffset);

    if (_throwing) {
      final double t = _throw.value;
      dx = _throwFromDx + (_throwToDx - _throwFromDx) * t;
      opacity = _throwFromOpacity + (0 - _throwFromOpacity) * t;
      scale = 1;
      dy = 0;
    } else if (_snapping) {
      final double t = _snap.value;
      dx = _snapFromDx + (0 - _snapFromDx) * t;
      opacity = _snapFromOpacity + (1 - _snapFromOpacity) * t;
      scale = 1;
      dy = 0;
    } else if (_dragging || _dragDx.value != 0) {
      dx = _dragDx.value;
      opacity = math.max(0.0, 1 - dx.abs() / _kSwipeOpacityPx);
      scale = 1;
      dy = 0;
    }

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        key: ValueKey<String>('KunMessage.${widget.id}.translate'),
        offset: Offset(dx, dy),
        child: Transform.scale(
          key: ValueKey<String>('KunMessage.${widget.id}.scale'),
          scale: scale,
          child: child,
        ),
      ),
    );
  }

  Widget _buildBox(
    BuildContext context, {
    required KunColorScale scale,
    required Color fill,
    required Color textColor,
    required bool dark,
  }) {
    return KeyedSubtree(
      key: ValueKey<String>('KunMessage.${widget.id}'),
      child: DecoratedBox(
        decoration: KunOuterShadowDecoration(
          shadows: <BoxShadow>[
            ...KunShadows.md,
            BoxShadow(
              color: scale.solid.withValues(alpha: 0.5),
              spreadRadius: 1,
            ),
          ],
          borderRadius: BorderRadius.circular(KunRadius.lg),
        ),
        child: DecoratedBox(
          key: _boxKey,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(KunRadius.lg),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KunRadius.lg),
            child: Stack(
              children: <Widget>[
                // The host sits outside every route, where MaterialApp's
                // fallback style (monospace, underlined) is the ambient one.
                DefaultTextStyle(
                  style: KunText.sm.copyWith(
                    fontWeight: KunFontWeights.medium,
                    color: textColor,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(KunSpacing.unit * 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        ExcludeSemantics(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: KunSpacing.unit * 0.5,
                              right: KunSpacing.unit * 3,
                            ),
                            child: Icon(
                              _icon,
                              size: KunSpacing.unit * 6,
                              color: scale.shade500,
                            ),
                          ),
                        ),
                        Expanded(
                          // The toast's own node carries the message.
                          child: ExcludeSemantics(child: Text(widget.message)),
                        ),
                        if (widget.count > 1)
                          Padding(
                            padding: const EdgeInsets.only(
                                left: KunSpacing.unit * 3),
                            child: SizedBox(
                              width: KunSpacing.unit * 6,
                              height: KunSpacing.unit * 6,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scale.solid.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${widget.count}',
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: KunText.xs.copyWith(
                                      fontWeight: KunFontWeights.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding:
                              const EdgeInsets.only(left: KunSpacing.unit * 2),
                          child: _buildClose(context,
                              textColor: textColor, dark: dark),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.duration > Duration.zero &&
                    !kunReducedMotion(context))
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: KunSpacing.unit * 1,
                    child: ExcludeSemantics(
                      child: AnimatedBuilder(
                        animation: _timer,
                        builder: (BuildContext context, Widget? child) {
                          return Transform.scale(
                            key:
                                ValueKey<String>('KunMessage.${widget.id}.bar'),
                            alignment: Alignment.centerLeft,
                            scaleX: 1 - _timer.value,
                            scaleY: 1,
                            child: child,
                          );
                        },
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: scale.shade400),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClose(
    BuildContext context, {
    required Color textColor,
    required bool dark,
  }) {
    final Color hoverFill =
        (dark ? KunColors.white : KunColors.black).withValues(alpha: 0.1);
    final Duration fade = kunMotion(context, KunDefaultTransition.duration);
    return Semantics(
      button: true,
      label: KunMessagesScope.of(context).message.close,
      child: FocusableActionDetector(
        onShowFocusHighlight: (bool value) {
          setState(() => _closeFocused = value);
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              _dismissFromClose();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (ButtonActivateIntent intent) {
              _dismissFromClose();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _closeHovered = true),
          onExit: (_) => setState(() => _closeHovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismissFromClose,
            child: AnimatedOpacity(
              key: ValueKey<String>('KunMessage.${widget.id}.closeOpacity'),
              opacity: (_hovered || _closeFocused) ? 1 : 0,
              duration: fade,
              curve: KunDefaultTransition.curve,
              child: AnimatedContainer(
                key: _closeKey,
                duration: fade,
                curve: KunDefaultTransition.curve,
                width: KunSpacing.unit * 6,
                height: KunSpacing.unit * 6,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _closeHovered ? hoverFill : null,
                ),
                child: Icon(
                  KunIcons.x,
                  size: KunSpacing.unit * 4,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
