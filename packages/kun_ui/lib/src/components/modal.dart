import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../config/config.dart';
import '../foundation/design.dart';
import '../foundation/motion.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'button.dart';

part 'modal_route.dart';
part 'modal_swipe.dart';
part 'modal_alert.dart';

/// How wide the [KunModal] panel may grow.
enum KunModalSize {
  /// Caps at [KunContainerWidths.sm].
  sm,

  /// Caps at [KunContainerWidths.md] — the default.
  md,

  /// Caps at [KunContainerWidths.lg].
  lg,

  /// Caps at [KunContainerWidths.xl2].
  xl,

  /// The layer width minus `unit * 6`, with no maximum.
  full,
}

/// Vertical placement of the [KunModal] panel.
enum KunModalPlacement {
  /// A bottom sheet below [KunBreakpoints.md], a centred dialog at `md` and up.
  auto,

  /// Centred at every width.
  center,

  /// Pinned to the top of the layer.
  top,
}

/// ARIA role of the [KunModal] panel.
enum KunModalRole {
  /// An ordinary dialog. The backdrop dismisses unless [KunModal.isDismissable]
  /// says otherwise.
  dialog,

  /// A prompt that needs an answer. The backdrop does not dismiss unless
  /// [KunModal.isDismissable] is `true`; Escape still does.
  alertdialog,
}

/// Which box scrolls when a [KunModal] outgrows the layer.
enum KunModalScrollBehavior {
  /// The panel body scrolls, capped at 90% of the viewport (85% for a sheet).
  inside,

  /// The whole layer scrolls. The panel has no maximum height.
  outside,
}

bool _hasText(String? value) => value != null && value.isNotEmpty;

bool _isBackdropDismissable(KunModal modal) =>
    modal.isDismissable ?? modal.role != KunModalRole.alertdialog;

bool _isEscapeDismissable(KunModal modal) => modal.isDismissable ?? true;

bool _isTouchFirstPlatform() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return true;
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return false;
  }
}

bool _isSheet(KunModal modal, BuildContext context) {
  if (modal.placement != KunModalPlacement.auto) {
    return false;
  }
  return MediaQuery.sizeOf(context).width < KunTheme.of(context).breakpoints.md;
}

/// A dialog implementing the web `KunModal` contract.
///
/// It is controlled and draws nothing where it sits — while [value] is true
/// its content is shown in a route on the root [Navigator], which the app
/// shell provides. A user dismissal (backdrop, Escape, back, swipe, close
/// button) calls [onChanged] with `false` then [onClose]. The content sees
/// the theme, language and [KunUIConfigScope] in force where the [KunModal]
/// sits. Give it a [title] or a [semanticLabel].
class KunModal extends StatefulWidget {
  /// Creates a controlled modal. Nothing is drawn at this widget's location.
  const KunModal({
    super.key,
    required this.value,
    this.onChanged,
    this.onClose,
    this.child,
    this.title,
    this.description,
    this.semanticLabel,
    this.isDismissable,
    this.isCloseRequestDismissable = true,
    this.isSwipeDismissable = true,
    this.isShowCloseButton = true,
    this.withContainer = true,
    this.rounded,
    this.size = KunModalSize.md,
    this.scrollBehavior = KunModalScrollBehavior.inside,
    this.placement = KunModalPlacement.auto,
    this.role = KunModalRole.dialog,
  });

  /// Whether the dialog is open (web `modelValue`).
  final bool value;

  /// Called with `false` on a user dismissal (web `update:modelValue`).
  ///
  /// Never called with `true`. A parent-driven close does not call this.
  final ValueChanged<bool>? onChanged;

  /// Called after [onChanged] on a user dismissal only (web `close`).
  final VoidCallback? onClose;

  /// The dialog body (web slot `default`).
  final Widget? child;

  /// The heading. Null or empty: no heading is drawn.
  final String? title;

  /// Supporting line under [title]. Null or empty: not drawn.
  final String? description;

  /// Accessible name (web `ariaLabel`). Ignored when [title] is non-empty.
  final String? semanticLabel;

  /// Backdrop and Escape. Null: the backdrop is off for
  /// [KunModalRole.alertdialog], Escape stays on.
  final bool? isDismissable;

  /// Whether the system back gesture or button dismisses the dialog.
  final bool isCloseRequestDismissable;

  /// Whether a downward drag dismisses the phone sheet, and whether the
  /// handle that advertises it is drawn.
  final bool isSwipeDismissable;

  /// Whether the × in the panel corner is shown.
  final bool isShowCloseButton;

  /// When false, [child] sits in the overlay with no panel, header, close
  /// button, handle, swipe or dialog semantics.
  final bool withContainer;

  /// Corner radius. Null follows [KunThemeData.rounded].
  final KunUIRounded? rounded;

