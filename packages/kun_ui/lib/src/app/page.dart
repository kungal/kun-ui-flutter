import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

/// How a [KunPage] or [KunPageRoute] enters and leaves.
enum KunPageTransition {
  /// [slide] on iOS and macOS, [fade] everywhere else.
  platform,

  /// KunUI's "a surface enters" motion: fade and scale from 0.95.
  fade,

  /// The iOS horizontal slide, with the covered page's parallax.
  slide,

  /// No motion and no back gestures. For full-screen viewers.
  none,
}

/// A [Page] that builds a [KunPageRoute] — for Navigator 2 and
/// `go_router`'s `pageBuilder`.
///
/// The created route reads [child] and [transition] from this page on every
/// rebuild, the same pattern as Material's `_PageBasedMaterialPageRoute`.
class KunPage<T> extends Page<T> {
  /// Creates a page whose route shows [child].
  const KunPage({
    required this.child,
    this.transition = KunPageTransition.platform,
    this.maintainState = true,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    super.canPop,
    super.onPopInvoked,
  });

  /// The contents of the route.
  final Widget child;

  /// How the route enters and leaves.
  final KunPageTransition transition;

  /// {@macro flutter.widgets.ModalRoute.maintainState}
  final bool maintainState;

  @override
  Route<T> createRoute(BuildContext context) =>
      _PageBasedKunPageRoute<T>(page: this);
}

/// A [PageRoute] with KunUI transitions — for Navigator 1 and
/// [WidgetsApp.pageRouteBuilder].
class KunPageRoute<T> extends PageRoute<T> with _KunRouteTransitionMixin<T> {
  /// Creates a route whose contents are defined by [builder].
  KunPageRoute({
    required this.builder,
    this.transition = KunPageTransition.platform,
    this.maintainState = true,
    super.settings,
    super.requestFocus,
    super.allowSnapshotting,
  }) {
    assert(opaque);
  }

  /// Builds the primary contents of the route.
  final WidgetBuilder builder;

  @override
  final KunPageTransition transition;

  @override
  final bool maintainState;

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  String get debugLabel => '${super.debugLabel}(${settings.name})';
}

class _PageBasedKunPageRoute<T> extends PageRoute<T>
    with _KunRouteTransitionMixin<T> {
  _PageBasedKunPageRoute({required KunPage<T> page}) : super(settings: page) {
    assert(opaque);
  }

  KunPage<T> get _page => settings as KunPage<T>;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  KunPageTransition get transition => _page.transition;

  @override
  bool get maintainState => _page.maintainState;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';
}

// cupertino/route.dart `_kBackGestureWidth`.
const double _kBackGestureWidth = 20;

// cupertino/route.dart `_kMinFlingVelocity` — screen widths per second.
const double _kMinFlingVelocity = 1;

// dropdown.dart / the existing "a surface enters" scale.
const double _kEnterScaleBegin = 0.95;

final Animatable<Offset> _kRightMiddleTween = Tween<Offset>(
  begin: const Offset(1, 0),
  end: Offset.zero,
);

// cupertino/route.dart `_kMiddleLeftTween`.
final Animatable<Offset> _kMiddleLeftTween = Tween<Offset>(
  begin: Offset.zero,
  end: const Offset(-1 / 3, 0),
);

