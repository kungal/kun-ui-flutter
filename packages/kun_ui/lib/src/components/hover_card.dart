part of 'popover.dart';

/// A preview for sighted pointer and keyboard users that leaves the trigger's
/// own semantics alone.
///
/// The card has no role and takes no focus, a click is never intercepted, and
/// touch never opens it. Keyboard focus (`:focus-visible`) on the trigger
/// opens it after [openDelay]; a pointer-driven focus does not.
///
/// [open] null means the card owns its open state (uncontrolled, starting
/// closed). A non-null [open] means the parent owns it and [onOpenChanged]
/// reports every request to change it — the web's `v-model:open` with a
/// default of `false`, bound or not bound.
class KunHoverCard extends StatefulWidget {
  /// Creates a hover card.
  const KunHoverCard({
    required this.trigger,
    required this.builder,
    this.position = KunPopoverPosition.bottomStart,
    this.autoPosition = true,
    this.openDelay = const Duration(milliseconds: 600),
    this.closeDelay = const Duration(milliseconds: 300),
    this.disabled = false,
    this.group,
    this.open,
    this.onOpenChanged,
    this.rounded,
    this.showArrow = false,
    super.key,
  });

  /// The element the card previews, usually a link. It keeps its own
  /// semantics and its own gestures; a click still reaches it.
  final Widget trigger;

  /// The card. Built only while open, so work in its builder runs on open.
  ///
  /// [close] dismisses the card, the web default slot's `{ close }`.
  final Widget Function(BuildContext context, VoidCallback close) builder;

  /// Placement relative to the trigger.
  final KunPopoverPosition position;

  /// Whether to avoid collisions with the edge of the view: flip to the
  /// opposite side, shift along the edge, and — when there is no caret — cap
  /// the panel to the room available so tall content scrolls. False honours
  /// [position] verbatim.
  final bool autoPosition;

  /// How long a mouse must rest on the trigger, or keyboard focus stay on it,
  /// before the card opens. The web's `openDelay`, 600ms.
  final Duration openDelay;

  /// How long the card stays open after the pointer leaves, so the pointer
  /// can cross the gap. The web's `closeDelay`, 300ms.
  final Duration closeDelay;

  /// Render the trigger alone, with no card and no listeners. For a trigger
  /// that has nothing to preview, such as a deleted user.
  final bool disabled;

  /// Shared id for a list of cards: only one is open at a time, and once one
  /// is open, moving to a sibling switches at once instead of waiting out
  /// [openDelay] again.
  final String? group;

  /// Whether the card is open. Null means uncontrolled; non-null means the
  /// parent owns it.
  final bool? open;

  /// Called whenever the card wants to open or close (the web's
  /// `update:open`).
  final ValueChanged<bool>? onOpenChanged;

  /// Corner rounding; defaults to [KunThemeData.rounded].
  final KunUIRounded? rounded;

  /// Whether to draw a caret pointing at the trigger.
  final bool showArrow;

  @override
  State<KunHoverCard> createState() => _KunHoverCardState();
}

