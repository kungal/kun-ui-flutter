import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/focus_outline.dart';

Widget harness({
  required bool visible,
  double offset = 2,
  BorderRadius borderRadius = BorderRadius.zero,
  bool circle = false,
  Size size = const Size(80, 40),
  Color? color,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox.fromSize(
        size: size,
        child: KunFocusOutline(
          visible: visible,
          color: color ?? KunColors.light.primary.solid,
          offset: offset,
          borderRadius: borderRadius,
          circle: circle,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

RenderObject painterOf(WidgetTester tester) {
  return tester.renderObject(
    find.descendant(
      of: find.byType(KunFocusOutline),
      matching: find.byType(CustomPaint),
    ),
  );
}

void main() {
  testWidgets('nothing is painted when not visible', (tester) async {
    await tester.pumpWidget(harness(visible: false));
    expect(painterOf(tester), paintsNothing);
  });

  testWidgets('offset 2 paints a 2px band outside the child', (tester) async {
    const Color color = Color.fromRGBO(0, 0, 255, 1);
    await tester.pumpWidget(
      harness(
        visible: true,
        offset: 2,
        borderRadius: BorderRadius.circular(KunRounded.lg),
        color: color,
      ),
    );
    const Rect inner = Rect.fromLTWH(-2, -2, 84, 44);
    const Rect outer = Rect.fromLTWH(-4, -4, 88, 48);
    expect(
      painterOf(tester),
      paints
        ..drrect(
          outer: RRect.fromRectAndRadius(outer, const Radius.circular(12)),
          inner: RRect.fromRectAndRadius(inner, const Radius.circular(10)),
          color: color,
          style: PaintingStyle.fill,
        ),
    );
  });

  testWidgets('offset -2 paints a 2px inset band', (tester) async {
    const Color color = Color.fromRGBO(0, 0, 255, 1);
    await tester.pumpWidget(
      harness(
        visible: true,
        offset: -2,
        borderRadius: BorderRadius.circular(KunRounded.lg),
        color: color,
      ),
    );
    const Rect inner = Rect.fromLTWH(2, 2, 76, 36);
    const Rect outer = Rect.fromLTWH(0, 0, 80, 40);
    expect(
      painterOf(tester),
      paints
        ..drrect(
          outer: RRect.fromRectAndRadius(outer, const Radius.circular(8)),
          inner: RRect.fromRectAndRadius(inner, const Radius.circular(6)),
          color: color,
          style: PaintingStyle.fill,
        ),
    );
  });

  testWidgets('circle paints concentric circular edges', (tester) async {
    const Color color = Color.fromRGBO(0, 0, 255, 1);
    await tester.pumpWidget(
      harness(
        visible: true,
        circle: true,
        size: const Size(24, 24),
        color: color,
      ),
    );
    const Rect inner = Rect.fromLTWH(-2, -2, 28, 28);
    const Rect outer = Rect.fromLTWH(-4, -4, 32, 32);
    expect(
      painterOf(tester),
      paints
        ..drrect(
          outer: RRect.fromRectAndRadius(outer, const Radius.circular(16)),
          inner: RRect.fromRectAndRadius(inner, const Radius.circular(14)),
          color: color,
          style: PaintingStyle.fill,
        ),
    );
  });
}
