import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/anchored.dart';
import '../foundation/design.dart';
import '../foundation/dismiss_layers.dart';
import '../foundation/motion.dart';
import '../foundation/pointer_menu.dart';
import '../theme/theme.dart';

/// Where a [KunPopover]'s panel sits relative to its trigger.
///
/// The side comes first and the alignment along that side second, exactly as
/// the web's floating-ui placements read: `bottomStart` puts the panel below
/// the trigger with their left edges flush.
enum KunPopoverPosition {
  /// Above, centred.
  top,

  /// Above, left edges flush.
  topStart,

  /// Above, right edges flush.
  topEnd,

  /// Below, centred.
  bottom,

  /// Below, left edges flush.
  bottomStart,

  /// Below, right edges flush.
  bottomEnd,

  /// To the right, centred.
  right,

  /// To the right, top edges flush.
  rightStart,

  /// To the right, bottom edges flush.
  rightEnd,

  /// To the left, centred.
  left,

  /// To the left, top edges flush.
  leftStart,

  /// To the left, bottom edges flush.
  leftEnd;

  /// The side of the trigger this placement is on.
  KunAnchorSide get side => switch (this) {
        KunPopoverPosition.top ||
        KunPopoverPosition.topStart ||
        KunPopoverPosition.topEnd =>
          KunAnchorSide.top,
        KunPopoverPosition.bottom ||
        KunPopoverPosition.bottomStart ||
        KunPopoverPosition.bottomEnd =>
          KunAnchorSide.bottom,
        KunPopoverPosition.right ||
        KunPopoverPosition.rightStart ||
        KunPopoverPosition.rightEnd =>
          KunAnchorSide.right,
        KunPopoverPosition.left ||
        KunPopoverPosition.leftStart ||
        KunPopoverPosition.leftEnd =>
          KunAnchorSide.left,
      };

  /// How the panel lines up along [side].
  KunAnchorAlign get align => switch (this) {
        KunPopoverPosition.topStart ||
        KunPopoverPosition.bottomStart ||
        KunPopoverPosition.rightStart ||
        KunPopoverPosition.leftStart =>
          KunAnchorAlign.start,
        KunPopoverPosition.topEnd ||
        KunPopoverPosition.bottomEnd ||
        KunPopoverPosition.rightEnd ||
        KunPopoverPosition.leftEnd =>
          KunAnchorAlign.end,
        _ => KunAnchorAlign.center,
      };
}

/// What opens a [KunPopover].
enum KunPopoverTrigger {
  /// A tap or click on the trigger toggles the panel, and opening moves focus
  /// into it.
  click,

  /// A mouse hovering the trigger opens the panel without taking focus, for
  /// navigation menus. Touch falls back to [click], because a touch device
  /// has no hover to open with.
  hover,
}

/// Opens and closes a [KunPopover] from outside it, the web's `defineExpose`.
class KunPopoverController {
  _KunPopoverState? _state;

  /// Whether the panel is open.
  bool get isOpen => _state?._isOpen ?? false;

  /// Opens the panel, moving focus into it.
  void open() => _state?._open();

  /// Closes the panel and returns focus to the trigger.
  void close() => _state?._close();

  /// Opens the panel when it is closed, and closes it when it is open.
  void toggle() => _state?._toggle();
}

/// A panel anchored to its trigger: a non-modal dialog that opens in place.
///
/// The panel is an overlay child on the root overlay, not a route. It paints
/// above the page like the web's teleport to `<body>`, while being built
/// under the trigger — so it inherits the trigger's theme, language and
/// config, and its focus nodes stay in the trigger's scope.
///
/// It is a dialog in behaviour, not only in name: opening moves focus into
/// the panel and closing returns it to where it was. Escape, a tap outside
/// and the Android back gesture all close it, and while it is open the back
/// gesture closes it instead of leaving the page.
class KunPopover extends StatefulWidget {
  /// Creates a popover.
  const KunPopover({
    required this.trigger,
    required this.child,
    this.controller,
    this.position = KunPopoverPosition.bottomStart,
    this.autoPosition = true,
    this.rounded,
    this.semanticLabel,
    this.showArrow = false,
    this.fullWidth = false,
    this.openOn = KunPopoverTrigger.click,
    this.openDelay = const Duration(milliseconds: 100),
    this.closeDelay = const Duration(milliseconds: 120),
    this.group,
    super.key,
  });

  /// The widget the panel is anchored to. It keeps its own semantics — a
  /// [KunButton] passed here stays a button, and the popover only reports
  /// whether it is expanded.
  final Widget trigger;

