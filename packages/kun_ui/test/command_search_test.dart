import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Finder get panel =>
    find.byKey(const ValueKey<String>('KunCommandSearch.panel'));

Finder item(Object value) => find.byKey(
      ValueKey<String>('KunCommandSearch.item.$value'),
    );

Finder get palettePanel =>
    find.byKey(const ValueKey<String>('KunCommandPalette.panel'));

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

const List<KunCommandGroup> recents = <KunCommandGroup>[
  KunCommandGroup(
    label: 'Recent',
    items: <KunCommandItem>[
      KunCommandItem(
        value: 'alpha',
        label: 'Alpha',
        removable: true,
      ),
      KunCommandItem(
        value: 'beta',
        label: 'Beta',
        removable: true,
      ),
    ],
  ),
];

Widget wrap(Widget child) {
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
        home: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(width: 400, child: child),
          ),
        ),
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
    this.loading = false,
    this.shortcut = KunCommandShortcut.modK,
    this.highlight = true,
    this.placeholder,
    this.noResultText,
    this.semanticLabel,
    this.empty,
    this.footer,
    this.noResult,
    this.loadingBuilder,
    this.itemBuilder,
    this.maxHeight = 420,
    this.size = KunUISize.md,
    this.focusNode,
    super.key,
  });

  final List<KunCommandGroup> items;
  final bool loading;
  final KunCommandShortcut shortcut;
  final bool highlight;
  final String? placeholder;
  final String? noResultText;
  final String? semanticLabel;
  final Widget? empty;
  final Widget? footer;
  final Widget Function(BuildContext, String)? noResult;
  final Widget? loadingBuilder;
  final Widget Function(BuildContext, KunCommandItem, bool)? itemBuilder;
  final double maxHeight;
  final KunUISize size;
  final FocusNode? focusNode;

  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  String query = '';
  final List<KunCommandItem> selected = <KunCommandItem>[];
  final List<KunCommandItem> removed = <KunCommandItem>[];
  final List<String> submitted = <String>[];

  @override
  Widget build(BuildContext context) {
    return KunCommandSearch(
      items: widget.items,
      query: query,
      loading: widget.loading,
      shortcut: widget.shortcut,
      highlight: widget.highlight,
      placeholder: widget.placeholder,
      noResultText: widget.noResultText,
      semanticLabel: widget.semanticLabel,
      empty: widget.empty,
      footer: widget.footer,
      noResult: widget.noResult,
      loadingBuilder: widget.loadingBuilder,
      itemBuilder: widget.itemBuilder,
      maxHeight: widget.maxHeight,
      size: widget.size,
      focusNode: widget.focusNode,
      onQueryChanged: (String value) => setState(() => query = value),
      onSelected: selected.add,
      onRemoved: removed.add,
      onSubmitted: submitted.add,
    );
  }
}

HostState hostOf(WidgetTester tester) =>
    tester.state<HostState>(find.byType(Host));