class _KunHoverCardState extends State<KunHoverCard>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final GlobalKey _panelKey = GlobalKey(debugLabel: 'KunHoverCard.panel');
  final GlobalKey _triggerKey = GlobalKey(debugLabel: 'KunHoverCard.trigger');
  final Object _tapGroup = Object();
  late final AnimationController _openClose;
  late final CurvedAnimation _curve;
  late final Animation<double> _scale;

  KunPointerMenu? _pointer;
  bool _visible = false;
  bool _keyboardInside = false;
  Widget? _builtCard;
  final ValueNotifier<KunAnchorResolution> _resolved =
      ValueNotifier<KunAnchorResolution>(
    const KunAnchorResolution(side: KunAnchorSide.bottom, arrowCross: 0),
  );

  bool get _isControlled => widget.open != null;

  @override
  void initState() {
    super.initState();
    _openClose = AnimationController(
      vsync: this,
      duration: KunDurations.base,
      reverseDuration: KunDurations.exit,
    );
    _curve = CurvedAnimation(
      parent: _openClose,
      curve: KunEasing.enter,
      reverseCurve: KunEasing.exit,
    );
    // The web grows the panel from `scale-95`.
    _scale = Tween<double>(begin: 0.95, end: 1).animate(_curve);
    _openClose.addListener(_hidePortalIfDismissed);
    FocusManager.instance.addListener(_onFocusChanged);
    _syncPointerMenu();
    if (widget.open == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.open == true) {
          _show();
        }
      });
    }
  }

  @override
  void didUpdateWidget(KunHoverCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openDelay != widget.openDelay ||
        oldWidget.closeDelay != widget.closeDelay ||
        oldWidget.group != widget.group) {
      _syncPointerMenu();
    }
    if (widget.disabled && !oldWidget.disabled) {
      _requestClose();
    }
    if (_isControlled && widget.open != oldWidget.open) {
      if (widget.open == true) {
        _show();
      } else {
        _hideNow();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _openClose.duration = kunMotion(context, KunDurations.base);
    _openClose.reverseDuration = kunMotion(context, KunDurations.exit);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    KunDismissLayers.remove(this);
    _pointer?.dispose();
    _openClose.removeListener(_hidePortalIfDismissed);
    if (_portal.isShowing) {
      _portal.hide();
    }
    _openClose.dispose();
    _curve.dispose();
    _resolved.dispose();
    super.dispose();
  }

  void _syncPointerMenu() {
    _pointer?.dispose();
    _pointer = KunPointerMenu(
      onOpen: _requestOpen,
      onClose: _requestClose,
      panelRect: _panelRect,
      openDelay: widget.openDelay,
      closeDelay: widget.closeDelay,
      group: widget.group,
    );
  }

  Rect? _panelRect() {
    final RenderBox? box =
        _panelKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  bool _focusInside(GlobalKey key, FocusNode? node) {
    final BuildContext? ancestor = key.currentContext;
    final BuildContext? target = node?.context;
    if (ancestor == null || target == null) {
      return false;
    }
    if (identical(ancestor, target)) {
      return true;
    }
    bool found = false;
    target.visitAncestorElements((Element element) {
      if (identical(element, ancestor)) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  void _onFocusChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.disabled) {
        return;
      }
      final FocusNode? primary = FocusManager.instance.primaryFocus;
      final bool inTrigger = _focusInside(_triggerKey, primary);
      final bool inPanel = _focusInside(_panelKey, primary);
      final bool traditional =
          FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
      if (inTrigger && traditional) {
        _keyboardInside = true;
        _pointer?.enterTrigger();
      } else if (inPanel) {
        _keyboardInside = true;
      } else if (_keyboardInside && !inTrigger && !inPanel) {
        _keyboardInside = false;
        _requestClose();
      }
    });
  }

  void _hidePortalIfDismissed() {
    if (!_visible && _openClose.value == 0 && _portal.isShowing) {
      _builtCard = null;
      _portal.hide();
    }
  }

  void _requestOpen() {
    if (widget.disabled || _visible) {
      return;
    }
    widget.onOpenChanged?.call(true);
    if (!_isControlled) {
      _show();
    }
  }

  void _requestClose() {
    if (widget.disabled) {
      _hideNow();
      return;
    }
    if (!_visible) {
      _pointer?.leaveTrigger(Offset.zero);
      return;
    }
    widget.onOpenChanged?.call(false);
    if (!_isControlled) {
      _hideNow();
    }
  }

  void _show() {
    if (_visible || !mounted || widget.disabled) {
      return;
    }
    KunDismissLayers.add(this);
    setState(() => _visible = true);
    void reveal() {
      if (!mounted || !_visible) {
        return;
      }
      if (!_portal.isShowing) {
        _portal.show();
      }
      _openClose.forward();
      _pointer?.opened();
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => reveal());
    } else {
      reveal();
    }
  }

  void _hideNow() {
    if (!_visible || !mounted) {
      return;
    }
    KunDismissLayers.remove(this);
    setState(() => _visible = false);
    _openClose.reverse();
    _pointer?.closed();
  }

  void _onResolved(KunAnchorResolution resolution) =>
      _kunScheduleResolved(_resolved, resolution, () => mounted);

  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final KunUIRounded rounded = widget.rounded ?? theme.rounded;
    if (_visible) {
      _builtCard = widget.builder(context, _requestClose);
    }

    final Widget panel = _kunFloatingPanel(
      panelKey: _panelKey,
      child: _builtCard ?? const SizedBox.shrink(),
      scheme: scheme,
      rounded: rounded,
      autoPosition: widget.autoPosition,
      showArrow: widget.showArrow,
      resolved: _resolved,
    );

    final Widget body = TapRegion(
      key: const ValueKey<String>('KunHoverCard.panel'),
      groupId: _tapGroup,
      child: Focus(
        canRequestFocus: true,
        skipTraversal: true,
        includeSemantics: false,
        child: panel,
      ),
    );

    final Widget hoverable = MouseRegion(
      onEnter: (PointerEnterEvent event) {
        if (KunPointerMenu.handles(event)) {
          _pointer!.enterPanel();
        }
      },
      onExit: (PointerExitEvent event) {
        if (KunPointerMenu.handles(event)) {
          _pointer!.leavePanel(event.position);
        }
      },
      child: body,
    );

    return _kunPlaceFloating(
      info: info,
      context: context,
      position: widget.position,
      autoPosition: widget.autoPosition,
      showArrow: widget.showArrow,
      fade: _curve,
      scale: _scale,
      resolved: _resolved,
      onResolved: _onResolved,
      child: hoverable,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.disabled) {
      return widget.trigger;
    }

    Widget trigger = KeyedSubtree(
      key: _triggerKey,
      child: KunTriggerTap(onTap: _requestClose, child: widget.trigger),
    );
    trigger = MouseRegion(
      onEnter: (PointerEnterEvent event) {
        if (KunPointerMenu.handles(event)) {
          _pointer!.enterTrigger();
        }
      },
      onExit: (PointerExitEvent event) {
        if (KunPointerMenu.handles(event)) {
          _pointer!.leaveTrigger(event.position);
        }
      },
      child: trigger,
    );

    return PopScope(
      canPop: !_visible,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && KunDismissLayers.isTop(this)) {
          _requestClose();
        }
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape &&
              _visible) {
            _requestClose();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TapRegion(
          groupId: _tapGroup,
          onTapOutside: (PointerDownEvent event) {
            if (_visible) {
              _requestClose();
            }
          },
          child: OverlayPortal.overlayChildLayoutBuilder(
            controller: _portal,
            overlayLocation: OverlayChildLocation.rootOverlay,
            overlayChildBuilder: _buildOverlay,
            child: trigger,
          ),
        ),
      ),
    );
  }
}
