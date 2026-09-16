import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(Widget child) => KunTheme(
      data: KunThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          key: UniqueKey(),
          initialEntries: [
            OverlayEntry(
              builder: (context) =>
                  Center(child: SizedBox(width: 300, child: child)),
            ),
          ],
        ),
      ),
    );

Finder get boxFinder => find
    .descendant(of: find.byType(KunTextarea), matching: find.byType(Container))
    .first;

BoxDecoration decorationOf(WidgetTester tester) =>
    tester.widget<Container>(boxFinder).decoration! as BoxDecoration;

EditableText editableOf(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText));

TextStyle resolved(WidgetTester tester, String text) => (tester
        .widget<RichText>(
          find.descendant(
            of: find.text(text),
            matching: find.byType(RichText),
          ),
        )
        .text as TextSpan)
    .style!;

const tenLines = '0\n1\n2\n3\n4\n5\n6\n7\n8\n9';

void main() {
  testWidgets('every size uses KunControlMetrics.of(size)', (tester) async {
    for (final size in KunUISize.values) {
      final metrics = KunControlMetrics.of(size);
      await tester.pumpWidget(wrap(KunTextarea(size: size)));
      expect(
        tester.widget<Container>(boxFinder).padding,
        EdgeInsets.symmetric(
          horizontal: metrics.horizontalPadding,
          vertical: metrics.verticalPadding,
        ),
        reason: size.name,
      );
      final style = editableOf(tester).style;
      expect(style.fontSize, metrics.textStyle.fontSize, reason: size.name);
      expect(style.height, metrics.textStyle.height, reason: size.name);
      expect(
        style.leadingDistribution,
        metrics.textStyle.leadingDistribution,
        reason: size.name,
      );
    }
  });

  testWidgets('default rows is 4 and the md box is 98 tall', (tester) async {
    await tester.pumpWidget(wrap(const KunTextarea()));
    expect(editableOf(tester).minLines, 4);
    expect(editableOf(tester).maxLines, 4);
    expect(tester.getSize(boxFinder).height, 98);

    await tester.pumpWidget(wrap(const KunTextarea(rows: 2)));
    expect(tester.getSize(boxFinder).height, 58);
  });

  testWidgets('autoGrow grows, caps at maxHeight, and ignores it when off',
      (tester) async {
    await tester.pumpWidget(wrap(const KunTextarea(autoGrow: true)));
    expect(editableOf(tester).maxLines, isNull);

    await tester.enterText(find.byType(EditableText), tenLines);
    await tester.pump();
    expect(tester.getSize(boxFinder).height, greaterThan(98));

    await tester.pumpWidget(
      wrap(const KunTextarea(autoGrow: true, maxHeight: 100, value: tenLines)),
    );
    expect(tester.getSize(boxFinder).height, 100);

    await tester.pumpWidget(
      wrap(const KunTextarea(maxHeight: 50)),
    );
    expect(tester.getSize(boxFinder).height, 98);
  });

  testWidgets('the value is controlled by the parent', (tester) async {
    final seen = <String>[];
    await tester.pumpWidget(wrap(KunTextarea(onChanged: seen.add)));
    await tester.enterText(find.byType(EditableText), 'kun');
    expect(seen, ['kun']);

    await tester.pumpWidget(wrap(const KunTextarea(value: 'one')));
    expect(find.text('one'), findsOneWidget);
    await tester.pumpWidget(wrap(const KunTextarea(value: 'two')));
    expect(find.text('two'), findsOneWidget);
    expect(find.text('one'), findsNothing);
  });

  testWidgets('maxLength truncates input', (tester) async {
    final seen = <String>[];
    await tester.pumpWidget(
      wrap(KunTextarea(maxLength: 3, onChanged: seen.add)),
    );
    await tester.enterText(find.byType(EditableText), 'abcdef');
    expect(seen, ['abc']);
  });

  testWidgets('showCharCount overlays the grapheme length', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunTextarea(
          maxLength: 10,
          showCharCount: true,
          value: 'ab👍',
        ),
      ),
    );
    expect(find.text('3/10'), findsOneWidget);
    expect(resolved(tester, '3/10').fontSize, KunText.xs.fontSize);
    expect(resolved(tester, '3/10').color, KunColors.light.neutral.shade500);

    await tester.pumpWidget(
      wrap(
        const KunTextarea(
          maxLength: 10,
          value: 'ab👍',
        ),
      ),
    );
    expect(find.text('3/10'), findsNothing);
  });

  testWidgets('without maxLength the count stands alone and nothing caps',
      (tester) async {
    final seen = <String>[];
    await tester.pumpWidget(
      wrap(
        KunTextarea(
          showCharCount: true,
          value: 'ab👍',
          onChanged: seen.add,
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);

    final long = 'k' * 100010;
    await tester.enterText(find.byType(EditableText), long);
    expect(seen.single.length, long.length);
  });

  testWidgets('disabled is read-only, unfocusable, dimmed and unshadowed',
      (tester) async {
    await tester.pumpWidget(
      wrap(const KunTextarea(disabled: true, value: 'locked')),
    );
    await tester.pump(KunDurations.fast);
    expect(editableOf(tester).readOnly, isTrue);
    expect(editableOf(tester).focusNode.canRequestFocus, isFalse);

    await tester.tap(find.byType(KunTextarea));
    await tester.pump();
    expect(editableOf(tester).focusNode.hasFocus, isFalse);

    expect(
      tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(KunTextarea),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      0.6,
    );
    expect(
      decorationOf(tester).boxShadow,
      isNot(contains(KunShadows.sm.single)),
    );
    expect(editableOf(tester).style.color, KunColors.light.neutral.shade500);
  });

  testWidgets('readOnly focuses and rings without dimming', (tester) async {
    await tester.pumpWidget(
      wrap(const KunTextarea(readOnly: true, value: 'fixed')),
    );
    expect(editableOf(tester).readOnly, isTrue);
    expect(
      find.descendant(
        of: find.byType(KunTextarea),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );

    await tester.tap(find.byType(KunTextarea));
    await tester.pump();
    await tester.pump(KunDurations.fast);
    expect(editableOf(tester).focusNode.hasFocus, isTrue);
    expect(decorationOf(tester).boxShadow!.first.spreadRadius, 2);
  });

  testWidgets('error takes the border, ring and helper slot', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KunTextarea(
          description: 'Helper',
          error: 'Required',
        ),
      ),
    );
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Helper'), findsNothing);
    expect(
      (decorationOf(tester).border! as Border).top.color,
      KunColors.light.danger.shade300,
    );

    await tester.tap(find.byType(KunTextarea));
    await tester.pump();
    await tester.pump(KunDurations.fast);
    final ring = decorationOf(tester).boxShadow!.first;
    expect(ring.spreadRadius, 2);
    expect(
      ring.color,
      KunColors.light.danger.solid.withValues(alpha: 0.5),
    );
  });

  testWidgets('the required marker sits after a 4px gap', (tester) async {
    await tester.pumpWidget(
      wrap(const KunTextarea(label: 'Name', required: true)),
    );
    final root = tester
        .widget<RichText>(
          find
              .descendant(
                of: find.byType(KunTextarea),
                matching: find.byType(RichText),
              )
              .first,
        )
        .text as TextSpan;
    final span = root.children!.single as TextSpan;
    expect(span.text, 'Name');
    expect(span.children, hasLength(3));
    expect((span.children![0] as TextSpan).text, ' ');
    final gap = span.children![1] as WidgetSpan;
    expect((gap.child as SizedBox).width, KunSpacing.unit);
    final star = span.children![2] as TextSpan;
    expect(star.text, '*');
    expect(star.style!.color, KunColors.light.danger.solid);
  });

  testWidgets('the ring fades and a border change is immediate',
      (tester) async {
    String? error;
    late StateSetter setError;
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            setError = setState;
            return KunTextarea(error: error);
          },
        ),
      ),
    );
    expect(decorationOf(tester).boxShadow!.first.spreadRadius, 0);

    await tester.tap(find.byType(KunTextarea));
    await tester.pump();
    expect(decorationOf(tester).boxShadow!.first.spreadRadius, 0);

    await tester.pump(KunDurations.fast);
    expect(decorationOf(tester).boxShadow!.first.spreadRadius, 2);
    expect(
      decorationOf(tester).boxShadow!.first.color.a,
      moreOrLessEquals(0.5),
    );

    editableOf(tester).focusNode.unfocus();
    await tester.pump();
    expect(decorationOf(tester).boxShadow!.first.spreadRadius, 2);

    await tester.pump(KunDurations.fast);
    expect(decorationOf(tester).boxShadow!.first.spreadRadius, 0);

    await tester.tap(find.byType(KunTextarea));
    await tester.pump();
    await tester.pump(KunDurations.fast);
    setError(() => error = 'Required');
    await tester.pump();
    expect(
      (decorationOf(tester).border! as Border).top.color,
      KunColors.light.danger.shade300,
    );
  });

  testWidgets('a tap places the caret', (tester) async {
    await tester.pumpWidget(
      wrap(const KunTextarea(value: 'hello world')),
    );
    final editable = find.byType(EditableText);
    await tester.tapAt(tester.getTopLeft(editable) + const Offset(2, 5));
    await tester.pump();
    expect(
      editableOf(tester).controller.selection,
      const TextSelection.collapsed(offset: 0),
    );

    await tester.tapAt(tester.getTopRight(editable) - const Offset(2, -5));
    await tester.pump();
    expect(editableOf(tester).controller.selection.isCollapsed, isTrue);
    expect(editableOf(tester).controller.selection.baseOffset, 11);
  });

  testWidgets('a mouse drag selects', (tester) async {
    await tester.pumpWidget(
      wrap(const KunTextarea(value: 'hello world')),
    );
    final start =
        tester.getTopLeft(find.byType(EditableText)) + const Offset(2, 5);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    final selection = editableOf(tester).controller.selection;
    expect(selection.isCollapsed, isFalse);
    expect(selection.start, 0);
  });

  testWidgets('onFocus then onBlur fire once each', (tester) async {
    final events = <String>[];
    await tester.pumpWidget(
      wrap(
        KunTextarea(
          onFocus: () => events.add('focus'),
          onBlur: () => events.add('blur'),
        ),
      ),
    );
    await tester.tap(find.byType(KunTextarea));
    await tester.pump();
    expect(events, ['focus']);
    editableOf(tester).focusNode.unfocus();
    await tester.pump();
    expect(events, ['focus', 'blur']);
  });

  testWidgets('the placeholder shows only while empty', (tester) async {
    await tester.pumpWidget(
      wrap(const KunTextarea(placeholder: 'Write')),
    );
    expect(find.text('Write'), findsOneWidget);
    expect(resolved(tester, 'Write').color, KunColors.light.neutral.shade400);

    await tester.pumpWidget(
      wrap(const KunTextarea(value: 'kun', placeholder: 'Write')),
    );
    expect(find.text('Write'), findsNothing);
  });

  testWidgets(
    'hides the scrollbar a multiline EditableText adds on desktop',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              const KunTextarea(value: tenLines),
              EditableText(
                controller: TextEditingController(text: tenLines),
                focusNode: FocusNode(),
                style: KunText.sm,
                cursorColor: KunColors.light.foreground,
                backgroundCursorColor: KunColors.light.neutral.shade300,
                maxLines: 2,
              ),
            ],
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(KunTextarea),
          matching: find.byType(RawScrollbar),
        ),
        findsNothing,
      );
      expect(find.byType(RawScrollbar), findsOneWidget);
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets('assistive technology sees an enabled text field',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrap(const KunTextarea()));
    expect(
      tester.getSemantics(find.byType(EditableText)),
      isSemantics(
        isTextField: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    await tester.pumpWidget(wrap(const KunTextarea(disabled: true)));
    expect(
      tester.getSemantics(find.byType(EditableText)),
      isSemantics(
        isTextField: true,
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    semantics.dispose();
  });
}
