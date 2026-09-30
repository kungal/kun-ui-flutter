import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/components/kbd.dart' show kunSpeakShortcut;
import 'package:kun_ui/src/components/menu_panel.dart';

Finder contextMenu() =>
    find.byKey(const ValueKey<String>('KunContextMenu.menu'));
Finder dropdownMenu() => find.byKey(const ValueKey<String>('KunDropdown.menu'));
Finder contextRow(String key) =>
    find.byKey(ValueKey<String>('KunContextMenu.item.$key'));
Finder dropdownRow(String key) =>
    find.byKey(ValueKey<String>('KunDropdown.item.$key'));
Finder contextSubmenu() =>
    find.byKey(const ValueKey<String>('KunContextMenu.item.submenu'));
Finder dropdownSubmenu() =>
    find.byKey(const ValueKey<String>('KunDropdown.item.submenu'));

const List<KunMenuEntry> _entries = <KunMenuEntry>[
  KunContextMenuItem(key: 'reply', label: 'Reply', shortcut: 'R'),
  KunContextMenuItem(key: 'copy', label: 'Copy', shortcut: 'Mod+C'),
  KunMenuSeparator(),
  KunContextMenuItem(
    key: 'share',
    label: 'Share',
    children: <KunMenuEntry>[
      KunContextMenuItem(key: 'share-link', label: 'Copy link'),
      KunContextMenuItem(key: 'share-image', label: 'Share image'),
    ],
  ),
  KunMenuSeparator(),
  KunContextMenuItem(
    key: 'delete',
    label: 'Delete',
    color: KunUIColor.danger,
    shortcut: 'Mod+Backspace',
  ),
];

class _ContextHost extends StatefulWidget {
  const _ContextHost({
    this.entries = _entries,
    this.onSelected,
    this.onClose,
  });

  final List<KunMenuEntry> entries;
  final ValueChanged<KunContextMenuItem>? onSelected;
  final VoidCallback? onClose;

  @override
  State<_ContextHost> createState() => _ContextHostState();
}

class _ContextHostState extends State<_ContextHost> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    return KunContextMenu(
      visible: _visible,
      items: widget.entries,
      position: const Offset(80, 80),
      onSelected: widget.onSelected,
      onClose: () {
        widget.onClose?.call();
        setState(() => _visible = false);
      },
      child: KunButton(
        onPressed: () => setState(() => _visible = true),
        child: const Text('Open'),
      ),
    );
  }
}

Widget wrap(Widget child, {Alignment alignment = Alignment.centerLeft}) {
  return KunTheme(
    data: KunThemeData.light(),
    child: KunMessagesScope(
      messages: KunMessages.en,
      child: WidgetsApp(
        color: KunColors.black,
        debugShowCheckedModeBanner: false,
        home: Align(alignment: alignment, child: child),
        pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
          return PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return builder(context);
            },
          );
        },
      ),
    ),
  );
}

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

bool focused(WidgetTester tester, Finder row) {
  return tester
      .widget<Focus>(find.descendant(of: row, matching: find.byType(Focus)))
      .focusNode!
      .hasPrimaryFocus;
}

Future<TestGesture> mouseAt(WidgetTester tester, Offset location) async {
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await tester.pump();
  await gesture.moveTo(location);
  await tester.pump();
  return gesture;
}

KunDropdown dropdown({
  List<KunMenuEntry> items = _entries,
  ValueChanged<KunDropdownItem>? onSelected,
  VoidCallback? onClose,
}) {
  return KunDropdown(
    items: items,
    onSelected: onSelected,
    onClose: onClose,
    trigger: KunButton(
      onPressed: () {},
      child: const Text('Actions'),
    ),
  );
}

