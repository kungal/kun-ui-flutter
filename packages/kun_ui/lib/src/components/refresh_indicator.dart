import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/control_metrics.dart';
import '../foundation/design.dart';
import '../foundation/motion.dart';
import '../foundation/spinner_painter.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';

// Flutter's overscroll-to-arm thresholds, not design tokens.
const double _kDragContainerExtentPercentage = 0.25;
const double _kDragSizeFactorLimit = 1.5;

enum _RefreshStatus { drag, armed, snap, refresh, done, canceled }

double _shadowMarginOf(List<BoxShadow> shadows) {
  double margin = 0;
  for (final BoxShadow shadow in shadows) {
    final double extent = shadow.blurRadius + shadow.spreadRadius;
    margin = math.max(margin, extent + shadow.offset.dx);
    margin = math.max(margin, extent - shadow.offset.dx);
    margin = math.max(margin, extent + shadow.offset.dy);
    margin = math.max(margin, extent - shadow.offset.dy);
  }
  return math.max(margin, 0);
}

/// KunUI's pull-to-refresh.
///
/// The web design system has no counterpart: on mobile web the browser draws
/// pull-to-refresh itself. KunUI draws that browser-owned touch chrome, the
/// same way it draws its own text-selection toolbar rather than importing
/// Material's. The gesture thresholds, notification handling and status
/// machine mirror Flutter's Material `RefreshIndicator`; this widget never
/// imports it. The disc is KunUI's floating surface and the ring is the
/// spinner geometry.
class KunRefreshIndicator extends StatefulWidget {
  /// Creates a pull-to-refresh wrapper around [child].
  const KunRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color = KunUIColor.primary,
    this.edgeOffset = 0,
    this.displacement = KunSpacing.unit * 10,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.semanticLabel,
  });

  /// Called when the user has dragged far enough to refresh. The returned
  /// [Future] must complete when the refresh operation is finished.
  final Future<void> Function() onRefresh;

  /// The scrollable this indicator listens to. Typically a [ListView] or
  /// [CustomScrollView].
  final Widget child;

  /// Semantic colour of the spinner. Resolved with
  /// [KunUIColorResolve.scaleOf] against the ambient scheme.
  final KunUIColor color;

  /// Where the indicator's travel starts, for example below a status bar or
  /// header. [displacement] is measured from this edge.
  final double edgeOffset;

  /// How far below [edgeOffset] the indicator rests while refreshing.
  final double displacement;

  /// Whether a [ScrollNotification] should be handled. Defaults to
  /// [defaultScrollNotificationPredicate], which accepts only depth 0.
  final ScrollNotificationPredicate notificationPredicate;

  /// Announced while refreshing. When null, the locale's loading
  /// description is used — the same string [KunLoading] reads.
  final String? semanticLabel;

  @override
  State<KunRefreshIndicator> createState() => _KunRefreshIndicatorState();
}

