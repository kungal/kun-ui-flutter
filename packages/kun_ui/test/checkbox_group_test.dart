import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

const List<KunCheckBoxGroupOption<String>> options =
    <KunCheckBoxGroupOption<String>>[
  KunCheckBoxGroupOption<String>(value: 'vue', label: 'Vue'),
  KunCheckBoxGroupOption<String>(
    value: 'react',
    label: 'React',
    description: 'A library, strictly',
  ),
  KunCheckBoxGroupOption<String>(
    value: 'angular',
    label: 'Angular',
    disabled: true,
  ),
  KunCheckBoxGroupOption<String>(value: 'svelte', label: 'Svelte'),
];

Widget wrap(Widget child) => KunTheme(
      data: KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: 400, child: child)),
      ),
    );

Finder option(String value) =>
    find.byKey(ValueKey<String>('KunCheckBoxGroup.option.$value'));

double opacityOf(WidgetTester tester, String value) => tester
    .widget<Opacity>(
      find.descendant(of: option(value), matching: find.byType(Opacity)),
    )
    .opacity;

void main() {
  testWidgets('a tap adds to the selection and another removes it',
      (tester) async {
    List<String>? reported;
    await tester.pumpWidget(
      wrap(
        KunCheckBoxGroup<String>(
          values: const <String>['vue'],
          options: options,
          onChanged: (List<String> values) => reported = values,
        ),
      ),
    );

    await tester.tap(find.text('Svelte'));
    expect(reported, <String>['vue', 'svelte']);

    await tester.tap(find.text('Vue'));
    expect(reported, <String>[]);
  });

  testWidgets('Space toggles a focused option', (tester) async {
    List<String>? reported;
    await tester.pumpWidget(
      wrap(
        KunCheckBoxGroup<String>(
          values: const <String>[],
          options: options,
          onChanged: (List<String> values) => reported = values,
        ),
      ),
    );

    tester
        .widget<Focus>(
          find.descendant(of: option('vue'), matching: find.byType(Focus)),
        )
        .focusNode!
        .requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(reported, <String>['vue']);
  });

  testWidgets('a disabled option and a disabled group report nothing',
      (tester) async {
    List<String>? reported;
    await tester.pumpWidget(
      wrap(
        KunCheckBoxGroup<String>(
          values: const <String>[],
          options: options,
          onChanged: (List<String> values) => reported = values,
        ),
      ),
    );
    await tester.tap(find.text('Angular'));
    expect(reported, isNull);

    await tester.pumpWidget(
      wrap(
        KunCheckBoxGroup<String>(
          values: const <String>[],
          options: options,
          disabled: true,
          onChanged: (List<String> values) => reported = values,
        ),
      ),
    );
    await tester.tap(find.text('Vue'));
    expect(reported, isNull);
  });

  testWidgets('max blocks an addition, dims it, and still allows a removal',
      (tester) async {
    List<String>? reported;
    KunCheckBoxGroupInvalidReason? refused;
    await tester.pumpWidget(
      wrap(
        KunCheckBoxGroup<String>(
          values: const <String>['vue', 'react'],
          options: options,
          max: 2,
          onChanged: (List<String> values) => reported = values,
          onInvalid: (KunCheckBoxGroupInvalidReason reason) => refused = reason,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(opacityOf(tester, 'svelte'), 0.6);
    expect(opacityOf(tester, 'vue'), 1);

    await tester.tap(find.text('Svelte'));
    expect(reported, isNull);
    expect(refused, KunCheckBoxGroupInvalidReason.maxReached);

    await tester.tap(find.text('Vue'));
    expect(reported, <String>['react']);
  });

  testWidgets('every option is its own tab stop', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunCheckBoxGroup<String>(
          values: <String>['vue'],
          options: options,
        ),
      ),
    );

    bool traversable(String value) => !tester
        .widget<Focus>(
          find.descendant(of: option(value), matching: find.byType(Focus)),
        )
        .skipTraversal;

    expect(traversable('vue'), isTrue);
    expect(traversable('react'), isTrue);
    expect(traversable('svelte'), isTrue);
  });

  testWidgets('every variant renders its options', (tester) async {
    for (final KunCheckBoxGroupVariant variant
        in KunCheckBoxGroupVariant.values) {
      await tester.pumpWidget(
        wrap(
          KunCheckBoxGroup<String>(
            values: const <String>['vue'],
            options: options,
            variant: variant,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vue'), findsOneWidget, reason: variant.name);
      expect(find.text('Svelte'), findsOneWidget, reason: variant.name);
    }
  });

  testWidgets('a chosen box fills in the colour and shows a check',
      (tester) async {
    final KunThemeData theme = KunThemeData.light();
    await tester.pumpWidget(
      wrap(
        const KunCheckBoxGroup<String>(
          values: <String>['vue'],
          options: options,
        ),
      ),
    );
    await tester.pumpAndSettle();

    BoxDecoration boxOf(String value) => tester
        .widget<AnimatedContainer>(
          find.descendant(
            of: option(value),
            matching: find.byType(AnimatedContainer),
          ),
        )
        .decoration! as BoxDecoration;

    expect(boxOf('vue').color, theme.colors.primary.solid);
    expect(boxOf('svelte').color, isNull);
    expect(
      find.descendant(of: option('vue'), matching: find.byIcon(KunIcons.check)),
      findsOneWidget,
    );
  });

  testWidgets('the group names itself and reports each option checked',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        KunCheckBoxGroup<String>(
          values: const <String>['vue'],
          options: options,
          label: 'Frameworks',
          onChanged: (_) {},
        ),
      ),
    );

    expect(
      tester
          .getSemantics(find.byType(KunCheckBoxGroup<String>))
          .getSemanticsData()
          .label,
      'Frameworks',
    );

    final SemanticsData vue =
        tester.getSemantics(find.text('Vue')).getSemanticsData();
    expect(vue.flagsCollection.isChecked, CheckedState.isTrue);

    final SemanticsData svelte =
        tester.getSemantics(find.text('Svelte')).getSemanticsData();
    expect(svelte.flagsCollection.isChecked, CheckedState.isFalse);

    final SemanticsData angular =
        tester.getSemantics(find.text('Angular')).getSemanticsData();
    expect(angular.flagsCollection.isEnabled, Tristate.isFalse);
    semantics.dispose();
  });

  testWidgets('a column of cards stretches to the group width', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunCheckBoxGroup<String>(
          values: <String>['vue'],
          options: options,
          variant: KunCheckBoxGroupVariant.card,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The web's `flex-col` stretches its children; a shrink-wrapped column
    // gave every card the width of its own label.
    for (final String value in <String>['vue', 'react', 'svelte']) {
      expect(tester.getRect(option(value)).width, 400, reason: value);
    }
  });

  testWidgets('an error shows under the group', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunCheckBoxGroup<String>(
          values: <String>[],
          options: options,
          error: 'Pick at least one',
        ),
      ),
    );

    expect(find.text('Pick at least one'), findsOneWidget);
  });
}
