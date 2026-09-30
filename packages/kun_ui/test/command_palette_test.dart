import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Finder get panel =>
    find.byKey(const ValueKey<String>('KunCommandPalette.panel'));

Finder item(Object value) => find.byKey(
      ValueKey<String>('KunCommandPalette.item.$value'),
    );

const List<KunCommandGroup> grouped = <KunCommandGroup>[
  KunCommandGroup(
    label: 'Navigate',
    items: <KunCommandItem>[
      KunCommandItem(value: 'home', label: 'Home'),
      KunCommandItem(value: 'docs', label: 'Docs', disabled: true),
      KunCommandItem(value: 'settings', label: 'Settings'),
    ],
  ),
  KunCommandGroup(
    label: 'Actions',
    items: <KunCommandItem>[
      KunCommandItem(value: 'copy', label: 'Copy link'),
    ],
  ),
];

const List<KunCommandGroup> flat = <KunCommandGroup>[
  KunCommandGroup(
    items: <KunCommandItem>[
      KunCommandItem(value: 'alpha', label: 'Alpha'),
      KunCommandItem(value: 'beta', label: 'Beta'),
    ],
  ),
];

Widget wrap(
  Widget child, {
  KunUIConfig? config,
}) {
  Widget home = child;
  if (config != null) {
    home = KunUIConfigScope(config: config, child: home);
  }
  return KunTheme(
    data: KunThemeData.light(),
    child: KunMessagesScope(
      messages: KunMessages.en,
      child: WidgetsApp(
        color: KunColors.black,
        debugShowCheckedModeBanner: false,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        },
        home: Align(alignment: Alignment.center, child: home),
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

class Host extends StatefulWidget {
  const Host({
    this.items = grouped,
    this.shortcut = KunCommandShortcut.modK,
    this.loading = false,
    this.highlight = true,
    this.emptyText,
    this.noResultText,
    this.placeholder,
    this.semanticLabel,
    this.empty,
    this.noResult,
    this.loadingBuilder,
    this.itemBuilder,
    this.onSubmitted,
    super.key,
  });

  final List<KunCommandGroup> items;
  final KunCommandShortcut shortcut;
  final bool loading;
  final bool highlight;
  final String? emptyText;
  final String? noResultText;
  final String? placeholder;
  final String? semanticLabel;
  final Widget? empty;
  final Widget? noResult;
  final Widget? loadingBuilder;
  final Widget Function(BuildContext, KunCommandItem, bool)? itemBuilder;
  final ValueChanged<String>? onSubmitted;

  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  bool open = false;
  String query = '';
  final List<KunCommandItem> selected = <KunCommandItem>[];
  final List<String> submitted = <String>[];
  String? shortcutLabel;
  String? keys;

  List<KunCommandGroup> get shown {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return widget.items;
    }
    return <KunCommandGroup>[
      for (final KunCommandGroup group in widget.items)
        KunCommandGroup(
          label: group.label,
          items: group.items
              .where(
                (KunCommandItem item) => item.label.toLowerCase().contains(q),
              )
              .toList(),
        ),
    ].where((KunCommandGroup g) => g.items.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return KunCommandPalette(
      items: shown,
      open: open,
      query: query,
      shortcut: widget.shortcut,
      loading: widget.loading,
      highlight: widget.highlight,
      emptyText: widget.emptyText,
      noResultText: widget.noResultText,
      placeholder: widget.placeholder,
      semanticLabel: widget.semanticLabel,
      empty: widget.empty,
      noResult: widget.noResult,
      loadingBuilder: widget.loadingBuilder,
      itemBuilder: widget.itemBuilder,
      onOpenChanged: (bool value) => setState(() => open = value),
      onQueryChanged: (String value) => setState(() => query = value),
      onSelected: selected.add,
      onSubmitted: (String value) {
        submitted.add(value);
        widget.onSubmitted?.call(value);
      },
      trigger: (
        BuildContext context,
        VoidCallback openPalette,
        String label,
        String chord,
      ) {
        shortcutLabel = label;
        keys = chord;
        return KunButton(
          onPressed: openPalette,
          child: const Text('Open'),
        );
      },
    );
  }
}

HostState hostOf(WidgetTester tester) =>
    tester.state<HostState>(find.byType(Host));

Future<void> openByTap(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> sendModChar(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

bool rowSelected(WidgetTester tester, Object value) {
  return tester
          .getSemantics(item(value))
          .getSemanticsData()
          .flagsCollection
          .isSelected ==
      Tristate.isTrue;
}

void main() {
  testWidgets('the shortcut toggles the palette on Apple and elsewhere',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(wrap(const Host()));

    expect(panel, findsNothing);
    await sendModChar(
      tester,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.keyK,
    );
    expect(panel, findsOneWidget);

    await sendModChar(
      tester,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.keyK,
    );
    expect(panel, findsNothing);

    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.pumpWidget(wrap(const Host()));
    await sendModChar(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyK,
    );
    expect(panel, findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('KunCommandShortcut.none never opens; key() binds that character',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(
      wrap(const Host(shortcut: KunCommandShortcut.none)),
    );
    await sendModChar(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyK,
    );
    expect(panel, findsNothing);

    await tester.pumpWidget(
      wrap(Host(shortcut: KunCommandShortcut.key('p'))),
    );
    await sendModChar(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyK,
    );
    expect(panel, findsNothing);
    await sendModChar(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyP,
    );
    expect(panel, findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the shortcut does nothing while another route is on top',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(wrap(const Host()));

    final NavigatorState navigator =
        Navigator.of(tester.element(find.text('Open')));
    final Future<void> pushed = navigator.push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return const Center(child: Text('overlay'));
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('overlay'), findsOneWidget);

    await sendModChar(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyK,
    );
    expect(panel, findsNothing);

    navigator.pop();
    await pushed;
    await tester.pumpAndSettle();

    await sendModChar(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyK,
    );
    expect(panel, findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('focus goes to the input on open and comes back on close',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));

    final FocusNode triggerFocus = Focus.of(tester.element(find.text('Open')));
    triggerFocus.requestFocus();
    await tester.pump();
    expect(triggerFocus.hasFocus, isTrue);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(triggerFocus.hasFocus, isTrue);
  });

  testWidgets('arrow keys skip disabled rows', (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await openByTap(tester);

    expect(rowSelected(tester, 'home'), isTrue);
    expect(rowSelected(tester, 'docs'), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(rowSelected(tester, 'settings'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(rowSelected(tester, 'copy'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(rowSelected(tester, 'settings'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(rowSelected(tester, 'home'), isTrue);
  });

  testWidgets('a hovered row that is not active takes the default-100 fill',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await openByTap(tester);
    Color? fill(String value) => (tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: item(value),
                matching: find.byType(AnimatedContainer),
              ),
            )
            .decoration! as BoxDecoration)
        .color;

    final TestGesture mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(item('home')));
    await tester.pump();
    expect(rowSelected(tester, 'home'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(rowSelected(tester, 'settings'), isTrue);
    expect(
      fill('home'),
      KunColors.light.neutral.shade100
          .withValues(alpha: KunColors.globalOpacity),
    );
    expect(fill('copy'), isNull);
  });

  testWidgets('Enter selects the active row', (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await openByTap(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(hostOf(tester).selected.single.label, 'Home');
    expect(panel, findsNothing);
  });

  testWidgets('Enter submits the trimmed query when there are no rows',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host(items: <KunCommandGroup>[])));
    await openByTap(tester);
    await tester.enterText(find.byType(EditableText), 'nowhere');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(hostOf(tester).submitted, <String>['nowhere']);
    expect(hostOf(tester).selected, isEmpty);
  });

  testWidgets('Enter during IME composing does nothing',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await openByTap(tester);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(hostOf(tester).selected, isEmpty);
    expect(hostOf(tester).submitted, isEmpty);
    expect(panel, findsOneWidget);
  });

  testWidgets('Escape closes from a row', (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await openByTap(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(rowSelected(tester, 'settings'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
  });

  testWidgets('the query clears on close', (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await openByTap(tester);
    await tester.enterText(find.byType(EditableText), 'home');
    await tester.pump();
    expect(hostOf(tester).query, 'home');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(hostOf(tester).query, isEmpty);
  });

  testWidgets('flat and grouped items, with group labels',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await openByTap(tester);
    expect(find.text('Navigate'), findsOneWidget);
    expect(find.text('Actions'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.pumpWidget(wrap(const Host(items: flat)));
    await openByTap(tester);
    expect(find.text('Navigate'), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('loading, empty and noResult states',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        const Host(
          items: <KunCommandGroup>[],
          loading: true,
        ),
      ),
    );
    await openByTap(tester);
    expect(find.text(KunMessages.en.commandPalette.loading), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      wrap(const Host(items: <KunCommandGroup>[])),
    );
    await openByTap(tester);
    expect(find.text(KunMessages.en.commandPalette.empty), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'zzz');
    await tester.pump();
    expect(
      find.textContaining(KunMessages.en.commandPalette.noResult),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('KunCommandPalette.list')),
        matching: find.textContaining('zzz'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('highlighting paints case-insensitive term matches',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await openByTap(tester);
    await tester.enterText(find.byType(EditableText), 'HO');
    await tester.pump();

    final RichText rich = tester.widget<RichText>(
      find.descendant(of: item('home'), matching: find.byType(RichText)).first,
    );
    final List<TextSpan> marks = <TextSpan>[];
    rich.text.visitChildren((InlineSpan span) {
      if (span is TextSpan &&
          span.style?.backgroundColor ==
              KunColors.light.primary.solid.withValues(alpha: 0.2)) {
        marks.add(span);
      }
      return true;
    });
    expect(marks, isNotEmpty);
    expect(marks.first.text, 'Ho');
  });

  testWidgets("the trigger slot's label and keys follow the platform",
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(wrap(const Host()));
    expect(hostOf(tester).shortcutLabel, 'Ctrl K');
    expect(hostOf(tester).keys, 'Mod+k');

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(wrap(const Host()));
    expect(hostOf(tester).shortcutLabel, '⌘K');
    expect(hostOf(tester).keys, 'Mod+k');

    await tester.pumpWidget(
      wrap(Host(shortcut: KunCommandShortcut.key('j'))),
    );
    expect(hostOf(tester).shortcutLabel, '⌘J');
    expect(hostOf(tester).keys, 'Mod+j');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('href rows navigate through KunUIConfig',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    final List<String> visited = <String>[];
    await tester.pumpWidget(
      wrap(
        const Host(
          items: <KunCommandGroup>[
            KunCommandGroup(
              items: <KunCommandItem>[
                KunCommandItem(
                  value: 'profile',
                  label: 'Profile',
                  href: '/me',
                ),
              ],
            ),
          ],
        ),
        config: KunUIConfig(
          navigate: (BuildContext context, String href) => visited.add(href),
        ),
      ),
    );
    await openByTap(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(visited, <String>['/me']);
    expect(hostOf(tester).selected.single.label, 'Profile');
    expect(panel, findsNothing);
  });

  testWidgets('semantics: dialog, text field, selected row',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        const Host(
          semanticLabel: 'Command palette',
          placeholder: 'Type a command',
        ),
      ),
    );
    await openByTap(tester);

    final SemanticsNode dialog = tester.getSemantics(panel);
    expect(dialog.getSemanticsData().role, SemanticsRole.dialog);
    expect(dialog.getSemanticsData().label, 'Command palette');

    expect(find.byType(EditableText), findsOneWidget);

    final SemanticsData home =
        tester.getSemantics(item('home')).getSemanticsData();
    expect(home.label, 'Home');
    expect(home.flagsCollection.isSelected, Tristate.isTrue);
    expect(home.flagsCollection.isButton, isTrue);

    final SemanticsData docs =
        tester.getSemantics(item('docs')).getSemanticsData();
    expect(docs.flagsCollection.isSelected, isNot(Tristate.isTrue));
    expect(docs.flagsCollection.isEnabled, Tristate.isFalse);

    handle.dispose();
  });

  testWidgets('a KunButton trigger still opens the palette',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    expect(find.byType(KunButton), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
  });
}
