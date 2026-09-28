import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../theme/theme.dart';

/// Web `sidebarWidth` default `22rem`.
const double _kSidebarWidth = 352;

/// Two panes from `md` up — conversation list beside the open conversation —
/// and one at a time below it, switched by [showConversation].
///
/// The sidebar and [child] stay in the tree when a phone switches panes, so
/// the list's scroll position survives. Hidden panes use [Offstage] plus
/// [TickerMode].
class KunChatLayout extends StatelessWidget {
  /// Creates a chat shell.
  const KunChatLayout({
    super.key,
    this.showConversation = false,
    this.sidebarWidth = _kSidebarWidth,
    this.child,
    this.empty,
    this.sidebar,
    this.onBack,
  });

  /// Which pane a narrow screen shows: the conversation, or the list. From
  /// `md` up both panes show.
  final bool showConversation;

  /// Width of the list pane from `md` up, in logical pixels. The web default
  /// is `22rem` (352). Not part of the web contract: upstream lists
  /// `sidebarWidth` as web-only ("the capability crosses as a plain double
  /// in the Flutter layout").
  final double sidebarWidth;

  /// The open conversation (web default slot).
  final Widget? child;

  /// What the right pane shows with no conversation open, from `md` up.
  final Widget? empty;

  /// The conversation list.
  final Widget? sidebar;

  /// When non-null, and the layout is narrow and showing the conversation,
  /// a [PopScope] with `canPop: false` calls this on a pop. The Android
  /// system back then returns from the conversation to the list. Everywhere
  /// else it does nothing. Not part of the web contract.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final bool narrow =
        MediaQuery.sizeOf(context).width < KunTheme.of(context).breakpoints.md;
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final Widget sidebarPane = sidebar ?? const SizedBox.shrink();
    final Widget conversation = child ?? const SizedBox.shrink();
    final Widget emptyPane = empty ?? const SizedBox.shrink();

    late final Widget body;
    if (narrow) {
      body = Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _KeepAlive(visible: !showConversation, child: sidebarPane),
          _KeepAlive(visible: showConversation, child: conversation),
        ],
      );
    } else {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: sidebarWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: scheme.neutral.solid.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: sidebarPane,
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _KeepAlive(visible: showConversation, child: conversation),
                _KeepAlive(visible: !showConversation, child: emptyPane),
              ],
            ),
          ),
        ],
      );
    }

    final Widget clipped = ClipRect(child: body);
    if (onBack != null && narrow && showConversation) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (!didPop) {
            onBack!();
          }
        },
        child: clipped,
      );
    }
    return clipped;
  }
}

class _KeepAlive extends StatelessWidget {
  const _KeepAlive({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !visible,
      child: TickerMode(enabled: visible, child: child),
    );
  }
}
