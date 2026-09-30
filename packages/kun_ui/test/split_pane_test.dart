import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/focus_outline.dart';

const Size desktop = Size(1000, 400);
const Key startKey = Key('start-pane');
const Key endKey = Key('end-pane');
const ValueKey<String> handleKey = ValueKey<String>('KunSplitPane.handle');

Finder get handle => find.byKey(handleKey);

Widget wrap(
  Widget child, {
  Size size = desktop,
  KunTapTargetSize tapTargetSize = KunTapTargetSize.shrinkWrap,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: KunMessagesScope(
      messages: KunMessages.en,
      child: KunTheme(
        data: KunThemeData.light(tapTargetSize: tapTargetSize),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget pane({
  double size = 360,
  ValueChanged<double>? onSizeChanged,
  ValueChanged<double>? onResizeEnd,
  KunSplitSide primary = KunSplitSide.start,
  double minSize = 240,
  double maxSize = 480,
  List<double> snapPoints = const <double>[],
  double snapThreshold = 8,
  double step = 10,
  KunSplitStackBelow stackBelow = KunSplitStackBelow.md,
  KunSplitSide showPane = KunSplitSide.start,
  Widget? start,
  Widget? end,
}) {
  return KunSplitPane(
    size: size,
    onSizeChanged: onSizeChanged,
    onResizeEnd: onResizeEnd,
    primary: primary,
    minSize: minSize,
    maxSize: maxSize,
    snapPoints: snapPoints,
    snapThreshold: snapThreshold,
    step: step,
    stackBelow: stackBelow,
    showPane: showPane,
    start: start ?? const SizedBox.expand(key: startKey, child: Text('start')),
    end: end ?? const SizedBox.expand(key: endKey, child: Text('end')),
  );
}

double startWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(startKey)).width;

Future<void> focusHandle(WidgetTester tester) async {
  tester
      .widget<FocusableActionDetector>(
        find.descendant(
          of: handle,
          matching: find.byType(FocusableActionDetector),
        ),
      )
      .focusNode!
      .requestFocus();
  await tester.pump();
}

class _Alive extends StatefulWidget {
  const _Alive({required this.label});

  final String label;

  @override
  State<_Alive> createState() => _AliveState();
}

class _AliveState extends State<_Alive> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      excludeFromSemantics: true,
      onTap: () => setState(() => count += 1),
      child: Text('${widget.label}:$count'),
    );
  }
}

