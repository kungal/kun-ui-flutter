import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../chat/constants.dart';
import '../chat/support.dart';
import '../chat/types.dart';
import '../foundation/design.dart';
import '../foundation/motion.dart';
import '../foundation/variant_style.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'avatar.dart';
import 'chat_shared.dart';
import 'chat_text.dart';
import 'chat_typing.dart';

/// Web `ChatConversationItem.vue:107` — each swipe action is 72 px wide.
const double _kActionWidth = 72;

/// Web `ChatConversationItem.vue:108` — axis lock before a swipe commits.
const double _kAxisLock = 12;

/// A swipe or menu action on a conversation row, e.g. archive or mute.
@immutable
class KunChatSwipeAction {
  /// Creates a swipe action.
  const KunChatSwipeAction({
    required this.key,
    required this.label,
    this.icon,
    this.color,
  });

  /// Identifies the action to [KunChatConversationItem.onAction].
  final String key;

  /// Shown on the action button and as the TalkBack custom action name.
  final String label;

  /// Drawn above [label]. An [IconData] rather than an Iconify name, as
  /// [KunDropdownItem] does.
  final IconData? icon;

  /// Solid fill. Null uses the web fallback: primary on leading actions,
  /// the default (neutral) colour on trailing actions.
  final KunUIColor? color;

  @override
  bool operator ==(Object other) =>
      other is KunChatSwipeAction &&
      other.key == key &&
      other.label == label &&
      other.icon == icon &&
      other.color == color;

  @override
  int get hashCode => Object.hash(key, label, icon, color);
}

/// One row of the conversation list: avatar, title, time, and a preview
/// line that shows — in this order of precedence — who is typing, the
/// draft, or the last message.
///
/// On a touch screen the row slides to uncover [leadingActions] and
/// [trailingActions]. Mouse drags do nothing. Every action is also a
/// [CustomSemanticsAction] on the row, so TalkBack's actions menu can fire
/// them without a swipe.
class KunChatConversationItem extends StatefulWidget {
  /// Creates a conversation row.
  const KunChatConversationItem({
    super.key,
    this.avatar,
    this.currentUserId,
    this.draft,
    this.kind = KunChatKind.direct,
    this.lastMessage,
    this.lastMessageSender,
    this.leadingActions = const <KunChatSwipeAction>[],
    this.trailingActions = const <KunChatSwipeAction>[],
    this.markedUnread = false,
    this.mentionCount = 0,
    this.muted = false,
    this.pinned = false,
    this.selected = false,
    this.status,
    this.time,
    this.title,
    this.typing = const <KunChatTypingEvent>[],
    this.unreadCount = 0,
    this.user,
    this.users = const <KunChatUser>[],
    this.onTap,
    this.onAction,
  });

  /// Avatar URL, e.g. a group photo. Defaults to [user]'s.
  final String? avatar;

  /// The viewer's id, so a service message can say "you".
  final String? currentUserId;

  /// An unsent draft replaces the preview with "Draft: …".
  final KunChatFormattedText? draft;

  /// A group prefixes the preview with its sender and names who is typing;
  /// a direct chat does neither.
  final KunChatKind kind;

  /// The newest message, previewed on the second line.
  final KunChatMessage? lastMessage;

  /// Who sent [lastMessage], as the preview prefix.
  final String? lastMessageSender;

  /// Revealed by swiping right on a touch screen.
  final List<KunChatSwipeAction> leadingActions;

  /// Revealed by swiping left on a touch screen.
  final List<KunChatSwipeAction> trailingActions;

  /// "Mark as unread" was used: a badge with no number.
  final bool markedUnread;

  /// Unread mentions: an @ badge.
  final int mentionCount;

  /// A muted conversation's badge is grey.
  final bool muted;

  /// A pin icon where the badge would be, when there is no unread badge.
  final bool pinned;

  /// The open conversation.
  final bool selected;

  /// Delivery state of [lastMessage] when the viewer sent it.
  final KunChatSendStatus? status;

  /// Defaults to [lastMessage.createdAt].
  final DateTime? time;

  /// Row title. Defaults to [user]'s name.
  final String? title;

  /// Typing notifications; while one is live it replaces the preview.
  final List<KunChatTypingEvent> typing;

  /// Unread messages; the badge caps at 999+.
  final int unreadCount;

  /// The other person of a direct chat: title, avatar and deleted state.
  final KunChatUser? user;