mixin _KunRouteTransitionMixin<T> on PageRoute<T> {
  /// Builds the primary contents of the route.
  @protected
  Widget buildContent(BuildContext context);

  /// How this route enters and leaves.
  KunPageTransition get transition;

  KunPageTransition get _resolved {
    if (transition != KunPageTransition.platform) {
      return transition;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => KunPageTransition.slide,
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.windows =>
        KunPageTransition.fade,
    };
  }

  bool get _reduceMotion {
    final NavigatorState? nav = navigator;
    if (nav == null) {
      return false;
    }
    return MediaQuery.maybeDisableAnimationsOf(nav.context) ?? false;
  }

  @override
  Duration get transitionDuration {
    if (_reduceMotion) {
      return Duration.zero;
    }
    return switch (_resolved) {
      KunPageTransition.fade || KunPageTransition.platform => KunDurations.base,
      KunPageTransition.slide => KunDurations.slow,
      KunPageTransition.none => Duration.zero,
    };
  }

  @override
  Duration get reverseTransitionDuration {
    if (_reduceMotion) {
      return Duration.zero;
    }
    return switch (_resolved) {
      KunPageTransition.fade || KunPageTransition.platform => KunDurations.exit,
      KunPageTransition.slide => KunDurations.slow,
      KunPageTransition.none => Duration.zero,
    };
  }

  @override
  TickerFuture didPush() {
    controller?.duration = transitionDuration;
    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    controller?.reverseDuration = reverseTransitionDuration;
    return super.didPop(result);
  }

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  DelegatedTransitionBuilder? get delegatedTransition {
    if (_resolved != KunPageTransition.slide) {
      return null;
    }
    return _delegatedSlide;
  }

  Widget? _delegatedSlide(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    return _KunCoveredSlide(
      secondaryAnimation: secondaryAnimation,
      linear: popGestureInProgress,
      child: child,
    );
  }

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    final bool nextHasDelegatedTransition =
        nextRoute is ModalRoute<T> && nextRoute.delegatedTransition != null;
    return (nextRoute is PageRoute<T>) &&
        ((nextRoute is _KunRouteTransitionMixin) || nextHasDelegatedTransition);
  }

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) =>
      previousRoute is PageRoute;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: buildContent(context),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final KunPageTransition resolved = _resolved;
    final bool linear = popGestureInProgress;
    Widget result = child;
    switch (resolved) {
      case KunPageTransition.fade:
        result = _KunFadePageTransition(
          animation: animation,
          linear: linear,
          child: child,
        );
      case KunPageTransition.slide:
        result = _KunSlidePageTransition(
          animation: animation,
          linear: linear,
          child: child,
        );
      case KunPageTransition.none:
      case KunPageTransition.platform:
        result = child;
    }
    if (resolved == KunPageTransition.slide) {
      result = _KunBackGestureDetector<T>(
        enabledCallback: () => popGestureEnabled,
        onStartPopGesture: _startPopGesture,
        child: result,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android &&
        resolved != KunPageTransition.none) {
      result = _KunPredictiveBackDetector(route: this, child: result);
    }
    return result;
  }

  _KunBackGestureController<T> _startPopGesture() {
    assert(popGestureEnabled);
    return _KunBackGestureController<T>(
      navigator: navigator!,
      getIsCurrent: () => isCurrent,
      getIsActive: () => isActive,
      controller: controller!,
    );
  }
}

class _KunFadePageTransition extends StatefulWidget {
  const _KunFadePageTransition({
    required this.animation,
    required this.linear,
    required this.child,
  });

  final Animation<double> animation;
  final bool linear;
  final Widget child;

  @override
  State<_KunFadePageTransition> createState() => _KunFadePageTransitionState();
}

class _KunFadePageTransitionState extends State<_KunFadePageTransition> {
  CurvedAnimation? _curve;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(_KunFadePageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.linear != widget.linear) {
      _curve?.dispose();
      _curve = null;
      _setup();
    }
  }

  @override
  void dispose() {
    _curve?.dispose();
    super.dispose();
  }

  void _setup() {
    final Animation<double> parent;
    if (widget.linear) {
      parent = widget.animation;
    } else {
      _curve = CurvedAnimation(
        parent: widget.animation,
        curve: KunEasing.enter,
        reverseCurve: KunEasing.exit,
      );
      parent = _curve!;
    }
    _fade = parent;
    _scale = Tween<double>(begin: _kEnterScaleBegin, end: 1).animate(parent);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}

class _KunSlidePageTransition extends StatefulWidget {
  const _KunSlidePageTransition({
    required this.animation,
    required this.linear,
    required this.child,
  });

  final Animation<double> animation;
  final bool linear;
  final Widget child;

  @override
  State<_KunSlidePageTransition> createState() =>
      _KunSlidePageTransitionState();
}

class _KunSlidePageTransitionState extends State<_KunSlidePageTransition> {
  CurvedAnimation? _curve;
  late Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(_KunSlidePageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.linear != widget.linear) {
      _curve?.dispose();
      _curve = null;
      _setup();
    }
  }

  @override
  void dispose() {
    _curve?.dispose();
    super.dispose();
  }

  void _setup() {
    final Animation<double> parent;
    if (widget.linear) {
      parent = widget.animation;
    } else {
      _curve = CurvedAnimation(
        parent: widget.animation,
        curve: KunEasing.emphasized,
        reverseCurve: KunEasing.emphasized.flipped,
      );
      parent = _curve!;
    }
    _position = parent.drive(_kRightMiddleTween);
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _position,
      textDirection: Directionality.of(context),
      child: DecoratedBox(
        decoration: const BoxDecoration(boxShadow: KunShadows.md),
        child: widget.child,
      ),
    );
  }
}

class _KunCoveredSlide extends StatefulWidget {
  const _KunCoveredSlide({
    required this.secondaryAnimation,
    required this.linear,
    required this.child,
  });

  final Animation<double> secondaryAnimation;
  final bool linear;
  final Widget? child;

  @override
  State<_KunCoveredSlide> createState() => _KunCoveredSlideState();
}

class _KunCoveredSlideState extends State<_KunCoveredSlide> {
  CurvedAnimation? _curve;
  late Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(_KunCoveredSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.secondaryAnimation != widget.secondaryAnimation ||
        oldWidget.linear != widget.linear) {
      _curve?.dispose();
      _curve = null;
      _setup();
    }
  }

  @override
  void dispose() {
    _curve?.dispose();
    super.dispose();
  }

  void _setup() {
    final Animation<double> parent;
    if (widget.linear) {
      parent = widget.secondaryAnimation;
    } else {
      _curve = CurvedAnimation(
        parent: widget.secondaryAnimation,
        curve: KunEasing.emphasized,
        reverseCurve: KunEasing.emphasized.flipped,
      );
      parent = _curve!;
    }
    _position = parent.drive(_kMiddleLeftTween);
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _position,
      textDirection: Directionality.of(context),
      transformHitTests: false,
      child: widget.child,
    );
  }
}

