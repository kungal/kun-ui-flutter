import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/outer_shadow.dart';

Finder toast(String id) => find.byKey(ValueKey<String>('KunMessage.$id'));

Finder toastBar(String id) =>
    find.byKey(ValueKey<String>('KunMessage.$id.bar'));

Finder toastClose(String id) =>
    find.byKey(ValueKey<String>('KunMessage.$id.closeOpacity'));

Finder toastTranslate(String id) =>
    find.byKey(ValueKey<String>('KunMessage.$id.translate'));

Finder toastScale(String id) =>
    find.byKey(ValueKey<String>('KunMessage.$id.scale'));

Widget wrap(
  Widget child, {
  KunThemeData? theme,
  KunMessages? messages,
  bool reducedMotion = false,
  EdgeInsets viewPadding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  bool webKeys = false,
  bool host = true,
  TextStyle? appTextStyle,
  Widget Function(Widget child)? wrapHome,
}) {
  Widget home = child;
  if (wrapHome != null) {
    home = wrapHome(child);
  }
  Widget app = KunTheme(
    data: theme ?? KunThemeData.light(),
    child: WidgetsApp(
      color: KunColors.black,
      debugShowCheckedModeBanner: false,
      textStyle: appTextStyle,
      shortcuts: webKeys
          ? <ShortcutActivator, Intent>{
              ...WidgetsApp.defaultShortcuts,
              const SingleActivator(LogicalKeyboardKey.enter):
                  const ButtonActivateIntent(),
            }
          : null,
      builder: (BuildContext context, Widget? navigator) {
        Widget tree = navigator!;
        if (host) {
          tree = KunMessageProvider(child: tree);
        }
        if (reducedMotion ||
            viewPadding != EdgeInsets.zero ||
            viewInsets != EdgeInsets.zero) {
          final MediaQueryData parent = MediaQuery.of(context);
          tree = MediaQuery(
            data: parent.copyWith(
              disableAnimations: reducedMotion || parent.disableAnimations,
              viewPadding: viewPadding,
              viewInsets: viewInsets,
            ),
            child: tree,
          );
        }
        return tree;
      },
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
  if (messages != null) {
    app = KunMessagesScope(messages: messages, child: app);
  }
  return app;
}

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

double translateX(WidgetTester tester, String id) {
  return tester
      .widget<Transform>(toastTranslate(id))
      .transform
      .getTranslation()
      .x;
}

double translateY(WidgetTester tester, String id) {
  return tester
      .widget<Transform>(toastTranslate(id))
      .transform
      .getTranslation()
      .y;
}

double scaleOf(WidgetTester tester, String id) {
  return tester.widget<Transform>(toastScale(id)).transform.storage[0];
}

double barScale(WidgetTester tester, String id) {
  return tester.widget<Transform>(toastBar(id)).transform.storage[0];
}

double closeOpacity(WidgetTester tester, String id) {
  return tester.widget<AnimatedOpacity>(toastClose(id)).opacity;
}

double toastOpacity(WidgetTester tester, String id) {
  return tester
      .widget<Opacity>(
        find.ancestor(of: toast(id), matching: find.byType(Opacity)).first,
      )
      .opacity;
}

T toastLayer<T extends Decoration>(WidgetTester tester, String id) {
  return tester
      .widgetList<DecoratedBox>(
        find.descendant(of: toast(id), matching: find.byType(DecoratedBox)),
      )
      .map((DecoratedBox box) => box.decoration)
      .whereType<T>()
      .first;
}

BoxDecoration toastDecoration(WidgetTester tester, String id) {
  return toastLayer<BoxDecoration>(tester, id);
}

List<BoxShadow> toastShadows(WidgetTester tester, String id) {
  return toastLayer<KunOuterShadowDecoration>(tester, id).shadows;
}

TextStyle renderedStyle(WidgetTester tester, Finder text) {
  return tester.renderObject<RenderParagraph>(text).text.style!;
}

const Duration _sticky = Duration.zero;

Future<void> pumpToast(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    debugResetKunMessages();
  });

  testWidgets('store ids, dedup, dismiss and unknown id',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    await tester.pumpWidget(wrap(const SizedBox()));
    final String first = showKunMessage(
      'Saved!',
      KunMessageType.success,
      duration: _sticky,
    );
    expect(first, 'message_1');
    await pumpToast(tester);
    expect(find.text('Saved!'), findsOneWidget);
    expect(find.text('2'), findsNothing);

    final String again = showKunMessage(
      'Saved!',
      KunMessageType.success,
      duration: _sticky,
    );
    expect(again, first);
    await tester.pump();
    expect(find.text('Saved!'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    final String otherType = showKunMessage(
      'Saved!',
      KunMessageType.info,
      duration: _sticky,
    );
    expect(otherType, isNot(first));
    final String otherPos = showKunMessage(
      'Saved!',
      KunMessageType.success,
      duration: _sticky,
      position: KunMessagePosition.topLeft,
    );
    expect(otherPos, isNot(first));
    await tester.pump();
    expect(find.text('Saved!'), findsNWidgets(3));

    dismissKunMessage(otherType);
    await pumpToast(tester);
    expect(find.text('Saved!'), findsNWidgets(2));

    dismissKunMessage('message_missing');
    await tester.pump();
    expect(find.text('Saved!'), findsNWidgets(2));
  });

  testWidgets('order and cap', (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    await tester.pumpWidget(wrap(const SizedBox()));
    showKunMessage('top-a', KunMessageType.info, duration: _sticky);
    showKunMessage('top-b', KunMessageType.info, duration: _sticky);
    showKunMessage('top-c', KunMessageType.info, duration: _sticky);
    await pumpToast(tester);
    expect(
      tester.getTopLeft(find.text('top-a')).dy,
      lessThan(tester.getTopLeft(find.text('top-b')).dy),
    );
    expect(
      tester.getTopLeft(find.text('top-b')).dy,
      lessThan(tester.getTopLeft(find.text('top-c')).dy),
    );

    debugResetKunMessages();
    await tester.pumpWidget(wrap(const SizedBox()));
    showKunMessage(
      'bot-a',
      KunMessageType.info,
      duration: _sticky,
      position: KunMessagePosition.bottomCenter,
    );
    showKunMessage(
      'bot-b',
      KunMessageType.info,
      duration: _sticky,
      position: KunMessagePosition.bottomCenter,
    );
    showKunMessage(
      'bot-c',
      KunMessageType.info,
      duration: _sticky,
      position: KunMessagePosition.bottomCenter,
    );
    await pumpToast(tester);
    expect(
      tester.getTopLeft(find.text('bot-c')).dy,
      lessThan(tester.getTopLeft(find.text('bot-b')).dy),
    );
    expect(
      tester.getTopLeft(find.text('bot-b')).dy,
      lessThan(tester.getTopLeft(find.text('bot-a')).dy),
    );

    debugResetKunMessages();
    await tester.pumpWidget(wrap(const SizedBox()));
    showKunMessage(
      'keep',
      KunMessageType.warn,
      duration: _sticky,
      position: KunMessagePosition.topLeft,
    );
    for (int i = 1; i <= 6; i++) {
      showKunMessage('cap-$i', KunMessageType.info, duration: _sticky);
    }
    await tester.pump();
    expect(find.text('cap-1'), findsOneWidget);
    await pumpToast(tester);
    expect(find.text('cap-1'), findsNothing);
    expect(find.text('cap-2'), findsOneWidget);
    expect(find.text('cap-6'), findsOneWidget);
    expect(find.text('keep'), findsOneWidget);
  });

  testWidgets('timer hover press touch and dedup', (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    await tester.pumpWidget(wrap(const SizedBox()));
    showKunMessage('tick', KunMessageType.info);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.text('tick'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(KunDurations.base);
    await tester.pump();
    expect(find.text('tick'), findsNothing);

    showKunMessage('forever', KunMessageType.info, duration: _sticky);
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('forever'), findsOneWidget);
    dismissKunMessage('message_2');
    await pumpToast(tester);

    showKunMessage('hover', KunMessageType.info);
    await tester.pump();
    await tester.pump(KunDurations.slow);
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 1,
    );
    await mouse.addPointer(location: tester.getCenter(toast('message_3')));
    addTearDown(mouse.removePointer);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('hover'), findsOneWidget);
    await mouse.moveTo(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump();
    await tester.pump(KunDurations.base);
    await tester.pump();
    expect(find.text('hover'), findsNothing);

    showKunMessage('press', KunMessageType.info);
    await tester.pump();
    await tester.pump(KunDurations.slow);
    await mouse.moveTo(tester.getCenter(toast('message_4')));
    await tester.pump();
    await mouse.down(tester.getCenter(toast('message_4')));
    await tester.pump();
    await mouse.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('press'), findsOneWidget);
    await mouse.moveTo(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump();
    await tester.pump(KunDurations.base);
    await tester.pump();
    expect(find.text('press'), findsNothing);

    showKunMessage('touch', KunMessageType.info);
    await tester.pump();
    await tester.pump(KunDurations.slow);
    final TestGesture finger = await tester.startGesture(
      tester.getCenter(toast('message_5')),
      pointer: 2,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('touch'), findsOneWidget);
    await finger.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump();
    await tester.pump(KunDurations.base);
    await tester.pump();
    expect(find.text('touch'), findsNothing);

    showKunMessage(
      'dedup-hover',
      KunMessageType.success,
      duration: const Duration(milliseconds: 800),
    );
    await tester.pump();
    await tester.pump(KunDurations.slow);
    await mouse.moveTo(tester.getCenter(toast('message_6')));
    await tester.pump();
    showKunMessage(
      'dedup-hover',
      KunMessageType.success,
      duration: const Duration(milliseconds: 2000),
    );
    await tester.pump();
    await mouse.moveTo(tester.getCenter(toast('message_6')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('dedup-hover'), findsOneWidget);
    await mouse.moveTo(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1990));
    expect(find.text('dedup-hover'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    await tester.pump(KunDurations.base);
    await tester.pump();
    expect(find.text('dedup-hover'), findsNothing);

    showKunMessage(
      'dedup-run',
      KunMessageType.error,
      duration: const Duration(milliseconds: 800),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    showKunMessage(
      'dedup-run',
      KunMessageType.error,
      duration: const Duration(milliseconds: 1000),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('dedup-run'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(KunDurations.base);
    await tester.pump();
    expect(find.text('dedup-run'), findsNothing);
  });

  testWidgets('progress bar scale pause zero and reduced motion',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    await tester.pumpWidget(wrap(const SizedBox()));
    showKunMessage('bar', KunMessageType.info);
    await tester.pump();
    expect(barScale(tester, 'message_1'), closeTo(1, 0.001));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(barScale(tester, 'message_1'), closeTo(0.5, 0.05));
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(toast('message_1')));
    await tester.pump();
    final double paused = barScale(tester, 'message_1');
    await tester.pump(const Duration(milliseconds: 400));
    expect(barScale(tester, 'message_1'), closeTo(paused, 0.001));
    dismissKunMessage('message_1');
    await pumpToast(tester);

    showKunMessage('none', KunMessageType.info, duration: _sticky);
    await tester.pump();
    expect(toastBar('message_2'), findsNothing);

    await tester.pumpWidget(wrap(const SizedBox(), reducedMotion: true));
    showKunMessage(
      'reduced',
      KunMessageType.info,
      duration: const Duration(milliseconds: 400),
    );
    await tester.pump();
    expect(toastBar('message_3'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump();
    expect(find.text('reduced'), findsNothing);
  });

  testWidgets('close button opacity focus tap Enter and label',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    final FocusHighlightStrategy previous =
        FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() {
      FocusManager.instance.highlightStrategy = previous;
    });

    await tester.pumpWidget(wrap(const SizedBox(), webKeys: true));
    showKunMessage('closable', KunMessageType.info, duration: _sticky);
    await pumpToast(tester);
    expect(closeOpacity(tester, 'message_1'), 0);

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(toast('message_1')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(closeOpacity(tester, 'message_1'), 1);
    await mouse.moveTo(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(closeOpacity(tester, 'message_1'), 0);

    final FocusNode closeFocus =
        Focus.of(tester.element(toastClose('message_1')));
    closeFocus.requestFocus();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(closeOpacity(tester, 'message_1'), 1);
    expect(
      tester.getSemantics(find.byIcon(KunIcons.x)).label,
      KunMessages.zhCN.message.close,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await pumpToast(tester);
    expect(find.text('closable'), findsNothing);

    showKunMessage('tap-close', KunMessageType.warn, duration: _sticky);
    await pumpToast(tester);
    await tester.tap(toastClose('message_2'));
    await pumpToast(tester);
    expect(find.text('tap-close'), findsNothing);

    await tester.pumpWidget(
      wrap(const SizedBox(), messages: KunMessages.en),
    );
    showKunMessage('en-close', KunMessageType.info, duration: _sticky);
    await pumpToast(tester);
    expect(
      tester.getSemantics(find.byIcon(KunIcons.x)).label,
      KunMessages.en.message.close,
    );
  });

  testWidgets('swipe throw snap close-start and vertical',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    await tester.pumpWidget(wrap(const SizedBox()));
    showKunMessage('swipe-right', KunMessageType.info, duration: _sticky);
    await pumpToast(tester);
    final Rect rest = tester.getRect(toast('message_1'));
    final TestGesture drag = await tester.startGesture(rest.center);
    await drag.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(
        tester.getRect(toast('message_1')).left, closeTo(rest.left + 100, 1));
    await drag.up();
    await tester.pump();
    await tester.pump(KunDurations.exit ~/ 2);
    expect(
        tester.getRect(toast('message_1')).left, greaterThan(rest.left + 100));
    expect(toastOpacity(tester, 'message_1'), lessThan(1));
    await tester.pump(KunDurations.exit ~/ 2);
    expect(
      tester.getRect(toast('message_1')).left,
      closeTo(rest.left + 100 + rest.width, 2),
    );
    await tester.pump(KunDurations.base);
    await tester.pump();
    expect(find.text('swipe-right'), findsNothing);

    await tester.pumpWidget(wrap(const SizedBox(), reducedMotion: true));
    showKunMessage('swipe-fast', KunMessageType.info, duration: _sticky);
    await tester.pump();
    await tester.pump();
    final Rect restFast = tester.getRect(toast('message_2'));
    final TestGesture fast = await tester.startGesture(restFast.center);
    await fast.moveBy(const Offset(100, 0));
    await tester.pump();
    await fast.up();
    await tester.pump();
    await tester.pump();
    expect(find.text('swipe-fast'), findsNothing);

    await tester.pumpWidget(wrap(const SizedBox()));
    showKunMessage('swipe-left', KunMessageType.info, duration: _sticky);
    await pumpToast(tester);
    final Rect restLeft = tester.getRect(toast('message_3'));
    final TestGesture left = await tester.startGesture(restLeft.center);
    await left.moveBy(const Offset(-100, 0));
    await tester.pump();
    await left.up();
    await tester.pump();
    await tester.pump(KunDurations.exit ~/ 2);
    expect(
      tester.getRect(toast('message_3')).left,
      lessThan(restLeft.left - 100),
    );
    await tester.pump(KunDurations.exit);
    await tester.pump(KunDurations.base);
    await tester.pump();
    expect(find.text('swipe-left'), findsNothing);

    showKunMessage('snap', KunMessageType.info, duration: _sticky);
    await pumpToast(tester);
    final Rect restSnap = tester.getRect(toast('message_4'));
    final TestGesture hold = await tester.startGesture(restSnap.center);
    await hold.moveBy(const Offset(-50, 0));
    await tester.pump();
    expect(
      tester.getRect(toast('message_4')).left,
      closeTo(restSnap.left - 50, 1),
    );
    expect(toastOpacity(tester, 'message_4'), closeTo(0.75, 0.01));
    await hold.up();
    await tester.pump();
    await tester.pump(KunDurations.slow ~/ 2);
    final double midLeft = tester.getRect(toast('message_4')).left;
    expect(midLeft, greaterThan(restSnap.left - 50));
    expect(midLeft, lessThan(restSnap.left));
    await tester.pump(KunDurations.slow);
    expect(tester.getRect(toast('message_4')).left, closeTo(restSnap.left, 1));

    showKunMessage('from-close', KunMessageType.info, duration: _sticky);
    await pumpToast(tester);
    final Rect restClose = tester.getRect(toast('message_5'));
    final Rect closeRect = tester.getRect(toastClose('message_5'));
    final TestGesture onClose = await tester.startGesture(closeRect.center);
    await onClose.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(tester.getRect(toast('message_5')).left, closeTo(restClose.left, 1));
    await onClose.up();
    await tester.pump();

    showKunMessage('vertical', KunMessageType.info, duration: _sticky);
    await pumpToast(tester);
    final Rect restVert = tester.getRect(toast('message_6'));
    final TestGesture vert = await tester.startGesture(restVert.center);
    await vert.moveBy(const Offset(0, 80));
    await tester.pump();
    expect(tester.getRect(toast('message_6')).left, closeTo(restVert.left, 1));
    await vert.up();
    await tester.pump();
  });

  testWidgets('a second finger neither restarts nor ends a swipe',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    await tester.pumpWidget(wrap(const SizedBox()));
    showKunMessage('two', KunMessageType.info, duration: _sticky);
    await pumpToast(tester);
    final Rect rest = tester.getRect(toast('message_1'));
    final TestGesture first = await tester.startGesture(rest.center);
    await first.moveBy(const Offset(-50, 0));
    await tester.pump();
    final TestGesture second = await tester.startGesture(
      rest.center + const Offset(40, 0),
      pointer: 7,
    );
    await second.moveBy(const Offset(-150, 0));
    await tester.pump();
    expect(tester.getRect(toast('message_1')).left, closeTo(rest.left - 50, 1));
    await second.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(toast('message_1')).left, closeTo(rest.left - 50, 1));
    await first.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(toast('message_1')).left, closeTo(rest.left, 1));
    expect(find.text('two'), findsOneWidget);
  });

  testWidgets('geometry positions safe area keyboard and parts',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    await tester.pumpWidget(wrap(const SizedBox()));
    showKunMessage('g-center', KunMessageType.success, duration: _sticky);
    await pumpToast(tester);
    final Rect center = tester.getRect(toast('message_1'));
    expect(center.width, 352);
    expect(center.top, 32);
    expect(center.left, 464);

    showKunMessage(
      'g-left',
      KunMessageType.success,
      duration: _sticky,
      position: KunMessagePosition.topLeft,
    );
    await pumpToast(tester);
    expect(tester.getRect(toast('message_2')).left, 32);

    showKunMessage(
      'g-right',
      KunMessageType.success,
      duration: _sticky,
      position: KunMessagePosition.topRight,
    );
    await pumpToast(tester);
    expect(tester.getRect(toast('message_3')).right, 1248);

    showKunMessage(
      'g-bottom',
      KunMessageType.success,
      duration: _sticky,
      position: KunMessagePosition.bottomCenter,
    );
    await pumpToast(tester);
    expect(tester.getRect(toast('message_4')).bottom, 756);

    debugResetKunMessages();
    await tester.pumpWidget(wrap(const SizedBox()));
    showKunMessage('stack-a', KunMessageType.info, duration: _sticky);
    showKunMessage('stack-b', KunMessageType.info, duration: _sticky);
    await pumpToast(tester);
    expect(
      tester.getRect(toast('message_2')).top -
          tester.getRect(toast('message_1')).bottom,
      12,
    );

    final BoxDecoration decoration = toastDecoration(tester, 'message_1');
    expect(decoration.borderRadius, BorderRadius.circular(KunRadius.lg));
    final Rect box = tester.getRect(toast('message_1'));
    final Rect icon = tester.getRect(find.byIcon(KunIcons.info).first);
    expect(icon.width, 24);
    expect(icon.height, 24);
    expect(icon.left - box.left, 16);
    expect(icon.top - box.top, 18);
    expect(tester.getTopLeft(find.text('stack-a')).dx - icon.right, 12);
    showKunMessage('stack-a', KunMessageType.info, duration: _sticky);
    await tester.pump();
    expect(tester.getSize(find.text('2')).width, lessThanOrEqualTo(24));
    final Rect close = tester.getRect(toastClose('message_1'));
    expect(close.width, 24);
    expect(close.height, 24);

    debugResetKunMessages();
    setView(tester, const Size(360, 800));
    await tester.pumpWidget(wrap(const SizedBox()));
    showKunMessage(
      'narrow',
      KunMessageType.info,
      duration: _sticky,
      position: KunMessagePosition.topLeft,
    );
    await pumpToast(tester);
    final Rect narrow = tester.getRect(toast('message_1'));
    expect(narrow.left, 32);
    expect(narrow.right, 360);

    setView(tester, const Size(1280, 800));
    await tester.pumpWidget(
      wrap(const SizedBox(), viewPadding: const EdgeInsets.only(top: 24)),
    );
    showKunMessage('padded', KunMessageType.info, duration: _sticky);
    await pumpToast(tester);
    expect(tester.getRect(toast('message_1')).top, 56);

    debugResetKunMessages();
    await tester.pumpWidget(
      wrap(
        const SizedBox(),
        viewInsets: const EdgeInsets.only(bottom: 300),
      ),
    );
    showKunMessage(
      'keyboard',
      KunMessageType.info,
      duration: _sticky,
      position: KunMessagePosition.bottomCenter,
    );
    await pumpToast(tester);
    expect(tester.getRect(toast('message_1')).bottom, 456);
  });

  testWidgets('colours for every type in light and dark',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    const List<(KunMessageType, IconData)> types = <(KunMessageType, IconData)>[
      (KunMessageType.success, KunIcons.circleCheck),
      (KunMessageType.error, KunIcons.circleX),
      (KunMessageType.warn, KunIcons.triangleAlert),
      (KunMessageType.info, KunIcons.info),
    ];
    for (final bool dark in <bool>[false, true]) {
      debugResetKunMessages();
      await tester.pumpWidget(
        wrap(
          const SizedBox(),
          theme: dark ? KunThemeData.dark() : KunThemeData.light(),
        ),
      );
      final KunColorScheme scheme = dark ? KunColors.dark : KunColors.light;
      for (int i = 0; i < types.length; i++) {
        final KunMessageType type = types[i].$1;
        final IconData icon = types[i].$2;
        final KunColorScale scale = switch (type) {
          KunMessageType.success => scheme.success,
          KunMessageType.error => scheme.danger,
          KunMessageType.warn => scheme.warning,
          KunMessageType.info => scheme.primary,
        };
        final String id = showKunMessage(
          'c-$dark-$i',
          type,
          duration: const Duration(milliseconds: 5000),
          position: KunMessagePosition.values[i],
        );
        showKunMessage(
          'c-$dark-$i',
          type,
          duration: const Duration(milliseconds: 5000),
          position: KunMessagePosition.values[i],
        );
        await tester.pump();
        final BoxDecoration decoration = toastDecoration(tester, id);
        final Color fill =
            dark ? scale.shade50.withValues(alpha: 0.9) : scale.shade50;
        expect(decoration.color, fill);
        expect(decoration.boxShadow, isNull);
        expect(
          toastShadows(tester, id),
          <BoxShadow>[
            ...KunShadows.md,
            BoxShadow(
                color: scale.solid.withValues(alpha: 0.5), spreadRadius: 1),
          ],
        );
        expect(
          tester.widget<Icon>(find.byIcon(icon)).color,
          scale.shade500,
        );
        expect(renderedStyle(tester, find.text('c-$dark-$i')).color,
            scale.shade800);
        expect(
            renderedStyle(tester,
                    find.descendant(of: toast(id), matching: find.text('2')))
                .color,
            scale.shade800);
        final Transform bar = tester.widget<Transform>(toastBar(id));
        final DecoratedBox barBox = bar.child! as DecoratedBox;
        expect((barBox.decoration as BoxDecoration).color, scale.shade400);
        final DecoratedBox countBox = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: toast(id),
                matching: find.byWidgetPredicate(
                  (Widget widget) =>
                      widget is DecoratedBox &&
                      widget.decoration is BoxDecoration &&
                      (widget.decoration as BoxDecoration).shape ==
                          BoxShape.circle,
                ),
              )
              .first,
        );
        expect(
          (countBox.decoration as BoxDecoration).color,
          scale.solid.withValues(alpha: 0.1),
        );
      }
    }
  });

  testWidgets('the app shell text style does not reach a toast',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    // MaterialApp hands WidgetsApp this kind of fallback, and the host sits
    // above every route that would replace it.
    await tester.pumpWidget(
      wrap(
        const SizedBox(),
        appTextStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 48,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.underline,
        ),
      ),
    );
    showKunMessage('plain', KunMessageType.info, duration: _sticky);
    showKunMessage('plain', KunMessageType.info, duration: _sticky);
    await pumpToast(tester);
    for (final String text in <String>['plain', '2']) {
      final TextStyle style = renderedStyle(tester, find.text(text));
      expect(style.fontFamily, isNull);
      expect(style.decoration, isNull);
    }
    expect(renderedStyle(tester, find.text('plain')).fontSize,
        KunText.sm.fontSize);
    expect(renderedStyle(tester, find.text('plain')).fontWeight,
        KunFontWeights.medium);
    expect(renderedStyle(tester, find.text('2')).fontSize, KunText.xs.fontSize);
    expect(
        renderedStyle(tester, find.text('2')).fontWeight, KunFontWeights.bold);
  });

  testWidgets('enter leave move and reduced motion',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    await tester.pumpWidget(wrap(const SizedBox()));
    showKunMessage('enter', KunMessageType.info, duration: _sticky);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(translateY(tester, 'message_1'), lessThan(0));
    expect(scaleOf(tester, 'message_1'), lessThan(1));
    expect(toastOpacity(tester, 'message_1'), lessThan(1));
    await tester.pumpAndSettle();
    expect(translateY(tester, 'message_1'), closeTo(0, 0.001));
    expect(scaleOf(tester, 'message_1'), closeTo(1, 0.001));
    expect(toastOpacity(tester, 'message_1'), closeTo(1, 0.001));

    debugResetKunMessages();
    await tester.pumpWidget(wrap(const SizedBox()));
    showKunMessage('a', KunMessageType.info, duration: _sticky);
    showKunMessage('b', KunMessageType.info, duration: _sticky);
    showKunMessage('c', KunMessageType.info, duration: _sticky);
    await pumpToast(tester);
    final double y1 = tester.getTopLeft(find.text('a')).dy;
    final double y2 = tester.getTopLeft(find.text('b')).dy;
    final double y3 = tester.getTopLeft(find.text('c')).dy;
    dismissKunMessage('message_1');
    await tester.pump();
    await tester.pump(KunDurations.base ~/ 2);
    expect(tester.getTopLeft(find.text('a')).dy, greaterThan(y1 - 35));
    expect(tester.getTopLeft(find.text('b')).dy, lessThan(y2));
    expect(tester.getTopLeft(find.text('c')).dy, lessThan(y3));
    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing);
    expect(tester.getTopLeft(find.text('b')).dy, closeTo(y1, 2));
    expect(tester.getTopLeft(find.text('c')).dy, closeTo(y2, 2));

    debugResetKunMessages();
    await tester.pumpWidget(wrap(const SizedBox(), reducedMotion: true));
    showKunMessage('instant', KunMessageType.info, duration: _sticky);
    await tester.pump();
    expect(translateY(tester, 'message_1'), closeTo(0, 0.001));
    expect(scaleOf(tester, 'message_1'), closeTo(1, 0.001));
    showKunMessage('i2', KunMessageType.info, duration: _sticky);
    showKunMessage('i3', KunMessageType.info, duration: _sticky);
    await tester.pump();
    dismissKunMessage('message_1');
    await tester.pump();
    expect(find.text('instant'), findsNothing);
  });

  testWidgets('semantics roles announcements and no errors',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<Map<dynamic, dynamic>> events = <Map<dynamic, dynamic>>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (dynamic message) async {
        if (message is Map) {
          events.add(Map<dynamic, dynamic>.from(message));
        }
        return null;
      },
    );
    try {
      await tester.pumpWidget(wrap(const SizedBox()));
      showKunMessage('boom', KunMessageType.error, duration: _sticky);
      await tester.pump();
      showKunMessage('ok', KunMessageType.success, duration: _sticky);
      await tester.pump();
      // At opacity 0, on the first frame, the toast's children have no
      // semantics at all, so a duplicated label only shows once it appears.
      await tester.pump(KunDurations.slow);

      SemanticsNode? alert;
      SemanticsNode? status;
      void walk(SemanticsNode node) {
        final SemanticsData data = node.getSemanticsData();
        if (data.role == SemanticsRole.alert && data.label == 'boom') {
          alert = node;
        }
        if (data.role == SemanticsRole.status && data.label == 'ok') {
          status = node;
        }
        node.visitChildren((SemanticsNode child) {
          walk(child);
          return true;
        });
      }

      walk(
        tester.binding.renderViews.first.owner!.semanticsOwner!
            .rootSemanticsNode!,
      );
      expect(alert, isNotNull);
      expect(status, isNotNull);
      final List<String> labels = <String>[];
      alert!.visitChildren((SemanticsNode child) {
        labels.add(child.getSemanticsData().label);
        return true;
      });
      expect(labels, isNot(contains('boom')));
      expect(alert!.getSemanticsData().flagsCollection.isLiveRegion, isFalse);
      expect(status!.getSemanticsData().flagsCollection.isLiveRegion, isFalse);

      final List<Map<dynamic, dynamic>> announces = events
          .where((Map<dynamic, dynamic> e) => e['type'] == 'announce')
          .toList();
      expect(
        announces.any(
          (Map<dynamic, dynamic> e) =>
              (e['data'] as Map)['message'] == 'boom' &&
              (e['data'] as Map)['assertiveness'] ==
                  Assertiveness.assertive.index,
        ),
        isTrue,
      );
      expect(
        announces.any(
          (Map<dynamic, dynamic> e) => (e['data'] as Map)['message'] == 'ok',
        ),
        isTrue,
      );

      final int before = announces.length;
      showKunMessage('boom', KunMessageType.error, duration: _sticky);
      await tester.pump();
      final List<Map<dynamic, dynamic>> after = events
          .where((Map<dynamic, dynamic> e) => e['type'] == 'announce')
          .toList();
      expect(after.length, greaterThan(before));
    } finally {
      handle.dispose();
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        null,
      );
    }
  });

  testWidgets('no host prints once then shows when mounted',
      (WidgetTester tester) async {
    final List<String> lines = <String>[];
    final DebugPrintCallback previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      lines.add(message ?? '');
    };
    showKunMessage('queued', KunMessageType.info, duration: _sticky);
    showKunMessage('queued-2', KunMessageType.warn, duration: _sticky);
    debugPrint = previous;
    expect(lines, hasLength(1));
    expect(lines.single, contains('KunMessageProvider'));

    setView(tester, const Size(1280, 800));
    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pump();
    expect(find.text('queued'), findsOneWidget);
  });

  testWidgets('toast renders above a modal and close takes a tap',
      (WidgetTester tester) async {
    setView(tester, const Size(1280, 800));
    final SemanticsHandle handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(wrap(const _ModalHost()));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Title'), findsOneWidget);
      showKunMessage('over-modal', KunMessageType.info, duration: _sticky);
      await pumpToast(tester);
      expect(find.text('over-modal'), findsOneWidget);
      bool found = false;
      void walk(SemanticsNode node) {
        if (node.getSemanticsData().label == 'over-modal') {
          found = true;
        }
        node.visitChildren((SemanticsNode child) {
          walk(child);
          return true;
        });
      }

      walk(
        tester.binding.renderViews.first.owner!.semanticsOwner!
            .rootSemanticsNode!,
      );
      expect(found, isTrue);
      await tester.tap(toastClose('message_1'));
      await pumpToast(tester);
      expect(find.text('over-modal'), findsNothing);
      expect(find.text('Title'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });
}

class _ModalHost extends StatefulWidget {
  const _ModalHost();

  @override
  State<_ModalHost> createState() => _ModalHostState();
}

class _ModalHostState extends State<_ModalHost> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        KunButton(
          onPressed: () => setState(() => _open = true),
          child: const Text('Open'),
        ),
        KunModal(
          value: _open,
          onChanged: (bool value) => setState(() => _open = value),
          title: 'Title',
          child: const SizedBox(width: 80, height: 20),
        ),
      ],
    );
  }
}
