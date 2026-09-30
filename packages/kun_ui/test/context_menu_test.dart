import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/dismiss_layers.dart';

Finder get menu => find.byKey(const ValueKey<String>('KunContextMenu.menu'));
Finder row(String key) =>
    find.byKey(ValueKey<String>('KunContextMenu.item.$key'));

const List<KunContextMenuItem> items = <KunContextMenuItem>[
  KunContextMenuItem(key: 'edit', label: 'Edit'),
  KunContextMenuItem(key: 'share', label: 'Share', disabled: true),
  KunContextMenuItem(key: 'move', label: 'Move'),
  KunContextMenuItem(key: 'delete', label: 'Delete', color: KunUIColor.danger),
];

class _Host extends StatefulWidget {
  const _Host({
    this.startVisible = true,
    this.position = Offset.zero,
    this.padding = 12,
    this.width = 192,
    this.menuItems = items,
    this.onSelected,
    this.onClose,
    this.priorFocus,
  });

  final bool startVisible;
  final Offset position;
  final double padding;
  final double width;
  final List<KunContextMenuItem> menuItems;
  final ValueChanged<KunContextMenuItem>? onSelected;
  final VoidCallback? onClose;
  final FocusNode? priorFocus;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late bool _visible = widget.startVisible;

  @override
  void didUpdateWidget(covariant _Host oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startVisible != widget.startVisible) {
      _visible = widget.startVisible;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        if (widget.priorFocus != null)
          Focus(
            focusNode: widget.priorFocus,
            child: const SizedBox(width: 12, height: 12),
          ),
        KunContextMenu(
          visible: _visible,
          items: widget.menuItems,
          position: widget.position,
          padding: widget.padding,
          width: widget.width,
          onSelected: widget.onSelected,
          onClose: () {
            widget.onClose?.call();
            setState(() => _visible = false);
          },
        ),
      ],
    );
  }
}

Widget wrap(Widget child, {bool webEnter = false, KunUIConfig? config}) {
  Widget home = child;
  if (webEnter) {
    home = Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
      },
      child: home,
    );
  }
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