class _KunBackGestureDetector<T> extends StatefulWidget {
  const _KunBackGestureDetector({
    required this.enabledCallback,
    required this.onStartPopGesture,
    required this.child,
  });

  final Widget child;
  final ValueGetter<bool> enabledCallback;
  final ValueGetter<_KunBackGestureController<T>> onStartPopGesture;

  @override
  State<_KunBackGestureDetector<T>> createState() =>
      _KunBackGestureDetectorState<T>();
}

class _KunBackGestureDetectorState<T>
    extends State<_KunBackGestureDetector<T>> {
  _KunBackGestureController<T>? _backGestureController;
  late HorizontalDragGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    if (_backGestureController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_backGestureController?.navigator.mounted ?? false) {
          _backGestureController?.navigator.didStopUserGesture();
        }
        _backGestureController = null;
      });
    }
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    assert(mounted);
    assert(_backGestureController == null);
    _backGestureController = widget.onStartPopGesture();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    assert(mounted);
    assert(_backGestureController != null);
    _backGestureController!.dragUpdate(
      _convertToLogical(details.primaryDelta! / context.size!.width),
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    assert(mounted);
    assert(_backGestureController != null);
    _backGestureController!.dragEnd(
      _convertToLogical(
        details.velocity.pixelsPerSecond.dx / context.size!.width,
      ),
    );
    _backGestureController = null;
  }

  void _handleDragCancel() {
    assert(mounted);
    _backGestureController?.dragEnd(0);
    _backGestureController = null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.enabledCallback()) {
      _recognizer.addPointer(event);
    }
  }

  double _convertToLogical(double value) {
    return switch (Directionality.of(context)) {
      TextDirection.rtl => -value,
      TextDirection.ltr => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    final double dragAreaWidth = switch (Directionality.of(context)) {
      TextDirection.rtl => MediaQuery.paddingOf(context).right,
      TextDirection.ltr => MediaQuery.paddingOf(context).left,
    };
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child,
        PositionedDirectional(
          start: 0,
          width: math.max(dragAreaWidth, _kBackGestureWidth),
          top: 0,
          bottom: 0,
          child: Listener(
            onPointerDown: _handlePointerDown,
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
}

class _KunBackGestureController<T> {
  _KunBackGestureController({
    required this.navigator,
    required this.controller,
    required this.getIsActive,
    required this.getIsCurrent,
  }) {
    navigator.didStartUserGesture();
  }

  final AnimationController controller;
  final NavigatorState navigator;
  final ValueGetter<bool> getIsActive;
  final ValueGetter<bool> getIsCurrent;

  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  void dragEnd(double velocity) {
    final bool isCurrent = getIsCurrent();
    final bool animateForward;
    if (!isCurrent) {
      animateForward = getIsActive();
    } else if (velocity.abs() >= _kMinFlingVelocity) {
      animateForward = velocity <= 0;
    } else {
      animateForward = controller.value > 0.5;
    }

    final bool reduce =
        MediaQuery.maybeDisableAnimationsOf(navigator.context) ?? false;
    final Duration settle = reduce ? Duration.zero : KunDurations.slow;

    if (animateForward) {
      controller.animateTo(
        1,
        duration: settle,
        curve: KunEasing.emphasized,
      );
    } else {
      if (isCurrent) {
        navigator.pop();
      }
      if (controller.isAnimating) {
        controller.animateBack(
          0,
          duration: settle,
          curve: KunEasing.emphasized,
        );
      }
    }

    if (controller.isAnimating) {
      late final AnimationStatusListener animationStatusCallback;
      animationStatusCallback = (AnimationStatus status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(animationStatusCallback);
      };
      controller.addStatusListener(animationStatusCallback);
    } else {
      navigator.didStopUserGesture();
    }
  }
}

class _KunPredictiveBackDetector extends StatefulWidget {
  const _KunPredictiveBackDetector({
    required this.route,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final Widget child;

  @override
  State<_KunPredictiveBackDetector> createState() =>
      _KunPredictiveBackDetectorState();
}

class _KunPredictiveBackDetectorState extends State<_KunPredictiveBackDetector>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent ||
        !(widget.route.isCurrent && widget.route.popGestureEnabled)) {
      return false;
    }
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    widget.route.handleUpdateBackGestureProgress(
      progress: 1 - backEvent.progress,
    );
  }

  @override
  void handleCommitBackGesture() {
    widget.route.handleCommitBackGesture();
  }

  @override
  void handleCancelBackGesture() {
    widget.route.handleCancelBackGesture();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
