import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../foundation/variant_style.dart';
import '../theme/theme.dart';

/// One row of a [KunContextMenu] or a [KunDropdown].
///
/// The same model the web shares between its context menu and its dropdown,
/// with the icon as [IconData] rather than an Iconify name: `kun_ui_icons`
/// carries only the glyphs the components themselves draw, so a menu's icons
/// come from the app's own set.
@immutable
class KunContextMenuItem {
  /// Creates an item.
  const KunContextMenuItem({
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
      other is KunContextMenuItem &&
      other.key == key &&
      other.label == label &&
      other.icon == icon &&
      other.color == color &&
      other.disabled == disabled &&
      other.href == href;

  @override
  int get hashCode => Object.hash(key, label, icon, color, disabled, href);
}

/// The dropdown reuses the context menu's item model, as on the web.
typedef KunDropdownItem = KunContextMenuItem;

/// Indices of the rows that keyboard navigation may land on.
List<int> kunMenuEnabledIndices(List<KunContextMenuItem> items) => <int>[
      for (int i = 0; i < items.length; i++)
        if (!items[i].disabled) i,
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
    super.key,
  });

  /// The model this row draws.
  final KunContextMenuItem item;

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
    if (widget.item.disabled) {
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
        ],
      ),
    );

    return Semantics(
      role: SemanticsRole.menuItem,
      label: item.label,
      enabled: !item.disabled,
      onTap: item.disabled ? null : _activate,
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
                excludeFromSemantics: true,
                onTap: item.disabled ? null : _activate,
                child: Opacity(opacity: item.disabled ? 0.5 : 1, child: row),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
