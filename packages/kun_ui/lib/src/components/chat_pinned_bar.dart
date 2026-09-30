import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../chat/support.dart';
import '../chat/types.dart';
import '../foundation/motion.dart';
import '../foundation/tap_target.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'chat_bubble.dart';
import 'chat_text.dart';
import 'image.dart';

/// Web `ChatPinnedBar.vue:53` — at most four sliding segments.
const int _kSegments = 4;

/// Web `h-12`.
const double _kBarHeight = KunSpacing.unit * 12;

/// Web `h-8` / `size-8`.
const double _kThumb = KunSpacing.unit * 8;

/// Web `w-0.5`.
const double _kRailWidth = KunSpacing.unit * 0.5;

/// Web `size-9`.
const double _kUnpinSize = KunSpacing.unit * 9;

/// Web `bg-default/10` on the jump control.
const double _kJumpHover = 0.1;

/// Web `bg-default/20` on the ×.
const double _kUnpinHover = 0.2;

/// Web `bg-primary/30` on an inactive segment.
const double _kRailOff = 0.3;

/// The pinned-message bar on top of a conversation.
///
/// With several pins it starts at the newest. A tap jumps to the one shown
/// and moves the bar to the next older one, wrapping around. The shown
/// message is tracked by seq, so adding a newer pin does not switch away
/// from it (the web tracks a position and would).
class KunChatPinnedBar extends StatefulWidget {
  /// Creates a pinned-message bar.
  const KunChatPinnedBar({
    super.key,
    required this.messages,
    this.resolveMediaUrl,
    this.unpinnable = false,
    this.actions,
    this.onJump,
    this.onUnpin,
  });

  /// Pinned messages, in any order. The bar starts at the newest.
  final List<KunChatMessage> messages;

  /// Turns a pinned photo into a URL for the thumbnail. Without it the
  /// thumbnail uses [KunChatPhoto.url], and a photo with neither has none.
  final KunChatMediaUrlResolver? resolveMediaUrl;

  /// Show the × that emits [onUnpin].
  final bool unpinnable;

  /// Extra buttons on the right, e.g. "all pinned messages".
  final Widget? actions;

  /// Scroll the conversation to this message (`scrollToSeq`).
  final ValueChanged<int>? onJump;

  /// The × was clicked for the message shown.
  final ValueChanged<int>? onUnpin;

  @override
  State<KunChatPinnedBar> createState() => _KunChatPinnedBarState();
}

class _KunChatPinnedBarState extends State<KunChatPinnedBar> {
  int? _shownSeq;
  int _index = 0;

  List<KunChatMessage> _stackOf(List<KunChatMessage> messages) {
    final List<KunChatMessage> stack = List<KunChatMessage>.of(messages);
    stack.sort((KunChatMessage a, KunChatMessage b) => b.seq.compareTo(a.seq));
    return stack;
  }

  void _sync(List<KunChatMessage> stack) {
    if (stack.isEmpty) {
      _shownSeq = null;
      _index = 0;
      return;
    }
    if (_shownSeq != null) {
      final int found = stack.indexWhere(
        (KunChatMessage m) => m.seq == _shownSeq,
      );
      if (found >= 0) {
        _index = found;
        return;
      }
    }
    _index = _index.clamp(0, stack.length - 1);
    _shownSeq = stack[_index].seq;
  }

  @override
  void initState() {
    super.initState();
    _sync(_stackOf(widget.messages));
  }

  @override
  void didUpdateWidget(KunChatPinnedBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(_stackOf(widget.messages));
  }

  void _onJump(List<KunChatMessage> stack) {
    final KunChatMessage? current =
        _index < stack.length ? stack[_index] : null;
    if (current == null) {
      return;
    }
    widget.onJump?.call(current.seq);
    if (stack.length > 1) {
      setState(() {
        _index = (_index + 1) % stack.length;
        _shownSeq = stack[_index].seq;
      });
    }
  }

  List<bool> _segments(int n) {
    if (n <= 1) {
      return const <bool>[];
    }
    final int count = n < _kSegments ? n : _kSegments;
    final int position = n - 1 - _index;
    final int first = (position - (count - 1)).clamp(0, n - count);
    return <bool>[for (int i = 0; i < count; i++) first + i == position];
  }

