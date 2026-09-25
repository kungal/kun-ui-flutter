import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

ScrollbarPainter painterOf(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((CustomPaint paint) => paint.foregroundPainter)
      .whereType<ScrollbarPainter>()
      .single;
}

Widget harness(ScrollController controller) {
  return KunTheme(
    data: KunThemeData.light(),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: KunScrollbar(
          controller: controller,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: controller,
            child: const SizedBox(height: 2000),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('an 8px fully rounded thumb in neutral 300', (tester) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    final ScrollbarPainter painter = painterOf(tester);
    final KunColorScheme scheme = KunThemeData.light().colors;
    expect(painter.thickness, 8);
    expect(painter.radius, const Radius.circular(4));
    expect(painter.color, scheme.neutral.shade300);
    expect(painter.trackColor, const Color(0x00000000));
  });

  testWidgets('hovering the thumb turns it neutral 400', (tester) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    final KunColorScheme scheme = KunThemeData.light().colors;
    final TestGesture mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(200, 200));
    await tester.pump();
    expect(painterOf(tester).color, scheme.neutral.shade300);

    await mouse.moveTo(const Offset(796, 20));
    await tester.pump();
    expect(painterOf(tester).color, scheme.neutral.shade400);

    await mouse.moveTo(const Offset(200, 200));
    await tester.pump();
    expect(painterOf(tester).color, scheme.neutral.shade300);
  });
}
