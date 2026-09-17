import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../config/config.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'avatar.dart';

/// Avatar plus name, and an optional description, implementing the web
/// `KunUserChip` contract.
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

  /// With a [user], the whole chip is one link.
  final bool isNavigation;

  @override
  Widget build(BuildContext context) {
    final bool isLink = isNavigation && user != null;
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
      child: isLink
          ? FocusableActionDetector(
              actions: <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    open();
                    return null;
                  },
                ),
                ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
                  onInvoke: (_) {
                    open();
                    return null;
                  },
                ),
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: open,
                  child: content,
                ),
              ),
            )
          : content,
    );
  }
}
