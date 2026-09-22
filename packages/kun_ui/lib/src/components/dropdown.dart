import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../config/config.dart';
import '../foundation/anchored.dart';
import '../foundation/design.dart';
import '../foundation/dismiss_layers.dart';
import '../foundation/motion.dart';
import '../foundation/variant_style.dart';
import '../theme/theme.dart';
import 'popover.dart' show KunPopoverPosition;

/// The web's `offset: 6` for a dropdown, tighter than the 8 every other
/// overlay uses.
const double _kDropdownOffset = 6;

/// One row of a [KunDropdown]'s menu.
///
/// The same model the web shares between its dropdown and its context menu,
/// with the icon as [IconData] rather than an Iconify name: `kun_ui_icons`
/// carries only the glyphs the components themselves draw, so a menu's icons
/// come from the app's own set.
@immutable
class KunDropdownItem {
  /// Creates an item.
  const KunDropdownItem({
    required this.key,
    required this.label,
    this.icon,
    this.color = KunUIColor.neutral,
    this.disabled = false,
    this.href,
  });

  /// Identifies the item to the application; never shown.
  final String key;

  /// The row's text.
  final String label;

  /// Drawn before [label].
  final IconData? icon;

  /// Tints the row, through the `light` variant.
  final KunUIColor color;

  /// Whether the row is inert: it is skipped by the arrow keys and by
  /// type-ahead, and activating it does nothing.
  final bool disabled;

  /// Hands this row to [KunUIConfig.navigate] when it is activated, for a
  /// menu that goes somewhere rather than doing something.
  final String? href;

  @override
  bool operator ==(Object other) =>
      other is KunDropdownItem &&
      other.key == key &&
      other.label == label &&
      other.icon == icon &&
      other.color == color &&
      other.disabled == disabled &&
      other.href == href;