void main() {
  test('menu separators: leading, trailing and doubled ones are dropped', () {
    const KunMenuSeparator s = KunMenuSeparator();
    const KunContextMenuItem a = KunContextMenuItem(key: 'a', label: 'A');
    const KunContextMenuItem b = KunContextMenuItem(key: 'b', label: 'B');
    expect(
      normalizeKunMenuSeparators(<KunMenuEntry>[s, a, s, s, b, s]),
      <KunMenuEntry>[a, s, b],
    );
    expect(
      normalizeKunMenuSeparators(<KunMenuEntry>[s, s]),
      isEmpty,
    );
    expect(
      normalizeKunMenuSeparators(<KunMenuEntry>[a, b]),
      <KunMenuEntry>[a, b],
    );
    expect(normalizeKunMenuSeparators(const <KunMenuEntry>[]), isEmpty);
  });

  testWidgets('separators render once between groups', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const _ContextHost()));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (Widget w) => w.runtimeType.toString() == '_KunMenuSeparatorLine',
      ),
      findsNWidgets(2),
    );
    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('a shortcut sits at the end and is the row hint', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const _ContextHost()));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: contextRow('copy'),
        matching: find.byType(KunKbd),
      ),
      findsOneWidget,
    );
    final SemanticsData copy =
        tester.getSemantics(find.text('Copy')).getSemanticsData();
    expect(copy.label, 'Copy');
    expect(copy.hint, kunSpeakShortcut('Mod+C', KunMessages.en));
    semantics.dispose();
  });

  testWidgets('a mouse hover opens a submenu after 100ms', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const _ContextHost()));
    await tester.pumpAndSettle();
    expect(contextSubmenu(), findsNothing);

    await mouseAt(tester, tester.getCenter(find.text('Share')));
    expect(contextSubmenu(), findsNothing);
    await tester.pump(const Duration(milliseconds: 99));
    expect(contextSubmenu(), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(contextSubmenu(), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('Share image'), findsOneWidget);
  });

  testWidgets('→, Enter and Space open a submenu and focus its first item',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const _ContextHost()));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(tester, contextRow('share')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(contextSubmenu(), findsOneWidget);
    expect(focused(tester, contextRow('share-link')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(contextSubmenu(), findsNothing);
    expect(focused(tester, contextRow('share')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(focused(tester, contextRow('share-link')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(focused(tester, contextRow('share-link')), isTrue);
  });

  testWidgets('a tap opens a submenu and a second tap leaves it open',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const _ContextHost()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(contextSubmenu(), findsOneWidget);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(contextSubmenu(), findsOneWidget);
    expect(contextMenu(), findsOneWidget);
  });

  testWidgets('← and Escape close one level; Tab closes the tree',
      (tester) async {
    setView(tester, const Size(800, 600));
    int closed = 0;
    await tester.pumpWidget(
      wrap(_ContextHost(onClose: () => closed++)),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(focused(tester, contextRow('share-link')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(contextSubmenu(), findsNothing);
    expect(focused(tester, contextRow('share')), isTrue);
    expect(closed, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(contextMenu(), findsNothing);
    expect(closed, 1);
  });

  testWidgets('leaving the submenu starts a 300ms grace', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const _ContextHost()));
    await tester.pumpAndSettle();

    final TestGesture gesture =
        await mouseAt(tester, tester.getCenter(find.text('Share')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(contextSubmenu(), findsOneWidget);

    await gesture.moveTo(tester.getCenter(find.text('Copy link')));
    await tester.pump();
    expect(contextSubmenu(), findsOneWidget);

    await gesture.moveTo(const Offset(700, 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 299));
    expect(contextSubmenu(), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(contextSubmenu(), findsNothing);
  });

  testWidgets('returning to the trigger within the grace keeps the submenu',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const _ContextHost()));
    await tester.pumpAndSettle();

    final TestGesture gesture =
        await mouseAt(tester, tester.getCenter(find.text('Share')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    await gesture.moveTo(tester.getCenter(find.text('Copy link')));
    await tester.pump();
    await gesture.moveTo(const Offset(700, 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.text('Share')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(contextSubmenu(), findsOneWidget);
  });

  testWidgets('a parent with no items or only separators is disabled',
      (tester) async {
    setView(tester, const Size(800, 600));
    KunContextMenuItem? picked;
    await tester.pumpWidget(
      wrap(
        _ContextHost(
          onSelected: (KunContextMenuItem item) => picked = item,
          entries: const <KunMenuEntry>[
            KunContextMenuItem(
              key: 'empty',
              label: 'Empty',
              children: <KunMenuEntry>[],
            ),
            KunContextMenuItem(
              key: 'seps',
              label: 'Seps',
              children: <KunMenuEntry>[KunMenuSeparator()],
            ),
            KunContextMenuItem(key: 'ok', label: 'Ok'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Empty'));
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(contextSubmenu(), findsNothing);

    await tester.tap(find.text('Seps'));
    await tester.pumpAndSettle();
    expect(picked, isNull);

    final SemanticsData empty =
        tester.getSemantics(find.text('Empty')).getSemanticsData();
    expect(empty.flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('selecting a submenu item emits it and closes the tree',
      (tester) async {
    setView(tester, const Size(800, 600));
    KunContextMenuItem? picked;
    int closed = 0;
    await tester.pumpWidget(
      wrap(
        _ContextHost(
          onSelected: (KunContextMenuItem item) => picked = item,
          onClose: () => closed++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(picked?.key, 'share-link');
    expect(closed, 1);
    expect(contextMenu(), findsNothing);
  });

  testWidgets('a parent with children never fires select', (tester) async {
    setView(tester, const Size(800, 600));
    KunContextMenuItem? picked;
    await tester.pumpWidget(
      wrap(
          _ContextHost(onSelected: (KunContextMenuItem item) => picked = item)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(contextMenu(), findsOneWidget);
  });

  testWidgets('type-ahead jumps to the matching enabled row', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const _ContextHost()));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pump();
    expect(focused(tester, contextRow('delete')), isTrue);
  });

  testWidgets('↑ with no focused row lands on the last enabled item',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(dropdown(), alignment: Alignment.center));
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    expect(focused(tester, dropdownRow('reply')), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(focused(tester, dropdownRow('delete')), isTrue);
  });

  testWidgets('the dropdown shares separators, shortcuts and a submenu',
      (tester) async {
    setView(tester, const Size(800, 600));
    KunDropdownItem? picked;
    await tester.pumpWidget(
      wrap(
        dropdown(onSelected: (KunDropdownItem item) => picked = item),
        alignment: Alignment.centerLeft,
      ),
    );
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    expect(dropdownMenu(), findsOneWidget);
    expect(
      find.descendant(of: dropdownRow('copy'), matching: find.byType(KunKbd)),
      findsOneWidget,
    );

    await mouseAt(tester, tester.getCenter(find.text('Share')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(dropdownSubmenu(), findsOneWidget);

    await tester.tap(find.text('Share image'));
    await tester.pumpAndSettle();
    expect(picked?.key, 'share-image');
    expect(dropdownMenu(), findsNothing);
  });

  testWidgets('the parent row reports expanded while its submenu is open',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const _ContextHost()));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.text('Share'))
          .getSemanticsData()
          .flagsCollection
          .isExpanded,
      Tristate.isFalse,
    );
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.text('Share'))
          .getSemanticsData()
          .flagsCollection
          .isExpanded,
      Tristate.isTrue,
    );
    semantics.dispose();
  });
}
