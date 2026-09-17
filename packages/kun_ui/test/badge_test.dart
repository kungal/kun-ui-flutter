import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(Widget child, {KunThemeData? data}) => KunTheme(
      data: data ?? KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

BoxDecoration decorationOf(WidgetTester tester) {
  final containers = tester
      .widgetList<Container>(
        find.descendant(
          of: find.byType(KunBadge),
          matching: find.byType(Container),
        ),
      )
      .where((container) => container.decoration != null);
  if (containers.isNotEmpty) {
    return containers.first.decoration! as BoxDecoration;
  }
  return tester
      .widget<DecoratedBox>(
        find.descendant(
          of: find.byType(KunBadge),
          matching: find.byType(DecoratedBox),
        ),
      )
      .decoration as BoxDecoration;
}

Finder badgePaint() => find.descendant(
      of: find.byType(KunBadge),
      matching: find.byType(DecoratedBox),
    );

void main() {
  testWidgets('visibility follows show, showZero, count and variant',
      (tester) async {
    await tester.pumpWidget(wrap(const KunBadge()));
    expect(find.byType(Text), findsNothing);
    expect(find.byType(DecoratedBox), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Container && widget.decoration != null,
      ),
      findsNothing,
    );

    await tester.pumpWidget(wrap(const KunBadge(count: 5)));
    expect(find.text('5'), findsOneWidget);

    await tester.pumpWidget(
      wrap(const KunBadge(showZero: true, count: 0)),
    );
    expect(find.text('0'), findsOneWidget);

    await tester.pumpWidget(
      wrap(const KunBadge(show: false, count: 5)),
    );
    expect(find.byType(Text), findsNothing);
    expect(find.byType(DecoratedBox), findsNothing);

    await tester.pumpWidget(
      wrap(const KunBadge(variant: KunBadgeVariant.dot, count: 0)),
    );
    expect(find.byType(DecoratedBox), findsOneWidget);
    expect(find.byType(Text), findsNothing);

    await tester.pumpWidget(
      wrap(const KunBadge(count: -3, showZero: true)),
    );
    expect(find.text('-3'), findsOneWidget);
  });

  testWidgets('count above max shows as max+', (tester) async {
    await tester.pumpWidget(wrap(const KunBadge(count: 100)));
    expect(find.text('99+'), findsOneWidget);

    await tester.pumpWidget(wrap(const KunBadge(count: 99)));
    expect(find.text('99'), findsOneWidget);

    await tester.pumpWidget(wrap(const KunBadge(count: 10, max: 9)));
    expect(find.text('9+'), findsOneWidget);

    await tester.pumpWidget(
      wrap(const KunBadge(count: 2000, max: 999)),
    );
    expect(find.text('999+'), findsOneWidget);
  });

  testWidgets('count sizes match the web table', (tester) async {
    const sizes = <KunBadgeSize,
        ({
      double height,
      double fontSize,
      double padding,
      double minWidth,
    })>{
      KunBadgeSize.sm: (
        height: 16,
        fontSize: 10,
        padding: 4,
        minWidth: 16,
      ),
      KunBadgeSize.md: (
        height: 20,
        fontSize: 12,
        padding: 6,
        minWidth: 20,
      ),
      KunBadgeSize.lg: (
        height: 24,
        fontSize: 14,
        padding: 8,
        minWidth: 24,
      ),
    };

    for (final entry in sizes.entries) {
      await tester.pumpWidget(
        wrap(KunBadge(count: 120, size: entry.key)),
      );
      final size = tester.getSize(find.byType(KunBadge));
      expect(size.height, entry.value.height, reason: entry.key.name);
      final style = (tester
              .widget<RichText>(
                find.descendant(
                  of: find.byType(KunBadge),
                  matching: find.byType(RichText),
                ),
              )
              .text as TextSpan)
          .style!;
      expect(style.fontSize, entry.value.fontSize, reason: entry.key.name);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(KunBadge),
          matching: find.byType(RichText),
        ),
      );
      expect(
        size.width,
        paragraph.size.width + 2 * entry.value.padding,
        reason: entry.key.name,
      );

      await tester.pumpWidget(
        wrap(KunBadge(count: 5, size: entry.key)),
      );
      expect(
        tester.getSize(find.byType(KunBadge)).width,
        greaterThanOrEqualTo(entry.value.minWidth),
        reason: '${entry.key.name} one-digit min width',
      );
    }
  });

  testWidgets('dot sizes are squares of 8 / 10 / 12', (tester) async {
    const sizes = <KunBadgeSize, double>{
      KunBadgeSize.sm: 8,
      KunBadgeSize.md: 10,
      KunBadgeSize.lg: 12,
    };
    for (final entry in sizes.entries) {
      await tester.pumpWidget(
        wrap(
          KunBadge(
            variant: KunBadgeVariant.dot,
            size: entry.key,
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(KunBadge)),
        Size.square(entry.value),
        reason: entry.key.name,
      );
    }
  });

  testWidgets('colours follow the solid scale', (tester) async {
    await tester.pumpWidget(wrap(const KunBadge(count: 5)));
    expect(decorationOf(tester).color, KunColors.light.danger.solid);
    final style = (tester
            .widget<RichText>(
              find.descendant(
                of: find.byType(KunBadge),
                matching: find.byType(RichText),
              ),
            )
            .text as TextSpan)
        .style!;
    expect(style.color, KunColors.light.danger.onSolid);
    expect(style.fontWeight, FontWeight.w500);

    await tester.pumpWidget(
      wrap(const KunBadge(count: 5, color: KunUIColor.neutral)),
    );
    expect(decorationOf(tester).color, KunColors.light.neutral.solid);
    final neutralStyle = (tester
            .widget<RichText>(
              find.descendant(
                of: find.byType(KunBadge),
                matching: find.byType(RichText),
              ),
            )
            .text as TextSpan)
        .style!;
    expect(neutralStyle.color, KunColors.light.neutral.onSolid);

    await tester.pumpWidget(
      wrap(const KunBadge(count: 5), data: KunThemeData.dark()),
    );
    expect(decorationOf(tester).color, KunColors.dark.danger.solid);
  });

  testWidgets('standalone has no ring; anchored has one', (tester) async {
    await tester.pumpWidget(wrap(const KunBadge(count: 5)));
    expect(decorationOf(tester).boxShadow, isNull);

    await tester.pumpWidget(
      wrap(
        const KunBadge(
          count: 5,
          child: SizedBox(width: 80, height: 40),
        ),
      ),
    );
    final lightShadows = decorationOf(tester).boxShadow!;
    expect(lightShadows, hasLength(1));
    expect(lightShadows.single.spreadRadius, 2);
    expect(lightShadows.single.blurRadius, 0);
    expect(lightShadows.single.offset, Offset.zero);
    expect(
      lightShadows.single.color,
      KunColors.light.background.withValues(alpha: KunColors.globalOpacity),
    );

    await tester.pumpWidget(
      wrap(
        const KunBadge(
          count: 5,
          child: SizedBox(width: 80, height: 40),
        ),
        data: KunThemeData.dark(),
      ),
    );
    final darkShadows = decorationOf(tester).boxShadow!;
    expect(darkShadows, hasLength(1));
    expect(darkShadows.single.spreadRadius, 2);
    expect(darkShadows.single.blurRadius, 0);
    expect(darkShadows.single.offset, Offset.zero);
    expect(
      darkShadows.single.color,
      KunColors.dark.background.withValues(alpha: KunColors.globalOpacity),
    );
  });

  testWidgets('anchored geometry sits 4px outside each corner', (tester) async {
    const child = SizedBox(width: 80, height: 40);

    for (final KunBadgePlacement placement in KunBadgePlacement.values) {
      await tester.pumpWidget(
        wrap(
          KunBadge(
            count: 5,
            placement: placement,
            child: child,
          ),
        ),
      );
      final anchor = tester.getRect(find.byType(KunBadge));
      expect(anchor.size, const Size(80, 40), reason: placement.name);
      final badge = tester.getRect(badgePaint());
      final double inset = KunSpacing.unit;
      switch (placement) {
        case KunBadgePlacement.topRight:
          expect(badge.top, anchor.top - inset);
          expect(badge.right, anchor.right + inset);
        case KunBadgePlacement.topLeft:
          expect(badge.top, anchor.top - inset);
          expect(badge.left, anchor.left - inset);
        case KunBadgePlacement.bottomRight:
          expect(badge.bottom, anchor.bottom + inset);
          expect(badge.right, anchor.right + inset);
        case KunBadgePlacement.bottomLeft:
          expect(badge.bottom, anchor.bottom + inset);
          expect(badge.left, anchor.left - inset);
      }
    }
  });

  testWidgets('anchored and hidden still shows the child', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunBadge(
          count: 0,
          child: SizedBox(width: 80, height: 40, key: ValueKey('anchor')),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('anchor')), findsOneWidget);
    expect(find.byType(DecoratedBox), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Container && widget.decoration != null,
      ),
      findsNothing,
    );
  });

  testWidgets('semanticLabel is a live region and hides the count text',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      wrap(const KunBadge(count: 5, semanticLabel: '5 条未读')),
    );
    expect(find.bySemanticsLabel('5 条未读'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('5 条未读'))
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    expect(find.bySemanticsLabel('5'), findsNothing);

    await tester.pumpWidget(wrap(const KunBadge(count: 5)));
    expect(find.bySemanticsLabel('5'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        KunBadge(
          count: 5,
          semanticLabel: '5 条未读',
          child: Semantics(
            label: 'Inbox',
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('5 条未读'), findsOneWidget);
    expect(find.bySemanticsLabel('Inbox'), findsOneWidget);

    semantics.dispose();
  });
}
