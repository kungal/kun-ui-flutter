import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(Widget child) => KunTheme(
      data: KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

BoxDecoration decorationOf(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(KunChip),
      matching: find.byType(Container),
    ),
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  testWidgets('the chip scale produces the web heights', (tester) async {
    const heights = {
      KunUISize.xs: 22.0,
      KunUISize.sm: 26.0,
      KunUISize.md: 30.0,
      KunUISize.lg: 34.0,
      KunUISize.xl: 42.0,
    };
    for (final entry in heights.entries) {
      await tester.pumpWidget(
        wrap(KunChip(size: entry.key, child: const Text('tag'))),
      );
      expect(
        tester.getSize(find.byType(KunChip)).height,
        entry.value,
        reason: 'size ${entry.key.name}',
      );
    }
  });

  testWidgets('defaults to the flat variant in the neutral color',
      (tester) async {
    await tester.pumpWidget(wrap(const KunChip(child: Text('tag'))));
    final expected = KunVariantStyle.resolve(
      scheme: KunColors.light,
      brightness: Brightness.light,
      variant: KunUIVariant.flat,
      color: KunUIColor.neutral,
    );
    expect(decorationOf(tester).color, expected.background);
  });

  testWidgets('closable renders the x and fires onClose', (tester) async {
    var closes = 0;
    await tester.pumpWidget(
      wrap(
        KunChip(
          closable: true,
          onClose: () => closes++,
          child: const Text('tag'),
        ),
      ),
    );
    expect(find.byIcon(KunIcons.x), findsOneWidget);
    await tester.tap(find.byIcon(KunIcons.x));
    expect(closes, 1);
  });

  testWidgets('no x without closable', (tester) async {
    await tester.pumpWidget(wrap(const KunChip(child: Text('tag'))));
    expect(find.byIcon(KunIcons.x), findsNothing);
  });

  testWidgets('disabled blocks the close button', (tester) async {
    var closes = 0;
    await tester.pumpWidget(
      wrap(
        KunChip(
          closable: true,
          disabled: true,
          onClose: () => closes++,
          child: const Text('tag'),
        ),
      ),
    );
    await tester.tap(find.byIcon(KunIcons.x), warnIfMissed: false);
    expect(closes, 0);
  });

  testWidgets('start and end widgets sit around the label', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunChip(
          start: SizedBox(width: 8, height: 8, key: ValueKey('start')),
          end: SizedBox(width: 8, height: 8, key: ValueKey('end')),
          child: Text('tag'),
        ),
      ),
    );
    final start = tester.getCenter(find.byKey(const ValueKey('start'))).dx;
    final label = tester.getCenter(find.text('tag')).dx;
    final end = tester.getCenter(find.byKey(const ValueKey('end'))).dx;
    expect(start, lessThan(label));
    expect(label, lessThan(end));
  });

  testWidgets("the close button's accessible name comes from the catalog",
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      wrap(KunChip(closable: true, onClose: () {}, child: const Text('tag'))),
    );
    expect(find.bySemanticsLabel(KunMessages.zhCN.chip.remove), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        KunMessagesScope(
          messages: KunMessages.en,
          child: KunChip(
            closable: true,
            onClose: () {},
            child: const Text('tag'),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel(KunMessages.en.chip.remove), findsOneWidget);
    expect(find.bySemanticsLabel(KunMessages.zhCN.chip.remove), findsNothing);

    semantics.dispose();
  });
}
