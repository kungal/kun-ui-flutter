import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Widget wrap(Widget child, {required bool reduce}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: KunTheme(
        data: KunThemeData.light(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: child),
        ),
      ),
    );

double opacityOf(WidgetTester tester, Finder of) => tester
    .renderObject<RenderAnimatedOpacity>(
      find.descendant(of: of, matching: find.byType(AnimatedOpacity)).first,
    )
    .opacity
    .value;

BoxShadow ringOf(WidgetTester tester, Type field) {
  final Container box = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(field),
          matching: find.byWidgetPredicate(
            (Widget widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).boxShadow != null,
          ),
        )
        .first,
  );
  return (box.decoration! as BoxDecoration).boxShadow!.first;
}

Future<TestGesture> hover(WidgetTester tester, Finder target) async {
  final TestGesture mouse =
      await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  await mouse.moveTo(tester.getCenter(target));
  return mouse;
}

void main() {
  for (final bool reduce in <bool>[false, true]) {
    final String mode = reduce ? 'reduced motion' : 'full motion';

    testWidgets('$mode: KunButton hover opacity', (tester) async {
      await tester.pumpWidget(
        wrap(KunButton(onPressed: () {}, child: const Text('Go')),
            reduce: reduce),
      );
      await hover(tester, find.text('Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      final double opacity = opacityOf(tester, find.byType(KunButton));
      expect(opacity, reduce ? 0.8 : greaterThan(0.8));
    });

    testWidgets('$mode: KunCard press scale', (tester) async {
      await tester.pumpWidget(
        wrap(
          KunCard(
            clickable: true,
            onTap: () {},
            child: const SizedBox(width: 200, height: 100),
          ),
          reduce: reduce,
        ),
      );
      final Finder content = find.byWidgetPredicate(
        (Widget widget) => widget is SizedBox && widget.width == 200,
      );
      final double contentRest = tester.getRect(content).width;
      final TestGesture press =
          await tester.startGesture(tester.getCenter(find.byType(KunCard)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      final double pressed = tester.getRect(content).width;
      if (reduce) {
        expect(pressed, closeTo(contentRest * 0.97, 0.01));
      } else {
        expect(pressed, greaterThan(contentRest * 0.97 + 0.5));
      }
      await press.up();
      await tester.pumpAndSettle();
    });

    testWidgets('$mode: KunChip remove button hover opacity', (tester) async {
      await tester.pumpWidget(
        wrap(
          KunChip(closable: true, onClose: () {}, child: const Text('Tag')),
          reduce: reduce,
        ),
      );
      await hover(tester, find.byIcon(KunIcons.x));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      final double opacity = opacityOf(tester, find.byType(KunChip));
      expect(opacity, reduce ? 1 : lessThan(1));
    });

    testWidgets('$mode: KunSwitch thumb and track', (tester) async {
      Widget at(bool value) =>
          wrap(KunSwitch(value: value, onChanged: (_) {}), reduce: reduce);
      await tester.pumpWidget(at(false));
      final Finder thumb = find.descendant(
        of: find.byType(AnimatedPositioned),
        matching: find.byType(DecoratedBox),
      );
      final double off = tester.getTopLeft(thumb).dx;
      await tester.pumpWidget(at(true));
      await tester.pump(const Duration(milliseconds: 1));
      final double moved = tester.getTopLeft(thumb).dx - off;
      expect(moved, reduce ? 20 : lessThan(20));
    });

    testWidgets('$mode: KunInput and KunTextarea focus rings', (tester) async {
      for (final Type field in <Type>[KunInput, KunTextarea]) {
        await tester.pumpWidget(
          wrap(
            field == KunInput ? const KunInput() : const KunTextarea(),
            reduce: reduce,
          ),
        );
        await tester.tap(find.byType(field));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        final double spread = ringOf(tester, field).spreadRadius;
        expect(spread, reduce ? 2 : lessThan(2), reason: '$field');
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}
