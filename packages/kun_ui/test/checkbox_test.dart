import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

Finder get box => find.byType(AnimatedContainer);

BoxDecoration decoration(WidgetTester tester) =>
    tester.widget<AnimatedContainer>(box).decoration! as BoxDecoration;

void main() {
  testWidgets('a tap reports the new state', (tester) async {
    bool? reported;
    await tester.pumpWidget(
      wrap(
        KunCheckBox(
          label: 'Remember me',
          onChanged: (bool value) => reported = value,
        ),
      ),
    );

    await tester.tap(find.text('Remember me'));
    expect(reported, isTrue);
  });

  testWidgets('Space toggles a focused checkbox', (tester) async {
    bool? reported;
    await tester.pumpWidget(
      wrap(KunCheckBox(onChanged: (bool value) => reported = value)),
    );

    Focus.of(tester.element(box), scopeOk: true).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(reported, isTrue);
  });

  testWidgets('a disabled checkbox never reports and is dimmed',
      (tester) async {
    bool? reported;
    await tester.pumpWidget(
      wrap(
        KunCheckBox(
          label: 'Remember me',
          disabled: true,
          onChanged: (bool value) => reported = value,
        ),
      ),
    );

    await tester.tap(find.text('Remember me'));
    expect(reported, isNull);
    expect(
      tester.widget<Opacity>(find.byType(Opacity).first).opacity,
      0.5,
    );
  });

  testWidgets('a null callback is inert but not dimmed', (tester) async {
    await tester.pumpWidget(wrap(const KunCheckBox(label: 'Remember me')));

    await tester.tap(find.text('Remember me'));
    await tester.pump();
    expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1);
  });

  testWidgets('a null callback does not report the box disabled',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrap(const KunCheckBox(label: 'Remember me')));

    // `disabled` disables; a missing callback only makes it inert. An
    // Android dump caught this reporting enabled=false on a box the app was
    // simply driving from elsewhere.
    expect(
      tester
          .getSemantics(find.byType(KunCheckBox))
          .getSemanticsData()
          .flagsCollection
          .isEnabled,
      Tristate.isTrue,
    );

    await tester.pumpWidget(
      wrap(const KunCheckBox(label: 'Remember me', disabled: true)),
    );
    expect(
      tester
          .getSemantics(find.byType(KunCheckBox))
          .getSemanticsData()
          .flagsCollection
          .isEnabled,
      Tristate.isFalse,
    );
    semantics.dispose();
  });

  testWidgets('the size scale is the shared selection scale', (tester) async {
    for (final KunUISize size in KunUISize.values) {
      await tester.pumpWidget(wrap(KunCheckBox(size: size)));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(box).width,
        KunSelectionMetrics.of(size).box,
        reason: size.name,
      );
    }
  });

  testWidgets('checked fills the box in the colour', (tester) async {
    final KunThemeData theme = KunThemeData.light();
    await tester.pumpWidget(
      wrap(const KunCheckBox(color: KunUIColor.primary)),
    );
    await tester.pumpAndSettle();
    expect(decoration(tester).color, isNull);

    await tester.pumpWidget(
      wrap(const KunCheckBox(value: true, color: KunUIColor.primary)),
    );
    await tester.pumpAndSettle();
    expect(decoration(tester).color, theme.colors.primary.solid);
  });

  testWidgets('indeterminate draws a dash, not a check, and reports mixed',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(const KunCheckBox(indeterminate: true, label: 'All')),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(KunIcons.check), findsNothing);
    expect(decoration(tester).color, isNotNull);
    final SemanticsData data =
        tester.getSemantics(find.byType(KunCheckBox)).getSemanticsData();
    expect(data.flagsCollection.isChecked, CheckedState.mixed);
    semantics.dispose();
  });

  testWidgets('an error replaces the description and turns it danger',
      (tester) async {
    final KunThemeData theme = KunThemeData.light();
    await tester.pumpWidget(
      wrap(const KunCheckBox(description: 'Optional')),
    );
    expect(find.text('Optional'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        const KunCheckBox(description: 'Optional', error: 'Required'),
      ),
    );
    expect(find.text('Optional'), findsNothing);
    expect(
      tester.widget<Text>(find.text('Required')).style!.color,
      theme.colors.danger.solid,
    );
  });

  testWidgets('a single checkbox is a circle, a multiple one a rounded square',
      (tester) async {
    await tester.pumpWidget(
      wrap(const KunCheckBox(type: KunCheckBoxType.single)),
    );
    await tester.pumpAndSettle();
    final double side = KunSelectionMetrics.of(KunUISize.md).box;
    expect(
      (decoration(tester).borderRadius! as BorderRadius).topLeft.x,
      side / 2,
    );

    await tester.pumpWidget(wrap(const KunCheckBox()));
    await tester.pumpAndSettle();
    expect(
      (decoration(tester).borderRadius! as BorderRadius).topLeft.x,
      moreOrLessEquals(side * 0.35, epsilon: 0.01),
    );
  });

  testWidgets('the focus ring shows for a keyboard focus only', (tester) async {
    await tester.pumpWidget(wrap(KunCheckBox(onChanged: (_) {})));
    await tester.pumpAndSettle();
    expect(decoration(tester).boxShadow!.single.spreadRadius, 0);

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    Focus.of(tester.element(box), scopeOk: true).requestFocus();
    await tester.pumpAndSettle();
    expect(decoration(tester).boxShadow!.single.spreadRadius, 2);
  });

  testWidgets('it reports itself checked and enabled', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(KunCheckBox(value: true, label: 'Remember me', onChanged: (_) {})),
    );

    final SemanticsData data =
        tester.getSemantics(find.byType(KunCheckBox)).getSemanticsData();
    expect(data.flagsCollection.isChecked, CheckedState.isTrue);
    expect(data.flagsCollection.isEnabled, Tristate.isTrue);
    expect(data.label, 'Remember me');
    semantics.dispose();
  });
}
