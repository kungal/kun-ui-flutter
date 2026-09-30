import 'package:flutter/foundation.dart';

/// Keyboard-shortcut display: the parser, the per-platform labels and the
/// modifier order behind KunKbd, KunTooltip's shortcut and the menu items'
/// shortcut. Display only — binding the key is the app's job.
///
/// Port of `packages/ui-core/src/shortcut.ts` at `kun_ui_tokens-v2.55.0`.

/// `apple` is macOS and iOS; everything else is `other`.
enum KunShortcutPlatform {
  /// macOS and iOS: Command, Option, and the HIG modifier glyphs.
  apple,

  /// Windows, Linux, Android, Fuchsia: Ctrl, Win, Alt, Shift.
  other,
}

/// Keys whose spoken name comes from the locale (`kbd.<name>`) rather than
/// from the label: a glyph such as ⌘ or ↑, or an abbreviation such as Esc.
enum KunKbdKeyName {
  /// Control / ⌃.
  control,

  /// Alt (non-Apple).
  alt,

  /// Option (Apple).
  option,

  /// Shift / ⇧.
  shift,

  /// Command (Apple).
  command,

  /// Meta / Win (non-Apple).
  meta,

  /// Enter / ↩.
  enter,

  /// Escape / Esc.
  escape,

  /// Backspace / ⌫.
  backspace,

  /// Delete / ⌦ / Del.
  delete,

  /// Tab / ⇥.
  tab,

  /// Space.
  space,

  /// Arrow up.
  up,

  /// Arrow down.
  down,

  /// Arrow left.
  left,

  /// Arrow right.
  right,

  /// Page up.
  pageUp,

  /// Page down.
  pageDown,

  /// Home.
  home,

  /// End.
  end,

  /// The plus key.
  plus,
}

/// One resolved key of a shortcut chord.
@immutable
class KunShortcutKey {
  /// Creates a resolved key.
  const KunShortcutKey({
    required this.key,
    required this.label,
    this.spoken,
  });

  /// Canonical key: `Control`, `Alt`, `Shift`, `Meta`, `Enter`, `ArrowUp`,
  /// `K`, `+`…
  final String key;

  /// What the key shows on this platform: `⌘`, `Ctrl`, `K`.
  final String label;

  /// The locale key (under `kbd`) a screen reader hears instead of [label];
  /// null when the label reads as itself (a letter, a digit, F5).
  final KunKbdKeyName? spoken;

  @override
  bool operator ==(Object other) =>
      other is KunShortcutKey &&
      other.key == key &&
      other.label == label &&
      other.spoken == spoken;

  @override
  int get hashCode => Object.hash(key, label, spoken);

  @override
  String toString() =>
      'KunShortcutKey(key: $key, label: $label, spoken: $spoken)';
}

const Map<String, String> _aliases = <String, String>{
  'mod': 'Mod',
  'ctrl': 'Control',
  'control': 'Control',
  'alt': 'Alt',
  'option': 'Alt',
  'opt': 'Alt',
  'shift': 'Shift',
  'meta': 'Meta',
  'cmd': 'Meta',
  'command': 'Meta',
  'super': 'Meta',
  'win': 'Meta',
  'enter': 'Enter',
  'return': 'Enter',
  'esc': 'Escape',
  'escape': 'Escape',
  'backspace': 'Backspace',
  'del': 'Delete',
  'delete': 'Delete',
  'tab': 'Tab',
  'space': 'Space',
  'spacebar': 'Space',
  'up': 'ArrowUp',
  'arrowup': 'ArrowUp',
  'down': 'ArrowDown',
  'arrowdown': 'ArrowDown',
  'left': 'ArrowLeft',
  'arrowleft': 'ArrowLeft',
  'right': 'ArrowRight',
  'arrowright': 'ArrowRight',
  'pageup': 'PageUp',
  'pgup': 'PageUp',
  'pagedown': 'PageDown',
  'pgdn': 'PageDown',
  'home': 'Home',
  'end': 'End',
  'plus': '+',
};

