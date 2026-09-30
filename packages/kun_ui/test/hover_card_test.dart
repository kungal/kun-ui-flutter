import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/dismiss_layers.dart';

Finder get panel => find.byKey(const ValueKey<String>('KunHoverCard.panel'));

Widget wrap(Widget child, {Alignment alignment = Alignment.center}) => KunTheme(
      data: KunThemeData.light(),
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
    );

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<TestGesture> hover(WidgetTester tester, Offset location) async {
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

KunHoverCard card({
  Widget? trigger,
  Widget Function(BuildContext context, VoidCallback close)? builder,
  Duration openDelay = const Duration(milliseconds: 600),
  Duration closeDelay = const Duration(milliseconds: 300),
  bool disabled = false,
  String? group,
  bool? open,
  ValueChanged<bool>? onOpenChanged,
  KunPopoverPosition position = KunPopoverPosition.bottomStart,
  bool showArrow = false,
}) {
  return KunHoverCard(
    position: position,
    openDelay: openDelay,
    closeDelay: closeDelay,
    disabled: disabled,
    group: group,
    open: open,
    onOpenChanged: onOpenChanged,
    showArrow: showArrow,
    trigger:
        trigger ?? const SizedBox(width: 80, height: 32, child: Text('open')),
    builder: builder ??
        (BuildContext context, VoidCallback close) => const SizedBox(
              width: 160,
              height: 80,
              child: Text('card'),
            ),
  );
}

void main() {
  testWidgets('a mouse rest opens after openDelay and not before',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(card()));

    expect(panel, findsNothing);
    await hover(tester, tester.getCenter(find.text('open')));
    expect(panel, findsNothing);

    await tester.pump(const Duration(milliseconds: 599));
    expect(panel, findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(find.text('card'), findsOneWidget);
  });

  testWidgets('leaving closes after closeDelay', (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(card()));
    final TestGesture gesture =
        await hover(tester, tester.getCenter(find.text('open')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);

    await gesture.moveTo(Offset.zero);
    await tester.pump();
    expect(panel, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 299));
    expect(panel, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(KunDismissLayers.debugLayers, isEmpty);
  });

  testWidgets('crossing to the card keeps it open',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(card()));
    final TestGesture gesture =
        await hover(tester, tester.getCenter(find.text('open')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);

    await gesture.moveTo(tester.getCenter(panel));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(find.text('card'), findsOneWidget);
  });

  testWidgets('a group switches instantly between siblings',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            KunHoverCard(
              group: 'authors',
              trigger: const SizedBox(width: 80, height: 32, child: Text('a')),
              builder: (BuildContext context, VoidCallback close) =>
                  const SizedBox(
                width: 120,
                height: 80,
                child: Text('card a'),
              ),
            ),
            KunHoverCard(
              group: 'authors',
              trigger: const SizedBox(width: 80, height: 32, child: Text('b')),
              builder: (BuildContext context, VoidCallback close) =>
                  const SizedBox(
                width: 120,
                height: 80,
                child: Text('card b'),
              ),
            ),
          ],
        ),
      ),
    );

    final TestGesture gesture = await hover(
      tester,
      tester.getCenter(find.text('a')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('card a'), findsOneWidget);

    await gesture.moveTo(tester.getCenter(find.text('b')));
    await tester.pumpAndSettle();
    expect(find.text('card b'), findsOneWidget);
    expect(find.text('card a'), findsNothing);
  });

  testWidgets(
      'a touch tap never opens it and still reaches the trigger handler',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    int pressed = 0;
    await tester.pumpWidget(
      wrap(
        card(
          trigger: KunButton(
            onPressed: () => pressed++,
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(pressed, 1);
  });

  testWidgets('keyboard focus opens it after openDelay',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    final FocusNode node = FocusNode(debugLabel: 'trigger');
    addTearDown(node.dispose);
    final FocusHighlightStrategy previous =
        FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);

    await tester.pumpWidget(
      wrap(
        card(
          trigger: Focus(
            focusNode: node,
            child: KunButton(
              onPressed: () {},
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    node.requestFocus();
    await tester.pump();
    expect(panel, findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
  });

  testWidgets('a pointer-driven focus does not open it',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    final FocusNode node = FocusNode(debugLabel: 'trigger');
    addTearDown(node.dispose);
    final FocusHighlightStrategy previous =
        FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);

    await tester.pumpWidget(
      wrap(
        card(
          trigger: Focus(
            focusNode: node,
            child: KunButton(
              onPressed: () {},
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    node.requestFocus();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
  });

  testWidgets('disabled renders the trigger alone',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    int pressed = 0;
    await tester.pumpWidget(
      wrap(
        card(
          disabled: true,
          trigger: KunButton(
            onPressed: () => pressed++,
            child: const Text('open'),
          ),
        ),
      ),
    );

    await hover(tester, tester.getCenter(find.text('open')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);

    await tester.tap(find.text('open'));
    expect(pressed, 1);
  });

  testWidgets('controlled open and onOpenChanged', (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    bool open = false;
    final List<bool> reported = <bool>[];

    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return card(
              open: open,
              onOpenChanged: (bool value) {
                reported.add(value);
                setState(() => open = value);
              },
            );
          },
        ),
      ),
    );

    await hover(tester, tester.getCenter(find.text('open')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(reported, <bool>[true]);
    expect(panel, findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(reported, <bool>[true, false]);
    expect(panel, findsNothing);
  });

  testWidgets('the builder runs only while open', (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    int builds = 0;
    await tester.pumpWidget(
      wrap(
        card(
          builder: (BuildContext context, VoidCallback close) {
            builds++;
            return const SizedBox(width: 160, height: 80, child: Text('card'));
          },
        ),
      ),
    );
    expect(builds, 0);

    await hover(tester, tester.getCenter(find.text('open')));
    await tester.pump(const Duration(milliseconds: 599));
    expect(builds, 0);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(builds, greaterThan(0));
    final int opened = builds;

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(builds, opened);
  });

  testWidgets('close from inside the card dismisses it',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        card(
          builder: (BuildContext context, VoidCallback close) {
            return KunButton(
              onPressed: close,
              child: const Text('dismiss'),
            );
          },
        ),
      ),
    );

    await hover(tester, tester.getCenter(find.text('open')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('dismiss'), findsOneWidget);

    await tester.tap(find.text('dismiss'));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
  });

  testWidgets('a click on a KunButton trigger still reaches it',
      (WidgetTester tester) async {
    setView(tester, const Size(800, 600));
    int pressed = 0;
    await tester.pumpWidget(
      wrap(
        card(
          trigger: KunButton(
            onPressed: () => pressed++,
            child: const Text('open'),
          ),
        ),
      ),
    );

    final TestGesture gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('open')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(pressed, 1);
    expect(panel, findsNothing);
  });
}
