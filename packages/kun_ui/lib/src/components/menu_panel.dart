import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/anchored.dart';
import '../foundation/design.dart';
import '../foundation/motion.dart';
import '../foundation/pointer_menu.dart';
import '../foundation/variant_style.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'kbd.dart';

/// Type-ahead buffer reset after the last character.
/// MenuList.vue:113 `setTimeout(() => (typeBuffer = ''), 600)`
const Duration _kMenuTypeaheadReset = Duration(milliseconds: 600);

/// Submenu hover open delay.
/// useKunPointerMenu.ts:108 `const openDelay = options.openDelay ?? 100`
const Duration _kSubmenuOpenDelay = Duration(milliseconds: 100);

/// Grace after leaving the submenu panel, and KunPointerMenu close delay.
/// MenuSubTrigger.vue:22 `const GRACE_MS = 300`
const Duration _kSubmenuGrace = Duration(milliseconds: 300);

/// Submenu floating-ui main-axis offset.
/// MenuList.vue:142 `offset: { mainAxis: 4, crossAxis: -4 }`
const double _kSubmenuMainOffset = 4;

/// Submenu floating-ui cross-axis offset (first item lines up with the row).
/// MenuList.vue:142 `offset: { mainAxis: 4, crossAxis: -4 }`
const double _kSubmenuCrossOffset = -4;

/// One row of a [KunContextMenu] or a [KunDropdown]: an item or a separator.
sealed class KunMenuEntry {
  /// Creates an entry.
  const KunMenuEntry();
}

