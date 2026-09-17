import 'package:flutter/widgets.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';

/// Provides a [KunMessages] catalog to the KunUI widgets below it.
///
/// The strings KunUI renders on its own — the accessible name of a chip's ×,
/// of an input's clear button — come from the generated `kun_ui_messages`
/// catalogs, the same ones the web bundle resolves `t('chip.remove')` from.
/// Wrap the app once to choose a language:
///
/// ```dart
/// KunMessagesScope(
///   messages: KunMessages.en,
///   child: const App(),
/// )
/// ```
///
/// Unlike `KunTheme` this is never required: with no scope above them the
/// widgets read [KunMessages.zhCN], KunUI's built-in default on both
/// platforms. It is deliberately not a field on `KunThemeData` — the web
/// carries its locale on `KunUIConfig`, not on the theme, and an app that
/// switches language does not switch colors.
///
/// There is no per-widget override, and the contract carries none: a string
/// KunUI renders for itself belongs to KunUI. Scope a subtree that needs a
/// different language in its own [KunMessagesScope].
///
/// An [InheritedTheme], so [InheritedTheme.capture] carries it into a route
/// or overlay opened from below it.
class KunMessagesScope extends InheritedTheme {
  /// Applies [messages] to the subtree under [child].
  const KunMessagesScope({
    required this.messages,
    required super.child,
    super.key,
  });

  /// The catalog the subtree resolves its strings from.
  final KunMessages messages;

  /// The catalog of the closest [KunMessagesScope] ancestor, or
  /// [KunMessages.zhCN] when there is none.
  static KunMessages of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<KunMessagesScope>()
          ?.messages ??
      KunMessages.zhCN;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      KunMessagesScope(messages: messages, child: child);

  @override
  bool updateShouldNotify(KunMessagesScope oldWidget) =>
      messages != oldWidget.messages;
}
