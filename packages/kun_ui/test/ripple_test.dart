import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/ripple.dart';

Widget wrap(Widget child, {bool disableAnimations = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: KunTheme(
        data: KunThemeData.light(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: child),
        ),
      ),
    );

Finder rippleLayer([Finder? host]) => find.descendant(
      of: host ?? find.byType(KunButton),
      matching: find.byType(KunRippleLayer),
    );

// The overlay's painter, not any CustomPaint in the content: a loading
// button's spinner is one too.
Finder ripplePaint([Finder? host]) => find.descendant(
      of: rippleLayer(host),
      matching: find.byWidgetPredicate(
        (Widget widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString() == '_RipplePainter',
      ),
    );

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  Widget build(BuildContext context) => const Text('Back');
}

void main() {
  testWidgets('a tap on a light button grows foreground at 30% from the finger',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        KunButton(
          variant: KunUIVariant.light,
          onPressed: () {},
          child: const Text('Share'),
        ),
      ),
    );
    expect(ripplePaint(), findsNothing);

    final Rect drawn = tester.getRect(rippleLayer());
    final Offset at = drawn.topLeft + const Offset(20, 10);
    await tester.tapAt(at);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final double diameter = drawn.longestSide - 2;
    final double progress = KunEasing.enter.transform(0.5);
    final Color foreground = KunThemeData.light().colors.foreground;
    expect(
      tester.renderObject(ripplePaint()),
      paints
        ..circle(
          x: 19,
          y: 9,
          radius: diameter * progress,
          color: foreground.withValues(alpha: 0.3 * (1 - progress)),
        ),
    );

    await tester.pump(const Duration(milliseconds: 301));
    expect(ripplePaint(), findsNothing);
  });

  testWidgets('each tap adds a ripple and each leaves after 600ms',
      (tester) async {
    await tester.pumpWidget(
      wrap(KunButton(onPressed: () {}, child: const Text('Share'))),
    );
    await tester.tap(find.text('Share'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Share'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.renderObject(ripplePaint()),
      paints
        ..circle()
        ..circle(),
    );

    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.renderObject(ripplePaint()), paints..circle());
    await tester.pump(const Duration(milliseconds: 200));
    expect(ripplePaint(), findsNothing);
  });

  testWidgets('the ripple is clipped inside the border', (tester) async {
    await tester.pumpWidget(
      wrap(
        KunButton(
          variant: KunUIVariant.bordered,
          rounded: KunUIRounded.lg,
          onPressed: () {},
          child: const Text('Share'),
        ),
      ),
    );
    await tester.tap(find.text('Share'));
    await tester.pump();

    final RenderClipRRect clip = tester.renderObject<RenderClipRRect>(
      find.descendant(of: rippleLayer(), matching: find.byType(ClipRRect)),
    );
    expect(
      clip.borderRadius,
      BorderRadius.circular(KunUIRounded.lg.radius - 1),
    );
    expect(
      tester.getSize(find.byType(ClipRRect)),
      tester.getSize(rippleLayer()) - const Offset(2, 2) as Size,
    );
  });

  testWidgets('the button content keeps its state when a ripple starts',
      (tester) async {
    await tester.pumpWidget(
      wrap(KunButton(onPressed: () {}, child: const _Counter())),
    );
    final State before = tester.state(find.byType(_Counter));
    await tester.tap(find.text('Back'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(ripplePaint(), findsOneWidget);
    expect(tester.state(find.byType(_Counter)), same(before));
  });

  testWidgets('no ripple under reduced motion', (tester) async {
    await tester.pumpWidget(
      wrap(
        KunButton(onPressed: () {}, child: const Text('Share')),
        disableAnimations: true,
      ),
    );
    await tester.tap(find.text('Share'));
    await tester.pump();
    expect(ripplePaint(), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('no ripple for a key press, as the browser clicks at (0, 0)',
      (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      wrap(
        Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
          },
          child: KunButton(
            onPressed: () => presses++,
            child: const Text('Share'),
          ),
        ),
      ),
    );
    Focus.of(tester.element(find.text('Share'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(presses, 2);
    expect(ripplePaint(), findsNothing);
  });

  testWidgets('no ripple while disabled, loading or without onPressed',
      (tester) async {
    for (final KunButton button in <KunButton>[
      KunButton(disabled: true, onPressed: () {}, child: const Text('Share')),
      KunButton(loading: true, onPressed: () {}, child: const Text('Share')),
      const KunButton(child: Text('Share')),
    ]) {
      await tester.pumpWidget(wrap(button));
      await tester.tap(find.text('Share'), warnIfMissed: false);
      await tester.pump();
      expect(ripplePaint(), findsNothing);
    }
  });

  testWidgets('a clickable card ripples inside its border; a static one never',
      (tester) async {
    const Widget body = SizedBox(width: 200, height: 80);
    await tester.pumpWidget(
      wrap(const KunCard(bordered: true, clickable: true, child: body)),
    );
    final Finder card = find.byType(KunCard);
    final Rect drawn = tester.getRect(rippleLayer(card));
    await tester.tapAt(drawn.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final double diameter = drawn.longestSide - 2;
    expect(
      tester.renderObject(ripplePaint(card)),
      paints
        ..circle(
          x: drawn.width / 2 - 1,
          y: drawn.height / 2 - 1,
          radius: diameter * KunEasing.enter.transform(0.5),
        ),
    );

    await tester.pumpWidget(wrap(KunCard(onTap: () {}, child: body)));
    await tester.tap(card);
    await tester.pump();
    expect(rippleLayer(card), findsNothing);
  });

  testWidgets('a KunButton in a clickable card ripples itself, not the card',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        KunCard(
          clickable: true,
          child: KunButton(onPressed: () {}, child: const Text('Reply')),
        ),
      ),
    );
    await tester.tap(find.text('Reply'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(ripplePaint(find.byType(KunButton)), findsOneWidget);
    expect(ripplePaint(find.byType(KunCard)), findsOneWidget);
  });
}
