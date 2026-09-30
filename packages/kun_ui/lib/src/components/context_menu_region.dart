import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/feedback.dart';
import 'context_menu.dart';
import 'menu_panel.dart';

class _KunRegionMenuIntent extends Intent {
  const _KunRegionMenuIntent();
}

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

  /// The rows shown by the menu. An empty list never opens.
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
    return KunContextMenu(
      visible: _visible,
      items: widget.items,
      position: _position,
      onSelected: (KunContextMenuItem item) {
        widget.onSelected?.call(item);
      },
      onClose: _close,
      child: Semantics(
        key: const ValueKey<String>('KunContextMenuRegion'),
        container: true,
        explicitChildNodes: true,
        customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
          CustomSemanticsAction(label: widget.semanticActionLabel): () =>
              openAt(_regionCenter()),
        },
        child: Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.f10, shift: true):
                _KunRegionMenuIntent(),
            SingleActivator(LogicalKeyboardKey.contextMenu):
                _KunRegionMenuIntent(),
          },
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
              onSecondaryTapUp: (TapUpDetails details) =>
                  openAt(details.globalPosition),
              onLongPressStart: widget.longPress
                  ? (LongPressStartDetails details) =>
                      _openFromLongPress(details.globalPosition)
                  : null,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
