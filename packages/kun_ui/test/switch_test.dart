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

Widget wrapKeyboard(Widget child) => KunTheme(
      data: KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Shortcuts(
          shortcuts: WidgetsApp.defaultShortcuts,
          child: Center(child: child),
        ),
      ),
    );

const sizes = <KunUISize,
    ({
  double trackWidth,
  double trackHeight,
  double thumb,
  double onLeft,
})>{
  KunUISize.xs: (trackWidth: 28, trackHeight: 16, thumb: 12, onLeft: 2 + 12),
  KunUISize.sm: (trackWidth: 36, trackHeight: 20, thumb: 16, onLeft: 2 + 16),
  KunUISize.md: (trackWidth: 44, trackHeight: 24, thumb: 20, onLeft: 2 + 20),
  KunUISize.lg: (trackWidth: 56, trackHeight: 28, thumb: 24, onLeft: 2 + 28),
  KunUISize.xl: (trackWidth: 64, trackHeight: 32, thumb: 28, onLeft: 2 + 32),
};

SizedBox trackBox(WidgetTester tester) => tester.widget<SizedBox>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.width != null && widget.height != null,
      ),
    );

AnimatedPositioned thumbOf(WidgetTester tester) =>
    tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned));

Finder get trackFinder => find.byWidgetPredicate(
      (widget) =>
          widget is SizedBox && widget.width != null && widget.height != null,
    );

double thumbLeft(WidgetTester tester) {
  final thumbFinder = find.descendant(
    of: find.byType(AnimatedPositioned),
    matching: find.byType(DecoratedBox),
  );
  return tester.getTopLeft(thumbFinder).dx - tester.getTopLeft(trackFinder).dx;
}

BoxDecoration trackDecoration(WidgetTester tester) {
  final decorations = tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(KunSwitch),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((box) => box.decoration as BoxDecoration);
  return decorations
      .firstWhere((decoration) => decoration.shape != BoxShape.circle);
}

BoxDecoration thumbDecoration(WidgetTester tester) {
  final decorations = tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(KunSwitch),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((box) => box.decoration as BoxDecoration);
  return decorations
      .firstWhere((decoration) => decoration.shape == BoxShape.circle);
}

TextStyle resolvedOf(WidgetTester tester, String text) => (tester
        .widget<RichText>(
          find.descendant(
            of: find.text(text),
            matching: find.byType(RichText),
          ),
        )
        .text as TextSpan)
    .style!;

Focus focusOf(WidgetTester tester) => tester.widget<Focus>(
      find.descendant(
        of: find.byType(KunSwitch),
        matching: find.byType(Focus),
      ),
    );

