import 'package:flutter/widgets.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/shortcut.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';

/// How a [KunKbd] draws its keys.
enum KunKbdVariant {
  /// Each key is a cap, sized in em so it follows the text around it.
  keycap,

  /// One line of muted text, the way a menu shows a shortcut: `⇧⌘Z` on
  /// Apple, `Ctrl+Shift+Z` elsewhere.
  plain,
}

/// A keyboard key, a chord, or a sequence of chords.
///
/// [keys] uses the same grammar as the web: `+` joins a chord and whitespace
/// separates a sequence (`Mod+K`, `Shift+Delete`, `G G`). `Mod` is ⌘ on
/// Apple and Ctrl elsewhere. With no [keys], [child] is shown as one key.
class KunKbd extends StatelessWidget {
  /// Creates a key, a chord, or a sequence.
  const KunKbd({
    this.keys = '',
    this.variant = KunKbdVariant.keycap,
    this.child,
    super.key,
  });

  /// Key combination. Empty shows [child] as one key.
  final String keys;

  /// Keycap caps, or the plain one-line form a menu uses.
  final KunKbdVariant variant;

  /// A single key written out, shown when [keys] is empty.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final double em =
        DefaultTextStyle.of(context).style.fontSize ?? KunText.sm.fontSize!;
    final KunColorScheme scheme = KunTheme.of(context).colors;
    if (keys.isEmpty) {
      return _keycap(em, scheme, child ?? const SizedBox.shrink());
    }

    final KunShortcutPlatform platform = kunShortcutPlatform();
    final KunMessages messages = KunMessagesScope.of(context);
    final String spoken = speakKunShortcut(
      resolveKunShortcut(keys, platform),
      (KunKbdKeyName name) => _kunKbdSpokenName(name, messages.kbd),
      messages.kbd.then,
    );

    final Widget visual = variant == KunKbdVariant.plain
        ? _plain(em, scheme, formatKunShortcut(keys, platform))
        : _keycaps(em, scheme, resolveKunShortcut(keys, platform));

    return Semantics(
      container: true,
      label: spoken,
      child: ExcludeSemantics(child: visual),
    );
  }

  Widget _plain(double em, KunColorScheme scheme, String text) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: scheme.foregroundMuted,
          fontSize: em * 0.85,
          fontWeight: KunFontWeights.normal,
          height: 1,
        ),
      ),
    );
  }

  Widget _keycaps(
    double em,
    KunColorScheme scheme,
    List<List<KunShortcutKey>> sequence,
  ) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int ci = 0; ci < sequence.length; ci++) ...<Widget>[
            if (ci > 0) SizedBox(width: em * 0.5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int ki = 0; ki < sequence[ci].length; ki++) ...<Widget>[
                  if (ki > 0) SizedBox(width: em * 0.2),
                  _keycap(em, scheme, Text(sequence[ci][ki].label)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _keycap(double em, KunColorScheme scheme, Widget child) {
    // Container.alignment fills a bounded parent: the gallery's Wrap
    // painted a lone Esc as an 800-wide bar. Align with size factors
    // shrink-wraps, as KunBadge does.
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            scheme.neutral.shade100.withValues(alpha: KunColors.globalOpacity),
        borderRadius: BorderRadius.circular(em * 0.3),
        border: Border(
          top: BorderSide(color: scheme.neutral.shade200),
          left: BorderSide(color: scheme.neutral.shade200),
          right: BorderSide(color: scheme.neutral.shade200),
          bottom: BorderSide(color: scheme.neutral.shade200, width: 2),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: em * 1.5,
          minHeight: em * 1.5,
          maxHeight: em * 1.5,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: em * 0.35),
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1,
            heightFactor: 1,
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: scheme.foregroundMuted,
                fontSize: em * 0.8,
                fontWeight: KunFontWeights.medium,
                height: 1,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

String _kunKbdSpokenName(KunKbdKeyName name, KunKbdStrings kbd) {
  return switch (name) {
    KunKbdKeyName.control => kbd.control,
    KunKbdKeyName.alt => kbd.alt,
    KunKbdKeyName.option => kbd.option,
    KunKbdKeyName.shift => kbd.shift,
    KunKbdKeyName.command => kbd.command,
    KunKbdKeyName.meta => kbd.meta,
    KunKbdKeyName.enter => kbd.enter,
    KunKbdKeyName.escape => kbd.escape,
    KunKbdKeyName.backspace => kbd.backspace,
    KunKbdKeyName.delete => kbd.delete,
    KunKbdKeyName.tab => kbd.tab,
    KunKbdKeyName.space => kbd.space,
    KunKbdKeyName.up => kbd.up,
    KunKbdKeyName.down => kbd.down,
    KunKbdKeyName.left => kbd.left,
    KunKbdKeyName.right => kbd.right,
    KunKbdKeyName.pageUp => kbd.pageUp,
    KunKbdKeyName.pageDown => kbd.pageDown,
    KunKbdKeyName.home => kbd.home,
    KunKbdKeyName.end => kbd.end,
    KunKbdKeyName.plus => kbd.plus,
  };
}

/// The spoken form of [keys] for [messages] on this platform.
String kunSpeakShortcut(String keys, KunMessages messages) {
  return speakKunShortcut(
    resolveKunShortcut(keys, kunShortcutPlatform()),
    (KunKbdKeyName name) => _kunKbdSpokenName(name, messages.kbd),
    messages.kbd.then,
  );
}