  /// The panel's content. The panel brings a surface, a shadow and rounding
  /// but no padding, as the web's does.
  final Widget child;

  /// Opens and closes the panel from application code.
  final KunPopoverController? controller;

  /// Where the panel sits. It flips and shifts to stay on screen unless
  /// [autoPosition] is false.
  final KunPopoverPosition position;

  /// Whether to avoid collisions with the edge of the view: flip to the
  /// opposite side, shift along the edge, and — when there is no caret — cap
  /// the panel to the room available so tall content scrolls. False honours
  /// [position] verbatim.
  final bool autoPosition;

  /// Corner rounding; defaults to [KunThemeData.rounded].
  final KunUIRounded? rounded;

  /// The panel's accessible name. A dialog needs one, so it falls back to the
  /// web's own untranslated default, `popover`.
  final String? semanticLabel;

  /// Whether to draw a caret pointing at the trigger. A caret and a capped,
  /// scrolling panel are mutually exclusive, as on the web: the caret sits
  /// half outside the panel and a scrolling panel would clip it.
  final bool showArrow;

  /// Whether the trigger fills its parent's width instead of shrinking to its
  /// content.
  final bool fullWidth;

  /// What opens the panel.
  final KunPopoverTrigger openOn;

  /// [KunPopoverTrigger.hover] only: how long the pointer must rest on the
  /// trigger before the panel opens. The web's `openDelay`, 100ms.
  final Duration openDelay;

  /// [KunPopoverTrigger.hover] only: how long the panel stays open after the
  /// pointer leaves, so the pointer can cross the gap. The web's
  /// `closeDelay`, 120ms.
  final Duration closeDelay;

  /// [KunPopoverTrigger.hover] only: popovers sharing this name behave as one
  /// menu bar — only one is open, and moving between siblings skips the open
  /// delay.
  final String? group;

  @override
  State<KunPopover> createState() => _KunPopoverState();
}

