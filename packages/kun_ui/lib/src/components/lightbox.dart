import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../config/config.dart';
import '../foundation/control_metrics.dart';
import '../foundation/design.dart';
import '../foundation/dismiss_layers.dart';
import '../foundation/motion.dart';
import '../foundation/tap_target.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'button.dart';

part 'lightbox_route.dart';
part 'lightbox_stage.dart';
part 'lightbox_chrome.dart';

const double _minScale = 1;
const double _maxScale = 5;
const double _swipeThreshold = 50;
const double _zoomStep = 0.5;
const double _dragMovePx = 6;
const int _doubleTapMs = 300;
const double _doubleTapPx = 30;
const int _ghostMouseMs = 700;
const double _wheelZoomFactor = 0.2;
const double _swipeVelocityPxPerMs = 0.2;
const Duration _transformDuration = Duration(milliseconds: 300);
const Cubic _transformEase = Cubic(0, 0, 0.58, 1);
const double _backdropBlurSigma = 2;
const double _thumbsMaxFraction = 0.92;
const double _thumbsMaxFractionMd = 0.80;
const double _borderWidth2 = 2;
const double _hairline = 1;
const double _zoomPercentMinWidth = KunSpacing.unit * 14;

/// One picture in a [KunLightbox] (web `KunLightboxImage`).
@immutable
class KunLightboxImage {
  /// Creates an image entry.
  const KunLightboxImage({required this.src, this.alt});

  /// Image URL (web `src`), resolved through [KunUIConfig.imageProvider].
  final String src;

  /// Alternative text (web `alt`).
  final String? alt;

  @override
  bool operator ==(Object other) =>
      other is KunLightboxImage && other.src == src && other.alt == alt;

  @override
  int get hashCode => Object.hash(src, alt);
}

/// Pushes the [KunLightbox] viewer on the root [Navigator] and completes
/// when it closes.
///
/// The chat bubble calls this. Theme, language and [KunUIConfigScope] are
/// taken from [context], the same way [KunLightbox] carries them.
Future<void> showKunLightbox(
  BuildContext context, {
  required List<KunLightboxImage> images,
  int initialIndex = 0,
}) {
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  final Completer<void> completer = Completer<void>();
  late final _KunLightboxRoute route;
  final _KunLightboxSession session = _KunLightboxSession(
    images: List<KunLightboxImage>.of(images),
    initialIndex: initialIndex,
    captured: InheritedTheme.capture(from: context, to: navigator.context),
    dismiss: () => _popLightboxRoute(navigator, route),
    onBack: () => _popLightboxRoute(navigator, route),
  );
  route = _KunLightboxRoute(
    session: session,
    transitionDuration: kunMotion(context, KunDurations.base),
    reverseTransitionDuration: kunMotion(context, KunDurations.exit),
  );
  KunDismissLayers.add(session);
  unawaited(
    navigator.push<void>(route).whenComplete(() {
      KunDismissLayers.remove(session);
      session.dispose();
      if (!completer.isCompleted) {
        completer.complete();
      }
    }),
  );
  return completer.future;
}

