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
    expect(decorationOf(tester).boxShadow!.first.spreadRadius, 0);
    expect(decorationOf(tester).boxShadow!.first.color.a, 0);
    expect(decorationOf(tester).boxShadow!.skip(1), KunShadows.sm);

    await tester.tap(find.byType(KunInput));
    await tester.pump();
    await tester.pump(KunDurations.fast);
    final shadows = decorationOf(tester).boxShadow!;
    expect(shadows.first.spreadRadius, 2);
    expect(shadows.first.blurRadius, 0);
    expect(
      shadows.first.color,
      KunColors.light.primary.solid.withValues(alpha: 0.5),
    );
  });

  testWidgets('field, label, description and error use CSS half-leading',
      (tester) async {
    TextStyle resolved(String text) => (tester
            .widget<RichText>(
              find.descendant(
                of: find.text(text),
                matching: find.byType(RichText),
              ),
            )
            .text as TextSpan)
        .style!;

    await tester.pumpWidget(wrap(const KunInput()));
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText))
          .style
          .leadingDistribution,
      TextLeadingDistribution.even,
    );

    await tester.pumpWidget(wrap(const KunInput(label: 'Name')));
    expect(resolved('Name').fontSize, 14);
    expect(resolved('Name').height, 20 / 14);
    expect(resolved('Name').leadingDistribution, TextLeadingDistribution.even);

    await tester.pumpWidget(
      wrap(const KunInput(description: 'Helper')),
    );
    expect(resolved('Helper').fontSize, 14);
    expect(resolved('Helper').height, 20 / 14);
    expect(
      resolved('Helper').leadingDistribution,
      TextLeadingDistribution.even,
    );

    await tester.pumpWidget(wrap(const KunInput(error: 'Required')));
    expect(resolved('Required').fontSize, 14);
    expect(resolved('Required').height, 20 / 14);
    expect(
      resolved('Required').leadingDistribution,
      TextLeadingDistribution.even,
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

  testWidgets("the clear button's accessible name comes from the catalog",
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      wrap(const KunInput(value: 'text', isClearable: true)),
    );
    expect(
      find.bySemanticsLabel(KunMessages.zhCN.input.clear),
      findsOneWidget,
    );

    await tester.pumpWidget(
      wrap(
        const KunMessagesScope(
          messages: KunMessages.en,
          child: KunInput(value: 'text', isClearable: true),
        ),
      ),
    );
    expect(find.bySemanticsLabel(KunMessages.en.input.clear), findsOneWidget);
    expect(find.bySemanticsLabel(KunMessages.zhCN.input.clear), findsNothing);

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
    expect(
      find.bySemanticsLabel(KunMessages.zhCN.input.reveal),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel(KunMessages.zhCN.input.reveal));
    await tester.pump();
    expect(find.bySemanticsLabel(KunMessages.zhCN.input.hide), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('a tap places the caret', (tester) async {
    await tester.pumpWidget(wrap(const KunInput(value: 'hello world')));
    final editable = find.byType(EditableText);
    await tester.tapAt(tester.getTopLeft(editable) + const Offset(2, 5));
    await tester.pump();
    expect(
      tester.widget<EditableText>(editable).controller.selection,
      const TextSelection.collapsed(offset: 0),
    );

    await tester.tapAt(tester.getTopRight(editable) - const Offset(2, -5));
    await tester.pump();
    final end = tester.widget<EditableText>(editable).controller.selection;
    expect(end.isCollapsed, isTrue);
    expect(end.baseOffset, 11);
  });

  testWidgets('a mouse drag selects', (tester) async {
    await tester.pumpWidget(wrap(const KunInput(value: 'hello world')));
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
    final selection = tester
        .widget<EditableText>(find.byType(EditableText))
        .controller
        .selection;
    expect(selection.isCollapsed, isFalse);
    expect(selection.start, 0);
  });

  testWidgets('disabled cannot take focus', (tester) async {
    await tester.pumpWidget(wrap(const KunInput(disabled: true)));
    final focus =
        tester.widget<EditableText>(find.byType(EditableText)).focusNode;
    expect(focus.canRequestFocus, isFalse);
    await tester.tap(find.byType(KunInput));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  });

  testWidgets('the ring fades in', (tester) async {
    await tester.pumpWidget(wrap(const KunInput()));
    expect(decorationOf(tester).boxShadow!.first.spreadRadius, 0);

    await tester.tap(find.byType(KunInput));
    await tester.pump();
    expect(decorationOf(tester).boxShadow!.first.spreadRadius, 0);

    await tester.pump(KunDurations.fast);
    expect(decorationOf(tester).boxShadow!.first.spreadRadius, 2);
    expect(
      decorationOf(tester).boxShadow!.first.color.a,
      moreOrLessEquals(0.5),
    );
  });

  testWidgets('assistive technology sees an enabled text field',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrap(const KunInput()));
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

    await tester.pumpWidget(wrap(const KunInput(disabled: true)));
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

  testWidgets('IME composing does not call onChanged until commit',
      (tester) async {
    final seen = <String>[];
    await tester.pumpWidget(wrap(KunInput(onChanged: seen.add)));
    await tester.tap(find.byType(EditableText));
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    expect(seen, isEmpty);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'ni',
    );

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '你',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(seen, ['你']);
  });

  testWidgets('ending composition without a text change reports once',
      (tester) async {
    final seen = <String>[];
    await tester.pumpWidget(wrap(KunInput(onChanged: seen.add)));
    await tester.tap(find.byType(EditableText));
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    expect(seen, isEmpty);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pump();
    expect(seen, ['ni']);
  });

  testWidgets('a parent rebuild during composition keeps the composing text',
      (tester) async {
    final seen = <String>[];
    final host = GlobalKey<_ComposeHostState>();
    await tester.pumpWidget(
      wrap(_ComposeHost(key: host, onChanged: seen.add)),
    );
    await tester.tap(find.byType(EditableText));
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    host.currentState!.bump();
    await tester.pump();
    expect(seen, isEmpty);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'ni',
    );
  });

  testWidgets('plain typing still calls onChanged once per edit',
      (tester) async {
    final seen = <String>[];
    await tester.pumpWidget(wrap(KunInput(onChanged: seen.add)));
    await tester.enterText(find.byType(EditableText), 'k');
    await tester.enterText(find.byType(EditableText), 'ku');
    expect(seen, ['k', 'ku']);
  });

  testWidgets('the clear button still reports an empty string', (tester) async {
    final seen = <String>[];
    await tester.pumpWidget(
      wrap(
        KunInput(
          value: 'kun',
          isClearable: true,
          onChanged: seen.add,
        ),
      ),
    );
    await tester.tap(find.byIcon(KunIcons.circleX));
    expect(seen, ['']);
  });
}

class _ComposeHost extends StatefulWidget {
  const _ComposeHost({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_ComposeHost> createState() => _ComposeHostState();
}

class _ComposeHostState extends State<_ComposeHost> {
  void bump() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return KunInput(onChanged: widget.onChanged);
  }
}
