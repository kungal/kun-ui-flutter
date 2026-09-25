import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(
  Widget child, {
  TargetPlatform? platform,
}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(800, 600)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: KunTheme(
        data: KunThemeData.light(),
        child: ScrollConfiguration(
          behavior: const KunScrollBehavior(),
          child: child,
        ),
      ),
    ),
  );
}

Widget overflowingList({ScrollController? controller}) {
  return SizedBox(
    width: 400,
    height: 400,
    child: ListView(
      controller: controller,
      children: <Widget>[
        for (int i = 0; i < 20; i++)
          SizedBox(height: 80, child: Text('item $i')),
      ],
    ),
  );
}

bool hasPhysics<T extends ScrollPhysics>(ScrollPhysics? physics) {
  ScrollPhysics? current = physics;
  while (current != null) {
    if (current is T) {
      return true;
    }
    current = current.parent;
  }
  return false;
}

void main() {
  testWidgets(
    'Android and Fuchsia build a StretchingOverscrollIndicator',
    (WidgetTester tester) async {
      await tester.pumpWidget(wrap(overflowingList()));
      expect(find.byType(StretchingOverscrollIndicator), findsOneWidget);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
      TargetPlatform.fuchsia,
    }),
  );

  testWidgets(
    'iOS builds no stretch indicator and uses bouncing physics',
    (WidgetTester tester) async {
      await tester.pumpWidget(wrap(overflowingList()));
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      final ScrollableState state =
          tester.state<ScrollableState>(find.byType(Scrollable));
      expect(hasPhysics<BouncingScrollPhysics>(state.position.physics), isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'linux, windows and macOS build a KunScrollbar',
    (WidgetTester tester) async {
      await tester.pumpWidget(wrap(overflowingList()));
      expect(find.byType(KunScrollbar), findsOneWidget);
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets(
    'Android builds no KunScrollbar',
    (WidgetTester tester) async {
      await tester.pumpWidget(wrap(overflowingList()));
      expect(find.byType(KunScrollbar), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('a mouse drag does not scroll a ListView',
      (WidgetTester tester) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(wrap(overflowingList(controller: controller)));
    expect(controller.offset, 0);
    await tester.drag(
      find.byType(ListView),
      const Offset(0, -200),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
  });

  testWidgets(
    'KunRefreshIndicator under KunScrollBehavior on Android shows no stretch',
    (WidgetTester tester) async {
      final List<bool> escaped = <bool>[];
      await tester.pumpWidget(
        wrap(
          NotificationListener<OverscrollIndicatorNotification>(
            onNotification: (OverscrollIndicatorNotification notification) {
              escaped.add(notification.accepted);
              return false;
            },
            child: KunRefreshIndicator(
              onRefresh: () async {},
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
      );
      expect(find.byType(StretchingOverscrollIndicator), findsOneWidget);
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
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