  @override
  Widget build(BuildContext context) {
    final List<KunChatMessage> stack = _stackOf(widget.messages);
    if (stack.isEmpty) {
      return const SizedBox.shrink();
    }
    final KunChatMessage current = stack[_index];
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final KunMessages messages = KunMessagesScope.of(context);
    final List<bool> segments = _segments(stack.length);
    final String title = stack.length > 1
        ? messages.chatPinned.indexed(index: stack.length - _index)
        : messages.chatPinned.label;
    final String preview = current.text.isNotEmpty
        ? kunChatPlainText(current, messages)
        : kunChatMediaLabel(current.media, messages);
    final KunChatMedia? media = current.media;
    final String? thumb = media is KunChatPhoto
        ? widget.resolveMediaUrl?.call(media, KunChatMediaVariant.preview) ??
            media.url
        : null;
    final String jumpLabel = preview.isEmpty ? title : '$title, $preview';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.content1,
        border: Border(
          bottom: BorderSide(
            color: scheme.neutral.solid.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SizedBox(
        height: _kBarHeight,
        child: Row(
          children: <Widget>[
            Expanded(
              child: _HoverFill(
                label: jumpLabel,
                hover: scheme.neutral.solid.withValues(alpha: _kJumpHover),
                onTap: () => _onJump(stack),
                child: Padding(
                  padding: const EdgeInsets.only(left: KunSpacing.unit * 3),
                  child: Row(
                    children: <Widget>[
                      _Rail(
                        segments: segments,
                        on: scheme.primary.solid,
                        off: scheme.primary.solid.withValues(alpha: _kRailOff),
                      ),
                      const SizedBox(width: KunSpacing.unit * 2.5),
                      if (thumb != null && thumb.isNotEmpty) ...<Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(KunRadius.sm),
                          child: KunImage(
                            src: thumb,
                            alt: '',
                            width: _kThumb,
                            height: _kThumb,
                            fit: BoxFit.cover,
                            skeleton: false,
                          ),
                        ),
                        const SizedBox(width: KunSpacing.unit * 2.5),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KunText.sm.copyWith(
                                color: scheme.primary.solid,
                                fontWeight: KunFontWeights.semibold,
                              ),
                            ),
                            DefaultTextStyle.merge(
                              style: KunText.sm.copyWith(
                                color: scheme.neutral.shade600,
                              ),
                              child: current.text.isNotEmpty
                                  ? KunChatText(
                                      text: current.text,
                                      entities: current.entities,
                                      preview: true,
                                    )
                                  : Text(
                                      kunChatMediaLabel(
                                        current.media,
                                        messages,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.actions != null) widget.actions!,
            if (widget.unpinnable)
              _IconTap(
                label: messages.chatPinned.unpin,
                size: _kUnpinSize,
                color: scheme.neutral.shade500,
                hoverColor: scheme.foreground,
                hoverFill: scheme.neutral.solid.withValues(alpha: _kUnpinHover),
                icon: KunIcons.x,
                iconSize: KunText.base.fontSize,
                onTap: () => widget.onUnpin?.call(current.seq),
              ),
            const SizedBox(width: KunSpacing.unit),
          ],
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.segments, required this.on, required this.off});

  final List<bool> segments;
  final Color on;
  final Color off;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: _kRailWidth,
        height: _kThumb,
        child: segments.isEmpty
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: on,
                  borderRadius: BorderRadius.circular(KunRadius.full),
                ),
              )
            : Column(
                children: <Widget>[
                  for (int i = 0; i < segments.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: KunSpacing.unit * 0.5),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: segments[i] ? on : off,
                          borderRadius: BorderRadius.circular(KunRadius.full),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _HoverFill extends StatefulWidget {
  const _HoverFill({
    required this.label,
    required this.hover,
    required this.onTap,
    required this.child,
  });

  final String label;
  final Color hover;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_HoverFill> createState() => _HoverFillState();
}

class _HoverFillState extends State<_HoverFill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: kunMotion(context, KunDurations.base),
              curve: KunEasing.enter,
              color:
                  _hovered ? widget.hover : widget.hover.withValues(alpha: 0),
              alignment: Alignment.centerLeft,
              child: SizedBox(height: _kBarHeight, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconTap extends StatefulWidget {
  const _IconTap({
    required this.label,
    required this.size,
    required this.color,
    required this.hoverColor,
    required this.hoverFill,
    required this.icon,
    required this.iconSize,
    required this.onTap,
  });

  final String label;
  final double size;
  final Color color;
  final Color hoverColor;
  final Color hoverFill;
  final IconData icon;
  final double? iconSize;
  final VoidCallback onTap;

  @override
  State<_IconTap> createState() => _IconTapState();
}

class _IconTapState extends State<_IconTap> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: KunTapTarget(
        child: FocusableActionDetector(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: kunMotion(context, KunDurations.base),
                curve: KunEasing.enter,
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: _hovered
                      ? widget.hoverFill
                      : widget.hoverFill.withValues(alpha: 0),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: _hovered ? widget.hoverColor : widget.color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