class _KunRefreshIndicatorState extends State<KunRefreshIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _positionController;
  late final AnimationController _scaleController;
  late final AnimationController _spinController;
  late final Animation<double> _positionFactor;
  late final Animation<double> _scaleFactor;

  _RefreshStatus? _status;
  bool? _isIndicatorAtTop;
  double? _dragOffset;

  static final Animatable<double> _kDragSizeFactorLimitTween =
      Tween<double>(begin: 0.0, end: _kDragSizeFactorLimit);

  static final Animatable<double> _oneToZeroTween =
      Tween<double>(begin: 1.0, end: 0.0);

  @override
  void initState() {
    super.initState();
    _positionController = AnimationController(vsync: this);
    _positionFactor = _positionController.drive(_kDragSizeFactorLimitTween);
    _scaleController = AnimationController(vsync: this);
    _scaleFactor = _scaleController.drive(_oneToZeroTween);
    _spinController = AnimationController(
      vsync: this,
      duration: kunSpinnerPeriod,
    );
  }

  @override
  void dispose() {
    _positionController.dispose();
    _scaleController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  double _spinnerOpacity() {
    const double armedAt = 1.0 / _kDragSizeFactorLimit;
    final double t = _positionController.value;
    if (t >= armedAt) {
      return 1;
    }
    if (t <= 0) {
      return 0;
    }
    return t / armedAt;
  }

  bool _shouldStart(ScrollNotification notification) {
    return notification is ScrollStartNotification &&
        notification.dragDetails != null &&
        notification.metrics.axisDirection == AxisDirection.down &&
        notification.metrics.extentBefore == 0.0 &&
        _status == null &&
        _start(notification.metrics.axisDirection);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.notificationPredicate(notification)) {
      return false;
    }
    if (_shouldStart(notification)) {
      setState(() {
        _status = _RefreshStatus.drag;
      });
      return false;
    }
    final bool? indicatorAtTopNow =
        switch (notification.metrics.axisDirection) {
      AxisDirection.down => true,
      AxisDirection.up || AxisDirection.left || AxisDirection.right => null,
    };
    if (indicatorAtTopNow != _isIndicatorAtTop) {
      if (_status == _RefreshStatus.drag || _status == _RefreshStatus.armed) {
        unawaited(_dismiss(_RefreshStatus.canceled));
      }
    } else if (notification is ScrollUpdateNotification) {
      if (_status == _RefreshStatus.drag || _status == _RefreshStatus.armed) {
        if (notification.metrics.axisDirection == AxisDirection.down) {
          _dragOffset = _dragOffset! - notification.scrollDelta!;
        }
        _checkDragOffset(notification.metrics.viewportDimension);
      }
      if (_status == _RefreshStatus.armed && notification.dragDetails == null) {
        _show();
      }
    } else if (notification is OverscrollNotification) {
      if (_status == _RefreshStatus.drag || _status == _RefreshStatus.armed) {
        if (notification.metrics.axisDirection == AxisDirection.down) {
          _dragOffset = _dragOffset! - notification.overscroll;
        }
        _checkDragOffset(notification.metrics.viewportDimension);
      }
    } else if (notification is ScrollEndNotification) {
      switch (_status) {
        case _RefreshStatus.armed:
          if (_positionController.value < 1.0) {
            unawaited(_dismiss(_RefreshStatus.canceled));
          } else {
            _show();
          }
        case _RefreshStatus.drag:
          unawaited(_dismiss(_RefreshStatus.canceled));
        case _RefreshStatus.canceled:
        case _RefreshStatus.done:
        case _RefreshStatus.refresh:
        case _RefreshStatus.snap:
        case null:
          break;
      }
    }
    return false;
  }

  bool _handleIndicatorNotification(
    OverscrollIndicatorNotification notification,
  ) {
    if (notification.depth != 0 || !notification.leading) {
      return false;
    }
    if (_status == _RefreshStatus.drag) {
      notification.disallowIndicator();
      return true;
    }
    return false;
  }

  bool _start(AxisDirection direction) {
    assert(_status == null);
    assert(_isIndicatorAtTop == null);
    assert(_dragOffset == null);
    switch (direction) {
      case AxisDirection.down:
        _isIndicatorAtTop = true;
      case AxisDirection.up:
      case AxisDirection.left:
      case AxisDirection.right:
        _isIndicatorAtTop = null;
        return false;
    }
    _dragOffset = 0.0;
    _scaleController.value = 0.0;
    _positionController.value = 0.0;
    return true;
  }

  void _checkDragOffset(double containerExtent) {
    assert(_status == _RefreshStatus.drag || _status == _RefreshStatus.armed);
    double newValue =
        _dragOffset! / (containerExtent * _kDragContainerExtentPercentage);
    if (_status == _RefreshStatus.armed) {
      newValue = math.max(newValue, 1.0 / _kDragSizeFactorLimit);
    }
    _positionController.value = clampDouble(newValue, 0.0, 1.0);
    if (_status == _RefreshStatus.drag && _spinnerOpacity() >= 1) {
      _status = _RefreshStatus.armed;
    }
  }

  Future<void> _dismiss(_RefreshStatus newMode) async {
    await Future<void>.value();
    if (!mounted) {
      return;
    }
    assert(
      newMode == _RefreshStatus.canceled || newMode == _RefreshStatus.done,
    );
    setState(() {
      _status = newMode;
    });
    final Duration duration = kunMotion(context, KunDurations.exit);
    switch (_status!) {
      case _RefreshStatus.done:
        await _scaleController.animateTo(
          1.0,
          duration: duration,
          curve: KunEasing.exit,
        );
      case _RefreshStatus.canceled:
        await _positionController.animateTo(
          0.0,
          duration: duration,
          curve: KunEasing.exit,
        );
      case _RefreshStatus.armed:
      case _RefreshStatus.drag:
      case _RefreshStatus.refresh:
      case _RefreshStatus.snap:
        assert(false);
    }
    if (mounted && _status == newMode) {
      _spinController.stop();
      _dragOffset = null;
      _isIndicatorAtTop = null;
      setState(() {
        _status = null;
      });
    }
  }

  void _show() {
    assert(_status != _RefreshStatus.refresh);
    assert(_status != _RefreshStatus.snap);
    _status = _RefreshStatus.snap;
    _positionController
        .animateTo(
      1.0 / _kDragSizeFactorLimit,
      duration: kunMotion(context, KunDurations.fast),
      curve: KunEasing.standard,
    )
        .then<void>((void value) {
      if (mounted && _status == _RefreshStatus.snap) {
        _spinController.value = _positionController.value * 0.75;
        unawaited(_spinController.repeat());
        setState(() {
          _status = _RefreshStatus.refresh;
        });
        final Future<void> refreshResult = widget.onRefresh();
        refreshResult.whenComplete(() {
          if (mounted && _status == _RefreshStatus.refresh) {
            unawaited(_dismiss(_RefreshStatus.done));
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: _handleIndicatorNotification,
        child: widget.child,
      ),
    );
    assert(() {
      if (_status == null) {
        assert(_dragOffset == null);
        assert(_isIndicatorAtTop == null);
      } else {
        assert(_dragOffset != null);
        assert(_isIndicatorAtTop != null);
      }
      return true;
    }());

    final bool spinning =
        _status == _RefreshStatus.refresh || _status == _RefreshStatus.done;

    return Stack(
      children: <Widget>[
        child,
        if (_status != null)
          Positioned(
            top: widget.edgeOffset,
            left: 0.0,
            right: 0.0,
            child: SizeTransition(
              alignment: const AlignmentDirectional(-1.0, 1.0),
              sizeFactor: _positionFactor,
              child: Padding(
                padding: EdgeInsets.only(top: widget.displacement),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ScaleTransition(
                    scale: _scaleFactor,
                    child: AnimatedBuilder(
                      animation:
                          spinning ? _spinController : _positionController,
                      builder: (BuildContext context, Widget? child) {
                        return _buildDisc(context, spinning: spinning);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDisc(BuildContext context, {required bool spinning}) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final Color spinnerColor = widget.color.scaleOf(scheme).solid;
    final double diameter = KunControlMetrics.of(KunUISize.md).square;
    final double margin = _shadowMarginOf(KunShadows.md);
    final double turns =
        spinning ? _spinController.value : _positionController.value * 0.75;
    final double opacity = spinning ? 1 : _spinnerOpacity();

    Widget disc = Padding(
      padding: EdgeInsets.all(margin),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.content1,
          shape: BoxShape.circle,
          boxShadow: KunShadows.md,
        ),
        child: SizedBox.square(
          dimension: diameter,
          child: Center(
            child: Opacity(
              opacity: opacity,
              child: CustomPaint(
                size: Size.square(KunSpacing.unit * 5),
                painter: KunSpinnerPainter(
                  color: spinnerColor,
                  turns: turns,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (spinning) {
      final String label = widget.semanticLabel ??
          KunMessagesScope.of(context).loading.description;
      disc = Semantics(label: label, child: disc);
    }
    return disc;
  }
}
