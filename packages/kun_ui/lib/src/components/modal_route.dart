part of 'modal.dart';

const ValueKey<String> _layerKey = ValueKey<String>('KunModal.layer');
const ValueKey<String> _backdropKey = ValueKey<String>('KunModal.backdrop');
const ValueKey<String> _panelKey = ValueKey<String>('KunModal.panel');
const ValueKey<String> _panelTransformKey =
    ValueKey<String>('KunModal.panelTransform');
const ValueKey<String> _handleKey = ValueKey<String>('KunModal.handle');
const ValueKey<String> _insideScrollKey =
    ValueKey<String>('KunModal.insideScroll');
const ValueKey<String> _outsideScrollKey =
    ValueKey<String>('KunModal.outsideScroll');

class _KunModalRoute extends PopupRoute<void> {
  _KunModalRoute({
    required this.session,
    required this.transitionDuration,
    required this.reverseTransitionDuration,
  });

  final _KunModalSession session;

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
    return _KunModalPage(route: this);
  }
}

class _KunModalPage extends StatefulWidget {
  const _KunModalPage({required this.route});

  final _KunModalRoute route;

  @override
  State<_KunModalPage> createState() => _KunModalPageState();
}

class _KunModalPageState extends State<_KunModalPage>
    with TickerProviderStateMixin {
  late final CurvedAnimation _fade;
  late final AnimationController _swipe;
  late final FocusNode _panelFocus;
  late final _KunSwipeRecognizer _swipeRecognizer;
  final GlobalKey _panelSizeKey = GlobalKey();
  final ScrollController _outsideScroll = ScrollController();
  bool _sheet = false;
  bool _exitFromSwipe = false;
  bool _focusedInitial = false;
  int? _backdropPointer;
  Offset? _backdropDown;
  double _claimedHeight = 0;

  _KunModalSession get session => widget.route.session;

  @override
  void initState() {
    super.initState();
    _fade = CurvedAnimation(
      parent: widget.route.animation!,
      curve: KunEasing.enter,
      reverseCurve: KunEasing.exit,
    );
    _swipe = AnimationController(
      vsync: this,
      value: 0,
      lowerBound: -KunSwipeDismissPhysics.rubberBandLimit,
      upperBound: 10000,
    );
    _panelFocus = FocusNode(
      debugLabel: 'KunModal.panel',
      canRequestFocus: true,
      skipTraversal: true,
    );
    _swipeRecognizer = _KunSwipeRecognizer(debugOwner: this)
      ..canStart = _canStartSwipe
      ..canClaim = _canClaimSwipe
      ..onClaim = _onSwipeClaimed
      ..onUpdate = _onSwipeUpdate
      ..onEnd = _onSwipeEnd
      ..onCancel = () => _settleSwipe(close: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusInitial());
    });
  }

  @override
  void dispose() {
    _swipeRecognizer.dispose();
    _fade.dispose();
    _swipe.dispose();
    _panelFocus.dispose();
    _outsideScroll.dispose();
    super.dispose();
  }

  void _focusInitial() {
    if (!mounted || _focusedInitial) {
      return;
    }
    _focusedInitial = true;
    final BuildContext? panelContext = _panelFocus.context;
    if (panelContext == null) {
      _focusedInitial = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusInitial());
      return;
    }
    if (session.openedFromKeyboard) {
      final FocusTraversalPolicy policy =
          FocusTraversalGroup.maybeOf(panelContext) ??
              WidgetOrderTraversalPolicy();
      final FocusNode? first = policy.findFirstFocus(_panelFocus);
      if (first != null && first.canRequestFocus && !first.skipTraversal) {
        first.requestFocus();
        return;
      }
    }
    _panelFocus.requestFocus();
  }

  bool _canStartSwipe(Offset global) {
    final KunModal modal = session.widget;
    return mounted &&
        modal.withContainer &&
        modal.isSwipeDismissable &&
        _isBackdropDismissable(modal) &&
        _isTouchFirstPlatform() &&
        _sheet &&
        widget.route.animation!.isCompleted &&
        _isOnPanel(global);
  }

  bool _canClaimSwipe(Offset global, int viewId) {
    if (_hitPathStartsOnEditable(_hitTestAt(global, viewId))) {
      return false;
    }
    final List<ScrollPosition> scrolls = <ScrollPosition>[
      if (_outsideScroll.hasClients) _outsideScroll.position,
      ..._verticalScrollsAt(_panelSizeKey.currentContext, global),
    ];
    return !scrolls.any(_scrollBlocksSwipe);
  }

  void _onSwipeClaimed() {
    _swipe.stop();
    final RenderObject? renderObject =
        _panelSizeKey.currentContext?.findRenderObject();
    final double height = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.size.height
        : 0;
    _claimedHeight = math.min(height, MediaQuery.sizeOf(context).height);
  }

  void _onSwipeUpdate(double dy) {
    final double offset = dy > 0
        ? dy
        : -KunSwipeDismissPhysics.rubberBandLimit *
            (1 - math.exp(dy / KunSwipeDismissPhysics.rubberBandLimit));
    _swipe.value = offset.clamp(_swipe.lowerBound, _swipe.upperBound);
  }

  void _onSwipeEnd(double velocity) {
    final double offset = _swipe.value;
    _settleSwipe(
      close: offset > 0 &&
          (velocity > KunSwipeDismissPhysics.closeVelocity ||
              offset >=
                  math.max(_claimedHeight, 1) *
                      KunSwipeDismissPhysics.closeDistanceRatio),
    );
  }

  void _settleSwipe({required bool close}) {
    if (!mounted) {
      return;
    }
    final double target = close ? _claimedHeight : 0;
    if (close) {
      _exitFromSwipe = true;
    }
    if (kunReducedMotion(context)) {
      _swipe.value = target;
    } else {
      unawaited(
        _swipe.animateTo(
          target,
          duration: close ? KunDurations.exit : KunDurations.base,
          curve: close ? KunEasing.exit : KunEasing.emphasized,
        ),
      );
    }
    if (close) {
      session.dismiss();
    }
  }

  bool _isOnPanel(Offset global) {
    final BuildContext? panelContext = _panelSizeKey.currentContext;
    final RenderObject? renderObject = panelContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return false;
    }
    final Offset local = renderObject.globalToLocal(global);
    return (Offset.zero & renderObject.size).contains(local);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!mounted) {
      return;
    }
    _swipeRecognizer.addPointer(event);
    if (_backdropPointer != null) {
      return;
    }
    _backdropPointer = event.pointer;
    _backdropDown =
        event.buttons & kPrimaryButton == 0 || _isOnPanel(event.position)
            ? null
            : event.position;
  }

  void _onPointerMove(PointerMoveEvent event) {
    _swipeRecognizer.decide(event);
    final Offset? down = _backdropDown;
    if (event.pointer == _backdropPointer &&
        down != null &&
        (event.position - down).distance > kTouchSlop) {
      _backdropDown = null;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _backdropPointer) {
      return;
    }
    _backdropPointer = null;
    final bool startedOnBackdrop = _backdropDown != null;
    _backdropDown = null;
    if (!mounted || !startedOnBackdrop || _isOnPanel(event.position)) {
      return;
    }
    if (_isBackdropDismissable(session.widget)) {
      session.dismiss();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _backdropPointer) {
      _backdropPointer = null;
      _backdropDown = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (BuildContext context, Widget? _) {
        return session.captured.wrap(
          Builder(builder: _buildCaptured),
        );
      },
    );
  }

  Widget _buildCaptured(BuildContext context) {
    final KunModal modal = session.widget;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, void result) {
        if (didPop) {
          return;
        }
        session.onBack();
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (DismissIntent intent) {
              if (_isEscapeDismissable(modal)) {
                session.dismiss();
              }
              return null;
            },
          ),
        },
        child: FadeTransition(
          key: _layerKey,
          opacity: _fade,
          child: BlockSemantics(
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _buildBackdrop(context),
                  _buildLayer(context, modal),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackdrop(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    final Color color = theme.brightness == Brightness.dark
        ? theme.colors.background.withValues(
            alpha: KunColors.globalOpacity * 0.7,
          )
        : theme.colors.neutral.shade800.withValues(alpha: 0.7);
    return ExcludeSemantics(
      child: ColoredBox(
        key: _backdropKey,
        color: color,
      ),
    );
  }

  Widget _buildLayer(BuildContext context, KunModal modal) {
    final MediaQueryData media = MediaQuery.of(context);
    final bool sheet = _isSheet(modal, context);
    _sheet = sheet;
    final EdgeInsets safe = EdgeInsets.only(
      top: media.viewPadding.top,
      left: media.viewPadding.left,
      right: media.viewPadding.right,
      bottom: media.viewInsets.bottom,
    );
    final EdgeInsets placement = sheet
        ? EdgeInsets.only(
            top: KunSpacing.unit * 1,
            left: KunSpacing.unit * 1,
            right: KunSpacing.unit * 1,
            bottom: math.max(KunSpacing.unit * 1, media.viewPadding.bottom),
          )
        : const EdgeInsets.all(KunSpacing.unit * 3);
    final Alignment alignment;
    if (sheet) {
      alignment = Alignment.bottomCenter;
    } else if (modal.placement == KunModalPlacement.top) {
      alignment = Alignment.topCenter;
    } else {
      alignment = Alignment.center;
    }
    final bool outside = modal.scrollBehavior == KunModalScrollBehavior.outside;
    final Widget body = _buildTransformedPanel(context, modal, sheet);
    final Widget placed = Padding(
      padding: placement,
      child: Align(
        alignment: alignment,
        child: outside && !sheet
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: KunSpacing.unit * 8,
                ),
                child: body,
              )
            : body,
      ),
    );
    Widget layer = placed;
    if (outside) {
      layer = LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
              overscroll: false,
            ),
            child: SingleChildScrollView(
              key: _outsideScrollKey,
              controller: _outsideScroll,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: placed,
              ),
            ),
          );
        },
      );
    }
    return Padding(padding: safe, child: layer);
  }

  Widget _buildTransformedPanel(
    BuildContext context,
    KunModal modal,
    bool sheet,
  ) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_fade, _swipe]),
      builder: (BuildContext context, Widget? child) {
        final double t = _fade.value;
        final double swipe = _swipe.value;
        final double ty;
        final double scale;
        if (_exitFromSwipe) {
          ty = swipe;
          scale = 1;
        } else if (sheet) {
          ty = (1 - t) * KunSpacing.unit * 20 + swipe;
          scale = 1;
        } else {
          ty = (1 - t) * KunSpacing.unit * 2 + swipe;
          scale = 0.96 + 0.04 * t;
        }
        return Transform.translate(
          key: _panelTransformKey,
          offset: Offset(0, ty),
          child: Transform.scale(
            key: const ValueKey<String>('KunModal.panelScale'),
            scale: scale,
            child: child,
          ),
        );
      },
      child: _buildSizedPanel(context, modal, sheet),
    );
  }

  Widget _buildSizedPanel(
    BuildContext context,
    KunModal modal,
    bool sheet,
  ) {
    final MediaQueryData media = MediaQuery.of(context);
    final double routeWidth = media.size.width;
    final double contentBoxWidth = routeWidth -
        media.viewPadding.left -
        media.viewPadding.right -
        (sheet ? KunSpacing.unit * 2 : KunSpacing.unit * 6);
    final double layerContentHeight =
        media.size.height - media.viewPadding.top - media.viewInsets.bottom;
    final double maxWidth;
    final double minWidth;
    if (sheet) {
      maxWidth = contentBoxWidth;
      minWidth = contentBoxWidth;
    } else if (modal.size == KunModalSize.full) {
      maxWidth = routeWidth - KunSpacing.unit * 6;
      minWidth = maxWidth;
    } else {
      maxWidth = switch (modal.size) {
        KunModalSize.sm => KunContainerWidths.sm,
        KunModalSize.md => KunContainerWidths.md,
        KunModalSize.lg => KunContainerWidths.lg,
        KunModalSize.xl => KunContainerWidths.xl2,
        KunModalSize.full => routeWidth - KunSpacing.unit * 6,
      };
      minWidth = KunSpacing.unit * 80;
    }
    final bool inside = modal.scrollBehavior == KunModalScrollBehavior.inside;
    final double? maxHeight;
    if (inside) {
      final double cap = media.size.height * (sheet ? 0.85 : 0.90);
      maxHeight = math.min(layerContentHeight, cap);
    } else {
      maxHeight = null;
    }
    Widget panel = _buildPanelContents(
      context,
      modal,
      sheet,
      minWidth: minWidth,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    return KeyedSubtree(
      key: _panelSizeKey,
      child: panel,
    );
  }

  Widget _buildPanelContents(
    BuildContext context,
    KunModal modal,
    bool sheet, {
    required double minWidth,
    required double maxWidth,
    required double? maxHeight,
  }) {
    if (!modal.withContainer) {
      return Focus(
        focusNode: _panelFocus,
        includeSemantics: false,
        child: _PanelSizer(
          minWidth: minWidth,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          child: modal.child ?? const SizedBox.shrink(),
        ),
      );
    }
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final double radius = (modal.rounded ?? theme.rounded).radius;
    final bool showHandle = sheet &&
        _isTouchFirstPlatform() &&
        modal.isSwipeDismissable &&
        _isBackdropDismissable(modal);
    final bool showHeader =
        _hasText(modal.title) || _hasText(modal.description);
    final List<Widget> column = <Widget>[];
    if (showHeader) {
      column.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: modal.child != null ? KunSpacing.unit * 4 : 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_hasText(modal.title))
                Padding(
                  padding: const EdgeInsets.only(right: KunSpacing.unit * 8),
                  child: Text(
                    modal.title!,
                    style: KunText.lg.copyWith(
                      fontWeight: KunFontWeights.semibold,
                      color: scheme.foreground,
                    ),
                  ),
                ),
              if (_hasText(modal.description))
                Padding(
                  padding: EdgeInsets.only(
                    top: _hasText(modal.title) ? KunSpacing.unit * 2 : 0,
                  ),
                  child: Text(
                    modal.description!,
                    style: KunText.sm.copyWith(
                      color: scheme.neutral.shade600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    if (modal.child != null) {
      column.add(modal.child!);
    }
    final Widget stack = Stack(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(KunSpacing.unit * 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: column,
          ),
        ),
        if (showHandle)
          Positioned(
            top: KunSpacing.unit * 2,
            left: 0,
            right: 0,
            child: ExcludeSemantics(
              child: Center(
                child: DecoratedBox(
                  key: _handleKey,
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? scheme.neutral.shade600
                        : scheme.neutral.shade300,
                    borderRadius: BorderRadius.circular(KunRadius.full),
                  ),
                  child: const SizedBox(
                    width: KunSpacing.unit * 9,
                    height: KunSpacing.unit * 1,
                  ),
                ),
              ),
            ),
          ),
        if (modal.isShowCloseButton)
          Positioned(
            top: KunSpacing.unit * 1,
            right: KunSpacing.unit * 1,
            child: KunButton(
              variant: KunUIVariant.light,
              color: KunUIColor.neutral,
              rounded: KunUIRounded.full,
              isIconOnly: true,
              semanticLabel: KunMessagesScope.of(context).modal.close,
              onPressed: session.dismiss,
              child: const Icon(KunIcons.x),
            ),
          ),
      ],
    );
    final Widget sized = _PanelSizer(
      minWidth: minWidth,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      child: stack,
    );
    final String? label =
        _hasText(modal.title) ? modal.title : modal.semanticLabel;
    Widget panel = FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Focus(
        focusNode: _panelFocus,
        includeSemantics: false,
        child: Semantics(
          container: true,
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          role: modal.role == KunModalRole.alertdialog
              ? SemanticsRole.alertDialog
              : SemanticsRole.dialog,
          label: _hasText(label) ? label : null,
          hint: _hasText(modal.description) ? modal.description : null,
          child: DecoratedBox(
            key: _panelKey,
            decoration: BoxDecoration(
              color: scheme.content1,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: KunShadows.lg,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: sized,
            ),
          ),
        ),
      ),
    );
    return panel;
  }
}

class _PanelSizer extends StatelessWidget {
  const _PanelSizer({
    required this.minWidth,
    required this.maxWidth,
    this.maxHeight,
    required this.child,
  });

  final double minWidth;
  final double maxWidth;
  final double? maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget body = child;
    if (maxHeight != null) {
      body = ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          overscroll: false,
        ),
        child: SingleChildScrollView(
          key: _insideScrollKey,
          primary: false,
          child: body,
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth,
        maxWidth: maxWidth,
        maxHeight: maxHeight ?? double.infinity,
      ),
      child: body,
    );
  }
}
