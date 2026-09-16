import 'package:flutter/gestures.dart';
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
  testWidgets('tap fires onPressed', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      wrap(
        KunButton(onPressed: () => presses++, child: const Text('Save')),
      ),
    );
    await tester.tap(find.text('Save'));
    expect(presses, 1);
  });

  testWidgets('disabled and loading block presses', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      wrap(
        KunButton(
          disabled: true,
          onPressed: () => presses++,
          child: const Text('Save'),
        ),
      ),
    );
    await tester.tap(find.text('Save'), warnIfMissed: false);
    expect(presses, 0);

    await tester.pumpWidget(
      wrap(
        KunButton(
          loading: true,
          onPressed: () => presses++,
          child: const Text('Save'),
        ),
      ),
    );
    await tester.tap(find.text('Save'), warnIfMissed: false);
    expect(presses, 0);
    expect(find.byType(KunSpinner), findsOneWidget);
  });

  testWidgets('the control scale produces the web heights', (tester) async {
    const heights = {
      KunUISize.xs: 26.0,
      KunUISize.sm: 34.0,
      KunUISize.md: 38.0,
      KunUISize.lg: 46.0,
      KunUISize.xl: 54.0,
    };
    for (final entry in heights.entries) {
      await tester.pumpWidget(
        wrap(
          KunButton(
            size: entry.key,
            onPressed: () {},
            child: const Text('Save'),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(KunButton)).height,
        entry.value,
        reason: '${entry.key} text button height',
      );

      await tester.pumpWidget(
        wrap(
          KunButton(
            size: entry.key,
            isIconOnly: true,
            semanticLabel: 'close',
            onPressed: () {},
            child: const Icon(KunIcons.x),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(KunButton)),
        Size.square(entry.value),
        reason: '${entry.key} icon-only square',
      );
    }
  });

  testWidgets('md label uses text-sm with CSS half-leading', (tester) async {
    await tester.pumpWidget(
      wrap(KunButton(onPressed: () {}, child: const Text('Save'))),
    );
    final style = (tester
            .widget<RichText>(
              find.descendant(
                of: find.byType(KunButton),
                matching: find.byType(RichText),
              ),
            )
            .text as TextSpan)
        .style!;
    expect(style.fontSize, 14);
    expect(style.height, 20 / 14);
    expect(style.leadingDistribution, TextLeadingDistribution.even);
  });

  testWidgets('solid primary paints the token fill', (tester) async {
    await tester.pumpWidget(
      wrap(KunButton(onPressed: () {}, child: const Text('Save'))),
    );
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(KunButton),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, KunColors.light.primary.solid);
  });

  testWidgets('fullWidth stretches to the parent', (tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 300,
          child: KunButton(
            fullWidth: true,
            onPressed: () {},
            child: const Text('Save'),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(KunButton)).width, 300);
  });

  testWidgets('hover swaps the light variant to its tint', (tester) async {
    await tester.pumpWidget(
      wrap(
        KunButton(
          variant: KunUIVariant.light,
          onPressed: () {},
          child: const Text('Save'),
        ),
      ),
    );
    BoxDecoration decoration() => tester
        .widget<Container>(
          find.descendant(
            of: find.byType(KunButton),
            matching: find.byType(Container),
          ),
        )
        .decoration! as BoxDecoration;
    expect(decoration().color, const Color(0x00000000));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(KunButton)));
    await tester.pumpAndSettle();
    expect(
      decoration().color,
      KunColors.light.primary.solid.withValues(alpha: 0.2),
    );
  });
  testWidgets('Space and web Enter press a focused button', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      wrapWebKeys(
        KunButton(onPressed: () => presses++, child: const Text('Save')),
      ),
    );
    Focus.of(tester.element(find.text('Save'))).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(presses, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(presses, 2);
  });
}