// Apple's Human Interface Guidelines list modifiers as Control, Option, Shift,
// Command (⌃⌥⇧⌘). Elsewhere this follows Primer's KeybindingHint: Ctrl, Win,
// Alt, Shift. A chord is sorted into that order whatever order it was written
// in, so one command table renders consistently.
const Map<KunShortcutPlatform, List<String>> _modifierOrder =
    <KunShortcutPlatform, List<String>>{
  KunShortcutPlatform.apple: <String>['Control', 'Alt', 'Shift', 'Meta'],
  KunShortcutPlatform.other: <String>['Control', 'Meta', 'Alt', 'Shift'],
};

class _KeyDisplay {
  const _KeyDisplay({
    required this.apple,
    required this.other,
    required this.spoken,
  });

  final String apple;
  final String other;
  final KunKbdKeyName Function(KunShortcutPlatform platform) spoken;

  String labelFor(KunShortcutPlatform platform) =>
      platform == KunShortcutPlatform.apple ? apple : other;
}

final Map<String, _KeyDisplay> _named = <String, _KeyDisplay>{
  'Control': _KeyDisplay(
    apple: '⌃',
    other: 'Ctrl',
    spoken: (_) => KunKbdKeyName.control,
  ),
  'Alt': _KeyDisplay(
    apple: '⌥',
    other: 'Alt',
    spoken: (KunShortcutPlatform p) => p == KunShortcutPlatform.apple
        ? KunKbdKeyName.option
        : KunKbdKeyName.alt,
  ),
  'Shift': _KeyDisplay(
    apple: '⇧',
    other: 'Shift',
    spoken: (_) => KunKbdKeyName.shift,
  ),
  'Meta': _KeyDisplay(
    apple: '⌘',
    other: 'Win',
    spoken: (KunShortcutPlatform p) => p == KunShortcutPlatform.apple
        ? KunKbdKeyName.command
        : KunKbdKeyName.meta,
  ),
  'Enter': _KeyDisplay(
    apple: '↩',
    other: 'Enter',
    spoken: (_) => KunKbdKeyName.enter,
  ),
  'Escape': _KeyDisplay(
    apple: 'Esc',
    other: 'Esc',
    spoken: (_) => KunKbdKeyName.escape,
  ),
  'Backspace': _KeyDisplay(
    apple: '⌫',
    other: 'Backspace',
    spoken: (_) => KunKbdKeyName.backspace,
  ),
  'Delete': _KeyDisplay(
    apple: '⌦',
    other: 'Del',
    spoken: (_) => KunKbdKeyName.delete,
  ),
  'Tab': _KeyDisplay(
    apple: '⇥',
    other: 'Tab',
    spoken: (_) => KunKbdKeyName.tab,
  ),
  'Space': _KeyDisplay(
    apple: 'Space',
    other: 'Space',
    spoken: (_) => KunKbdKeyName.space,
  ),
  'ArrowUp': _KeyDisplay(
    apple: '↑',
    other: '↑',
    spoken: (_) => KunKbdKeyName.up,
  ),
  'ArrowDown': _KeyDisplay(
    apple: '↓',
    other: '↓',
    spoken: (_) => KunKbdKeyName.down,
  ),
  'ArrowLeft': _KeyDisplay(
    apple: '←',
    other: '←',
    spoken: (_) => KunKbdKeyName.left,
  ),
  'ArrowRight': _KeyDisplay(
    apple: '→',
    other: '→',
    spoken: (_) => KunKbdKeyName.right,
  ),
  'PageUp': _KeyDisplay(
    apple: 'PgUp',
    other: 'PgUp',
    spoken: (_) => KunKbdKeyName.pageUp,
  ),
  'PageDown': _KeyDisplay(
    apple: 'PgDn',
    other: 'PgDn',
    spoken: (_) => KunKbdKeyName.pageDown,
  ),
  'Home': _KeyDisplay(
    apple: 'Home',
    other: 'Home',
    spoken: (_) => KunKbdKeyName.home,
  ),
  'End': _KeyDisplay(
    apple: 'End',
    other: 'End',
    spoken: (_) => KunKbdKeyName.end,
  ),
  '+': _KeyDisplay(
    apple: '+',
    other: '+',
    spoken: (_) => KunKbdKeyName.plus,
  ),
};

final RegExp _functionKey = RegExp(r'^f\d{1,2}$', caseSensitive: false);

String _canonicalKey(String token) {
  final String? alias = _aliases[token.toLowerCase()];
  if (alias != null) {
    return alias;
  }
  if (_functionKey.hasMatch(token)) {
    return token.toUpperCase();
  }
  return token.length == 1 ? token.toUpperCase() : token;
}

