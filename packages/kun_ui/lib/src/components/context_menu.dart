import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../config/config.dart';
import '../foundation/anchored.dart';
import '../foundation/dismiss_layers.dart';
import '../foundation/motion.dart';
import '../theme/theme.dart';
import 'menu_panel.dart';

/// A menu positioned at an x/y point and clamped into the viewport.
///
/// Controlled through [visible] and [position], the same surface as the web
/// `KunContextMenu`. Implements the WAI-ARIA menu pattern — role menu /
/// menuitem, roving tabindex, arrow keys, Home, End, Enter, Space and
/// Escape — focuses the first enabled item on open and restores focus on
/// close, the same a11y layer as [KunDropdown].
///
/// The panel is an overlay child on the root overlay, as every KunUI popup
/// is, so it paints above the page while inheriting the host's theme,
/// language and config.
class KunContextMenu extends StatefulWidget {
  /// Creates a context menu.
  const KunContextMenu({
    required this.visible,
    this.items = const <KunMenuEntry>[],
    this.padding = 12,
    this.position = Offset.zero,
    this.width = 192,
    this.onSelected,
    this.onClose,
    this.child,
    super.key,
  });

  /// Whether the menu is open. It asks to close by calling [onClose]; it
  /// never hides itself.
  final bool visible;

  /// The rows, in order. An empty list never opens. Separators and one
  /// level of submenu are allowed; an item with [KunContextMenuItem.children]
  /// never fires [onSelected].
  final List<KunMenuEntry> items;

  /// Margin kept between the panel and the edge of the view, the web's
  /// `padding`.
  final double padding;

  /// Global point to open at — the cursor, or the long-press point.
  ///
  /// The web's `null` means `{ x: 0, y: 0 }`, so a non-null [Offset] covers
  /// it. Defaults to [Offset.zero].
  final Offset position;

  /// A floor for the menu's width, so a menu of short labels does not shrink
  /// to a sliver. The web's `width`, 192, which is `min-width` on the panel.
  final double width;

  /// Called with the row the user activated. A disabled row never calls it.
  final ValueChanged<KunContextMenuItem>? onSelected;

  /// Called when the menu closes, however it closed.
  final VoidCallback? onClose;

  /// Where this widget sits in the tree.
  ///
  /// Not a contract slot. A Flutter overlay needs an element in the tree to
  /// attach the portal; the menu itself opens at [position], not on [child].
  /// Null is an empty anchor.
  final Widget? child;

  @override
  State<KunContextMenu> createState() => _KunContextMenuState();
}

