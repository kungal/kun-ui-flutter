import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../foundation/focus_outline.dart';
import '../foundation/motion.dart';
import '../foundation/split_size.dart';
import '../foundation/tap_target.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';

/// Which pane of a [KunSplitPane] [KunSplitPane.size] belongs to, and which
/// pane [KunSplitPane.showPane] keeps visible while stacked.
enum KunSplitSide {
  /// The left pane.
  start,

  /// The right pane.
  end,
}

/// Below this width of the [KunSplitPane] itself, it shows one pane at a
/// time. The web's `false` is [never].
enum KunSplitStackBelow {
  /// Stack below the theme's `md` breakpoint (48rem / 768).
  md,

  /// Stack below the theme's `lg` breakpoint (64rem / 1024).
  lg,

  /// Keep two panes at any width. The web's `stackBelow: false`.
  never,
}

/// Web `flex: 0 0 1px` on `.kun-split-pane__handle`.
const double _kLineWidth = 1;

/// Web `.kun-split-pane__handle::after { inset: 0 -4px }` — 4px either
/// side of the 1px line.
const double _kMouseGrab = 9;

/// Web `@media (pointer: coarse) { inset: 0 -10px }`.
const double _kCoarseGrab = 21;

/// Web `bg-default/20`, `hover:bg-primary/60`, `focus-visible:ring-primary/40`.
const double _kRestAlpha = 0.2;
const double _kHoverAlpha = 0.6;
const double _kRingAlpha = 0.4;

class _KunSplitArrowIntent extends Intent {
  const _KunSplitArrowIntent(this.direction, this.shift);

  /// `+1` is ArrowRight, `-1` is ArrowLeft.
  final double direction;
  final bool shift;
}

class _KunSplitHomeIntent extends Intent {
  const _KunSplitHomeIntent();
}

class _KunSplitEndIntent extends Intent {
  const _KunSplitEndIntent();
}

/// Two panes with a draggable divider. [size] is the width of the [primary]
/// pane in logical pixels; the other pane takes the rest.
///
/// Stacking is decided from this widget's own width, not the window's.
class KunSplitPane extends StatefulWidget {
  /// Creates a split pane.
  const KunSplitPane({
    super.key,
    required this.start,
    required this.end,
    this.size = 360,
    this.onSizeChanged,
    this.onResizeEnd,
    this.primary = KunSplitSide.start,
    this.minSize = 240,
    this.maxSize = 480,
    this.snapPoints = const <double>[],
    this.snapThreshold = 8,
    this.step = 10,
    this.stackBelow = KunSplitStackBelow.md,
    this.showPane = KunSplitSide.start,
    this.semanticLabel,
  });

  /// The left pane.
  final Widget start;

  /// The right pane.
  final Widget end;

  /// Width of the [primary] pane in logical pixels.
  ///
  /// Updated on every pointer move while dragging; persist from
  /// [onResizeEnd]. A new value from the parent, different from the previous
  /// widget's, replaces the internal width.
  final double size;

  /// Called on every pointer move while dragging, and on each key press that
  /// changes the width. The web's `update:size`.
  final ValueChanged<double>? onSizeChanged;

  /// A drag or a key press finished with this width — the one to persist.
  final ValueChanged<double>? onResizeEnd;

  /// Which pane [size] belongs to; the other takes the rest.
  final KunSplitSide primary;

  /// Narrowest the primary pane can be dragged, in px.
  final double minSize;

  /// Widest the primary pane can be dragged, in px.
  final double maxSize;

  /// Widths the divider is pulled to when it comes within [snapThreshold].
  final List<double> snapPoints;

  /// How close, in px, the divider must come to a snap point to be pulled
  /// to it.
  final double snapThreshold;

  /// Arrow-key step in px; Shift moves five steps.
  final double step;

  /// Below this width of the component itself, show one pane at a time.
  final KunSplitStackBelow stackBelow;

  /// Which pane shows while stacked.
  final KunSplitSide showPane;

  /// Accessible name of the divider. Defaults to
  /// [KunMessages.splitPane.handle].
  final String? semanticLabel;

  @override
  State<KunSplitPane> createState() => _KunSplitPaneState();
}

class _KunSplitPaneState extends State<KunSplitPane> {
  late double _size;
  late final String _uid;
  late final FocusNode _focus;
  bool _dragging = false;
  bool _hovered = false;
  bool _focused = false;

  // A press focuses the divider, as a pointerdown focuses the web's
  // tabindex=0 handle, but the browser keeps :focus-visible off until a key
  // is pressed. Flutter keeps the highlight mode after a mouse press, so
  // without this the ring stayed lit after every drag.
  bool _pointerFocus = false;

  bool get _focusVisible => _focused && !_pointerFocus;
  int? _pointer;
  double _dragOriginX = 0;
  double _dragOriginSize = 0;

  @override
  void initState() {
    super.initState();
    _size = widget.size;
    _uid = 'kun-split-${identityHashCode(this)}';
    _focus = FocusNode(debugLabel: 'KunSplitPane.handle');
  }