/// One command row of a [KunContextMenu] or a [KunDropdown].
///
/// The same model the web shares between its context menu and its dropdown,
/// with the icon as [IconData] rather than an Iconify name: `kun_ui_icons`
/// carries only the glyphs the components themselves draw, so a menu's icons
/// come from the app's own set.
@immutable
class KunContextMenuItem extends KunMenuEntry {
  /// Creates an item.
  const KunContextMenuItem({
    required this.key,
    required this.label,
    this.icon,
    this.color = KunUIColor.neutral,
    this.disabled = false,
    this.href,
    this.shortcut,
    this.children,
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

  /// A keyboard shortcut shown at the row's end, e.g. `'Mod+C'`. Display
  /// only: the app binds the key.
  final String? shortcut;

  /// Items of a submenu, opened by hover, → or a tap. One level only: a
  /// child cannot have children. Null is a leaf; an empty or
  /// separator-only list is a disabled submenu parent.
  ///
  /// Defaults to null, not `const []`, so existing callers that omit
  /// [children] stay leaves. The web's `children?` is the same absence.
  final List<KunMenuEntry>? children;

  @override
  bool operator ==(Object other) =>
      other is KunContextMenuItem &&
      other.key == key &&
      other.label == label &&
      other.icon == icon &&
      other.color == color &&
      other.disabled == disabled &&
      other.href == href &&
      other.shortcut == shortcut &&
      listEquals(other.children, children);

  @override
  int get hashCode => Object.hash(
        key,
        label,
        icon,
        color,
        disabled,
        href,
        shortcut,
        Object.hashAll(children ?? const <KunMenuEntry>[]),
      );
}

/// A dividing line between groups of items. Leading, trailing and repeated
/// separators are dropped, so a filtered list stays clean.
@immutable
class KunMenuSeparator extends KunMenuEntry {
  /// Creates a separator.
  const KunMenuSeparator({this.key});

  /// Optional identity for a keyed list; never shown.
  final String? key;

  @override
  bool operator ==(Object other) =>
      other is KunMenuSeparator && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// The dropdown reuses the context menu's item model, as on the web.
typedef KunDropdownItem = KunContextMenuItem;

/// Drop separators that would render as stray lines: leading, trailing, and
/// all but the first of a run.
List<KunMenuEntry> normalizeKunMenuSeparators(List<KunMenuEntry> entries) {
  final List<KunMenuEntry> out = <KunMenuEntry>[];
  for (final KunMenuEntry entry in entries) {
    final KunMenuEntry? last = out.isEmpty ? null : out.last;
    if (entry is KunMenuSeparator &&
        (last == null || last is KunMenuSeparator)) {
      continue;
    }
    out.add(entry);
  }
  while (out.isNotEmpty && out.last is KunMenuSeparator) {
    out.removeLast();
  }
  return out;
}

/// Whether the list has a command row, as the web's `hasItems`.
bool kunMenuHasContent(List<KunMenuEntry> entries) =>
    entries.any((KunMenuEntry entry) => entry is KunContextMenuItem);

/// Whether [item] opens a submenu at [level].
bool kunMenuHasSubmenu(KunContextMenuItem item, {int level = 0}) =>
    level == 0 && item.children != null;

/// Whether [item] is inert at [level], including a submenu with no items.
bool kunMenuRowDisabled(KunContextMenuItem item, {int level = 0}) {
  if (item.disabled) {
    return true;
  }
  if (kunMenuHasSubmenu(item, level: level)) {
    return !item.children!
        .any((KunMenuEntry child) => child is KunContextMenuItem);
  }
  return false;
}

/// Indices of the rows that keyboard navigation may land on.
List<int> kunMenuEnabledIndices(
  List<KunMenuEntry> items, {
  int level = 0,
}) =>
    <int>[
      for (int i = 0; i < items.length; i++)
        if (items[i] is KunContextMenuItem &&
            !kunMenuRowDisabled(
              items[i] as KunContextMenuItem,
              level: level,
            ))
          i,
    ];

/// The next enabled index after moving [delta] steps, wrapping at the ends.
///
/// Returns `-1` when nothing is enabled. A start of `-1` with a negative
/// [delta] lands on the last enabled row, matching the web's `move`.
int kunMenuMoveIndex({
  required List<int> enabled,
  required int activeIndex,
  required int delta,
}) {
  if (enabled.isEmpty) {
    return -1;
  }
  final int at = enabled.indexOf(activeIndex);
  final int next = (at + delta + enabled.length) % enabled.length;
  return enabled[at == -1 && delta < 0 ? enabled.length - 1 : next];
}

/// The WAI-ARIA menu key map shared by [KunDropdown] and [KunContextMenu].
KeyEventResult kunMenuKeyEvent(
  KeyEvent event, {
  required List<int> enabled,
  required int activeIndex,
  required void Function(int index) onFocusItem,
  required VoidCallback onClose,
  required VoidCallback onSelectActive,
  void Function(String character)? onTypeahead,
}) {
  if (event is! KeyDownEvent) {
    return KeyEventResult.ignored;
  }
  switch (event.logicalKey) {
    case LogicalKeyboardKey.arrowDown:
      final int next = kunMenuMoveIndex(
        enabled: enabled,
        activeIndex: activeIndex,
        delta: 1,
      );
      if (next >= 0) {
        onFocusItem(next);
      }
      return KeyEventResult.handled;
    case LogicalKeyboardKey.arrowUp:
      final int next = kunMenuMoveIndex(
        enabled: enabled,
        activeIndex: activeIndex,
        delta: -1,
      );
      if (next >= 0) {
        onFocusItem(next);
      }
      return KeyEventResult.handled;
    case LogicalKeyboardKey.home:
      if (enabled.isNotEmpty) {
        onFocusItem(enabled.first);
      }
      return KeyEventResult.handled;
    case LogicalKeyboardKey.end:
      if (enabled.isNotEmpty) {
        onFocusItem(enabled.last);
      }
      return KeyEventResult.handled;
    case LogicalKeyboardKey.enter:
    case LogicalKeyboardKey.space:
      onSelectActive();
      return KeyEventResult.handled;
    case LogicalKeyboardKey.escape:
    case LogicalKeyboardKey.tab:
      onClose();
      return KeyEventResult.handled;
  }
  final String? character = event.character;
  if (onTypeahead != null &&
      character != null &&
      character.length == 1 &&
      character.trim().isNotEmpty) {
    onTypeahead(character);
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

/// The role="menu" list [KunDropdown] and [KunContextMenu] share.
///
/// Not exported from `package:kun_ui/kun_ui.dart`.
class KunMenuList extends StatefulWidget {
  /// Creates a shared menu list.
  const KunMenuList({
    required this.entries,
    required this.itemKeyPrefix,
    required this.theme,
    required this.onSelect,
    required this.onClose,
    this.level = 0,
    this.minWidth = 192,
    this.tapGroup,
    this.onBack,
    super.key,
  });

  /// Items and separators, before normalisation.
  final List<KunMenuEntry> entries;

  /// Prefix for each row's [ValueKey], e.g. `KunContextMenu.item`.
  final String itemKeyPrefix;

  /// Colours and brightness for the `light` tint.
  final KunThemeData theme;

  /// A leaf was activated.
  final ValueChanged<KunContextMenuItem> onSelect;

  /// Close the whole menu tree.
  final void Function({required bool returnFocus}) onClose;

  /// `0` is the root; `1` is a submenu.
  final int level;

  /// Floor for a submenu panel's width.
  final double minWidth;

  /// Shared with the host's [TapRegion], so a tap in a submenu is not
  /// outside.
  final Object? tapGroup;

  /// A submenu asks its parent to close it (← or Escape).
  final VoidCallback? onBack;

  @override
  State<KunMenuList> createState() => KunMenuListState();
}

/// The state [KunContextMenu] and [KunDropdown] drive.
class KunMenuListState extends State<KunMenuList> {
  List<FocusNode> _itemFocus = <FocusNode>[];
  int _activeIndex = -1;
  int _openSub = -1;
  bool _focusSubOnOpen = false;
  String _typeBuffer = '';
  Timer? _typeTimer;
  Rect? _submenuRect;

  List<KunMenuEntry> get _rows => normalizeKunMenuSeparators(widget.entries);

  List<int> get _enabled => kunMenuEnabledIndices(_rows, level: widget.level);

  @override
  void initState() {
    super.initState();
    _assertOneLevel();
    _syncItemFocus();
  }

  @override
  void didUpdateWidget(KunMenuList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _assertOneLevel();
    if (_itemFocus.length != _rows.length) {
      _syncItemFocus();
    }
    final String before =
        _rowSignature(normalizeKunMenuSeparators(oldWidget.entries));
    final String after = _rowSignature(_rows);
    if (before != after) {
      _closeSubmenu(refocus: false);
    }
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    for (final FocusNode node in _itemFocus) {
      node.dispose();
    }
    super.dispose();
  }

  void _assertOneLevel() {
    assert(() {
      for (final KunMenuEntry entry in widget.entries) {
        if (entry is! KunContextMenuItem) {
          continue;
        }
        for (final KunMenuEntry child
            in entry.children ?? const <KunMenuEntry>[]) {
          if (child is KunContextMenuItem &&
              child.children != null &&
              child.children!.isNotEmpty) {
            throw FlutterError(
              'KunContextMenuItem.children is one level only.',
            );
          }
        }
      }
      return true;
    }());
  }

  String _rowSignature(List<KunMenuEntry> rows) {
    return rows.map((KunMenuEntry row) {
      if (row is KunContextMenuItem) {
        return row.key;
      }
      return (row as KunMenuSeparator).key ?? '';
    }).join('\u0000');
  }

  void _syncItemFocus() {
    for (final FocusNode node in _itemFocus) {
      node.dispose();
    }
    _itemFocus = <FocusNode>[
      for (int i = 0; i < _rows.length; i++)
        FocusNode(debugLabel: '${widget.itemKeyPrefix}.$i'),
    ];
    if (_activeIndex >= _itemFocus.length) {
      _activeIndex = -1;
    }
  }

  /// Focus the first enabled row, or the list itself when none is enabled.
  void focusFirst() {
    final List<int> enabled = _enabled;
    if (enabled.isEmpty) {
      _activeIndex = -1;
      return;
    }
    _focusItem(enabled.first);
  }

  /// Focus the last enabled row, or the list itself when none is enabled.
  void focusLast() {
    final List<int> enabled = _enabled;
    if (enabled.isEmpty) {
      _activeIndex = -1;
      return;
    }
    _focusItem(enabled.last);
  }

  /// Clear the roving tabindex, matching the web's `focusMenu`.
  void focusMenu() {
    setState(() => _activeIndex = -1);
  }

  /// The open submenu's global box, if any.
  Rect? get submenuPanelRect => _submenuRect;

  void _focusItem(int index) {
    if (index < 0 || index >= _itemFocus.length) {
      return;
    }
    setState(() => _activeIndex = index);
    _itemFocus[index].requestFocus();
  }

  void _typeahead(String character) {
    _typeBuffer += character.toLowerCase();
    _typeTimer?.cancel();
    _typeTimer = Timer(_kMenuTypeaheadReset, () => _typeBuffer = '');
    final int index = _rows.indexWhere((KunMenuEntry row) {
      return row is KunContextMenuItem &&
          !kunMenuRowDisabled(row, level: widget.level) &&
          row.label.toLowerCase().startsWith(_typeBuffer);
    });
    if (index >= 0) {
      _focusItem(index);
    }
  }

  void _openSubmenu(int index, {required bool focus}) {
    final KunMenuEntry row = _rows[index];
    if (row is! KunContextMenuItem ||
        !kunMenuHasSubmenu(row, level: widget.level) ||
        kunMenuRowDisabled(row, level: widget.level)) {
      return;
    }
    setState(() {
      _openSub = index;
      _focusSubOnOpen = focus;
      _activeIndex = index;
    });
  }

  void _closeSubmenu({required bool refocus}) {
    final int index = _openSub;
    if (index < 0) {
      return;
    }
    setState(() {
      _openSub = -1;
      _focusSubOnOpen = false;
    });
    if (refocus) {
      _focusItem(index);
    }
  }

  void _activate(KunContextMenuItem item, int index) {
    if (kunMenuRowDisabled(item, level: widget.level)) {
      return;
    }
    if (kunMenuHasSubmenu(item, level: widget.level)) {
      if (_openSub != index) {
        _openSubmenu(index, focus: false);
      }
      return;
    }
    widget.onSelect(item);
  }

  /// The WAI-ARIA menu key map, plus submenu ←/→.
  KeyEventResult handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final KunMenuEntry? row = _activeIndex >= 0 && _activeIndex < _rows.length
        ? _rows[_activeIndex]
        : null;
    final KunContextMenuItem? item = row is KunContextMenuItem ? row : null;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
        if (item != null &&
            kunMenuHasSubmenu(item, level: widget.level) &&
            !kunMenuRowDisabled(item, level: widget.level)) {
          _openSubmenu(_activeIndex, focus: true);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.arrowLeft:
        if (widget.level == 1) {
          widget.onBack?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
        if (item != null &&
            kunMenuHasSubmenu(item, level: widget.level) &&
            !kunMenuRowDisabled(item, level: widget.level)) {
          _openSubmenu(_activeIndex, focus: true);
          return KeyEventResult.handled;
        }
        break;
      case LogicalKeyboardKey.escape:
        if (widget.level == 1) {
          widget.onBack?.call();
          return KeyEventResult.handled;
        }
        break;
      case LogicalKeyboardKey.tab:
        if (widget.level == 1) {
          widget.onClose(returnFocus: true);
          return KeyEventResult.handled;
        }
        break;
    }
    return kunMenuKeyEvent(
      event,
      enabled: _enabled,
      activeIndex: _activeIndex,
      onFocusItem: _focusItem,
      onClose: () => widget.onClose(returnFocus: true),
      onSelectActive: () {
        if (item != null) {
          _activate(item, _activeIndex);
        }
      },
      onTypeahead: _typeahead,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<KunMenuEntry> rows = _rows;
    final List<Widget> children = <Widget>[
      for (int i = 0; i < rows.length; i++)
        if (rows[i] is KunMenuSeparator)
          _KunMenuSeparatorLine(
            key: ValueKey<String>(
              '${widget.itemKeyPrefix}.separator.${(rows[i] as KunMenuSeparator).key ?? i}',
            ),
            color: widget.theme.colors.border,
          )
        else
          _buildItem(rows[i] as KunContextMenuItem, i),
    ];
    final Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (widget.level != 1) {
      return column;
    }
    return Focus(
      skipTraversal: true,
      onKeyEvent: (FocusNode node, KeyEvent event) => handleKey(event),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        role: SemanticsRole.menu,
        child: column,
      ),
    );
  }

  Widget _buildItem(KunContextMenuItem item, int index) {
    final bool disabled = kunMenuRowDisabled(item, level: widget.level);
    final bool hasSubmenu = kunMenuHasSubmenu(item, level: widget.level);
    final Widget row = KunMenuRow(
      key: ValueKey<String>('${widget.itemKeyPrefix}.${item.key}'),
      item: item,
      disabled: disabled,
      hasSubmenu: hasSubmenu,
      expanded: hasSubmenu && _openSub == index,
      focusNode: _itemFocus[index],
      theme: widget.theme,
      onActivate: () => _activate(item, index),
      onHover: () {
        if (!disabled) {
          _focusItem(index);
        }
      },
    );
    if (!hasSubmenu) {
      return row;
    }
    return _KunSubmenuAnchor(
      open: _openSub == index,
      focusOnOpen: _focusSubOnOpen && _openSub == index,
      entries: item.children ?? const <KunMenuEntry>[],
      itemKeyPrefix: widget.itemKeyPrefix,
      theme: widget.theme,
      minWidth: widget.minWidth,
      tapGroup: widget.tapGroup,
      onSelect: widget.onSelect,
      onClose: widget.onClose,
      onHoverOpen: () => _openSubmenu(index, focus: false),
      onHoverClose: () {
        if (_openSub == index) {
          _closeSubmenu(refocus: false);
        }
      },
      onBack: () => _closeSubmenu(refocus: true),
      onPanelRect: (Rect? rect) => _submenuRect = rect,
      enabled: !disabled,
      child: row,
    );
  }
}

/// One painted row of a [KunDropdown] or [KunContextMenu] panel.
///
/// Not exported from `package:kun_ui/kun_ui.dart`. Apps pass
/// [KunContextMenuItem]s; they do not build this widget.
class KunMenuRow extends StatefulWidget {
  /// Creates a row.
  const KunMenuRow({
    required this.item,
    required this.focusNode,
    required this.theme,
    required this.onActivate,
    required this.onHover,
    this.disabled = false,
    this.hasSubmenu = false,
    this.expanded = false,
    super.key,
  });

  /// The model this row draws.
  final KunContextMenuItem item;

  /// Resolved inert state, including an empty submenu parent.
  final bool disabled;

  /// Whether this row opens a submenu.
  final bool hasSubmenu;

  /// The web's `aria-expanded`, true while the submenu is open.
  final bool expanded;

  /// The row's place in the menu's roving tabindex.
  final FocusNode focusNode;

  /// Colours and brightness for the `light` tint.
  final KunThemeData theme;

  /// Called when the row is activated. A disabled row never calls it.
  final VoidCallback onActivate;

  /// Called when the pointer enters an enabled row, so the menu can move
  /// its active index.
  final VoidCallback onHover;

  @override
  State<KunMenuRow> createState() => _KunMenuRowState();
}

class _KunMenuRowState extends State<KunMenuRow> {
  bool _hovered = false;

  void _activate() {
    if (widget.disabled) {
      return;
    }
    widget.onActivate();
  }

  @override
  Widget build(BuildContext context) {
    final KunContextMenuItem item = widget.item;
    final KunVariantStyle style = KunVariantStyle.resolve(
      scheme: widget.theme.colors,
      brightness: widget.theme.brightness,
      variant: KunUIVariant.light,
      color: item.color,
    );
    // The web's `light` cell defines only `hover:`, so the menu adds a focus
    // tint of the same 20% — a row reached by the arrow keys has to look
    // exactly like one reached by the pointer. `aria-expanded` uses it too.
    final bool lit = !widget.disabled &&
        (_hovered || widget.focusNode.hasFocus || widget.expanded);
    final String? shortcut = item.shortcut;
    final String? hint = shortcut == null || shortcut.isEmpty
        ? null
        : kunSpeakShortcut(shortcut, KunMessagesScope.of(context));

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
            Icon(
              item.icon,
              size: KunText.base.fontSize,
              color: style.foreground,
            ),
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
          if (shortcut != null && shortcut.isNotEmpty) ...<Widget>[
            const SizedBox(width: KunSpacing.unit * 4),
            KunKbd(keys: shortcut, variant: KunKbdVariant.plain),
          ],
          if (widget.hasSubmenu) ...<Widget>[
            const SizedBox(width: KunSpacing.unit * 2),
            Transform.translate(
              offset: const Offset(-KunSpacing.unit, 0),
              child: Opacity(
                opacity: 0.6,
                child: Icon(
                  KunIcons.chevronRight,
                  size: KunText.base.fontSize,
                  color: style.foreground,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      role: SemanticsRole.menuItem,
      label: item.label,
      hint: hint,
      enabled: !widget.disabled,
      expanded: widget.hasSubmenu ? widget.expanded : null,
      onTap: widget.disabled ? null : _activate,
      child: ExcludeSemantics(
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (ActivateIntent intent) {
                _activate();
                return null;
              },
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (ButtonActivateIntent intent) {
                _activate();
                return null;
              },
            ),
          },
          child: Focus(
            focusNode: widget.focusNode,
            canRequestFocus: !widget.disabled,
            skipTraversal: true,
            onFocusChange: (_) => setState(() {}),
            child: MouseRegion(
              cursor: widget.disabled
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              onEnter: (_) {
                setState(() => _hovered = true);
                widget.onHover();
              },
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: widget.disabled ? null : _activate,
                child: Opacity(
                  opacity: widget.disabled ? 0.5 : 1,
                  child: row,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KunMenuSeparatorLine extends StatelessWidget {
  const _KunMenuSeparatorLine({
    required this.color,
    super.key,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: KunSpacing.unit * 2 + 1,
      child: CustomPaint(painter: _KunMenuSeparatorPainter(color: color)),
    );
  }
}

class _KunMenuSeparatorPainter extends CustomPainter {
  const _KunMenuSeparatorPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final double y = KunSpacing.unit + 0.5;
    canvas.drawLine(
      Offset(-KunSpacing.unit, y),
      Offset(size.width + KunSpacing.unit, y),
      paint,
    );
  }

  @override
  bool shouldRepaint(_KunMenuSeparatorPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _KunSubmenuAnchor extends StatefulWidget {
  const _KunSubmenuAnchor({
    required this.open,
    required this.focusOnOpen,
    required this.entries,
    required this.itemKeyPrefix,
    required this.theme,
    required this.minWidth,
    required this.tapGroup,
    required this.onSelect,
    required this.onClose,
    required this.onHoverOpen,
    required this.onHoverClose,
    required this.onBack,
    required this.onPanelRect,
    required this.enabled,
    required this.child,
  });

  final bool open;
  final bool focusOnOpen;
  final List<KunMenuEntry> entries;
  final String itemKeyPrefix;
  final KunThemeData theme;
  final double minWidth;
  final Object? tapGroup;
  final ValueChanged<KunContextMenuItem> onSelect;
  final void Function({required bool returnFocus}) onClose;
  final VoidCallback onHoverOpen;
  final VoidCallback onHoverClose;
  final VoidCallback onBack;
  final ValueChanged<Rect?> onPanelRect;
  final bool enabled;
  final Widget child;

  @override
  State<_KunSubmenuAnchor> createState() => _KunSubmenuAnchorState();
}

class _KunSubmenuAnchorState extends State<_KunSubmenuAnchor>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final GlobalKey _panelKey = GlobalKey();
  final GlobalKey<KunMenuListState> _listKey = GlobalKey<KunMenuListState>();
  final ValueNotifier<KunAnchorResolution> _resolved =
      ValueNotifier<KunAnchorResolution>(
    const KunAnchorResolution(side: KunAnchorSide.right, arrowCross: 0),
  );

  late final AnimationController _openClose;
  late final CurvedAnimation _curve;
  late final Animation<double> _scale;
  late final KunPointerMenu _pointer;
  Timer? _panelLeave;
  bool _isOpen = false;

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
    _pointer = KunPointerMenu(
      onOpen: widget.onHoverOpen,
      onClose: widget.onHoverClose,
      panelRect: _panelRect,
      openDelay: _kSubmenuOpenDelay,
      closeDelay: _kSubmenuGrace,
    );
    if (widget.open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.open) {
          _present();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _openClose.duration = kunMotion(context, KunDurations.base);
    _openClose.reverseDuration = kunMotion(context, KunDurations.exit);
  }

  @override
  void didUpdateWidget(_KunSubmenuAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      // OverlayPortal.show cannot run while the parent menu is rebuilding
      // inside overlayChildLayoutBuilder (persistentCallbacks).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (widget.open) {
          _present();
        } else {
          _dismiss();
        }
      });
    } else if (widget.open && widget.focusOnOpen && !oldWidget.focusOnOpen) {
      _focusSub();
    }
  }

  @override
  void dispose() {
    _panelLeave?.cancel();
    _pointer.dispose();
    _openClose.removeListener(_hidePortalIfDismissed);
    if (_portal.isShowing) {
      _portal.hide();
    }
    _openClose.dispose();
    _curve.dispose();
    _resolved.dispose();
    widget.onPanelRect(null);
    super.dispose();
  }

  Rect? _panelRect() {
    final RenderObject? ro = _panelKey.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) {
      return null;
    }
    final Rect rect = ro.localToGlobal(Offset.zero) & ro.size;
    widget.onPanelRect(rect);
    return rect;
  }

  void _hidePortalIfDismissed() {
    if (_isOpen || _openClose.value != 0 || !_portal.isShowing) {
      return;
    }
    _portal.hide();
  }

  void _present() {
    if (_isOpen) {
      if (widget.focusOnOpen) {
        _focusSub();
      }
      return;
    }
    _isOpen = true;
    if (!_portal.isShowing) {
      _portal.show();
    }
    _openClose.forward();
    _pointer.opened();
    if (widget.focusOnOpen) {
      _focusSub();
    }
    setState(() {});
  }

  void _dismiss() {
    if (!_isOpen) {
      return;
    }
    _isOpen = false;
    _panelLeave?.cancel();
    _openClose.reverse();
    _pointer.closed();
    widget.onPanelRect(null);
    setState(() {});
  }

  void _focusSub() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.open) {
        _listKey.currentState?.focusFirst();
      }
    });
  }

  void _clearPanelLeave() {
    _panelLeave?.cancel();
    _panelLeave = null;
  }

  Widget _buildSubmenu(BuildContext context, OverlayChildLayoutInfo info) {
    final KunColorScheme scheme = widget.theme.colors;
    final Rect anchor = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    ).shift(const Offset(0, _kSubmenuCrossOffset));

    final Widget panel = DecoratedBox(
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
            child: DefaultTextStyle.merge(
              style: KunText.sm.copyWith(color: scheme.foreground),
              child: KunMenuList(
                key: _listKey,
                entries: widget.entries,
                itemKeyPrefix: widget.itemKeyPrefix,
                theme: widget.theme,
                minWidth: widget.minWidth,
                tapGroup: widget.tapGroup,
                level: 1,
                onSelect: widget.onSelect,
                onClose: widget.onClose,
                onBack: widget.onBack,
              ),
            ),
          ),
        ),
      ),
    );

    return Positioned.fill(
      child: TapRegion(
        groupId: widget.tapGroup,
        child: CustomSingleChildLayout(
          delegate: KunAnchoredLayout(
            anchor: anchor,
            viewport: kunAnchorViewport(context, info.overlaySize),
            side: KunAnchorSide.right,
            align: KunAnchorAlign.start,
            offset: _kSubmenuMainOffset,
            minWidth: widget.minWidth,
            onResolved: (KunAnchorResolution next) {
              if (_resolved.value != next) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _resolved.value = next;
                  }
                });
              }
            },
          ),
          child: FadeTransition(
            opacity: _curve,
            child: ListenableBuilder(
              listenable: Listenable.merge(<Listenable>[_scale, _resolved]),
              builder: (BuildContext context, Widget? child) => Transform.scale(
                scale: _scale.value,
                alignment: kunAnchorOrigin(
                  _resolved.value.side,
                  KunAnchorAlign.start,
                ),
                child: child,
              ),
              child: MouseRegion(
                onEnter: (PointerEnterEvent event) {
                  if (!KunPointerMenu.handles(event)) {
                    return;
                  }
                  _clearPanelLeave();
                  _pointer.enterPanel();
                },
                onExit: (PointerExitEvent event) {
                  if (!KunPointerMenu.handles(event)) {
                    return;
                  }
                  _clearPanelLeave();
                  _panelLeave = Timer(_kSubmenuGrace, widget.onHoverClose);
                },
                child: KeyedSubtree(
                  key: ValueKey<String>('${widget.itemKeyPrefix}.submenu'),
                  child: panel,
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
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: _buildSubmenu,
      child: MouseRegion(
        onEnter: (PointerEnterEvent event) {
          if (!widget.enabled || !KunPointerMenu.handles(event)) {
            return;
          }
          _clearPanelLeave();
          _pointer.enterTrigger();
        },
        onExit: (PointerExitEvent event) {
          if (!KunPointerMenu.handles(event)) {
            return;
          }
          _pointer.leaveTrigger(event.position);
        },
        child: widget.child,
      ),
    );
  }
}
