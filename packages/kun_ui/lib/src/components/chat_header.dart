import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../chat/constants.dart';
import '../chat/support.dart';
import '../chat/types.dart';
import '../foundation/motion.dart';
import '../foundation/tap_target.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'avatar.dart';
import 'chat_shared.dart';
import 'chat_typing.dart';

/// Web `h-14`.
const double _kBarHeight = KunSpacing.unit * 14;

/// Web `size-10`.
const double _kBackSize = KunSpacing.unit * 10;

/// Web `hover:bg-default/20`.
const double _kBackHover = 0.2;

/// When the conversation header shows its back button.
enum KunChatHeaderBack {
  /// Always show the back button.
  always,

  /// Never show the back button.
  never,

  /// Show the back button only below the theme's `md` viewport width.
  mobile,
}

/// The bar above a conversation: back (on a phone), avatar, title, and a
/// second line that turns into "typing…" while someone types.
class KunChatHeader extends StatefulWidget {
  /// Creates a conversation header.
  const KunChatHeader({
    super.key,
    this.avatar,
    this.back = KunChatHeaderBack.mobile,
    this.kind = KunChatKind.direct,
    this.subtitle = '',
    this.title,
    this.typing = const <KunChatTypingEvent>[],
    this.user,
    this.users = const <KunChatUser>[],
    this.onBack,
    this.onTitleTap,
    this.actions,
    this.subtitleWidget,
  });

  /// Avatar URL, e.g. a group photo. Defaults to [user]'s.
  final String? avatar;

  /// The back button: [KunChatHeaderBack.mobile] below the `md` breakpoint
  /// only.
  final KunChatHeaderBack back;

  /// A direct chat says "typing…"; a group names who is typing.
  final KunChatKind kind;

  /// Second line, e.g. a member count. Replaced while someone types.
  final String subtitle;

  /// Title. Defaults to [user]'s name.
  final String? title;

  /// Typing notifications as received; while one is live it replaces the
  /// subtitle.
  final List<KunChatTypingEvent> typing;

  /// The other person of a direct chat: title and avatar.
  final KunChatUser? user;

  /// Users, to name who is typing in a group.
  final List<KunChatUser> users;

  /// The back button was clicked.
  final VoidCallback? onBack;

  /// The avatar or title was clicked, e.g. to open the profile or details.
  final VoidCallback? onTitleTap;

  /// Buttons on the right: search, call, a menu.
  final Widget? actions;

  /// Replaces the second line when nobody is typing. The contract slot
  /// shares the name `subtitle` with the string prop; this is the slot,
  /// as [KunReaction.icon] / [KunReaction.iconBuilder] pair a value with
  /// a builder.
  final Widget? subtitleWidget;

  @override
  State<KunChatHeader> createState() => _KunChatHeaderState();
}

class _KunChatHeaderState extends State<KunChatHeader> {
  DateTime _now = DateTime.now();
  Timer? _typingTimer;
  bool _backHovered = false;

  bool get _typingActive {
    for (final KunChatTypingEvent event in widget.typing) {
      if (_now.difference(event.at) < kunChatTypingTimeout) {
        return true;
      }
    }
    return false;
  }

  bool _showBack(BuildContext context) {
    switch (widget.back) {
      case KunChatHeaderBack.always:
        return true;
      case KunChatHeaderBack.never:
        return false;
      case KunChatHeaderBack.mobile:
        return MediaQuery.sizeOf(context).width <
            KunTheme.of(context).breakpoints.md;
    }
  }

  @override
  void initState() {
    super.initState();
    _scheduleTyping();
  }

  @override
  void didUpdateWidget(KunChatHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.typing, widget.typing)) {
      _now = DateTime.now();
      _scheduleTyping();
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
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
      name: resolved != null && resolved.deleted ? '' : name,
      avatar: widget.avatar ?? resolved?.avatar ?? '',
    );
    final bool showBack = _showBack(context);
    final Widget second = _typingActive
        ? DefaultTextStyle.merge(
            style: KunText.xs.copyWith(
              color: scheme.primary.solid,
              height: 16 / 12,
              leadingDistribution: TextLeadingDistribution.even,
            ),
            child: KunChatTyping(
              events: widget.typing,
              users: widget.users,
              kind: widget.kind,
            ),
          )
        : DefaultTextStyle.merge(
            style: KunText.xs.copyWith(
              color: scheme.foregroundMuted,
              height: 16 / 12,
              leadingDistribution: TextLeadingDistribution.even,
            ),
            child: widget.subtitleWidget ??
                Text(
                  widget.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      header: true,
      child: DecoratedBox(
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
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KunSpacing.unit * 2,
            ),
            child: Row(
              children: <Widget>[
                if (showBack)
                  _BackButton(
                    label: messages.chat.back,
                    hovered: _backHovered,
                    color: _backHovered
                        ? scheme.foreground
                        : scheme.neutral.shade600,
                    fill: _backHovered
                        ? scheme.neutral.solid.withValues(alpha: _kBackHover)
                        : scheme.neutral.solid.withValues(alpha: 0),
                    onHover: (bool value) =>
                        setState(() => _backHovered = value),
                    onTap: () => widget.onBack?.call(),
                  ),
                Expanded(
                  child: SizedBox(
                    height: double.infinity,
                    child: _TitleButton(
                      label: name,
                      onTap: () => widget.onTitleTap?.call(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KunSpacing.unit,
                          vertical: KunSpacing.unit,
                        ),
                        child: Row(
                          children: <Widget>[
                            ExcludeSemantics(
                              child: KunAvatar(
                                user: avatarUser,
                                size: KunAvatarSize.lg,
                                isNavigation: false,
                              ),
                            ),
                            const SizedBox(width: KunSpacing.unit * 3),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: KunFontWeights.semibold,
                                      height:
                                          20 / (KunText.base.fontSize ?? 16),
                                      leadingDistribution:
                                          TextLeadingDistribution.even,
                                    ),
                                  ),
                                  second,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.actions != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[widget.actions!],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({
    required this.label,
    required this.hovered,
    required this.color,
    required this.fill,
    required this.onHover,
    required this.onTap,
  });

  final String label;
  final bool hovered;
  final Color color;
  final Color fill;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: KunTapTarget(
        child: FocusableActionDetector(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                onTap();
                return null;
              },
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (_) {
                onTap();
                return null;
              },
            ),
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => onHover(true),
            onExit: (_) => onHover(false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: onTap,
              child: AnimatedContainer(
                duration: kunMotion(context, KunDurations.base),
                curve: KunEasing.enter,
                width: _kBackSize,
                height: _kBackSize,
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(
                  KunIcons.arrowLeft,
                  size: KunText.xl.fontSize,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleButton extends StatelessWidget {
  const _TitleButton({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: FocusableActionDetector(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              onTap();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: onTap,
            child: child,
          ),
        ),
      ),
    );
  }
}
