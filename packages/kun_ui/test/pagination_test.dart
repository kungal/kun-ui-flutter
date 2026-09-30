import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(
  Widget child, {
  KunMessages? messages,
  KunTapTargetSize tapTargetSize = KunTapTargetSize.adaptive,
}) {
  Widget tree = KunTheme(
    data: KunThemeData.light(tapTargetSize: tapTargetSize),
    child: child,
  );
  if (messages != null) {
    tree = KunMessagesScope(messages: messages, child: tree);
  }
  return WidgetsApp(
    color: KunColors.black,
    debugShowCheckedModeBanner: false,
    shortcuts: const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
    },
    home: Align(
      alignment: Alignment.center,
      child: SizedBox(width: 800, child: tree),
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
  );
}

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget host({
  int currentPage = 1,
  int totalPage = 20,
  bool isLoading = false,
  KunMessages? messages,
  KunTapTargetSize tapTargetSize = KunTapTargetSize.adaptive,
}) {
  return wrap(
    _Host(
      currentPage: currentPage,
      totalPage: totalPage,
      isLoading: isLoading,
    ),
    messages: messages,
    tapTargetSize: tapTargetSize,
  );
}

class _Host extends StatefulWidget {
  const _Host({
    required this.currentPage,
    required this.totalPage,
    required this.isLoading,
  });

  final int currentPage;
  final int totalPage;
  final bool isLoading;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int _page = widget.currentPage;

  @override
  void didUpdateWidget(_Host oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      _page = widget.currentPage;
    }
  }

  @override
  Widget build(BuildContext context) {
    return KunPagination(
      currentPage: _page,
      totalPage: widget.totalPage,
      isLoading: widget.isLoading,
      onCurrentPageChanged: (int page) => setState(() => _page = page),
    );
  }
}

Finder pageButton(int page) => find.widgetWithText(KunButton, '$page');

