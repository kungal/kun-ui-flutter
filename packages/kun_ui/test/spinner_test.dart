import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

void main() {
  testWidgets('spins one turn per 750ms and honours size', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: KunSpinner(size: 32)),
      ),
    );
    expect(tester.getSize(find.byType(KunSpinner)), const Size.square(32));

    CustomPaint paintWidget() => tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(KunSpinner),
            matching: find.byType(CustomPaint),
          ),
        );
    final before = paintWidget().painter;
    await tester.pump(const Duration(milliseconds: 375));
    final after = paintWidget().painter;
    expect(identical(before, after), isFalse);
    expect(before!.shouldRepaint(after!), isTrue);
  });

  testWidgets('takes the ambient IconTheme color', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: IconTheme(
          data: IconThemeData(color: Color(0xFF123456)),
          child: Center(child: KunSpinner()),
        ),
      ),
    );
    // No KunTheme ancestor on purpose: the spinner must work standalone.
    expect(tester.takeException(), isNull);
  });
}
