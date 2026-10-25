part of 'modal.dart';

/// A [Page] whose route is a [KunModal] — for Navigator 2 and `go_router`'s
/// `pageBuilder`. Flutter-only: the web modal is never a route.
///
/// It draws the same panel, sizes, backdrop, motion and phone sheet as
/// [KunModal], over the page under it, which stays painted. Because the
/// dialog is the route, a page pushed from inside it lands on top of it,
/// and popping that page brings the dialog back with its state.
///
/// The backdrop, Escape, the close button and the sheet's swipe each call
/// [NavigatorState.maybePop], so [canPop], a `PopScope` in [child] and the
/// router's own pop handling all apply; a swipe that is refused springs
/// back. The system back gesture pops the route like any page. The content
/// reads [KunModalScope.maybeOf] to learn it is in a dialog. Give it a
/// [title] or a [semanticLabel].
class KunModalPage<T> extends Page<T> {
  /// Creates a page whose route shows [child] in a dialog.
  const KunModalPage({
    required this.child,
    this.title,
    this.description,
    this.semanticLabel,
    this.isDismissable,
    this.isSwipeDismissable = true,
    this.isShowCloseButton = true,
    this.withContainer = true,
    this.rounded,
    this.size = KunModalSize.md,
    this.scrollBehavior = KunModalScrollBehavior.inside,
    this.placement = KunModalPlacement.auto,
    this.role = KunModalRole.dialog,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    super.canPop,
    super.onPopInvoked,
  });

  /// The dialog body.
  final Widget child;

  /// See [KunModal.title].
  final String? title;

  /// See [KunModal.description].
  final String? description;

  /// See [KunModal.semanticLabel].
  final String? semanticLabel;

  /// Whether the backdrop and Escape pop the route. Null: the backdrop is
  /// off for [KunModalRole.alertdialog], Escape stays on. The system back
  /// gesture is the route's and is not affected; use [canPop] for it.
  final bool? isDismissable;

  /// See [KunModal.isSwipeDismissable].
  final bool isSwipeDismissable;

  /// See [KunModal.isShowCloseButton].
  final bool isShowCloseButton;

  /// See [KunModal.withContainer].
  final bool withContainer;

  /// See [KunModal.rounded].
  final KunUIRounded? rounded;

  /// See [KunModal.size].
  final KunModalSize size;

  /// See [KunModal.scrollBehavior].
  final KunModalScrollBehavior scrollBehavior;

  /// See [KunModal.placement].
  final KunModalPlacement placement;

  /// See [KunModal.role].
  final KunModalRole role;

  @override
  Route<T> createRoute(BuildContext context) =>
      _KunModalPageRoute<T>(page: this);
}

class _KunModalPageRoute<T> extends PopupRoute<T> implements _KunModalHost {
  _KunModalPageRoute({required KunModalPage<T> page}) : super(settings: page) {
    _KunModalInputTracker.ensureInstalled();
    openedFromKeyboard = _KunModalInputTracker.lastWasKey;
  }

  KunModalPage<T> get _page => settings as KunModalPage<T>;

  final ChangeNotifier _changes = ChangeNotifier();
  bool _popped = false;

  @override
  late final bool openedFromKeyboard;

  @override
  Listenable get changes => _changes;

  @override
  CapturedThemes? get captured => null;

  @override
  bool get interceptsBack => false;

  @override
  KunModal get modal {
    final KunModalPage<T> page = _page;
    return KunModal(
      value: true,
      title: page.title,
      description: page.description,
      semanticLabel: page.semanticLabel,
      isDismissable: page.isDismissable,
      isSwipeDismissable: page.isSwipeDismissable,
      isShowCloseButton: page.isShowCloseButton,
      withContainer: page.withContainer,
      rounded: page.rounded,
      size: page.size,
      scrollBehavior: page.scrollBehavior,
      placement: page.placement,
      role: page.role,
      child: page.child,
    );
  }

  @override
  Future<bool> dismiss() async {
    final NavigatorState? navigator = this.navigator;
    if (_popped || navigator == null || !isCurrent) {
      return _popped;
    }
    await navigator.maybePop<T>();
    return _popped;
  }

  @override
  void onBack() {}

  @override
  bool didPop(T? result) {
    final bool popped = super.didPop(result);
    _popped = _popped || popped;
    return popped;
  }

  @override
  Duration get transitionDuration => _motion(KunDurations.base);

  @override
  Duration get reverseTransitionDuration => _motion(KunDurations.exit);

  Duration _motion(Duration duration) {
    final BuildContext? context = navigator?.context;
    return context == null ? duration : kunMotion(context, duration);
  }

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  TraversalEdgeBehavior get traversalEdgeBehavior =>
      TraversalEdgeBehavior.closedLoop;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _KunModalPage(route: this, host: this);
  }

  @override
  void dispose() {
    _changes.dispose();
    super.dispose();
  }

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';
}