  @override
  void didUpdateWidget(KunSplitPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.size != oldWidget.size) {
      _size = widget.size;
    }
  }

  @override
  void dispose() {
    _pointer = null;
    _focus.dispose();
    super.dispose();
  }

  double get _lo {
    final double min = widget.minSize;
    final double max = widget.maxSize;
    return min < max ? min : max;
  }

  double get _hi {
    final double min = widget.minSize;
    final double max = widget.maxSize;
    return min > max ? min : max;
  }

  double get _shownSize {
    final double lo = _lo;
    final double hi = _hi;
    final double clamped = _size < lo ? lo : (_size > hi ? hi : _size);
    return clamped.roundToDouble();
  }

  String get _primaryId => '$_uid-${widget.primary.name}';

  double _resolve(double raw, {double? from}) {
    return resolveKunSplitSize(
      raw,
      KunSplitSizeOptions(
        min: widget.minSize,
        max: widget.maxSize,
        snapPoints: widget.snapPoints,
        snapThreshold: widget.snapThreshold,
        from: from,
      ),
    );
  }

  double _arrowDelta(double direction, bool shift) {
    final double step = widget.step * (shift ? 5 : 1);
    final double signed =
        widget.primary == KunSplitSide.start ? direction : -direction;
    return signed * step;
  }

  void _emitSize(double next) {
    if (next == _size) {
      return;
    }
    setState(() => _size = next);
    widget.onSizeChanged?.call(next);
  }

  void _onArrow(_KunSplitArrowIntent intent) {
    _clearPointerFocus();
    final double current = _shownSize;
    final double next = _resolve(
      current + _arrowDelta(intent.direction, intent.shift),
      from: current,
    );
    if (next == current) {
      return;
    }
    _emitSize(next);
    widget.onResizeEnd?.call(next);
  }

  void _onHome() {
    _clearPointerFocus();
    final double current = _shownSize;
    final double next = _lo;
    if (next == current) {
      return;
    }
    _emitSize(next);
    widget.onResizeEnd?.call(next);
  }

  void _onEnd() {
    _clearPointerFocus();
    final double current = _shownSize;
    final double next = _hi;
    if (next == current) {
      return;
    }
    _emitSize(next);
    widget.onResizeEnd?.call(next);
  }

  void _clearPointerFocus() {
    if (_pointerFocus) {
      setState(() => _pointerFocus = false);
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) {
      return;
    }
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons != kPrimaryButton) {
      return;
    }
    _pointer = event.pointer;
    _dragOriginX = event.position.dx;
    _dragOriginSize = _shownSize;
    _focus.requestFocus();
    setState(() {
      _dragging = true;
      _pointerFocus = true;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    final double delta = (event.position.dx - _dragOriginX) *
        (widget.primary == KunSplitSide.start ? 1 : -1);
    _emitSize(_resolve(_dragOriginSize + delta));
  }

  void _onPointerEnd(PointerEvent event) {
    if (_pointer == null || event.pointer != _pointer) {
      return;
    }
    _pointer = null;
    final double ended = _shownSize;
    final double origin = _dragOriginSize;
    setState(() => _dragging = false);
    if (ended != origin) {
      widget.onResizeEnd?.call(ended);
    }
  }

  bool _isStacked(double width, KunThemeData theme) {
    return switch (widget.stackBelow) {
      KunSplitStackBelow.md => width < theme.breakpoints.md,
      KunSplitStackBelow.lg => width < theme.breakpoints.lg,
      KunSplitStackBelow.never => false,
    };
  }

  double _startWidthForEndPrimary(double width, double shown) {
    final double rest = width - shown - _kLineWidth;
    if (rest < 0) {
      return 0;
    }
    if (rest > width) {
      return width;
    }
    return rest;
  }

  double _grabWidth(BuildContext context) {
    return kunMinTapTargetSize(context) == Size.zero
        ? _kMouseGrab
        : _kCoarseGrab;
  }

  Color _lineColor(KunColorScheme scheme) {
    final Color primary = KunUIColor.primary.scaleOf(scheme).solid;
    if (_dragging || _focusVisible) {
      return primary;
    }
    if (_hovered) {
      return primary.withValues(alpha: _kHoverAlpha);
    }
    return scheme.neutral.solid.withValues(alpha: _kRestAlpha);
  }

  Widget _keep({required bool visible, required Widget child}) {
    return _KeepAlive(visible: visible, child: child);
  }

  Widget _pane({
    required KunSplitSide side,
    required Widget child,
    required bool visible,
    required double? left,
    required double? width,
    double? right,
  }) {
    Widget body = _keep(visible: visible, child: child);
    if (side == widget.primary) {
      body = Semantics(
        identifier: _primaryId,
        container: true,
        child: body,
      );
    }
    return Positioned(
      left: left,
      width: width,
      right: right,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: _dragging,
        child: body,
      ),
    );
  }

  Widget _handle(BuildContext context, double startWidth) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final double grab = _grabWidth(context);
    final double shown = _shownSize;
    final String label =
        widget.semanticLabel ?? KunMessagesScope.of(context).splitPane.handle;
    final double right = shown + _arrowDelta(1, false);
    final double left = shown + _arrowDelta(-1, false);
    final double increased = _resolve(right, from: shown);
    final double decreased = _resolve(left, from: shown);
    final Color primary = KunUIColor.primary.scaleOf(scheme).solid;

    return Positioned(
      left: startWidth - (grab - _kLineWidth) / 2,
      width: grab,
      top: 0,
      bottom: 0,
      child: Semantics(
        key: const ValueKey<String>('KunSplitPane.handle'),
        container: true,
        slider: true,
        focusable: true,
        label: label,
        value: '${shown.toInt()}',
        minValue: '${_lo.toInt()}',
        maxValue: '${_hi.toInt()}',
        increasedValue: '${increased.toInt()}',
        decreasedValue: '${decreased.toInt()}',
        onIncrease: increased == shown
            ? null
            : () => _onArrow(
                  const _KunSplitArrowIntent(1, false),
                ),
        onDecrease: decreased == shown
            ? null
            : () => _onArrow(
                  const _KunSplitArrowIntent(-1, false),
                ),
        controlsNodes: <String>{_primaryId},
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerEnd,
            onPointerCancel: _onPointerEnd,
            child: FocusableActionDetector(
              focusNode: _focus,
              includeFocusSemantics: false,
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.arrowRight):
                    _KunSplitArrowIntent(1, false),
                SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
                    _KunSplitArrowIntent(1, true),
                SingleActivator(LogicalKeyboardKey.arrowLeft):
                    _KunSplitArrowIntent(-1, false),
                SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
                    _KunSplitArrowIntent(-1, true),
                SingleActivator(LogicalKeyboardKey.home): _KunSplitHomeIntent(),
                SingleActivator(LogicalKeyboardKey.home, shift: true):
                    _KunSplitHomeIntent(),
                SingleActivator(LogicalKeyboardKey.end): _KunSplitEndIntent(),
                SingleActivator(LogicalKeyboardKey.end, shift: true):
                    _KunSplitEndIntent(),
              },
              actions: <Type, Action<Intent>>{
                _KunSplitArrowIntent: CallbackAction<_KunSplitArrowIntent>(
                  onInvoke: (_KunSplitArrowIntent intent) {
                    _onArrow(intent);
                    return null;
                  },
                ),
                _KunSplitHomeIntent: CallbackAction<_KunSplitHomeIntent>(
                  onInvoke: (_KunSplitHomeIntent intent) {
                    _onHome();
                    return null;
                  },
                ),
                _KunSplitEndIntent: CallbackAction<_KunSplitEndIntent>(
                  onInvoke: (_KunSplitEndIntent intent) {
                    _onEnd();
                    return null;
                  },
                ),
              },
              onShowFocusHighlight: (bool value) => setState(() {
                _focused = value;
                if (!value) {
                  _pointerFocus = false;
                }
              }),
              mouseCursor: SystemMouseCursors.resizeColumn,
              child: SizedBox.expand(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Spacer(),
                    KunFocusOutline(
                      visible: _focusVisible,
                      color: primary.withValues(alpha: _kRingAlpha),
                      offset: 0,
                      child: AnimatedContainer(
                        duration: kunMotion(
                          context,
                          KunDefaultTransition.duration,
                        ),
                        curve: KunDefaultTransition.curve,
                        width: _kLineWidth,
                        color: _lineColor(scheme),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    return MouseRegion(
      cursor: _dragging ? SystemMouseCursors.resizeColumn : MouseCursor.defer,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final bool stacked = _isStacked(width, theme);
          final double shown = _shownSize;
          final double startWidth = widget.primary == KunSplitSide.start
              ? shown
              : _startWidthForEndPrimary(width, shown);
          final bool showStart =
              !stacked || widget.showPane == KunSplitSide.start;
          final bool showEnd = !stacked || widget.showPane == KunSplitSide.end;

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: <Widget>[
              if (stacked) ...<Widget>[
                _pane(
                  side: KunSplitSide.start,
                  visible: showStart,
                  left: 0,
                  width: null,
                  right: 0,
                  child: widget.start,
                ),
                _pane(
                  side: KunSplitSide.end,
                  visible: showEnd,
                  left: 0,
                  width: null,
                  right: 0,
                  child: widget.end,
                ),
              ] else ...<Widget>[
                _pane(
                  side: KunSplitSide.start,
                  visible: true,
                  left: 0,
                  width: startWidth,
                  child: widget.start,
                ),
                _pane(
                  side: KunSplitSide.end,
                  visible: true,
                  left: startWidth + _kLineWidth,
                  width: null,
                  right: 0,
                  child: widget.end,
                ),
                _handle(context, startWidth),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _KeepAlive extends StatelessWidget {
  const _KeepAlive({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !visible,
      child: TickerMode(enabled: visible, child: child),
    );
  }
}
