import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/dismiss_layers.dart';

Finder get menu => find.byKey(const ValueKey<String>('KunDropdown.menu'));
Finder row(String key) => find.byKey(ValueKey<String>('KunDropdown.item.$key'));

const List<KunDropdownItem> items = <KunDropdownItem>[
  KunDropdownItem(key: 'edit', label: 'Edit'),
  KunDropdownItem(key: 'share', label: 'Share', disabled: true),
  KunDropdownItem(key: 'move', label: 'Move'),
  KunDropdownItem(key: 'delete', label: 'Delete', color: KunUIColor.danger),
];

Widget wrap(Widget child, {KunUIConfig? config, Alignment? alignment}) {
  Widget home = Align(alignment: alignment ?? Alignment.center, child: child);
  if (config != null) {
    home = KunUIConfigScope(config: config, child: home);
  }
  return KunTheme(
    data: KunThemeData.light(),
    child: WidgetsApp(
      color: KunColors.black,
      debugShowCheckedModeBanner: false,
      home: home,
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
  );
}

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

KunDropdown dropdown({
  List<KunDropdownItem> menuItems = items,
  bool disabled = false,
  double minWidth = 192,
  ValueChanged<KunDropdownItem>? onSelected,
  VoidCallback? onOpen,
  VoidCallback? onClose,
}) {
  return KunDropdown(
    items: menuItems,
    disabled: disabled,
    minWidth: minWidth,
    onSelected: onSelected,
    onOpen: onOpen,
    onClose: onClose,
    trigger: const SizedBox(width: 80, height: 32, child: Text('actions')),
  );
}

bool focused(WidgetTester tester, String key) {
  return tester
      .widget<Focus>(
          find.descendant(of: row(key), matching: find.byType(Focus)))
      .focusNode!
      .hasPrimaryFocus;
}

Future<void> openWithTap(WidgetTester tester) async {
  await tester.tap(find.text('actions'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a tap opens the menu and a second tap closes it',
      (tester) async {
    setView(tester, const Size(800, 600));
    int opened = 0;
    int closed = 0;
    await tester.pumpWidget(
      wrap(dropdown(onOpen: () => opened++, onClose: () => closed++)),
    );

    expect(menu, findsNothing);
    await openWithTap(tester);
    expect(menu, findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(opened, 1);

    await tester.tap(find.text('actions'));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(closed, 1);
    expect(KunDismissLayers.debugLayers, isEmpty);
  });

  testWidgets('a trigger with its own tap handler still opens the menu',
      (tester) async {
    setView(tester, const Size(800, 600));
    int pressed = 0;
    await tester.pumpWidget(
      wrap(
        KunDropdown(
          items: items,
          trigger: KunButton(
            onPressed: () => pressed++,
            child: const Text('actions'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('actions'));
    await tester.pumpAndSettle();
    expect(menu, findsOneWidget);
    expect(pressed, 1);
  });

  testWidgets('an empty or disabled dropdown never opens', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(dropdown(menuItems: const <KunDropdownItem>[])),
    );
    await openWithTap(tester);
    expect(menu, findsNothing);

    await tester.pumpWidget(wrap(dropdown(disabled: true)));
    await openWithTap(tester);
    expect(menu, findsNothing);
  });

  testWidgets('ArrowDown opens on the first row and ArrowUp on the last',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(dropdown()));

    await tester.tap(find.text('actions'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    Focus.of(
      tester.element(find.text('actions')),
      scopeOk: true,
    ).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(menu, findsOneWidget);
    expect(focused(tester, 'edit'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(focused(tester, 'delete'), isTrue);
  });

  testWidgets('the arrow keys skip a disabled row and wrap', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(dropdown()));
    await openWithTap(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(tester, 'edit'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(tester, 'move'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(tester, 'delete'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(tester, 'edit'), isTrue);
  });

  testWidgets('Home and End jump to the ends', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(dropdown()));
    await openWithTap(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(focused(tester, 'delete'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(focused(tester, 'edit'), isTrue);
  });

  testWidgets('type-ahead jumps to the row that starts with what was typed',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(dropdown()));
    await openWithTap(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pump();
    expect(focused(tester, 'delete'), isTrue);
  });

  testWidgets('Enter selects the focused row, closes and returns focus',
      (tester) async {
    setView(tester, const Size(800, 600));
    KunDropdownItem? picked;
    await tester.pumpWidget(
      wrap(dropdown(onSelected: (KunDropdownItem item) => picked = item)),
    );
    await openWithTap(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(picked?.key, 'edit');
    expect(menu, findsNothing);
    expect(
      Focus.of(tester.element(find.text('actions')), scopeOk: true)
          .hasPrimaryFocus,
      isTrue,
    );
  });

  testWidgets('a tap picks a row, and a disabled row picks nothing',
      (tester) async {
    setView(tester, const Size(800, 600));
    KunDropdownItem? picked;
    await tester.pumpWidget(
      wrap(dropdown(onSelected: (KunDropdownItem item) => picked = item)),
    );

    await openWithTap(tester);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(menu, findsOneWidget);

    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    expect(picked?.key, 'move');
    expect(menu, findsNothing);
  });

  testWidgets('Escape and Tab close it', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(dropdown()));

    await openWithTap(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(menu, findsNothing);

    await openWithTap(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
  });

  testWidgets('a row with an href hands it to the config', (tester) async {
    setView(tester, const Size(800, 600));
    final List<String> visited = <String>[];
    await tester.pumpWidget(
      wrap(
        dropdown(
          menuItems: const <KunDropdownItem>[
            KunDropdownItem(key: 'profile', label: 'Profile', href: '/me'),
          ],
        ),
        config: KunUIConfig(
          navigate: (BuildContext context, String href) => visited.add(href),
        ),
      ),
    );

    await openWithTap(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(visited, <String>['/me']);
  });

  testWidgets('a tap outside and a back gesture both close it', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(dropdown()));

    await openWithTap(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);

    await openWithTap(tester);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(find.text('actions'), findsOneWidget);
    expect(KunDismissLayers.debugLayers, isEmpty);
  });

  testWidgets('the menu shrink-wraps its rows, never past minWidth',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(dropdown(minWidth: 240)));

    await openWithTap(tester);
    // The web's menu is absolutely positioned: minWidth is a floor, not the
    // width it takes. A stretched Column once made it as wide as the view.
    expect(tester.getRect(menu).width, moreOrLessEquals(240, epsilon: 0.5));
  });

  testWidgets('a row wider than minWidth widens the menu, not the view',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        dropdown(
          menuItems: const <KunDropdownItem>[
            KunDropdownItem(
              key: 'long',
              label: 'A label far wider than the minimum width of the menu',
            ),
          ],
        ),
      ),
    );

    await openWithTap(tester);
    final double wide = tester.getRect(menu).width;
    expect(wide, greaterThan(192));
    expect(wide, lessThan(800));
  });

  testWidgets('disposing an open dropdown leaves no dismiss layer behind',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(dropdown()));
    await openWithTap(tester);
    expect(KunDismissLayers.debugLayers, hasLength(1));

    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(KunDismissLayers.debugLayers, isEmpty);
  });

  testWidgets('the trigger is an expandable button and the rows are menu items',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(dropdown()));

    final SemanticsNode trigger = tester.getSemantics(find.text('actions'));
    expect(trigger.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(
      trigger.getSemanticsData().flagsCollection.isExpanded,
      Tristate.isFalse,
    );

    await openWithTap(tester);
    final SemanticsData edit =
        tester.getSemantics(find.text('Edit')).getSemanticsData();
    expect(edit.role, SemanticsRole.menuItem);
    expect(edit.label, 'Edit');
    final SemanticsData share =
        tester.getSemantics(find.text('Share')).getSemanticsData();
    expect(share.flagsCollection.isEnabled, Tristate.isFalse);
    semantics.dispose();
  });
}
