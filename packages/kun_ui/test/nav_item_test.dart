import 'dart:ui' show Tristate;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(
  Widget child, {
  KunUIConfig? config,
}) {
  Widget tree = child;
  if (config != null) {
    tree = KunUIConfigScope(config: config, child: tree);
  }
  return KunTheme(
    data: KunThemeData.light(),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: tree),
    ),
  );
}

void main() {
  testWidgets('current is flat in color; otherwise light and neutral',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunNavItem(
          label: 'Search',
          icon: Icon(KunIcons.search),
          current: true,
        ),
      ),
    );
    KunButton button = tester.widget<KunButton>(find.byType(KunButton));
    expect(button.variant, KunUIVariant.flat);
    expect(button.color, KunUIColor.primary);
    expect(button.fullWidth, isTrue);

    await tester.pumpWidget(
      wrap(
        const KunNavItem(
          label: 'Search',
          icon: Icon(KunIcons.search),
          color: KunUIColor.danger,
        ),
      ),
    );
    button = tester.widget<KunButton>(find.byType(KunButton));
    expect(button.variant, KunUIVariant.light);
    expect(button.color, KunUIColor.neutral);

    await tester.pumpWidget(
      wrap(
        const KunNavItem(
          label: 'Search',
          icon: Icon(KunIcons.search),
          current: true,
          color: KunUIColor.danger,
        ),
      ),
    );
    button = tester.widget<KunButton>(find.byType(KunButton));
    expect(button.variant, KunUIVariant.flat);
    expect(button.color, KunUIColor.danger);
  });

  testWidgets('current is selected; others are not', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KunNavItem(
              label: 'Search',
              icon: Icon(KunIcons.search),
              current: true,
            ),
            KunNavItem(
              label: 'Calendar',
              icon: Icon(KunIcons.calendar),
            ),
          ],
        ),
      ),
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Search'))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Calendar'))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.none,
    );
    handle.dispose();
  });

  testWidgets('stacked puts a 20px icon above the xs label', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 96,
          child: KunNavItem(
            label: 'Search',
            icon: Icon(KunIcons.search),
            stacked: true,
          ),
        ),
      ),
    );
    final Rect icon = tester.getRect(find.byIcon(KunIcons.search));
    final Rect label = tester.getRect(find.text('Search'));
    expect(icon.size, const Size.square(20));
    expect(icon.bottom, lessThanOrEqualTo(label.top));
    expect(icon.center.dx, closeTo(label.center.dx, 1));
    expect(label.top - icon.bottom, closeTo(KunSpacing.unit, 1));
    final TextStyle style = tester
        .widget<DefaultTextStyle>(
          find
              .ancestor(
                of: find.text('Search'),
                matching: find.byType(DefaultTextStyle),
              )
              .first,
        )
        .style;
    expect(style.fontSize, KunText.xs.fontSize);
  });

  testWidgets('inline puts a 16px icon left of the label at the left padding',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 224,
          child: KunNavItem(
            label: 'Search',
            icon: Icon(KunIcons.search),
          ),
        ),
      ),
    );
    final Rect button = tester.getRect(find.byType(KunButton));
    final Rect icon = tester.getRect(find.byIcon(KunIcons.search));
    final Rect label = tester.getRect(find.text('Search'));
    expect(icon.size, const Size.square(16));
    expect(icon.center.dy, closeTo(label.center.dy, 1));
    expect(icon.right, lessThanOrEqualTo(label.left));
    expect(label.left - icon.right, closeTo(KunSpacing.unit * 2, 1));
    final double pad = 1 + KunControlMetrics.of(KunUISize.md).horizontalPadding;
    expect(icon.left, closeTo(button.left + pad, 0.5));
    expect(label.left, greaterThan(button.left + pad));
  });

  testWidgets('onPressed fires; href navigates after it; disabled blocks both',
      (tester) async {
    final List<String> order = <String>[];
    await tester.pumpWidget(
      wrap(
        KunNavItem(
          label: 'Search',
          icon: const Icon(KunIcons.search),
          href: '/search',
          onPressed: () => order.add('press'),
        ),
        config: KunUIConfig(
          navigate: (BuildContext context, String href) => order.add(href),
        ),
      ),
    );
    await tester.tap(find.byType(KunNavItem));
    expect(order, <String>['press', '/search']);

    order.clear();
    await tester.pumpWidget(
      wrap(
        KunNavItem(
          label: 'Search',
          icon: const Icon(KunIcons.search),
          href: '/search',
          disabled: true,
          onPressed: () => order.add('press'),
        ),
        config: KunUIConfig(
          navigate: (BuildContext context, String href) => order.add(href),
        ),
      ),
    );
    await tester.tap(find.byType(KunNavItem), warnIfMissed: false);
    expect(order, isEmpty);
  });

  testWidgets('null onPressed and href do nothing and do not gray out',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunNavItem(
          label: 'Search',
          icon: Icon(KunIcons.search),
        ),
      ),
    );
    await tester.tap(find.byType(KunNavItem));
    final KunButton button = tester.widget<KunButton>(find.byType(KunButton));
    expect(button.disabled, isFalse);
    expect(button.onPressed, isNotNull);
  });

  testWidgets('the semantics label is the item label exactly once',
      (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        const KunNavItem(
          label: 'Search',
          icon: Icon(KunIcons.search),
        ),
      ),
    );
    final String label =
        tester.getSemantics(find.bySemanticsLabel('Search')).label;
    expect(label, 'Search');
    expect(RegExp('Search').allMatches(label).length, 1);
    handle.dispose();
  });

  testWidgets('a KunBadge icon renders, taps, and keeps the node named',
      (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    var presses = 0;
    await tester.pumpWidget(
      wrap(
        KunNavItem(
          label: 'Uploads',
          stacked: true,
          icon: const KunBadge(
            count: 3,
            child: Icon(KunIcons.upload),
          ),
          onPressed: () => presses++,
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(KunIcons.upload), findsOneWidget);
    await tester.tap(find.byType(KunNavItem));
    expect(presses, 1);
    final Finder named = find.bySemanticsLabel(RegExp('Uploads'));
    expect(named, findsOneWidget);
    final String nodeLabel = tester.getSemantics(named).label;
    expect(RegExp('Uploads').allMatches(nodeLabel).length, 1);
    handle.dispose();
  });

  testWidgets('four stacked items in Expanded stay short under a tall parent',
      (tester) async {
    const List<String> labels = <String>[
      'Search',
      'Calendar',
      'Uploads',
      'Downloads',
    ];
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 400,
          height: 800,
          child: Row(
            children: [
              for (final String label in labels)
                Expanded(
                  child: KunNavItem(
                    label: label,
                    stacked: true,
                    icon: const Icon(KunIcons.search),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    for (int i = 0; i < labels.length; i++) {
      expect(
        tester.getSize(find.byType(KunNavItem).at(i)).height,
        lessThan(100),
        reason: labels[i],
      );
    }
  });
}
