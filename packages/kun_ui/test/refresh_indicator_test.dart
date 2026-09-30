import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/spinner_painter.dart';

Widget wrap(Widget child, {bool reduce = false, KunThemeData? theme}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(800, 600),
      disableAnimations: reduce,
    ),
    child: KunTheme(
      data: theme ?? KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: child,
      ),
    ),
  );
}

Widget refreshList({
  required Future<void> Function() onRefresh,
  ScrollPhysics? physics,
  List<Widget>? children,
  ScrollController? controller,
  KunUIColor color = KunUIColor.primary,
  ScrollNotificationPredicate notificationPredicate =
      defaultScrollNotificationPredicate,
  String? semanticLabel,
}) {
  return KunRefreshIndicator(
    onRefresh: onRefresh,
    color: color,
    notificationPredicate: notificationPredicate,
    semanticLabel: semanticLabel,
    child: ListView(
      controller: controller,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      children: children ??
          <Widget>[
            for (final String label in <String>['A', 'B', 'C', 'D', 'E', 'F'])
              SizedBox(height: 200, child: Text(label)),
          ],
    ),
  );
}

Finder get spinnerPaint => find.byWidgetPredicate(
      (Widget widget) =>
          widget is CustomPaint && widget.painter is KunSpinnerPainter,
    );

KunSpinnerPainter painterOf(WidgetTester tester) {
  return tester.widget<CustomPaint>(spinnerPaint).painter! as KunSpinnerPainter;
}

BoxDecoration discOf(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(KunRefreshIndicator),
      matching: find.byWidgetPredicate((Widget widget) {
        return widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle;
      }),
    ),
  );
  return box.decoration as BoxDecoration;
}

void expectNoForbiddenChrome(WidgetTester tester) {
  final Iterable<Element> elements = collectAllElementsFrom(
    tester.binding.rootElement!,
    skipOffstage: false,
  );
  for (final Element element in elements) {
    final String name = element.widget.runtimeType.toString();
    expect(name.startsWith('Material'), isFalse, reason: name);
    expect(name.startsWith('Cupertino'), isFalse, reason: name);
    expect(name.startsWith('RefreshProgressIndicator'), isFalse, reason: name);
  }
}

Future<void> settleFling(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(KunDurations.fast);
  await tester.pump(KunDurations.fast);
}

