import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(
  Widget child, {
  KunThemeData? data,
  bool disableAnimations = false,
}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: KunTheme(
        data: data ?? KunThemeData.light(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: child),
        ),
      ),
    );

BoxDecoration decorationOf(WidgetTester tester) => tester
    .widget<DecoratedBox>(
      find.descendant(
        of: find.byType(KunSkeleton),
        matching: find.byType(DecoratedBox),
      ),
    )
    .decoration as BoxDecoration;

FadeTransition pulseOf(WidgetTester tester) => tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(KunSkeleton),
        matching: find.byType(FadeTransition),
      ),
    );

/// Pumps until the frame timestamp is a whole number of pulse cycles, the
/// moment every pulse on screen is at opacity 1.
Future<void> pumpToCycleStart(WidgetTester tester) async {
  late Duration stamp;
  SchedulerBinding.instance.addPostFrameCallback((ts) => stamp = ts);
  await tester.pump();
  final int period = KunPulse.duration.inMicroseconds;
  final int rest = period - stamp.inMicroseconds % period;
  await tester.pump(Duration(microseconds: rest % period));
}

void main() {
  testWidgets('defaults: rect is 20 tall and fills a 300-wide parent',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 300),
          child: KunSkeleton(),
        ),
      ),
    );
    expect(tester.getSize(find.byType(KunSkeleton)), const Size(300, 20));
  });

  testWidgets('text is one em tall and full width', (tester) async {
    await tester.pumpWidget(
      wrap(
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 300),
          child: DefaultTextStyle(
            style: TextStyle(fontSize: 18),
            child: KunSkeleton(variant: KunSkeletonVariant.text),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(KunSkeleton)), const Size(300, 18));
  });

  testWidgets('an intrinsic parent can measure every variant', (tester) async {
    await tester.pumpWidget(
      wrap(
        const IntrinsicWidth(
          child: IntrinsicHeight(
            child: Row(
              children: <Widget>[
                KunSkeleton(
                  key: ValueKey<String>('circle'),
                  variant: KunSkeletonVariant.circle,
                ),
                SizedBox(
                  width: 200,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      KunSkeleton(
                        key: ValueKey<String>('factor'),
                        variant: KunSkeletonVariant.text,
                        widthFactor: 0.6,
                      ),
                      KunSkeleton(
                        key: ValueKey<String>('fill'),
                        variant: KunSkeletonVariant.text,
                      ),
                      KunSkeleton(key: ValueKey<String>('fixed'), width: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    Size sizeOf(String key) =>
        tester.getSize(find.byKey(ValueKey<String>(key)));
    expect(sizeOf('circle'), const Size(40, 40));
    expect(sizeOf('factor'), const Size(120, kDefaultFontSize));
    expect(sizeOf('fill'), const Size(200, kDefaultFontSize));
    expect(sizeOf('fixed'), const Size(120, 20));
  });

  testWidgets('circle is 40 × 40', (tester) async {
    await tester.pumpWidget(
      wrap(const KunSkeleton(variant: KunSkeletonVariant.circle)),
    );
    expect(tester.getSize(find.byType(KunSkeleton)), const Size(40, 40));
  });

  testWidgets('width, widthFactor and height apply', (tester) async {
    await tester.pumpWidget(
      wrap(
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 300),
          child: KunSkeleton(width: 120),
        ),
      ),
    );
    expect(tester.getSize(find.byType(KunSkeleton)), const Size(120, 20));

    await tester.pumpWidget(
      wrap(
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 300),
          child: KunSkeleton(widthFactor: 0.6),
        ),
      ),
    );
    expect(tester.getSize(find.byType(KunSkeleton)), const Size(180, 20));

    await tester.pumpWidget(
      wrap(
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 300),
          child: KunSkeleton(height: 48),
        ),
      ),
    );
    expect(tester.getSize(find.byType(KunSkeleton)), const Size(300, 48));
  });

  test('width and widthFactor together assert', () {
    expect(
      () => KunSkeleton(width: 10, widthFactor: 0.5),
      throwsAssertionError,
    );
  });

  testWidgets('colours: light shade200, dark shade100 at global opacity',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 300),
          child: KunSkeleton(),
        ),
      ),
    );
    expect(decorationOf(tester).color, KunColors.light.neutral.shade200);

    await tester.pumpWidget(
      wrap(
        const SizedBox(width: 300, child: KunSkeleton()),
        data: KunThemeData.dark(),
      ),
    );
    expect(
      decorationOf(tester).color,
      KunColors.dark.neutral.shade100
          .withValues(alpha: KunColors.globalOpacity),
    );
  });

  testWidgets(
      'corners: text ignores the theme, circle is a circle, rect follows',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 300,
          child: KunSkeleton(variant: KunSkeletonVariant.text),
        ),
        data: KunThemeData.light(rounded: KunUIRounded.lg),
      ),
    );
    expect(
      decorationOf(tester).borderRadius,
      BorderRadius.circular(KunRounded.md),
    );
    expect(decorationOf(tester).shape, BoxShape.rectangle);

    await tester.pumpWidget(
      wrap(const KunSkeleton(variant: KunSkeletonVariant.circle)),
    );
    expect(decorationOf(tester).shape, BoxShape.circle);
    expect(decorationOf(tester).borderRadius, isNull);

    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 300,
          child: KunSkeleton(rounded: KunUIRounded.sm),
        ),
      ),
    );
    expect(
      decorationOf(tester).borderRadius,
      BorderRadius.circular(KunRadius.sm),
    );

    await tester.pumpWidget(
      wrap(
        const SizedBox(width: 300, child: KunSkeleton()),
        data: KunThemeData.light(rounded: KunUIRounded.lg),
      ),
    );
    expect(
      decorationOf(tester).borderRadius,
      BorderRadius.circular(KunRadius.lg),
    );
  });

  testWidgets('loaded shows the child and no placeholder', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunSkeleton(
          loaded: true,
          child: Text('ready'),
        ),
      ),
    );
    expect(find.text('ready'), findsOneWidget);
    expect(find.byType(DecoratedBox), findsNothing);

    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 300,
          child: KunSkeleton(child: Text('ready')),
        ),
      ),
    );
    expect(find.text('ready'), findsNothing);
    expect(find.byType(DecoratedBox), findsOneWidget);
  });

  testWidgets('pulse opacities follow KunPulse', (tester) async {
    await tester.pumpWidget(
      wrap(
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 300),
          child: KunSkeleton(),
        ),
      ),
    );
    await pumpToCycleStart(tester);
    expect(pulseOf(tester).opacity.value, closeTo(1, 0.001));

    await tester.pump(KunPulse.duration ~/ 4);
    expect(
      pulseOf(tester).opacity.value,
      closeTo(1 - 0.5 * KunPulse.curve.transform(0.5), 0.001),
    );

    await tester.pump(KunPulse.duration ~/ 4);
    expect(pulseOf(tester).opacity.value, closeTo(KunPulse.midOpacity, 0.001));

    await tester.pump(KunPulse.duration ~/ 2);
    expect(pulseOf(tester).opacity.value, closeTo(1, 0.001));
  });

  testWidgets('skeletons mounted at different times pulse in step',
      (tester) async {
    Widget rows(int count) => wrap(
          SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < count; i++) KunSkeleton(key: ValueKey(i)),
              ],
            ),
          ),
        );
    List<double> opacities() => <double>[
          for (final FadeTransition fade in tester.widgetList<FadeTransition>(
            find.descendant(
              of: find.byType(KunSkeleton),
              matching: find.byType(FadeTransition),
            ),
          ))
            fade.opacity.value,
        ];

    await tester.pumpWidget(rows(1));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(rows(2));
    await tester.pump(const Duration(milliseconds: 170));
    await tester.pumpWidget(rows(3));

    for (int frame = 0; frame < 8; frame++) {
      final List<double> values = opacities();
      expect(values, hasLength(3));
      expect(values[1], closeTo(values[0], 0.0001));
      expect(values[2], closeTo(values[0], 0.0001));
      await tester.pump(const Duration(milliseconds: 230));
    }
  });

  testWidgets('animation none keeps opacity 1 and runs no ticker',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 300,
          child: KunSkeleton(animation: KunSkeletonAnimation.none),
        ),
      ),
    );
    expect(find.byType(FadeTransition), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion keeps opacity 1 and starts when flipped',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(width: 300, child: KunSkeleton()),
        disableAnimations: true,
      ),
    );
    expect(pulseOf(tester).opacity.value, 1);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(KunPulse.duration ~/ 4);
    expect(pulseOf(tester).opacity.value, 1);

    await tester.pumpWidget(
      wrap(
        const SizedBox(width: 300, child: KunSkeleton()),
        disableAnimations: false,
      ),
    );
    expect(tester.hasRunningAnimations, isTrue);
    await pumpToCycleStart(tester);
    expect(pulseOf(tester).opacity.value, closeTo(1, 0.001));
    await tester.pump(KunPulse.duration ~/ 2);
    expect(pulseOf(tester).opacity.value, closeTo(KunPulse.midOpacity, 0.001));
  });

  testWidgets('the placeholder is absent from the semantics tree',
      (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Semantics(
            label: 'host',
            child: const KunSkeleton(),
          ),
        ),
      ),
    );
    expect(tester.getSemantics(find.bySemanticsLabel('host')).childrenCount, 0);
    handle.dispose();
  });
}