  @override
  int get hashCode => Object.hash(key, label, icon, color, disabled, href);
}

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
    this.items = const <KunDropdownItem>[],
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

  /// The rows, in order. An empty list never opens.
  final List<KunDropdownItem> items;

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
  List<FocusNode> _itemFocus = <FocusNode>[];

  late final AnimationController _openClose;
  late final CurvedAnimation _curve;
  late final Animation<double> _scale;

  bool _isOpen = false;
  int _activeIndex = -1;
  String _typeBuffer = '';
  Timer? _typeTimer;
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
    _syncItemFocus();
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
    if (oldWidget.items.length != widget.items.length) {
      _syncItemFocus();
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
    _typeTimer?.cancel();
    _openClose.removeListener(_hidePortalIfDismissed);
    if (_portal.isShowing) {
      _portal.hide();
    }
    _openClose.dispose();
    _curve.dispose();
    _triggerFocus.dispose();
    _menuFocus.dispose();
    for (final FocusNode node in _itemFocus) {
      node.dispose();
    }
    _resolved.dispose();
    super.dispose();
  }

  void _syncItemFocus() {
    for (final FocusNode node in _itemFocus) {
      node.dispose();
    }
    _itemFocus = <FocusNode>[
      for (int i = 0; i < widget.items.length; i++)
        FocusNode(debugLabel: 'KunDropdown.item.$i'),
    ];
  }

  void _hidePortalIfDismissed() {
    if (!_isOpen && _openClose.value == 0 && _portal.isShowing) {
      _portal.hide();
    }
  }

  List<int> get _enabled => <int>[
        for (int i = 0; i < widget.items.length; i++)
          if (!widget.items[i].disabled) i,
      ];

  void _open({int? focusIndex}) {
    if (_isOpen || widget.disabled || widget.items.isEmpty || !mounted) {
      return;
    }
    KunDismissLayers.add(this);
    setState(() {
      _isOpen = true;
      _activeIndex = -1;
    });
    _portal.show();
    _openClose.forward();
    widget.onOpen?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isOpen || !mounted) {
        return;
      }
      if (focusIndex != null) {
        _focusItem(focusIndex);
      } else {
        _menuFocus.requestFocus();
      }
    });
  }

  void _openFirst() {
    final List<int> enabled = _enabled;
    _open(focusIndex: enabled.isEmpty ? null : enabled.first);
  }

  void _openLast() {
    final List<int> enabled = _enabled;
    _open(focusIndex: enabled.isEmpty ? null : enabled.last);
  }

  void _close({bool returnFocus = false}) {
    if (!_isOpen || !mounted) {
      return;
    }
    KunDismissLayers.remove(this);
    setState(() {
      _isOpen = false;
      _activeIndex = -1;
    });
    _openClose.reverse();
    _typeTimer?.cancel();
    _typeBuffer = '';
    widget.onClose?.call();
    if (returnFocus) {
      _triggerFocus.requestFocus();
    }
  }

  void _toggle() => _isOpen ? _close() : _open();

  void _focusItem(int index) {
    if (index < 0 || index >= _itemFocus.length) {
      return;
    }
    setState(() => _activeIndex = index);
    _itemFocus[index].requestFocus();
  }

  void _move(int delta) {
    final List<int> enabled = _enabled;
    if (enabled.isEmpty) {
      return;
    }
    final int at = enabled.indexOf(_activeIndex);
    final int next = (at + delta + enabled.length) % enabled.length;
    _focusItem(enabled[at == -1 && delta < 0 ? enabled.length - 1 : next]);
  }

  void _typeahead(String character) {
    _typeBuffer += character.toLowerCase();
    _typeTimer?.cancel();
    _typeTimer = Timer(
      const Duration(milliseconds: 600),
      () => _typeBuffer = '',
    );
    final int index = widget.items.indexWhere(
      (KunDropdownItem item) =>
          !item.disabled && item.label.toLowerCase().startsWith(_typeBuffer),
    );
    if (index >= 0) {
      _focusItem(index);
    }
  }

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
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        final List<int> enabled = _enabled;
        if (enabled.isNotEmpty) {
          _focusItem(enabled.first);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        final List<int> enabled = _enabled;
        if (enabled.isNotEmpty) {
          _focusItem(enabled.last);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
        if (_activeIndex >= 0) {
          _select(widget.items[_activeIndex]);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.tab:
        _close(returnFocus: true);
        return KeyEventResult.handled;
    }
    final String? character = event.character;
    if (character != null &&
        character.length == 1 &&
        character.trim().isNotEmpty) {
      _typeahead(character);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < widget.items.length; i++)
                  _KunDropdownRow(
                    key: ValueKey<String>(
                        'KunDropdown.item.${widget.items[i].key}'),
                    item: widget.items[i],
                    focusNode: _itemFocus[i],
                    theme: theme,
                    onActivate: () => _select(widget.items[i]),
                    onHover: () {
                      if (!widget.items[i].disabled) {
                        _focusItem(i);
                      }
                    },
                  ),
              ],
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
    final Widget trigger = Semantics(
      button: true,
      enabled: !widget.disabled,
      expanded: _isOpen,
      label: widget.semanticLabel,
      onTap: widget.disabled ? null : _toggle,
      child: ExcludeSemantics(child: widget.trigger),
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

class _KunDropdownRow extends StatefulWidget {
  const _KunDropdownRow({
    required this.item,
    required this.focusNode,
    required this.theme,
    required this.onActivate,
    required this.onHover,
    super.key,
  });

  final KunDropdownItem item;
  final FocusNode focusNode;
  final KunThemeData theme;
  final VoidCallback onActivate;
  final VoidCallback onHover;

  @override
  State<_KunDropdownRow> createState() => _KunDropdownRowState();
}

class _KunDropdownRowState extends State<_KunDropdownRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final KunDropdownItem item = widget.item;
    final KunVariantStyle style = KunVariantStyle.resolve(
      scheme: widget.theme.colors,
      brightness: widget.theme.brightness,
      variant: KunUIVariant.light,
      color: item.color,
    );
    // The web's `light` cell defines only `hover:`, so the menu adds a focus
    // tint of the same 20% — a row reached by the arrow keys has to look
    // exactly like one reached by the pointer.
    final bool lit = !item.disabled && (_hovered || widget.focusNode.hasFocus);

    final Widget row = Container(
      decoration: BoxDecoration(
        color: lit ? style.hoverOverlay : null,
        borderRadius: BorderRadius.circular(KunRadius.md),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: KunSpacing.unit * 3,
        vertical: KunSpacing.unit * 1.5,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (item.icon != null) ...<Widget>[
            Icon(item.icon,
                size: KunText.base.fontSize, color: style.foreground),
            const SizedBox(width: KunSpacing.unit * 2),
          ],
          Flexible(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KunText.sm.copyWith(
                color: style.foreground,
                fontWeight: KunFontWeights.medium,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      role: SemanticsRole.menuItem,
      label: item.label,
      enabled: !item.disabled,
      onTap: item.disabled ? null : widget.onActivate,
      child: ExcludeSemantics(
        child: Focus(
          focusNode: widget.focusNode,
          canRequestFocus: !item.disabled,
          skipTraversal: true,
          onFocusChange: (_) => setState(() {}),
          child: MouseRegion(
            cursor: item.disabled
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            onEnter: (_) {
              setState(() => _hovered = true);
              widget.onHover();
            },
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: item.disabled ? null : widget.onActivate,
              child: Opacity(opacity: item.disabled ? 0.5 : 1, child: row),
            ),
          ),
        ),
      ),
    );
  }
}
