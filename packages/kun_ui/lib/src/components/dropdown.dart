import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../config/config.dart';
import '../foundation/anchored.dart';
import '../foundation/dismiss_layers.dart';
import '../foundation/motion.dart';
import '../theme/theme.dart';
import 'menu_panel.dart';
import 'popover.dart' show KunPopoverPosition;

export 'menu_panel.dart'
    show KunContextMenuItem, KunDropdownItem, KunMenuEntry, KunMenuSeparator;

/// The web's `offset: 6` for a dropdown, tighter than the 8 every other
/// overlay uses.
const double _kDropdownOffset = 6;

/// Opens and closes a [KunDropdown] from outside it, the web's
/// `defineExpose`.
class KunDropdownController {
  _KunDropdownState? _state;

  /// Whether the menu is open.
  bool get isOpen => _state?._isOpen ?? false;

  /// Opens the menu without moving focus onto a row.
  void open() => _state?._open();

  /// Closes the menu.
  void close() => _state?._close();

  /// Opens the menu when it is closed, and closes it when it is open.
  void toggle() => _state?._toggle();
}

/// An action menu that drops out of its trigger.
///
/// Deliberately not built on [KunPopover], for the same reason the web keeps
/// them apart: a menu owes assistive technology the menu/menuitem roles and
/// the keyboard of the WAI-ARIA menu-button pattern — one tab stop for the
/// whole menu, the arrow keys moving between rows, Home and End, type-ahead,
/// and Escape or Tab closing it — none of which a dialog can carry.
///
/// The panel is an overlay child on the root overlay, as every KunUI popup
/// is, so it paints above the page while inheriting the trigger's theme,
/// language and config.
class KunDropdown extends StatefulWidget {
  /// Creates a dropdown.
  const KunDropdown({
    required this.trigger,
    this.items = const <KunMenuEntry>[],
    this.position = KunPopoverPosition.bottomStart,
    this.minWidth = 192,
    this.disabled = false,
    this.onSelected,
    this.onOpen,
    this.onClose,
    this.controller,
    this.semanticLabel,
    super.key,
  });

  /// What the menu drops out of. It becomes the menu's single tab stop, so
  /// pass a plain widget rather than something that takes focus itself.
  final Widget trigger;

  /// The rows, in order. An empty list never opens. Separators and one
  /// level of submenu are allowed; an item with [KunContextMenuItem.children]
  /// never fires [onSelected].
  final List<KunMenuEntry> items;

  /// Where the menu sits. It flips and shifts to stay on screen.
  final KunPopoverPosition position;

  /// A floor for the menu's width, so a menu of short labels does not shrink
  /// to a sliver. The web's `minWidth`, 192.
  final double minWidth;

  /// Whether the trigger is inert.
  final bool disabled;

  /// Called with the row the user activated. A disabled row never calls it.
  final ValueChanged<KunDropdownItem>? onSelected;

  /// Called when the menu opens.
  final VoidCallback? onOpen;

  /// Called when the menu closes, however it closed.
  final VoidCallback? onClose;

  /// Opens and closes the menu from application code.
  final KunDropdownController? controller;

  /// The trigger's accessible name, for a trigger that is only an icon.
  final String? semanticLabel;

  @override
  State<KunDropdown> createState() => _KunDropdownState();
}

