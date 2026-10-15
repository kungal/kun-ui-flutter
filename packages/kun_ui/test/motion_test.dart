import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:kun_ui/src/foundation/motion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a surface decelerates in and accelerates out, as on the web', () {
    final AnimationController controller = AnimationController(
      vsync: const TestVSync(),
      duration: KunDurations.base,
    );
    final CurvedAnimation curve = kunSurfaceCurve(controller);
    addTearDown(() {
      curve.dispose();
      controller.dispose();
    });

    controller.forward();
    controller.value = 0.5;
    expect(curve.value, closeTo(KunEasing.enter.transform(0.5), 1e-9));

    controller.reverse(from: 1);
    controller.value = 0.5;
    // Half way out in time, the web's ease-kun-in has covered
    // exit(0.5) of the way, so the surface is still 1 - exit(0.5) there.
    expect(curve.value, closeTo(1 - KunEasing.exit.transform(0.5), 1e-9));
    expect(curve.value, greaterThan(0.5));
  });
}
