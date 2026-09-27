part of 'lightbox.dart';

class _KunLightboxSession extends ChangeNotifier {
  _KunLightboxSession({
    required this.images,
    required this.initialIndex,
    required this.captured,
    required this.dismiss,
    required this.onBack,
  });

  List<KunLightboxImage> images;
  int initialIndex;
  CapturedThemes captured;
  final VoidCallback dismiss;
  final VoidCallback onBack;
  VoidCallback? prev;
  VoidCallback? next;

  void notify() => notifyListeners();
}

class _KunLightboxRoute extends PopupRoute<void> {
  _KunLightboxRoute({
    required this.session,
    required this.transitionDuration,
    required this.reverseTransitionDuration,
  });

  final _KunLightboxSession session;

  @override
  final Duration transitionDuration;

  @override
  final Duration reverseTransitionDuration;

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
    return _KunLightboxPage(route: this);
  }
}

class _LightboxPrevIntent extends Intent {
  const _LightboxPrevIntent();
}

class _LightboxNextIntent extends Intent {
  const _LightboxNextIntent();
}

class _KunLightboxPage extends StatefulWidget {
  const _KunLightboxPage({required this.route});

  final _KunLightboxRoute route;

  @override
  State<_KunLightboxPage> createState() => _KunLightboxPageState();
}

class _KunLightboxPageState extends State<_KunLightboxPage> {
  late final CurvedAnimation _fade;
  late final FocusNode _panelFocus;
  bool _focusedInitial = false;

  _KunLightboxSession get session => widget.route.session;

  @override
  void initState() {
    super.initState();
    _fade = CurvedAnimation(
      parent: widget.route.animation!,
      curve: KunEasing.enter,
      reverseCurve: KunEasing.exit,
    );
    _panelFocus = FocusNode(
      debugLabel: 'KunLightbox.panel',
      canRequestFocus: true,
      skipTraversal: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusInitial());
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  void _focusInitial() {
    if (!mounted || _focusedInitial) {
      return;
    }
    _focusedInitial = true;
    if (_panelFocus.context == null) {
      _focusedInitial = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusInitial());
      return;
    }
    if (_panelFocus.hasFocus) {
      return;
    }
    _panelFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (BuildContext context, Widget? _) {
        return session.captured.wrap(Builder(builder: _buildCaptured));
      },
    );
  }

  Widget _buildCaptured(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, void result) {
        if (didPop || !KunDismissLayers.isTop(session)) {
          return;
        }
        session.onBack();
      },
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowLeft): _LightboxPrevIntent(),
          SingleActivator(LogicalKeyboardKey.arrowRight): _LightboxNextIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (DismissIntent intent) {
                session.dismiss();
                return null;
              },
            ),
            _LightboxPrevIntent: CallbackAction<_LightboxPrevIntent>(
              onInvoke: (_LightboxPrevIntent intent) {
                session.prev?.call();
                return null;
              },
            ),
            _LightboxNextIntent: CallbackAction<_LightboxNextIntent>(
              onInvoke: (_LightboxNextIntent intent) {
                session.next?.call();
                return null;
              },
            ),
          },
          child: FadeTransition(
            key: KunLightbox.layerKey,
            opacity: _fade,
            child: BlockSemantics(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ExcludeSemantics(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: _backdropBlurSigma,
                        sigmaY: _backdropBlurSigma,
                      ),
                      child: ColoredBox(
                        key: KunLightbox.backdropKey,
                        color: theme.colors.neutral.shade800.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ),
                  FocusTraversalGroup(
                    policy: WidgetOrderTraversalPolicy(),
                    child: Focus(
                      focusNode: _panelFocus,
                      includeSemantics: false,
                      child: Semantics(
                        container: true,
                        scopesRoute: true,
                        namesRoute: true,
                        explicitChildNodes: true,
                        role: SemanticsRole.dialog,
                        label: KunMessagesScope.of(context).lightbox.label,
                        child: _LightboxViewer(session: session),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