void main() {
  testWidgets('every size matches the web track, thumb and travel',
      (tester) async {
    for (final entry in sizes.entries) {
      await tester.pumpWidget(
        wrap(
          KunSwitch(
            value: true,
            size: entry.key,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final track = trackBox(tester);
      expect(track.width, entry.value.trackWidth, reason: '${entry.key} width');
      expect(
        track.height,
        entry.value.trackHeight,
        reason: '${entry.key} height',
      );
      final thumb = thumbOf(tester);
      expect(thumb.width, entry.value.thumb, reason: '${entry.key} thumb');
      expect(thumb.height, entry.value.thumb, reason: '${entry.key} thumb h');
      expect(
        thumbLeft(tester),
        entry.value.onLeft,
        reason: '${entry.key} on left',
      );

      await tester.pumpWidget(
        wrap(
          KunSwitch(
            value: false,
            size: entry.key,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(thumbLeft(tester), 2, reason: '${entry.key} off left');
    }
  });

  testWidgets('tapping the label toggles; tapping the description does not',
      (tester) async {
    final seen = <bool>[];
    await tester.pumpWidget(
      wrap(
        KunSwitch(
          value: false,
          onChanged: seen.add,
          label: 'Notify',
          description: 'Helper',
        ),
      ),
    );
    await tester.tap(find.text('Notify'));
    expect(seen, [true]);

    seen.clear();
    await tester.tap(find.text('Helper'));
    expect(seen, isEmpty);
  });

  testWidgets('the value is controlled and the thumb animates when it changes',
      (tester) async {
    final seen = <bool>[];
    await tester.pumpWidget(
      wrap(
        KunSwitch(
          value: false,
          onChanged: seen.add,
          label: 'Notify',
        ),
      ),
    );
    expect(thumbLeft(tester), 2);

    await tester.tap(find.text('Notify'));
    await tester.pump();
    expect(seen, [true]);
    expect(thumbLeft(tester), 2);

    await tester.pumpWidget(
      wrap(
        KunSwitch(
          value: true,
          onChanged: seen.add,
          label: 'Notify',
        ),
      ),
    );
    await tester.pump(KunDurations.fast ~/ 2);
    final mid = thumbLeft(tester);
    expect(mid, greaterThan(2));
    expect(mid, lessThan(22));

    await tester.pump(KunDurations.fast);
    expect(thumbLeft(tester), 22);
  });

  testWidgets('track colours, opacity and thumb colour', (tester) async {
    await tester.pumpWidget(
      wrap(KunSwitch(value: false, onChanged: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(trackDecoration(tester).color, KunColors.light.neutral.shade500);
    expect(find.byType(Opacity), findsNothing);
    expect(thumbDecoration(tester).color, KunColors.white);

    await tester.pumpWidget(
      wrap(KunSwitch(value: true, onChanged: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(trackDecoration(tester).color, KunColors.light.primary.solid);
    expect(find.byType(Opacity), findsNothing);

    await tester.pumpWidget(
      wrap(
        const KunSwitch(value: true, disabled: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(trackDecoration(tester).color, KunColors.light.primary.shade300);
    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(opacity.opacity, 0.5);
    expect(
      find.descendant(
        of: find.byType(AnimatedPositioned),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    expect(thumbDecoration(tester).color, KunColors.white);
  });

  testWidgets('disabled blocks taps, greys the label and is not focusable',
      (tester) async {
    final seen = <bool>[];
    await tester.pumpWidget(
      wrap(
        KunSwitch(
          value: false,
          disabled: true,
          onChanged: seen.add,
          label: 'Notify',
        ),
      ),
    );
    await tester.tap(find.text('Notify'), warnIfMissed: false);
    expect(seen, isEmpty);
    expect(
      resolvedOf(tester, 'Notify').color,
      KunColors.light.neutral.shade400,
    );
    expect(focusOf(tester).canRequestFocus, isFalse);
  });

  testWidgets('a null onChanged does nothing and does not grey the switch out',
      (tester) async {
    await tester.pumpWidget(
      wrap(const KunSwitch(value: false, label: 'Notify')),
    );
    await tester.tap(find.text('Notify'), warnIfMissed: false);
    expect(find.byType(Opacity), findsNothing);
    expect(
      resolvedOf(tester, 'Notify').color,
      KunColors.light.foreground,
    );
  });

  testWidgets('keyboard activation toggles and paints the focus ring',
      (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() {
      FocusManager.instance.highlightStrategy = previous;
    });

    final seen = <bool>[];
    await tester.pumpWidget(
      wrapKeyboard(
        KunSwitch(
          value: false,
          onChanged: seen.add,
          label: 'Notify',
        ),
      ),
    );
    await tester.pump();
    expect(trackDecoration(tester).boxShadow, isNull);

    final node = Focus.of(tester.element(find.byType(GestureDetector)));
    node.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(seen, [true]);

    final ring = trackDecoration(tester).boxShadow!.single;
    expect(ring.spreadRadius, 2);
    expect(
      ring.color,
      KunColors.light.primary.solid.withValues(alpha: 0.5),
    );
  });

  testWidgets('a mouse tap does not show the ring under the touch strategy',
      (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    addTearDown(() {
      FocusManager.instance.highlightStrategy = previous;
    });

    await tester.pumpWidget(
      wrap(
        KunSwitch(
          value: false,
          onChanged: (_) {},
          label: 'Notify',
        ),
      ),
    );
    await tester.tap(find.text('Notify'));
    await tester.pump();
    expect(trackDecoration(tester).boxShadow, isNull);
  });

  testWidgets('error hides description; both use the sm type size',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        KunSwitch(
          value: false,
          onChanged: (_) {},
          error: 'Required',
          description: 'Helper',
        ),
      ),
    );
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Helper'), findsNothing);
    expect(
      resolvedOf(tester, 'Required').color,
      KunColors.light.danger.solid,
    );
    expect(resolvedOf(tester, 'Required').fontSize, KunText.sm.fontSize);

    await tester.pumpWidget(
      wrap(
        KunSwitch(
          value: false,
          onChanged: (_) {},
          description: 'Helper',
        ),
      ),
    );
    expect(find.text('Helper'), findsOneWidget);
    expect(
      resolvedOf(tester, 'Helper').color,
      KunColors.light.neutral.shade500,
    );
    expect(resolvedOf(tester, 'Helper').fontSize, KunText.sm.fontSize);
  });

  testWidgets('assistive technology sees a switch', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        KunSwitch(
          value: true,
          onChanged: (_) {},
          label: 'Notify',
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(MergeSemantics)),
      isSemantics(
        label: 'Notify',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    await tester.pumpWidget(
      wrap(
        const KunSwitch(
          value: true,
          disabled: true,
          label: 'Notify',
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(MergeSemantics)),
      isSemantics(
        label: 'Notify',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    semantics.dispose();
  });
}