class _KunContextMenuState extends State<KunContextMenu>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final Object _tapGroup = Object();
  final GlobalKey _panelKey = GlobalKey();
  final FocusNode _menuFocus = FocusNode(debugLabel: 'KunContextMenu.menu');
  final GlobalKey<KunMenuListState> _listKey = GlobalKey<KunMenuListState>();

  late final AnimationController _openClose;
  late final CurvedAnimation _curve;
  late final Animation<double> _scale;

  bool _isOpen = false;
  bool _restoreFocus = false;
  bool _scrollRoute = false;
  Size? _viewSize;
  FocusNode? _previouslyFocused;

  bool get _hasContent => kunMenuHasContent(widget.items);

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
    _scale = Tween<double>(begin: 0.95, end: 1).animate(_curve);
    _openClose.addListener(_hidePortalIfDismissed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncOpen();
      }
    });
  }

  @override
  void didUpdateWidget(KunContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool want = widget.visible && _hasContent;
    if (want != _isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncOpen();
        }
      });
    } else if (_isOpen &&
        (oldWidget.position != widget.position ||
            oldWidget.padding != widget.padding ||
            oldWidget.width != widget.width ||
            !identical(oldWidget.items, widget.items))) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _openClose.duration = kunMotion(context, KunDurations.base);
    _openClose.reverseDuration = kunMotion(context, KunDurations.exit);
    final Size size = MediaQuery.sizeOf(context);
    if (_isOpen && _viewSize != null && size != _viewSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _requestClose();
        }
      });
    }
    _viewSize = size;
  }

  @override
  void dispose() {
    _removeScrollClose();
    KunDismissLayers.remove(this);
    _openClose.removeListener(_hidePortalIfDismissed);
    if (_portal.isShowing) {
      _portal.hide();
    }
    _openClose.dispose();
    _curve.dispose();
    _menuFocus.dispose();
    super.dispose();
  }

  void _hidePortalIfDismissed() {
    if (_isOpen || _openClose.value != 0 || !_portal.isShowing) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _hidePortalIfDismissed();
        }
      });
      return;
    }
    _portal.hide();
  }

  void _syncOpen() {
    final bool want = widget.visible && _hasContent;
    if (want && !_isOpen) {
      _present();
    } else if (!want && _isOpen) {
      _dismissVisual();
    }
  }

  void _present() {
    if (_isOpen || !mounted || !widget.visible || !_hasContent) {
      return;
    }
    _previouslyFocused = FocusManager.instance.primaryFocus;
    _restoreFocus = false;
    _isOpen = true;
    KunDismissLayers.add(this);
    _installScrollClose();
    if (!_portal.isShowing) {
      _portal.show();
    }
    _openClose.forward();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isOpen) {
        return;
      }
      final KunMenuListState? list = _listKey.currentState;
      if (list != null) {
        list.focusFirst();
      } else {
        _menuFocus.requestFocus();
      }
    });
  }

  void _dismissVisual() {
    if (!_isOpen) {
      return;
    }
    _isOpen = false;
    KunDismissLayers.remove(this);
    _removeScrollClose();
    _openClose.reverse();
    if (_restoreFocus) {
      _previouslyFocused?.requestFocus();
    }
    _restoreFocus = false;
    setState(() {});
  }

  void _requestClose({bool returnFocus = false}) {
    if (!_isOpen) {
      return;
    }
    _restoreFocus = returnFocus;
    widget.onClose?.call();
  }

  void _installScrollClose() {
    if (_scrollRoute) {
      return;
    }
    _scrollRoute = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  void _removeScrollClose() {
    if (!_scrollRoute) {
      return;
    }
    _scrollRoute = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
  }

  void _onPointer(PointerEvent event) {
    if (event is! PointerScrollEvent || !_isOpen) {
      return;
    }
    final Rect? panel = _panelRect();
    if (panel != null && panel.contains(event.position)) {
      return;
    }
    final Rect? sub = _listKey.currentState?.submenuPanelRect;
    if (sub != null && sub.contains(event.position)) {
      return;
    }
    _requestClose();
  }

  Rect? _panelRect() {
    final RenderObject? ro = _panelKey.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) {
      return null;
    }
    return ro.localToGlobal(Offset.zero) & ro.size;
  }

  void _select(KunContextMenuItem item) {
    if (item.disabled) {
      return;
    }
    widget.onSelected?.call(item);
    final String? href = item.href;
    if (href != null) {
      KunUIConfigScope.of(context).navigateTo(context, href);
    }
    _requestClose(returnFocus: true);
  }

  KeyEventResult _onMenuKey(KeyEvent event) {
    return _listKey.currentState?.handleKey(event) ?? KeyEventResult.ignored;
  }

  Offset _overlayPoint(BuildContext overlayContext, Offset global) {
    final OverlayState overlay = Overlay.of(overlayContext);
    final RenderObject? ro = overlay.context.findRenderObject();
    if (ro is RenderBox && ro.hasSize) {
      return ro.globalToLocal(global);
    }
    return global;
  }

  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final Offset point = _overlayPoint(context, widget.position);
    final Rect viewport = kunAnchorViewport(context, info.overlaySize);

    final Widget menu = DecoratedBox(
      key: _panelKey,
      decoration: BoxDecoration(
        color: scheme.content1,
        borderRadius: BorderRadius.circular(KunRadius.lg),
        boxShadow: KunShadows.md,
      ),
      child: Padding(
        padding: const EdgeInsets.all(KunSpacing.unit),
        child: IntrinsicWidth(
          child: SingleChildScrollView(
            child: KunMenuList(
              key: _listKey,
              entries: widget.items,
              itemKeyPrefix: 'KunContextMenu.item',
              theme: theme,
              minWidth: widget.width,
              tapGroup: _tapGroup,
              onSelect: _select,
              onClose: ({required bool returnFocus}) =>
                  _requestClose(returnFocus: returnFocus),
            ),
          ),
        ),
      ),
    );

    return Positioned.fill(
      child: TapRegion(
        groupId: _tapGroup,
        onTapOutside: (PointerDownEvent event) {
          if (_isOpen) {
            _requestClose();
          }
        },
        child: CustomSingleChildLayout(
          delegate: _KunContextMenuLayout(
            point: point,
            viewport: viewport,
            padding: widget.padding,
            minWidth: widget.width,
          ),
          child: FadeTransition(
            opacity: _curve,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.topLeft,
              child: Focus(
                focusNode: _menuFocus,
                skipTraversal: true,
                onKeyEvent: (FocusNode node, KeyEvent event) =>
                    _onMenuKey(event),
                child: Semantics(
                  key: const ValueKey<String>('KunContextMenu.menu'),
                  container: true,
                  explicitChildNodes: true,
                  role: SemanticsRole.menu,
                  child: GestureDetector(
                    excludeFromSemantics: true,
                    onSecondaryTap: () {},
                    child: DefaultTextStyle.merge(
                      style: KunText.sm.copyWith(color: scheme.foreground),
                      child: menu,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isOpen,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && KunDismissLayers.isTop(this)) {
          _requestClose(returnFocus: true);
        }
      },
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _portal,
        overlayLocation: OverlayChildLocation.rootOverlay,
        overlayChildBuilder: _buildOverlay,
        child: widget.child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _KunContextMenuLayout extends SingleChildLayoutDelegate {
  _KunContextMenuLayout({
    required this.point,
    required this.viewport,
    required this.padding,
    required this.minWidth,
  });

  final Offset point;
  final Rect viewport;
  final double padding;
  final double minWidth;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final double maxW = math.max(0, viewport.width - padding * 2);
    final double maxH = math.max(0, viewport.height - padding * 2);
    return BoxConstraints(
      minWidth: minWidth.clamp(0, maxW),
      maxWidth: maxW,
      maxHeight: maxH,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double minX = viewport.left + padding;
    final double minY = viewport.top + padding;
    final double maxX = viewport.right - padding - childSize.width;
    final double maxY = viewport.bottom - padding - childSize.height;
    final double x = math.min(math.max(point.dx, minX), math.max(minX, maxX));
    final double y = math.min(math.max(point.dy, minY), math.max(minY, maxY));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _KunContextMenuLayout oldDelegate) {
    return point != oldDelegate.point ||
        viewport != oldDelegate.viewport ||
        padding != oldDelegate.padding ||
        minWidth != oldDelegate.minWidth;
  }
}