void _popLightboxRoute(NavigatorState navigator, Route<void> route) {
  void run() {
    if (!route.isActive) {
      return;
    }
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  if (SchedulerBinding.instance.schedulerPhase ==
      SchedulerPhase.persistentCallbacks) {
    WidgetsBinding.instance.addPostFrameCallback((_) => run());
  } else {
    run();
  }
}

/// A full-screen image viewer implementing the web `KunLightbox` contract.
///
/// It is controlled and draws nothing where it sits — while [isOpen] is true
/// its content is shown in a route on the root [Navigator], which the app
/// shell provides. A user dismissal (backdrop, Escape, back, the close
/// button) calls [onOpenChanged] with `false`. The content sees the theme,
/// language and [KunUIConfigScope] in force where the [KunLightbox] sits.
///
/// The web's download control is omitted: Flutter cannot write a file
/// without a plugin, which this library does not take.
///
/// Both [KunLightbox] and [showKunLightbox] push the same viewer route.
class KunLightbox extends StatefulWidget {
  /// Creates a controlled lightbox. Nothing is drawn at this widget's location.
  const KunLightbox({
    super.key,
    required this.images,
    required this.isOpen,
    this.initialIndex = 0,
    this.onOpenChanged,
  });

  /// Pictures to show (web `images`).
  final List<KunLightboxImage> images;

  /// Whether the viewer is open (web `isOpen`).
  final bool isOpen;

  /// Which picture is current when the viewer opens (web `initialIndex`).
  final int initialIndex;

  /// Called with `false` on a user dismissal (web `update:isOpen`).
  ///
  /// Never called with `true`. A parent-driven close does not call this.
  final ValueChanged<bool>? onOpenChanged;

  /// The full-screen layer, for tests.
  @visibleForTesting
  static const Key layerKey = ValueKey<String>('KunLightbox.layer');

  /// The dimmed backdrop, for tests.
  @visibleForTesting
  static const Key backdropKey = ValueKey<String>('KunLightbox.backdrop');

  /// The gesture stage, for tests.
  @visibleForTesting
  static const Key stageKey = ValueKey<String>('KunLightbox.stage');

  /// The transform around the current picture, for tests.
  @visibleForTesting
  static const Key imageTransformKey = ValueKey<String>(
    'KunLightbox.imageTransform',
  );

  /// The `n / N` counter, for tests.
  @visibleForTesting
  static const Key counterKey = ValueKey<String>('KunLightbox.counter');

  /// The thumbnail strip, for tests.
  @visibleForTesting
  static const Key thumbsKey = ValueKey<String>('KunLightbox.thumbs');

  /// The zoom / rotate toolbar, for tests.
  @visibleForTesting
  static const Key toolbarKey = ValueKey<String>('KunLightbox.toolbar');

  @override
  State<KunLightbox> createState() => _KunLightboxState();
}

enum _KunLightboxRemoval { none, user, silent }

class _KunLightboxState extends State<KunLightbox> {
  NavigatorState? _navigator;
  _KunLightboxRoute? _route;
  _KunLightboxSession? _session;
  _KunLightboxRemoval _removal = _KunLightboxRemoval.none;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    if (widget.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openIfNeeded());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = Navigator.of(context, rootNavigator: true);
    _publish();
  }

  @override
  void didUpdateWidget(KunLightbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openIfNeeded());
    } else if (!widget.isOpen && oldWidget.isOpen) {
      _closeSilent();
    } else {
      _publish();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final _KunLightboxRoute? route = _route;
    final NavigatorState? navigator = _navigator;
    _route = null;
    final _KunLightboxSession? session = _session;
    if (session != null) {
      KunDismissLayers.remove(session);
    }
    session?.dispose();
    _session = null;
    if (route != null && navigator != null && route.isActive) {
      navigator.removeRoute(route);
    }
    super.dispose();
  }

  CapturedThemes _capture() {
    return InheritedTheme.capture(
      from: context,
      to: Navigator.of(context, rootNavigator: true).context,
    );
  }

  void _publish() {
    final _KunLightboxSession? session = _session;
    if (session == null) {
      return;
    }
    session.images = List<KunLightboxImage>.of(widget.images);
    session.initialIndex = widget.initialIndex;
    session.captured = _capture();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _session != session) {
        return;
      }
      session.notify();
    });
  }

  void _openIfNeeded() {
    if (_disposed || !mounted || !widget.isOpen || _route != null) {
      return;
    }
    _open();
  }

  void _open() {
    if (_disposed || !mounted || _route != null) {
      return;
    }
    final NavigatorState navigator =
        _navigator ?? Navigator.of(context, rootNavigator: true);
    _navigator = navigator;
    _removal = _KunLightboxRemoval.none;
    _session = _KunLightboxSession(
      images: List<KunLightboxImage>.of(widget.images),
      initialIndex: widget.initialIndex,
      captured: _capture(),
      dismiss: _dismiss,
      onBack: _onBack,
    );
    final _KunLightboxRoute route = _KunLightboxRoute(
      session: _session!,
      transitionDuration: kunMotion(context, KunDurations.base),
      reverseTransitionDuration: kunMotion(context, KunDurations.exit),
    );
    _route = route;
    KunDismissLayers.add(_session!);
    unawaited(navigator.push<void>(route).whenComplete(_onRouteCompleted));
  }

  void _takeDown({required bool popIfCurrent}) {
    void run() {
      final _KunLightboxRoute? route = _route;
      final NavigatorState? navigator = _navigator;
      if (route == null || navigator == null || !route.isActive) {
        _route = null;
        return;
      }
      if (popIfCurrent && route.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(route);
      }
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          run();
        }
      });
    } else {
      run();
    }
  }

  void _dismiss() {
    if (_route == null || _removal != _KunLightboxRemoval.none) {
      return;
    }
    _removal = _KunLightboxRemoval.user;
    _takeDown(popIfCurrent: true);
    widget.onOpenChanged?.call(false);
  }

  void _closeSilent() {
    if (_route == null || _removal != _KunLightboxRemoval.none) {
      return;
    }
    _removal = _KunLightboxRemoval.silent;
    _takeDown(popIfCurrent: true);
  }

  void _onBack() {
    if (_route == null || _removal != _KunLightboxRemoval.none) {
      return;
    }
    _dismiss();
  }

  void _onRouteCompleted() {
    final bool ours = _route != null;
    _route = null;
    final _KunLightboxSession? session = _session;
    _session = null;
    if (session != null) {
      KunDismissLayers.remove(session);
    }
    session?.dispose();
    if (_disposed || !ours) {
      return;
    }
    if (_removal == _KunLightboxRemoval.none) {
      widget.onOpenChanged?.call(false);
    }
    _removal = _KunLightboxRemoval.none;
  }

  @override
  Widget build(BuildContext context) {
    KunTheme.of(context);
    KunMessagesScope.of(context);
    KunUIConfigScope.of(context);
    return const SizedBox.shrink();
  }
}
