import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(
  Widget child, {
  bool disableAnimations = false,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: KunTheme(
      data: KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
}

List<KunChip> chips(int count) {
  return <KunChip>[
    for (int i = 1; i <= count; i++)
      KunChip(
        color: KunUIColor.primary,
        child: Text('标签 $i'),
      ),
  ];
}

Finder get startFade =>
    find.byKey(const ValueKey<String>('KunScrollShadow.startFade'));
Finder get endFade =>
    find.byKey(const ValueKey<String>('KunScrollShadow.endFade'));

double fadeOpacity(WidgetTester tester, Finder fade) {
  return tester
      .renderObject<RenderAnimatedOpacity>(
        find.descendant(of: fade, matching: find.byType(AnimatedOpacity)),
      )
      .opacity
      .value;
}

LinearGradient fadeGradient(WidgetTester tester, Finder fade) {
  final BoxDecoration decoration = tester
      .widget<DecoratedBox>(
        find.descendant(of: fade, matching: find.byType(DecoratedBox)),
      )
      .decoration as BoxDecoration;
  return decoration.gradient! as LinearGradient;
}

Widget overflowingStrip({
  required List<Widget> children,
  ScrollController? controller,
  Axis axis = Axis.horizontal,
  Color? shadowColor,
  double shadowSize = 32,
  String? semanticLabel,
  KunScrollShadowWheel wheel = KunScrollShadowWheel.off,
  bool draggable = false,
  KunScrollShadowScrollbar scrollbar = KunScrollShadowScrollbar.hide,
}) {
  return SizedBox(
    width: 200,
    height: axis == Axis.vertical ? 160 : null,
    child: KunScrollShadow(
      controller: controller,
      axis: axis,
      shadowColor: shadowColor,
      shadowSize: shadowSize,
      semanticLabel: semanticLabel,
      wheel: wheel,
      draggable: draggable,
      scrollbar: scrollbar,
      children: children,
    ),
  );
}

Future<void> wheelAt(
  WidgetTester tester,
  Offset position, {
  Offset scrollDelta = const Offset(0, 120),
}) async {
  final TestPointer pointer = TestPointer(7, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(pointer.hover(position));
  await tester.sendEventToBinding(pointer.scroll(scrollDelta));
  await tester.pump();
}

void main() {
  testWidgets('no fades when the content fits', (tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 800,
          child: KunScrollShadow(children: chips(2)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fadeOpacity(tester, startFade), 0);
    expect(fadeOpacity(tester, endFade), 0);
  });

  testWidgets('end fade at the start, both mid-way, start fade at the end',
      (tester) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrap(
        overflowingStrip(
          controller: controller,
          children: chips(12),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.position.maxScrollExtent, greaterThan(1));
    expect(fadeOpacity(tester, startFade), 0);
    expect(fadeOpacity(tester, endFade), 1);

    controller.jumpTo(controller.position.maxScrollExtent / 2);
    await tester.pumpAndSettle();
    expect(fadeOpacity(tester, startFade), 1);
    expect(fadeOpacity(tester, endFade), 1);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(fadeOpacity(tester, startFade), 1);
    expect(fadeOpacity(tester, endFade), 0);
  });

  testWidgets('adding children re-evaluates the end fade', (tester) async {
    final ValueNotifier<int> count = ValueNotifier<int>(1);
    addTearDown(count.dispose);
    await tester.pumpWidget(
      wrap(
        ValueListenableBuilder<int>(
          valueListenable: count,
          builder: (BuildContext context, int n, Widget? _) {
            return overflowingStrip(children: chips(n));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fadeOpacity(tester, endFade), 0);

    count.value = 12;
    await tester.pumpAndSettle();
    expect(fadeOpacity(tester, endFade), 1);
  });

  testWidgets('fade gradient is shadowColor to the same colour at alpha 0',
      (tester) async {
    final Color color = KunColors.light.primary.solid;
    await tester.pumpWidget(
      wrap(
        overflowingStrip(
          shadowColor: color,
          shadowSize: KunSpacing.unit * 10,
          children: chips(12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final LinearGradient start = fadeGradient(tester, startFade);
    expect(start.colors.first, color);
    expect(start.colors.last, color.withValues(alpha: 0));
    expect(tester.getSize(startFade).width, KunSpacing.unit * 10);

    final LinearGradient end = fadeGradient(tester, endFade);
    expect(end.colors.first, color);
    expect(end.colors.last, color.withValues(alpha: 0));
    expect(tester.getSize(endFade).width, KunSpacing.unit * 10);
  });

  testWidgets('default fade colour is the theme background', (tester) async {
    await tester.pumpWidget(
      wrap(overflowingStrip(children: chips(12))),
    );
    await tester.pumpAndSettle();
    final Color background = KunThemeData.light().colors.background;
    expect(fadeGradient(tester, endFade).colors.first, background);
    expect(
      fadeGradient(tester, endFade).colors.last,
      background.withValues(alpha: 0),
    );
    expect(tester.getSize(endFade).width, 32);
  });

  testWidgets('vertical axis fades top and bottom and stretches items',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        overflowingStrip(
          axis: Axis.vertical,
          children: <Widget>[
            const KunCard(
              key: ValueKey<String>('card-a'),
              child: Text('第 1 行内容'),
            ),
            const KunCard(
              key: ValueKey<String>('card-b'),
              child: Text('第 2 行内容'),
            ),
            const KunCard(child: Text('第 3 行内容')),
            const KunCard(child: Text('第 4 行内容')),
            const KunCard(child: Text('第 5 行内容')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(startFade).height, 32);
    expect(tester.getSize(endFade).height, 32);
    expect(tester.getSize(startFade).width, 200);
    expect(fadeOpacity(tester, startFade), 0);
    expect(fadeOpacity(tester, endFade), 1);
    expect(tester.getSize(find.byKey(const ValueKey<String>('card-a'))).width,
        200);
    expect(tester.getSize(find.byKey(const ValueKey<String>('card-b'))).width,
        200);

    final LinearGradient start = fadeGradient(tester, startFade);
    expect(start.begin, Alignment.topCenter);
    expect(start.end, Alignment.bottomCenter);
    final LinearGradient end = fadeGradient(tester, endFade);
    expect(end.begin, Alignment.bottomCenter);
    expect(end.end, Alignment.topCenter);
  });

  testWidgets('horizontal items stretch to the tallest child', (tester) async {
    await tester.pumpWidget(
      wrap(
        KunScrollShadow(
          children: <Widget>[
            const KunChip(
              key: ValueKey<String>('short'),
              child: Text('短'),
            ),
            const SizedBox(
              key: ValueKey<String>('tall'),
              width: 80,
              height: 80,
              child: KunButton(child: Text('高')),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('short'))).height,
      tester.getSize(find.byKey(const ValueKey<String>('tall'))).height,
    );
  });

  testWidgets('wheel on moves the strip and not the outer list',
      (tester) async {
    final ScrollController strip = ScrollController();
    final ScrollController outer = ScrollController();
    addTearDown(strip.dispose);
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 240,
          height: 400,
          child: ListView(
            controller: outer,
            children: <Widget>[
              SizedBox(
                height: 60,
                child: KunScrollShadow(
                  controller: strip,
                  wheel: KunScrollShadowWheel.on,
                  children: chips(16),
                ),
              ),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(strip.offset, 0);
    expect(outer.offset, 0);

    await wheelAt(tester, tester.getCenter(find.byType(KunScrollShadow)));
    expect(strip.offset, 120);
    expect(outer.offset, 0);

    strip.jumpTo(strip.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final double max = strip.offset;
    await wheelAt(tester, tester.getCenter(find.byType(KunScrollShadow)));
    expect(strip.offset, max);
    expect(outer.offset, 120);
  });

  testWidgets('wheel contain at the wall moves neither', (tester) async {
    final ScrollController strip = ScrollController();
    final ScrollController outer = ScrollController();
    addTearDown(strip.dispose);
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 240,
          height: 400,
          child: ListView(
            controller: outer,
            children: <Widget>[
              SizedBox(
                height: 60,
                child: KunScrollShadow(
                  controller: strip,
                  wheel: KunScrollShadowWheel.contain,
                  children: chips(16),
                ),
              ),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    strip.jumpTo(strip.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final double max = strip.offset;
    await wheelAt(tester, tester.getCenter(find.byType(KunScrollShadow)));
    expect(strip.offset, max);
    expect(outer.offset, 0);
  });

  testWidgets('wheel off does not move the strip', (tester) async {
    final ScrollController strip = ScrollController();
    final ScrollController outer = ScrollController();
    addTearDown(strip.dispose);
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 240,
          height: 400,
          child: ListView(
            controller: outer,
            children: <Widget>[
              SizedBox(
                height: 60,
                child: KunScrollShadow(
                  controller: strip,
                  children: chips(16),
                ),
              ),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await wheelAt(tester, tester.getCenter(find.byType(KunScrollShadow)));
    expect(strip.offset, 0);
    expect(outer.offset, 120);
  });

  testWidgets('draggable mouse drag moves the strip and eats the click',
      (tester) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    var presses = 0;
    await tester.pumpWidget(
      wrap(
        overflowingStrip(
          controller: controller,
          draggable: true,
          children: <Widget>[
            KunButton(
              onPressed: () => presses++,
              child: const Text('Go'),
            ),
            ...chips(12),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.position.maxScrollExtent, greaterThan(1));

    await tester.drag(
      find.text('Go'),
      const Offset(-80, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(presses, 0);

    controller.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go'), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(presses, 1);
  });

  testWidgets('without draggable a mouse drag does not move the strip',
      (tester) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrap(
        overflowingStrip(
          controller: controller,
          children: chips(12),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(KunScrollShadow),
      const Offset(-80, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(controller.offset, 0);
  });

  testWidgets(
    'scrollbar thin shows KunScrollbar; hide shows none',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          overflowingStrip(
            scrollbar: KunScrollShadowScrollbar.thin,
            children: chips(12),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(KunScrollbar), findsOneWidget);

      await tester.pumpWidget(
        wrap(overflowingStrip(children: chips(12))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(KunScrollbar), findsNothing);
      expect(
        find.descendant(
          of: find.byType(KunScrollShadow),
          matching: find.byType(RawScrollbar),
        ),
        findsNothing,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('semanticLabel is a labelled container; none without it',
      (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        overflowingStrip(
          semanticLabel: '标签列表',
          children: chips(4),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('标签列表')),
      isSemantics(label: '标签列表'),
    );

    await tester.pumpWidget(
      wrap(overflowingStrip(children: chips(4))),
    );
    expect(find.bySemanticsLabel('标签列表'), findsNothing);
    expect(find.bySemanticsLabel('scrollable content'), findsNothing);
    handle.dispose();
  });

  testWidgets('reduced motion flips a fade in one frame', (tester) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrap(
        overflowingStrip(
          controller: controller,
          children: chips(12),
        ),
        disableAnimations: true,
      ),
    );
    await tester.pump();
    expect(fadeOpacity(tester, endFade), 1);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(fadeOpacity(tester, startFade), 1);
    expect(fadeOpacity(tester, endFade), 0);
  });

  testWidgets('right to left, the start fade is on the right',
      (WidgetTester tester) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      KunTheme(
        data: KunThemeData.light(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 60,
              child: KunScrollShadow(
                controller: controller,
                children: <Widget>[
                  for (int i = 0; i < 12; i++)
                    const SizedBox(width: 80, height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    controller.jumpTo(100);
    await tester.pumpAndSettle();
    final Rect strip = tester.getRect(find.byType(KunScrollShadow));
    final Rect startFade = tester.getRect(
      find.byKey(const ValueKey<String>('KunScrollShadow.startFade')),
    );
    expect(startFade.right, strip.right);
  });

  group('builder', () {
    Widget lazyStrip({
      required int itemCount,
      required Set<int> built,
      ScrollController? controller,
      KunScrollShadowWheel wheel = KunScrollShadowWheel.off,
    }) {
      return wrap(
        SizedBox(
          width: 300,
          height: 96,
          child: KunScrollShadow.builder(
            controller: controller,
            wheel: wheel,
            itemCount: itemCount,
            itemBuilder: (BuildContext context, int index) {
              built.add(index);
              return SizedBox(
                key: ValueKey<int>(index),
                width: 100,
                child: KunCard(child: Text('$index')),
              );
            },
          ),
        ),
      );
    }

    testWidgets('builds only the items near the viewport', (tester) async {
      final Set<int> built = <int>{};
      await tester.pumpWidget(lazyStrip(itemCount: 200, built: built));
      await tester.pumpAndSettle();
      expect(built, contains(0));
      expect(built.length, lessThan(20));
      expect(built, isNot(contains(199)));
    });

    testWidgets('fades, spacing and the stretched height', (tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        lazyStrip(itemCount: 50, built: <int>{}, controller: controller),
      );
      await tester.pumpAndSettle();
      expect(fadeOpacity(tester, startFade), 0);
      expect(fadeOpacity(tester, endFade), 1);

      final Rect first = tester.getRect(find.byKey(const ValueKey<int>(0)));
      final Rect second = tester.getRect(find.byKey(const ValueKey<int>(1)));
      expect(second.left - first.right, KunSpacing.unit * 3);
      expect(first.height, 96);

      // A lazy list's maxScrollExtent is an estimate until the far items are
      // built, so the first jump lands short of the real end.
      while (controller.offset < controller.position.maxScrollExtent) {
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      expect(fadeOpacity(tester, startFade), 1);
      expect(fadeOpacity(tester, endFade), 0);
    });

    testWidgets('a vertical wheel scrolls a lazy horizontal strip',
        (tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        lazyStrip(
          itemCount: 50,
          built: <int>{},
          controller: controller,
          wheel: KunScrollShadowWheel.on,
        ),
      );
      await tester.pumpAndSettle();
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(150, 48)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
      await tester.pumpAndSettle();
      expect(controller.offset, 120);
    });
  });
}