void setView(
  WidgetTester tester,
  Size size, {
  FakeViewPadding padding = FakeViewPadding.zero,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
}

Future<void> pumpHost(
  WidgetTester tester,
  Widget host, {
  bool webEnter = false,
  KunUIConfig? config,
}) async {
  await tester.pumpWidget(
    wrap(
      KeyedSubtree(key: UniqueKey(), child: host),
      webEnter: webEnter,
      config: config,
    ),
  );
  await tester.pumpAndSettle();
}

bool focused(WidgetTester tester, String key) {
  return tester
      .widget<Focus>(
        find.descendant(of: row(key), matching: find.byType(Focus)),
      )
      .focusNode!
      .hasPrimaryFocus;
}

void main() {
  test('const KunDropdownItem is a KunContextMenuItem', () {
    const KunDropdownItem item = KunDropdownItem(key: 'a', label: 'A');
    expect(item, isA<KunContextMenuItem>());
    expect(item.key, 'a');
    expect(item.label, 'A');
  });

  testWidgets('opens at the given position', (tester) async {
    setView(tester, const Size(800, 600));
    await pumpHost(tester, const _Host(position: Offset(120, 80)));

    expect(menu, findsOneWidget);
    final Rect box = tester.getRect(menu);
    expect(box.left, moreOrLessEquals(120, epsilon: 1));
    expect(box.top, moreOrLessEquals(80, epsilon: 1));
  });

  testWidgets('clamps at each of the four edges', (tester) async {
    setView(tester, const Size(800, 600));
    const List<Offset> corners = <Offset>[
      Offset.zero,
      Offset(800, 0),
      Offset(0, 600),
      Offset(800, 600),
    ];
    for (final Offset at in corners) {
      await pumpHost(tester, _Host(position: at));
      final Rect box = tester.getRect(menu);
      expect(box.left, greaterThanOrEqualTo(12 - 0.5));
      expect(box.top, greaterThanOrEqualTo(12 - 0.5));
      expect(box.right, lessThanOrEqualTo(800 - 12 + 0.5));
      expect(box.bottom, lessThanOrEqualTo(600 - 12 + 0.5));
    }

    await pumpHost(tester, const _Host());
    final Rect origin = tester.getRect(menu);
    expect(origin.left, moreOrLessEquals(12, epsilon: 0.5));
    expect(origin.top, moreOrLessEquals(12, epsilon: 0.5));

    await pumpHost(tester, const _Host(position: Offset(800, 600)));
    final Rect far = tester.getRect(menu);
    expect(far.right, moreOrLessEquals(800 - 12, epsilon: 0.5));
    expect(far.bottom, moreOrLessEquals(600 - 12, epsilon: 0.5));
  });

  testWidgets('padding is the clamp margin', (tester) async {
    setView(tester, const Size(800, 600));
    await pumpHost(tester, const _Host(padding: 24));
    final Rect box = tester.getRect(menu);
    expect(box.left, moreOrLessEquals(24, epsilon: 0.5));
    expect(box.top, moreOrLessEquals(24, epsilon: 0.5));
  });

  testWidgets('the first enabled item takes focus on open', (tester) async {
    setView(tester, const Size(800, 600));
    await pumpHost(tester, const _Host());
    expect(focused(tester, 'edit'), isTrue);
  });

  testWidgets('the arrow keys skip a disabled row and wrap', (tester) async {
    setView(tester, const Size(800, 600));
    await pumpHost(tester, const _Host());

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(tester, 'move'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(tester, 'delete'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(tester, 'edit'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(focused(tester, 'delete'), isTrue);
  });

  testWidgets('Home and End jump to the ends', (tester) async {
    setView(tester, const Size(800, 600));
    await pumpHost(tester, const _Host());

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(focused(tester, 'delete'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(focused(tester, 'edit'), isTrue);
  });

  testWidgets('Enter selects the focused row and closes', (tester) async {
    setView(tester, const Size(800, 600));
    KunContextMenuItem? picked;
    int closed = 0;
    await pumpHost(
      tester,
      _Host(
        onSelected: (KunContextMenuItem item) => picked = item,
        onClose: () => closed++,
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(picked?.key, 'edit');
    expect(closed, 1);
    expect(menu, findsNothing);
  });

  testWidgets('Space selects, and the web Enter map selects too', (
    tester,
  ) async {
    setView(tester, const Size(800, 600));
    KunContextMenuItem? picked;
    await pumpHost(
      tester,
      _Host(onSelected: (KunContextMenuItem item) => picked = item),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(picked?.key, 'edit');
    expect(menu, findsNothing);

    picked = null;
    await pumpHost(
      tester,
      _Host(onSelected: (KunContextMenuItem item) => picked = item),
      webEnter: true,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(picked?.key, 'edit');

    picked = null;
    await pumpHost(
      tester,
      _Host(onSelected: (KunContextMenuItem item) => picked = item),
      webEnter: true,
    );
    Actions.invoke<ButtonActivateIntent>(
      tester.element(
        find.descendant(of: row('edit'), matching: find.byType(Focus)),
      ),
      const ButtonActivateIntent(),
    );
    await tester.pumpAndSettle();
    expect(picked?.key, 'edit');
  });

  testWidgets('Escape and Tab close it', (tester) async {
    setView(tester, const Size(800, 600));
    int closed = 0;
    await pumpHost(tester, _Host(onClose: () => closed++));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(closed, 1);

    closed = 0;
    await pumpHost(tester, _Host(onClose: () => closed++));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(closed, 1);
  });

  testWidgets('a tap picks a row, and a disabled row picks nothing', (
    tester,
  ) async {
    setView(tester, const Size(800, 600));
    KunContextMenuItem? picked;
    int closed = 0;
    await pumpHost(
      tester,
      _Host(
        onSelected: (KunContextMenuItem item) => picked = item,
        onClose: () => closed++,
      ),
    );

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(menu, findsOneWidget);
    expect(closed, 0);

    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    expect(picked?.key, 'move');
    expect(menu, findsNothing);
    expect(closed, 1);
  });

  testWidgets('a row with an href hands it to the config', (tester) async {
    setView(tester, const Size(800, 600));
    final List<String> visited = <String>[];
    await pumpHost(
      tester,
      const _Host(
        menuItems: <KunContextMenuItem>[
          KunContextMenuItem(key: 'profile', label: 'Profile', href: '/me'),
        ],
      ),
      config: KunUIConfig(
        navigate: (BuildContext context, String href) => visited.add(href),
      ),
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(visited, <String>['/me']);
  });

  testWidgets('focus returns to where it was on close', (tester) async {
    setView(tester, const Size(800, 600));
    final FocusNode prior = FocusNode();
    addTearDown(prior.dispose);
    await tester.pumpWidget(
      wrap(_Host(priorFocus: prior, startVisible: false)),
    );
    prior.requestFocus();
    await tester.pump();
    expect(prior.hasPrimaryFocus, isTrue);

    await tester.pumpWidget(wrap(_Host(priorFocus: prior)));
    await tester.pump();
    await tester.pump();
    expect(menu, findsOneWidget);
    expect(prior.hasPrimaryFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(prior.hasPrimaryFocus, isTrue);
  });

  testWidgets('onClose fires for a tap outside and a back gesture', (
    tester,
  ) async {
    setView(tester, const Size(800, 600));
    int closed = 0;
    await pumpHost(
      tester,
      _Host(position: const Offset(200, 200), onClose: () => closed++),
    );

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(closed, 1);
    expect(KunDismissLayers.debugLayers, isEmpty);

    closed = 0;
    await pumpHost(
      tester,
      _Host(position: const Offset(200, 200), onClose: () => closed++),
    );
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(closed, 1);
    expect(KunDismissLayers.debugLayers, isEmpty);
  });

  testWidgets('an empty list never opens', (tester) async {
    setView(tester, const Size(800, 600));
    await pumpHost(tester, const _Host(menuItems: <KunContextMenuItem>[]));
    expect(menu, findsNothing);
  });

  testWidgets('the menu never narrows past width', (tester) async {
    setView(tester, const Size(800, 600));
    await pumpHost(tester, const _Host(width: 240));
    expect(tester.getRect(menu).width, moreOrLessEquals(240, epsilon: 0.5));
  });

  testWidgets('opens from a real KunButton onPressed', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const _ButtonHost()));
    expect(menu, findsNothing);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(menu, findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('the panel is a menu of labelled menu items', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    setView(tester, const Size(800, 600));
    await pumpHost(tester, const _Host());

    final SemanticsData panel = tester.getSemantics(menu).getSemanticsData();
    expect(panel.role, SemanticsRole.menu);

    final SemanticsData edit =
        tester.getSemantics(find.text('Edit')).getSemanticsData();
    expect(edit.role, SemanticsRole.menuItem);
    expect(edit.label, 'Edit');
    expect(edit.flagsCollection.isEnabled, isNot(Tristate.isFalse));

    final SemanticsData share =
        tester.getSemantics(find.text('Share')).getSemanticsData();
    expect(share.role, SemanticsRole.menuItem);
    expect(share.label, 'Share');
    expect(share.flagsCollection.isEnabled, Tristate.isFalse);
    semantics.dispose();
  });
}

class _ButtonHost extends StatefulWidget {
  const _ButtonHost();

  @override
  State<_ButtonHost> createState() => _ButtonHostState();
}

class _ButtonHostState extends State<_ButtonHost> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return KunContextMenu(
      visible: _visible,
      items: items,
      position: const Offset(80, 80),
      onClose: () => setState(() => _visible = false),
      child: KunButton(
        onPressed: () => setState(() => _visible = true),
        child: const Text('Open'),
      ),
    );
  }
}