void main() {
  testWidgets('a short catalogue lists every page and no ellipsis',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(host(totalPage: 5));
    await tester.pump();

    for (int i = 1; i <= 5; i++) {
      expect(find.text('$i'), findsOneWidget);
    }
    expect(find.text('...'), findsNothing);
  });

  testWidgets('page 1 of many shows a leading window and a trailing ellipsis',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('5'), findsNothing);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('...'), findsOneWidget);
  });

  testWidgets('a middle page shows ellipses on both sides',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(host(currentPage: 10));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('8'), findsNothing);
    expect(find.text('12'), findsNothing);
    expect(find.text('...'), findsNWidgets(2));
  });

  testWidgets('the last page shows a trailing window',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(host(currentPage: 20));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('19'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('16'), findsNothing);
    expect(find.text('...'), findsOneWidget);
  });

  testWidgets('tapping a page reports it and selecting it again is a no-op',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    final List<int> pages = <int>[];
    await tester.pumpWidget(
      wrap(
        KunPagination(
          currentPage: 1,
          totalPage: 20,
          onCurrentPageChanged: pages.add,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(pageButton(2));
    expect(pages, <int>[2]);

    await tester.tap(pageButton(1));
    expect(pages, <int>[2]);
  });

  testWidgets('prev and next step one page; edges stay put',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(host());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('KunPagination.prev')));
    await tester.pump();
    expect(pageButton(1), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('KunPagination.next')));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    await tester.pumpWidget(host(currentPage: 20));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('KunPagination.next')));
    await tester.pump();
    expect(find.text('20'), findsOneWidget);
  });

  testWidgets('isLoading disables every control', (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    final List<int> pages = <int>[];
    await tester.pumpWidget(
      wrap(
        KunPagination(
          currentPage: 3,
          totalPage: 20,
          isLoading: true,
          onCurrentPageChanged: pages.add,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(pageButton(4), warnIfMissed: false);
    await tester.tap(find.byKey(const ValueKey<String>('KunPagination.next')),
        warnIfMissed: false);
    await tester.tap(find.byKey(const ValueKey<String>('KunPagination.go')),
        warnIfMissed: false);
    await tester.enterText(
      find.byKey(const ValueKey<String>('KunPagination.jump')),
      '8',
    );
    await tester.testTextInput.receiveAction(TextInputAction.go);
    expect(pages, isEmpty);
  });

  testWidgets('jump goes to a typed page and ignores out of range',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(host());
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey<String>('KunPagination.jump')),
      '11',
    );
    await tester.tap(find.byKey(const ValueKey<String>('KunPagination.go')));
    await tester.pumpAndSettle();
    expect(find.text('11'), findsOneWidget);
    expect(find.text('...'), findsNWidgets(2));

    await tester.enterText(
      find.byKey(const ValueKey<String>('KunPagination.jump')),
      '0',
    );
    await tester.tap(find.byKey(const ValueKey<String>('KunPagination.go')));
    await tester.pump();
    expect(find.text('11'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('KunPagination.jump')),
      '99',
    );
    await tester.tap(find.byKey(const ValueKey<String>('KunPagination.go')));
    await tester.pump();
    expect(find.text('11'), findsOneWidget);
  });

  testWidgets('strings resolve through KunMessagesScope in two locales',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(host(messages: KunMessages.zhCN));
    await tester.pump();
    expect(find.text(KunMessages.zhCN.pagination.jump), findsOneWidget);
    expect(find.text(KunMessages.zhCN.pagination.jumpLabel), findsOneWidget);
    expect(find.text(KunMessages.zhCN.pagination.hintBefore), findsOneWidget);
    expect(
      find.bySemanticsLabel(KunMessages.zhCN.pagination.page(page: 1)),
      findsOneWidget,
    );

    await tester.pumpWidget(host(messages: KunMessages.en));
    await tester.pump();
    expect(find.text(KunMessages.en.pagination.jump), findsOneWidget);
    expect(find.text(KunMessages.en.pagination.jumpLabel), findsOneWidget);
    expect(find.text(KunMessages.en.pagination.hintAfter), findsOneWidget);
    expect(
      find.bySemanticsLabel(KunMessages.en.pagination.page(page: 1)),
      findsOneWidget,
    );
    expect(find.text(KunMessages.zhCN.pagination.jump), findsNothing);
    handle.dispose();
  });

  testWidgets('Space and web Enter activate a focused page button',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(host(totalPage: 5));
    await tester.pump();

    Focus.of(tester.element(find.text('2'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    Focus.of(tester.element(find.text('3'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('arrow keys page while nothing has focus',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(host(currentPage: 5));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('7'), findsOneWidget);
    expect(find.text('4'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    expect(find.text('7'), findsNothing);
  });

  testWidgets('arrow keys page from a focused page button',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(host(currentPage: 5));
    await tester.pump();

    Focus.of(tester.element(find.text('5'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('arrow keys stay with a focused widget outside it',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    final FocusNode other = FocusNode();
    addTearDown(other.dispose);
    final List<LogicalKeyboardKey> seen = <LogicalKeyboardKey>[];
    await tester.pumpWidget(
      wrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Focus(
              focusNode: other,
              onKeyEvent: (FocusNode node, KeyEvent event) {
                if (event is KeyDownEvent) {
                  seen.add(event.logicalKey);
                }
                return KeyEventResult.handled;
              },
              child: const SizedBox(width: 40, height: 40),
            ),
            const _Host(currentPage: 5, totalPage: 20, isLoading: false),
          ],
        ),
      ),
    );
    other.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(seen, <LogicalKeyboardKey>[LogicalKeyboardKey.arrowRight]);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('a route pushed on top stops the paging',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(host(currentPage: 5));
    await tester.pump();

    final NavigatorState navigator = tester.state(find.byType(Navigator));
    navigator.push(
      PageRouteBuilder<void>(
        pageBuilder: (BuildContext context, _, __) => const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    expect(find.text('7'), findsNothing);
  });

  testWidgets('arrow keys leave an editable jump field alone',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(host(currentPage: 3, totalPage: 20));
    await tester.pump();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('...'), findsOneWidget);

    final EditableText field = tester.widget(find.byType(EditableText));
    field.focusNode.requestFocus();
    await tester.pump();
    expect(field.focusNode.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(find.text('...'), findsOneWidget);
  });

  testWidgets('each page control is labelled and the current page is selected',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(host(currentPage: 3, totalPage: 5));
    await tester.pump();

    final KunPaginationStrings strings = KunMessages.zhCN.pagination;
    expect(find.bySemanticsLabel(strings.page(page: 3)), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(strings.page(page: 3)))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(strings.page(page: 1)))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.none,
    );
    expect(find.bySemanticsLabel(strings.prev), findsOneWidget);
    expect(find.bySemanticsLabel(strings.next), findsOneWidget);
    handle.dispose();
  });

  testWidgets('padded page controls meet the tap-target minimum',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      host(totalPage: 5, tapTargetSize: KunTapTargetSize.padded),
    );
    await tester.pump();

    final Size size = tester.getSize(pageButton(1));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('the arrow hint hides below the sm breakpoint',
      (WidgetTester tester) async {
    setView(tester, const Size(400, 600));
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 400,
          child: KunPagination(currentPage: 1, totalPage: 5),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(KunMessages.zhCN.pagination.hintBefore), findsNothing);

    setView(tester, const Size(800, 600));
    await tester.pumpWidget(host(totalPage: 5));
    await tester.pump();
    expect(find.text(KunMessages.zhCN.pagination.hintBefore), findsOneWidget);
  });

  testWidgets('on a phone the strip scrolls and keeps the page in view',
      (WidgetTester tester) async {
    setView(tester, const Size(380, 800));
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 380,
          child: _Host(currentPage: 20, totalPage: 20, isLoading: false),
        ),
        tapTargetSize: KunTapTargetSize.padded,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    final Rect strip = tester.getRect(find.byType(SingleChildScrollView));
    expect(strip.right, lessThanOrEqualTo(380));
    final Rect current = tester.getRect(pageButton(20));
    expect(current.left, greaterThanOrEqualTo(strip.left));
    expect(current.right, lessThanOrEqualTo(strip.right));
    expect(tester.getSize(pageButton(20)).height, greaterThanOrEqualTo(48));

    expect(tester.getRect(pageButton(1)).left, lessThan(strip.left));
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 380,
          child: _Host(currentPage: 1, totalPage: 20, isLoading: false),
        ),
        tapTargetSize: KunTapTargetSize.padded,
      ),
    );
    await tester.pumpAndSettle();
    final Rect first = tester.getRect(pageButton(1));
    expect(first.left, greaterThanOrEqualTo(strip.left));
    expect(first.right, lessThanOrEqualTo(strip.right));
  });

  testWidgets('jump reads the leading digits, as parseInt does',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(host(currentPage: 1));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), '12.5');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(find.text('13'), findsOneWidget);
    expect(find.text('10'), findsNothing);
  });
}