void main() {
  testWidgets('a drag past the threshold calls onRefresh once', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final Completer<void> completer = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      wrap(
        refreshList(
          onRefresh: () {
            calls += 1;
            return completer.future;
          },
        ),
      ),
    );

    await tester.fling(find.text('A'), const Offset(0, 300), 1000);
    await settleFling(tester);

    expect(calls, 1);
    expect(spinnerPaint, findsOneWidget);
    expect(
      find.bySemanticsLabel(KunMessages.zhCN.loading.description),
      findsOneWidget,
    );
    expectNoForbiddenChrome(tester);

    completer.complete();
    await tester.pump();
    await tester.pump(KunDurations.exit);
    await tester.pump(KunDurations.exit);
    expect(spinnerPaint, findsNothing);
    expect(
      find.bySemanticsLabel(KunMessages.zhCN.loading.description),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('a short drag never calls onRefresh', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      wrap(
        refreshList(
          onRefresh: () async {
            calls += 1;
          },
        ),
      ),
    );

    await tester.fling(find.text('A'), const Offset(0, 50), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(KunDurations.exit);
    await tester.pump(KunDurations.exit);

    expect(calls, 0);
    expect(spinnerPaint, findsNothing);
  });

  testWidgets('a list scrolled away from the top does not refresh',
      (tester) async {
    var calls = 0;
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrap(
        refreshList(
          controller: controller,
          onRefresh: () async {
            calls += 1;
          },
        ),
      ),
    );

    controller.jumpTo(50);
    await tester.pump();
    await tester.fling(find.text('A'), const Offset(0, 300), 1000);
    await settleFling(tester);
    await tester.pump(KunDurations.exit);

    expect(calls, 0);
    expect(spinnerPaint, findsNothing);
  });

  testWidgets('ClampingScrollPhysics overscroll calls onRefresh',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      wrap(
        refreshList(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          onRefresh: () async {
            calls += 1;
          },
        ),
      ),
    );

    await tester.fling(find.text('A'), const Offset(0, 300), 1000);
    await settleFling(tester);
    await tester.pump(KunDurations.exit);
    await tester.pump(KunDurations.exit);

    expect(calls, 1);
    expect(spinnerPaint, findsNothing);
  });

  testWidgets('BouncingScrollPhysics bounce-back calls onRefresh',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      wrap(
        refreshList(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          onRefresh: () async {
            calls += 1;
          },
        ),
      ),
    );

    await tester.fling(find.text('A'), const Offset(0, 300), 1000);
    await settleFling(tester);
    await tester.pump(KunDurations.exit);
    await tester.pump(KunDurations.exit);

    expect(calls, 1);
    expect(spinnerPaint, findsNothing);
  });

  testWidgets('a nested scrollable at depth 1 is ignored by default',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      wrap(
        KunRefreshIndicator(
          onRefresh: () async {
            calls += 1;
          },
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 600,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: <Widget>[
                  for (final String label in <String>['A', 'B', 'C', 'D'])
                    SizedBox(height: 200, child: Text(label)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.fling(find.text('A'), const Offset(0, 300), 1000);
    await settleFling(tester);
    await tester.pump(KunDurations.exit);

    expect(calls, 0);
    expect(spinnerPaint, findsNothing);
  });

  testWidgets('reduced motion snaps and dismisses at once, spinner still turns',
      (tester) async {
    final Completer<void> completer = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      wrap(
        refreshList(
          onRefresh: () {
            calls += 1;
            return completer.future;
          },
        ),
        reduce: true,
      ),
    );

    await tester.fling(find.text('A'), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(calls, 1);
    expect(spinnerPaint, findsOneWidget);
    final double before = painterOf(tester).turns;
    await tester.pump(const Duration(milliseconds: 375));
    expect(painterOf(tester).turns, isNot(before));

    completer.complete();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(spinnerPaint, findsNothing);
  });

  testWidgets('the disc is content1 plus KunShadows.md, colour follows color',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        refreshList(
          color: KunUIColor.danger,
          onRefresh: () => Completer<void>().future,
        ),
      ),
    );

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text('A')),
    );
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();

    final BoxDecoration disc = discOf(tester);
    expect(disc.color, KunColors.light.content1);
    expect(disc.boxShadow, KunShadows.md);
    expect(
      painterOf(tester).color,
      KunUIColor.danger.scaleOf(KunColors.light).solid,
    );

    await gesture.up();
    await tester.pump();
  });

  testWidgets('a tap on a slotted KunButton still fires before and after',
      (tester) async {
    var presses = 0;
    var refreshes = 0;
    await tester.pumpWidget(
      wrap(
        refreshList(
          onRefresh: () async {
            refreshes += 1;
          },
          children: <Widget>[
            KunButton(
              onPressed: () => presses += 1,
              child: const Text('Go'),
            ),
            for (final String label in <String>['A', 'B', 'C', 'D', 'E'])
              SizedBox(height: 200, child: Text(label)),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    expect(presses, 1);

    await tester.fling(find.text('A'), const Offset(0, 300), 1000);
    await settleFling(tester);
    await tester.pump(KunDurations.exit);
    await tester.pump(KunDurations.exit);
    expect(refreshes, 1);

    await tester.tap(find.text('Go'));
    expect(presses, 2);
  });

  testWidgets('the overscroll glow stays hidden once the pull is armed',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final List<bool> escaped = <bool>[];
    await tester.pumpWidget(
      wrap(
        NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (OverscrollIndicatorNotification notification) {
            escaped.add(notification.accepted);
            return false;
          },
          child: refreshList(onRefresh: () async {}),
        ),
      ),
    );
    final TestGesture gesture = await tester.startGesture(
      const Offset(400, 100),
    );
    for (int i = 0; i < 60; i++) {
      await gesture.moveBy(const Offset(0, 6));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(escaped, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the tree has no Material or Cupertino chrome', (tester) async {
    await tester.pumpWidget(
      wrap(
        refreshList(onRefresh: () async {}),
      ),
    );
    expectNoForbiddenChrome(tester);

    await tester.fling(find.text('A'), const Offset(0, 300), 1000);
    await settleFling(tester);
    expectNoForbiddenChrome(tester);
    await tester.pump(KunDurations.exit);
    await tester.pump(KunDurations.exit);
    expectNoForbiddenChrome(tester);
  });

  testWidgets('F5 and Mod+R refresh on a desktop, as a browser reloads',
      (tester) async {
    int calls = 0;
    Completer<void> pending = Completer<void>();
    Future<void> press(LogicalKeyboardKey key,
        {LogicalKeyboardKey? mod}) async {
      if (mod != null) {
        await tester.sendKeyDownEvent(mod);
      }
      await tester.sendKeyEvent(key);
      if (mod != null) {
        await tester.sendKeyUpEvent(mod);
      }
      await tester.pump();
      await tester.pump(KunDurations.fast);
      await tester.pump(const Duration(milliseconds: 16));
    }

    Future<void> finish() async {
      pending.complete();
      await tester.pumpAndSettle();
      pending = Completer<void>();
    }

    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await tester.pumpWidget(
        wrap(
          refreshList(
            onRefresh: () {
              calls++;
              return pending.future;
            },
          ),
        ),
      );

      await press(LogicalKeyboardKey.f5);
      expect(calls, 1);
      expect(spinnerPaint, findsOneWidget);
      await finish();
      expect(spinnerPaint, findsNothing);

      await press(LogicalKeyboardKey.keyR, mod: LogicalKeyboardKey.controlLeft);
      expect(calls, 2);
      await finish();
      await press(LogicalKeyboardKey.keyR, mod: LogicalKeyboardKey.metaLeft);
      expect(calls, 2);
      await press(LogicalKeyboardKey.keyR);
      expect(calls, 2);

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await press(LogicalKeyboardKey.keyR, mod: LogicalKeyboardKey.metaLeft);
      expect(calls, 3);
      await finish();
      await press(LogicalKeyboardKey.keyR, mod: LogicalKeyboardKey.controlLeft);
      expect(calls, 3);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a covered route or a disabled TickerMode keeps the keys',
      (tester) async {
    int calls = 0;
    await tester.pumpWidget(
      wrap(
        TickerMode(
          enabled: false,
          child: refreshList(onRefresh: () async => calls++),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(calls, 0);

    final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      wrap(
        WidgetsApp(
          navigatorKey: navigator,
          color: KunColors.black,
          home: refreshList(onRefresh: () async => calls++),
          pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder b) =>
              PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (BuildContext context, _, __) => b(context),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(calls, 1);

    unawaited(
      navigator.currentState!.push(
        PageRouteBuilder<void>(
          pageBuilder: (BuildContext context, _, __) => const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('show() refreshes from code and completes with the refresh',
      (tester) async {
    final GlobalKey<KunRefreshIndicatorState> key =
        GlobalKey<KunRefreshIndicatorState>();
    final Completer<void> pending = Completer<void>();
    int calls = 0;
    await tester.pumpWidget(
      wrap(
        KunRefreshIndicator(
          key: key,
          onRefresh: () {
            calls++;
            return pending.future;
          },
          child: ListView(
            children: const <Widget>[SizedBox(height: 200, child: Text('A'))],
          ),
        ),
      ),
    );

    bool finished = false;
    final Future<void> done = key.currentState!.show();
    unawaited(done.then((_) => finished = true));
    await tester.pump();
    expect(spinnerPaint, findsOneWidget);
    await tester.pump(KunDurations.fast);
    await tester.pump(const Duration(milliseconds: 16));
    expect(calls, 1);
    expect(identical(key.currentState!.show(), done), isTrue);
    expect(calls, 1);

    pending.complete();
    await tester.pumpAndSettle();
    expect(finished, isTrue);
    expect(spinnerPaint, findsNothing);
  });
}
