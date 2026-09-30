import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../theme/theme.dart';
import 'split_pane.dart';

/// Web `sidebarWidth` default `22rem`.
const double _kSidebarWidth = 352;

/// Two panes from `md` up — conversation list beside the open conversation —
/// and one at a time below it, switched by [showConversation].
///
/// `md` is measured on the width the layout is given, not the window's: the
/// web's `md:` is a viewport query, and a chat opened beside an app's side
/// rail took the two-pane layout at a 768 window with 679 to fill, leaving
/// the conversation 327. Read the decision with [narrowOf].
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
    this.resizable = false,
    this.sidebarSize = _kSidebarWidth,
    this.onSidebarSizeChanged,
    this.sidebarMinSize = 280,
    this.sidebarMaxSize = 480,
    this.onSidebarResizeEnd,
    this.child,
    this.empty,
    this.sidebar,
    this.onBack,
  });

  /// Which pane a narrow screen shows: the conversation, or the list. From
  /// `md` up both panes show.
  final bool showConversation;

  /// Width of the list pane from `md` up, in logical pixels, when
  /// [resizable] is false. The web default is `22rem` (352). Not part of
  /// the web contract: upstream lists `sidebarWidth` as web-only ("the
  /// capability crosses as a plain double in the Flutter layout").
  final double sidebarWidth;

  /// Let the reader drag the divider between the list and the conversation
  /// (or move it with the arrow keys), through [KunSplitPane].
  final bool resizable;

  /// Width of the list pane in px while [resizable]. Persist it from
  /// [onSidebarResizeEnd]. A new value from the parent, different from the
  /// previous widget's, replaces the internal width.
  final double sidebarSize;

  /// Called on every pointer move while dragging the list divider, and on
  /// each key press that changes the width. The web's `update:sidebarSize`.
  final ValueChanged<double>? onSidebarSizeChanged;

  /// Narrowest the list can be dragged, in px. Only with [resizable].
  final double sidebarMinSize;

  /// Widest the list can be dragged, in px. Only with [resizable].
  final double sidebarMaxSize;

  /// A drag or a key press on the divider finished with this list width.
  final ValueChanged<double>? onSidebarResizeEnd;

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

  /// Whether the nearest [KunChatLayout] shows one pane at a time: the width
  /// it was given is below the theme's `md` breakpoint. Null outside a chat
  /// layout.
  ///
  /// [KunChatHeader]'s [KunChatHeaderBack.mobile] follows it, and so should an
  /// app's own pane logic, so the two never disagree. Not part of the web
  /// contract.
  static bool? narrowOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_KunChatLayoutScope>()?.narrow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final bool narrow = width < KunTheme.of(context).breakpoints.md;
        return _KunChatLayoutScope(
          narrow: narrow,
          child: resizable
              ? _buildResizable(context, narrow)
              : _buildPanes(context, narrow),
        );
      },
    );
  }

  Widget _buildPanes(BuildContext context, bool narrow) {
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

    return _backScope(narrow, ClipRect(child: body));
  }

  Widget _buildResizable(BuildContext context, bool narrow) {
    final Widget sidebarPane = sidebar ?? const SizedBox.shrink();
    final Widget conversation = child ?? const SizedBox.shrink();
    final Widget emptyPane = empty ?? const SizedBox.shrink();
    final Widget body = KunSplitPane(
      size: sidebarSize,
      onSizeChanged: onSidebarSizeChanged,
      onResizeEnd: onSidebarResizeEnd,
      minSize: sidebarMinSize,
      maxSize: sidebarMaxSize,
      stackBelow: KunSplitStackBelow.md,
      showPane: showConversation ? KunSplitSide.end : KunSplitSide.start,
      start: sidebarPane,
      end: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _KeepAlive(visible: showConversation, child: conversation),
          _KeepAlive(visible: !showConversation, child: emptyPane),
        ],
      ),
    );
    return _backScope(narrow, ClipRect(child: body));
  }

  // The scope stays in the tree at every width. Added only while narrow, it
  // remounted the body on every md crossing: KunSplitPane's LayoutBuilder
  // then rebuilt the app's GlobalKey panes during layout, which tripped the
  // semantics geometry assertion, and unkeyed pane state was lost.
  Widget _backScope(bool narrow, Widget child) {
    final VoidCallback? back = onBack;
    final bool intercepts = back != null && narrow && showConversation;
    return PopScope(
      canPop: !intercepts,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && intercepts) {
          back();
        }
      },
      child: child,
    );
  }
}

class _KunChatLayoutScope extends InheritedWidget {
  const _KunChatLayoutScope({required this.narrow, required super.child});

  final bool narrow;

  @override
  bool updateShouldNotify(_KunChatLayoutScope oldWidget) =>
      narrow != oldWidget.narrow;
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
