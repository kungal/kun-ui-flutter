import 'dart:ui' show SemanticsRole;

import 'package:flutter/widgets.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../chat/support.dart';
import '../chat/types.dart';
import '../foundation/design.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'button.dart';

/// One of the four buttons on a [KunChatRequestBar], the web's
/// `KunChatRequestAction`.
enum KunChatRequestAction {
  /// Move the conversation into the inbox.
  accept,

  /// Delete the conversation; the sender is not told.
  delete,

  /// Block the sender.
  block,

  /// Report the sender.
  report,
}

/// The bar on top of a message request.
class KunChatRequestBar extends StatelessWidget {
  /// Creates a request bar.
  const KunChatRequestBar({
    super.key,
    this.actions = const <KunChatRequestAction>[
      KunChatRequestAction.accept,
      KunChatRequestAction.delete,
      KunChatRequestAction.block,
      KunChatRequestAction.report,
    ],
    this.loading,
    this.user,
    this.onAccept,
    this.onDelete,
    this.onBlock,
    this.onReport,
  });

  /// The buttons, in order.
  final List<KunChatRequestAction> actions;

  /// The action in flight: its button spins and the others wait.
  final KunChatRequestAction? loading;

  /// Who sent the request.
  final KunChatUser? user;

  /// Move the conversation into the inbox.
  final VoidCallback? onAccept;

  /// Delete the conversation; the sender is not told.
  final VoidCallback? onDelete;

  /// Block the sender.
  final VoidCallback? onBlock;

  /// Report the sender.
  final VoidCallback? onReport;

  static ({KunUIVariant variant, KunUIColor color}) _look(
    KunChatRequestAction action,
  ) {
    return switch (action) {
      KunChatRequestAction.accept => (
          variant: KunUIVariant.solid,
          color: KunUIColor.primary,
        ),
      KunChatRequestAction.delete => (
          variant: KunUIVariant.flat,
          color: KunUIColor.neutral,
        ),
      KunChatRequestAction.block => (
          variant: KunUIVariant.flat,
          color: KunUIColor.danger,
        ),
      KunChatRequestAction.report => (
          variant: KunUIVariant.light,
          color: KunUIColor.danger,
        ),
    };
  }

  void _run(KunChatRequestAction action) {
    switch (action) {
      case KunChatRequestAction.accept:
        onAccept?.call();
      case KunChatRequestAction.delete:
        onDelete?.call();
      case KunChatRequestAction.block:
        onBlock?.call();
      case KunChatRequestAction.report:
        onReport?.call();
    }
  }

  String _label(KunMessages messages, KunChatRequestAction action) {
    final KunChatRequestStrings strings = messages.chatRequest;
    return switch (action) {
      KunChatRequestAction.accept => strings.accept,
      KunChatRequestAction.delete => strings.delete,
      KunChatRequestAction.block => strings.block,
      KunChatRequestAction.report => strings.report,
    };
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final KunMessages messages = KunMessagesScope.of(context);
    final String title = messages.chatRequest.title;
    final String name = user == null
        ? ''
        : resolveKunChatUser(
                kunChatUserMap(<KunChatUser>[user!]), user!.id, messages)
            .name;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: title,
      role: SemanticsRole.region,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.content1,
          border: Border(
            bottom: BorderSide(
              color: scheme.neutral.solid.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KunSpacing.unit * 4,
            vertical: KunSpacing.unit * 3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                textAlign: TextAlign.center,
                style: KunText.sm.copyWith(
                  fontWeight: KunFontWeights.semibold,
                  color: scheme.foreground,
                ),
              ),
              const SizedBox(height: KunSpacing.unit * 2),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: KunContainerWidths.md,
                ),
                child: Text(
                  messages.chatRequest.description(name: name),
                  textAlign: TextAlign.center,
                  style: KunText.sm.copyWith(color: scheme.neutral.shade600),
                ),
              ),
              const SizedBox(height: KunSpacing.unit * 2),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: KunSpacing.unit * 2,
                runSpacing: KunSpacing.unit * 2,
                children: <Widget>[
                  for (final KunChatRequestAction action in actions)
                    KunButton(
                      size: KunUISize.sm,
                      variant: _look(action).variant,
                      color: _look(action).color,
                      loading: loading == action,
                      disabled: loading != null && loading != action,
                      onPressed: () => _run(action),
                      child: Text(_label(messages, action)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
