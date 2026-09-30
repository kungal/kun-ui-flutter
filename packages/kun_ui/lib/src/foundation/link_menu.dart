import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../components/context_menu.dart';
import '../components/menu_panel.dart';
import '../config/config.dart';
import 'feedback.dart';

class _KunLinkMenuIntent extends Intent {
  const _KunLinkMenuIntent();
}

const Map<ShortcutActivator, Intent> _kLinkMenuKeys =
    <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.f10, shift: true): _KunLinkMenuIntent(),
  SingleActivator(LogicalKeyboardKey.contextMenu): _KunLinkMenuIntent(),
};

/// [href] as a [Uri], or null when it is empty or does not parse.
Uri? kunLinkUri(String? href) =>
    href == null || href.isEmpty ? null : Uri.tryParse(href);

/// Whether [url] currently has a non-empty [KunUIConfig.linkMenu] off Flutter
/// web, where the browser keeps its own menu.
bool kunLinkMenuClaims(BuildContext context, Uri url) {
  if (kIsWeb) {
    return false;
  }
  final KunLinkMenu? menu = KunUIConfigScope.of(context).linkMenu;
  if (menu == null) {
    return false;
  }
  return menu.items(url).isNotEmpty;
}

/// Hosts a [KunContextMenu] for one link.
///
/// Mounted while the widget is a link. [capturePointers] and [captureKeys]
/// stay what the wrapping widget passed; only the callbacks go null when
/// [kunLinkMenuClaims] is false, [enabled] is false, or [items] is empty.
class KunLinkMenuHost extends StatefulWidget {
  /// Creates a host around [child] for [url].
  const KunLinkMenuHost({
    required this.url,
    required this.child,
    this.enabled = true,
    this.capturePointers = true,
    this.captureKeys = true,
    super.key,
  });

  /// The link this menu is for. Null claims nothing.
  final Uri? url;

  /// The link widget.
  final Widget child;

  /// When false, the host claims nothing.
  final bool enabled;

  /// When true, a right-click and a long press on [child] open the menu.
  final bool capturePointers;

  /// When true, Shift+F10 and the Menu key open the menu at [child]'s
  /// centre while a descendant has focus.
  final bool captureKeys;

  /// The host above [context], if any.
  static KunLinkMenuHostState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_KunLinkMenuScope>()
        ?.state;
  }

  /// The host above [context].
  static KunLinkMenuHostState of(BuildContext context) {
    final KunLinkMenuHostState? state = maybeOf(context);
    assert(state != null, 'KunLinkMenuHost.of called with no host above');
    return state!;
  }

  @override
  State<KunLinkMenuHost> createState() => KunLinkMenuHostState();
}

/// The state of a [KunLinkMenuHost].
class KunLinkMenuHostState extends State<KunLinkMenuHost> {
  bool _visible = false;
  Offset _position = Offset.zero;
  List<KunMenuEntry> _items = const <KunMenuEntry>[];

  /// Whether this host currently claims gestures, keys and semantics.
  bool get isActive {
    final Uri? url = widget.url;
    return widget.enabled && url != null && kunLinkMenuClaims(context, url);
  }

  /// Global centre of the host.
  Offset center() {
    final RenderObject? ro = context.findRenderObject();
    if (ro is RenderBox && ro.hasSize) {
      return ro.localToGlobal(ro.size.center(Offset.zero));
    }
    return Offset.zero;
  }

  /// Opens the menu at [globalPosition], or does nothing when inactive.
  void openAt(Offset globalPosition) {
    if (!isActive) {
      return;
    }
    final List<KunMenuEntry> items =
        KunUIConfigScope.of(context).linkMenu!.items(widget.url!);
    if (items.isEmpty) {
      return;
    }
    setState(() {
      _items = items;
      _position = globalPosition;
      _visible = true;
    });
  }

  /// Long-press feedback, then [openAt] at the pointer.
  void openFromLongPress(Offset globalPosition) {
    kunLongPressFeedback(context);
    openAt(globalPosition);
  }

  /// Long-press feedback, then [openAt] at [center].
  void openFromLongPressAtCenter() {
    kunLongPressFeedback(context);
    openAt(center());
  }

  void _close() {
    if (!_visible) {
      return;
    }
    setState(() => _visible = false);
  }

  void _select(KunContextMenuItem item) {
    final Uri? url = widget.url;
    if (url != null) {
      KunUIConfigScope.of(context).linkMenu?.onSelected(item, url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool active = isActive;
    Widget child = widget.child;
    if (widget.captureKeys) {
      child = Shortcuts(
        includeSemantics: false,
        shortcuts:
            active ? _kLinkMenuKeys : const <ShortcutActivator, Intent>{},
        child: Actions(
          actions: <Type, Action<Intent>>{
            _KunLinkMenuIntent: CallbackAction<_KunLinkMenuIntent>(
              onInvoke: (_) {
                openAt(center());
                return null;
              },
            ),
          },
          child: child,
        ),
      );
    }
    if (widget.capturePointers) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onSecondaryTapUp: active
            ? (TapUpDetails details) => openAt(details.globalPosition)
            : null,
        onLongPressStart: active
            ? (LongPressStartDetails details) =>
                openFromLongPress(details.globalPosition)
            : null,
        child: child,
      );
    }
    return _KunLinkMenuScope(
      state: this,
      child: KunContextMenu(
        visible: _visible,
        items: _items,
        position: _position,
        onSelected: _select,
        onClose: _close,
        child: child,
      ),
    );
  }
}

class _KunLinkMenuScope extends InheritedWidget {
  const _KunLinkMenuScope({required this.state, required super.child});

  final KunLinkMenuHostState state;

  @override
  bool updateShouldNotify(_KunLinkMenuScope oldWidget) => false;
}
