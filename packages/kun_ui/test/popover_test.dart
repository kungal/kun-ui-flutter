import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/anchored.dart';
import 'package:kun_ui/src/foundation/dismiss_layers.dart';

Finder get panel => find.byKey(const ValueKey<String>('KunPopover.panel'));

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

KunPopover popover({
  KunPopoverPosition position = KunPopoverPosition.bottomStart,
  bool autoPosition = true,
  bool showArrow = false,
  bool fullWidth = false,
  KunPopoverTrigger openOn = KunPopoverTrigger.click,
  String? group,
  KunPopoverController? controller,
  Widget? content,
}) {
  return KunPopover(
    position: position,
    autoPosition: autoPosition,
    showArrow: showArrow,
    fullWidth: fullWidth,
    openOn: openOn,
    group: group,
    controller: controller,
    trigger: const SizedBox(width: 80, height: 32, child: Text('open')),
    child: content ?? const SizedBox(width: 160, height: 120),
  );
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

void main() {
  testWidgets('a tap opens the panel and a second tap closes it',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(popover()));

    expect(panel, findsNothing);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(KunDismissLayers.debugLayers, isEmpty);
  });

  testWidgets('a trigger with its own tap handler still opens it',
      (tester) async {
    setView(tester, const Size(800, 600));
    int pressed = 0;
    await tester.pumpWidget(
      wrap(
        KunPopover(
          trigger: KunButton(
            onPressed: () => pressed++,
            child: const Text('open'),
          ),
          child: const SizedBox(width: 160, height: 120),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(pressed, 1);
  });

  testWidgets('opening moves focus into the panel and closing returns it',
      (tester) async {
    setView(tester, const Size(800, 600));
    final FocusNode inside = FocusNode(debugLabel: 'inside');
    final FocusNode outside = FocusNode(debugLabel: 'outside');
    addTearDown(inside.dispose);
    addTearDown(outside.dispose);

    await tester.pumpWidget(
      wrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Focus(
              focusNode: outside,
              child: const SizedBox(width: 10, height: 10),
            ),
            popover(
              content: Focus(
                focusNode: inside,
                child: const SizedBox(width: 160, height: 40),
              ),
            ),
          ],
        ),
      ),
    );

    outside.requestFocus();
    await tester.pump();
    expect(outside.hasPrimaryFocus, isTrue);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(inside.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(outside.hasPrimaryFocus, isTrue);
  });

  testWidgets('a tap outside closes it', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            popover(),
            const SizedBox(width: 100, height: 100),
          ],
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
  });

  testWidgets('the caret straddles the panel edge, centred on the trigger',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        popover(position: KunPopoverPosition.bottom, showArrow: true),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final Rect box = tester.getRect(panel);
    final Rect caret = tester.getRect(find.byType(KunAnchorArrow));
    expect(caret.center.dy, moreOrLessEquals(box.top, epsilon: 0.5));
    expect(
      caret.center.dx,
      moreOrLessEquals(tester.getRect(find.text('open')).center.dx, epsilon: 1),
    );
  });

  testWidgets('a back gesture closes the panel instead of the page',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(popover()));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(KunDismissLayers.debugLayers, isEmpty);
  });

  testWidgets('it opens below the trigger with their left edges flush',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(popover()));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final Rect trigger = tester.getRect(find.text('open'));
    final Rect box = tester.getRect(panel);
    expect(box.top, greaterThanOrEqualTo(trigger.bottom));
    expect(box.left, moreOrLessEquals(trigger.left, epsilon: 0.5));
  });

  testWidgets('it flips to the other side when there is no room',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        popover(position: KunPopoverPosition.topStart),
        alignment: Alignment.topCenter,
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(panel).top,
      greaterThanOrEqualTo(tester.getRect(find.text('open')).bottom),
    );
  });

  testWidgets('autoPosition false keeps the side it was given', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        popover(
          position: KunPopoverPosition.topStart,
          autoPosition: false,
        ),
        alignment: Alignment.topCenter,
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(panel).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('open')).top),
    );
  });

  testWidgets('the controller opens, closes and toggles it', (tester) async {
    setView(tester, const Size(800, 600));
    final KunPopoverController controller = KunPopoverController();
    await tester.pumpWidget(wrap(popover(controller: controller)));

    expect(controller.isOpen, isFalse);
    controller.open();
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(controller.isOpen, isTrue);

    controller.toggle();
    await tester.pumpAndSettle();
    expect(panel, findsNothing);

    controller.open();
    await tester.pumpAndSettle();
    controller.close();
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
  });

  testWidgets('hover mode opens after the delay without taking focus',
      (tester) async {
    setView(tester, const Size(800, 600));
    final FocusNode outside = FocusNode(debugLabel: 'outside');
    addTearDown(outside.dispose);

    await tester.pumpWidget(
      wrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Focus(
              focusNode: outside,
              child: const SizedBox(width: 10, height: 10),
            ),
            popover(openOn: KunPopoverTrigger.hover),
          ],
        ),
      ),
    );

    outside.requestFocus();
    await tester.pump();

    await hover(tester, tester.getCenter(find.text('open')));
    expect(panel, findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(outside.hasPrimaryFocus, isTrue);
  });

  testWidgets('a tap still opens a hover popover on a touch device',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(popover(openOn: KunPopoverTrigger.hover)),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
  });

  testWidgets('a group keeps one sibling open at a time', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            KunPopover(
              openOn: KunPopoverTrigger.hover,
              group: 'bar',
              trigger: const SizedBox(width: 80, height: 32, child: Text('a')),
              child: const SizedBox(
                width: 120,
                height: 80,
                child: Text('panel a'),
              ),
            ),
            KunPopover(
              openOn: KunPopoverTrigger.hover,
              group: 'bar',
              trigger: const SizedBox(width: 80, height: 32, child: Text('b')),
              child: const SizedBox(
                width: 120,
                height: 80,
                child: Text('panel b'),
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
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('panel a'), findsOneWidget);

    await gesture.moveTo(tester.getCenter(find.text('b')));
    await tester.pumpAndSettle();
    expect(find.text('panel b'), findsOneWidget);
    expect(find.text('panel a'), findsNothing);

    await gesture.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(find.text('panel b'), findsNothing);
    expect(KunDismissLayers.debugLayers, isEmpty);
  });

  testWidgets('fullWidth makes the trigger fill its parent', (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(
      wrap(
        SizedBox(width: 400, child: popover(fullWidth: true)),
      ),
    );

    expect(
      tester.getRect(find.byType(KunPopover)).width,
      moreOrLessEquals(400, epsilon: 0.5),
    );
  });

  testWidgets('disposing an open popover leaves no dismiss layer behind',
      (tester) async {
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(popover()));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(KunDismissLayers.debugLayers, hasLength(1));

    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(KunDismissLayers.debugLayers, isEmpty);
  });

  testWidgets('the panel is a dialog and the trigger reports it expanded',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    setView(tester, const Size(800, 600));
    await tester.pumpWidget(wrap(popover()));

    expect(
      tester
          .getSemantics(find.text('open'))
          .getSemanticsData()
          .flagsCollection
          .isExpanded,
      Tristate.isFalse,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.text('open'))
          .getSemanticsData()
          .flagsCollection
          .isExpanded,
      Tristate.isTrue,
    );
    final SemanticsData dialog = tester
        .getSemantics(find.bySemanticsLabel('popover'))
        .getSemanticsData();
    expect(dialog.role, SemanticsRole.dialog);
    semantics.dispose();
  });

  testWidgets('a KunButton trigger inside a node carries expanded itself',
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
                KunPopover(
                  trigger: KunButton(
                    onPressed: () {},
                    child: const Text('open'),
                  ),
                  child: const Text('panel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final SemanticsNode node = tester.getSemantics(find.byType(KunButton));
    expect(node.rect.size, tester.getSize(find.byType(KunButton)));
    expect(node,
        isSemantics(isButton: true, label: 'open', hasExpandedState: true));
    handle.dispose();
  });
}