// `Mod++` is Mod and the plus key, and a lone `+` is the plus key: a `+` that
// has nothing after it is a key, not a joiner.
List<String> _splitChord(String chord) {
  if (chord == '+') {
    return <String>['+'];
  }
  final bool plusKey = chord.endsWith('++');
  final String body = plusKey ? chord.substring(0, chord.length - 2) : chord;
  final List<String> keys =
      body.split('+').where((String token) => token.isNotEmpty).toList();
  return plusKey ? <String>[...keys, '+'] : keys;
}

/// Resolve the shortcut platform from [defaultTargetPlatform]: macOS and iOS
/// are [KunShortcutPlatform.apple].
KunShortcutPlatform kunShortcutPlatform([TargetPlatform? platform]) {
  final TargetPlatform resolved = platform ?? defaultTargetPlatform;
  return resolved == TargetPlatform.iOS || resolved == TargetPlatform.macOS
      ? KunShortcutPlatform.apple
      : KunShortcutPlatform.other;
}

/// Parse a shortcut into its chords of canonical key names, `Mod` unresolved:
/// `'Shift+cmd+Z'` → `[['Shift', 'Meta', 'Z']]`, `'G G'` → `[['G'], ['G']]`.
List<List<String>> parseKunShortcut(String keys) {
  return keys
      .trim()
      .split(RegExp(r'\s+'))
      .where((String chord) => chord.isNotEmpty)
      .map(
        (String chord) =>
            _splitChord(chord).map(_canonicalKey).toList(growable: false),
      )
      .where((List<String> chord) => chord.isNotEmpty)
      .toList(growable: false);
}

/// Resolve a shortcut for one platform: `Mod` becomes Meta on Apple and
/// Control elsewhere, repeated modifiers collapse, modifiers are sorted into
/// the platform's order, and every key carries its label and spoken name.
List<List<KunShortcutKey>> resolveKunShortcut(
  String keys,
  KunShortcutPlatform platform,
) {
  final List<String> order = _modifierOrder[platform]!;
  return parseKunShortcut(keys).map((List<String> chord) {
    final List<String> resolved = chord
        .map(
          (String key) => key == 'Mod'
              ? (platform == KunShortcutPlatform.apple ? 'Meta' : 'Control')
              : key,
        )
        .toList();
    final List<String> modifiers =
        order.where(resolved.contains).toList(growable: false);
    final List<String> rest = <String>[
      for (int i = 0; i < resolved.length; i++)
        if (!order.contains(resolved[i]) && resolved.indexOf(resolved[i]) == i)
          resolved[i],
    ];
    return <KunShortcutKey>[
      for (final String key in <String>[...modifiers, ...rest])
        _resolveKey(key, platform),
    ];
  }).toList(growable: false);
}

KunShortcutKey _resolveKey(String key, KunShortcutPlatform platform) {
  final _KeyDisplay? named = _named[key];
  if (named != null) {
    return KunShortcutKey(
      key: key,
      label: named.labelFor(platform),
      spoken: named.spoken(platform),
    );
  }
  return KunShortcutKey(key: key, label: key);
}

/// One-line form, as a menu shows it: `⇧⌘Z` on Apple (no joiner, the macOS
/// menu convention) and `Ctrl+Shift+Z` elsewhere; chords of a sequence are
/// separated by a space.
String formatKunShortcut(String keys, KunShortcutPlatform platform) {
  return resolveKunShortcut(keys, platform)
      .map(
        (List<KunShortcutKey> chord) => chord
            .map((KunShortcutKey key) => key.label)
            .join(platform == KunShortcutPlatform.apple ? '' : '+'),
      )
      .join(' ');
}

/// What a screen reader should hear: `Command Shift Z`, chords of a sequence
/// joined by the locale's "then". [name] maps a spoken key to its word.
String speakKunShortcut(
  List<List<KunShortcutKey>> sequence,
  String Function(KunKbdKeyName key) name,
  String then,
) {
  return sequence
      .map(
        (List<KunShortcutKey> chord) => chord
            .map(
              (KunShortcutKey key) =>
                  key.spoken != null ? name(key.spoken!) : key.label,
            )
            .join(' '),
      )
      .join(' $then ');
}
