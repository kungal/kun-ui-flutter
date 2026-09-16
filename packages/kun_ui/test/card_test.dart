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

BoxDecoration decorationOf(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(of: find.byType(KunCard), matching: find.byType(Container))
        .first,
  );
  return container.decoration! as BoxDecoration;
}

const body = SizedBox(width: 100, height: 40, key: ValueKey('body'));

// Flutter web's activation bindings. The VM's WidgetsApp.defaultShortcuts
// send Enter as ActivateIntent too, which hid that a browser's Enter did
// nothing on a KunButton.
Widget wrapWebKeys(Widget child) => Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
      },
      child: wrap(child),
    );

void main() {
  testWidgets('the padding scale matches the web', (tester) async {
    const paddings = {
      KunCardPadding.none: 0.0,
      KunCardPadding.sm: 12.0,
      KunCardPadding.md: 20.0,
      KunCardPadding.lg: 24.0,
    };
    for (final entry in paddings.entries) {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 300,
            child: KunCard(padding: entry.key, child: body),
          ),
        ),
      );
      // Width is the parent's — a card fills its container, as the web's
      // block-level div does. Height is what the padding scale decides.
      expect(
        tester.getSize(find.byType(KunCard)).height,
        40 + entry.value * 2 + 2, // content + padding + the 1px border
        reason: 'padding ${entry.key.name}',
      );
    }
  });

  testWidgets('the default card is the raised content1 surface',
      (tester) async {
    await tester.pumpWidget(wrap(const KunCard(child: body)));
    final decoration = decorationOf(tester);
    expect(decoration.color, KunColors.light.content1);
    expect(decoration.boxShadow, KunShadows.sm);
    expect(
      (decoration.border! as Border).top.color,
      KunColors.light.neutral.shade100,
    );
  });

  testWidgets('a tinted card takes the 100 shade at 30% and a 300 border',
      (tester) async {
    await tester.pumpWidget(
      wrap(const KunCard(color: KunUIColor.primary, child: body)),
    );
    final decoration = decorationOf(tester);
    expect(
      decoration.color,
      KunColors.light.primary.shade100.withValues(alpha: 0.3),
    );
    expect(
      (decoration.border! as Border).top.color,
      KunColors.light.primary.shade300,
    );
  });

  testWidgets('isTransparent drops the fill and the shadow', (tester) async {
    await tester.pumpWidget(
      wrap(const KunCard(isTransparent: true, child: body)),
    );
    final decoration = decorationOf(tester);
    expect(decoration.color, isNull);
    expect(decoration.boxShadow, isNull);
    expect(decoration.border, isNotNull); // bordered is independent
  });

  testWidgets('bordered false drops the outline', (tester) async {
    await tester.pumpWidget(wrap(const KunCard(bordered: false, child: body)));
    expect(decorationOf(tester).border, isNull);
  });

  testWidgets('onTap fires on a plain card, as the web click does',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(KunCard(onTap: () => taps++, child: body)),
    );
    await tester.tap(find.byType(KunCard));
    expect(taps, 1);
  });

  testWidgets('clickable marks the card a button for assistive tech',
      (tester) async {
    await tester.pumpWidget(wrap(const KunCard(child: body)));
    expect(
      tester.getSemantics(find.byType(KunCard)).flagsCollection.isButton,
      isFalse,
    );

    await tester.pumpWidget(wrap(const KunCard(clickable: true, child: body)));
    expect(
      tester.getSemantics(find.byType(KunCard)).flagsCollection.isButton,
      isTrue,
    );
  });

  testWidgets('the slots stack header, cover, body, footer', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 300,
          child: KunCard(
            header: Text('header'),
            cover: SizedBox(height: 20),
            footer: Text('footer'),
            child: Text('body'),
          ),
        ),
      ),
    );
    final header = tester.getCenter(find.text('header')).dy;
    final bodyY = tester.getCenter(find.text('body')).dy;
    final footer = tester.getCenter(find.text('footer')).dy;
    expect(header, lessThan(bodyY));
    expect(bodyY, lessThan(footer));
  });
  testWidgets('a clickable card takes focus and Space or Enter taps it',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrapWebKeys(
        KunCard(clickable: true, onTap: () => taps++, child: const Text('go')),
      ),
    );
    final node = Focus.of(tester.element(find.text('go')));
    expect(node.canRequestFocus, isTrue);
    node.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 2);

    await tester.pumpWidget(
      wrapWebKeys(KunCard(onTap: () => taps++, child: const Text('static'))),
    );
    expect(
        Focus.of(tester.element(find.text('static'))).canRequestFocus, isFalse);
  });
}