  /// Users, to name who is typing in a group and who acted in a service
  /// message.
  final List<KunChatUser> users;

  /// The row was activated (web `click`).
  final VoidCallback? onTap;

  /// A swipe action was chosen (web `action`).
  final ValueChanged<String>? onAction;

  @override
  State<KunChatConversationItem> createState() =>
      _KunChatConversationItemState();
}

class _KunChatConversationItemState extends State<KunChatConversationItem>
    with TickerProviderStateMixin {
  double _offset = 0;
  bool _dragging = false;
  bool _hovered = false;
  bool _swallowClick = false;
  DateTime _now = DateTime.now();
  Timer? _typingTimer;
  AnimationController? _spring;

  double get _leadingW => widget.leadingActions.length * _kActionWidth;

  double get _trailingW => widget.trailingActions.length * _kActionWidth;

  bool get _typingActive {
    for (final KunChatTypingEvent event in widget.typing) {
      if (_now.difference(event.at) < kunChatTypingTimeout) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _scheduleTyping();
  }

  @override
  void didUpdateWidget(KunChatConversationItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.typing, widget.typing)) {
      _now = DateTime.now();
      _scheduleTyping();
    }
    if (oldWidget.leadingActions.length != widget.leadingActions.length ||
        oldWidget.trailingActions.length != widget.trailingActions.length) {
      _offset = _offset.clamp(-_trailingW, _leadingW);
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _spring?.dispose();
    _spring = null;
    super.dispose();
  }

  void _scheduleTyping() {
    _typingTimer?.cancel();
    _typingTimer = null;
    DateTime? soonest;
    for (final KunChatTypingEvent event in widget.typing) {
      if (_now.difference(event.at) < kunChatTypingTimeout) {
        if (soonest == null || event.at.isBefore(soonest)) {
          soonest = event.at;
        }
      }
    }
    if (soonest == null) {
      return;
    }
    final DateTime fireAt = soonest.add(kunChatTypingTimeout);
    final Duration wait = fireAt.difference(_now);
    _typingTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      if (!mounted) {
        return;
      }
      final DateTime wall = DateTime.now();
      setState(() {
        _now = wall.isAfter(fireAt) ? wall : fireAt;
      });
      _scheduleTyping();
    });
  }

  int? _swipePointer;
  Offset _swipeOrigin = Offset.zero;
  double _swipeLastDx = 0;
  bool _swipeLocked = false;

  bool _isSwipeKind(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.touch || kind == PointerDeviceKind.stylus;

  void _onPointerDown(PointerDownEvent event) {
    if (!_isSwipeKind(event.kind)) {
      return;
    }
    if (_leadingW == 0 && _trailingW == 0) {
      return;
    }
    _swipePointer = event.pointer;
    _swipeOrigin = event.position;
    _swipeLastDx = event.position.dx;
    _swipeLocked = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _swipePointer) {
      return;
    }
    final double dx = event.position.dx - _swipeOrigin.dx;
    final double dy = event.position.dy - _swipeOrigin.dy;
    if (!_swipeLocked) {
      if (dy.abs() > _kAxisLock && dy.abs() > dx.abs()) {
        _swipePointer = null;
        return;
      }
      if (dx.abs() <= _kAxisLock) {
        return;
      }
      _swipeLocked = true;
      _onDragStart();
    }
    final double delta = event.position.dx - _swipeLastDx;
    _swipeLastDx = event.position.dx;
    _onDragUpdate(delta);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _swipePointer) {
      return;
    }
    _swipePointer = null;
    if (_swipeLocked) {
      _onDragEnd();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _swipePointer) {
      return;
    }
    _swipePointer = null;
    if (_swipeLocked) {
      _onDragCancel();
    }
  }

  void _onDragStart() {
    _swallowClick = false;
    _spring?.stop();
    _dragging = true;
  }

  void _onDragUpdate(double delta) {
    setState(() {
      _dragging = true;
      _offset = (_offset + delta).clamp(-_trailingW, _leadingW);
    });
  }

  void _onDragEnd() {
    _swallowClick = true;
    _dragging = false;
    final double target;
    if (_offset > _leadingW / 2) {
      target = _leadingW;
    } else if (_offset < -_trailingW / 2) {
      target = -_trailingW;
    } else {
      target = 0;
    }
    _animateTo(target);
  }

  void _onDragCancel() {
    _dragging = false;
    _animateTo(0);
  }

  void _animateTo(double target) {
    _spring?.dispose();
    _spring = null;
    if (_offset == target) {
      setState(() {});
      return;
    }
    final double begin = _offset;
    final AnimationController controller = AnimationController(
      vsync: this,
      duration: kunMotion(context, KunDurations.base),
    );
    _spring = controller;
    final Animation<double> curved = CurvedAnimation(
      parent: controller,
      curve: KunEasing.enter,
    );
    controller.addListener(() {
      setState(() {
        _offset = begin + (target - begin) * curved.value;
      });
    });
    controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _offset = target;
      }
    });
    controller.forward();
  }

  void _onRowTap() {
    if (_swallowClick || _offset != 0) {
      _swallowClick = false;
      _animateTo(0);
      return;
    }
    widget.onTap?.call();
  }

  void _fireAction(KunChatSwipeAction action) {
    _animateTo(0);
    widget.onAction?.call(action.key);
  }

  IconData? _statusIcon(KunChatSendStatus status) {
    return switch (status) {
      KunChatSendStatus.sending => KunIcons.clock,
      KunChatSendStatus.sent => KunIcons.check,
      KunChatSendStatus.read => KunIcons.checkCheck,
      KunChatSendStatus.failed => KunIcons.circleAlert,
    };
  }

  String _statusLabel(KunMessages messages, KunChatSendStatus status) {
    return switch (status) {
      KunChatSendStatus.sending => messages.chatStatus.sending,
      KunChatSendStatus.sent => messages.chatStatus.sent,
      KunChatSendStatus.read => messages.chatStatus.read,
      KunChatSendStatus.failed => messages.chatStatus.failed,
    };
  }

  Widget _labelledVisual(String? label, Widget child) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: child,
    );
  }

  Map<CustomSemanticsAction, VoidCallback> _semanticActions() {
    return <CustomSemanticsAction, VoidCallback>{
      for (final KunChatSwipeAction action in <KunChatSwipeAction>[
        ...widget.leadingActions,
        ...widget.trailingActions,
      ])
        CustomSemanticsAction(label: action.label): () => _fireAction(action),
    };
  }

  @override
  Widget build(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    final KunColorScheme scheme = theme.colors;
    final KunMessages messages = KunMessagesScope.of(context);
    final KunChatResolvedUser? resolved = widget.user == null
        ? null
        : resolveKunChatUser(
            kunChatUserMap(<KunChatUser>[widget.user!]),
            widget.user!.id,
            messages,
          );
    final String name = widget.title ?? resolved?.name ?? '';
    final KunUser avatarUser = KunUser(
      id: 0,
      name: resolved?.deleted == true ? '' : name,
      avatar: widget.avatar ?? resolved?.avatar ?? '',
    );
    final DateTime? timeValue = widget.time ?? widget.lastMessage?.createdAt;
    final String timeText = timeValue == null
        ? ''
        : formatKunChatListTime(timeValue, messages.code);
    final KunChatFormattedText? draftText =
        widget.draft != null && widget.draft!.text.trim().isNotEmpty
            ? widget.draft
            : null;
    final String serviceText =
        widget.lastMessage?.kind == KunChatMessageKind.service
            ? kunChatServiceText(
                widget.lastMessage!,
                KunChatServiceContext(
                  users: kunChatUserMap(widget.users),
                  currentUserId: widget.currentUserId,
                  messages: messages,
                ),
              )
            : '';
    final String badge =
        widget.unreadCount > 999 ? '999+' : '${widget.unreadCount}';

    final Color hoverFill = widget.selected
        ? scheme.primary.solid
        : _hovered
            ? Color.alphaBlend(
                scheme.neutral.solid.withValues(alpha: 0.1),
                scheme.content1,
              )
            : scheme.content1;
    final Color titleColor =
        widget.selected ? scheme.primary.onSolid : scheme.foreground;
    final Color metaColor = widget.selected
        ? scheme.primary.onSolid.withValues(alpha: 0.8)
        : scheme.foregroundMuted;
    final Color previewColor = widget.selected
        ? scheme.primary.onSolid.withValues(alpha: 0.85)
        : scheme.foregroundMuted;
    final Color typingColor =
        widget.selected ? scheme.primary.onSolid : scheme.primary.text;

    Widget preview;
    if (_typingActive) {
      preview = DefaultTextStyle.merge(
        style: KunText.sm.copyWith(color: typingColor),
        child: KunChatTyping(
          events: widget.typing,
          users: widget.users,
          kind: widget.kind,
        ),
      );
    } else if (draftText != null) {
      preview = Row(
        children: <Widget>[
          Text(
            messages.chat.draft,
            style: KunText.sm.copyWith(
              color:
                  widget.selected ? scheme.primary.onSolid : scheme.danger.text,
              fontWeight: widget.selected
                  ? KunFontWeights.medium
                  : KunFontWeights.normal,
            ),
          ),
          Expanded(
            child: DefaultTextStyle.merge(
              style: KunText.sm.copyWith(color: previewColor),
              child: KunChatText(
                text: draftText.text,
                entities: draftText.entities,
                preview: true,
              ),
            ),
          ),
        ],
      );
    } else if (widget.lastMessage != null) {
      if (widget.lastMessage!.kind == KunChatMessageKind.service) {
        preview = Text(
          serviceText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KunText.sm.copyWith(color: previewColor),
        );
      } else {
        preview = Row(
          children: <Widget>[
            if (widget.lastMessageSender != null)
              Text(
                messages.chat.senderPrefix(name: widget.lastMessageSender!),
                maxLines: 1,
                style: KunText.sm.copyWith(
                  color: widget.selected
                      ? previewColor
                      : scheme.foreground.withValues(alpha: 0.8),
                ),
              ),
            if (widget.lastMessage!.media != null) ...<Widget>[
              Icon(
                KunIcons.image,
                size: KunText.xs.fontSize,
                color: previewColor,
              ),
              const SizedBox(width: KunSpacing.unit * 0.5),
            ],
            if (widget.lastMessage!.text.isNotEmpty)
              Expanded(
                child: DefaultTextStyle.merge(
                  style: KunText.sm.copyWith(color: previewColor),
                  child: KunChatText(
                    text: widget.lastMessage!.text,
                    entities: widget.lastMessage!.entities,
                    preview: true,
                  ),
                ),
              )
            else
              Expanded(
                child: Text(
                  kunChatMediaLabel(widget.lastMessage!.media, messages),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KunText.sm.copyWith(color: previewColor),
                ),
              ),
          ],
        );
      }
    } else {
      preview = const SizedBox.shrink();
    }

    final Widget badges = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.mentionCount > 0)
          _labelledVisual(
            messages.chat.mentioned,
            Container(
              width: KunSpacing.unit * 5,
              height: KunSpacing.unit * 5,
              decoration: BoxDecoration(
                color: widget.selected
                    ? scheme.primary.onSolid
                    : scheme.primary.solid,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                KunIcons.atSign,
                size: KunText.xs.fontSize,
                color: widget.selected
                    ? scheme.primary.solid
                    : scheme.primary.onSolid,
              ),
            ),
          ),
        if (widget.mentionCount > 0 &&
            (widget.unreadCount > 0 || widget.markedUnread))
          const SizedBox(width: KunSpacing.unit * 1.5),
        if (widget.unreadCount > 0 || widget.markedUnread)
          _labelledVisual(
            widget.unreadCount > 0
                ? messages.chat.unreadCount(count: widget.unreadCount)
                : null,
            Container(
              constraints: const BoxConstraints(
                minWidth: KunSpacing.unit * 5,
                minHeight: KunSpacing.unit * 5,
              ),
              height: KunSpacing.unit * 5,
              padding: const EdgeInsets.symmetric(
                horizontal: KunSpacing.unit * 1.5,
              ),
              decoration: BoxDecoration(
                color: widget.selected
                    ? scheme.primary.onSolid
                    : widget.muted
                        ? scheme.neutral.shade400
                        : scheme.primary.solid,
                borderRadius: BorderRadius.circular(KunRadius.full),
              ),
              alignment: Alignment.center,
              child: widget.unreadCount > 0
                  ? Text(
                      badge,
                      style: KunText.xs.copyWith(
                        fontWeight: KunFontWeights.medium,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                        color: widget.selected
                            ? scheme.primary.solid
                            : widget.muted
                                ? KunColors.white
                                : scheme.primary.onSolid,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          )
        else if (widget.pinned)
          _labelledVisual(
            messages.chat.pinned,
            Transform.rotate(
              angle: math.pi / 4,
              child: Icon(
                KunIcons.pin,
                size: KunText.sm.fontSize,
                color: widget.selected
                    ? titleColor.withValues(alpha: 0.8)
                    : scheme.neutral.shade400,
              ),
            ),
          ),
      ],
    );

    final Widget row = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The row's Semantics already carries the tap. A second tap action
        // cannot merge with it, which left TalkBack an unnamed button over a
        // separately clickable label.
        excludeFromSemantics: true,
        onTap: _onRowTap,
        child: AnimatedContainer(
          duration:
              _dragging ? Duration.zero : kunMotion(context, KunDurations.base),
          curve: KunEasing.enter,
          color: hoverFill,
          padding: const EdgeInsets.symmetric(
            horizontal: KunSpacing.unit * 3,
            vertical: KunSpacing.unit * 2,
          ),
          child: Row(
            children: <Widget>[
              ExcludeSemantics(
                child: KunAvatar(
                  user: avatarUser,
                  size: KunAvatarSize.xl,
                  isNavigation: false,
                ),
              ),
              const SizedBox(width: KunSpacing.unit * 3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: KunFontWeights.semibold,
                              color: titleColor,
                            ),
                          ),
                        ),
                        if (widget.muted) ...<Widget>[
                          const SizedBox(width: KunSpacing.unit * 1.5),
                          _labelledVisual(
                            messages.chat.muted,
                            Icon(
                              KunIcons.bellOff,
                              size: KunText.xs.fontSize,
                              color: widget.selected
                                  ? titleColor.withValues(alpha: 0.8)
                                  : scheme.neutral.shade400,
                            ),
                          ),
                        ],
                        const SizedBox(width: KunSpacing.unit * 1.5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (widget.status != null) ...<Widget>[
                              _labelledVisual(
                                _statusLabel(messages, widget.status!),
                                Icon(
                                  _statusIcon(widget.status!),
                                  size: KunText.sm.fontSize,
                                  color:
                                      widget.status == KunChatSendStatus.failed
                                          ? scheme.danger.text
                                          : widget.selected
                                              ? metaColor
                                              : scheme.primary.text,
                                ),
                              ),
                              const SizedBox(width: KunSpacing.unit),
                            ],
                            Text(
                              timeText,
                              style: KunText.xs.copyWith(color: metaColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: KunSpacing.unit * 0.5),
                    Row(
                      children: <Widget>[
                        Expanded(child: preview),
                        const SizedBox(width: KunSpacing.unit * 1.5),
                        badges,
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Widget leading = const SizedBox.shrink();
    if (_leadingW > 0) {
      leading = Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        child: ExcludeSemantics(
          excluding: _offset <= 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final KunChatSwipeAction action in widget.leadingActions)
                _SwipeActionButton(
                  action: action,
                  fallback: KunUIColor.primary,
                  onPressed: () => _fireAction(action),
                ),
            ],
          ),
        ),
      );
    }
    Widget trailing = const SizedBox.shrink();
    if (_trailingW > 0) {
      trailing = Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        child: ExcludeSemantics(
          excluding: _offset >= 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final KunChatSwipeAction action in widget.trailingActions)
                _SwipeActionButton(
                  action: action,
                  fallback: KunUIColor.neutral,
                  onPressed: () => _fireAction(action),
                ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      selected: widget.selected,
      onTap: _onRowTap,
      customSemanticsActions: _semanticActions(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KunRadius.md),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: Stack(
            children: <Widget>[
              if (_leadingW > 0) leading,
              if (_trailingW > 0) trailing,
              Transform.translate(offset: Offset(_offset, 0), child: row),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({
    required this.action,
    required this.fallback,
    required this.onPressed,
  });

  final KunChatSwipeAction action;
  final KunUIColor fallback;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    final KunVariantStyle style = KunVariantStyle.resolve(
      scheme: theme.colors,
      brightness: theme.brightness,
      variant: KunUIVariant.solid,
      color: action.color ?? fallback,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: ColoredBox(
        color: style.background,
        child: SizedBox(
          width: _kActionWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KunSpacing.unit),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (action.icon != null)
                  Icon(
                    action.icon,
                    size: KunText.lg.fontSize,
                    color: style.foreground,
                  ),
                if (action.icon != null)
                  const SizedBox(height: KunSpacing.unit),
                Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: KunText.xs.copyWith(color: style.foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
