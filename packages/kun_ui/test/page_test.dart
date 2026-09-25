import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrapNav({
  required GlobalKey<NavigatorState> navKey,
  Widget home = const Text('home'),
  KunPageTransition homeTransition = KunPageTransition.none,
  bool reduce = false,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(800, 600),
      disableAnimations: reduce,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: KunTheme(
        data: KunThemeData.light(),
        child: Navigator(
          key: navKey,
          onGenerateRoute: (RouteSettings settings) {
            return KunPageRoute<void>(
              settings: settings,
              transition: homeTransition,
              builder: (BuildContext context) => home,
            );
          },
        ),
      ),
    ),
  );
}

Future<void> sendBackGesture(
  WidgetTester tester,
  String method, [
  Map<String, dynamic>? arguments,
]) async {
  final ByteData message = const StandardMethodCodec().encodeMethodCall(
    MethodCall(method, arguments),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (ByteData? _) {},
  );
}

void main() {
  testWidgets(
    'platform resolves to slide on iOS and macOS and fade elsewhere',
    (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(wrapNav(navKey: navKey));
      navKey.currentState!.push(
        KunPageRoute<void>(
          transition: KunPageTransition.platform,
          builder: (BuildContext context) => const Text('next'),
        ),
      );
      await tester.pump();
      final KunPageRoute<void> route = ModalRoute.of(
        tester.element(find.text('next')),
      )! as KunPageRoute<void>;
      final bool apple = <TargetPlatform>{
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform);
      if (apple) {
        expect(route.transitionDuration, KunDurations.slow);
        expect(route.reverseTransitionDuration, KunDurations.slow);
        expect(find.byType(SlideTransition), findsWidgets);
      } else {
        expect(route.transitionDuration, KunDurations.base);
        expect(route.reverseTransitionDuration, KunDurations.exit);
        expect(find.byType(FadeTransition), findsWidgets);
        expect(find.byType(ScaleTransition), findsWidgets);
      }
    },
    variant: TargetPlatformVariant.all(),
  );

  testWidgets('fade durations and mid-push opacity and scale',
      (WidgetTester tester) async {
    final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(wrapNav(navKey: navKey));
    navKey.currentState!.push(
      KunPageRoute<void>(
        transition: KunPageTransition.fade,
        builder: (BuildContext context) => const Text('next'),
      ),
    );
    await tester.pump();
    final KunPageRoute<void> route = ModalRoute.of(
      tester.element(find.text('next', skipOffstage: false)),
    )! as KunPageRoute<void>;
    expect(route.transitionDuration, KunDurations.base);
    expect(route.reverseTransitionDuration, KunDurations.exit);

    await tester.pump(KunDurations.base ~/ 2);
    final FadeTransition fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('next'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(1));
    final ScaleTransition scale = tester.widget<ScaleTransition>(
      find
          .ancestor(
            of: find.text('next'),
            matching: find.byType(ScaleTransition),
          )
          .first,
    );
    expect(scale.scale.value, greaterThan(0.95));
    expect(scale.scale.value, lessThan(1));
  });

  testWidgets('slide durations and mid-push offsets',
      (WidgetTester tester) async {
    final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(wrapNav(navKey: navKey));
    navKey.currentState!.push(
      KunPageRoute<void>(
        transition: KunPageTransition.slide,
        builder: (BuildContext context) => const Text('next'),
      ),
    );
    await tester.pump();
    final KunPageRoute<void> route = ModalRoute.of(
      tester.element(find.text('next', skipOffstage: false)),
    )! as KunPageRoute<void>;
    expect(route.transitionDuration, KunDurations.slow);
    expect(route.reverseTransitionDuration, KunDurations.slow);

    await tester.pump(KunDurations.slow ~/ 2);
    final SlideTransition incoming = tester.widget<SlideTransition>(
      find
          .ancestor(
            of: find.text('next'),
            matching: find.byType(SlideTransition),
          )
          .first,
    );
    expect(incoming.position.value.dx, greaterThan(0));
    expect(incoming.position.value.dx, lessThan(1));

    final SlideTransition covered = tester.widget<SlideTransition>(
      find
          .ancestor(
            of: find.text('home'),
            matching: find.byType(SlideTransition),
          )
          .first,
    );
    expect(covered.position.value.dx, lessThan(0));
    expect(covered.position.value.dx, greaterThanOrEqualTo(-1 / 3));
  });

  testWidgets('none completes in one frame', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(wrapNav(navKey: navKey));
    navKey.currentState!.push(
      KunPageRoute<void>(
        transition: KunPageTransition.none,
        builder: (BuildContext context) => const Text('next'),
      ),
    );
    await tester.pump();
    expect(find.text('next'), findsOneWidget);
    final ModalRoute<void> route =
        ModalRoute.of(tester.element(find.text('next')))!;
    expect(route.animation!.isCompleted, isTrue);
  });

  testWidgets('reduced motion completes in one frame',
      (WidgetTester tester) async {
    final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(wrapNav(navKey: navKey, reduce: true));
    navKey.currentState!.push(
      KunPageRoute<void>(
        transition: KunPageTransition.fade,
        builder: (BuildContext context) => const Text('next'),
      ),
    );
    await tester.pump();
    expect(find.text('next'), findsOneWidget);
    final ModalRoute<void> route =
        ModalRoute.of(tester.element(find.text('next')))!;
    expect(route.transitionDuration, Duration.zero);
    expect(route.animation!.isCompleted, isTrue);
  });

  testWidgets('KunPage with a new child on rebuild shows the new child',
      (WidgetTester tester) async {
    Widget app(Widget child) {
      return MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: KunTheme(
            data: KunThemeData.light(),
            child: Navigator(
              pages: <Page<void>>[
                KunPage<void>(
                  key: const ValueKey<String>('p'),
                  child: child,
                ),
              ],
              onDidRemovePage: (Page<Object?> page) {},
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(app(const Text('first')));
    expect(find.text('first'), findsOneWidget);
    await tester.pumpWidget(app(const Text('second')));
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
  });

  testWidgets('KunPage works as Navigator.pages with onDidRemovePage',
      (WidgetTester tester) async {
    final List<Page<void>> pages = <Page<void>>[
      const KunPage<void>(
        key: ValueKey<String>('a'),
        child: Text('one'),
      ),
      const KunPage<void>(
        key: ValueKey<String>('b'),
        child: Text('two'),
      ),
    ];
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: KunTheme(
            data: KunThemeData.light(),
            child: Navigator(
              pages: pages,
              onDidRemovePage: (Page<Object?> page) {
                pages.remove(page);
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('two'), findsOneWidget);
    expect(find.text('one'), findsNothing);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('one'), findsOneWidget);
    expect(pages, hasLength(1));
  });

  testWidgets(
    'iOS edge drag from x=5 past half the width pops',
    (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(wrapNav(navKey: navKey));
      navKey.currentState!.push(
        KunPageRoute<void>(
          transition: KunPageTransition.slide,
          builder: (BuildContext context) => const Text('next'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('next'), findsOneWidget);

      final TestGesture gesture =
          await tester.startGesture(const Offset(5, 300));
      await gesture.moveBy(const Offset(401, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('next'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'iOS a short slow drag restores',
    (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(wrapNav(navKey: navKey));
      navKey.currentState!.push(
        KunPageRoute<void>(
          transition: KunPageTransition.slide,
          builder: (BuildContext context) => const Text('next'),
        ),
      );
      await tester.pumpAndSettle();

      final TestGesture gesture =
          await tester.startGesture(const Offset(5, 300));
      await gesture.moveBy(const Offset(80, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('next'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'iOS a drag starting at x=100 does nothing',
    (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(wrapNav(navKey: navKey));
      navKey.currentState!.push(
        KunPageRoute<void>(
          transition: KunPageTransition.slide,
          builder: (BuildContext context) => const Text('next'),
        ),
      );
      await tester.pumpAndSettle();

      final TestGesture gesture =
          await tester.startGesture(const Offset(100, 300));
      await gesture.moveBy(const Offset(400, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('next'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('next')).dx,
        greaterThanOrEqualTo(0),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'iOS edge drag does nothing with transition none',
    (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(wrapNav(navKey: navKey));
      navKey.currentState!.push(
        KunPageRoute<void>(
          transition: KunPageTransition.none,
          builder: (BuildContext context) => const Text('next'),
        ),
      );
      await tester.pumpAndSettle();

      final TestGesture gesture =
          await tester.startGesture(const Offset(5, 300));
      await gesture.moveBy(const Offset(401, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('next'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Android predictive back scrubs, commits and cancels',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        KunApp(
          home: Builder(
            builder: (BuildContext context) {
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    KunPageRoute<void>(
                      transition: KunPageTransition.fade,
                      builder: (BuildContext context) => const Text('page b'),
                    ),
                  );
                },
                child: const Text('push'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();
      expect(find.text('page b'), findsOneWidget);

      await sendBackGesture(tester, 'startBackGesture', <String, dynamic>{
        'touchOffset': <double>[5.0, 300.0],
        'progress': 0.0,
        'swipeEdge': 0,
      });
      await tester.pump();

      await sendBackGesture(
        tester,
        'updateBackGestureProgress',
        <String, dynamic>{
          'touchOffset': <double>[100.0, 300.0],
          'progress': 0.35,
          'swipeEdge': 0,
        },
      );
      await tester.pump();
      final ModalRoute<void> route =
          ModalRoute.of(tester.element(find.text('page b')))!;
      expect(route.animation!.value, closeTo(1 - 0.35, 0.001));

      await sendBackGesture(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('page b'), findsOneWidget);
      expect(route.animation!.value, 1);

      await sendBackGesture(tester, 'startBackGesture', <String, dynamic>{
        'touchOffset': <double>[5.0, 300.0],
        'progress': 0.0,
        'swipeEdge': 0,
      });
      await tester.pump();
      await sendBackGesture(
        tester,
        'updateBackGestureProgress',
        <String, dynamic>{
          'touchOffset': <double>[200.0, 300.0],
          'progress': 0.6,
          'swipeEdge': 0,
        },
      );
      await tester.pump();
      await sendBackGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('page b'), findsNothing);
      expect(find.text('push'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Android none does not claim the gesture and commit still pops',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        KunApp(
          home: Builder(
            builder: (BuildContext context) {
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    KunPageRoute<void>(
                      transition: KunPageTransition.none,
                      builder: (BuildContext context) => const Text('page b'),
                    ),
                  );
                },
                child: const Text('push'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();

      final ModalRoute<void> route =
          ModalRoute.of(tester.element(find.text('page b')))!;
      expect(route.animation!.value, 1);

      await sendBackGesture(tester, 'startBackGesture', <String, dynamic>{
        'touchOffset': <double>[5.0, 300.0],
        'progress': 0.0,
        'swipeEdge': 0,
      });
      await tester.pump();
      await sendBackGesture(
        tester,
        'updateBackGestureProgress',
        <String, dynamic>{
          'touchOffset': <double>[100.0, 300.0],
          'progress': 0.35,
          'swipeEdge': 0,
        },
      );
      await tester.pump();
      expect(route.animation!.value, 1);

      await sendBackGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('page b'), findsNothing);
      expect(find.text('push'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
