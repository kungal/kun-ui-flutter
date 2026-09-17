import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../config/config.dart';
import '../foundation/design.dart';
import '../foundation/focus_outline.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'avatar.dart';

/// Avatar plus name, and an optional description, implementing the web
/// `KunUserChip` contract.
///
/// When [isNavigation] is true (the default) and [user] is non-null with a
/// [KunUser.id] that is not 0, the whole chip is one link to the user's
/// profile. A null [user], or a user whose id is 0, is never a link.
///
/// The web chip is a block and spans its container; this one is as wide as
/// its content. In a narrower parent both lines truncate with an ellipsis
/// on one line each.
class KunUserChip extends StatelessWidget {
  /// Creates a user chip.
  const KunUserChip({
    super.key,
    required this.user,
    this.description = '',
    this.size = KunAvatarSize.md,
    this.isNavigation = true,
  });

  /// Null: the fallback picture and the unknown-user name.
  final KunUser? user;

  /// Secondary line. Empty draws no second line.
  final String description;

  /// The avatar's size. The text stays `text-sm`.
  final KunAvatarSize size;

  /// When true (the default) and [user] is non-null with a [KunUser.id] that
  /// is not 0, the whole chip is one link to the user's profile.
  final bool isNavigation;

  @override
  Widget build(BuildContext context) {
    final bool isLink = isNavigation && user != null && user!.id != 0;
    final String rawName = user?.name ?? '';
    final String name = rawName.isEmpty
        ? KunMessagesScope.of(context).avatar.unknownUser
        : rawName;
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final String semanticsLabel =
        description.isEmpty ? name : '$name\n$description';

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: KunSpacing.unit * 2,
      children: [
        KunAvatar(
          user: user,
          size: size,
          isNavigation: false,
        ),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: KunText.sm,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (description.isNotEmpty)
                Text(
                  description,
                  style: KunText.sm.copyWith(color: scheme.neutral.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );

    void open() {
      final KunUser? current = user;
      if (!isLink || current == null) {
        return;
      }
      final KunUIConfig config = KunUIConfigScope.of(context);
      config.navigateTo(context, config.userLinkFor(current.id));
    }

    return Semantics(
      container: true,
      link: isLink,
      label: semanticsLabel,
      onTap: isLink ? open : null,
      excludeSemantics: true,
      child: isLink ? _KunUserChipLink(onOpen: open, child: content) : content,
    );
  }
}

class _KunUserChipLink extends StatefulWidget {
  const _KunUserChipLink({required this.onOpen, required this.child});

  final VoidCallback onOpen;
  final Widget child;

  @override
  State<_KunUserChipLink> createState() => _KunUserChipLinkState();
}

class _KunUserChipLinkState extends State<_KunUserChipLink> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (bool value) => setState(() => _focused = value),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onOpen();
            return null;
          },
        ),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
          onInvoke: (_) {
            widget.onOpen();
            return null;
          },
        ),
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onOpen,
          child: KunFocusOutline(
            visible: _focused,
            color: KunUIColor.primary
                .scaleOf(KunTheme.of(context).colors)
                .solid
                .withValues(alpha: 0.5),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