class _KunPopoverState extends State<KunPopover>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final GlobalKey _panelKey = GlobalKey(debugLabel: 'KunPopover.panel');
  final Object _tapGroup = Object();
  late final FocusScopeNode _panelScope = FocusScopeNode(
    debugLabel: 'KunPopover.panel',
  );
  late final FocusNode _panelFocus = FocusNode(
    debugLabel: 'KunPopover.panelFallback',
  );
  late final AnimationController _openClose;
  late final CurvedAnimation _curve;
  late final Animation<double> _scale;

  KunPointerMenu? _pointer;
  FocusNode? _restoreTo;
  bool _isOpen = false;
  final ValueNotifier<KunAnchorResolution> _resolved =
      ValueNotifier<KunAnchorResolution>(
    const KunAnchorResolution(side: KunAnchorSide.bottom, arrowCross: 0),
  );

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
    widget.controller?._state = this;
    _syncPointerMenu();
  }

  @override
  void didUpdateWidget(KunPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (identical(oldWidget.controller?._state, this)) {
        oldWidget.controller?._state = null;
      }
      widget.controller?._state = this;
    }
    if (oldWidget.openOn != widget.openOn ||
        oldWidget.openDelay != widget.openDelay ||
        oldWidget.closeDelay != widget.closeDelay ||
        oldWidget.group != widget.group) {
      _syncPointerMenu();
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
    KunDismissLayers.remove(this);
    if (identical(widget.controller?._state, this)) {
      widget.controller?._state = null;
    }
    _pointer?.dispose();
    _openClose.removeListener(_hidePortalIfDismissed);
    if (_portal.isShowing) {
      _portal.hide();
    }
    _openClose.dispose();
    _curve.dispose();
    _panelScope.dispose();
    _panelFocus.dispose();
    _resolved.dispose();
    super.dispose();
  }

  void _syncPointerMenu() {
    _pointer?.dispose();
    _pointer = widget.openOn == KunPopoverTrigger.hover
        ? KunPointerMenu(
            onOpen: () => _open(takeFocus: false),
            onClose: () => _close(returnFocus: false),
            panelRect: _panelRect,
            openDelay: widget.openDelay,
            closeDelay: widget.closeDelay,
            group: widget.group,
          )
        : null;
  }

  Rect? _panelRect() {
    final RenderBox? box =
        _panelKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _hidePortalIfDismissed() {
    if (!_isOpen && _openClose.value == 0 && _portal.isShowing) {
      _portal.hide();
    }
  }

  void _open({bool takeFocus = true}) {
    if (_isOpen || !mounted) {
      return;
    }
    _restoreTo = takeFocus ? FocusManager.instance.primaryFocus : null;
    KunDismissLayers.add(this);
    setState(() => _isOpen = true);
    _portal.show();
    _openClose.forward();
    _pointer?.opened();
    if (takeFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isOpen && mounted) {
          _focusPanel();
        }
      });
    }
  }

  void _close({bool returnFocus = true}) {
    if (!_isOpen || !mounted) {
      return;
    }
    KunDismissLayers.remove(this);
    setState(() => _isOpen = false);
    _openClose.reverse();
    _pointer?.closed();
    final FocusNode? restore = _restoreTo;
    _restoreTo = null;
    if (returnFocus && restore != null && restore.context != null) {
      restore.requestFocus();
    } else if (_panelScope.hasFocus) {
      // Focus is about to sit on a detached node; the web's backstop pulls it
      // back to the trigger rather than leaving it nowhere.
      FocusScope.of(context).requestFocus();
    }
  }

  void _toggle() => _isOpen ? _close() : _open();

  void _focusPanel() {
    _panelScope.requestFocus();
    if (!_panelScope.nextFocus()) {
      _panelFocus.requestFocus();
    }
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _isOpen) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onResolved(KunAnchorResolution resolution) {
    if (_resolved.value == resolution) {
      return;
    }
    // This runs inside layout, where notifying a listener would rebuild
    // mid-layout, so the placement reaches the caret and the scale origin on
    // the next frame. The panel's first frame paints at opacity 0, so the
    // frame drawn from the default placement is never seen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resolved.value = resolution;
      }
    });
  }

  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final KunUIRounded rounded = widget.rounded ?? theme.rounded;
    final Rect anchor = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );

    Widget panel = DecoratedBox(
      key: _panelKey,
      decoration: BoxDecoration(
        color: scheme.content1,
        borderRadius: BorderRadius.circular(rounded.radius),
        boxShadow: KunShadows.md,
      ),
      child: widget.child,
    );
    if (widget.autoPosition && !widget.showArrow) {
      // `size()` on the web sets `overflow-y: auto` alongside the cap.
      panel = ClipRRect(
        borderRadius: BorderRadius.circular(rounded.radius),
        child: SingleChildScrollView(child: panel),
      );
    }
    panel = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        panel,
        if (widget.showArrow)
          ValueListenableBuilder<KunAnchorResolution>(
            valueListenable: _resolved,
            builder: (BuildContext context, KunAnchorResolution resolved, _) =>
                KunAnchorArrow(
              side: resolved.side,
              cross: resolved.arrowCross,
              color: scheme.content1,
            ),
          ),
      ],
    );

    final Widget body = TapRegion(
      key: const ValueKey<String>('KunPopover.panel'),
      groupId: _tapGroup,
      child: FocusScope(
        node: _panelScope,
        child: Focus(
          focusNode: _panelFocus,
          skipTraversal: true,
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            role: SemanticsRole.dialog,
            label: widget.semanticLabel ?? 'popover',
            child: panel,
          ),
        ),
      ),
    );

    final Widget hoverable = _pointer == null
        ? body
        : MouseRegion(
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

    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: KunAnchoredLayout(
          anchor: anchor,
          viewport: kunAnchorViewport(context, info.overlaySize),
          side: widget.position.side,
          align: widget.position.align,
          constrain: widget.autoPosition,
          capSize: widget.autoPosition && !widget.showArrow,
          arrowSize: widget.showArrow ? kKunArrowSize : 0,
          onResolved: _onResolved,
        ),
        child: FadeTransition(
          opacity: _curve,
          child: ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[_scale, _resolved]),
            builder: (BuildContext context, Widget? child) => Transform.scale(
              scale: _scale.value,
              alignment: kunAnchorOrigin(
                _resolved.value.side,
                widget.position.align,
              ),
              child: child,
            ),
            child: hoverable,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget trigger = KunTriggerTap(
      onTap: _toggle,
      child: Semantics(expanded: _isOpen, child: widget.trigger),
    );
    if (_pointer != null) {
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
    }
    if (widget.fullWidth) {
      trigger = SizedBox(width: double.infinity, child: trigger);
    }

    return PopScope(
      canPop: !_isOpen,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && KunDismissLayers.isTop(this)) {
          _close();
        }
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: (FocusNode node, KeyEvent event) => _onKey(event),
        child: TapRegion(
          groupId: _tapGroup,
          onTapOutside: (PointerDownEvent event) {
            if (_isOpen) {
              _close(returnFocus: false);
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
