import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(
  Widget child, {
  KunTapTargetSize tapTargetSize = KunTapTargetSize.adaptive,
}) {
  return WidgetsApp(
    color: KunColors.black,
    debugShowCheckedModeBanner: false,
    shortcuts: const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
    },
    home: Align(
      alignment: Alignment.center,
      child: SizedBox(width: 800, child: child),
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
  bool reduce = false,
}) {
  return wrap(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(800, 600),
        devicePixelRatio: 1,
        disableAnimations: reduce,
      ),
      child: KunTheme(
        data: KunThemeData.light(),
        child: _Host(currentPage: currentPage, totalPage: totalPage),
      ),
    ),
  );
}

class _Host extends StatefulWidget {
  const _Host({required this.currentPage, required this.totalPage});

  final int currentPage;
  final int totalPage;

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
      onCurrentPageChanged: (int page) => setState(() => _page = page),
    );
  }
}

Finder pageButton(int page) => find.widgetWithText(KunButton, '$page');

Finder nextButton() => find.byKey(const ValueKey<String>('KunPagination.next'));

AnimatedPositioned indicatorOf(WidgetTester tester) =>
    tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned));

double slotOpacity(WidgetTester tester, Finder of) => tester
    .widget<Opacity>(
      find.ancestor(of: of, matching: find.byType(Opacity)).first,
    )
    .opacity;

Future<void> show(WidgetTester tester, Widget app) async {
  setView(tester, const Size(800, 600));
  await tester.pumpWidget(app);
  await tester.pump();
}

void main() {
  testWidgets('staying numbers slide from their old slots to the new ones',
      (WidgetTester tester) async {
    await show(tester, host(currentPage: 10));

    await tester.tap(nextButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final Offset start = tester.getTopLeft(pageButton(11));
    await tester.pump(const Duration(milliseconds: 75));
    final Offset mid = tester.getTopLeft(pageButton(11));
    await tester.pump(const Duration(milliseconds: 75));
    final Offset rest = tester.getTopLeft(pageButton(11));

    expect(start.dx, greaterThan(rest.dx));
    expect(mid.dx, lessThan(start.dx));
    expect(mid.dx, greaterThan(rest.dx));
    expect(mid.dy, closeTo(start.dy, 0.5));
    expect(rest.dy, closeTo(start.dy, 0.5));
  });

  testWidgets(
      'a leaving number fades out where it stood and takes no hits or semantics',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await show(tester, host(currentPage: 10));

    await tester.tap(nextButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('9'), findsOneWidget);
    final Offset pinned = tester.getTopLeft(pageButton(9));
    expect(slotOpacity(tester, pageButton(9)), closeTo(1, 0.001));

    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('9'), findsOneWidget);
    expect(tester.getTopLeft(pageButton(9)), pinned);
    expect(slotOpacity(tester, pageButton(9)), lessThan(1));
    expect(slotOpacity(tester, pageButton(9)), greaterThan(0));
    expect(pageButton(9).hitTestable(), findsNothing);
    expect(
      find.semantics.byLabel(KunMessages.zhCN.pagination.page(page: 9)),
      findsNothing,
    );
    expect(
      find.semantics.byLabel(KunMessages.zhCN.pagination.page(page: 11)),
      findsOne,
    );

    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('9'), findsNothing);
    handle.dispose();
  });

  testWidgets('an entering number fades in', (WidgetTester tester) async {
    await show(tester, host(currentPage: 10));

    expect(find.text('12'), findsNothing);
    await tester.tap(nextButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('12'), findsOneWidget);
    expect(slotOpacity(tester, pageButton(12)), closeTo(0, 0.001));

    await tester.pump(const Duration(milliseconds: 75));
    final double mid = slotOpacity(tester, pageButton(12));
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));

    await tester.pump(const Duration(milliseconds: 75));
    expect(slotOpacity(tester, pageButton(12)), closeTo(1, 0.001));
  });

  testWidgets('the ellipses move with the numbers',
      (WidgetTester tester) async {
    await show(tester, host(currentPage: 3));

    expect(find.text('...'), findsOneWidget);
    await tester.tap(pageButton(4));
    await tester.pump();

    expect(find.text('...'), findsNWidgets(2));
    final Offset start = tester.getTopLeft(find.text('...').last);
    expect(slotOpacity(tester, find.text('...').first), closeTo(0, 0.001));

    await tester.pump(const Duration(milliseconds: 75));
    final Offset mid = tester.getTopLeft(find.text('...').last);
    expect(slotOpacity(tester, find.text('...').first), inExclusiveRange(0, 1));

    await tester.pumpAndSettle();
    final Offset rest = tester.getTopLeft(find.text('...').last);
    expect(mid.dx, isNot(closeTo(start.dx, 0.5)));
    expect(rest.dx, isNot(closeTo(start.dx, 0.5)));
    expect(slotOpacity(tester, find.text('...').first), closeTo(1, 0.001));
  });

  testWidgets('the highlight lands on the settled slot, not a mid-move number',
      (WidgetTester tester) async {
    await show(tester, host(currentPage: 10));

    await tester.tap(nextButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    final double destLeft = indicatorOf(tester).left!;
    final Offset moving = tester.getTopLeft(pageButton(11));

    await tester.pump(const Duration(milliseconds: 75));
    expect(indicatorOf(tester).left, destLeft);
    expect(
        tester.getTopLeft(pageButton(11)).dx, isNot(closeTo(moving.dx, 0.5)));

    await tester.pumpAndSettle();
    expect(indicatorOf(tester).left, destLeft);
    final Rect pill = tester.getRect(find.byType(AnimatedPositioned));
    final Rect page = tester.getRect(pageButton(11));
    expect(pill.center.dx, closeTo(page.center.dx, 1));
    expect(pill.center.dy, closeTo(page.center.dy, 1));
  });

  testWidgets('reduced motion jumps the number row to rest',
      (WidgetTester tester) async {
    await show(tester, host(currentPage: 10, reduce: true));

    await tester.tap(nextButton());
    await tester.pump();

    expect(find.text('12'), findsOneWidget);
    expect(find.text('9'), findsNothing);
    expect(slotOpacity(tester, pageButton(12)), closeTo(1, 0.001));
    expect(slotOpacity(tester, pageButton(11)), closeTo(1, 0.001));

    final Offset rest = tester.getTopLeft(pageButton(11));
    await tester.pump(const Duration(milliseconds: 75));
    expect(tester.getTopLeft(pageButton(11)), rest);
    expect(find.text('9'), findsNothing);
  });

  testWidgets('rapid page changes mid-animation settle on the last window',
      (WidgetTester tester) async {
    await show(tester, host(currentPage: 10));

    await tester.tap(nextButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    expect(find.text('11'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('13'), findsOneWidget);
    expect(find.text('9'), findsNothing);
    expect(find.text('10'), findsNothing);
    expect(slotOpacity(tester, pageButton(12)), closeTo(1, 0.001));
    final Rect pill = tester.getRect(find.byType(AnimatedPositioned));
    final Rect page = tester.getRect(pageButton(12));
    expect(pill.center.dx, closeTo(page.center.dx, 1));
    expect(pill.center.dy, closeTo(page.center.dy, 1));
  });
}
