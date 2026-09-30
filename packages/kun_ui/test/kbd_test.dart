import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/components/kbd.dart' show kunSpeakShortcut;
import 'package:kun_ui/src/foundation/shortcut.dart';

Widget wrap(Widget child, {KunMessages messages = KunMessages.en}) {
  return KunTheme(
    data: KunThemeData.light(),
    child: KunMessagesScope(
      messages: messages,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('keys draw the resolved labels', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(wrap(const KunKbd(keys: 'Mod+K')));
    expect(find.text('Ctrl'), findsOneWidget);
    expect(find.text('K'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Mod is Command on Apple and Ctrl elsewhere', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(wrap(const KunKbd(keys: 'Mod+K')));
    expect(find.text('⌘'), findsOneWidget);
    expect(find.text('K'), findsOneWidget);
    expect(find.text('Ctrl'), findsNothing);

    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(wrap(const KunKbd(keys: 'Mod+K')));
    expect(find.text('Ctrl'), findsOneWidget);
    expect(find.text('⌘'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a child with no keys reads as itself', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrap(const KunKbd(child: Text('Esc'))));
    expect(find.text('Esc'), findsOneWidget);
    expect(tester.getSemantics(find.text('Esc')).label, 'Esc');
    semantics.dispose();
  });

  testWidgets('keys expose one spoken label and hide the glyphs',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      wrap(const KunKbd(keys: 'Mod+Shift+Z')),
    );
    final String spoken = kunSpeakShortcut('Mod+Shift+Z', KunMessages.en);
    expect(spoken, 'Shift Command Z');
    expect(find.bySemanticsLabel(spoken), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(KunKbd)).label,
      spoken,
    );
    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('plain variant draws the one-line form', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      wrap(const KunKbd(keys: 'Mod+Shift+Z', variant: KunKbdVariant.plain)),
    );
    expect(
      find.text(formatKunShortcut('Mod+Shift+Z', KunShortcutPlatform.other)),
      findsOneWidget,
    );
    expect(find.text('Ctrl+Shift+Z'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('keycap size follows the ambient em', (tester) async {
    Future<Size> sizeAt(double fontSize) async {
      await tester.pumpWidget(
        wrap(
          DefaultTextStyle(
            style: TextStyle(fontSize: fontSize),
            child: const KunKbd(keys: 'A'),
          ),
        ),
      );
      return tester.getSize(
        find.descendant(
          of: find.byType(KunKbd),
          matching: find.byType(DecoratedBox),
        ),
      );
    }

    final Size small = await sizeAt(10);
    expect(small.height, 15);
    expect(small.width, greaterThanOrEqualTo(15));

    final Size large = await sizeAt(20);
    expect(large.height, 30);
    expect(large.width, greaterThanOrEqualTo(30));
    expect(large.height, small.height * 2);
  });

  testWidgets('without an ambient font size the em is KunText.sm',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const DefaultTextStyle(
          style: TextStyle(),
          child: KunKbd(keys: 'A'),
        ),
      ),
    );
    final Size size = tester.getSize(
      find.descendant(
        of: find.byType(KunKbd),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(size.height, KunText.sm.fontSize! * 1.5);
  });
}
