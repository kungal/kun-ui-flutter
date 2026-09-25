import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/anchored.dart';
import 'package:kun_ui/src/foundation/dismiss_layers.dart';

Finder get panel => find.byKey(const ValueKey<String>('KunTooltip.panel'));

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

Future<TestGesture> hover(WidgetTester tester, Finder target) async {
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await tester.pump();
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump();
  return gesture;
}

void main() {
  testWidgets('a hover opens the panel after the show delay', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(const KunTooltip(text: 'Copy', child: Text('trigger'))),
    );

    await hover(tester, find.text('trigger'));
    expect(panel, findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('a trigger with its own gestures still shows the tooltip',
      (tester) async {
    setView(tester, const Size(800, 600));
    int pressed = 0;
    await tester.pumpWidget(
      wrap(
        KunTooltip(
          text: 'Copy',
          child: KunButton(
            onPressed: () => pressed++,
            child: const Text('trigger'),
          ),
        ),
      ),
    );

    await hover(tester, find.text('trigger'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    expect(pressed, 1);
  });

  testWidgets('leaving the trigger closes it', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(const KunTooltip(text: 'Copy', child: Text('trigger'))),
    );

    final TestGesture gesture = await hover(tester, find.text('trigger'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);

    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(KunDismissLayers.debugLayers, isEmpty);
  });

  testWidgets('focus opens it and Escape closes it', (tester) async {
    setView(tester, const Size(800, 600));
    final FocusNode node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      wrap(
        KunTooltip(
          text: 'Copy',
          child: Focus(focusNode: node, child: const Text('trigger')),
        ),
      ),
    );

    node.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
  });

  testWidgets('hideOnMobile suppresses it below the sm breakpoint',
      (tester) async {
    setView(tester, const Size(500, 800));
    await tester.pumpWidget(
      wrap(const KunTooltip(text: 'Copy', child: Text('trigger'))),
    );

    await hover(tester, find.text('trigger'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
  });

  testWidgets('hideOnMobile false shows it on a narrow view', (tester) async {
    setView(tester, const Size(500, 800));
    await tester.pumpWidget(
      wrap(
        const KunTooltip(
          text: 'Copy',
          hideOnMobile: false,
          child: Text('trigger'),
        ),
      ),
    );

    await hover(tester, find.text('trigger'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
  });

  testWidgets('it sits above its trigger', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(const KunTooltip(text: 'Copy', child: Text('trigger'))),
    );

    await hover(tester, find.text('trigger'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(panel).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('trigger')).top),
    );
  });

  testWidgets('it flips below a trigger with no room above', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        const KunTooltip(text: 'Copy', child: Text('trigger')),
        alignment: Alignment.topCenter,
      ),
    );

    await hover(tester, find.text('trigger'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(panel).top,
      greaterThanOrEqualTo(tester.getRect(find.text('trigger')).bottom),
    );
  });

  testWidgets('the caret straddles the panel edge, centred on the trigger',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        const KunTooltip(
          text: 'Copy',
          showArrow: true,
          child: Text('trigger'),
        ),
      ),
    );

    await hover(tester, find.text('trigger'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    final Rect box = tester.getRect(panel);
    final Rect caret = tester.getRect(find.byType(KunAnchorArrow));
    expect(caret.center.dy, moreOrLessEquals(box.bottom, epsilon: 0.5));
    expect(
      caret.center.dx,
      moreOrLessEquals(
        tester.getRect(find.text('trigger')).center.dx,
        epsilon: 1,
      ),
    );
  });

  testWidgets('a back gesture closes the tooltip instead of the page',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(const KunTooltip(text: 'Copy', child: Text('trigger'))),
    );

    await hover(tester, find.text('trigger'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(find.text('trigger'), findsOneWidget);
    expect(KunDismissLayers.debugLayers, isEmpty);
  });

  testWidgets('disposing an open tooltip leaves no dismiss layer behind',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(const KunTooltip(text: 'Copy', child: Text('trigger'))),
    );

    await hover(tester, find.text('trigger'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(KunDismissLayers.debugLayers, hasLength(1));

    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(KunDismissLayers.debugLayers, isEmpty);
  });

  testWidgets('the trigger carries the text as its description',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(const KunTooltip(text: 'Copy', child: Text('trigger'))),
    );

    expect(
      tester.getSemantics(find.text('trigger')).tooltip,
      'Copy',
    );
    semantics.dispose();
  });

  testWidgets('a KunButton child inside a node carries the tooltip itself',
      (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        Semantics(
          container: true,
          child: SizedBox(
            width: 400,
            child: Row(
              children: <Widget>[
                KunReaction(count: 1, label: 'Like', onChanged: (_) {}),
                KunTooltip(
                  text: 'Copy',
                  child: KunButton(onPressed: () {}, child: const Text('c')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final SemanticsNode node = tester.getSemantics(find.byType(KunButton));
    expect(node.rect.size, tester.getSize(find.byType(KunButton)));
    expect(node, isSemantics(isButton: true, tooltip: 'Copy'));
    handle.dispose();
  });
}