  /// Maximum width of the panel.
  ///
  /// Between `KunSpacing.unit * 80` and this cap, the panel is as wide as
  /// [child] lays out. A child that fills the width it is given, such as a
  /// `Row` with the default `mainAxisSize`, widens the panel to the cap;
  /// wrap it in an `IntrinsicWidth` to size the panel by its content, as the
  /// web's panel is sized.
  final KunModalSize size;

  /// Which box scrolls when the content is taller than the layer.
  final KunModalScrollBehavior scrollBehavior;

  /// Vertical alignment of the panel.
  final KunModalPlacement placement;

  /// Role announced for the panel.
  final KunModalRole role;

  @override
  State<KunModal> createState() => _KunModalState();
}

enum _KunModalRemoval { none, user, silent }

class _KunModalSession extends ChangeNotifier {
  _KunModalSession({
    required this.widget,
    required this.captured,
    required this.openedFromKeyboard,
    required this.dismiss,
    required this.onBack,
  });

  KunModal widget;
  CapturedThemes captured;
  final bool openedFromKeyboard;
  final VoidCallback dismiss;
  final VoidCallback onBack;

  void notify() => notifyListeners();
}

class _KunModalInputTracker {
  _KunModalInputTracker._();

  static bool lastWasKey = false;
  static bool _pointerRouteAdded = false;

  static bool _onKey(KeyEvent event) {
    lastWasKey = true;
    return false;
  }

  static void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) {
      lastWasKey = false;
    }
  }

  static void ensureInstalled() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    HardwareKeyboard.instance.addHandler(_onKey);
    if (!_pointerRouteAdded) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
      _pointerRouteAdded = true;
    }
  }
}

class _KunModalState extends State<KunModal> {
  NavigatorState? _navigator;
  _KunModalRoute? _route;
  _KunModalSession? _session;
  _KunModalRemoval _removal = _KunModalRemoval.none;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _KunModalInputTracker.ensureInstalled();
    if (widget.value) {
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
  void didUpdateWidget(KunModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value && !oldWidget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openIfNeeded());
    } else if (!widget.value && oldWidget.value) {
      _closeSilent();
    } else {
      _publish();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final _KunModalRoute? route = _route;
    final NavigatorState? navigator = _navigator;
    _route = null;
    _session?.dispose();
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
    final _KunModalSession? session = _session;
    if (session == null) {
      return;
    }
    session.widget = widget;
    session.captured = _capture();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _session != session) {
        return;
      }
      session.notify();
    });
  }

  void _openIfNeeded() {
    if (_disposed || !mounted || !widget.value || _route != null) {
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
    _removal = _KunModalRemoval.none;
    _session = _KunModalSession(
      widget: widget,
      captured: _capture(),
      openedFromKeyboard: _KunModalInputTracker.lastWasKey,
      dismiss: _dismiss,
      onBack: _onBack,
    );
    final _KunModalRoute route = _KunModalRoute(
      session: _session!,
      transitionDuration: kunMotion(context, KunDurations.base),
      reverseTransitionDuration: kunMotion(context, KunDurations.exit),
    );
    _route = route;
    if (kDebugMode &&
        !_hasText(widget.title) &&
        !_hasText(widget.semanticLabel)) {
      debugPrint(
        '[KunModal] this dialog has no accessible name, so a screen reader '
        'announces it as just "dialog". Pass `title` or `semanticLabel`.',
      );
    }
    unawaited(navigator.push<void>(route).whenComplete(_onRouteCompleted));
  }

  void _takeDown({required bool popIfCurrent}) {
    void run() {
      final _KunModalRoute? route = _route;
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
    if (_route == null || _removal != _KunModalRemoval.none) {
      return;
    }
    _removal = _KunModalRemoval.user;
    _takeDown(popIfCurrent: true);
    widget.onChanged?.call(false);
    widget.onClose?.call();
  }

  void _closeSilent() {
    if (_route == null || _removal != _KunModalRemoval.none) {
      return;
    }
    _removal = _KunModalRemoval.silent;
    _takeDown(popIfCurrent: true);
  }

  void _onBack() {
    if (_route == null || _removal != _KunModalRemoval.none) {
      return;
    }
    if (_isEscapeDismissable(widget) && widget.isCloseRequestDismissable) {
      _dismiss();
      return;
    }
    final NavigatorState? navigator = _navigator;
    _removal = _KunModalRemoval.silent;
    _takeDown(popIfCurrent: false);
    _route = null;
    widget.onChanged?.call(false);
    navigator?.maybePop();
  }

  void _onRouteCompleted() {
    final bool ours = _route != null;
    _route = null;
    final _KunModalSession? session = _session;
    _session = null;
    session?.dispose();
    if (_disposed || !ours) {
      return;
    }
    if (_removal == _KunModalRemoval.none) {
      widget.onChanged?.call(false);
    }
    _removal = _KunModalRemoval.none;
  }

  @override
  Widget build(BuildContext context) {
    KunTheme.of(context);
    KunMessagesScope.of(context);
    KunUIConfigScope.of(context);
    return const SizedBox.shrink();
  }
}
