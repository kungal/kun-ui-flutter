part of 'modal.dart';

/// Web type `KunAlertType`.
enum KunAlertType {
  /// Confirm in the primary color.
  info,

  /// Confirm in the warning color.
  warning,

  /// Confirm in the danger color — a destructive action.
  danger,
}

class _KunAlertController {
  Completer<bool>? completer;
  _KunModalSession? session;
  _KunModalRoute? route;
  NavigatorState? navigator;
}

final _KunAlertController _alert = _KunAlertController();

/// Web `useKunAlert(options)`.
///
/// Resolves `true` when the user confirms and `false` on cancel, Escape,
/// back, the close button, or when another [showKunAlert] call replaces it.
/// Needs no provider widget (the web's `KunAlertProvider`) and opens on the
/// root navigator, above everything already open, with the theme, language
/// and [KunUIConfigScope] in force at [context].
///
/// [confirmText] and [cancelText], when null or empty, come from
/// [KunMessagesScope] (`alert.confirm` / `alert.cancel`). [confirmColor]
/// wins over [type].
Future<bool> showKunAlert(
  BuildContext context, {
  String? title,
  String? message,
  bool showCancel = true,
  String? confirmText,
  String? cancelText,
  KunAlertType type = KunAlertType.info,
  KunUIColor? confirmColor,
}) {
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  _KunModalInputTracker.ensureInstalled();
  final KunModal modal = _alertModal(
    context,
    title: title,
    message: message,
    showCancel: showCancel,
    confirmText: confirmText,
    cancelText: cancelText,
    type: type,
    confirmColor: confirmColor,
  );
  final CapturedThemes captured = InheritedTheme.capture(
    from: context,
    to: navigator.context,
  );

  final bool existing = _alert.session != null &&
      _alert.route != null &&
      _alert.navigator != null &&
      _alert.navigator!.mounted &&
      _alert.route!.isActive;
  if (existing) {
    final Completer<bool>? previous = _alert.completer;
    if (previous != null && !previous.isCompleted) {
      previous.complete(false);
    }
    _alert.completer = Completer<bool>();
    _alert.session!.widget = modal;
    _alert.session!.captured = captured;
    void notify() {
      _alert.session?.notify();
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notify());
    } else {
      notify();
    }
    return _alert.completer!.future;
  }

  final Completer<bool>? stale = _alert.completer;
  if (stale != null && !stale.isCompleted) {
    stale.complete(false);
  }
  _clearAlert();

  final Completer<bool> completer = Completer<bool>();
  _alert.completer = completer;
  final _KunModalSession session = _KunModalSession(
    widget: modal,
    captured: captured,
    openedFromKeyboard: _KunModalInputTracker.lastWasKey,
    dismiss: () => _finishAlert(false),
    onBack: () => _finishAlert(false),
  );
  final _KunModalRoute route = _KunModalRoute(
    session: session,
    transitionDuration: kunMotion(context, KunDurations.base),
    reverseTransitionDuration: kunMotion(context, KunDurations.exit),
  );
  _alert.session = session;
  _alert.route = route;
  _alert.navigator = navigator;
  unawaited(
    navigator.push<void>(route).whenComplete(() {
      session.dispose();
      if (_alert.route == route) {
        final Completer<bool>? pending = _alert.completer;
        if (pending != null && !pending.isCompleted) {
          pending.complete(false);
        }
        _clearAlert();
      }
    }),
  );
  return completer.future;
}

KunModal _alertModal(
  BuildContext context, {
  required String? title,
  required String? message,
  required bool showCancel,
  required String? confirmText,
  required String? cancelText,
  required KunAlertType type,
  required KunUIColor? confirmColor,
}) {
  return KunModal(
    value: true,
    role: KunModalRole.alertdialog,
    title: null,
    description: null,
    semanticLabel:
        _hasText(title) ? title : KunMessagesScope.of(context).alert.title,
    child: _KunAlertBody(
      title: title,
      message: message,
      showCancel: showCancel,
      confirmText: confirmText,
      cancelText: cancelText,
      type: type,
      confirmColor: confirmColor,
    ),
  );
}

void _finishAlert(bool result) {
  final Completer<bool>? completer = _alert.completer;
  final _KunModalRoute? route = _alert.route;
  final NavigatorState? navigator = _alert.navigator;
  _clearAlert();
  if (completer != null && !completer.isCompleted) {
    completer.complete(result);
  }
  void takeDown() {
    if (route == null || navigator == null || !navigator.mounted) {
      return;
    }
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
    WidgetsBinding.instance.addPostFrameCallback((_) => takeDown());
  } else {
    takeDown();
  }
}

void _clearAlert() {
  _alert.completer = null;
  _alert.session = null;
  _alert.route = null;
  _alert.navigator = null;
}

class _KunAlertBody extends StatelessWidget {
  const _KunAlertBody({
    required this.title,
    required this.message,
    required this.showCancel,
    required this.confirmText,
    required this.cancelText,
    required this.type,
    required this.confirmColor,
  });

  final String? title;
  final String? message;
  final bool showCancel;
  final String? confirmText;
  final String? cancelText;
  final KunAlertType type;
  final KunUIColor? confirmColor;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final String confirmLabel = _hasText(confirmText)
        ? confirmText!
        : KunMessagesScope.of(context).alert.confirm;
    final String cancelLabel = _hasText(cancelText)
        ? cancelText!
        : KunMessagesScope.of(context).alert.cancel;
    final KunUIColor color = confirmColor ??
        switch (type) {
          KunAlertType.danger => KunUIColor.danger,
          KunAlertType.warning => KunUIColor.warning,
          KunAlertType.info => KunUIColor.primary,
        };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KunSpacing.unit * 80),
      child: IntrinsicWidth(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: KunSpacing.unit * 80 - KunSpacing.unit * 6 * 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_hasText(title))
                Text(
                  title!,
                  style: KunText.lg.copyWith(
                    fontWeight: KunFontWeights.semibold,
                    color: scheme.foreground,
                  ),
                ),
              if (_hasText(message))
                Padding(
                  padding: EdgeInsets.only(
                    top: _hasText(title) ? KunSpacing.unit * 2 : 0,
                  ),
                  child: Text(
                    message!,
                    style: KunText.sm.copyWith(
                      color: scheme.neutral.shade600,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: KunSpacing.unit * 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: KunSpacing.unit * 2,
                  children: <Widget>[
                    if (showCancel)
                      KunButton(
                        variant: KunUIVariant.light,
                        color: KunUIColor.neutral,
                        onPressed: () => _finishAlert(false),
                        child: Text(cancelLabel),
                      ),
                    KunButton(
                      color: color,
                      onPressed: () => _finishAlert(true),
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
