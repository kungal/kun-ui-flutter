import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/design.dart';
import '../foundation/feedback.dart';
import '../foundation/focus_outline.dart';
import '../foundation/link_menu.dart';
import '../foundation/tap_target.dart';
import '../theme/theme.dart';
import 'context_menu.dart';

/// What a [KunPressable] is doing, handed to its builder.
@immutable
class KunPressableState {
  /// Creates a state.
  const KunPressableState({
    this.hovered = false,
    this.pressed = false,
    this.focused = false,
    this.disabled = false,
  });

  /// A mouse is over it. Never true for a touch, which does not hover.
  final bool hovered;

  /// A pointer is down on it.
  final bool pressed;

  /// It has keyboard focus: the CSS `:focus-visible` case, so a tap that
  /// focuses it does not set this.
  final bool focused;

  /// [KunPressable.disabled].
  final bool disabled;

  @override
  bool operator ==(Object other) =>
      other is KunPressableState &&
      other.hovered == hovered &&
      other.pressed == pressed &&
      other.focused == focused &&
      other.disabled == disabled;

  @override
  int get hashCode => Object.hash(hovered, pressed, focused, disabled);
}

/// What a browser gives every `<button>`, without a look of its own: for a
/// list row, a card or a tile the app draws itself.
///
/// The web needs no such component, because the element brings all of it:
/// the pointer cursor, `:hover`, keyboard focus with the `:focus-visible`
/// ring, Enter and Space, `contextmenu` on a right-click or Shift+F10, and a
/// button role, or a link role for an `<a>` ([link]). A Flutter
/// [GestureDetector] brings none of them. Not part of the web contract.
///
/// [builder] draws the content from a [KunPressableState], so the hover and
/// press looks come from the app's own tokens. The keyboard focus ring is
/// the only thing drawn here, KunUI's 2px outline at [rounded], hugging the
/// drawn content. On phones the content sits in a [KunTapTarget], so a
/// small pressable still meets the platform's minimum.
///
/// For a menu, open a [KunContextMenu] from [onSecondaryTap] on a desktop
/// and from [onLongPress] on a phone: both hand over the global position
/// the menu opens at.
class KunPressable extends StatefulWidget {
  /// Creates a pressable.
  const KunPressable({
    super.key,
    required this.builder,
    this.onTap,
    this.onSecondaryTap,
    this.onLongPress,
    this.disabled = false,
    this.link = false,
    this.linkUrl,
    this.selected,
    this.expanded,
    this.semanticLabel,
    this.rounded,
    this.focusNode,
    this.autofocus = false,
  });

  /// Draws the content for the current state.
  final Widget Function(BuildContext context, KunPressableState state) builder;

  /// Called on a tap, and on Enter or Space while focused (the web's
  /// `click`). A [link] takes Enter only.
  ///
  /// As with `KunButton`, null does not look disabled; it only does nothing.
  final VoidCallback? onTap;

  /// Called on a right-click with the pointer's global position, and on
  /// Shift+F10 or the Menu key with the centre of the pressable, as a
  /// browser fires `contextmenu`.
  ///
  /// On Flutter web the browser opens its own menu as well, unless the app
  /// calls `BrowserContextMenu.disableContextMenu()` once at startup. That
  /// switch is global, so it is the app's to flip.
  final ValueChanged<Offset>? onSecondaryTap;

  /// Called on a long press with the finger's global position. A screen
  /// reader's long-press action calls it with the centre.
  final ValueChanged<Offset>? onLongPress;

  /// Blocks every callback, takes it out of the focus order and reports it
  /// disabled. The look is the builder's, through
  /// [KunPressableState.disabled].
  final bool disabled;

  /// Makes it the web's `<a>` rather than a `<button>`: a screen reader
  /// announces a link, and Enter activates it but Space does not. In a
  /// browser, Space on a link scrolls the page.
  ///
  /// Where it goes stays in [onTap].
  ///
  /// Android's TalkBack announces a link only when the node carries a URL
  /// ([linkUrl]); without one it reads a button, as for any tappable node.
  final bool link;

  /// The web's `href`: where the link goes, for assistive technology. It
  /// makes the pressable a [link].
  ///
  /// TalkBack announces a link with it, and on Flutter web it becomes the
  /// `<a>` element's `href`, which the browser can open on its own (a middle
  /// click, "Open in new tab"). Pass the URL the app would show.
  final Uri? linkUrl;

  /// The web's `aria-selected` or `aria-pressed`: the chosen one of a set, or
  /// a toggle that is on. Null reports no selection state.
  final bool? selected;

  /// The web's `aria-expanded`, for a row that shows or hides a section.
  /// Null reports no expansion state.
  final bool? expanded;

  /// Accessible name. It replaces whatever the content would read, as
  /// `aria-label` does, nested controls included. Leave it null for a row
  /// whose text names it, or that holds controls of its own.
  final String? semanticLabel;

  /// Corner radius of the focus ring. Left null it follows
  /// [KunThemeData.rounded].
  final KunUIRounded? rounded;

  /// An external focus node.
  final FocusNode? focusNode;

  /// Whether it takes focus when first built.
  final bool autofocus;

