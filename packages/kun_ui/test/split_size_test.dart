import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/src/foundation/split_size.dart';

const KunSplitSizeOptions range = KunSplitSizeOptions(min: 240, max: 480);
const KunSplitSizeOptions snaps = KunSplitSizeOptions(
  min: 240,
  max: 480,
  snapPoints: <double>[360, 412],
);

void main() {
  test('clamps into [min, max]', () {
    expect(resolveKunSplitSize(100, range), 240);
    expect(resolveKunSplitSize(900, range), 480);
    expect(resolveKunSplitSize(300, range), 300);
  });

  test('rounds to a whole pixel', () {
    expect(resolveKunSplitSize(300.4, range), 300);
    expect(resolveKunSplitSize(300.6, range), 301);
  });

  test('a swapped min and max still clamps', () {
    expect(
      resolveKunSplitSize(100, const KunSplitSizeOptions(min: 480, max: 240)),
      240,
    );
  });

  test('snaps within the threshold (default 8), not beyond it', () {
    expect(resolveKunSplitSize(365, snaps), 360);
    expect(resolveKunSplitSize(352, snaps), 360);
    expect(resolveKunSplitSize(351, snaps), 351);
    expect(resolveKunSplitSize(370, snaps), 370);
    expect(resolveKunSplitSize(405, snaps), 412);
    expect(
      resolveKunSplitSize(
        405,
        const KunSplitSizeOptions(
          min: 240,
          max: 480,
          snapPoints: <double>[360, 412],
          snapThreshold: 4,
        ),
      ),
      405,
    );
  });

  test('the nearest snap point wins; the first one on a tie', () {
    expect(
      resolveKunSplitSize(
        390,
        const KunSplitSizeOptions(
          min: 240,
          max: 480,
          snapPoints: <double>[380, 396],
        ),
      ),
      396,
    );
    expect(
      resolveKunSplitSize(
        388,
        const KunSplitSizeOptions(
          min: 240,
          max: 480,
          snapPoints: <double>[380, 396],
        ),
      ),
      380,
    );
  });

  test('snap points outside [min, max] are ignored', () {
    expect(
      resolveKunSplitSize(
        478,
        const KunSplitSizeOptions(
          min: 240,
          max: 480,
          snapPoints: <double>[484],
        ),
      ),
      478,
    );
  });

  test('a snap is applied after clamping', () {
    expect(
      resolveKunSplitSize(
        100,
        const KunSplitSizeOptions(
          min: 240,
          max: 480,
          snapPoints: <double>[244],
        ),
      ),
      244,
    );
  });

  test('a keyboard step is not cancelled or reversed by a snap', () {
    expect(
      resolveKunSplitSize(
        365,
        const KunSplitSizeOptions(
          min: 240,
          max: 480,
          snapPoints: <double>[360, 412],
          from: 360,
        ),
      ),
      365,
    );
    expect(
      resolveKunSplitSize(
        358,
        const KunSplitSizeOptions(
          min: 240,
          max: 480,
          snapPoints: <double>[360, 412],
          from: 348,
        ),
      ),
      360,
    );
    expect(
      resolveKunSplitSize(
        365,
        const KunSplitSizeOptions(
          min: 240,
          max: 480,
          snapPoints: <double>[360, 412],
          from: 375,
        ),
      ),
      360,
    );
    expect(
      resolveKunSplitSize(
        363,
        const KunSplitSizeOptions(
          min: 240,
          max: 480,
          snapPoints: <double>[360, 412],
          from: 355,
        ),
      ),
      360,
    );
    expect(
      resolveKunSplitSize(
        355,
        const KunSplitSizeOptions(
          min: 240,
          max: 480,
          snapPoints: <double>[360, 412],
          from: 358,
        ),
      ),
      355,
    );
  });
}
