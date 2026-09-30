import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/feedback.dart';
import 'context_menu.dart';
import 'menu_panel.dart';

class _KunRegionMenuIntent extends Intent {
  const _KunRegionMenuIntent();
}

const Map<ShortcutActivator, Intent> _kRegionKeys = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.f10, shift: true): _KunRegionMenuIntent(),
  SingleActivator(LogicalKeyboardKey.contextMenu): _KunRegionMenuIntent(),
};

/// A region that opens a [KunContextMenu] on a right-click, a long press, or
/// Shift+F10 / the Menu key, without turning its contents into one button.
///
/// Reply cards and comments hold buttons and selectable text; wrapping them
/// in [KunPressable] would give the whole card a button role and a Tab stop.
/// This widget takes no primary taps, so inner buttons and links keep theirs,
/// and it adds one semantics node of its own with a custom action rather
/// than a tap.
class KunContextMenuRegion extends StatefulWidget {
  /// Creates a context-menu region around [child].
  const KunContextMenuRegion({
    super.key,
    required this.child,
    required this.items,
    required this.semanticActionLabel,
    this.onSelected,
    this.longPress = true,
  });

  /// The subtree that owns the menu. Not collapsed into one semantics node.
  final Widget child;

  /// The rows shown by the menu.
  ///
  /// An empty list never opens, and the region then claims nothing: no
  /// custom semantics action, no long press (so no haptic, and an ancestor's
  /// long press still wins), no right-click, no Shift+F10. The subtree keeps
  /// its place, so commands that appear later do not remount [child].
  final List<KunMenuEntry> items;

  /// The custom semantics action that opens the menu, for a screen reader's
  /// actions menu. Not a button name; the region has no tap action.
  final String semanticActionLabel;

  /// Called with the row the user activated. A disabled row never calls it.
  final ValueChanged<KunContextMenuItem>? onSelected;

  /// Whether a long press also opens the menu. A right-click always does.
  final bool longPress;

  @override
  State<KunContextMenuRegion> createState() => KunContextMenuRegionState();
}

/// The state of a [KunContextMenuRegion]; reach it with a
/// `GlobalKey<KunContextMenuRegionState>` to call [openAt].
class KunContextMenuRegionState extends State<KunContextMenuRegion> {
  final GlobalKey _hitKey = GlobalKey();

  bool _visible = false;
  Offset _position = Offset.zero;

  /// Opens the menu at [globalPosition], or moves it there when open.
  void openAt(Offset globalPosition) {
    if (widget.items.isEmpty) {
      return;
    }
    setState(() {
      _position = globalPosition;
      _visible = true;
    });
  }

  void _close() {
    if (!_visible) {
      return;
    }
    setState(() => _visible = false);
  }

  Offset? _centerOf(BuildContext? ctx) {
    final RenderObject? ro = ctx?.findRenderObject();
    if (ro is RenderBox && ro.hasSize) {
      return ro.localToGlobal(ro.size.center(Offset.zero));
    }
    return null;
  }

  Offset _regionCenter() => _centerOf(_hitKey.currentContext) ?? Offset.zero;

  Offset _focusedCenter() =>
      _centerOf(FocusManager.instance.primaryFocus?.context) ?? _regionCenter();

  void _openFromLongPress(Offset globalPosition) {
    kunLongPressFeedback(context);
    openAt(globalPosition);
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.items.isNotEmpty;
    return KunContextMenu(
      visible: _visible,
      items: widget.items,
      position: _position,
      onSelected: (KunContextMenuItem item) {
        widget.onSelected?.call(item);
      },
      onClose: _close,
      child: Shortcuts(
        shortcuts: active ? _kRegionKeys : const <ShortcutActivator, Intent>{},
        child: Actions(
          actions: <Type, Action<Intent>>{
            _KunRegionMenuIntent: CallbackAction<_KunRegionMenuIntent>(
              onInvoke: (_) {
                openAt(_focusedCenter());
                return null;
              },
            ),
          },
          child: GestureDetector(
            key: _hitKey,
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onSecondaryTapUp: active
                ? (TapUpDetails details) => openAt(details.globalPosition)
                : null,
            onLongPressStart: active && widget.longPress
                ? (LongPressStartDetails details) =>
                    _openFromLongPress(details.globalPosition)
                : null,
            // Directly around the child: with Shortcuts inside it, the
            // Focus that Shortcuts builds became a node of its own under
            // explicitChildNodes, and every plain Text below merged into
            // that node's label (a Pixel dump read the author row and the
            // first paragraph as one stop).
            child: Semantics(
              key: const ValueKey<String>('KunContextMenuRegion'),
              container: true,
              explicitChildNodes: true,
              customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
                if (active)
                  CustomSemanticsAction(label: widget.semanticActionLabel):
                      () => openAt(_regionCenter()),
              },
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