class _KunDropdownState extends State<KunDropdown>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final Object _tapGroup = Object();
  final FocusNode _triggerFocus = FocusNode(debugLabel: 'KunDropdown.trigger');
  final FocusNode _menuFocus = FocusNode(debugLabel: 'KunDropdown.menu');
  final GlobalKey<KunMenuListState> _listKey = GlobalKey<KunMenuListState>();

  late final AnimationController _openClose;
  late final CurvedAnimation _curve;
  late final Animation<double> _scale;

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
    _scale = Tween<double>(begin: 0.95, end: 1).animate(_curve);
    _openClose.addListener(_hidePortalIfDismissed);
    _triggerFocus.canRequestFocus = !widget.disabled;
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(KunDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (identical(oldWidget.controller?._state, this)) {
        oldWidget.controller?._state = null;
      }
      widget.controller?._state = this;
    }
    _triggerFocus.canRequestFocus = !widget.disabled;
    if (widget.disabled && _isOpen) {
      _close();
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
    _openClose.removeListener(_hidePortalIfDismissed);
    if (_portal.isShowing) {
      _portal.hide();
    }
    _openClose.dispose();
    _curve.dispose();
    _triggerFocus.dispose();
    _menuFocus.dispose();
    _resolved.dispose();
    super.dispose();
  }

  void _hidePortalIfDismissed() {
    if (!_isOpen && _openClose.value == 0 && _portal.isShowing) {
      _portal.hide();
    }
  }

  void _open({void Function(KunMenuListState list)? focus}) {
    if (_isOpen ||
        widget.disabled ||
        !kunMenuHasContent(widget.items) ||
        !mounted) {
      return;
    }
    KunDismissLayers.add(this);
    setState(() {
      _isOpen = true;
    });
    _portal.show();
    _openClose.forward();
    widget.onOpen?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isOpen || !mounted) {
        return;
      }
      final KunMenuListState? list = _listKey.currentState;
      if (list != null && focus != null) {
        focus(list);
      } else {
        _menuFocus.requestFocus();
      }
    });
  }

  void _openFirst() {
    _open(focus: (KunMenuListState list) => list.focusFirst());
  }

  void _openLast() {
    _open(focus: (KunMenuListState list) => list.focusLast());
  }

  void _close({bool returnFocus = false}) {
    if (!_isOpen || !mounted) {
      return;
    }
    KunDismissLayers.remove(this);
    setState(() {
      _isOpen = false;
    });
    _openClose.reverse();
    widget.onClose?.call();
    if (returnFocus) {
      _triggerFocus.requestFocus();
    }
  }

  void _toggle() => _isOpen ? _close() : _open();

  void _select(KunDropdownItem item) {
    if (item.disabled) {
      return;
    }
    widget.onSelected?.call(item);
    final String? href = item.href;
    if (href != null) {
      KunUIConfigScope.of(context).navigateTo(context, href);
    }
    _close(returnFocus: true);
  }

  KeyEventResult _onTriggerKey(KeyEvent event) {
    if (event is! KeyDownEvent || widget.disabled) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
        _openFirst();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _openLast();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onMenuKey(KeyEvent event) {
    return _listKey.currentState?.handleKey(event) ?? KeyEventResult.ignored;
  }

  void _onResolved(KunAnchorResolution resolution) {
    if (_resolved.value == resolution) {
      return;
    }
    // This runs inside layout, where notifying a listener would rebuild
    // mid-layout, so the placement reaches the scale origin on the next
    // frame. The menu's first frame paints at opacity 0, so the frame drawn
    // from the default placement is never seen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resolved.value = resolution;
      }
    });
  }

  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final Rect anchor = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );

    final Widget menu = DecoratedBox(
      key: const ValueKey<String>('KunDropdown.menu'),
      decoration: BoxDecoration(
        color: scheme.content1,
        borderRadius: BorderRadius.circular(KunRadius.lg),
        boxShadow: KunShadows.md,
      ),
      child: Padding(
        padding: const EdgeInsets.all(KunSpacing.unit),
        // The web's menu is absolutely positioned, so it shrink-wraps its
        // widest row and only `min-width` holds it open. A stretched Column
        // takes the width it is offered instead, which is the whole view.
        child: IntrinsicWidth(
          child: SingleChildScrollView(
            child: KunMenuList(
              key: _listKey,
              entries: widget.items,
              itemKeyPrefix: 'KunDropdown.item',
              theme: theme,
              minWidth: widget.minWidth,
              tapGroup: _tapGroup,
              onSelect: _select,
              onClose: ({required bool returnFocus}) =>
                  _close(returnFocus: returnFocus),
            ),
          ),
        ),
      ),
    );

    return Positioned.fill(
      child: TapRegion(
        groupId: _tapGroup,
        child: CustomSingleChildLayout(
          delegate: KunAnchoredLayout(
            anchor: anchor,
            viewport: kunAnchorViewport(context, info.overlaySize),
            side: widget.position.side,
            align: widget.position.align,
            offset: _kDropdownOffset,
            minWidth: widget.minWidth,
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
              child: Focus(
                focusNode: _menuFocus,
                skipTraversal: true,
                onKeyEvent: (FocusNode node, KeyEvent event) =>
                    _onMenuKey(event),
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  role: SemanticsRole.menu,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Merged, not excluded: the web's wrapper carries role="button" while the
    // slotted trigger supplies the accessible name. Excluding the trigger's
    // own semantics left the node nameless — an Android dump showed no node
    // for it at all — and giving it a separate node would announce a button
    // inside a button.
    final Widget trigger = MergeSemantics(
      child: Semantics(
        button: true,
        enabled: !widget.disabled,
        expanded: _isOpen,
        label: widget.semanticLabel,
        onTap: widget.disabled ? null : _toggle,
        child: widget.trigger,
      ),
    );

    return PopScope(
      canPop: !_isOpen,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && KunDismissLayers.isTop(this)) {
          _close(returnFocus: true);
        }
      },
      child: TapRegion(
        groupId: _tapGroup,
        onTapOutside: (PointerDownEvent event) {
          if (_isOpen) {
            _close();
          }
        },
        child: Focus(
          focusNode: _triggerFocus,
          onKeyEvent: (FocusNode node, KeyEvent event) => _onTriggerKey(event),
          child: KunTriggerTap(
            onTap: widget.disabled ? null : _toggle,
            child: Opacity(
              opacity: widget.disabled ? 0.5 : 1,
              child: OverlayPortal.overlayChildLayoutBuilder(
                controller: _portal,
                overlayLocation: OverlayChildLocation.rootOverlay,
                overlayChildBuilder: _buildOverlay,
                child: trigger,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
