import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(Widget child) => KunTheme(
      data: KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: 300, child: child)),
      ),
    );

Finder get boxFinder => find
    .descendant(of: find.byType(KunInput), matching: find.byType(Container))
    .first;

BoxDecoration decorationOf(WidgetTester tester) =>
    tester.widget<Container>(boxFinder).decoration! as BoxDecoration;

void main() {
  testWidgets('shares the control scale with KunButton', (tester) async {
    const heights = {
      KunUISize.xs: 26.0,
      KunUISize.sm: 34.0,
      KunUISize.md: 38.0,
      KunUISize.lg: 46.0,
      KunUISize.xl: 54.0,
    };
    for (final entry in heights.entries) {
      await tester.pumpWidget(wrap(KunInput(size: entry.key)));
      expect(
        tester.getSize(boxFinder).height,
        entry.value,
        reason: 'size ${entry.key.name}',
      );
      expect(
        tester.getSize(boxFinder).height,
        KunControlMetrics.of(entry.key).square,
        reason: 'an icon-only button of the same size is a square of this side',
      );
    }
  });

  testWidgets('typing reports through onChanged', (tester) async {
    final seen = <String>[];
    await tester.pumpWidget(wrap(KunInput(onChanged: seen.add)));
    await tester.enterText(find.byType(EditableText), 'kun');
    expect(seen, ['kun']);
  });

  testWidgets('the value is controlled by the parent', (tester) async {
    await tester.pumpWidget(wrap(const KunInput(value: 'one')));
    expect(find.text('one'), findsOneWidget);
    await tester.pumpWidget(wrap(const KunInput(value: 'two')));
    expect(find.text('two'), findsOneWidget);
    expect(find.text('one'), findsNothing);
  });

  testWidgets('the placeholder shows only while empty', (tester) async {
    await tester.pumpWidget(wrap(const KunInput(placeholder: 'Search')));
    expect(find.text('Search'), findsOneWidget);
    await tester.pumpWidget(
      wrap(const KunInput(value: 'kun', placeholder: 'Search')),
    );
    expect(find.text('Search'), findsNothing);
  });

  testWidgets('clear appears with a value and empties it', (tester) async {
    final seen = <String>[];
    var clears = 0;
    await tester.pumpWidget(wrap(const KunInput(isClearable: true)));
    expect(find.byIcon(KunIcons.circleX), findsNothing);

    await tester.pumpWidget(
      wrap(
        KunInput(
          value: 'kun',
          isClearable: true,
          onChanged: seen.add,
          onClear: () => clears++,
        ),
      ),
    );
    expect(find.byIcon(KunIcons.circleX), findsOneWidget);
    await tester.tap(find.byIcon(KunIcons.circleX));
    expect(seen, ['']);
    expect(clears, 1);
  });

  testWidgets('password obscures, and revealPassword toggles it',
      (tester) async {
    await tester.pumpWidget(
      wrap(const KunInput(value: 'secret', type: KunInputType.password)),
    );
    expect(tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isTrue);
    expect(find.byIcon(KunIcons.eye), findsNothing);

    await tester.pumpWidget(
      wrap(
        const KunInput(
          value: 'secret',
          type: KunInputType.password,
          revealPassword: true,
        ),
      ),
    );
    await tester.tap(find.byIcon(KunIcons.eye));
    await tester.pump();
    expect(tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isFalse);
    expect(find.byIcon(KunIcons.eyeOff), findsOneWidget);
  });

  testWidgets('an error takes the border to danger and hides the helper',
      (tester) async {
    await tester.pumpWidget(
      wrap(const KunInput(description: 'Helper', error: 'Required')),
    );
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Helper'), findsNothing);
    expect(
      (decorationOf(tester).border! as Border).top.color,
      KunColors.light.danger.shade300,
    );
  });

  testWidgets('isInvalid reddens the border with no message', (tester) async {
    await tester.pumpWidget(wrap(const KunInput(isInvalid: true)));
    expect(
      (decorationOf(tester).border! as Border).top.color,
      KunColors.light.danger.shade300,
    );
  });

  testWidgets('focus paints the flush 2px ring in the control color',
      (tester) async {
    await tester.pumpWidget(wrap(const KunInput(color: KunUIColor.primary)));
    expect(decorationOf(tester).boxShadow, KunShadows.sm);

    await tester.tap(find.byType(KunInput));
    await tester.pump();
    final shadows = decorationOf(tester).boxShadow!;
    expect(shadows.first.spreadRadius, 2);
    expect(shadows.first.blurRadius, 0);
    expect(
      shadows.first.color,
      KunColors.light.primary.solid.withValues(alpha: 0.5),
    );
  });

  testWidgets('the label carries the required marker', (tester) async {
    await tester.pumpWidget(
      wrap(const KunInput(label: 'Name', required: true)),
    );
    expect(find.textContaining('Name'), findsOneWidget);
    expect(find.textContaining('*'), findsOneWidget);
  });

  testWidgets('disabled blocks editing', (tester) async {
    await tester.pumpWidget(wrap(const KunInput(disabled: true)));
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).readOnly,
      isTrue,
    );
  });

  testWidgets('the clear button carries an overridable accessible name',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      wrap(const KunInput(value: 'text', isClearable: true)),
    );
    expect(find.bySemanticsLabel('清除'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        const KunInput(
          value: 'text',
          isClearable: true,
          clearSemanticLabel: 'Clear',
        ),
      ),
    );
    expect(find.bySemanticsLabel('Clear'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('the reveal toggle names both of its states', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      wrap(
        const KunInput(
          value: 'secret',
          type: KunInputType.password,
          revealPassword: true,
        ),
      ),
    );
    expect(find.bySemanticsLabel('显示密码'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('显示密码'));
    await tester.pump();
    expect(find.bySemanticsLabel('隐藏密码'), findsOneWidget);

    semantics.dispose();
  });
}
