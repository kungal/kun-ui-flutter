import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/src/components/menu_panel.dart';
import 'package:kun_ui/src/foundation/shortcut.dart';

void main() {
  test('parse: chords, sequences, aliases, case', () {
    expect(parseKunShortcut('Mod+K'), <List<String>>[
      <String>['Mod', 'K'],
    ]);
    expect(parseKunShortcut('cmd+shift+p'), <List<String>>[
      <String>['Meta', 'Shift', 'P'],
    ]);
    expect(parseKunShortcut('G G'), <List<String>>[
      <String>['G'],
      <String>['G'],
    ]);
    expect(parseKunShortcut('  ctrl+k   ctrl+s '), <List<String>>[
      <String>['Control', 'K'],
      <String>['Control', 'S'],
    ]);
    expect(parseKunShortcut('esc'), <List<String>>[
      <String>['Escape'],
    ]);
    expect(parseKunShortcut('f5'), <List<String>>[
      <String>['F5'],
    ]);
    expect(parseKunShortcut(''), isEmpty);
  });

  test('parse: the plus key', () {
    expect(parseKunShortcut('Mod++'), <List<String>>[
      <String>['Mod', '+'],
    ]);
    expect(parseKunShortcut('+'), <List<String>>[
      <String>['+'],
    ]);
    expect(parseKunShortcut('Mod+Plus'), <List<String>>[
      <String>['Mod', '+'],
    ]);
  });

  test('Mod is Command on Apple and Ctrl elsewhere', () {
    expect(formatKunShortcut('Mod+K', KunShortcutPlatform.apple), '⌘K');
    expect(formatKunShortcut('Mod+K', KunShortcutPlatform.other), 'Ctrl+K');
  });

  test('modifiers sort into the platform order whatever the input order', () {
    expect(formatKunShortcut('Mod+Shift+Z', KunShortcutPlatform.apple), '⇧⌘Z');
    expect(formatKunShortcut('Shift+Mod+Z', KunShortcutPlatform.apple), '⇧⌘Z');
    expect(
      formatKunShortcut('Shift+Mod+Z', KunShortcutPlatform.other),
      'Ctrl+Shift+Z',
    );
    expect(
      formatKunShortcut('Shift+Alt+Ctrl+Meta+X', KunShortcutPlatform.apple),
      '⌃⌥⇧⌘X',
    );
    expect(
      formatKunShortcut('Shift+Alt+Ctrl+Meta+X', KunShortcutPlatform.other),
      'Ctrl+Win+Alt+Shift+X',
    );
  });

  test('a repeated modifier collapses once Mod is resolved', () {
    expect(
      formatKunShortcut('Ctrl+Mod+K', KunShortcutPlatform.other),
      'Ctrl+K',
    );
    expect(formatKunShortcut('Ctrl+Mod+K', KunShortcutPlatform.apple), '⌃⌘K');
  });

  test('named keys', () {
    expect(
      formatKunShortcut('Alt+ArrowUp', KunShortcutPlatform.apple),
      '⌥↑',
    );
    expect(
      formatKunShortcut('Alt+ArrowUp', KunShortcutPlatform.other),
      'Alt+↑',
    );
    expect(
      formatKunShortcut('Shift+Delete', KunShortcutPlatform.other),
      'Shift+Del',
    );
    expect(formatKunShortcut('Mod+Enter', KunShortcutPlatform.apple), '⌘↩');
    expect(formatKunShortcut('Escape', KunShortcutPlatform.apple), 'Esc');
    expect(formatKunShortcut('Mod+Space', KunShortcutPlatform.apple), '⌘Space');
    expect(formatKunShortcut('Mod++', KunShortcutPlatform.other), 'Ctrl++');
  });

  test('a sequence keeps its chords apart', () {
    expect(
      formatKunShortcut('Mod+K Mod+S', KunShortcutPlatform.apple),
      '⌘K ⌘S',
    );
    expect(
      formatKunShortcut('Mod+K Mod+S', KunShortcutPlatform.other),
      'Ctrl+K Ctrl+S',
    );
  });

  test('each key carries its label and spoken name', () {
    expect(
      resolveKunShortcut('Mod+Alt+K', KunShortcutPlatform.apple),
      <List<KunShortcutKey>>[
        <KunShortcutKey>[
          const KunShortcutKey(
            key: 'Alt',
            label: '⌥',
            spoken: KunKbdKeyName.option,
          ),
          const KunShortcutKey(
            key: 'Meta',
            label: '⌘',
            spoken: KunKbdKeyName.command,
          ),
          const KunShortcutKey(key: 'K', label: 'K'),
        ],
      ],
    );
    expect(
      resolveKunShortcut('Mod+Alt+K', KunShortcutPlatform.other),
      <List<KunShortcutKey>>[
        <KunShortcutKey>[
          const KunShortcutKey(
            key: 'Control',
            label: 'Ctrl',
            spoken: KunKbdKeyName.control,
          ),
          const KunShortcutKey(
            key: 'Alt',
            label: 'Alt',
            spoken: KunKbdKeyName.alt,
          ),
          const KunShortcutKey(key: 'K', label: 'K'),
        ],
      ],
    );
  });

  test('speak: spoken names, chords joined by "then"', () {
    const Map<KunKbdKeyName, String> names = <KunKbdKeyName, String>{
      KunKbdKeyName.command: 'Command',
      KunKbdKeyName.shift: 'Shift',
      KunKbdKeyName.control: 'Control',
    };
    String name(KunKbdKeyName key) => names[key] ?? key.name;
    expect(
      speakKunShortcut(
        resolveKunShortcut('Mod+Shift+Z', KunShortcutPlatform.apple),
        name,
        'then',
      ),
      'Shift Command Z',
    );
    expect(
      speakKunShortcut(
        resolveKunShortcut('Mod+K Mod+S', KunShortcutPlatform.other),
        name,
        'then',
      ),
      'Control K then Control S',
    );
  });

  test('menu separators: leading, trailing and doubled ones are dropped', () {
    const KunMenuSeparator s = KunMenuSeparator();
    const KunContextMenuItem a = KunContextMenuItem(key: 'a', label: 'A');
    const KunContextMenuItem b = KunContextMenuItem(key: 'b', label: 'B');
    expect(
      normalizeKunMenuSeparators(<KunMenuEntry>[s, a, s, s, b, s]),
      <KunMenuEntry>[a, s, b],
    );
    expect(normalizeKunMenuSeparators(<KunMenuEntry>[s, s]), isEmpty);
    expect(
      normalizeKunMenuSeparators(<KunMenuEntry>[a, b]),
      <KunMenuEntry>[a, b],
    );
    expect(normalizeKunMenuSeparators(const <KunMenuEntry>[]), isEmpty);
  });
}