Future<void> focusField(WidgetTester tester) async {
  await tester.tap(find.byType(EditableText));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

bool rowSelected(WidgetTester tester, Object value) {
  return tester
          .getSemantics(item(value))
          .getSemanticsData()
          .flagsCollection
          .isSelected ==
      Tristate.isTrue;
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

List<SemanticsNode> platformNodes(WidgetTester tester) {
  final List<SemanticsNode> nodes = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    if (node.isMergedIntoParent) {
      return;
    }
    nodes.add(node);
    node
        .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
        .forEach(visit);
  }

  for (final RenderView view in tester.binding.renderViews) {
    visit(view.owner!.semanticsOwner!.rootSemanticsNode!);
  }
  return nodes;
}

void visitUnnamed(SemanticsNode node, List<SemanticsNode> unnamed) {
  final SemanticsData data = node.getSemanticsData();
  if (data.hasAction(SemanticsAction.tap) && data.label.isEmpty) {
    unnamed.add(node);
  }
  node.visitChildren((SemanticsNode child) {
    visitUnnamed(child, unnamed);
    return true;
  });
}

void main() {
  testWidgets('focus, typing and a click on a focused field open the panel',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));

    expect(panel, findsNothing);
    await focusField(tester);
    expect(panel, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );

    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
  });

  testWidgets('shown needs rows, loading, a typed query or an empty slot',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(Host(key: UniqueKey(), items: const <KunCommandGroup>[])),
    );
    await focusField(tester);
    expect(panel, findsNothing);

    await tester.enterText(find.byType(EditableText), 'q');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(panel, findsOneWidget);

    await tester.pumpWidget(
      wrap(
        Host(
          key: UniqueKey(),
          items: const <KunCommandGroup>[],
          empty: const Text('Empty slot'),
        ),
      ),
    );
    await focusField(tester);
    expect(find.text('Empty slot'), findsOneWidget);
  });

  testWidgets('clearing the field keeps it open when there are rows',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host(items: recents)));
    await focusField(tester);
    await tester.enterText(find.byType(EditableText), 'al');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(KunIcons.circleX));
    await tester.pumpAndSettle();
    expect(hostOf(tester).query, isEmpty);
    expect(panel, findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('nothing is highlighted until an arrow key moves',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await focusField(tester);
    expect(rowSelected(tester, 'home'), isFalse);
    expect(rowSelected(tester, 'settings'), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(rowSelected(tester, 'home'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(rowSelected(tester, 'settings'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(rowSelected(tester, 'copy'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(rowSelected(tester, 'home'), isFalse);
    expect(rowSelected(tester, 'copy'), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(rowSelected(tester, 'copy'), isTrue);
  });

  testWidgets('arrows open a closed panel', (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await focusField(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
  });

  testWidgets('Enter submits the trimmed query when nothing is highlighted',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await focusField(tester);
    await tester.enterText(find.byType(EditableText), '  go  ');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(hostOf(tester).submitted, <String>['go']);
    expect(hostOf(tester).selected, isEmpty);
    expect(panel, findsNothing);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
  });

  testWidgets('Enter on a highlighted row selects it',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await focusField(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(hostOf(tester).selected.single.label, 'Home');
    expect(panel, findsNothing);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
  });

  testWidgets('a tap selects the row, closes and blurs',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await focusField(tester);
    await tester.tap(item('settings'));
    await tester.pumpAndSettle();
    expect(hostOf(tester).selected.single.label, 'Settings');
    expect(panel, findsNothing);
  });

  testWidgets('the soft keyboard action follows Enter',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await focusField(tester);
    await tester.enterText(find.byType(EditableText), 'site');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(hostOf(tester).submitted, <String>['site']);
  });

  testWidgets('Home and End are left to the caret',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await focusField(tester);
    await tester.enterText(find.byType(EditableText), 'ab');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(rowSelected(tester, 'home'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    final TextSelection selection = tester
        .widget<EditableText>(find.byType(EditableText))
        .controller
        .selection;
    expect(selection.baseOffset, 0);
    expect(rowSelected(tester, 'home'), isTrue);
  });

  testWidgets('a new query or item list resets the highlight to none',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await focusField(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(rowSelected(tester, 'home'), isTrue);

    await tester.enterText(find.byType(EditableText), 's');
    await tester.pump();
    expect(rowSelected(tester, 'home'), isFalse);
    expect(rowSelected(tester, 'settings'), isFalse);
  });

  testWidgets('Tab closes the panel and is not handled',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await focusField(tester);
    expect(panel, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
  });

  testWidgets('blur and an outside tap close the panel',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        Stack(
          children: <Widget>[
            const Host(),
            Align(
              alignment: Alignment.topRight,
              child: KunButton(
                onPressed: () {},
                child: const Text('other'),
              ),
            ),
          ],
        ),
      ),
    );
    await focusField(tester);
    expect(panel, findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );

    tester.widget<EditableText>(find.byType(EditableText)).focusNode.unfocus();
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
    expect(panel, findsNothing);

    await focusField(tester);
    expect(panel, findsOneWidget);
    await tester.tapAt(const Offset(10, 500));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
  });

  testWidgets('hovering a row highlights it; leaving the list clears it',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await focusField(tester);

    final TestGesture mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(item('settings')));
    await tester.pump();
    expect(rowSelected(tester, 'settings'), isTrue);

    await mouse.moveTo(const Offset(1, 1));
    await tester.pump();
    expect(rowSelected(tester, 'settings'), isFalse);
  });

  testWidgets('the search icon becomes a spinner; rows stay while loading',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await focusField(tester);
    expect(find.byIcon(KunIcons.search), findsOneWidget);
    expect(find.byType(KunSpinner), findsNothing);
    expect(item('home'), findsOneWidget);

    await tester.pumpWidget(wrap(const Host(loading: true)));
    await tester.pump();
    expect(find.byType(KunSpinner), findsOneWidget);
    expect(item('home'), findsOneWidget);
    expect(find.text(KunMessages.en.commandPalette.loading), findsNothing);
  });

  testWidgets('the loading text shows only when there are no rows',
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
    await focusField(tester);
    expect(find.text(KunMessages.en.commandPalette.loading), findsOneWidget);
  });

  testWidgets('a typed query with no rows shows the no-result text',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        const Host(
          items: <KunCommandGroup>[],
          noResultText: 'Nothing',
        ),
      ),
    );
    await focusField(tester);
    await tester.enterText(find.byType(EditableText), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nothing'), findsOneWidget);
  });

  testWidgets('the Kbd hint shows while unfocused and hides while focused',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(wrap(const Host()));
    expect(find.byType(KunKbd), findsOneWidget);

    await focusField(tester);
    expect(find.byType(KunKbd), findsNothing);

    await tester.pumpWidget(
      wrap(const Host(shortcut: KunCommandShortcut.none)),
    );
    expect(find.byType(KunKbd), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the clear button is a labelled unfocusable control',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(const Host()));
    await focusField(tester);
    await tester.enterText(find.byType(EditableText), 'q');
    await tester.pump();

    final SemanticsData clear =
        tester.getSemantics(find.byIcon(KunIcons.circleX)).getSemanticsData();
    expect(clear.label, KunMessages.en.commandPalette.clear);
    expect(clear.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('✕ emits remove and does not select',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host(items: recents)));
    await focusField(tester);
    await tester.tap(
      find.descendant(of: item('alpha'), matching: find.byIcon(KunIcons.x)),
    );
    await tester.pump();
    expect(hostOf(tester).removed.single.value, 'alpha');
    expect(hostOf(tester).selected, isEmpty);
    expect(panel, findsOneWidget);
  });

  testWidgets('Shift+Delete removes the highlighted removable row',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host(items: recents)));
    await focusField(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(hostOf(tester).removed.single.value, 'alpha');
  });

  testWidgets(
      'the highlight after a removal stays, then follows once the item is gone',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const _SearchRemoveHost()));
    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(rowSelected(tester, 'b'), isTrue);

    final _SearchRemoveHostState state =
        tester.state<_SearchRemoveHostState>(find.byType(_SearchRemoveHost));
    await tester.tap(
      find.descendant(of: item('b'), matching: find.byIcon(KunIcons.x)),
    );
    await tester.pump();
    expect(state.removed.single.value, 'b');
    expect(rowSelected(tester, 'b'), isTrue);

    state.dropRemoved();
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('KunCommandSearch.item.b')),
        findsNothing);
    expect(rowSelected(tester, 'c'), isTrue);
  });

  testWidgets('an empty group is dropped', (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        const Host(
          items: <KunCommandGroup>[
            KunCommandGroup(label: 'Empty', items: <KunCommandItem>[]),
            KunCommandGroup(
              label: 'Keep',
              items: <KunCommandItem>[
                KunCommandItem(value: 'a', label: 'Alpha'),
              ],
            ),
          ],
        ),
      ),
    );
    await focusField(tester);
    expect(find.text('Empty'), findsNothing);
    expect(find.text('Keep'), findsOneWidget);
  });

  testWidgets("a labelled group's header has the header flag",
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(const Host()));
    await focusField(tester);
    expect(
      tester
          .getSemantics(find.text('Navigate'))
          .getSemanticsData()
          .flagsCollection
          .isHeader,
      isTrue,
    );
    handle.dispose();
  });

  testWidgets('expanded follows what is on screen; the list is a list',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(const Host()));

    SemanticsData field =
        tester.getSemantics(find.byType(EditableText)).getSemanticsData();
    expect(field.flagsCollection.isTextField, isTrue);
    expect(field.label, 'Search…');
    expect(field.flagsCollection.isExpanded, Tristate.isFalse);

    await focusField(tester);
    field = tester.getSemantics(find.byType(EditableText)).getSemanticsData();
    expect(field.flagsCollection.isExpanded, Tristate.isTrue);

    final SemanticsData list = tester
        .getSemantics(
          find.byKey(const ValueKey<String>('KunCommandSearch.list')),
        )
        .getSemanticsData();
    expect(list.role, SemanticsRole.list);
    handle.dispose();
  });

  testWidgets('the status line lives in the field subtree',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(const Host()));
    await focusField(tester);
    await tester.enterText(find.byType(EditableText), 's');
    await tester.pumpAndSettle();

    final String expected = KunMessages.en.commandPalette.resultCount(count: 4);
    expect(
      platformNodes(tester).any(
        (SemanticsNode node) => node.getSemanticsData().label == expected,
      ),
      isTrue,
    );
    handle.dispose();
  });

  testWidgets('arrow keys keep the highlighted row in view',
      (WidgetTester tester) async {
    setView(tester, const Size(500, 800));
    await tester.pumpWidget(
      wrap(
        Host(
          maxHeight: 160,
          items: <KunCommandGroup>[
            KunCommandGroup(
              items: <KunCommandItem>[
                for (int i = 0; i < 12; i++)
                  KunCommandItem(value: 'o$i', label: 'Option $i'),
              ],
            ),
          ],
        ),
      ),
    );
    await focusField(tester);
    final Rect box = tester.getRect(panel);
    for (int i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    final Rect last = tester.getRect(item('o11'));
    expect(last.bottom, lessThanOrEqualTo(box.bottom + 1));
    expect(last.top, greaterThanOrEqualTo(box.top - 1));
  });

  testWidgets('a footer KunButton fires while the field keeps focus',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    bool pressed = false;
    await tester.pumpWidget(
      wrap(
        Host(
          footer: KunButton(
            onPressed: () => pressed = true,
            child: const Text('All results'),
          ),
        ),
      ),
    );
    await focusField(tester);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.tap(find.text('All results'));
    await tester.pump();
    expect(pressed, isTrue);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('Escape inside a KunModal: panel, then text, then the modal',
      (WidgetTester tester) async {
    setView(tester, const Size(1024, 768));
    await tester.pumpWidget(wrap(const _ModalSearchHost()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(
        find.byKey(const ValueKey<String>('KunModal.panel')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(
        find.byKey(const ValueKey<String>('KunModal.panel')), findsOneWidget);
    expect(
        tester
            .state<_ModalSearchHostState>(find.byType(_ModalSearchHost))
            .query,
        'hello');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey<String>('KunModal.panel')), findsOneWidget);
    expect(
      tester.state<_ModalSearchHostState>(find.byType(_ModalSearchHost)).query,
      isEmpty,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('KunModal.panel')), findsNothing);
  });

  testWidgets('a builder row is named by all of its text',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        Host(
          itemBuilder: (_, KunCommandItem item, __) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(item.label),
              Text('${item.value} page'),
            ],
          ),
        ),
      ),
    );
    await focusField(tester);

    final SemanticsNode home = tester.getSemantics(item('home'));
    expect(home.getSemanticsData().label, 'Home\nhome page');
    expect(home.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    final List<SemanticsNode> unnamed = <SemanticsNode>[];
    visitUnnamed(
      tester
          .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
      unnamed,
    );
    expect(unnamed, isEmpty);
    handle.dispose();
  });

  testWidgets('the overlay reaches the traversal-order semantics tree',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(const Host()));
    await focusField(tester);

    final List<String> labels = <String>[
      for (final SemanticsNode node in platformNodes(tester))
        node.getSemanticsData().label,
    ];
    expect(labels, contains('Home'));
    expect(labels, contains('Settings'));
    handle.dispose();
  });

  testWidgets('a visible search takes Mod+K before a palette',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(wrap(const _SearchAndPaletteHost()));
    await sendModChar(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyK,
    );
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    expect(palettePanel, findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a search with no shortcut leaves Mod+K to the palette',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      wrap(
        const _SearchAndPaletteHost(searchShortcut: KunCommandShortcut.none),
      ),
    );
    await sendModChar(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyK,
    );
    expect(palettePanel, findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byType(KunCommandSearch),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isFalse,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('an Offstage search leaves Mod+K to the palette',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      wrap(const _SearchAndPaletteHost(searchOffstage: true)),
    );
    await sendModChar(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyK,
    );
    expect(palettePanel, findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
      'a search under a pushed route leaves Mod+K to the current palette',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(wrap(const _CoveredSearchHost()));
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    await sendModChar(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyK,
    );
    expect(palettePanel, findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Mod+K selects the whole query', (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final FocusNode node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(wrap(Host(focusNode: node)));
    await focusField(tester);
    await tester.enterText(find.byType(EditableText), 'hello');
    await tester.pump();
    node.unfocus();
    await tester.pump();

    await sendModChar(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyK,
    );
    expect(node.hasFocus, isTrue);
    final TextSelection selection = tester
        .widget<EditableText>(find.byType(EditableText))
        .controller
        .selection;
    expect(selection, const TextSelection(baseOffset: 0, extentOffset: 5));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Enter during IME composing does nothing',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(const Host()));
    await focusField(tester);
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
}

class _SearchRemoveHost extends StatefulWidget {
  const _SearchRemoveHost();

  @override
  State<_SearchRemoveHost> createState() => _SearchRemoveHostState();
}

class _SearchRemoveHostState extends State<_SearchRemoveHost> {
  List<KunCommandItem> items = const <KunCommandItem>[
    KunCommandItem(value: 'a', label: 'a', removable: true),
    KunCommandItem(value: 'b', label: 'b', removable: true),
    KunCommandItem(value: 'c', label: 'c', removable: true),
  ];
  final List<KunCommandItem> removed = <KunCommandItem>[];

  void dropRemoved() {
    setState(() {
      items = items
          .where(
            (KunCommandItem item) =>
                !removed.any((KunCommandItem r) => r.value == item.value),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KunCommandSearch(
      items: <KunCommandGroup>[KunCommandGroup(items: items)],
      onRemoved: removed.add,
    );
  }
}

class _ModalSearchHost extends StatefulWidget {
  const _ModalSearchHost();

  @override
  State<_ModalSearchHost> createState() => _ModalSearchHostState();
}

class _ModalSearchHostState extends State<_ModalSearchHost> {
  bool open = true;
  String query = 'hello';

  @override
  Widget build(BuildContext context) {
    return KunModal(
      value: open,
      onChanged: (bool value) => setState(() => open = value),
      title: 'Search',
      child: KunCommandSearch(
        query: query,
        items: grouped,
        onQueryChanged: (String value) => setState(() => query = value),
      ),
    );
  }
}

class _SearchAndPaletteHost extends StatefulWidget {
  const _SearchAndPaletteHost({
    this.searchOffstage = false,
    this.searchShortcut = KunCommandShortcut.modK,
  });

  final bool searchOffstage;
  final KunCommandShortcut searchShortcut;

  @override
  State<_SearchAndPaletteHost> createState() => _SearchAndPaletteHostState();
}

class _SearchAndPaletteHostState extends State<_SearchAndPaletteHost> {
  bool paletteOpen = false;

  @override
  Widget build(BuildContext context) {
    final Widget search = SizedBox(
      width: 400,
      height: 80,
      child: KunCommandSearch(
        items: grouped,
        shortcut: widget.searchShortcut,
      ),
    );
    return Column(
      children: <Widget>[
        if (widget.searchOffstage)
          Offstage(offstage: true, child: search)
        else
          search,
        KunCommandPalette(
          items: grouped,
          open: paletteOpen,
          onOpenChanged: (bool value) => setState(() => paletteOpen = value),
          trigger: (
            BuildContext context,
            VoidCallback open,
            String shortcutLabel,
            String keys,
          ) {
            return KunButton(
              onPressed: open,
              child: const Text('Palette'),
            );
          },
        ),
      ],
    );
  }
}

class _CoveredSearchHost extends StatefulWidget {
  const _CoveredSearchHost();

  @override
  State<_CoveredSearchHost> createState() => _CoveredSearchHostState();
}

class _CoveredSearchHostState extends State<_CoveredSearchHost> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(
          width: 400,
          height: 80,
          child: KunCommandSearch(items: grouped),
        ),
        KunButton(
          onPressed: () {
            Navigator.of(context).push<void>(
              PageRouteBuilder<void>(
                pageBuilder: (
                  BuildContext context,
                  Animation<double> animation,
                  Animation<double> secondaryAnimation,
                ) {
                  return KunTheme(
                    data: KunThemeData.light(),
                    child: const Center(child: _PaletteOnRoute()),
                  );
                },
              ),
            );
          },
          child: const Text('Push'),
        ),
      ],
    );
  }
}

class _PaletteOnRoute extends StatefulWidget {
  const _PaletteOnRoute();

  @override
  State<_PaletteOnRoute> createState() => _PaletteOnRouteState();
}

class _PaletteOnRouteState extends State<_PaletteOnRoute> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    return KunCommandPalette(
      items: grouped,
      open: open,
      onOpenChanged: (bool value) => setState(() => open = value),
      trigger: (
        BuildContext context,
        VoidCallback openPalette,
        String shortcutLabel,
        String keys,
      ) {
        return KunButton(
          onPressed: openPalette,
          child: const Text('Palette'),
        );
      },
    );
  }
}