void main() {
  testWidgets('a mouse drag emits on each move and ends once', (
    WidgetTester tester,
  ) async {
    final List<double> moved = <double>[];
    final List<double> ended = <double>[];
    await tester.pumpWidget(
      wrap(
        pane(
          stackBelow: KunSplitStackBelow.never,
          onSizeChanged: moved.add,
          onResizeEnd: ended.add,
        ),
      ),
    );
    expect(startWidth(tester), 360);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(handle),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(moved, isEmpty);
    expect(ended, isEmpty);

    await gesture.moveBy(const Offset(10, 0));
    await tester.pump();
    expect(moved, <double>[370]);
    expect(ended, isEmpty);

    await gesture.moveBy(const Offset(10, 0));
    await tester.pump();
    expect(moved, <double>[370, 380]);

    await gesture.up();
    await tester.pump();
    expect(ended, <double>[380]);
    expect(startWidth(tester), 380);
  });

  testWidgets('a second pointer is ignored mid-drag',
      (WidgetTester tester) async {
    final List<double> moved = <double>[];
    await tester.pumpWidget(
      wrap(
        pane(
          stackBelow: KunSplitStackBelow.never,
          onSizeChanged: moved.add,
        ),
      ),
    );
    final Offset centre = tester.getCenter(handle);
    final TestGesture first = await tester.startGesture(
      centre,
      kind: PointerDeviceKind.mouse,
      pointer: 1,
    );
    await first.moveBy(const Offset(10, 0));
    await tester.pump();
    expect(moved, <double>[370]);

    final TestGesture second = await tester.startGesture(
      centre,
      pointer: 2,
    );
    await second.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(moved, <double>[370]);

    await second.up();
    await first.moveBy(const Offset(10, 0));
    await tester.pump();
    expect(moved, <double>[370, 380]);
    await first.up();
  });

  testWidgets('a secondary-button drag is ignored',
      (WidgetTester tester) async {
    final List<double> moved = <double>[];
    await tester.pumpWidget(
      wrap(
        pane(
          stackBelow: KunSplitStackBelow.never,
          onSizeChanged: moved.add,
        ),
      ),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(handle),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(moved, isEmpty);
    expect(startWidth(tester), 360);
    await gesture.up();
  });

  testWidgets('a mouse drag focuses the divider without lighting the ring', (
    WidgetTester tester,
  ) async {
    // A desktop: FocusableActionDetector reads the highlight mode as it
    // mounts, and the test binding starts in touch mode.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    await tester.pumpWidget(
      wrap(pane(stackBelow: KunSplitStackBelow.never)),
    );
    bool ringVisible() =>
        tester.widget<KunFocusOutline>(find.byType(KunFocusOutline)).visible;

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(handle),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(10, 0));
    await gesture.up();
    await tester.pump();
    expect(startWidth(tester), 370);
    expect(ringVisible(), isFalse, reason: 'a press is not focus-visible');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(startWidth(tester), 380, reason: 'the press still focused it');
    expect(ringVisible(), isTrue, reason: 'a key makes focus visible');
  });

  testWidgets('arrow keys, Shift, Home and End, with primary start and end', (
    WidgetTester tester,
  ) async {
    final List<double> moved = <double>[];
    final List<double> ended = <double>[];
    await tester.pumpWidget(
      wrap(
        pane(
          stackBelow: KunSplitStackBelow.never,
          onSizeChanged: moved.add,
          onResizeEnd: ended.add,
        ),
      ),
    );
    await focusHandle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(moved, <double>[370]);
    expect(ended, <double>[370]);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(moved.last, 420);
    expect(ended.last, 420);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(moved.last, 240);
    expect(startWidth(tester), 240);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(moved.last, 480);
    expect(startWidth(tester), 480);

    moved.clear();
    ended.clear();
    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pumpWidget(
      wrap(
        pane(
          size: 360,
          primary: KunSplitSide.end,
          stackBelow: KunSplitStackBelow.never,
          onSizeChanged: moved.add,
          onResizeEnd: ended.add,
        ),
      ),
    );
    await focusHandle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(moved, <double>[350]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(moved.last, 360);
  });

  testWidgets('snapping on a drag, and no snap reversal on a key step', (
    WidgetTester tester,
  ) async {
    final List<double> moved = <double>[];
    await tester.pumpWidget(
      wrap(
        pane(
          snapPoints: const <double>[360, 412],
          stackBelow: KunSplitStackBelow.never,
          onSizeChanged: moved.add,
        ),
      ),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(handle),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(5, 0));
    await tester.pump();
    expect(moved, isEmpty);
    expect(startWidth(tester), 360);

    await gesture.moveBy(const Offset(7, 0));
    await tester.pump();
    expect(moved, <double>[372]);
    await gesture.up();

    moved.clear();
    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pumpWidget(
      wrap(
        pane(
          size: 360,
          step: 5,
          snapPoints: const <double>[360, 412],
          stackBelow: KunSplitStackBelow.never,
          onSizeChanged: moved.add,
        ),
      ),
    );
    await focusHandle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(moved, <double>[365]);
    expect(startWidth(tester), 365);
  });

  testWidgets('stacking is decided by its own width, not the window', (
    WidgetTester tester,
  ) async {
    Widget host({required Size window, required double width}) {
      return MediaQuery(
        data: MediaQueryData(size: window),
        child: KunMessagesScope(
          messages: KunMessages.en,
          child: KunTheme(
            data: KunThemeData.light(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  height: 400,
                  child: pane(showPane: KunSplitSide.start),
                ),
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(host(window: desktop, width: 700));
    expect(find.text('start'), findsOneWidget);
    expect(find.text('end'), findsNothing);
    expect(handle, findsNothing);

    await tester.pumpWidget(host(window: const Size(500, 400), width: 800));
    expect(find.text('start'), findsOneWidget);
    expect(find.text('end'), findsOneWidget);
    expect(handle, findsOneWidget);
  });

  testWidgets('the hidden pane stays kept alive, with TickerMode off', (
    WidgetTester tester,
  ) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    Widget host({required double width, required KunSplitSide showPane}) {
      return wrap(
        pane(
          showPane: showPane,
          start: ListView(
            controller: controller,
            children: const <Widget>[
              SizedBox(height: 800, child: Text('top')),
              Text('bottom'),
            ],
          ),
          end: const _Alive(label: 'end'),
        ),
        size: Size(width, 400),
      );
    }

    await tester.pumpWidget(host(width: 800, showPane: KunSplitSide.start));
    controller.jumpTo(120);
    await tester.pump();
    expect(controller.offset, 120);

    await tester.pumpWidget(host(width: 700, showPane: KunSplitSide.end));
    expect(find.text('end:0'), findsOneWidget);
    expect(find.text('top', skipOffstage: false), findsOneWidget);
    expect(controller.offset, 120);
    final bool ticker = tester
        .widget<TickerMode>(
          find
              .ancestor(
                of: find.text('top', skipOffstage: false),
                matching: find.byType(TickerMode, skipOffstage: false),
              )
              .first,
        )
        .enabled;
    expect(ticker, isFalse);

    await tester.tap(find.text('end:0'));
    await tester.pump();
    expect(find.text('end:1'), findsOneWidget);

    await tester.pumpWidget(host(width: 800, showPane: KunSplitSide.start));
    expect(controller.offset, 120);
    expect(find.text('end:1', skipOffstage: false), findsOneWidget);
  });

  testWidgets('semantics include onIncrease and onDecrease', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(pane(stackBelow: KunSplitStackBelow.never)),
    );
    final SemanticsData data = tester.getSemantics(handle).getSemanticsData();
    expect(data.label, KunMessages.en.splitPane.handle);
    expect(data.value, '360');
    expect(data.minValue, '240');
    expect(data.maxValue, '480');
    expect(data.increasedValue, '370');
    expect(data.decreasedValue, '350');
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
    expect(data.flagsCollection.isSlider, isTrue);

    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
      tester.getSemantics(handle).id,
      SemanticsAction.increase,
    );
    await tester.pump();
    expect(startWidth(tester), 370);
    semantics.dispose();
  });

  testWidgets('the cursor is resizeColumn over the divider and while dragging',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(pane(stackBelow: KunSplitStackBelow.never)),
    );
    final TestGesture mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    await mouse.moveTo(tester.getCenter(handle));
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.resizeColumn,
    );

    await mouse.down(tester.getCenter(handle));
    await mouse.moveBy(const Offset(8, 0));
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.byKey(startKey)));
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.resizeColumn,
    );
    await mouse.up();
  });

  testWidgets('the parent replacing size updates the pane', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(pane(size: 360, stackBelow: KunSplitStackBelow.never)),
    );
    expect(startWidth(tester), 360);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(handle),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(startWidth(tester), 380);
    await gesture.up();

    await tester.pumpWidget(
      wrap(pane(size: 280, stackBelow: KunSplitStackBelow.never)),
    );
    expect(startWidth(tester), 280);
  });
}
