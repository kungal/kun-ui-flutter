import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/motion.dart';
import '../theme/theme.dart';
import 'scrollbar.dart';

// Web prop default `'2rem'`.
const double _kDefaultShadowSize = 32;

// Web `epsilon = 1`.
const double _kShadowEpsilon = 1;

const ValueKey<String> _startFadeKey =
    ValueKey<String>('KunScrollShadow.startFade');
const ValueKey<String> _endFadeKey =
    ValueKey<String>('KunScrollShadow.endFade');

/// How a vertical mouse wheel is mapped onto a horizontal strip (web
/// `wheel`).
enum KunScrollShadowWheel {
  /// The wheel is ignored, so the page scrolls (web `false`).
  off,

  /// The wheel scrolls the strip, and at either wall the page takes over
  /// (web `true`).
  on,

  /// The wheel stays on the strip at the walls so the page does not move
  /// (web `'contain'`).
  contain,
}

/// Which scrollbar the scroller draws (web `scrollbar`).
enum KunScrollShadowScrollbar {
  /// No scrollbar — the edge fades are the affordance (web `'hide'`).
  hide,

  /// The thin KunUI scrollbar, [KunScrollbar] (web `'thin'`).
  thin,

  /// Whatever the ambient [ScrollBehavior] draws (web `'auto'`).
  auto,
}

/// A scroll strip with fades at either overflowed edge.
///
/// Implements the web `KunScrollShadow` contract: edge gradients that appear
/// when content is scrolled off an end, and — for a horizontal strip — an
/// optional vertical-wheel mapping and mouse-drag so a desktop pointer can
/// reach off-screen children. The web default `ariaLabel` `'scrollable
/// content'` is not carried over: a Chinese app would read that English
/// literal as the region's name.
class KunScrollShadow extends StatefulWidget {
  /// Creates a scroll strip with edge fades.
  const KunScrollShadow({
    super.key,
    required this.children,
    this.axis = Axis.horizontal,
    this.shadowColor,
    this.shadowSize = _kDefaultShadowSize,
    this.semanticLabel,
    this.wheel = KunScrollShadowWheel.off,
    this.draggable = false,
    this.scrollbar = KunScrollShadowScrollbar.hide,
    this.spacing = KunSpacing.unit * 3,
    this.padding,
    this.controller,
  });

  /// The contents of the strip (web default slot).
  ///
  /// Laid out in a [Row] or [Column], so on a horizontal strip each child
  /// needs a finite width of its own, as in any horizontally scrolling
  /// [Row]: give a card a width. Horizontal children are stretched to the
  /// tallest one, as the web's `flex` row stretches them.
  final List<Widget> children;

  /// Scroll axis (web `axis`). Defaults to [Axis.horizontal].
  final Axis axis;

  /// Fade colour (web `shadowColor`). Null paints the theme
  /// [KunColorScheme.background] opaque — the web default is the raw
  /// `var(--color-background)`, not the `bg-background` utility, so no
  /// global opacity applies.
  final Color? shadowColor;

  /// Fade extent along the axis, in logical pixels (web `shadowSize`).
  /// Defaults to 32, the web `'2rem'`.
  final double shadowSize;

  /// Accessible name of the scrollable region (web `ariaLabel`).
  ///
  /// With a label, a container semantics node is added. Without one, no
  /// extra node is created.
  final String? semanticLabel;

  /// Vertical-wheel mapping onto a horizontal strip (web `wheel`). Ignored
  /// when [axis] is [Axis.vertical], as on the web.
  final KunScrollShadowWheel wheel;

  /// Click-and-drag with a mouse or pen to scroll (web `draggable`).
  ///
  /// Touch already drags. A drag past the slop wins the arena over a
  /// child's tap, so a card's click does not fire after a drag and does
  /// fire on a plain click.
  final bool draggable;

  /// Scrollbar style (web `scrollbar`).
  final KunScrollShadowScrollbar scrollbar;

  /// Gap between [children]. Flutter-only: the web hard-codes `gap-3`.
  final double spacing;

  /// Padding inside the scroller. Flutter-only: the web uses `contentClass`.
  final EdgeInsetsGeometry? padding;

  /// Drives the scroller. Flutter-only. Created and owned when null.
  final ScrollController? controller;

  @override
  State<KunScrollShadow> createState() => _KunScrollShadowState();
}

class _KunScrollShadowState extends State<KunScrollShadow> {
  ScrollController? _owned;
  bool _showStart = false;
  bool _showEnd = false;
  bool _grabbing = false;

