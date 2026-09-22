import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

const List<KunRadioOption<String>> options = <KunRadioOption<String>>[
  KunRadioOption<String>(value: 'free', label: 'Free'),
  KunRadioOption<String>(
    value: 'pro',
    label: 'Pro',
    description: 'Everything in Free',
  ),
  KunRadioOption<String>(value: 'team', label: 'Team', disabled: true),
  KunRadioOption<String>(value: 'max', label: 'Max'),
];

Widget wrap(Widget child) => KunTheme(
      data: KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: 400, child: child)),
      ),
    );

Finder option(String value) =>
    find.byKey(ValueKey<String>('KunRadioGroup.option.$value'));

bool focused(WidgetTester tester, String value) => tester
    .widget<Focus>(
        find.descendant(of: option(value), matching: find.byType(Focus)))
    .focusNode!
    .hasPrimaryFocus;

void main() {
  testWidgets('a tap chooses the option and reports its index', (tester) async {
    String? value;
    int? index;
    await tester.pumpWidget(
      wrap(
        KunRadioGroup<String>(
          value: 'free',
          options: options,
          onChanged: (String v) => value = v,
          onSelected: (String v, int i) => index = i,
        ),
      ),
    );

    await tester.tap(find.text('Pro'));
    expect(value, 'pro');
    expect(index, 1);
  });

  testWidgets('choosing the chosen one, or a disabled one, reports nothing',
      (tester) async {
    String? value;
    await tester.pumpWidget(
      wrap(
        KunRadioGroup<String>(
          value: 'free',
          options: options,
          onChanged: (String v) => value = v,
        ),
      ),
    );

    await tester.tap(find.text('Free'));
    expect(value, isNull);

    await tester.tap(find.text('Team'));
    expect(value, isNull);
  });

  testWidgets('a disabled group reports nothing at all', (tester) async {
    String? value;
    await tester.pumpWidget(
      wrap(
        KunRadioGroup<String>(
          value: 'free',
          options: options,
          disabled: true,
          onChanged: (String v) => value = v,
        ),
      ),
    );

    await tester.tap(find.text('Pro'));
    expect(value, isNull);
  });

  testWidgets('the arrow keys move and choose, skipping disabled and wrapping',
      (tester) async {
    String value = 'free';
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return KunRadioGroup<String>(
              value: value,
              options: options,
              onChanged: (String v) => setState(() => value = v),
            );
          },
        ),
      ),
    );

    tester
        .widget<Focus>(
          find.descendant(of: option('free'), matching: find.byType(Focus)),
        )
        .focusNode!
        .requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(value, 'pro');
    expect(focused(tester, 'pro'), isTrue);

    // 'team' is disabled, so the next one down is 'max'.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(value, 'max');

    // And it wraps back to the top.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(value, 'free');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(value, 'max');
  });

  testWidgets('only the chosen option is a tab stop', (tester) async {
    await tester.pumpWidget(
      wrap(KunRadioGroup<String>(value: 'pro', options: options)),
    );

    bool traversable(String value) => !tester
        .widget<Focus>(
          find.descendant(of: option(value), matching: find.byType(Focus)),
        )
        .skipTraversal;

    expect(traversable('pro'), isTrue);
    expect(traversable('free'), isFalse);
    expect(traversable('max'), isFalse);
  });

  testWidgets('with nothing chosen the first enabled option is the tab stop',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunRadioGroup<String>(value: null, options: options),
      ),
    );

    expect(
      !tester
          .widget<Focus>(
            find.descendant(of: option('free'), matching: find.byType(Focus)),
          )
          .skipTraversal,
      isTrue,
    );
  });

  testWidgets('every variant renders its options', (tester) async {
    for (final KunRadioVariant variant in KunRadioVariant.values) {
      await tester.pumpWidget(
        wrap(
          KunRadioGroup<String>(
            value: 'free',
            options: options,
            variant: variant,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Free'), findsOneWidget, reason: variant.name);
      expect(find.text('Max'), findsOneWidget, reason: variant.name);
    }
  });

  testWidgets('a card tints its border and fill when chosen', (tester) async {
    final KunThemeData theme = KunThemeData.light();
    await tester.pumpWidget(
      wrap(
        KunRadioGroup<String>(
          value: 'free',
          options: options,
          variant: KunRadioVariant.card,
        ),
      ),
    );
    await tester.pumpAndSettle();

    BoxDecoration cardOf(String value) => tester
        .widget<AnimatedContainer>(
          find
              .descendant(
                of: option(value),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        )
        .decoration! as BoxDecoration;

    expect(
      cardOf('free').color,
      theme.colors.primary.solid.withValues(alpha: 0.05),
    );
    expect(cardOf('max').color, theme.colors.content1);
  });

  testWidgets('a column of cards stretches to the group width', (tester) async {
    await tester.pumpWidget(
      wrap(
        KunRadioGroup<String>(
          value: 'free',
          options: options,
          variant: KunRadioVariant.card,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The web's `flex-col` stretches its children; a shrink-wrapped column
    // gave every card the width of its own label.
    for (final String value in <String>['free', 'pro', 'team', 'max']) {
      expect(tester.getRect(option(value)).width, 400, reason: value);
    }
  });

  testWidgets('the label names the group and an error shows under it',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        KunRadioGroup<String>(
          value: 'free',
          options: options,
          label: 'Plan',
          error: 'Pick one',
        ),
      ),
    );

    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Pick one'), findsOneWidget);
  });

  testWidgets('the group is a radiogroup of mutually exclusive options',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        KunRadioGroup<String>(
          value: 'pro',
          options: options,
          label: 'Plan',
          onChanged: (_) {},
        ),
      ),
    );

    final SemanticsData group = tester
        .getSemantics(find.byType(KunRadioGroup<String>))
        .getSemanticsData();
    expect(group.role, SemanticsRole.radioGroup);
    expect(group.label, 'Plan');

    final SemanticsData pro =
        tester.getSemantics(find.text('Pro')).getSemanticsData();
    expect(pro.flagsCollection.isChecked, CheckedState.isTrue);
    expect(pro.flagsCollection.isInMutuallyExclusiveGroup, isTrue);

    final SemanticsData team =
        tester.getSemantics(find.text('Team')).getSemanticsData();
    expect(team.flagsCollection.isEnabled, Tristate.isFalse);
    semantics.dispose();
  });
}