  @override
  State<KunPressable> createState() => _KunPressableState();
}

class _KunContextMenuIntent extends Intent {
  const _KunContextMenuIntent();
}

class _KunLinkActivateIntent extends Intent {
  const _KunLinkActivateIntent();
}

// Bound only when [KunPressable.onSecondaryTap] is set. Bound always, they
// swallowed Shift+F10 before a wrapping [KunContextMenuRegion] saw it.
const Map<ShortcutActivator, Intent> _kMenuKeys = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.f10, shift: true): _KunContextMenuIntent(),
  SingleActivator(LogicalKeyboardKey.contextMenu): _KunContextMenuIntent(),
};

// A link takes Enter itself and leaves ActivateIntent unhandled, so Space
// falls through to the app's shortcuts (a page scroll on the web).
const Map<ShortcutActivator, Intent> _kLinkActivateKeys =
    <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.enter): _KunLinkActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): _KunLinkActivateIntent(),
};

class _KunPressableState extends State<KunPressable> {
  final GlobalKey<KunLinkMenuHostState> _linkMenu = GlobalKey();
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => !widget.disabled;

  bool get _isLink => widget.link || widget.linkUrl != null;

  bool get _linkMenuActive {
    final Uri? url = widget.linkUrl;
    return _enabled && url != null && kunLinkMenuClaims(context, url);
  }

  Offset _center() {
    final RenderBox box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  void _activate() {
    if (_enabled) {
      widget.onTap?.call();
    }
  }

  void _contextMenu(Offset position) {
    if (!_enabled) {
      return;
    }
    if (widget.onSecondaryTap != null) {
      widget.onSecondaryTap!(position);
      return;
    }
    _linkMenu.currentState?.openAt(position);
  }

  void _longPress(Offset position) {
    kunLongPressFeedback(context);
    if (widget.onLongPress != null) {
      widget.onLongPress!(position);
      return;
    }
    _linkMenu.currentState?.openAt(position);
  }

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  void didUpdateWidget(KunPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.disabled && (_hovered || _pressed)) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    final bool canTap = _enabled && widget.onTap != null;
    final bool canMenu =
        _enabled && (widget.onSecondaryTap != null || _linkMenuActive);
    final bool canLongPress =
        _enabled && (widget.onLongPress != null || _linkMenuActive);
    final KunPressableState state = KunPressableState(
      hovered: _hovered,
      pressed: _pressed,
      focused: _focused,
      disabled: widget.disabled,
    );

    Widget body = KunTapTarget(
      child: FocusableActionDetector(
        enabled: canTap || canMenu || canLongPress,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onShowFocusHighlight: (bool value) => setState(() => _focused = value),
        shortcuts: <ShortcutActivator, Intent>{
          if (_isLink) ..._kLinkActivateKeys,
          if (canMenu) ..._kMenuKeys,
        },
        actions: <Type, Action<Intent>>{
          if (_isLink)
            _KunLinkActivateIntent: CallbackAction<_KunLinkActivateIntent>(
              onInvoke: (_) {
                _activate();
                return null;
              },
            )
          else ...<Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _activate();
                return null;
              },
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (_) {
                _activate();
                return null;
              },
            ),
          },
          if (canMenu)
            _KunContextMenuIntent: CallbackAction<_KunContextMenuIntent>(
              onInvoke: (_) {
                _contextMenu(_center());
                return null;
              },
            ),
        },
        child: MouseRegion(
          cursor: widget.disabled
              ? SystemMouseCursors.forbidden
              : (canTap ? SystemMouseCursors.click : MouseCursor.defer),
          onEnter: (_) {
            if (_enabled) {
              setState(() => _hovered = true);
            }
          },
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: canTap ? (_) => _setPressed(true) : null,
            onTapUp: canTap ? (_) => _setPressed(false) : null,
            onTapCancel: canTap ? () => _setPressed(false) : null,
            onTap: canTap ? _activate : null,
            onSecondaryTapUp: canMenu
                ? (TapUpDetails details) => _contextMenu(details.globalPosition)
                : null,
            onLongPressStart: canLongPress
                ? (LongPressStartDetails details) {
                    _setPressed(false);
                    _longPress(details.globalPosition);
                  }
                : null,
            child: KunFocusOutline(
              visible: _focused,
              color: KunUIColor.primary
                  .scaleOf(theme.colors)
                  .solid
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(
                (widget.rounded ?? theme.rounded).radius,
              ),
              child: widget.builder(context, state),
            ),
          ),
        ),
      ),
    );
    final Uri? linkUrl = widget.linkUrl;
    if (linkUrl != null) {
      body = KunLinkMenuHost(
        key: _linkMenu,
        url: linkUrl,
        enabled: _enabled,
        capturePointers: false,
        captureKeys: false,
        child: body,
      );
    }

    return Semantics(
      container: true,
      button: !_isLink,
      link: _isLink,
      linkUrl: widget.linkUrl,
      selected: widget.selected,
      expanded: widget.expanded,
      enabled: _enabled,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      onTap: canTap ? _activate : null,
      onLongPress: canLongPress ? () => _longPress(_center()) : null,
      child: body,
    );
  }
}