  ScrollController get _controller => widget.controller ?? _owned!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _owned = ScrollController();
    }
  }

  @override
  void didUpdateWidget(KunScrollShadow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == oldWidget.controller) {
      return;
    }
    if (oldWidget.controller == null) {
      _owned?.dispose();
      _owned = null;
    }
    if (widget.controller == null) {
      _owned = ScrollController();
    }
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  void _syncFades(ScrollMetrics metrics) {
    final bool start = metrics.pixels > _kShadowEpsilon;
    final bool end = metrics.maxScrollExtent - metrics.pixels > _kShadowEpsilon;
    if (start == _showStart && end == _showEnd) {
      return;
    }
    setState(() {
      _showStart = start;
      _showEnd = end;
    });
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    if (notification.depth != 0) {
      return false;
    }
    _syncFades(notification.metrics);
    return false;
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) {
      return false;
    }
    _syncFades(notification.metrics);
    if (widget.draggable) {
      if (notification is ScrollStartNotification &&
          notification.dragDetails != null) {
        if (!_grabbing) {
          setState(() => _grabbing = true);
        }
      } else if (notification is ScrollEndNotification) {
        if (_grabbing) {
          setState(() => _grabbing = false);
        }
      }
    }
    return false;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    if (!_controller.hasClients) {
      return;
    }
    final double dx = event.scrollDelta.dx;
    final double dy = event.scrollDelta.dy;
    if (dx.abs() >= dy.abs()) {
      return;
    }
    final double delta = dy;
    final ScrollPosition position = _controller.position;
    if (position.maxScrollExtent <= 0) {
      return;
    }
    final bool atWall =
        (delta < 0 && position.pixels <= position.minScrollExtent) ||
            (delta > 0 &&
                position.pixels >= position.maxScrollExtent - _kShadowEpsilon);
    if (atWall) {
      if (widget.wheel == KunScrollShadowWheel.contain) {
        GestureBinding.instance.pointerSignalResolver.register(
          event,
          (PointerSignalEvent _) {},
        );
      }
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      (PointerSignalEvent _) => position.pointerScroll(delta),
    );
  }

  Widget _edgeFade({
    required Key key,
    required bool show,
    required bool start,
    required Color color,
  }) {
    final bool horizontal = widget.axis == Axis.horizontal;
    final AlignmentGeometry begin;
    final AlignmentGeometry end;
    if (horizontal) {
      begin = start
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd;
      end = start
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart;
    } else {
      begin = start ? Alignment.topCenter : Alignment.bottomCenter;
      end = start ? Alignment.bottomCenter : Alignment.topCenter;
    }
    final Widget fade = IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: kunMotion(context, KunDefaultTransition.duration),
          curve: KunDefaultTransition.curve,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: begin,
                end: end,
                colors: <Color>[color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
    if (horizontal) {
      return PositionedDirectional(
        key: key,
        start: start ? 0 : null,
        end: start ? null : 0,
        top: 0,
        bottom: 0,
        width: widget.shadowSize,
        child: fade,
      );
    }
    return Positioned(
      key: key,
      top: start ? 0 : null,
      bottom: start ? null : 0,
      left: 0,
      right: 0,
      height: widget.shadowSize,
      child: fade,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color color =
        widget.shadowColor ?? KunTheme.of(context).colors.background;
    final Widget content = widget.axis == Axis.horizontal
        ? IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: widget.spacing,
              children: widget.children,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: widget.spacing,
            children: widget.children,
          );

    Widget scroller = SingleChildScrollView(
      scrollDirection: widget.axis,
      controller: _controller,
      padding: widget.padding,
      child: content,
    );

    scroller = NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: scroller,
      ),
    );

    if (widget.scrollbar == KunScrollShadowScrollbar.thin) {
      scroller = KunScrollbar(controller: _controller, child: scroller);
    }

    final ScrollBehavior behavior = ScrollConfiguration.of(context);
    final bool hideBars = widget.scrollbar != KunScrollShadowScrollbar.auto;
    if (widget.draggable || hideBars) {
      scroller = ScrollConfiguration(
        behavior: behavior.copyWith(
          scrollbars: hideBars ? false : null,
          dragDevices: widget.draggable
              ? <PointerDeviceKind>{
                  ...behavior.dragDevices,
                  PointerDeviceKind.mouse,
                }
              : null,
        ),
        child: scroller,
      );
    }

    Widget built = Stack(
      children: <Widget>[
        scroller,
        _edgeFade(
          key: _startFadeKey,
          show: _showStart,
          start: true,
          color: color,
        ),
        _edgeFade(
          key: _endFadeKey,
          show: _showEnd,
          start: false,
          color: color,
        ),
      ],
    );

    if (widget.wheel != KunScrollShadowWheel.off &&
        widget.axis == Axis.horizontal) {
      built = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerSignal: _onPointerSignal,
        child: built,
      );
    }

    if (widget.draggable) {
      built = MouseRegion(
        cursor:
            _grabbing ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        child: built,
      );
    }

    final String? label = widget.semanticLabel;
    if (label != null) {
      built = Semantics(
        container: true,
        explicitChildNodes: true,
        label: label,
        child: built,
      );
    }
    return built;
  }
}
