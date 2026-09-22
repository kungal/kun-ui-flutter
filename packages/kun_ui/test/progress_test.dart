import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(Widget child, {bool reducedMotion = false, double? width = 200}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: KunTheme(
        data: KunThemeData.light(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SizedBox(width: width, child: child)),
        ),
      ),
    );

Finder get bar => find.byType(KunProgress);

double barHeight(WidgetTester tester) => tester.getRect(bar).height;

void main() {
  testWidgets('the percentage is rounded, clamped, and reported once',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(const KunProgress(value: 33.4, showLabel: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('33%'), findsOneWidget);
    expect(tester.getSemantics(bar).value, '33');

    await tester.pumpWidget(
      wrap(const KunProgress(value: 250, showLabel: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);

    await tester.pumpWidget(
      wrap(const KunProgress(value: -10, showLabel: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('0%'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('it reports itself a progressbar', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(const KunProgress(value: 40, semanticLabel: 'Upload progress')),
    );
    await tester.pumpAndSettle();

    // Without the role an Android dump showed a plain android.view.View with
    // the percentage as its text, where the web has role="progressbar".
    final SemanticsData data = tester.getSemantics(bar).getSemanticsData();
    expect(data.role, SemanticsRole.progressBar);
    expect(data.label, 'Upload progress');
    // The range is the percentage's, not `max`'s: Flutter asserts the value
    // lies between the bounds, and the web reports a percentage beside an
    // aria-valuemax of `max`.
    expect(data.value, '40');
    expect(data.minValue, '0');
    expect(data.maxValue, '100');
    semantics.dispose();
  });

  testWidgets('max scales the percentage, and zero falls back to 100',
      (tester) async {
    await tester.pumpWidget(
      wrap(const KunProgress(value: 25, max: 50, showLabel: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('50%'), findsOneWidget);

    await tester.pumpWidget(
      wrap(const KunProgress(value: 40, max: 0, showLabel: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('40%'), findsOneWidget);
  });

  testWidgets('an indeterminate bar reports no value and shows no label',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(const KunProgress(indeterminate: true, showLabel: true)),
    );
    await tester.pump();

    final SemanticsData data = tester.getSemantics(bar).getSemanticsData();
    expect(data.value, '');
    // Flutter refuses a progressBar with no value, where ARIA allows one.
    expect(data.role, SemanticsRole.none);
    expect(find.textContaining('%'), findsNothing);
    semantics.dispose();
  });

  testWidgets('the size scale is the web h-1..h-5', (tester) async {
    const Map<KunUISize, double> heights = <KunUISize, double>{
      KunUISize.xs: KunSpacing.unit,
      KunUISize.sm: KunSpacing.unit * 2,
      KunUISize.md: KunSpacing.unit * 3,
      KunUISize.lg: KunSpacing.unit * 4,
      KunUISize.xl: KunSpacing.unit * 5,
    };
    for (final MapEntry<KunUISize, double> entry in heights.entries) {
      await tester.pumpWidget(wrap(KunProgress(size: entry.key, value: 50)));
      await tester.pumpAndSettle();
      expect(barHeight(tester), entry.value, reason: entry.key.name);
    }
  });

  testWidgets('the fill is the percentage of the track', (tester) async {
    await tester.pumpWidget(wrap(const KunProgress(value: 50)));
    await tester.pumpAndSettle();

    final Finder fill = find.byType(ColoredBox);
    final Rect track = tester.getRect(bar);
    // The track is the first ColoredBox, the fill the last.
    expect(
      tester.getRect(fill.last).width,
      moreOrLessEquals(track.width / 2, epsilon: 0.5),
    );
  });

  testWidgets('the ring is the web 96px square', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunProgress(variant: KunProgressVariant.circle, value: 60),
        width: null,
      ),
    );
    await tester.pumpAndSettle();

    final Rect box = tester.getRect(bar);
    expect(box.width, KunSpacing.unit * 24);
    expect(box.height, KunSpacing.unit * 24);
  });

  testWidgets('the ring shows its label, and an indeterminate one does not',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunProgress(
          variant: KunProgressVariant.circle,
          value: 60,
          showLabel: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('60%'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        const KunProgress(
          variant: KunProgressVariant.circle,
          value: 60,
          showLabel: true,
          indeterminate: true,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('60%'), findsNothing);
  });

  testWidgets('reduced motion stops the sweep and the stripes', (tester) async {
    await tester.pumpWidget(
      wrap(const KunProgress(indeterminate: true), reducedMotion: true),
    );
    await tester.pump();
    // A running loop would schedule a frame on every tick; a stopped one
    // settles. pumpAndSettle times out on an endless animation.
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      wrap(
        const KunProgress(variant: KunProgressVariant.striped, value: 40),
        reducedMotion: true,
      ),
    );
    await tester.pumpAndSettle();
  });
}
